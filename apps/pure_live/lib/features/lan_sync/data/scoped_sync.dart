import 'dart:convert' show jsonEncode;

import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:live_storage/live_storage.dart' show JsonStore;
import 'package:pure_live/features/lan_sync/data/sync_scopes.dart';

/// What a scope looked like the last time the sync saw it: entity id → the
/// payload then. The change detector diffs the live store against this to
/// find local edits, and every remote apply writes here too, so a change
/// that came from a peer is never read back as a local one.
///
/// One namespace, keys `scope/entityId`, values the payload maps.
final class ScopeSnapshotLedger {
  /// The ledger over [store].
  const ScopeSnapshotLedger(this.store);

  /// The `lan_sync_snapshots` namespace.
  final JsonStore store;

  static String _key(LanSyncScope scope, String entityId) => '${scope.id}/$entityId';

  /// Every remembered entry of [scope].
  Map<String, Map<String, Object?>> entriesOf(LanSyncScope scope) {
    final prefix = '${scope.id}/';
    final out = <String, Map<String, Object?>>{};
    for (final entry in store.entries.entries) {
      if (!entry.key.startsWith(prefix)) continue;
      final value = entry.value;
      if (value is Map) out[entry.key.substring(prefix.length)] = Map<String, Object?>.from(value);
    }
    return out;
  }

  /// Remembers [payload] for one entity; null forgets it. Called after a
  /// remote change was applied.
  Future<void> markApplied(LanSyncScope scope, String entityId, Map<String, Object?>? payload) async {
    if (payload == null) {
      await store.delete(_key(scope, entityId));
    } else {
      await store.put(_key(scope, entityId), payload);
    }
  }

  /// Replaces everything remembered for [scope] with [current]. Called
  /// after the detector recorded the differences.
  Future<void> replaceScope(LanSyncScope scope, Map<String, Map<String, Object?>> current) async {
    final stale = entriesOf(scope).keys.where((id) => !current.containsKey(id)).map((id) => _key(scope, id));
    await store.deleteAll(stale.toList());
    await store.putAll({for (final entry in current.entries) _key(scope, entry.key): entry.value});
    await store.flush();
  }
}

/// Finds this device's local edits since the last sync and records them
/// into the engine's change log — for every scope that has no write hook
/// of its own. The favorites keep their repository hook; the rest are
/// diffed here right before a sync, which also catches a `clear`, a trim
/// and an edit made while the feature was off.
final class LocalChangeDetector {
  /// The detector over [ledger], handing every difference to [record].
  const LocalChangeDetector({required this.ledger, required this.record, required this.currentOf});

  /// A detector recording straight into [engine]'s log.
  LocalChangeDetector.into(SyncEngine engine, {required this.ledger, required this.currentOf})
    : record = ((scope, entityId, payload) => engine.recordLocalChange(
        scope: scope.id,
        entityType: scope.id,
        entityId: entityId,
        payload: payload ?? const <String, Object?>{},
        operation: payload == null ? SyncOperation.delete : SyncOperation.upsert,
      ));

  /// The snapshot of the last sync.
  final ScopeSnapshotLedger ledger;

  /// Receives one change: a payload for an upsert, null for a delete.
  final Future<void> Function(LanSyncScope scope, String entityId, Map<String, Object?>? payload) record;

  /// The live entries of a scope: entity id → payload.
  final Future<Map<String, Map<String, Object?>>> Function(LanSyncScope scope) currentOf;

  /// Records every difference between the live [scopes] and the ledger,
  /// then moves the ledger up to date. Answers how many changes went in.
  Future<int> recordChanges(Iterable<LanSyncScope> scopes) async {
    var recorded = 0;
    for (final scope in scopes) {
      final current = await currentOf(scope);
      final previous = ledger.entriesOf(scope);
      for (final entry in current.entries) {
        final before = previous[entry.key];
        if (before != null && jsonEncode(before) == jsonEncode(entry.value)) continue;
        await record(scope, entry.key, entry.value);
        recorded++;
      }
      for (final id in previous.keys) {
        if (current.containsKey(id)) continue;
        await record(scope, id, null);
        recorded++;
      }
      await ledger.replaceScope(scope, current);
    }
    return recorded;
  }
}

/// The writes one scope makes into the host's data, and the read that
/// lists it for the detector.
typedef ScopeSource = ({
  Future<Map<String, Map<String, Object?>>> Function() current,
  Future<void> Function(String entityId, Map<String, Object?> payload) upsert,
  Future<void> Function(String entityId) delete,
  Future<void> Function()? afterBatch,
});

/// One adapter per scope, over a [ScopeSource]: applies what arrives from a
/// peer straight into the host's store and remembers it in the ledger so
/// the detector does not echo it back.
///
/// Conflicts escalate: the host's policy (prefer local or remote) decides
/// at the engine, and the rest land in the conflicts list for the user.
final class ScopedSyncAdapter implements LanSyncDataAdapter {
  /// The adapter for [syncScope], resolving [open] lazily — the stores may
  /// not be up when the engine is composed.
  ScopedSyncAdapter({required this.syncScope, required this.open, required this.ledger});

  /// The scope this adapter serves.
  final LanSyncScope syncScope;

  /// Resolves the source lazily; a null answer fails the batch's changes
  /// per change, and the engine retries the scope on the next sync.
  final Future<ScopeSource?> Function() open;

  /// The snapshot ledger every apply updates.
  final ScopeSnapshotLedger ledger;

  @override
  String get scope => syncScope.id;

  @override
  int get schemaVersion => 1;

  @override
  ScopeSyncCapabilities get capabilities => const ScopeSyncCapabilities(
    supportsDelete: true,
    supportsBidirectional: true,
    supportsMerge: false,
    supportedPolicies: {ConflictPolicy.preferLocal, ConflictPolicy.preferRemote},
  );

  @override
  Future<SyncApplyResult> applyChanges({required List<SyncChange> changes}) async {
    final source = await open();
    if (source == null) {
      return SyncApplyResult(
        appliedCount: 0,
        failures: [
          for (final change in changes)
            SyncChangeFailure(change: change, reason: 'the ${syncScope.id} store is not open yet'),
        ],
      );
    }
    var applied = 0;
    final failures = <SyncChangeFailure>[];
    for (final change in changes) {
      try {
        if (change.isTombstone) {
          await source.delete(change.entityId);
          await ledger.markApplied(syncScope, change.entityId, null);
        } else {
          await source.upsert(change.entityId, change.payload);
          await ledger.markApplied(syncScope, change.entityId, change.payload);
        }
        applied++;
      } on Object catch (error) {
        failures.add(SyncChangeFailure(change: change, reason: 'the ${syncScope.id} entry could not be saved: $error'));
      }
    }
    if (applied > 0) await source.afterBatch?.call();
    return SyncApplyResult(appliedCount: applied, failures: failures);
  }

  @override
  Future<SyncConflictResolution> resolveConflict({required SyncChange local, required SyncChange remote}) async =>
      const EscalateResolution();
}
