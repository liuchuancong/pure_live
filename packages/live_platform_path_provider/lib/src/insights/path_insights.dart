import 'dart:io';

/// Cheap, synchronous answers about a path's existence and shape, for
/// planning a write or a download before touching anything: does it exist,
/// is it a directory, is it a file, how big is it. Single metadata probes
/// only — anything that writes goes through the storage manager or the
/// atomic writer.
abstract final class PathInsights {
  /// Whether [path] exists as a file or a directory.
  static bool exists(String path) => FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;

  /// Whether [path] exists and is a directory.
  static bool isDirectory(String path) => FileSystemEntity.typeSync(path) == FileSystemEntityType.directory;

  /// Whether [path] exists and is a regular file.
  static bool isFile(String path) => FileSystemEntity.typeSync(path) == FileSystemEntityType.file;

  /// The size of the file at [path] in bytes, or null when it is not a
  /// readable file.
  static int? fileSize(String path) {
    if (!isFile(path)) {
      return null;
    }
    try {
      return File(path).lengthSync();
    } on FileSystemException {
      return null;
    }
  }
}
