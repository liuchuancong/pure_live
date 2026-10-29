import 'package:media_core_danmaku/media_core_danmaku.dart' show DanmakuColor, DanmakuPlacement;

import 'package:pure_live/shared/danmaku/danmaku_entry.dart';

/// The Bilibili danmaku XML — the format this app writes for live recordings
/// and the one a video's danmaku is served in.
///
/// One line is `<d p="time,mode,size,color,unix,pool,user,row">text</d>`;
/// `mode` 4 pins to the bottom, 5 to the top, and everything else scrolls.
/// Mode 8 (a scripted line) and empty text are dropped on read: neither can
/// be shown as text.
abstract final class BilibiliDanmakuXml {
  /// Reads the XML [source] into timeline entries, in file order.
  static List<DanmakuEntry> decode(String source) {
    final entries = <DanmakuEntry>[];
    final pattern = RegExp(r'<d\s+p="([^"]*)"([^>]*)>(.*?)</d>', dotAll: true);
    for (final match in pattern.allMatches(source)) {
      final fields = match.group(1)!.split(',');
      if (fields.length < 4) continue;
      final seconds = double.tryParse(fields[0]);
      if (seconds == null) continue;
      final mode = int.tryParse(fields[1].trim()) ?? 1;
      if (mode == 8) continue;
      final text = unescape(match.group(3)!).trim();
      if (text.isEmpty) continue;
      final user = RegExp('user="([^"]*)"').firstMatch(match.group(2) ?? '')?.group(1) ?? '';
      entries.add(
        DanmakuEntry(
          time: Duration(milliseconds: (seconds * 1000).round()),
          text: text,
          color: DanmakuColor.fromInt(int.tryParse(fields[3].trim()) ?? 0xFFFFFF),
          placement: switch (mode) {
            4 => DanmakuPlacement.bottom,
            5 => DanmakuPlacement.top,
            _ => DanmakuPlacement.scroll,
          },
          fontSize: int.tryParse(fields[2].trim()) ?? 25,
          user: unescape(user),
        ),
      );
    }
    return entries;
  }

  /// Writes [entries] as the XML a player or DanmakuFactory opens.
  static String encode(Iterable<DanmakuEntry> entries) {
    final buffer = StringBuffer(_header);
    for (final entry in entries) {
      buffer.write(encodeEntry(entry));
    }
    buffer.write(_closing);
    return buffer.toString();
  }

  /// One `<d …>text</d>` line, as a recording appends them; empty text gives
  /// an empty string.
  static String encodeEntry(DanmakuEntry entry) {
    final text = escape(entry.text);
    if (text.isEmpty) return '';
    final mode = switch (entry.placement) {
      DanmakuPlacement.bottom => 4,
      DanmakuPlacement.top => 5,
      DanmakuPlacement.scroll => 1,
    };
    final user = entry.user.isEmpty ? '' : ' user="${escape(entry.user)}"';
    final unix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return '<d p="${entry.seconds.toStringAsFixed(3)},$mode,${entry.fontSize},${entry.color.toInt()},'
        '$unix,0,0,0"$user>$text</d>\n';
  }

  static const String _header = '<?xml version="1.0" encoding="UTF-8"?>\n<i>\n<chatserver>pure_live</chatserver>\n';
  static const String _closing = '</i>\n';

  /// XML-escapes [value] and drops characters XML 1.0 cannot carry.
  static String escape(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final allowed =
          rune == 0x9 ||
          rune == 0xA ||
          rune == 0xD ||
          (rune >= 0x20 && rune <= 0xD7FF) ||
          (rune >= 0xE000 && rune <= 0xFFFD) ||
          rune >= 0x10000;
      if (!allowed) continue;
      buffer.write(switch (rune) {
        0x26 => '&amp;',
        0x3C => '&lt;',
        0x3E => '&gt;',
        0x22 => '&quot;',
        0x27 => '&apos;',
        _ => String.fromCharCode(rune),
      });
    }
    return buffer.toString().trim();
  }

  /// Undoes [escape].
  static String unescape(String value) => value
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&#34;', '"')
      .replaceAll('&amp;', '&');
}
