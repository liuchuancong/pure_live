import 'dart:io';

import 'package:path/path.dart' as p;

/// The recording folder's own size answers — the reference's
/// `refreshStorageInfo` and cache-limit pruning.
///
/// Pruning deletes the oldest finished recordings, by the media files' own
/// modification time, until the folder is back under the cap. A file written
/// within the last hour is never a deletion candidate: a recording that is
/// merging right now is the newest thing in the folder, and a cap that eats
/// the session being captured is a cap that loses data rather than space.
abstract final class RecordStorage {
  /// Bytes used by every regular file under [root]; a folder that does not
  /// exist yet is empty, and an entry that cannot be read is skipped rather
  /// than failing the whole measure.
  static Future<int> usedBytes(String root) async {
    final directory = Directory(root);
    if (!directory.existsSync()) {
      return 0;
    }
    var total = 0;
    await for (final entry in directory.list(recursive: true, followLinks: false)) {
      if (entry is! File) {
        continue;
      }
      try {
        total += await entry.length();
      } on Object {
        // A file that vanished mid-count is counted as nothing.
      }
    }
    return total;
  }

  /// The merged/published media files under [root], oldest modification
  /// first — the order the cap prunes in.
  static List<File> _finishedRecordings(String root) {
    final directory = Directory(root);
    if (!directory.existsSync()) {
      return const <File>[];
    }
    final files = directory
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((file) => const ['.mp4', '.mkv', '.ts'].contains(p.extension(file.path).toLowerCase()))
        .toList(growable: false)
      ..sort((left, right) {
        DateTime at(File file) {
          try {
            return file.statSync().modified;
          } on Object {
            return DateTime(2100);
          }
        }

        return at(left).compareTo(at(right));
      });
    return files;
  }

  /// Deletes the oldest finished recordings under [root] until the folder
  /// holds no more than [maxMB]; returns the bytes freed.
  ///
  /// Files written after [protectBefore] stay whatever their size — the
  /// ongoing session's segments share the newest timestamps, and the prune
  /// that ends a live recording is never the right answer to a full disk.
  static Future<int> pruneToLimit({required String root, required int maxMB, DateTime? protectBefore}) async {
    final capBytes = maxMB * 1024 * 1024;
    final protect = protectBefore ?? DateTime.now().subtract(const Duration(hours: 1));
    var used = await usedBytes(root);
    if (used <= capBytes) {
      return 0;
    }
    var freed = 0;
    for (final file in _finishedRecordings(root)) {
      if (used <= capBytes) {
        break;
      }
      final DateTime modified;
      try {
        modified = file.statSync().modified;
      } on Object {
        continue;
      }
      if (modified.isAfter(protect)) {
        // The rest is newer still; the loop has reached the protected tail.
        break;
      }
      try {
        final length = file.lengthSync();
        await file.delete();
        freed += length;
        used -= length;
      } on Object {
        // A file that refuses to go (open elsewhere, permissions) is left
        // and the next one takes its place.
      }
    }
    return freed;
  }

  /// Deletes every recording file under [root] — the settings page's "清空
  /// 全部缓存", newest protection the same as the prune's.
  static Future<int> clearAll({required String root, DateTime? protectBefore}) async {
    final protect = protectBefore ?? DateTime.now().subtract(const Duration(hours: 1));
    var freed = 0;
    for (final file in _finishedRecordings(root)) {
      try {
        if (file.statSync().modified.isAfter(protect)) {
          continue;
        }
        freed += file.lengthSync();
        await file.delete();
      } on Object {
        continue;
      }
    }
    return freed;
  }
}
