import 'dart:io' show Directory, File;

import 'package:path/path.dart' as p;

/// The file a download writes: the archive's name, the part's name when it
/// has more than one, and the container the source served.
String vodDownloadFileName({
  required String title,
  required String part,
  int index = 1,
  int parts = 1,
  String extension = 'mp4',
}) {
  // Trim the pieces, never the line: cutting the whole name at some limit
  // would drop the `P<index>` marker at its tail and let two parts of one
  // archive collide under the same dodged `_2` name. The ceiling matches the
  // music downloader's own 120-character trim (`sanitizeFileName`), because a
  // name is one component of a path the viewer may have parked under a deep
  // custom folder — Windows stops a whole path near 260 characters.
  String clip(String value, int max) => value.length <= max ? value : value.substring(0, max).trim();
  final raw = parts > 1 ? '${clip(title, 80)} - P$index ${clip(part, 30)}' : clip(title, 120);
  final clean = raw.replaceAll(RegExp(r'[\\/:*?"<>|\r\n\t]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  final name = clean.isEmpty ? 'bilibili_$index' : clean;
  return '$name.$extension';
}

/// A file named [name] in [folder] that does not exist yet, adding `_2`,
/// `_3` … when the name is taken.
File freeDownloadFile(Directory folder, String name) {
  final base = p.basenameWithoutExtension(name);
  final extension = p.extension(name);
  var file = File(p.join(folder.path, name));
  for (var index = 2; file.existsSync(); index++) {
    file = File(p.join(folder.path, '${base}_$index$extension'));
  }
  return file;
}
