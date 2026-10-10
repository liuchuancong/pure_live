// Module: lib/src/storage_guard.dart
// Purpose: The operations every writable directory needs - create, prove it is writable, measure it, make room
// in it, and refuse a download that cannot fit.
// Author: liuchuancong
// Created: 2026-10-11
//
// A resolved path is not a usable path. On Android the external directory can disappear when a card is
// unmounted, on Windows a roaming profile can be read-only, and a portable build on a write-protected stick
// resolves cleanly and then fails on the first save. So every location is proved once, by writing and removing
// a probe file, and the result is remembered: a caller that asks twice in one session gets one answer rather
// than two disk round trips.

import 'dart:async';
import 'dart:io';

import 'package:pure_live_utils/pure_live_utils.dart';

import 'atomic_file.dart';
import 'storage_locations.dart';

/// A storage operation that could not be completed, named for what the caller has to tell the user.
final class StorageGuardFailure extends DomainFailure {
  const StorageGuardFailure(super.reason, {this.path, this.kind, super.cause});

  final String? path;
  final StorageKind? kind;

  @override
  String toString() {
    final where = path == null ? '' : ' at $path';
    return 'StorageGuardFailure($reason$where)';
  }
}

/// How much room a volume has.
final class StorageCapacity {
  const StorageCapacity({required this.totalBytes, required this.freeBytes});

  final int totalBytes;
  final int freeBytes;

  ByteSize get total => ByteSize(totalBytes);
  ByteSize get free => ByteSize(freeBytes);

  /// The fraction still free, or null when the volume reports no size at all.
  double? get freeRatio => totalBytes <= 0 ? null : freeBytes / totalBytes;

  @override
  String toString() => 'StorageCapacity(${free.humanReadable} free of ${total.humanReadable})';
}

/// Free-space lookup, which Dart's io library does not provide.
///
/// Bound by the host: `statfs` on Linux, `GetDiskFreeSpaceEx` on Windows, `StatFs` on Android. A guard with no
/// probe answers "unknown" and callers that need a hard guarantee must say so, because a download that cannot
/// be size-checked should still be attempted rather than refused.
abstract interface class DiskCapacityProbe {
  Future<StorageCapacity?> capacityOf(String path);
}

/// The probe for hosts that cannot answer, which is the default rather than a crash.
final class UnknownDiskCapacity implements DiskCapacityProbe {
  const UnknownDiskCapacity();

  @override
  Future<StorageCapacity?> capacityOf(String path) async => null;
}

/// What one eviction pass did.
final class EvictionReport {
  const EvictionReport({
    required this.scanned,
    required this.removedFiles,
    required this.freedBytes,
    required this.bytesBefore,
    required this.bytesAfter,
    required this.skipped,
  });

  final int scanned;
  final int removedFiles;
  final int freedBytes;
  final int bytesBefore;
  final int bytesAfter;

  /// Files the policy wanted to remove but could not, which is normal on Windows while a player holds one
  /// open. Reported because "the cache did not shrink" is otherwise indistinguishable from a bug.
  final int skipped;

  @override
  String toString() =>
      'EvictionReport(removed $removedFiles, freed ${ByteSize(freedBytes).humanReadable}, '
      'now ${ByteSize(bytesAfter).humanReadable}, skipped $skipped)';
}

/// Creates, measures and trims directories, and refuses work that cannot fit.
final class StorageGuard {
  StorageGuard({DiskCapacityProbe capacity = const UnknownDiskCapacity(), this.clock = systemClock})
    : _capacity = capacity;

  final DiskCapacityProbe _capacity;
  final Clock clock;

  final Map<String, bool> _writable = <String, bool>{};

  /// How much of a volume must stay free after a write, so an app never fills a user's disk to the last byte.
  static const double kFreeSpaceSafetyRatio = 0.02;

  /// Creates [path] and proves it writable, answering the directory or failing with a named reason.
  ///
  /// The proof is a real write: `Directory.create` succeeds on a read-only volume in some sandboxes and the
  /// failure only appears later, in the middle of saving something the user cannot recover.
  Future<Directory> ensure(String path, {StorageKind? kind}) async {
    final directory = Directory(path);
    try {
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    } on Object catch (error) {
      throw StorageGuardFailure('cannot create the directory', path: path, kind: kind, cause: error);
    }
    if (!await isWritable(path)) {
      throw StorageGuardFailure('the directory is not writable', path: path, kind: kind);
    }
    return directory;
  }

  /// Whether a probe file can be written and removed here, remembered per path for the session.
  Future<bool> isWritable(String path) async {
    final cached = _writable[path];
    if (cached != null) {
      return cached;
    }
    final answer = await _probe(path);
    _writable[path] = answer;
    return answer;
  }

  /// Drops the remembered answers, which a host calls after a permission grant or a storage remount: the
  /// cached "not writable" would otherwise outlive the change that made it false.
  void invalidate() => _writable.clear();

  Future<bool> _probe(String path) async {
    final probe = File('$path${Platform.pathSeparator}.pure_live_write_probe');
    try {
      await probe.writeAsString('probe', flush: true);
      return true;
    } on Object {
      return false;
    } finally {
      try {
        if (await probe.exists()) {
          await probe.delete();
        }
      } on Object {
        // A probe that cannot be deleted is not a failure of the caller's write; leaving it is cheaper than
        // turning a successful probe into a reported error.
      }
    }
  }

  /// The bytes under [path], counting nested files.
  Future<int> usedBytes(String path) async {
    final directory = Directory(path);
    if (!await directory.exists()) {
      return 0;
    }
    return directorySize(directory);
  }

  /// Whether [requiredBytes] can be written at [path] with the safety margin left over.
  ///
  /// Answers true when free space is unknown, because refusing a download on a host that cannot measure its
  /// disk would break that host entirely; the caller that needs a hard guarantee passes [requireKnownCapacity].
  Future<bool> hasRoom(String path, int requiredBytes, {bool requireKnownCapacity = false}) async {
    final capacity = await _capacity.capacityOf(path);
    if (capacity == null) {
      return !requireKnownCapacity;
    }
    final reserved = (capacity.totalBytes * kFreeSpaceSafetyRatio).round();
    return capacity.freeBytes - reserved >= requiredBytes;
  }

  /// The free space at [path], or null when the host cannot measure it.
  Future<StorageCapacity?> capacityOf(String path) => _capacity.capacityOf(path);

  /// Removes everything under [path], keeping the directory itself.
  ///
  /// Keeps the root because a caller holds a path it resolved at startup; deleting the directory would make
  /// every later write fail until something recreates it.
  Future<EvictionReport> clear(String path) async {
    final directory = Directory(path);
    if (!await directory.exists()) {
      return const EvictionReport(
        scanned: 0,
        removedFiles: 0,
        freedBytes: 0,
        bytesBefore: 0,
        bytesAfter: 0,
        skipped: 0,
      );
    }
    final before = await usedBytes(path);
    var removed = 0;
    var skipped = 0;
    var scanned = 0;
    await for (final entity in directory.list(recursive: false)) {
      scanned++;
      try {
        await entity.delete(recursive: true);
        removed++;
      } on Object {
        skipped++;
      }
    }
    final after = await usedBytes(path);
    return EvictionReport(
      scanned: scanned,
      removedFiles: removed,
      freedBytes: before - after,
      bytesBefore: before,
      bytesAfter: after,
      skipped: skipped,
    );
  }

  /// Brings [path] under a budget, oldest first.
  ///
  /// At most one of [maxBytes] and [olderThan] is required; when both are given, a file must fail both to
  /// survive, which is what "clear the cache but keep this week" means to a user.
  ///
  /// [keep] is honoured absolutely: a pinned file is never evicted even when it is the oldest thing here, so a
  /// download the user marked offline-safe cannot be reclaimed by a cache pass.
  Future<EvictionReport> evict(
    String path, {
    int? maxBytes,
    Duration? olderThan,
    bool Function(File file)? keep,
  }) async {
    if (maxBytes == null && olderThan == null) {
      throw const StorageGuardFailure('evict needs a budget: maxBytes, olderThan, or both');
    }
    final directory = Directory(path);
    if (!await directory.exists()) {
      return const EvictionReport(
        scanned: 0,
        removedFiles: 0,
        freedBytes: 0,
        bytesBefore: 0,
        bytesAfter: 0,
        skipped: 0,
      );
    }

    final entries = <_CacheEntry>[];
    await for (final entity in directory.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      if (keep != null && keep(entity)) {
        continue;
      }
      final FileStat stat;
      try {
        stat = await entity.stat();
      } on Object {
        continue;
      }
      entries.add(_CacheEntry(file: entity, modified: stat.modified, bytes: stat.size));
    }
    // Oldest first: a cache is a recency structure, and evicting by name would delete whatever sorts first
    // rather than whatever is least likely to be used again.
    entries.sort((left, right) => left.modified.compareTo(right.modified));

    final before = entries.fold<int>(0, (sum, entry) => sum + entry.bytes);
    final cutoff = olderThan == null ? null : clock().toUtc().subtract(olderThan);
    var target = before;
    if (maxBytes != null && before > maxBytes) {
      target = maxBytes;
    }

    var freed = 0;
    var removed = 0;
    var skipped = 0;
    for (final entry in entries) {
      final overBudget = target < before - freed;
      final tooOld = cutoff != null && entry.modified.isBefore(cutoff);
      if (!overBudget && !tooOld) {
        continue;
      }
      try {
        await entry.file.delete();
        freed += entry.bytes;
        removed++;
      } on Object {
        skipped++;
      }
    }
    return EvictionReport(
      scanned: entries.length,
      removedFiles: removed,
      freedBytes: freed,
      bytesBefore: before,
      bytesAfter: before - freed,
      skipped: skipped,
    );
  }

  /// The directory a namespace owns under [root], created and proved writable.
  Future<Directory> ensureNamespace(String root, String namespace) async {
    final safe = _safeNamespace(namespace);
    return ensure('$root${Platform.pathSeparator}$safe');
  }

  /// A namespace as a single path segment.
  ///
  /// Namespaces come from plugin ids and source ids, which are not this package's to trust: one containing a
  /// separator or `..` would let a caller's cache pass evict another namespace's files.
  static String _safeNamespace(String namespace) {
    var safe = namespace.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    safe = safe.replaceAll(RegExp(r'\.{2,}'), '_').replaceAll(RegExp(r'^\.+|\.+$'), '_');
    return safe.isEmpty ? '_' : safe;
  }
}

/// One file considered for eviction.
final class _CacheEntry {
  const _CacheEntry({required this.file, required this.modified, required this.bytes});

  final File file;
  final DateTime modified;
  final int bytes;
}
