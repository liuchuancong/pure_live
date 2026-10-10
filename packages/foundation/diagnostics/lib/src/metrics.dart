// Module: lib/src/metrics.dart
// Purpose: Counters and duration summaries with a hard bound on both labels and samples.
// Author: liuchuancong
// Created: 2026-10-11
//
// A dashboard metric is only trustworthy if it says what it threw away. An unbounded label set is a memory
// leak keyed on user input (a room id per view), and a mean-only duration hides the one slow request that made
// the session unwatchable, so this keeps a bounded sample window and reports p50 and p95 alongside it.

/// The default number of duration samples kept per label.
const int kMetricSampleLimit = 256;

/// The default number of distinct labels the registry accepts.
const int kMetricLabelLimit = 512;

/// What one label's samples look like.
final class MetricSummary {
  const MetricSummary({
    required this.name,
    required this.count,
    required this.total,
    required this.min,
    required this.max,
    required this.mean,
    this.p50,
    this.p95,
    this.discardedSamples = 0,
  });

  final String name;

  /// Total observations, including the ones outside the retained window.
  final int count;
  final Duration total;
  final Duration? min;
  final Duration? max;
  final Duration mean;

  /// Null until at least one sample is retained.
  final Duration? p50;
  final Duration? p95;

  /// Observations dropped from the window. A summary with a high count and a small window is a sampled view,
  /// not a census, and a p95 read off it says that.
  final int discardedSamples;

  bool get isSampled => discardedSamples > 0;

  @override
  String toString() =>
      'MetricSummary($name x$count min=${min?.inMilliseconds}ms p50=${p50?.inMilliseconds}ms '
      'p95=${p95?.inMilliseconds}ms max=${max?.inMilliseconds}ms${isSampled ? ' sampled' : ''})';
}

/// Counters and duration meters over a bounded window.
final class MetricRegistry {
  MetricRegistry({this.sampleLimit = kMetricSampleLimit, this.labelLimit = kMetricLabelLimit})
    : assert(sampleLimit >= 1, 'a window of zero samples measures nothing'),
      assert(labelLimit >= 1, 'a registry with no labels holds nothing');

  /// Counters collapse into this label once the label budget is gone, so the totals survive a label storm even
  /// though the per-name detail does not.
  static const String kOverflowLabelName = 'metric.overflow';

  final int sampleLimit;
  final int labelLimit;

  final Map<String, int> _counters = <String, int>{};
  final Map<String, _Samples> _durations = <String, _Samples>{};
  bool _overflowed = false;

  /// Distinct labels currently tracked.
  int get labelCount => {..._counters.keys, ..._durations.keys}.length;

  /// True once a label was refused and folded into [kOverflowLabelName].
  bool get hasOverflowed => _overflowed;

  /// Adds [by] to [name].
  void increment(String name, {int by = 1}) {
    final key = _accept(name);
    _counters[key] = (_counters[key] ?? 0) + by;
  }

  /// The current counter value, or zero.
  int counter(String name) => _counters[name] ?? 0;

  /// Records one observation of [name].
  void record(String name, Duration elapsed) {
    if (elapsed.isNegative) {
      // A negative duration is a wall-clock bug, not a measurement; keeping it would poison min and p50.
      increment('$name.negative');
      return;
    }
    final key = _accept(name);
    _durations.putIfAbsent(key, () => _Samples(sampleLimit)).add(elapsed);
  }

  /// Runs [body] and records how long it took, including when it throws.
  Future<R> timed<R>(String name, Future<R> Function() body) async {
    final watch = Stopwatch()..start();
    try {
      return await body();
    } finally {
      watch.stop();
      record(name, watch.elapsed);
    }
  }

  MetricSummary summary(String name) {
    final samples = _durations[name];
    if (samples == null) {
      return MetricSummary(name: name, count: 0, total: Duration.zero, min: null, max: null, mean: Duration.zero);
    }
    return samples.summarise(name);
  }

  /// Every counter and duration label, durations first by p95 so the slowest thing is at the top.
  List<MetricSummary> snapshots() {
    final out = <MetricSummary>[];
    for (final name in _counters.keys) {
      out.add(
        MetricSummary(
          name: name,
          count: _counters[name]!,
          total: Duration.zero,
          min: null,
          max: null,
          mean: Duration.zero,
        ),
      );
    }
    for (final entry in _durations.entries) {
      out.add(entry.value.summarise(entry.key));
    }
    out.sort((left, right) => (right.p95 ?? Duration.zero).compareTo(left.p95 ?? Duration.zero));
    return out;
  }

  Map<String, Object?> export() {
    return <String, Object?>{
      'counters': <String, int>{..._counters},
      'durations': <String, Object?>{
        for (final entry in _durations.entries) entry.key: entry.value.summarise(entry.key).toJson(),
      },
      'overflowed': _overflowed,
    };
  }

  void reset() {
    _counters.clear();
    _durations.clear();
    _overflowed = false;
  }

  String _accept(String name) {
    final known = _counters.containsKey(name) || _durations.containsKey(name);
    if (known || labelCount < labelLimit) {
      return name;
    }
    _overflowed = true;
    return kOverflowLabelName;
  }
}

class _Samples {
  _Samples(this.limit);

  final int limit;
  final List<int> _micros = <int>[];
  int _count = 0;
  int _totalMicros = 0;
  int? _min;
  int? _max;
  int _discarded = 0;

  void add(Duration elapsed) {
    final micros = elapsed.inMicroseconds;
    _count++;
    _totalMicros += micros;
    _min = _min == null || micros < _min! ? micros : _min;
    _max = _max == null || micros > _max! ? micros : _max;
    if (_micros.length >= limit) {
      // Drop the oldest retained sample: the window is a sliding view of recent behaviour, which is what a
      // "is it slow now" question needs.
      _micros.removeAt(0);
      _discarded++;
    }
    _micros.add(micros);
  }

  MetricSummary summarise(String name) {
    if (_micros.isEmpty) {
      return MetricSummary(
        name: name,
        count: _count,
        total: Duration(microseconds: _totalMicros),
        min: _min == null ? null : Duration(microseconds: _min!),
        max: _max == null ? null : Duration(microseconds: _max!),
        mean: _count == 0 ? Duration.zero : Duration(microseconds: (_totalMicros / _count).round()),
        discardedSamples: _discarded,
      );
    }
    final sorted = List<int>.of(_micros)..sort();
    return MetricSummary(
      name: name,
      count: _count,
      total: Duration(microseconds: _totalMicros),
      min: Duration(microseconds: sorted.first),
      max: Duration(microseconds: sorted.last),
      mean: Duration(microseconds: (_totalMicros / _count).round()),
      p50: Duration(microseconds: _percentile(sorted, 0.5)),
      p95: Duration(microseconds: _percentile(sorted, 0.95)),
      discardedSamples: _discarded,
    );
  }

  /// Nearest-rank percentile: for two samples the p95 is the larger one, not an interpolation that invents a
  /// third value nobody measured.
  static int _percentile(List<int> sorted, double fraction) {
    if (sorted.isEmpty) {
      return 0;
    }
    final rank = (sorted.length * fraction).ceil();
    return sorted[(rank - 1).clamp(0, sorted.length - 1)];
  }
}

extension MetricSummaryJson on MetricSummary {
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'count': count,
      'totalMs': total.inMilliseconds,
      'meanMs': mean.inMilliseconds,
      if (min != null) 'minMs': min!.inMilliseconds,
      if (max != null) 'maxMs': max!.inMilliseconds,
      if (p50 != null) 'p50Ms': p50!.inMilliseconds,
      if (p95 != null) 'p95Ms': p95!.inMilliseconds,
      if (discardedSamples > 0) 'discardedSamples': discardedSamples,
    };
  }
}
