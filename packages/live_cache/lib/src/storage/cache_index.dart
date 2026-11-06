import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:live_cache/src/models/cache_entry.dart';
import 'package:live_cache/src/models/cache_priority.dart';
import 'package:live_cache/src/storage/cache_directory.dart';
import 'package:live_cache/src/storage/cache_file.dart';
import 'package:live_log/live_log.dart' show LiveLog;
import 'package:path/path.dart' as p;

/// The index file's schema version; a different value triggers a rebuild.
const int _indexVersion = 1;

/// The light bookkeeping beside the image files: no database, one JSON file,
/// written with a debounce and an atomic replace.
///
/// Losing the file only costs the timestamps and validators; [rebuildFromDisk]
/// reconstructs entries from the files themselves.
final class CacheIndex {
  /// Creates an index over [directory].
  new({required this.directory, this.flushDelay = const Duration(seconds: 5), this.log});

  /// Where the index and the image tree live.
  final CacheDirectory directory;

  /// How long a change may wait before the index is flushed.
  final Duration flushDelay;

  /// Optional diagnostics target.
  final LiveLog? log;

  final Map<String, CacheEntry> _entries = {};

  Timer? _flushTimer;
  bool _dirty = false;
  bool _loaded = false;
  bool _needsRebuild = false;

  /// The last explicit cleanup, persisted for the settings surface.
  DateTime? lastCleanupAt;

  /// Whether [load] found the index missing or unreadable.
  bool get needsRebuild => _needsRebuild;

  /// The number of indexed files.
  int get length => _entries.length;

  /// Every indexed entry, in no particular order.
  Iterable<CacheEntry> get entries => _entries.values;

  /// The entry under [key], or null.
  CacheEntry? operator [](String key) => _entries[key];

  /// Whether [key] is indexed.
  bool containsKey(String key) => _entries.containsKey(key);

  /// Reads the index once. A missing or broken file is a rebuild signal, not
  /// an error.
  Future<void> load() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    try {
      final file = directory.indexFile;
      if (!await file.exists()) {
        _needsRebuild = true;
        return;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map || decoded['version'] != _indexVersion) {
        _needsRebuild = true;
        return;
      }
      final rawEntries = decoded['entries'];
      if (rawEntries is Map) {
        for (final raw in rawEntries.entries) {
          final key = raw.key;
          if (key is! String) {
            continue;
          }
          final entry = CacheEntry.fromJson(key, raw.value);
          if (entry != null) {
            _entries[key] = entry;
          }
        }
      }
      final cleanup = decoded['lastCleanupAt'];
      if (cleanup is int) {
        lastCleanupAt = DateTime.fromMillisecondsSinceEpoch(cleanup, isUtc: true);
      }
    } on Object catch (error) {
      log?.warning('cache index unreadable; rebuilding', fields: {'error': '$error'});
      _needsRebuild = true;
    }
  }

  /// Replaces the index with entries reconstructed from the files on disk.
  ///
  /// This is the recovery path and the idle reconciliation's slow half; it is
  /// never part of a normal startup.
  Future<void> rebuildFromDisk({
    required Duration? Function(String category) ttlForCategory,
    required CachePriority Function(String category) priorityForCategory,
  }) async {
    final rebuilt = <String, CacheEntry>{};
    try {
      final root = directory.images;
      if (await root.exists()) {
        await for (final entity in root.list(recursive: true, followLinks: false)) {
          if (entity is! File || p.extension(entity.path).toLowerCase() != '.img') {
            continue;
          }
          final key = p.basenameWithoutExtension(entity.path);
          final category = p.basename(entity.parent.parent.path);
          final stat = await entity.stat();
          if (stat.size <= 0) {
            continue;
          }
          final modified = stat.modified;
          final ttl = ttlForCategory(category);
          rebuilt[key] = CacheEntry(
            key: key,
            category: category,
            size: stat.size,
            createdAt: modified,
            lastAccessedAt: modified,
            expiresAt: ttl == null ? null : modified.add(ttl),
            priority: priorityForCategory(category),
          );
        }
      }
    } on FileSystemException catch (error) {
      log?.warning('cache rebuild could not finish', fields: {'error': '$error'});
    }
    _entries
      ..clear()
      ..addAll(rebuilt);
    _needsRebuild = false;
    _dirty = true;
    await flush();
  }

  /// Stores [entry], replacing any earlier copy of the same key.
  void put(CacheEntry entry) {
    _entries[entry.key] = entry;
    _markDirty();
  }

  /// Forgets [key].
  void remove(String key) {
    if (_entries.remove(key) != null) {
      _markDirty();
    }
  }

  /// Records a read of [key] at [now]; the LRU order uses it.
  void markAccessed(String key, DateTime now) {
    final entry = _entries[key];
    if (entry == null) {
      return;
    }
    _entries[key] = entry.copyWith(lastAccessedAt: now);
    _markDirty();
  }

  /// Replaces [entry]'s expiry.
  void setExpiry(CacheEntry entry, DateTime? expiresAt) {
    _entries[entry.key] = entry.copyWith(expiresAt: expiresAt, clearExpiresAt: expiresAt == null);
    _markDirty();
  }

  /// Records the last explicit cleanup.
  void setLastCleanupAt(DateTime value) {
    lastCleanupAt = value;
    _markDirty();
  }

  /// Drops every entry.
  void clear() {
    if (_entries.isEmpty) {
      return;
    }
    _entries.clear();
    _markDirty();
  }

  /// Writes the index now, cancelling any pending debounce.
  Future<void> flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (!_dirty) {
      return;
    }
    _dirty = false;
    try {
      final payload = jsonEncode({
        'version': _indexVersion,
        if (lastCleanupAt != null) 'lastCleanupAt': lastCleanupAt!.toUtc().millisecondsSinceEpoch,
        'entries': {for (final entry in _entries.values) entry.key: entry.toJson()},
      });
      await writeBytesAtomically(
        target: directory.indexFile,
        bytes: utf8.encode(payload),
        temporaryDirectory: directory.temporary,
      );
    } on Object catch (error) {
      _dirty = true;
      log?.warning('cache index write failed', fields: {'error': '$error'});
    }
  }

  /// Cancels the debounce and writes once more.
  Future<void> close() => flush();

  void _markDirty() {
    _dirty = true;
    if (_flushTimer?.isActive ?? false) {
      return;
    }
    _flushTimer = Timer(flushDelay, () => unawaited(flush()));
  }
}
