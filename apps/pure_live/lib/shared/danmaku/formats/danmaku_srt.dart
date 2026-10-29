import 'package:pure_live/shared/danmaku/danmaku_entry.dart';

/// The SRT subtitles a video player or an editor can open: one cue per
/// danmaku line, four seconds long, in timeline order.
///
/// SRT has no color, size or placement, so those are dropped rather than
/// approximated — a file that renders everywhere is worth more than one that
/// only one player understands.
abstract final class SrtDanmaku {
  /// Writes [entries] as an SRT file.
  static String encode(Iterable<DanmakuEntry> entries) {
    final rows = [...entries.where((entry) => !entry.isEmpty)]..sort((a, b) => a.time.compareTo(b.time));
    final buffer = StringBuffer();
    var index = 1;
    for (final entry in rows) {
      buffer.write(cue(entry, index++));
    }
    return buffer.toString();
  }

  /// One cue numbered [index], four seconds long; a recording appends these.
  static String cue(DanmakuEntry entry, int index) {
    final start = entry.time;
    final end = start + const Duration(seconds: 4);
    final text = entry.text.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    return '$index\n${time(start)} --> ${time(end)}\n$text\n\n';
  }

  /// One SRT timestamp.
  static String time(Duration value) {
    final millis = value.inMilliseconds < 0 ? 0 : value.inMilliseconds;
    final hours = millis ~/ 3600000;
    final minutes = (millis ~/ 60000) % 60;
    final seconds = (millis ~/ 1000) % 60;
    final rest = millis % 1000;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')},${rest.toString().padLeft(3, '0')}';
  }
}
