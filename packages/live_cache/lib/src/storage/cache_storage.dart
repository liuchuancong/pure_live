import 'dart:io';
import 'dart:typed_data';

import 'package:live_cache/src/models/cache_entry.dart';
import 'package:live_cache/src/models/cache_failure.dart';
import 'package:live_cache/src/models/cache_priority.dart';
import 'package:live_cache/src/storage/cache_directory.dart';
import 'package:live_cache/src/storage/cache_file.dart';
import 'package:live_cache/src/storage/cache_index.dart';
import 'package:live_log/live_log.dart' show LiveLog;
import 'package:path/path.dart' as p;

/// The outcome of a cleanup pass.
final class CacheCleanupResult {
  /// Creates a result.
  const new({required this.freedBytes, required this.removedFiles, required this.failedFiles, required this.bytesLeft});

  /// No work done.
  static const CacheCleanupResult empty = CacheCleanupResult(
    freedBytes: 0,
    removedFiles: 0,
    failedFiles: 0,
    bytesLeft: 0,
  );

  /// Bytes this pass released.
  final int freedBytes;

  /// Files this pass deleted.
  final int removedFiles;

  /// Files a lock or a permission refused; the next pass retries.
  final int failedFiles;

  /// Bytes still held after the pass.
  final int bytesLeft;
}

/// The disk half of the cache: the folder, the atomic writer and the index.
///
/// Reads never repair the index eagerly; a missing or corrupt file is
/// dropped and counts as a miss, so a damaged cache can only cost a network
/// fetch.
final class CacheStorage {
  /// Creates storage over [directory].
  new({
    required this.directory,
    required this.index,
    required this.ttlForCategory,
    required this.priorityForCategory,
    required this.maxStaleForCategory,
    this.log,
  });

  /// Where the files and the index live.
  final CacheDirectory directory;

  /// The bookkeeping index.
  final CacheIndex index;

  /// The effective TTL of a category (already multiplied by the viewer's
  /// freshness setting); null for permanent.
  final Duration? Function(String category) ttlForCategory;

  /// A category's cleanup priority.
  final CachePriority Function(String category) priorityForCategory;

  /// A category's stale window.
  final Duration? Function(String category) maxStaleForCategory;

  /// Optional diagnostics target.
  final LiveLog? log;

  /// Prepares the tree, loads the index and sweeps leftover partial writes.
  ///
  /// False means the disk layer is unavailable and the caller keeps memory
  /// and network only.
  Future<bool> initialize() async {
    if (!await directory.ensure()) {
      log?.warning('cache folder unavailable; disk cache disabled');
      return false;
    }
    await index.load();
    if (index.needsRebuild) {
      await index.rebuildFromDisk(ttlForCategory: ttlForCategory, priorityForCategory: priorityForCategory);
    }
    await clearTemporary();
    return true;
  }

  /// Every indexed entry.
  Iterable<CacheEntry> get entries => index.entries;

  /// The indexed byte count. Missing files are corrected on the next cleanup.
  int get totalBytes => index.entries.fold<int>(0, (sum, entry) => sum + entry.size);

  /// The last explicit cleanup, when one ran.
  DateTime? get lastCleanupAt => index.lastCleanupAt;

  /// The indexed entry under [key].
  CacheEntry? entryFor(String key) => index[key];

  /// The bytes behind [entry], or null when the file is missing or no longer
  /// an image. A bad file is removed so the next load fetches it again.
  Future<Uint8List?> read(CacheEntry entry) async {
    final file = directory.imageFile(entry.category, entry.key);
    try {
      if (!await file.exists()) {
        index.remove(entry.key);
        return null;
      }
      final bytes = await file.readAsBytes();
      if (!looksLikeImage(bytes)) {
        log?.warning('cached image is corrupt; dropping', fields: {'category': entry.category});
        await delete(entry.key, category: entry.category);
        return null;
      }
      return bytes;
    } on FileSystemException {
      return null;
    }
  }

  /// Writes [bytes] for [entry] and indexes the result.
  ///
  /// A non-image body is refused before it can reach the folder; a refused
  /// write is a [CacheFailure] the caller may ignore.
  Future<void> write(CacheEntry entry, Uint8List bytes) async {
    if (!looksLikeImage(bytes)) {
      throw const CacheFailure(CacheFailureKind.unsupportedFormat, message: 'body is not an image');
    }
    await writeBytesAtomically(
      target: directory.imageFile(entry.category, entry.key),
      bytes: bytes,
      temporaryDirectory: directory.temporary,
    );
    index.put(entry.copyWith(size: bytes.length));
  }

  /// Records a read at [now].
  void touch(CacheEntry entry, DateTime now) => index.markAccessed(entry.key, now);

  /// Extends [entry]'s TTL after a 304 answer; null keeps it permanent.
  void extend(CacheEntry entry, DateTime? expiresAt) => index.setExpiry(entry, expiresAt);

  /// Deletes one file and its index entry; false when the file was already
  /// gone or could not be removed.
  Future<bool> delete(String key, {String? category}) async {
    final entry = index[key];
    final folder = category ?? entry?.category;
    if (folder == null) {
      return false;
    }
    final file = directory.imageFile(folder, key);
    try {
      if (!await file.exists()) {
        index.remove(key);
        return false;
      }
      await file.delete();
      index.remove(key);
      return true;
    } on FileSystemException {
      // A file the engine is still reading stays indexed; the next pass
      // retries instead of leaving an unaccounted orphan behind.
      return false;
    }
  }

  /// Marks [key] expired without deleting the bytes.
  void invalidate(String key, DateTime now) {
    final entry = index[key];
    if (entry != null) {
      index.setExpiry(entry, now);
    }
  }

  /// Marks every entry of [category] expired without deleting the bytes.
  void invalidateByCategory(String category, DateTime now) {
    for (final entry in index.entries.where((entry) => entry.category == category).toList()) {
      index.setExpiry(entry, now);
    }
  }

  /// Removes entries that are expired *and* past their stale window.
  ///
  /// This is what automatic cleanup may delete without hurting a stale-while-
  /// revalidate draw; [clearExpired] is the viewer's explicit wider sweep.
  Future<CacheCleanupResult> clearDead(DateTime now) async {
    var freed = 0;
    var removed = 0;
    var failed = 0;
    final dead = index.entries
        .where((entry) => entry.isExpiredAt(now) && !entry.isUsableWhenStale(now, maxStaleForCategory(entry.category)))
        .toList();
    for (final entry in dead) {
      final size = entry.size;
      if (await delete(entry.key, category: entry.category)) {
        freed += size;
        removed++;
      } else {
        failed++;
      }
    }
    if (dead.isNotEmpty) {
      index.setLastCleanupAt(now);
      await index.flush();
    }
    return CacheCleanupResult(freedBytes: freed, removedFiles: removed, failedFiles: failed, bytesLeft: totalBytes);
  }

  /// Removes entries whose TTL has passed.
  Future<CacheCleanupResult> clearExpired(DateTime now) async {
    var freed = 0;
    var removed = 0;
    var failed = 0;
    final expired = index.entries.where((entry) => entry.isExpiredAt(now)).toList();
    for (final entry in expired) {
      final size = entry.size;
      if (await delete(entry.key, category: entry.category)) {
        freed += size;
        removed++;
      } else {
        failed++;
      }
    }
    index.setLastCleanupAt(now);
    await index.flush();
    return CacheCleanupResult(freedBytes: freed, removedFiles: removed, failedFiles: failed, bytesLeft: totalBytes);
  }

  /// Removes every entry of [category], including files the index forgot.
  Future<CacheCleanupResult> clearByCategory(String category, DateTime now) async {
    var freed = 0;
    var removed = 0;
    var failed = 0;
    for (final entry in index.entries.where((entry) => entry.category == category).toList()) {
      final size = entry.size;
      if (await delete(entry.key, category: category)) {
        freed += size;
        removed++;
      } else {
        failed++;
      }
    }
    final (extraFreed, extraRemoved, extraFailed) = await _deleteTree(
      Directory(p.join(directory.images.path, category)),
    );
    freed += extraFreed;
    removed += extraRemoved;
    failed += extraFailed;
    index.setLastCleanupAt(now);
    await index.flush();
    return CacheCleanupResult(freedBytes: freed, removedFiles: removed, failedFiles: failed, bytesLeft: totalBytes);
  }

  /// Empties the image tree, leaving partial writes alone.
  Future<CacheCleanupResult> clearImages(DateTime now) async {
    final (freed, removed, failed) = await _deleteTree(directory.images);
    index
      ..clear()
      ..setLastCleanupAt(now);
    await index.flush();
    return CacheCleanupResult(freedBytes: freed, removedFiles: removed, failedFiles: failed, bytesLeft: 0);
  }

  /// Empties the cache tree and the temporary folder.
  Future<CacheCleanupResult> clearAll(DateTime now) async {
    final images = await clearImages(now);
    final temporary = await clearTemporary();
    return CacheCleanupResult(
      freedBytes: images.freedBytes + temporary.freedBytes,
      removedFiles: images.removedFiles + temporary.removedFiles,
      failedFiles: images.failedFiles + temporary.failedFiles,
      bytesLeft: 0,
    );
  }

  /// Deletes leftover partial writes; safe at every startup.
  Future<CacheCleanupResult> clearTemporary() async {
    final (freed, removed, failed) = await _deleteTree(directory.temporary);
    return CacheCleanupResult(freedBytes: freed, removedFiles: removed, failedFiles: failed, bytesLeft: totalBytes);
  }

  /// Prunes until the cache fits [maxBytes], keeping [targetRatio] of it.
  ///
  /// Order: copies past their stale window, then expired copies, then fresh
  /// ones; within a bucket low priority first and least recently used first.
  /// Permanent entries are considered only when nothing else is left.
  Future<CacheCleanupResult> enforceLimit({
    required int maxBytes,
    required double targetRatio,
    required DateTime now,
  }) async {
    var total = totalBytes;
    if (maxBytes <= 0 || total <= maxBytes) {
      return CacheCleanupResult(freedBytes: 0, removedFiles: 0, failedFiles: 0, bytesLeft: total);
    }
    final target = (maxBytes * targetRatio).round().clamp(0, maxBytes);
    final ordered = index.entries.toList()
      ..sort((a, b) {
        final bucket = _bucket(a, now).compareTo(_bucket(b, now));
        if (bucket != 0) {
          return bucket;
        }
        final priority = a.priority.rank.compareTo(b.priority.rank);
        if (priority != 0) {
          return priority;
        }
        return a.lastAccessedAt.compareTo(b.lastAccessedAt);
      });
    var freed = 0;
    var removed = 0;
    var failed = 0;
    for (final entry in ordered) {
      if (total <= target) {
        break;
      }
      final size = entry.size;
      if (await delete(entry.key, category: entry.category)) {
        total -= size;
        freed += size;
        removed++;
      } else {
        failed++;
      }
    }
    index.setLastCleanupAt(now);
    await index.flush();
    return CacheCleanupResult(freedBytes: freed, removedFiles: removed, failedFiles: failed, bytesLeft: total);
  }

  /// Reconciles the index with the folder: adopts files the index forgot and
  /// drops entries whose files vanished. The slow path, for idle time.
  Future<void> reconcile(DateTime now) async {
    final seen = <String>{};
    try {
      final root = directory.images;
      if (await root.exists()) {
        await for (final entity in root.list(recursive: true, followLinks: false)) {
          if (entity is! File || p.extension(entity.path).toLowerCase() != '.img') {
            continue;
          }
          final key = p.basenameWithoutExtension(entity.path);
          seen.add(key);
          if (index.containsKey(key)) {
            continue;
          }
          final folder = p.basename(entity.parent.parent.path);
          final stat = await entity.stat();
          if (stat.size <= 0) {
            continue;
          }
          final ttl = ttlForCategory(folder);
          index.put(
            CacheEntry(
              key: key,
              category: folder,
              size: stat.size,
              createdAt: stat.modified,
              lastAccessedAt: stat.modified,
              expiresAt: ttl == null ? null : stat.modified.add(ttl),
              priority: priorityForCategory(folder),
            ),
          );
        }
      }
    } on FileSystemException catch (error) {
      log?.warning('cache reconcile could not finish', fields: {'error': '$error'});
    }
    for (final entry in index.entries.toList()) {
      if (!seen.contains(entry.key)) {
        index.remove(entry.key);
      }
    }
    if (index.lastCleanupAt == null) {
      index.setLastCleanupAt(now);
    }
    await index.flush();
  }

  /// Writes any pending index change.
  Future<void> flush() => index.flush();

  int _bucket(CacheEntry entry, DateTime now) {
    if (entry.isPermanent) {
      return 3;
    }
    if (!entry.isExpiredAt(now)) {
      return 2;
    }
    return entry.isUsableWhenStale(now, maxStaleForCategory(entry.category)) ? 1 : 0;
  }

  Future<(int, int, int)> _deleteTree(Directory root) async {
    var freed = 0;
    var removed = 0;
    var failed = 0;
    try {
      if (!await root.exists()) {
        return (0, 0, 0);
      }
      await for (final entity in root.list(recursive: true, followLinks: false)) {
        if (entity is! File) {
          continue;
        }
        try {
          final size = await entity.length();
          if (await deleteFileQuietly(entity)) {
            freed += size;
            removed++;
          } else {
            failed++;
          }
        } on FileSystemException {
          failed++;
        }
      }
    } on FileSystemException {
      // An unreadable folder frees nothing this round; the caller reports it.
    }
    return (freed, removed, failed);
  }
}
