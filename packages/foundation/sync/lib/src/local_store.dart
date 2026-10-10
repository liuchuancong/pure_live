// Module: lib/src/local_store.dart
// Purpose: A reference LocalStore with a pending queue and tombstone retention, plus the purge rule.
// Author: liuchuancong
// Created: 2026-10-11
//
// The engine only knows the LocalStore port, so without one working implementation every test writes its own
// and each one forgets a different edge - usually the tombstone. A deletion has to travel: dropping the row
// instead of marking it means the other device keeps a favourite the user deleted and the two stores never
// agree again. Retention is bounded too, because a tombstone for a row nobody has asked about in a year is
// only a growing list of keys.

import 'package:pure_live_utils/pure_live_utils.dart';

import 'sync_engine.dart';

/// How long a tombstone is kept before it may be dropped.
final class TombstonePolicy {
  const TombstonePolicy({this.retention = const Duration(days: 30), this.maxTombstones = 4096})
    : assert(maxTombstones >= 1, 'a store that keeps no tombstones cannot propagate a deletion');

  /// A deletion older than this is no longer worth carrying.
  final Duration retention;

  /// Even inside the retention window, the oldest tombstones past this count are dropped: a device that
  /// synced a 100k-row library once and then deleted half of it should not grow forever.
  final int maxTombstones;

  static const TombstonePolicy standard = TombstonePolicy();

  /// The cutoff timestamp for a purge run at [now].
  DateTime cutoff(DateTime now) => now.subtract(retention);

  @override
  String toString() => 'TombstonePolicy(retention=${retention.inDays}d, max=$maxTombstones)';
}

/// The changes not yet pushed, kept in the order they were made.
final class PendingQueue {
  PendingQueue({this.limit = 1024});

  /// Beyond this the oldest unsent change is dropped and counted. A queue that grows with the user's edits is
  /// a memory leak on a device that has been offline for a week, and the newest changes are the ones worth
  /// keeping.
  final int limit;

  final Map<String, SyncRecord> _entries = <String, SyncRecord>{};
  final List<String> _order = <String>[];
  int _dropped = 0;

  int get length => _entries.length;

  int get droppedCount => _dropped;

  bool get isEmpty => _entries.isEmpty;

  /// The queued records, oldest change first.
  List<SyncRecord> get records =>
      List<SyncRecord>.unmodifiable(_order.map((key) => _entries[key]).whereType<SyncRecord>());

  void add(SyncRecord record) {
    if (!_entries.containsKey(record.key)) {
      _order.add(record.key);
    } else {
      // A later edit to the same key replaces the earlier one and keeps its position: the remote needs the
      // newest value, and re-queueing at the tail would reorder a user's edits.
      _entries[record.key] = record;
      return;
    }
    _entries[record.key] = record;
    while (_order.length > limit) {
      final oldest = _order.removeAt(0);
      _entries.remove(oldest);
      _dropped++;
    }
  }

  void markPushed(Iterable<String> keys) {
    for (final key in keys) {
      if (_entries.remove(key) != null) {
        _order.remove(key);
      }
    }
  }

  void clear() {
    _entries.clear();
    _order.clear();
    _dropped = 0;
  }
}

/// An in-memory [LocalStore]: the reference the tests and the app's early wiring use before a database-backed
/// one exists.
final class MemoryLocalStore implements LocalStore {
  MemoryLocalStore({this.policy = TombstonePolicy.standard, Clock? clock}) : _clock = clock ?? systemClock;

  final TombstonePolicy policy;
  final Clock _clock;

  final Map<String, SyncRecord> _rows = <String, SyncRecord>{};
  final PendingQueue _pending = PendingQueue();

  /// Live rows, tombstones excluded.
  Map<String, SyncRecord> get liveRows => Map<String, SyncRecord>.unmodifiable(<String, SyncRecord>{
    for (final entry in _rows.entries)
      if (!entry.value.deleted) entry.key: entry.value,
  });

  int get tombstoneCount => _rows.values.where((record) => record.deleted).length;

  @override
  Future<Map<String, SyncRecord>> readAll() async => Map<String, SyncRecord>.of(_rows);

  @override
  Future<void> apply(List<SyncRecord> records) async {
    for (final record in records) {
      _rows[record.key] = record;
    }
  }

  @override
  Future<List<SyncRecord>> pendingChanges() async => _pending.records;

  @override
  Future<void> markPushed(List<String> keys) async => _pending.markPushed(keys);

  /// Records a local edit or deletion. A deletion is a tombstone, never a removal: see the file note.
  void edit(String key, Object? value, {bool deleted = false, DateTime? at}) {
    final record = SyncRecord(
      key: key,
      updatedAt: (at ?? _clock()).toUtc(),
      value: deleted ? null : value,
      deleted: deleted,
    );
    _rows[key] = record;
    _pending.add(record);
  }

  /// Drops tombstones past the retention window or over the count, returning how many went.
  ///
  /// Both bounds matter and neither is checked at write time: a purge that only looks at age keeps a 100k
  /// tombstone list for a month, and one that only looks at count forgets the deletions that are still recent.
  Future<int> purgeTombstones({DateTime? now}) async {
    final cutoff = policy.cutoff(now ?? _clock());
    var removed = 0;
    final tombstones = _rows.values.where((record) => record.deleted).toList(growable: false)
      ..sort((left, right) => left.updatedAt.compareTo(right.updatedAt));
    for (final record in tombstones) {
      if (record.updatedAt.isBefore(cutoff)) {
        _rows.remove(record.key);
        removed++;
      }
    }
    final remaining = _rows.values.where((record) => record.deleted).length;
    if (remaining > policy.maxTombstones) {
      final overflow = _rows.values.where((record) => record.deleted).toList(growable: false)
        ..sort((left, right) => left.updatedAt.compareTo(right.updatedAt));
      for (final record in overflow.take(remaining - policy.maxTombstones)) {
        _rows.remove(record.key);
        removed++;
      }
    }
    return removed;
  }

  Future<void> clear() async {
    _rows.clear();
    _pending.clear();
  }
}
