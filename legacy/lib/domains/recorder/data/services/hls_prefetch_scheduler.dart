import 'dart:async';
import 'dart:convert';

import 'hls_prefetch_pool.dart';
import 'hls_retained_manifest.dart';
import 'hls_retained_window.dart';

enum HlsPrefetchResourceKind { media, initialization, key }

enum HlsPrefetchRefreshStage { snapshot, retention }

typedef HlsPrefetchSelection = ({String id, Uri source, HlsMediaSnapshot snapshot});

final class HlsPrefetchResource {
  HlsPrefetchResource._(this.key, this.uri, this.range, this.kind, [this.feedId, this.sequence]);
  factory HlsPrefetchResource.media(String feedId, HlsSegmentDescriptor segment) => HlsPrefetchResource._(
    jsonEncode(['media', feedId, segment.sequence, segment.uri.toString(), segment.range?.identity]),
    segment.uri,
    segment.range,
    HlsPrefetchResourceKind.media,
    feedId,
    segment.sequence,
  );
  factory HlsPrefetchResource.initialization(HlsMapDescriptor map) => HlsPrefetchResource._(
    jsonEncode(['map', map.identity]),
    map.uri,
    map.range,
    HlsPrefetchResourceKind.initialization,
  );
  factory HlsPrefetchResource.key(HlsKeyDescriptor key) =>
      HlsPrefetchResource._(jsonEncode(['key', key.identity]), key.uri!, null, HlsPrefetchResourceKind.key);
  final String key;
  final Uri uri;
  final HlsSegmentRange? range;
  final HlsPrefetchResourceKind kind;
  final String? feedId;
  final int? sequence;
}

/// One recording source generation, one shared pool, explicitly selected media
/// feeds only. Playlist refresh is independent of native fragment consumption.
/// This owner never selects a different quality or follows a master on its own.
final class HlsPrefetchScheduler {
  HlsPrefetchScheduler({
    required this.pool,
    required this.fetchSnapshot,
    required this.loadResource,
    this.onCoverageGap,
    this.onDownloadResult,
    this.onRefreshFailure,
    this.pollInterval,
    this.maximumFeeds = 2,
    this.maximumSegments = 64,
  }) {
    if (maximumFeeds < 1 ||
        maximumFeeds > 2 ||
        maximumSegments < 2 ||
        maximumSegments > 64 ||
        (pollInterval != null && (pollInterval! <= Duration.zero || pollInterval! > const Duration(seconds: 30)))) {
      throw ArgumentError('Invalid recording prefetch scheduling limits');
    }
  }
  final HlsPrefetchPool pool;
  final Future<HlsMediaSnapshot> Function(Uri source, HlsPrefetchCancellation cancellation) fetchSnapshot;
  final Future<HlsPrefetchResponse> Function(HlsPrefetchResource resource, HlsPrefetchCancellation cancellation)
  loadResource;
  final void Function()? onCoverageGap;
  final void Function(HlsPrefetchResource resource, bool ready)? onDownloadResult;
  final void Function(String feedId, HlsPrefetchRefreshStage stage, Object error)? onRefreshFailure;
  final Duration? pollInterval;
  final int maximumFeeds;
  final int maximumSegments;
  final Map<String, _Feed> _feeds = {};
  final Map<String, (HlsPrefetchResource, HlsPrefetchTicket, String)> _items = {};
  final Set<Future<void>> _jobs = {};
  bool _finishing = false;
  bool _stopped = false;
  bool _closed = false;
  bool _gap = false;
  Future<void>? _closing;
  Future<bool>? _draining;
  int _nextFeed = 0;
  Completer<void> _changed = Completer<void>();

  bool get coverageIncomplete => _gap;
  int get feedCount => _feeds.length;
  int get resourceRecordCount => _items.length;
  bool hasFeed(String id) => _feeds.containsKey(id);
  Map<String, Object?> describeDownload(String key) => {
    'admitted': _items.containsKey(key),
    'ticket': _items[key]?.$2.diagnosticsSnapshot(),
  };
  Set<String> get requiredKeys => {
    for (final feed in _feeds.values) ...feed.wanted.keys,
    for (final feed in _feeds.values)
      for (final generation in feed.published)
        for (final resource in _dependencies(feed.id, generation.where((s) => s.sequence >= feed.delivered - 1)))
          resource.key,
  };

  /// Unsupported inputs remain with the caller's original path. No network is
  /// started until the complete initial metadata/render contract is accepted.
  bool select(String id, Uri fetchSource, HlsMediaSnapshot initial) =>
      selectAll([(id: id, source: fetchSource, snapshot: initial)]);

  /// Validate the whole selected A/V set before allocating any downloader or
  /// refresh timer. A rejected member must leave existing selection untouched.
  bool selectAll(Iterable<HlsPrefetchSelection> selections) {
    if (_closed || _finishing) return false;
    final pending = <String, _Feed>{};
    try {
      for (final selection in selections) {
        if (pending.length + _feeds.length >= maximumFeeds ||
            selection.id.isEmpty ||
            selection.id.length > 256 ||
            pending.containsKey(selection.id) ||
            _feeds.containsKey(selection.id) ||
            !_validSource(selection.source) ||
            !_validSource(selection.snapshot.source)) {
          return false;
        }
        final window = HlsRetainedWindow(selection.snapshot.source, maximumSegments: maximumSegments);
        // Admission must preserve the initial prefix, including finite media.
        // The caller can retain its original path when the bounded window is
        // too small; silently dropping its first segments is not selection.
        if (window.merge(selection.snapshot).isNotEmpty) return false;
        renderHlsRetainedManifest(window, localUri: (uri) => uri);
        final feed = _Feed(selection.id, selection.source, window, selection.snapshot.reloadFingerprint);
        _rebuild(feed);
        pending[selection.id] = feed;
      }
    } on FormatException {
      return false;
    }
    if (pending.isEmpty || _closed || _finishing) return false;
    _feeds.addAll(pending);
    _pump();
    for (final feed in pending.values) {
      _schedule(feed);
    }
    return true;
  }

  static bool _validSource(Uri uri) =>
      const {'http', 'https'}.contains(uri.scheme) &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      !uri.hasFragment &&
      uri.toString().length <= 65536;

  String publish(String id, Uri Function(HlsPrefetchResource resource) localUri, {bool startAtFirst = false}) {
    final feed = _feeds[id];
    if (_closed || feed == null) throw StateError('Selected HLS feed is unavailable');
    if (_finishing) return feed.finishedManifest!;
    if (feed.failed) throw StateError('Selected HLS feed is unavailable');
    Uri map(HlsPrefetchResource resource) {
      return localUri(resource);
    }

    final text = renderHlsRetainedManifest(
      feed.window,
      localUri: (uri) => uri,
      segmentUri: (segment) => map(HlsPrefetchResource.media(id, segment)),
      initializationUri: (initialization) => map(HlsPrefetchResource.initialization(initialization)),
      keyUri: (key) => map(HlsPrefetchResource.key(key)),
      startAtFirst: startAtFirst,
    );
    feed.published = [feed.window.segments, if (feed.published.isNotEmpty) feed.published.first];
    feed.lastManifest = text;
    _prune();
    return text;
  }

  Future<HlsPrefetchLease?> acquire(String key) async {
    final clock = Stopwatch()..start();
    final deadline = pool.bodyIdleTimeout * 4 + const Duration(seconds: 15);
    while (!_closed) {
      _pump();
      final left = deadline - clock.elapsed;
      if (left <= Duration.zero) return null;
      final entry = _items[key];
      try {
        if (entry != null) {
          if (!await entry.$2.ready.timeout(left) || _closed) return null;
          return pool.acquire(key);
        }
        if (_finishing || _stopped || !requiredKeys.contains(key)) return null;
        await _changed.future.timeout(left);
      } on TimeoutException {
        return null;
      }
    }
    return null;
  }

  /// Local response completion, not a decoder-consumption claim. Keep two
  /// delivered segments and both published generations for repeat requests.
  void delivered(String key) {
    final resource = _items[key]?.$1;
    final feed = _feeds[resource?.feedId];
    if (_closed || _finishing || feed == null || resource?.sequence == null) return;
    final sequence = resource!.sequence!;
    if (sequence <= feed.delivered) return;
    feed.delivered = sequence;
    if (sequence > 1) feed.window.retireBefore(sequence - 1);
    _rebuild(feed);
    _prune();
    _pump();
  }

  void freeze() {
    if (_finishing) return;
    _finishing = true;
    for (final feed in _feeds.values) {
      feed.timer?.cancel();
      feed.refreshCancellation?.cancel();
      // Snapshot the actual offered URI mapping, not newer background metadata.
      // No callback is invoked after stop, including for a never-published feed.
      final cached = feed.lastManifest;
      feed.finishedManifest = cached == null
          ? '#EXTM3U\n#EXT-X-TARGETDURATION:${feed.window.targetDuration}\n#EXT-X-ENDLIST\n'
          : RegExp(r'^#EXT-X-ENDLIST$', multiLine: true).hasMatch(cached)
          ? cached
          : '${cached.trimRight()}\n#EXT-X-ENDLIST\n';
      if (feed.published.isNotEmpty) {
        feed.wanted = {
          for (final resource in _dependencies(
            feed.id,
            feed.published.first.where((segment) => segment.sequence >= feed.delivered - 1),
          ))
            resource.key: resource,
        };
      }
    }
    _prune();
    // A missing item can never be admitted after freeze; wake its existing
    // acquire waiter rather than making it consume a full network deadline.
    _notify();
  }

  /// Settle only already admitted dependencies from the last offered media
  /// generations. Freeze prevents refresh/admission; completion stops transport
  /// immediately rather than sleeping for the entire finite shutdown allowance.
  /// A successful result describes complete cache bodies, not native delivery.
  Future<bool> drainPublished({required Duration timeout}) {
    if (timeout <= Duration.zero || timeout > const Duration(seconds: 20)) {
      throw ArgumentError('Invalid HLS published download drain timeout');
    }
    return _draining ??= _drainPublished(timeout);
  }

  Future<bool> _drainPublished(Duration timeout) async {
    freeze();
    final keys = <String>{};
    for (final feed in _feeds.values) {
      if (feed.published.isEmpty) continue;
      keys.addAll(
        _dependencies(feed.id, feed.published.first.where((s) => s.sequence > feed.delivered)).map((r) => r.key),
      );
    }
    try {
      final ready = await Future.wait([for (final key in keys) _items[key]?.$2.ready ?? Future<bool>.value(false)])
          .timeout(timeout);
      return ready.every((value) => value);
    } on TimeoutException {
      return false;
    } finally {
      // Timed-out waits refer only to tickets still owned by the pool. Retire
      // their actual requests; close continues to await their final disposal.
      stopFetching();
    }
  }

  /// End unpublished downloads, retaining complete cached bodies for drain.
  void stopFetching() {
    freeze();
    _stopped = true;
    _notify();
    for (final entry in _items.values.toList()) {
      if (!entry.$2.isReady) _own(pool.evict(entry.$1.key));
    }
  }

  void _schedule(_Feed feed) {
    if (_closed || _finishing || feed.failed || feed.window.ended) return;
    // RFC 8216 6.3.4: first/changed loads use a full target, unchanged
    // loads a half target. Count time already spent loading, not another
    // full sleep after a slow successful response. Never overlap reloads.
    final interval = pollInterval ?? Duration(milliseconds: feed.window.targetDuration * (feed.unchanged ? 500 : 1000));
    final remaining = interval - feed.reloadClock.elapsed;
    feed.timer = Timer(remaining > Duration.zero ? remaining : Duration.zero, () => _own(_refresh(feed)));
  }

  Future<void> _refresh(_Feed feed) async {
    if (_closed || _finishing || feed.failed) return;
    feed.reloadClock.reset();
    final cancellation = HlsPrefetchCancellation();
    feed.refreshCancellation = cancellation;
    var stage = HlsPrefetchRefreshStage.snapshot;
    try {
      final snapshot = await fetchSnapshot(feed.source, cancellation);
      if (_closed || _finishing || cancellation.isCancelled) return;
      stage = HlsPrefetchRefreshStage.retention;
      final evicted = feed.window.merge(snapshot);
      feed.unchanged = snapshot.reloadFingerprint == feed.lastSnapshotFingerprint;
      feed.lastSnapshotFingerprint = snapshot.reloadFingerprint;
      if (evicted.any((s) => s.sequence > feed.delivered)) _markGap();
      _rebuild(feed);
      _prune();
      _pump();
    } on Object catch (error) {
      // A failed refresh is exposed to the caller, not an endlessly repeated
      // stale manifest. Recording retry/source-refresh policy stays upstream.
      if (!_closed && !_finishing) {
        feed.failed = true;
        // This feed will never refresh again. Surface the loss of continuous
        // coverage now, even when native stops before requesting its next
        // playlist. Draining already published bodies cannot clear this latch.
        _markGap();
        try {
          onRefreshFailure?.call(feed.id, stage, error);
        } on Object {
          /* Observation only: never retry or hide a failed feed. */
        }
      }
    } finally {
      feed.refreshCancellation = null;
      _schedule(feed);
    }
  }

  void _rebuild(_Feed feed) {
    final wanted = <String, HlsPrefetchResource>{};
    for (final resource in _dependencies(feed.id, feed.window.segments)) {
      wanted.putIfAbsent(resource.key, () => resource);
    }
    feed.wanted = wanted;
  }

  static Iterable<HlsPrefetchResource> _dependencies(String id, Iterable<HlsSegmentDescriptor> segments) sync* {
    for (final segment in segments) {
      final initialization = segment.initialization;
      if (initialization != null) {
        for (final key in initialization.keys) {
          yield HlsPrefetchResource.key(key);
        }
        yield HlsPrefetchResource.initialization(initialization);
      }
      for (final key in segment.keys) {
        yield HlsPrefetchResource.key(key);
      }
      if (!segment.gap) yield HlsPrefetchResource.media(id, segment);
    }
  }

  void _pump() {
    if (_closed || _stopped || _finishing || _feeds.isEmpty) return;
    final feeds = _feeds.values.where((feed) => !feed.failed).toList();
    if (feeds.isEmpty) return;
    var misses = 0;
    // Reserve space for every supported selected rendition: eager admission
    // of a long first playlist must not prevent the second feed from starting.
    final quota = (pool.maximumEntries ~/ maximumFeeds).clamp(1, 32);
    // Round-robin admission, not one unbounded queue for each rendition.
    while (misses < feeds.length && _items.length < 512) {
      final feed = feeds[_nextFeed++ % feeds.length];
      if (_items.values.where((entry) => entry.$3 == feed.id && entry.$2.failure == null).length >= quota) {
        misses++;
        continue;
      }
      HlsPrefetchResource? next;
      for (final resource in feed.wanted.values) {
        if (!_items.containsKey(resource.key)) {
          next = resource;
          break;
        }
      }
      if (next == null) {
        misses++;
        continue;
      }
      final resource = next;
      HlsPrefetchTicket? ticket;
      try {
        ticket = pool.prefetch(resource.key, (cancel) => loadResource(resource, cancel));
      } on Object {
        feed.failed = true;
        _markGap();
        return;
      }
      if (ticket == null) return; // Bounded backpressure, not an implicit retry.
      final admittedTicket = ticket;
      misses = 0;
      _items[resource.key] = (resource, ticket, feed.id);
      _notify();
      _own(() async {
        final ready = await admittedTicket.ready;
        _notify();
        try {
          onDownloadResult?.call(resource, ready);
        } on Object {
          /* Observation only. */
        }
        if (!ready && !_closed && !_finishing) _markGap();
        if (!ready) {
          await admittedTicket.disposed;
          _notify();
          _pump();
        }
      }());
    }
  }

  void _prune() {
    if (_closed) return;
    final required = requiredKeys;
    for (final key in _items.keys.where((key) => !required.contains(key)).toList()) {
      _items.remove(key);
      _own(() async {
        await pool.evict(key);
        _notify();
        _pump();
      }());
    }
  }

  void _markGap() {
    if (_gap || _closed || _finishing) return;
    _gap = true;
    try {
      onCoverageGap?.call();
    } on Object {
      /* Observation only. */
    }
  }

  void _notify() {
    final changed = _changed;
    _changed = Completer<void>();
    changed.complete();
  }

  void _own(Future<void> job) {
    // Store the handled future so no asynchronous failure is left unobserved.
    late Future<void> owned;
    owned = job
        .catchError((Object _) {
          _markGap();
        })
        .whenComplete(() => _jobs.remove(owned));
    _jobs.add(owned);
  }

  /// Caller ends native/local writers and releases their leases first.
  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    _closed = true;
    stopFetching();
    try {
      await pool.close();
    } finally {
      await Future.wait(_jobs.toList());
      _feeds.clear();
      _items.clear();
    }
  }
}

final class _Feed {
  _Feed(this.id, this.source, this.window, this.lastSnapshotFingerprint);
  final String id;
  final Uri source;
  final HlsRetainedWindow window;
  // The initial loader's start time is not available for every selection.
  // Selection time is conservative; subsequent loads have exact start times.
  final reloadClock = Stopwatch()..start();
  String lastSnapshotFingerprint;
  bool unchanged = false;
  Map<String, HlsPrefetchResource> wanted = {};
  List<List<HlsSegmentDescriptor>> published = [];
  String? lastManifest;
  String? finishedManifest;
  int delivered = -1;
  bool failed = false;
  Timer? timer;
  HlsPrefetchCancellation? refreshCancellation;
}
