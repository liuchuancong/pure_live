import 'package:live_lan_sync/live_lan_sync.dart';

/// The writes the favorites adapter makes into the host's store.
typedef FavoritesApplier = ({
  Future<void> Function(String identityKey, Map<String, Object?> payload) upsert,
  Future<void> Function(String identityKey) delete,
});

/// The `favorites` scope: followed rooms as generic changes (spec §12).
///
/// The engine keeps the change log and drives every exchange; this adapter
/// only applies what arrives, straight into the host's repository — not
/// through `FollowsController`, so a remote apply never re-enters the
/// recording path the UI uses (the echo hazard of spec §10.2). Local edits
/// reach the log through `SyncEngine.recordLocalChange` in the host's
/// follow/unfollow hook, one `upsert` per favorite carrying the room's
/// full JSON.
final class FavoritesSyncAdapter implements LanSyncDataAdapter {
  /// An adapter whose `openRepository` callback resolves the writes lazily —
  /// the database may not be up when the engine is composed. A null answer
  /// fails the batch's changes per change, and the engine retries the scope
  /// on the next sync.
  FavoritesSyncAdapter({required this.openRepository});

  /// Resolves the repository writes lazily; a null answer fails the batch's
  /// changes per change, and the engine retries the scope on the next sync.
  final Future<FavoritesApplier?> Function() openRepository;

  @override
  String get scope => 'favorites';

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
    final applier = await openRepository();
    if (applier == null) {
      return SyncApplyResult(
        appliedCount: 0,
        failures: [
          for (final change in changes)
            SyncChangeFailure(change: change, reason: 'the favorites store is not open yet'),
        ],
      );
    }
    var applied = 0;
    final failures = <SyncChangeFailure>[];
    for (final change in changes) {
      try {
        if (change.isTombstone) {
          await applier.delete(change.entityId);
        } else {
          await applier.upsert(change.entityId, change.payload);
        }
        applied++;
      } on Object catch (error) {
        failures.add(SyncChangeFailure(change: change, reason: 'the favorite could not be saved: $error'));
      }
    }
    return SyncApplyResult(appliedCount: applied, failures: failures);
  }

  @override
  Future<SyncConflictResolution> resolveConflict({required SyncChange local, required SyncChange remote}) async =>
      const EscalateResolution();
}
