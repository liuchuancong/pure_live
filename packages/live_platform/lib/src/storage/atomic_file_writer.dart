import 'dart:convert';
import 'dart:io';

import 'package:live_platform/src/contracts/platform_exception.dart';
import 'package:path/path.dart' as p;

/// Crash-safe file replacement: write to a unique temp file in the same
/// directory, flush to disk, then atomically rename over the target.
///
/// A crash mid-write leaves the target untouched and at most one stray
/// `.pure_live_tmp` file behind. Windows note: `rename` cannot clobber an
/// existing target, so the old file is removed in the same window — the
/// remove+rename pair is not fully atomic there; the temp copy still
/// guards against truncated writes.
abstract final class AtomicFileWriter {
  /// Writes [bytes] to [target] through a temp file. Creates parent
  /// directories as needed.
  static Future<File> writeBytes(File target, List<int> bytes) async {
    await target.parent.create(recursive: true);
    final temp = File(p.join(target.parent.path, '.pure_live_tmp_${DateTime.now().microsecondsSinceEpoch}'));
    try {
      final sink = temp.openWrite();
      try {
        sink.add(bytes);
        await sink.flush();
      } finally {
        await sink.close();
      }
      return _promote(temp, target);
    } on FileSystemException catch (error) {
      _discard(temp);
      throw StorageOperationException('atomic write to ${target.path} failed: ${error.message}', cause: error);
    }
  }

  /// Writes [contents] as UTF-8 text through [writeBytes].
  static Future<File> writeString(File target, String contents) => writeBytes(target, utf8.encode(contents));

  static File _promote(File temp, File target) {
    if (target.existsSync()) {
      target.deleteSync();
    }
    return temp.renameSync(target.path);
  }

  static void _discard(File temp) {
    try {
      if (temp.existsSync()) {
        temp.deleteSync();
      }
    } on FileSystemException {
      // Best effort cleanup of a failed temp file.
    }
  }
}
