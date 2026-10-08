// Module: lib/src/paths.dart
// Purpose: The directory policy seam, an atomic text writer and extension-to-MIME mapping.
// Author: liuchuancong
// Created: 2026-10-08
//
// Directory lookup needs a platform plugin, which is Flutter-side, so this package declares the policy
// instead of implementing it: the app binds DirectoryPolicy to path_provider, and everything above stays
// testable and free of an upward dependency.

import 'dart:io';

/// Where the application keeps its files. Implemented by the composition root.
abstract interface class DirectoryPolicy {
  /// Persistent user data: settings, databases, downloaded playlists.
  Future<String> dataDirectory();

  /// Evictable storage, safe to clear from the settings screen. [namespace] is a cache namespace name.
  Future<String> cacheDirectory(String namespace);

  /// A directory the user chose or expects, for example recordings.
  Future<String> downloadsDirectory();
}

/// Writes text so a reader never sees a half-written file.
///
/// The write goes to a sibling temp name and is then renamed onto the target, which is atomic within one
/// volume. Writing the target directly is what turns a crash mid-save into a permanently broken setting.
Future<void> writeTextAtomically(File target, String content) async {
  final directory = target.parent;
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  final temp = File('${target.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');
  try {
    await temp.writeAsString(content, flush: true);
    await temp.rename(target.path);
  } catch (error) {
    if (await temp.exists()) {
      await temp.delete();
    }
    rethrow;
  }
}

/// The MIME type for [path] by extension, defaulting to application/octet-stream.
///
/// Only the types this application actually serves are listed; an unknown extension is deliberately not
/// guessed at, because a wrong content type is harder to debug than a generic one.
String mimeTypeFor(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0 || dot == path.length - 1) {
    return 'application/octet-stream';
  }
  return _mimeTypes[path.substring(dot + 1).toLowerCase()] ?? 'application/octet-stream';
}

const Map<String, String> _mimeTypes = <String, String>{
  'json': 'application/json',
  'txt': 'text/plain',
  'm3u': 'audio/x-mpegurl',
  'm3u8': 'application/vnd.apple.mpegurl',
  'mpd': 'application/dash+xml',
  'ts': 'video/mp2t',
  'mp4': 'video/mp4',
  'mkv': 'video/x-matroska',
  'webm': 'video/webm',
  'srt': 'application/x-subrip',
  'ass': 'text/x-ssa',
  'vtt': 'text/vtt',
  'xml': 'application/xml',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'ttf': 'font/ttf',
  'otf': 'font/otf',
  'zip': 'application/zip',
};
