import 'dart:convert';
import 'dart:io';

import 'package:live_platform_path_provider/src/contracts/platform_exception.dart';
import 'package:path/path.dart' as p;

/// Crash-safe file replacement: write to a unique temp file in the same
/// directory, flush, then atomically rename over the target. The flush
/// reaches the operating system, so an application crash cannot truncate
/// the target; a power loss before the OS writes through still can.
///
/// A crash mid-write leaves the target untouched and at most one stray
/// `.pure_tmp` file behind. Windows note: `rename` cannot clobber an
/// existing target, so the old file is removed in the same window — the
/// remove+rename pair is not fully atomic there; the temp copy still
/// guards against truncated writes.
abstract final class AtomicFileWriter {
  /// Per-process counter making each temp path unique. A timestamp alone is not:
  /// two writes into the same directory inside one microsecond claimed the same
  /// temp file, which either failed the second rename outright or — worse, and
  /// silently — promoted one file holding interleaved bytes of two payloads.
  static int _sequence = 0;

  /// Writes [bytes] to [target] through a temp file. Creates parent
  /// directories as needed.
  static Future<File> writeBytes(File target, List<int> bytes) async {
    // The whole operation is inside the try, including the directory creation: the
    // package contract is that callers match on `PlatformException`, and a raw
    // `PathExistsException` from `create` used to escape past the handler below
    // whenever a parent segment was already occupied by a file.
    File? temp;
    try {
      await target.parent.create(recursive: true);
      // The target name is kept in the temp name so an orphan left by a crash
      // identifies the file it was writing.
      temp = File(p.join(target.parent.path, '.file_tmp_${pid}_${++_sequence}_${p.basename(target.path)}'));
      final sink = temp.openWrite();
      try {
        sink.add(bytes);
        await sink.flush();
      } finally {
        await sink.close();
      }
      return _promote(temp, target);
    } on FileSystemException catch (error) {
      final partial = temp;
      if (partial != null) {
        _discard(partial);
      }
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
