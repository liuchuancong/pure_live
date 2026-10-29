import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:media_core_danmaku/media_core_danmaku.dart' show DanmakuColor, DanmakuPlacement;

import 'package:pure_live/shared/danmaku/danmaku_entry.dart';

/// The Bilibili danmaku JSON — the shape its own clients keep a segment in,
/// and the easiest one for other tools to read back.
///
/// A file is `{"code":0,"data":[{...}]}`; each row carries `progress` in
/// milliseconds, `mode`, `fontsize`, `color` as a packed integer, `content`
/// and `midHash`. A bare array of rows is accepted too, as is a `time` in
/// seconds in place of `progress`.
abstract final class BilibiliDanmakuJson {
  /// Reads [source] into timeline entries.
  static List<DanmakuEntry> decode(String source) {
    final Object? root;
    try {
      root = jsonDecode(source);
    } on FormatException {
      return const [];
    }
    final rows = root is Map ? root['data'] : root;
    if (rows is! List) return const [];
    final entries = <DanmakuEntry>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final text = '${row['content'] ?? row['text'] ?? ''}'.trim();
      if (text.isEmpty) continue;
      final progress = _number(row['progress']);
      final seconds = progress == null ? _number(row['time']) : progress / 1000;
      if (seconds == null || seconds < 0) continue;
      final mode = _number(row['mode'])?.round() ?? 1;
      entries.add(
        DanmakuEntry(
          time: Duration(milliseconds: (seconds * 1000).round()),
          text: text,
          color: DanmakuColor.fromInt(_number(row['color'])?.round() ?? 0xFFFFFF),
          placement: switch (mode) {
            4 => DanmakuPlacement.bottom,
            5 => DanmakuPlacement.top,
            _ => DanmakuPlacement.scroll,
          },
          fontSize: _number(row['fontsize'])?.round() ?? 25,
          user: '${row['midHash'] ?? row['user'] ?? ''}',
          id: '${row['id'] ?? ''}',
        ),
      );
    }
    return entries;
  }

  /// Writes [entries] as the segment JSON.
  static String encode(Iterable<DanmakuEntry> entries) => jsonEncode({
    'code': 0,
    'data': [
      for (final entry in entries)
        if (!entry.isEmpty)
          {
            'id': _intOf(entry.id),
            'progress': entry.time.inMilliseconds,
            'mode': switch (entry.placement) {
              DanmakuPlacement.bottom => 4,
              DanmakuPlacement.top => 5,
              DanmakuPlacement.scroll => 1,
            },
            'fontsize': entry.fontSize,
            'color': entry.color.toInt(),
            'midHash': entry.user,
            'content': entry.text,
            'ctime': 0,
            'weight': 0,
          },
    ],
  });

  static num? _number(Object? value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value.trim());
    return null;
  }

  static int _intOf(String value) => int.tryParse(value) ?? 0;
}
