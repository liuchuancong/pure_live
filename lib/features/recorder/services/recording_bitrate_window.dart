import 'dart:collection';

/// Output bitrate from file growth over a short sliding window.
///
/// FFmpeg's own statistic divides the output size by the source timestamp,
/// which for live inputs can run far ahead of wall time and made the recorder
/// show about a seventh of the real rate. One-second growth deltas are exact
/// but jump with the muxer's bursty writes, so average the last few seconds.
class RecordingBitrateWindow {
  RecordingBitrateWindow({this.span = const Duration(seconds: 5)});

  final Duration span;
  final Queue<({int bytes, DateTime at})> _samples = Queue();

  /// Records a sample and returns kbit/s, or null until two samples span time.
  double? add(int bytes, DateTime at) {
    if (_samples.isNotEmpty && bytes < _samples.last.bytes) _samples.clear();
    _samples.addLast((bytes: bytes, at: at));
    while (_samples.length > 2 && at.difference(_samples.elementAt(1).at) >= span) {
      _samples.removeFirst();
    }
    final first = _samples.first;
    final elapsedMs = at.difference(first.at).inMilliseconds;
    if (elapsedMs <= 0 || bytes <= first.bytes) return null;
    return (bytes - first.bytes) * 8 / elapsedMs;
  }
}
