/// Probing a channel's addresses and ranking them.
///
/// A playlist line is a claim, not a promise: the same list carries
/// addresses that answer in 80 ms, addresses that answer 200 with no bytes
/// in them, and addresses that are a dead host on the other side of the
/// world. Ranking them is what turns "one channel, one URL" into "one
/// channel, a list of candidates to hand to the player's recovery ladder",
/// which is the difference between a channel that stalls and a channel that
/// switches lines.
///
/// The transport is a seam — [IptvLineProbe] — exactly as the importer's
/// `IptvFetcher` is: this package does not know dio, a proxy rule, or how
/// many bytes make a stream count as alive. It only knows how to walk a
/// list of addresses without stampeding the server, how long to wait for
/// one, and what to do with the answer.
library;

// ignore_for_file: unnecessary_type_name_in_constructor -- this SDK has no
// `new.named` shorthand: a named constructor must repeat its type name.

import 'dart:async';

import 'package:live_iptv/src/model/model.dart';
import 'package:meta/meta.dart';

/// Asks one address whether it is there, and how fast it answers.
///
/// The implementation must resolve [IptvProbeOutcome.answered] only when it
/// saw actual media bytes: an HTTP 200 with an empty body is a dead stream,
/// and calling it reachable would put it first in the ranking and make the
/// player stall on it. An address this transport cannot speak to at all —
/// an `rtmp://` or `udp://` line, which real IPTV lists are full of —
/// answers [IptvProbeOutcome.inconclusive] rather than
/// [IptvProbeOutcome.down]: not being able to ask is not evidence of death.
typedef IptvLineProbe = Future<IptvProbeOutcome> Function(String url, Map<String, String> headers);

/// What a probe of one address found.
@immutable
class IptvProbeOutcome {
  /// A verdict.
  const new({required this.ok, this.inconclusive = false, this.latency, this.bytes, this.message});

  /// A verdict about an address that answered with media in [latency].
  const IptvProbeOutcome.answered(this.latency, {this.bytes, this.message}) : ok = true, inconclusive = false;

  /// A verdict about an address that did not answer.
  ///
  /// The reason is required: a failure the screen cannot explain and a log
  /// cannot grep is the one thing a probe must not produce.
  const IptvProbeOutcome.down(this.message) : ok = false, inconclusive = false, latency = null, bytes = null;

  /// A verdict from a probe that could not ask the question.
  ///
  /// It writes no health record, so the address keeps being ranked with the
  /// lines nobody has probed instead of being buried with the failures —
  /// which is what an `rtmp://` mirror of a working HLS line deserves.
  const IptvProbeOutcome.inconclusive(this.message) : ok = false, inconclusive = true, latency = null, bytes = null;

  /// Whether the address delivered media.
  final bool ok;

  /// Whether the probe abstained because the address is not something it can
  /// open. Never both with [ok].
  final bool inconclusive;

  /// How long the first bytes took, when they came.
  final Duration? latency;

  /// How many bytes were read to decide, when the probe counted them.
  final int? bytes;

  /// Why it failed, or anything else worth showing the user.
  final String? message;

  /// This outcome, with [latency] filled in with [elapsed] when the probe
  /// measured none.
  IptvProbeOutcome withLatency(Duration elapsed) =>
      ok && latency == null ? IptvProbeOutcome(ok: true, latency: elapsed, bytes: bytes, message: message) : this;

  @override
  bool operator ==(Object other) =>
      other is IptvProbeOutcome &&
      other.ok == ok &&
      other.inconclusive == inconclusive &&
      other.latency == latency &&
      other.bytes == bytes &&
      other.message == message;

  @override
  int get hashCode => Object.hash(ok, inconclusive, latency, bytes, message);

  @override
  String toString() =>
      'IptvProbeOutcome(${inconclusive
          ? 'skipped'
          : ok
          ? 'ok'
          : 'down'}${latency == null ? '' : ', ${latency!.inMilliseconds}ms'})';
}

/// The probe of one address of one channel.
@immutable
class IptvLineResult {
  /// A result.
  const new(this.url, this.outcome);

  /// The address that was probed.
  final String url;

  /// What it answered.
  final IptvProbeOutcome outcome;
}

/// Every address of one channel, in the order it was probed.
@immutable
class IptvProbeReport {
  /// A report.
  IptvProbeReport({required this.channelId, required List<IptvLineResult> results, this.aborted = false})
    : results = List.unmodifiable(results);

  /// The channel whose addresses were probed.
  final String channelId;

  /// The results, in the playlist's own address order.
  final List<IptvLineResult> results;

  /// Whether the probe stopped before every address had an answer, either
  /// because the caller cancelled or because a good line was found and the
  /// rest were left alone.
  final bool aborted;

  /// The fastest address that answered, null when none did.
  String? get bestUrl {
    final working = results.where((result) => result.outcome.ok).toList();
    if (working.isEmpty) {
      return null;
    }
    working.sort((a, b) => _compareLatency(a.outcome.latency, b.outcome.latency));
    return working.first.url;
  }

  /// Whether nothing answered: the channel is unwatchable right now.
  ///
  /// A channel whose every address the probe could not ask about is *not*
  /// down — it is unknown, which is the honest answer for an `rtmp://`-only
  /// line and the difference between "switch to the next list" and "this
  /// list is dead". A channel with no address at all is down, because there
  /// is nothing left to be unsure about.
  bool get isDown => bestUrl == null && !isUnprobed;

  /// Whether the probe learned nothing: every address abstained.
  bool get isUnprobed => results.isNotEmpty && results.every((result) => result.outcome.inconclusive);
}

/// One playable address of a channel, with the request it needs.
@immutable
class IptvLineCandidate {
  /// A candidate.
  const new({required this.url, this.headers = const {}, this.health});

  /// The address.
  final String url;

  /// The request headers the playlist declared for the channel.
  final Map<String, String> headers;

  /// What the last probe said, null when this address has never been
  /// probed or the verdict is too old to act on.
  final IptvLineHealth? health;

  /// Whether the last verdict was good.
  bool get isHealthy => health?.ok ?? false;

  /// Whether the address has an answer at all.
  bool get isProbed => health != null;
}

/// The addresses of [entry]: the primary URL first, then its alternatives,
/// with duplicates gone.
///
/// The order is the playlist's, and it is kept as the tie-break everywhere
/// below: a list the provider put first is a claim that it is the best one,
/// and probing must not quietly invert that when several addresses answer
/// equally fast.
List<String> iptvLineUrls(IptvEntry entry) {
  final urls = <String>[];
  for (final url in [entry.url, ...entry.alternatives]) {
    final trimmed = url.trim();
    if (trimmed.isNotEmpty && !urls.contains(trimmed)) {
      urls.add(trimmed);
    }
  }
  return List.unmodifiable(urls);
}

/// The channel's addresses, best first, given what the probes found.
///
/// Three buckets, in that order: an address that answered, an address
/// nobody has asked, and an address that failed. A never-asked address sits
/// *ahead* of the failures rather than behind them, because "nobody knows"
/// is not evidence of death — a channel imported an hour ago has no
/// verdicts, and ranking it by that absence would send the player to a
/// known-dead address first.
///
/// A verdict older than [staleAfter] is dropped to "nobody knows": sources
/// come back, and a failure from yesterday has no business deciding tonight's
/// order.
List<IptvLineCandidate> rankIptvLines(
  IptvChannel channel,
  Map<String, IptvLineHealth> health, {
  DateTime? now,
  Duration staleAfter = const Duration(hours: 12),
}) {
  final urls = iptvLineUrls(channel.entry);
  final ranked = <_RankedLine>[];
  for (final (index, url) in urls.indexed) {
    final record = health[url];
    final stale = record != null && now != null && now.difference(record.checkedAt) > staleAfter;
    final verdict = stale ? null : record;
    ranked.add(
      _RankedLine(
        candidate: IptvLineCandidate(url: url, headers: channel.entry.headers, health: verdict),
        index: index,
        bucket: verdict == null ? 1 : (verdict.ok ? 0 : 2),
      ),
    );
  }
  ranked.sort((a, b) {
    if (a.bucket != b.bucket) {
      return a.bucket.compareTo(b.bucket);
    }
    final byLatency = _compareLatency(a.candidate.health?.latency, b.candidate.health?.latency);
    if (byLatency != 0) {
      return byLatency;
    }
    final byFailures = (a.candidate.health?.failures ?? 0).compareTo(b.candidate.health?.failures ?? 0);
    if (byFailures != 0) {
      return byFailures;
    }
    return a.index.compareTo(b.index);
  });
  return List.unmodifiable([for (final line in ranked) line.candidate]);
}

/// Compares two latencies, the unknown one last.
int _compareLatency(Duration? a, Duration? b) {
  if (a == null) {
    return b == null ? 0 : 1;
  }
  if (b == null) {
    return -1;
  }
  return a.compareTo(b);
}

/// One ranked address, with the bucket and the playlist order it keeps.
class _RankedLine {
  const _RankedLine({required this.candidate, required this.index, required this.bucket});

  final IptvLineCandidate candidate;
  final int index;
  final int bucket;
}

/// Walks a channel's addresses and asks each one how it is.
///
/// [concurrency] bounds how many probes run at once, because the point of
/// probing is to be asked about a hundred channels and a hundred channels
/// have a hundred addresses each; unbounded, that is a denial-of-service
/// attempt against whoever sold the list. [timeout] is applied per address,
/// so one black-holed host cannot hold up the report — a probe that never
/// answers is a failure, not an unfinished future.
///
/// By default a channel stops being probed as soon as an address answers
/// ([stopOnFirstOk]): the user is waiting for a picture, and timing the
/// remaining addresses tells them nothing they need before it starts. A
/// deliberate health check of the whole list passes `stopOnFirstOk: false`.
final class IptvLineProber {
  /// A prober asking [probe] about each address.
  new({
    required this.probe,
    this.concurrency = 4,
    this.timeout = const Duration(seconds: 6),
    this.stopOnFirstOk = true,
  });

  /// The transport seam.
  final IptvLineProbe probe;

  /// How many addresses are asked at once, at most.
  final int concurrency;

  /// How long one address may take before it counts as silent.
  final Duration timeout;

  /// Whether a channel's probe stops at its first working address.
  final bool stopOnFirstOk;

  bool _cancelled = false;

  /// Whether [cancel] has been called.
  bool get isCancelled => _cancelled;

  /// Stops handing out more addresses.
  ///
  /// Probes already in flight are not aborted — the transport owns those,
  /// and this package will not guess how to interrupt one — but no further
  /// address is asked, and the report says [IptvProbeReport.aborted].
  void cancel() => _cancelled = true;

  /// Probes every address of [channel].
  Future<IptvProbeReport> probeChannel(IptvChannel channel, {bool? stopOnFirstOk}) async {
    final urls = iptvLineUrls(channel.entry);
    if (urls.isEmpty) {
      return IptvProbeReport(channelId: channel.id, results: const [], aborted: true);
    }
    final stopFirst = stopOnFirstOk ?? this.stopOnFirstOk;
    final answers = List<IptvLineResult?>.filled(urls.length, null);
    var cursor = 0;
    var settled = false;

    Future<void> worker() async {
      while (true) {
        if (_cancelled || (stopFirst && settled)) {
          return;
        }
        final index = cursor++;
        if (index >= urls.length) {
          return;
        }
        final outcome = await _ask(urls[index], channel.entry.headers);
        answers[index] = IptvLineResult(urls[index], outcome);
        if (outcome.ok) {
          settled = true;
        }
      }
    }

    await Future.wait([for (var start = 0; start < concurrency.clamp(1, urls.length); start++) worker()]);
    final results = [for (final answer in answers) ?answer];
    return IptvProbeReport(
      channelId: channel.id,
      results: results,
      aborted: _cancelled || results.length != urls.length,
    );
  }

  /// Probes [channels] a channel at a time, reporting each as it finishes.
  ///
  /// Channels are walked one after another rather than all at once: the
  /// concurrency limit is per channel, and running a hundred channels in
  /// parallel would multiply it into a hundred times the traffic the caller
  /// agreed to. [onReport] exists so a screen can fill in as it goes.
  ///
  /// Returns the reports for the channels it got through; [cancel] stops it
  /// handing out new ones, and what was already collected comes back rather
  /// than being discarded.
  Future<List<IptvProbeReport>> probeChannels(
    List<IptvChannel> channels, {
    void Function(IptvProbeReport report)? onReport,
    int? limit,
  }) async {
    final reports = <IptvProbeReport>[];
    final wanted = limit == null ? channels.length : limit.clamp(0, channels.length);
    for (final channel in channels.take(wanted)) {
      if (_cancelled) {
        break;
      }
      final report = await probeChannel(channel);
      reports.add(report);
      onReport?.call(report);
    }
    return List.unmodifiable(reports);
  }

  /// One address, with the timeout and the exceptions turned into a verdict.
  Future<IptvProbeOutcome> _ask(String url, Map<String, String> headers) async {
    final started = DateTime.now();
    try {
      final outcome = await probe(url, headers).timeout(timeout);
      return outcome.withLatency(DateTime.now().difference(started));
    } on TimeoutException {
      return IptvProbeOutcome.down('no answer in ${timeout.inSeconds}s');
    } on Object catch (error) {
      return IptvProbeOutcome.down('$error');
    }
  }
}

/// Folds the verdicts of [reports] into [previous], keyed by URL.
///
/// An address nobody probed — because the walk stopped at a good line, or
/// because the caller cancelled — keeps the verdict it already had: silence
/// is not a retraction, and a probe that abstained must not quietly promote
/// a known-dead mirror back to the front of the ranking.
Map<String, IptvLineHealth> mergeIptvLineHealth(
  Iterable<IptvProbeReport> reports, {
  Map<String, IptvLineHealth> previous = const {},
  DateTime? now,
}) {
  final moment = now ?? DateTime.now();
  final next = {...previous};
  for (final report in reports) {
    for (final result in report.results) {
      // An abstention writes nothing: the line keeps the verdict it already
      // had, or no verdict at all, which is what keeps an unprobeable
      // address ahead of a known-dead one in the ranking.
      if (result.outcome.inconclusive) {
        continue;
      }
      final outcome = result.outcome;
      next[result.url] = outcome.ok
          ? IptvLineHealth.probe(
              url: result.url,
              checkedAt: moment,
              latency: outcome.latency ?? Duration.zero,
              message: outcome.message,
            )
          : IptvLineHealth.failed(
              url: result.url,
              checkedAt: moment,
              message: outcome.message,
              previous: previous[result.url],
            );
    }
  }
  return Map.unmodifiable(next);
}
