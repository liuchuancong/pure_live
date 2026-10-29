import 'dart:io' show File;

import 'package:path/path.dart' as p;

import 'package:pure_live/shared/danmaku/danmaku_entry.dart';
import 'package:pure_live/shared/danmaku/danmaku_format.dart';

/// The danmaku sidecar for [video] in [format]: the video's own path with the
/// format's extension, beside it.
File danmakuFileFor(File video, DanmakuFormat format) => File('${p.withoutExtension(video.path)}.${format.extension}');

/// Writes [entries] beside [video] in every one of [formats], each file named
/// after the video.
///
/// The entries are filtered once and encoded per format; a caller that only
/// wants one sidecar passes one format.
Future<List<File>> writeDanmakuFiles(
  File video,
  Iterable<DanmakuEntry> entries,
  Iterable<DanmakuFormat> formats,
) async {
  final lines = [...entries.where((entry) => !entry.isEmpty)]..sort((a, b) => a.time.compareTo(b.time));
  final written = <File>[];
  for (final format in formats) {
    final file = danmakuFileFor(video, format);
    await file.writeAsString(format.encode(lines), flush: true);
    written.add(file);
  }
  return written;
}
