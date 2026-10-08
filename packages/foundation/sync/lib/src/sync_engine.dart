// Module: lib/src/sync_engine.dart
// Purpose: The cloud sync skeleton: pull and push with tombstones, a cursor, and one conflict rule.
// Author: liuchuancong
// Created: 2026-10-08
//
// docs/services/sync.md treats sync as a data plane over user content, never over credentials: the
// credential predicate is injected so the exclusion is enforced here rather than remembered by callers.
// The remote is a port, not a dependency: the application binds it to Firebase in its composition root,
// which keeps this L0 package free of a vendor SDK.

import 'package:pure_live_utils/pure_live_utils.dart';

/// One synced item. A deleted record is kept as a tombstone so a deletion propagates instead of looking
/// like an absent key.
final class SyncRecord {
  const SyncRecord({
    required this.key,
    required this.updatedAt,
    this.value,
    this.deleted = false,
  });

  final String key;
  final DateTime updatedAt;
  final Object? value;
  final bool deleted;

  Map<String, Object?> toJson() => <String, Object?>{
        'key': key,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'deleted': deleted,
        if (!deleted) 'value': value,
      };

  factory SyncRecord.fromJson(Map<String, Object?> json) => SyncRecord(
        key: json['key']! as String,
        updatedAt: (DateTime.tryParse('${json['updatedAt']}') ?? DateTime.utc(1970)).toUtc(),
        value: json['deleted'] == true ? null : json['value'],
        deleted: json['deleted'] as bool? ?? false,
      );
}

/// Where a sync has reached. Opaque to callers; monotonic per store.
final class SyncCursor {
  const SyncCursor(this.token);

  final String token;

  static const SyncCursor start = SyncCursor('');
}

/// How to resolve the same key changed on both sides.
enum ConflictPolicy {
  /// The remote wins. Correct when the cloud is the shared truth.
  remoteWins,

  /// Local wins, and the change is queued for push.
  localWins,

  /// Newest timestamp wins; a tie goes to the remote, because the other device already applied it.
  newestWins,
}

/// The remote side.
abstract interface class RemoteStore {
  Future<List<SyncRecord>> fetchSince(SyncCursor cursor);

  Future<SyncCursor> push(List<SyncRecord> records);
}

/// The local side.
abstract interface class LocalStore {
  Future<Map<String, SyncRecord>> readAll();

  Future<void> apply(List<SyncRecord> records);

  Future<List<SyncRecord>> pendingChanges();

  Future<void> markPushed(List<String> keys);
}

/// What one sync pass did.
final class SyncReport {
  const SyncReport({
    required this.applied,
    required this.conflicts,
    required this.pushed,
    required this.refusedCredentials,
    required this.cursor,
  });

  final int applied;
  final int conflicts;
  final int pushed;
  final int refusedCredentials;
  final SyncCursor cursor;

  @override
  String toString() =>
      'SyncReport(applied=$applied, conflicts=$conflicts, pushed=$pushed, '
      'refusedCredentials=$refusedCredentials)';
}

/// Moves records between a local store and a remote one.
final class SyncEngine {
  const SyncEngine({
    required this.remote,
    required this.local,
    required this.isCredentialKey,
    this.policy = ConflictPolicy.newestWins,
  });

  final RemoteStore remote;
  final LocalStore local;

  /// Keys belonging to the credential store are never synced, in either direction.
  final bool Function(String key) isCredentialKey;
  final ConflictPolicy policy;

  /// Pulls everything after [from] and writes the accepted records locally.
  Future<SyncReport> pull({SyncCursor from = SyncCursor.start, Clock? clock}) async {
    final incoming = await remote.fetchSince(from);
    final safe = <SyncRecord>[];
    var refused = 0;
    for (final record in incoming) {
      if (isCredentialKey(record.key)) {
        refused++;
        continue;
      }
      safe.add(record);
    }
    if (safe.isEmpty) {
      return SyncReport(
        applied: 0,
        conflicts: 0,
        pushed: 0,
        refusedCredentials: refused,
        cursor: from,
      );
    }

    final existing = await local.readAll();
    // The clock seam keeps pull deterministic for a caller that injects one.
    (clock ?? systemClock)();
    final accepted = <SyncRecord>[];
    var conflicts = 0;
    for (final record in safe) {
      final localRecord = existing[record.key];
      if (localRecord == null) {
        accepted.add(record);
        continue;
      }
      if (_remoteWins(localRecord, record)) {
        conflicts++;
        accepted.add(record);
      }
    }
    if (accepted.isNotEmpty) {
      await local.apply(accepted);
    }
    return SyncReport(
      applied: accepted.length,
      conflicts: conflicts,
      pushed: 0,
      refusedCredentials: refused,
      cursor: from,
    );
  }

  /// Pushes local changes and returns the cursor the next pull should start from.
  Future<SyncReport> push() async {
    final pending = await local.pendingChanges();
    final safe = pending.where((record) => !isCredentialKey(record.key)).toList(growable: false);
    if (safe.isEmpty) {
      return SyncReport(
        applied: 0,
        conflicts: 0,
        pushed: 0,
        refusedCredentials: pending.length - safe.length,
        cursor: SyncCursor.start,
      );
    }
    final cursor = await remote.push(safe);
    await local.markPushed(safe.map((record) => record.key).toList(growable: false));
    return SyncReport(
      applied: 0,
      conflicts: 0,
      pushed: safe.length,
      refusedCredentials: pending.length - safe.length,
      cursor: cursor,
    );
  }

  /// Whether the incoming record replaces the local one.
  bool _remoteWins(SyncRecord localRecord, SyncRecord incoming) {
    return switch (policy) {
      ConflictPolicy.remoteWins => true,
      ConflictPolicy.localWins => false,
      // Equal timestamps go to the remote: the other device already applied that version.
      ConflictPolicy.newestWins => !incoming.updatedAt.isBefore(localRecord.updatedAt),
    };
  }
}
