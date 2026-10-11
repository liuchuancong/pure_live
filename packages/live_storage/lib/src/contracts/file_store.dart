import 'dart:io';

import 'package:live_platform/live_platform.dart';

/// Typed file access over the platform directory service.
///
/// Every operation names a [StorageArea]; the directory comes from the
/// injected StorageManager, so business modules never splice paths.
/// Names are single path segments — the implementation rejects anything
/// that smells like traversal (`..`, separators, absolute paths) before
/// it can escape the area directory.
abstract interface class FileStore {
  /// The resolved, probed directory for [area].
  Future<Directory> directoryFor(StorageArea area);

  /// Atomically writes [contents] as UTF-8 text to [name] inside
  /// [area]; the file either appears complete or not at all.
  Future<File> writeText(StorageArea area, String name, String contents);

  /// Atomically writes [bytes] to [name] inside [area].
  Future<File> writeBytes(StorageArea area, String name, List<int> bytes);

  /// Reads [name] as UTF-8 text, or null when absent.
  Future<String?> readText(StorageArea area, String name);

  /// Reads [name] as bytes, or null when absent.
  Future<List<int>?> readBytes(StorageArea area, String name);

  /// Whether [name] exists inside [area].
  Future<bool> exists(StorageArea area, String name);

  /// Deletes [name]; a no-op when absent.
  Future<void> delete(StorageArea area, String name);
}
