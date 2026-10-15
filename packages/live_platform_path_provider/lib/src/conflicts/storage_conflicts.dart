import 'dart:io';

/// What a data-directory conflict looks like: both the preferred tree (say,
/// the portable `data/` next to the executable) and a legacy tree (say, the
/// OS application directory an earlier installed run wrote to) hold config
/// files, and the app must decide which wins instead of silently reading
/// either.
final class StorageConflictReport {
  /// A report over the two trees.
  const new({
    required this.preferred,
    required this.legacy,
    required this.preferredFiles,
    required this.legacyFiles,
    required this.conflicts,
  });

  /// The directory the current deployment prefers.
  final Directory preferred;

  /// The older directory that also exists.
  final Directory legacy;

  /// File names found at the top level of [preferred].
  final List<String> preferredFiles;

  /// File names found at the top level of [legacy].
  final List<String> legacyFiles;

  /// Names present in both trees — the files a migration must reconcile.
  final List<String> conflicts;

  /// Whether any file exists in both trees.
  bool get hasConflict => conflicts.isNotEmpty;
}

/// Detects the split-brain case: a deployment change (installed to
/// portable, a restored backup, a moved data directory) leaving real config
/// files in two places. Only the top level is compared — databases and
/// caches live in their own packages' stores; this answers "which config
/// set is authoritative" before the app offers a choice or migrates.
abstract final class StorageConflicts {
  /// Compares the top-level files of [preferred] and [legacy].
  ///
  /// A directory that cannot be read (missing, inaccessible) simply
  /// contributes no files — an unreadable side can never conflict.
  static Future<StorageConflictReport> inspect({required Directory preferred, required Directory legacy}) async {
    final preferredFiles = await _topLevelFileNames(preferred);
    final legacyFiles = await _topLevelFileNames(legacy);
    final conflicts = preferredFiles.where(legacyFiles.contains).toList()..sort();
    return StorageConflictReport(
      preferred: preferred,
      legacy: legacy,
      preferredFiles: preferredFiles,
      legacyFiles: legacyFiles,
      conflicts: conflicts,
    );
  }

  static Future<List<String>> _topLevelFileNames(Directory directory) async {
    try {
      final entities = await directory.list().toList();
      return entities.whereType<File>().map((file) => file.uri.pathSegments.last).toList()..sort();
    } on FileSystemException {
      return const [];
    }
  }
}
