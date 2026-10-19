import 'dart:io';

import 'package:archive/archive.dart' as zip;
import 'package:path/path.dart' as p;

/// The subtrees of the data area that never enter a backup: logs are
/// diagnostics, fonts are re-downloadable.
const Set<String> _excludedTrees = {'logs', 'fonts'};

/// One backup in the backups tree — a full zip of the data area or a
/// follows-only JSON document (the reference's two file kinds).
final class BackupEntry {
  /// A backup entry.
  const new({
    required this.file,
    required this.name,
    required this.modified,
    required this.size,
    this.followsOnly = false,
  });

  /// The archive file.
  final File file;

  /// The display name (the file name without the extension).
  final String name;

  /// The last-modified time.
  final DateTime modified;

  /// The size in bytes.
  final int size;

  /// Whether this is a follows-only backup (the `-follows-` name the
  /// document writer stamps).
  final bool followsOnly;

  /// The file's size in bytes.
  int get sizeBytes => file.lengthSync();
}

/// The size in the file list's words — KB under a meg, MB above (the
/// reference's `formatFileSize`).
String formatBackupSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Creates a timestamped backup of [dataDir] in [backupsDir] and returns
/// it. Only the data area's top-level files and its non-excluded subtrees
/// enter the archive.
File createBackup({required Directory dataDir, required Directory backupsDir}) {
  if (!dataDir.existsSync()) {
    throw StateError('data area does not exist');
  }
  final stamp = DateTime.now().toLocal();
  final name =
      'pure_live-backup-${stamp.year}${_two(stamp.month)}${_two(stamp.day)}-${_two(stamp.hour)}${_two(stamp.minute)}${_two(stamp.second)}.zip';
  final archive = zip.Archive();
  _addTree(archive, dataDir, dataDir, _excludedTrees);
  final bytes = zip.ZipEncoder().encode(archive);
  backupsDir.createSync(recursive: true);
  return File(p.join(backupsDir.path, name))..writeAsBytesSync(bytes, flush: true);
}

/// Lists the backups in [backupsDir], newest first: the zips and the
/// follows-only JSON documents the page writes.
List<BackupEntry> listBackups(Directory backupsDir) {
  if (!backupsDir.existsSync()) {
    return const [];
  }
  final entries = [
    for (final entity in backupsDir.listSync())
      if (entity is File &&
          (entity.path.toLowerCase().endsWith('.zip') || entity.path.toLowerCase().endsWith('.json')))
        BackupEntry(
          file: entity,
          name: p.basenameWithoutExtension(entity.path),
          modified: entity.statSync().modified,
          size: entity.lengthSync(),
          followsOnly: entity.path.toLowerCase().endsWith('.json') && p.basename(entity.path).contains('-follows-'),
        ),
  ]..sort((a, b) => b.modified.compareTo(a.modified));
  return entries;
}

/// Restores [backup] into [dataDir], overwriting the files the archive
/// carries. The storage layer must be closed before this runs.
void restoreBackup({required File backup, required Directory dataDir}) {
  final bytes = backup.readAsBytesSync();
  final archive = zip.ZipDecoder().decodeBytes(bytes);
  for (final file in archive) {
    if (file.isFile) {
      final target = File(p.join(dataDir.path, file.name));
      target.parent.createSync(recursive: true);
      target.writeAsBytesSync(file.content as List<int>, flush: true);
    }
  }
}

/// Deletes the backup file the [entry] wraps.
void deleteBackup(BackupEntry entry) => entry.file.deleteSync();

void _addTree(zip.Archive archive, Directory dir, Directory root, Set<String> excludedTrees) {
  for (final entity in dir.listSync()) {
    final relative = p.relative(entity.path, from: root.path).replaceAll(r'\', '/');
    final topTree = relative.split('/').first;
    if (excludedTrees.contains(topTree)) {
      continue;
    }
    if (entity is File) {
      archive.addFile(zip.ArchiveFile(relative, entity.lengthSync(), entity.readAsBytesSync()));
    } else if (entity is Directory) {
      _addTree(archive, entity, root, excludedTrees);
    }
  }
}

String _two(int value) => value.toString().padLeft(2, '0');
