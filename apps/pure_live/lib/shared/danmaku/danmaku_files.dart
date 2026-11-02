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

/// Removes every danmaku sidecar [video]'s name owns.
///
/// The writer names each file after the video, so the delete walks the same
/// rule rather than a caller's guess: a download's file going away without its
/// `.xml`/`.ass`/`.srt` beside it leaves a subtitle for a video that is gone,
/// and nothing in the queue can point at it to clean it up.
Future<void> deleteDanmakuSidecars(File video) async {
  for (final format in DanmakuFormat.values) {
    final file = danmakuFileFor(video, format);
    try {
      if (file.existsSync()) await file.delete();
    } on Object {
      // A sidecar that will not go is not a reason to fail the delete.
    }
  }
}
