import 'package:pure_live/shared/danmaku/danmaku_entry.dart';

/// The plain-text danmaku a human reads in an editor: one line per message,
/// prefixed with its time as `[mm:ss.cc]`.
abstract final class TextDanmaku {
  /// Writes [entries] as `[mm:ss.cc]text` lines.
  static String encode(Iterable<DanmakuEntry> entries) {
    final rows = [...entries.where((entry) => !entry.isEmpty)]..sort((a, b) => a.time.compareTo(b.time));
    final buffer = StringBuffer();
    for (final entry in rows) {
      buffer.write(line(entry));
    }
    return buffer.toString();
  }

  /// One `[mm:ss.cc]text` line, as a recording appends them.
  static String line(DanmakuEntry entry) =>
      '[${_time(entry.time)}]${entry.text.replaceAll(RegExp(r'[\r\n]+'), ' ').trim()}\n';

  /// Reads `[mm:ss]` or `[mm:ss.cc]` (and an optional hour field) lines back;
  /// a line without a readable time prefix is skipped.
  static List<DanmakuEntry> decode(String source) {
    final entries = <DanmakuEntry>[];
    final pattern = RegExp(r'^\s*\[(?:(\d+):)?(\d+):(\d+(?:[.,]\d+)?)\]\s*(.*)$');
    for (final line in source.split('\n')) {
      final match = pattern.firstMatch(line);
      if (match == null) continue;
      final text = match.group(4)!.trim();
      if (text.isEmpty) continue;
      final hours = int.tryParse(match.group(1) ?? '') ?? 0;
      final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
      final seconds = double.tryParse((match.group(3) ?? '').replaceAll(',', '.')) ?? 0;
      final millis = ((hours * 3600 + minutes * 60 + seconds) * 1000).round();
      entries.add(
        DanmakuEntry(
          time: Duration(milliseconds: millis),
          text: text,
        ),
      );
    }
    return entries;
  }

  static String _time(Duration value) {
    final millis = value.inMilliseconds < 0 ? 0 : value.inMilliseconds;
    final minutes = millis ~/ 60000;
    final seconds = (millis ~/ 1000) % 60;
    final centis = (millis % 1000) ~/ 10;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
        '.${centis.toString().padLeft(2, '0')}';
  }
}
