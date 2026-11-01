import 'dart:convert' show jsonEncode, utf8;
import 'dart:math' show max, min;

import 'package:crypto/crypto.dart' as crypto show sha256;

import 'package:live_lan_sync/src/adapter/adapter.dart' show LanSyncDataAdapter, SyncApplyResult, SyncChangeFailure;
import 'package:live_lan_sync/src/domain/conflict/conflict.dart' show SyncConflict, VersionRelation;
import 'package:live_lan_sync/src/domain/errors/errors.dart' show LanSyncError, LanSyncErrorCategory;
import 'package:live_lan_sync/src/domain/sync/sync.dart' show LoggedChange, SyncChange, SyncCursor, SyncOperation;
import 'package:live_lan_sync/src/store/store.dart' show LanSyncStore, SyncBatchCommit;

/// What applying one batch did.
final class AppliedBatch {
  /// One batch's outcome.
  const new({
    required this.handledThrough,
    required this.applied,
    required this.duplicates,
    required this.stale,
    required this.converged,
    required this.conflicts,
    required this.failures,
    this.appliedChanges = const <SyncChange>[],
  });

  /// The sequence (in the sender's log) up to which every change is durably
  /// handled; the cursor stands here now.
  final int handledThrough;

  /// Changes the adapter applied.
  final int applied;

  /// Changes already handled before.
  final int duplicates;

  /// Changes older than what this device holds.
  final int stale;

  /// Concurrent changes whose content matched this device's: settled at
  /// once by joining their version vectors, no decision needed.
  final int converged;

  /// Concurrent modifications with different content, recorded for the
  /// scope's policy or the user.
  final List<SyncConflict> conflicts;

  /// Changes refused, each with its reason; the cursor stops before the
  /// first of them.
  final List<SyncChangeFailure> failures;

  /// The versions now current here because of this batch, joins included.
  final List<SyncChange> appliedChanges;

  /// Every change this batch dealt with, whatever the outcome.
  int get handled => applied + duplicates + stale + converged + conflicts.length;
}

/// Applies one received batch: validate, deduplicate, compare causality,
/// hand the causally new changes to the adapter, and commit everything —
/// relayed changes, processed ids, conflicts, cursor — in one store call
/// (spec §10.3 steps 6–11, §10.4, §11, §15.3).
///
/// Callers serialize batches per scope; the applier itself holds no lock.
final class BatchApplier {
  /// An applier for [localDeviceId] over [store].
  new({required this.store, required this.localDeviceId, required this.now});

  /// Where processed ids, the change log, conflicts and cursors live.
  final LanSyncStore store;

  /// This device; it signs the versions it writes to join concurrent
  /// identical changes.
  final String localDeviceId;

  /// The clock cursor timestamps come from.
  final DateTime Function() now;

  /// The longest id or type this engine accepts in a change.
  static const int maxIdentifierLength = 256;

  /// The operation-id prefix of version joins.
  static const String joinPrefix = 'join/';

  /// Applies [batch] — the entries of [peer]'s log for [scope] after
  /// [after], up to [through] — and returns what happened.
  ///
  /// Throws a [LanSyncError] with `dataValidation` when the batch itself is
  /// malformed (out of order, outside its window), or `storage` when the
  /// adapter or the store failed; nothing is committed then.
  Future<AppliedBatch> apply({
    required String peer,
    required String scope,
    required LanSyncDataAdapter adapter,
    required List<LoggedChange> batch,
    required int after,
    required int through,
    required SyncCursor cursor,
  }) async {
    var previous = after;
    for (final entry in batch) {
      if (entry.sequence <= previous || entry.sequence > through) {
        throw LanSyncError(
          category: LanSyncErrorCategory.dataValidation,
          code: 'batch_out_of_order',
          message: 'The other device sent changes out of order.',
          deviceId: peer,
          debugContext: 'scope: $scope, after: $after, through: $through, saw: ${entry.sequence}',
        );
      }
      previous = entry.sequence;
    }

    final toApply = <LoggedChange>[];
    final processedOnly = <String>{};
    final conflicts = <SyncConflict>[];
    final failures = <SyncChangeFailure>[];
    int? firstFailedSequence;
    var duplicates = 0;
    var stale = 0;
    var converged = 0;

    for (final entry in batch) {
      final change = entry.change;
      final problem = _problemWith(change, scope, adapter);
      if (problem != null) {
        failures.add(SyncChangeFailure(change: change, reason: problem));
        firstFailedSequence = entry.sequence;
        break;
      }
      if (await store.hasProcessedOperation(change.operationId)) {
        processedOnly.add(change.operationId);
        duplicates++;
        continue;
      }
      final local = await store.latestChange(scope: scope, entityId: change.entityId);
      final relation = local == null ? VersionRelation.ahead : change.revision.compareTo(local.change.revision);
      switch (relation) {
        case VersionRelation.ahead:
          toApply.add(entry);
        case VersionRelation.equal || VersionRelation.behind:
          processedOnly.add(change.operationId);
          stale++;
        case VersionRelation.concurrent when sameContent(local!.change, change):
          // Both sides arrived at the same state: join the vectors. Every
          // device joining the same pair derives the same operation id, so
          // the joins deduplicate when they meet.
          toApply.add(LoggedChange(sequence: entry.sequence, change: _join(local.change, change, adapter)));
          processedOnly.add(change.operationId);
          converged++;
        case VersionRelation.concurrent:
          conflicts.add(
            SyncConflict(
              scope: scope,
              entityId: change.entityId,
              local: local!.change,
              remote: change,
              relation: relation,
            ),
          );
          processedOnly.add(change.operationId);
      }
    }

    SyncApplyResult result;
    try {
      result = toApply.isEmpty
          ? const SyncApplyResult(appliedCount: 0)
          : await adapter.applyChanges(changes: [for (final entry in toApply) entry.change]);
    } on LanSyncError {
      rethrow;
    } on Object catch (error) {
      throw LanSyncError(
        category: LanSyncErrorCategory.storage,
        code: 'adapter_apply_failed',
        message: 'The changes could not be saved on this device.',
        deviceId: peer,
        debugContext: 'scope: $scope, $error',
      );
    }

    final refusedIds = {for (final failure in result.failures) failure.change.operationId};
    final adapterConflictIds = {for (final conflict in result.conflicts) conflict.remote.operationId};
    final applied = <SyncChange>[];
    for (final entry in toApply) {
      final id = entry.change.operationId;
      if (refusedIds.contains(id)) {
        firstFailedSequence = firstFailedSequence == null ? entry.sequence : min(firstFailedSequence, entry.sequence);
      } else if (!adapterConflictIds.contains(id)) {
        applied.add(entry.change);
      }
    }
    failures.addAll(result.failures);
    conflicts.addAll(result.conflicts);
    processedOnly.addAll(adapterConflictIds);

    final handledThrough = firstFailedSequence == null ? through : firstFailedSequence - 1;
    final current = sequenceOf(cursor.remoteCheckpoint);
    try {
      await store.commitBatch(
        SyncBatchCommit(
          peerDeviceId: peer,
          scope: scope,
          relayed: applied,
          processedOperationIds: processedOnly,
          conflicts: conflicts,
          cursor: handledThrough > current
              ? cursor.advanced(remoteCheckpoint: '${max(handledThrough, current)}', at: now().toUtc())
              : null,
        ),
      );
    } on Object catch (error) {
      // The adapter may already have applied the changes; with the cursor
      // unmoved they arrive again and the adapter's idempotence absorbs it.
      throw LanSyncError(
        category: LanSyncErrorCategory.storage,
        code: 'store_commit_failed',
        message: 'The sync progress could not be saved on this device.',
        deviceId: peer,
        debugContext: 'scope: $scope, $error',
      );
    }
    final joins = applied.where((change) => change.operationId.startsWith(joinPrefix)).length;
    return AppliedBatch(
      handledThrough: handledThrough,
      applied: applied.length - joins,
      duplicates: duplicates,
      stale: stale,
      converged: converged,
      conflicts: conflicts,
      failures: failures,
      appliedChanges: applied,
    );
  }

  /// A cursor checkpoint as a sequence; absent or unreadable is 0.
  static int sequenceOf(String? checkpoint) => int.tryParse(checkpoint ?? '') ?? 0;

  /// Whether [a] and [b] describe the same state: same operation, same
  /// payload regardless of key order.
  static bool sameContent(SyncChange a, SyncChange b) =>
      a.operation == b.operation &&
      (a.operation == SyncOperation.delete || _canonical(a.payload) == _canonical(b.payload));

  SyncChange _join(SyncChange local, SyncChange remote, LanSyncDataAdapter adapter) {
    final ids = [local.operationId, remote.operationId]..sort();
    final digest = crypto.sha256.convert(utf8.encode(ids.join('\n'))).toString().substring(0, 32);
    return SyncChange(
      operationId: '$joinPrefix$digest',
      scope: remote.scope,
      entityType: remote.entityType,
      entityId: remote.entityId,
      originDeviceId: localDeviceId,
      operation: remote.operation,
      schemaVersion: adapter.schemaVersion,
      revision: local.revision.merged(remote.revision),
      createdAt: now().toUtc(),
      payload: remote.payload,
    );
  }

  static String _canonical(Object? value) => jsonEncode(_sorted(value));

  static Object? _sorted(Object? value) => switch (value) {
    final Map<Object?, Object?> map => <String, Object?>{
      for (final key in map.keys.map((key) => '$key').toList()..sort()) key: _sorted(map[key]),
    },
    final List<Object?> list => [for (final item in list) _sorted(item)],
    _ => value,
  };

  static String? _problemWith(SyncChange change, String scope, LanSyncDataAdapter adapter) {
    if (change.scope != scope) {
      return 'The change belongs to scope "${change.scope}", not "$scope".';
    }
    if (change.schemaVersion != adapter.schemaVersion) {
      return 'The change uses schema version ${change.schemaVersion}; this device speaks ${adapter.schemaVersion}.';
    }
    for (final identifier in [change.operationId, change.entityId, change.entityType, change.originDeviceId]) {
      if (identifier.isEmpty || identifier.length > maxIdentifierLength) {
        return 'The change carries an empty or oversized identifier.';
      }
    }
    if (change.operation == SyncOperation.delete && !adapter.capabilities.supportsDelete) {
      return 'This scope does not accept deletes.';
    }
    if (change.revision.isEmpty) {
      return 'The change carries no version.';
    }
    return null;
  }
}
