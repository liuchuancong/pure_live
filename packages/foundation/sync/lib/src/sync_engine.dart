// Module: lib/src/sync_engine.dart
// Purpose: The cloud sync skeleton: pull and push with tombstones, a cursor, and one conflict rule.
// Author: liuchuancong
// Created: 2026-10-08
//
// docs/services/sync.md treats sync as a data plane over user content, never over credentials: the
// credential predicate is injected so the exclusion is enforced here rather than remembered by callers.
// The remote is a port, not a dependency: the application binds it to Firebase in its composition root,
// which keeps this L0 package free of a vendor SDK.

/// One synced item. A deleted record is kept as a tombstone so a deletion propagates instead of looking
/// like an absent key.
final class SyncRecord {
  const SyncRecord({required this.key, required this.updatedAt, this.value, this.deleted = false});

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

  /// True when nothing has been fetched yet, which the engine treats as "the remote owes me everything".
  bool get isStart => token.isEmpty;

  @override
  bool operator ==(Object other) => other is SyncCursor && other.token == token;

  @override
  int get hashCode => token.hashCode;

  @override
  String toString() => 'SyncCursor($token)';
}

/// One page pulled from the remote: the records and where the next page starts.
///
/// The cursor has to travel with the batch. When it does not, the engine can only echo the cursor it was
/// given, and a caller that dutifully passes the previous report's cursor forward re-downloads the whole
/// history on every sync - which looks like a working sync until the store is big enough to notice.
final class RemoteBatch {
  const RemoteBatch({required this.records, required this.cursor});

  final List<SyncRecord> records;
  final SyncCursor cursor;
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
  /// The records after [cursor], and the cursor to continue from.
  Future<RemoteBatch> fetchSince(SyncCursor cursor);

  /// Sends [records] and returns the cursor that reflects the remote's state afterwards.
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
    this.rejected = 0,
    this.nextCursor,
  });

  final int applied;

  /// Keys that differed on both sides and were resolved by [SyncEngine.policy].
  final int conflicts;

  final int pushed;

  /// Keys the remote tried to send (or local tried to send) that belong to the credential store.
  final int refusedCredentials;

  /// Records dropped for being unusable - a blank key, or a repeat of a key already in the same batch.
  ///
  /// Counted rather than filtered quietly: a remote that sends keyless rows is broken, and the number is
  /// the evidence.
  final int rejected;

  /// Where the next pull should start, or null when this pass learned nothing.
  ///
  /// Null is the point: the earlier design reported [SyncCursor.start] for a no-op pass, so a caller that
  /// fed the report back into the next pull silently restarted full history every single time.
  final SyncCursor? nextCursor;

  /// The cursor to continue from, keeping [previous] when this pass learned nothing.
  SyncCursor cursorAfter(SyncCursor previous) => nextCursor ?? previous;

  @override
  String toString() =>
      'SyncReport(applied=$applied, conflicts=$conflicts, pushed=$pushed, '
      'refusedCredentials=$refusedCredentials, rejected=$rejected, nextCursor=$nextCursor)';
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
  ///
  /// The report carries the cursor the remote handed back, so successive pulls advance instead of
  /// re-downloading history; see [SyncReport.nextCursor].
  Future<SyncReport> pull({SyncCursor from = SyncCursor.start}) async {
    final batch = await remote.fetchSince(from);
    final safe = <SyncRecord>[];
    var refused = 0;
    var rejected = 0;
    final seen = <String>{};
    for (final record in batch.records) {
      if (record.key.trim().isEmpty) {
        rejected++;
        continue;
      }
      if (isCredentialKey(record.key)) {
        refused++;
        continue;
      }
      // Two rows for one key inside a single batch: keep the later one, which is the order the remote sent
      // them in, and count the collapse.
      if (!seen.add(record.key)) {
        rejected++;
        safe.removeWhere((previous) => previous.key == record.key);
      }
      safe.add(record);
    }

    if (safe.isEmpty) {
      return SyncReport(
        applied: 0,
        conflicts: 0,
        pushed: 0,
        refusedCredentials: refused,
        rejected: rejected,
        nextCursor: _advance(from, batch.cursor),
      );
    }

    final existing = await local.readAll();
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
      rejected: rejected,
      nextCursor: _advance(from, batch.cursor),
    );
  }

  /// Pushes local changes and returns the cursor that reflects the remote afterwards.
  Future<SyncReport> push({SyncCursor known = SyncCursor.start}) async {
    final pending = await local.pendingChanges();
    final safe = pending.where((record) => !isCredentialKey(record.key)).toList(growable: false);
    if (safe.isEmpty) {
      // Nothing went out, so nothing was learned about the remote's position: the caller keeps the cursor
      // it already had. Reporting `start` here is what restarted full history on every idle pass.
      return SyncReport(
        applied: 0,
        conflicts: 0,
        pushed: 0,
        refusedCredentials: pending.length - safe.length,
        nextCursor: known.isStart ? null : known,
      );
    }
    final cursor = await remote.push(safe);
    await local.markPushed(safe.map((record) => record.key).toList(growable: false));
    return SyncReport(
      applied: 0,
      conflicts: 0,
      pushed: safe.length,
      refusedCredentials: pending.length - safe.length,
      nextCursor: cursor,
    );
  }

  /// A remote that answers with the same cursor it was asked with has advanced nothing; reporting it as a
  /// new position would be a claim this layer cannot verify.
  static SyncCursor? _advance(SyncCursor from, SyncCursor returned) => returned == from ? null : returned;

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
