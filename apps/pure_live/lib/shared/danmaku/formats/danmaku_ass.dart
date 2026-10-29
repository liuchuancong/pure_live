import 'package:media_core_danmaku/media_core_danmaku.dart' show DanmakuColor, DanmakuPlacement;

import 'package:pure_live/shared/danmaku/danmaku_entry.dart';

/// The ASS subtitle a desktop player overlays on a video — the format
/// DanmakuFactory and most "danmaku as subtitles" workflows hand out.
///
/// A scrolling line is a `\move` from the picture's right edge to beyond its
/// left edge, one of twelve lanes; a pinned line is a `\pos` anchored to the
/// top or bottom for four seconds. The canvas is the usual 1920×1080, which
/// every player scales to its own window.
abstract final class AssDanmaku {
  /// Writes [entries] as an ASS script. [title] names the script's header.
  static String encode(Iterable<DanmakuEntry> entries, {String title = 'pure_live danmaku'}) {
    final rows = [...entries.where((entry) => !entry.isEmpty)]..sort((a, b) => a.time.compareTo(b.time));
    final buffer = StringBuffer()
      ..writeln('[Script Info]')
      ..writeln('Title: $title')
      ..writeln('ScriptType: v4.00+')
      ..writeln('WrapStyle: 2')
      ..writeln('PlayResX: 1920')
      ..writeln('PlayResY: 1080')
      ..writeln('ScaledBorderAndShadow: yes')
      ..writeln()
      ..writeln('[V4+ Styles]')
      ..writeln(
        [
          'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour',
          'Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline',
          'Shadow, Alignment, MarginL, MarginR, MarginV, Encoding',
        ].join(', '),
      )
      ..writeln(
        [
          'Style: Danmaku,Microsoft YaHei,40,&H00FFFFFF,&H00FFFFFF,&H00000000,&H64000000',
          '0,0,0,0,100,100,0,0,1,2,0,7,0,0,0,1',
        ].join(','),
      )
      ..writeln()
      ..writeln('[Events]')
      ..writeln('Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text');
    final scrollFree = List<double>.filled(_scrollLanes, -1000000000);
    final topFree = List<double>.filled(_fixedLanes, -1000000000);
    final bottomFree = List<double>.filled(_fixedLanes, -1000000000);
    for (final entry in rows) {
      final start = entry.seconds;
      final size = (entry.fontSize * 1.4).clamp(18.0, 64.0);
      final width = _width(entry.text, size);
      final color = '{\\c${_assColor(entry.color)}}';
      final second = switch (entry.placement) {
        DanmakuPlacement.scroll => start + _scrollSeconds,
        DanmakuPlacement.top || DanmakuPlacement.bottom => start + _fixedSeconds,
      };
      final text = _escape(entry.text);
      final String line;
      switch (entry.placement) {
        case DanmakuPlacement.scroll:
          final lane = _lane(scrollFree, start, _scrollSeconds / 4);
          final y = _laneY(lane, _scrollLanes);
          line = '$color{\\move(1920,$y,-$width,$y)}';
        case DanmakuPlacement.top:
          final lane = _lane(topFree, start, _fixedSeconds + _fixedSeconds / 2);
          line = '{\\an8}$color{\\pos(960,${_laneY(lane, _fixedLanes)})}';
        case DanmakuPlacement.bottom:
          final lane = _lane(bottomFree, start, _fixedSeconds + _fixedSeconds / 2);
          line = '{\\an2}$color{\\pos(960,${1080 - _laneY(lane, _fixedLanes)})}';
      }
      buffer.writeln('Dialogue: 0,${_time(start)},${_time(second)},Danmaku,,0,0,0,,$line$text');
    }
    return buffer.toString();
  }

  static const int _scrollLanes = 12;
  static const int _fixedLanes = 5;
  static const double _scrollSeconds = 12;
  static const double _fixedSeconds = 4;

  /// The first lane that is free at [start], else the one that frees first.
  static int _lane(List<double> free, double start, double headway) {
    var best = 0;
    for (var index = 0; index < free.length; index++) {
      if (free[index] <= start) {
        best = index;
        break;
      }
      if (free[index] < free[best]) best = index;
    }
    free[best] = start + headway;
    return best;
  }

  static double _laneY(int lane, int lanes) => 20 + (lane + 0.5) * (1080 - 120) / lanes;

  /// An estimated advance width: a CJK glyph is a full em, other glyphs a
  /// little over half. Exact metrics need the font, which a file writer does
  /// not have.
  static double _width(String text, double size) {
    var units = 0.0;
    for (final rune in text.runes) {
      units += rune >= 0x2E80 ? 1 : 0.55;
    }
    return units * size;
  }

  static String _assColor(DanmakuColor color) {
    String hex(int value) => value.toRadixString(16).padLeft(2, '0').toUpperCase();
    return '&H${hex(color.b)}${hex(color.g)}${hex(color.r)}&';
  }

  static String _time(double seconds) {
    final total = seconds < 0 ? 0 : (seconds * 100).round();
    final centis = total % 100;
    final whole = total ~/ 100;
    final minutes = (whole ~/ 60) % 60;
    final hours = whole ~/ 3600;
    final secs = whole % 60;
    return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}'
        '.${centis.toString().padLeft(2, '0')}';
  }

  /// ASS has no escape for braces or newlines; both would be read as markup.
  static String _escape(String text) => text
      .replaceAll('\r\n', ' ')
      .replaceAll('\n', ' ')
      .replaceAll('\r', ' ')
      .replaceAll('{', '｛')
      .replaceAll('}', '｝');
}
