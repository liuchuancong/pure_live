import 'dart:io';

import 'package:path/path.dart' as p;

/// The outcome of carrying one directory tree into another.
final class AdoptionReport {
  /// A carry report; [moved] and [blocked] are sorted for stable reports.
  const new({required this.from, required this.to, required this.moved, required this.blocked});

  /// The tree the entries came from.
  final Directory from;

  /// The tree the entries moved into.
  final Directory to;

  /// Top-level entry names now living under [to].
  final List<String> moved;

  /// Names left behind in [from]: the target existed, or the move failed.
  final List<String> blocked;

  /// Whether nothing was left behind.
  bool get isComplete => blocked.isEmpty;
}

/// Carries one directory tree into another: every top-level entry of the
/// source moves under the target — a rename when the volume allows it, a
/// copy-then-delete otherwise — and an entry whose target already exists,
/// or that the filesystem refuses to let go, stays behind and is reported.
///
/// This is the boot-time half of "the user moved the data directory": the
/// previous tree is carried into the one this boot resolved *before* the
/// storage layer opens anything, so the move cannot race an open database
/// file. The semantics are per-entry, never a wholesale refusal: a partially
/// populated target (a probe created it last run, a second instance still
/// holds one box) converges over the next starts instead of sticking.
abstract final class StorageAdoption {
  /// Carries [from] into [to]. Null when [from] does not exist or is [to]
  /// itself — nothing to carry. A [from] that ends up empty is removed, so
  /// an abandoned tree does not linger. Never throws: per-entry failures
  /// land in [AdoptionReport.blocked].
  static Future<AdoptionReport?> carry({required Directory from, required Directory to}) async {
    if (p.equals(from.absolute.path, to.absolute.path) || !from.existsSync()) {
      return null;
    }
    final entries = from.listSync();
    final moved = <String>[];
    final blocked = <String>[];
    try {
      await to.create(recursive: true);
    } on FileSystemException {
      return AdoptionReport(from: from, to: to, moved: const [], blocked: _names(entries));
    }
    for (final entry in entries) {
      final name = p.basename(entry.path);
      final target = p.join(to.path, name);
      if (FileSystemEntity.typeSync(target) != FileSystemEntityType.notFound) {
        blocked.add(name);
        continue;
      }
      if (await _move(entry, target)) {
        moved.add(name);
      } else {
        blocked.add(name);
      }
    }
    _removeIfEmpty(from);
    return AdoptionReport(from: from, to: to, moved: moved..sort(), blocked: blocked..sort());
  }

  static Future<bool> _move(FileSystemEntity entry, String target) async {
    try {
      await entry.rename(target);
      return true;
    } on FileSystemException {
      // A cross-volume move, or a file another process holds: fall back to
      // a copy, which the rename path cannot serve.
    }
    return await _copyRecursive(entry, target) && _delete(entry);
  }

  static Future<bool> _copyRecursive(FileSystemEntity entry, String target) async {
    final type = FileSystemEntity.typeSync(entry.path);
    if (type == FileSystemEntityType.file) {
      try {
        await (entry as File).copy(target);
        return true;
      } on FileSystemException {
        return false;
      }
    }
    if (type != FileSystemEntityType.directory) {
      return false;
    }
    final source = entry as Directory;
    final copy = Directory(target);
    try {
      await copy.create(recursive: true);
      for (final child in source.listSync()) {
        if (!await _copyRecursive(child, p.join(target, p.basename(child.path)))) {
          return false;
        }
      }
      return true;
    } on FileSystemException {
      return false;
    }
  }

  static bool _delete(FileSystemEntity entry) {
    try {
      entry.deleteSync(recursive: true);
      return true;
    } on FileSystemException {
      return false;
    }
  }

  static void _removeIfEmpty(Directory directory) {
    try {
      if (directory.existsSync() && directory.listSync().isEmpty) {
        directory.deleteSync();
      }
    } on FileSystemException {
      // Best effort; a lingering empty tree costs nothing.
    }
  }

  static List<String> _names(List<FileSystemEntity> entries) =>
      entries.map((entry) => p.basename(entry.path)).toList()..sort();
}
