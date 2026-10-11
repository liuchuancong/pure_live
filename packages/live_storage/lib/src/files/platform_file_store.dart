import 'dart:convert';
import 'dart:io';

import 'package:live_platform/live_platform.dart' show AtomicFileWriter, StorageArea, StorageManager;
import 'package:live_storage/src/contracts/file_store.dart';
import 'package:live_storage/src/contracts/storage_exception.dart';
import 'package:path/path.dart' as p;

/// [FileStore] over the live_platform directory service.
///
/// Every operation names a [StorageArea]; the directory comes from the
/// injected StorageManager (resolved once, then memoised), so business
/// modules never splice paths. Text and byte writes go through
/// [AtomicFileWriter] — temp file, flush, rename — so a crash mid-write
/// never leaves a truncated file where the caller expects content.
///
/// All failures surface as typed [StorageException]s: validation before
/// touching the disk (single-segment names, no traversal), permission,
/// disk-full and missing-entry cases mapped from `FileSystemException`
/// here, once, so callers pattern-match categories instead of parsing
/// OS messages.
final class PlatformFileStore implements FileStore {
  /// A file store resolving areas through [storage].
  new(this.storage);

  /// The directory authority (probed candidates, honest access states).
  final StorageManager storage;

  @override
  Future<Directory> directoryFor(StorageArea area) => _directory(area);

  @override
  Future<File> writeText(StorageArea area, String name, String contents) =>
      writeBytes(area, name, utf8.encode(contents));

  @override
  Future<File> writeBytes(StorageArea area, String name, List<int> bytes) async {
    final file = await _fileFor(area, name);
    try {
      return await AtomicFileWriter.writeBytes(file, bytes);
    } on StorageOperationException catch (error) {
      throw _mapOperation(error);
    }
  }

  @override
  Future<String?> readText(StorageArea area, String name) async {
    final bytes = await readBytes(area, name);
    if (bytes == null) {
      return null;
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  @override
  Future<List<int>?> readBytes(StorageArea area, String name) async {
    final file = await _fileFor(area, name);
    if (!file.existsSync()) {
      return null;
    }
    try {
      return await file.readAsBytes();
    } on FileSystemException catch (error) {
      throw _mapFileSystem(error, 'read ${file.path}');
    }
  }

  @override
  Future<bool> exists(StorageArea area, String name) async {
    final file = await _fileFor(area, name);
    return file.existsSync();
  }

  @override
  Future<void> delete(StorageArea area, String name) async {
    final file = await _fileFor(area, name);
    try {
      if (file.existsSync()) {
        file.deleteSync();
      }
    } on FileSystemException catch (error) {
      throw _mapFileSystem(error, 'delete ${file.path}');
    }
  }

  Future<Directory> _directory(StorageArea area) async {
    final location = await storage.resolve(area);
    return Directory(location.path);
  }

  /// Resolves the target file, refusing anything that could leave the
  /// area directory: separators, `..` segments, absolute names.
  Future<File> _fileFor(StorageArea area, String name) async {
    if (name.isEmpty) {
      throw const StorageValidationException('file name must not be empty');
    }
    if (name.contains('/') || name.contains(r'\') || name == '..' || p.isAbsolute(name)) {
      throw StorageValidationException('file name must be a single path segment: "$name"');
    }
    final directory = await _directory(area);
    final file = File(p.join(directory.path, name));
    final areaPath = p.normalize(directory.path);
    if (!p.isWithin(areaPath, file.path)) {
      throw StorageValidationException('file name escapes the ${area.name} directory: "$name"');
    }
    return file;
  }

  StorageException _mapOperation(StorageOperationException error) {
    final cause = error.cause;
    final description = cause.toString().toLowerCase();
    if (description.contains('full') || description.contains('space')) {
      return StorageDiskFullException(error.message, cause: cause);
    }
    if (description.contains('access is denied') || description.contains('permission')) {
      return StoragePermissionException(error.message, cause: cause);
    }
    return StorageOperationException(error.message, cause: cause);
  }

  StorageException _mapFileSystem(FileSystemException error, String action) {
    final code = error.osError?.errorCode;
    if (code == 2 || code == 3) {
      return StorageNotFoundException('$action: not found', cause: error);
    }
    if (code == 5 || code == 13) {
      return StoragePermissionException('$action: access denied', cause: error);
    }
    if (code == 28) {
      return StorageDiskFullException('$action: disk full', cause: error);
    }
    return StorageOperationException('$action failed: ${error.message}', cause: error);
  }
}
