import 'dart:async' show Future, unawaited;

import 'package:live_net/live_net.dart' show CancelToken;
import 'package:live_vod/src/douyu_replay.dart' show DouyuVodDanmakuChunk, VodDanmaku;

/// Loads one position-based comment page at a time, ahead of playback.
/// Seeks fence stale responses; memory stays bounded independently of the
/// recording's length.
final class DouyuVodTimeline {
  /// [fetch] uses the selected recording's id; [clear] removes comments
  /// already flying on screen.
  new({required this.fetch, required this.emit, required this.clear});

  /// Fetches one server page at a cursor.
  final Future<DouyuVodDanmakuChunk> Function(Duration start, CancelToken cancel) fetch;

  /// Delivers comments as the playback clock crosses their timestamp.
  final void Function(VodDanmaku message) emit;

  /// Removes flying comments after a seek or recording change.
  final void Function() clear;

  final List<VodDanmaku> _pending = [];
  CancelToken? _cancel;
  Duration? _next = Duration.zero;
  Duration _position = Duration.zero;
  Duration? _last;
  Duration? _retryAfter;
  bool _loading = false;
  bool _disposed = false;
  bool _running = false;
  int _generation = 0;

  /// Explicit seeking clears the old frame immediately, paused seeks
  /// included.
  void seek(Duration position) {
    if (_disposed) return;
    _generation++;
    _cancel?.cancel();
    _loading = false;
    _pending.clear();
    _position = position;
    _last = position;
    _next = position;
    _retryAfter = null;
    clear();
    _prefetch();
  }

  /// Advances from the engine's clock. Paused or buffering clocks never
  /// deliver; a backwards or large jump re-seeks the timeline itself.
  void update(Duration position, {required bool playing}) {
    if (_disposed) return;
    final previous = _last;
    _running = playing;
    _position = position;
    if (previous != null && (position < previous || position - previous > const Duration(seconds: 3))) {
      seek(position);
    } else {
      _last = position;
      if (playing) _deliver();
    }
    _prefetch();
  }

  void _deliver() {
    var count = 0;
    while (_pending.isNotEmpty && _pending.first.progress <= _position) {
      final message = _pending.removeAt(0);
      // A slow answer must not flood the current frame with stale comments.
      if (_position - message.progress <= const Duration(seconds: 2) && count++ < 40) emit(message);
    }
  }

  void _prefetch() {
    final cursor = _next;
    if (_disposed ||
        _loading ||
        cursor == null ||
        _pending.length >= 1500 ||
        cursor > _position + const Duration(seconds: 20) ||
        (_retryAfter != null && _position < _retryAfter!)) {
      return;
    }
    final generation = _generation;
    final cancel = _cancel = CancelToken();
    _loading = true;
    unawaited(() async {
      var success = false;
      try {
        final chunk = await fetch(cursor, cancel);
        if (_disposed || generation != _generation) return;
        _next = chunk.blocked ? null : chunk.next;
        final seen = <String>{for (final item in _pending) '${item.progress.inMilliseconds}:${item.id}:${item.text}'};
        for (final item in chunk.messages) {
          if (item.progress < _position - const Duration(seconds: 2)) continue;
          if (seen.add('${item.progress.inMilliseconds}:${item.id}:${item.text}')) _pending.add(item);
          if (_pending.length >= 2000) break;
        }
        _pending.sort((a, b) => a.progress.compareTo(b.progress));
        if (_running) _deliver();
        success = true;
      } on Object {
        if (!_disposed && generation == _generation) _retryAfter = _position + const Duration(seconds: 10);
      } finally {
        if (!_disposed && generation == _generation) {
          _loading = false;
          if (success) _prefetch();
        }
      }
    }());
  }

  /// Releases pending network work; late completions can never emit.
  void dispose() {
    _disposed = true;
    _generation++;
    _cancel?.cancel();
    _pending.clear();
  }
}
