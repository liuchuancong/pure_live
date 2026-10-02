import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'hls_media_spool.dart';
import 'hls_body_reader.dart';
import 'hls_http_body_metadata.dart';

/// The loader owns connect/header deadlines and registers request cancellation.
/// The pool awaits it even after retirement; it never abandons a live Future.
typedef HlsPrefetchLoader = Future<HlsPrefetchResponse> Function(HlsPrefetchCancellation cancellation);

final class HlsPrefetchResponse {
  const HlsPrefetchResponse(this.body, {this.expectedLength = -1, this.metadata});
  final Stream<List<int>> body;
  final int expectedLength;
  final HlsHttpBodyMetadata? metadata;
}

enum HlsPrefetchFailure { cancelled, download, capacity, timedOut }

final class HlsPrefetchCancellation {
  bool _cancelled = false;
  final Set<void Function()> _hooks = {};
  bool get isCancelled => _cancelled;
  void throwIfCancelled() {
    if (_cancelled) throw const _HlsPrefetchCancelled();
  }

  void Function() onCancel(void Function() hook) {
    if (_cancelled) {
      hook();
    } else {
      _hooks.add(hook);
    }
    return () => _hooks.remove(hook);
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final hook in _hooks.toList()) {
      try {
        hook();
      } on Object {
        // A faulty hook must not prevent cancellation of the other owners.
        // The corresponding loader still has to actually finish before close.
      }
    }
    _hooks.clear();
  }
}

final class HlsPrefetchTicket {
  HlsPrefetchTicket._(this.key, this._loader, this._body, this._trace);
  final String key;
  final HlsPrefetchLoader _loader;
  final HlsMediaSpool _body;
  final HlsPrefetchCancellation _cancellation = HlsPrefetchCancellation();
  final Completer<bool> _ready = Completer<bool>();
  final Completer<void> _disposed = Completer<void>();
  Future<bool> get ready => _ready.future;
  bool get isReady => _complete && !_retired;
  Future<void> get disposed => _disposed.future;
  HlsPrefetchFailure? _failure;
  HlsPrefetchFailure? get failure => _failure;
  bool _loading = false;
  bool _complete = false;
  bool _retired = false;
  bool _disposing = false;
  int _readers = 0;
  int _bytes = 0;
  HlsHttpBodyMetadata? _metadata;
  final _PrefetchTrace? _trace;

  /// Detached numeric/enum evidence, deliberately excluding the request key.
  /// Times use this ticket's admission clock, not the relay request clock.
  Map<String, Object?>? diagnosticsSnapshot() => _trace == null
      ? null
      : {
          ..._trace.snapshot(),
          'ready': isReady,
          'retired': _retired,
          'disposed': _disposed.isCompleted,
          'failure': _failure?.name,
        };
}

final class _PrefetchTrace {
  final clock = Stopwatch()..start();
  String phase = 'queued';
  int? loadStartedMs;
  int? headersMs;
  int? firstBodyMs;
  int? lastBodyMs;
  int? sealedMs;
  int? retiredMs;
  String? retiredPhase;
  int? expectedBytes;
  int receivedBytes = 0;
  int stagedBytes = 0;

  Map<String, Object?> snapshot() => {
    'clock': 'milliseconds-since-ticket-admission',
    'ageMs': clock.elapsedMilliseconds,
    'phase': phase,
    'loadStartedMs': loadStartedMs,
    'headersMs': headersMs,
    'firstBodyMs': firstBodyMs,
    'lastBodyMs': lastBodyMs,
    'sealedMs': sealedMs,
    'retiredMs': retiredMs,
    'retiredPhase': retiredPhase,
    'expectedBytes': expectedBytes,
    'receivedBytes': receivedBytes,
    'stagedBytes': stagedBytes,
  };
}

/// One bounded pool per recording source generation. Queued, downloading,
/// cached and retired-but-leased entries all consume the same entry budget.
/// Entries are never evicted implicitly to disguise an over-capacity request.
final class HlsPrefetchPool {
  HlsPrefetchPool({
    required this.createDirectory,
    this.maximumEntries = 8,
    this.maximumConcurrent = 6,
    this.maximumReaders = 8,
    this.maximumBytes = 128 * 1024 * 1024,
    this.maximumBodyBytes = 128 * 1024 * 1024,
    this.memoryBytesPerBody = 2 * 1024 * 1024,
    this.bodyIdleTimeout = const Duration(seconds: 15),
    this.enableDiagnostics = false,
  }) {
    if (bodyIdleTimeout <= Duration.zero ||
        bodyIdleTimeout > const Duration(minutes: 1) ||
        maximumEntries < 1 ||
        maximumEntries > 32 ||
        maximumConcurrent < 1 ||
        maximumConcurrent > maximumEntries ||
        maximumReaders < 1 ||
        maximumReaders > 8 ||
        maximumBytes < 1 ||
        maximumBytes > 128 * 1024 * 1024 ||
        maximumBodyBytes < 1 ||
        maximumBodyBytes > maximumBytes ||
        memoryBytesPerBody < 0 ||
        memoryBytesPerBody > 2 * 1024 * 1024) {
      throw ArgumentError('Invalid HLS prefetch capacity');
    }
  }

  final Future<Directory> Function() createDirectory;
  final int maximumEntries;
  final int maximumConcurrent;
  final int maximumReaders;
  final int maximumBytes;
  final int maximumBodyBytes;
  final int memoryBytesPerBody;
  final Duration bodyIdleTimeout;
  final bool enableDiagnostics;
  final Map<String, HlsPrefetchTicket> _entries = {};
  final Set<HlsPrefetchTicket> _owned = {};
  final ListQueue<HlsPrefetchTicket> _queue = ListQueue();
  int _active = 0;
  int _bytes = 0;
  int _readers = 0;
  bool _closed = false;
  bool _cleanupFailed = false;
  Future<void>? _closing;
  int get ownedEntries => _owned.length;
  int get activeDownloads => _active;
  int get retainedBytes => _bytes;
  int get activeReaders => _readers;

  HlsPrefetchTicket? prefetch(String key, HlsPrefetchLoader loader) {
    if (_closed || _cleanupFailed) throw StateError('HLS prefetch pool is closed or faulted');
    if (key.isEmpty || key.length > 65536) throw ArgumentError('Invalid HLS prefetch identity');
    final existing = _entries[key];
    if (existing != null) return existing;
    if (_owned.length >= maximumEntries) return null;
    final entry = HlsPrefetchTicket._(
      key,
      loader,
      HlsMediaSpool(
        createDirectory: createDirectory,
        memoryLimit: memoryBytesPerBody,
        byteLimit: maximumBodyBytes,
        reusable: true,
      ),
      enableDiagnostics ? _PrefetchTrace() : null,
    );
    _entries[key] = entry;
    _owned.add(entry);
    _queue.add(entry);
    _pump();
    return entry;
  }

  HlsPrefetchLease? acquire(String key) {
    final entry = _entries[key];
    if (_closed ||
        _cleanupFailed ||
        entry == null ||
        !entry._complete ||
        entry._retired ||
        _readers >= maximumReaders) {
      return null;
    }
    entry._readers++;
    _readers++;
    return HlsPrefetchLease._(entry._body, entry._metadata, () {
      entry._readers--;
      _readers--;
      _maybeDispose(entry);
    });
  }

  Future<void> evict(String key) async {
    final entry = _entries[key];
    if (entry == null) return;
    _retire(entry);
    await entry._disposed.future;
    if (_cleanupFailed) throw StateError('HLS prefetch cleanup failed');
  }

  void _pump() {
    while (!_closed && !_cleanupFailed && _active < maximumConcurrent && _queue.isNotEmpty) {
      final entry = _queue.removeFirst();
      entry._trace?.phase = 'loading';
      entry._trace?.loadStartedMs = entry._trace.clock.elapsedMilliseconds;
      entry._loading = true;
      _active++;
      unawaited(_run(entry));
    }
  }

  Future<void> _run(HlsPrefetchTicket entry) async {
    try {
      await _receive(entry);
      entry._cancellation.throwIfCancelled();
      entry._complete = true;
      entry._trace?.phase = 'ready';
      entry._ready.complete(true);
    } on Object catch (error) {
      entry._failure = entry._cancellation.isCancelled
          ? HlsPrefetchFailure.cancelled
          : error is _HlsPrefetchCapacity
          ? HlsPrefetchFailure.capacity
          : error is TimeoutException
          ? HlsPrefetchFailure.timedOut
          : HlsPrefetchFailure.download;
      _retire(entry);
    } finally {
      entry._loading = false;
      _active--;
      _maybeDispose(entry);
      _pump();
    }
  }

  Future<void> _receive(HlsPrefetchTicket entry) async {
    final budget = HlsResponseBudget(bodyIdleTimeout);
    final response = await entry._loader(entry._cancellation);
    entry._trace?.phase = 'body';
    entry._trace?.headersMs = entry._trace.clock.elapsedMilliseconds;
    entry._trace?.expectedBytes = response.expectedLength;
    final iterator = HlsBodyReader(response.body);
    final detach = entry._cancellation.onCancel(() {
      unawaited(iterator.cancel().catchError((Object _) {}));
    });
    try {
      entry._cancellation.throwIfCancelled();
      budget.check();
      if (response.expectedLength < -1) throw const FormatException('Invalid HLS response length');
      if (response.metadata != null && response.metadata!.expectedLength != response.expectedLength) {
        throw const FormatException('HLS response metadata differs from its body contract');
      }
      if (response.expectedLength > maximumBodyBytes) throw const _HlsPrefetchCapacity();
      while (await budget.wait(iterator.moveNext)) {
        entry._cancellation.throwIfCancelled();
        final chunk = iterator.current;
        final trace = entry._trace;
        if (trace != null && chunk.isNotEmpty) {
          trace.firstBodyMs ??= trace.clock.elapsedMilliseconds;
          trace.lastBodyMs = trace.clock.elapsedMilliseconds;
          trace.receivedBytes += chunk.length;
        }
        if (chunk.length > maximumBytes - _bytes || chunk.length > maximumBodyBytes - entry._bytes) {
          throw const _HlsPrefetchCapacity();
        }
        // Reserve before asynchronous disk IO; simultaneous receives share it.
        _bytes += chunk.length;
        entry._bytes += chunk.length;
        entry._trace?.phase = 'staging';
        await entry._body.add(chunk);
        if (trace != null) trace.stagedBytes += chunk.length;
        entry._trace?.phase = 'body';
      }
      entry._cancellation.throwIfCancelled();
      entry._trace?.phase = 'sealing';
      await entry._body.seal(expectedLength: response.expectedLength);
      entry._trace?.sealedMs = entry._trace.clock.elapsedMilliseconds;
      budget.check();
      entry._metadata = response.metadata;
    } finally {
      detach();
      await iterator.cancel();
    }
  }

  void _retire(HlsPrefetchTicket entry) {
    if (entry._retired) return;
    entry._retired = true;
    entry._trace?.retiredPhase = entry._trace.phase;
    entry._trace?.retiredMs = entry._trace.clock.elapsedMilliseconds;
    // A retired loader may still settle later. Keep its monotonic clock valid
    // for that response/disposal; Stopwatch has no scheduled timer to release.
    if (identical(_entries[entry.key], entry)) _entries.remove(entry.key);
    _queue.remove(entry);
    entry._failure ??= entry._complete ? null : HlsPrefetchFailure.cancelled;
    entry._cancellation.cancel();
    if (!entry._ready.isCompleted) entry._ready.complete(false);
    _maybeDispose(entry);
  }

  void _maybeDispose(HlsPrefetchTicket entry) {
    if (!entry._retired || entry._loading || entry._readers != 0 || entry._disposing) return;
    entry._disposing = true;
    unawaited(_dispose(entry));
  }

  Future<void> _dispose(HlsPrefetchTicket entry) async {
    try {
      await entry._body.dispose();
      _bytes -= entry._bytes;
      _owned.remove(entry);
    } on Object {
      // Failed cleanup keeps its capacity charged and prohibits more work.
      _cleanupFailed = true;
      for (final other in _owned.toList()) {
        _retire(other);
      }
    } finally {
      entry._disposed.complete();
    }
  }

  /// The caller closes local response writers and releases every lease first.
  /// Pending upstream loaders are cancelled and awaited, not detached.
  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    _closed = true;
    final owned = _owned.toList();
    for (final entry in owned) {
      _retire(entry);
    }
    await Future.wait(owned.map((entry) => entry._disposed.future));
    if (_cleanupFailed) throw StateError('HLS prefetch cleanup failed; capacity remains charged');
  }
}

/// A lease pins the whole spool, including during a slow local response write.
/// Releasing during a write waits for that actual write to complete or fail.
final class HlsPrefetchLease {
  HlsPrefetchLease._(this._body, this.metadata, this._onRelease);
  final HlsHttpBodyMetadata? metadata;
  final HlsMediaSpool _body;
  final void Function() _onRelease;
  final Completer<void> _released = Completer<void>();
  bool _releaseRequested = false;
  bool _writing = false;
  int get length => _body.length;

  Future<void> writeTo(StreamConsumer<List<int>> destination) async {
    if (_releaseRequested || _writing) throw StateError('HLS lease is released or already writing');
    _writing = true;
    try {
      await destination.addStream(_body.read());
    } finally {
      _writing = false;
      if (_releaseRequested) _finishRelease();
    }
  }

  Future<void> release() {
    _releaseRequested = true;
    if (!_writing) _finishRelease();
    return _released.future;
  }

  void _finishRelease() {
    if (_released.isCompleted) return;
    _onRelease();
    _released.complete();
  }
}

final class _HlsPrefetchCancelled implements Exception {
  const _HlsPrefetchCancelled();
}

final class _HlsPrefetchCapacity implements Exception {
  const _HlsPrefetchCapacity();
}
