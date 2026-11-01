import 'package:live_lan_sync/src/domain/conflict/conflict.dart'
    show ConflictPolicy, SyncConflict, SyncConflictResolution;
import 'package:live_lan_sync/src/domain/transfer/transfer.dart' show FileTransferRecord;

/// Something the engine reports to the host as it happens (spec §17).
///
/// Events notify; they never replace persisted state. After a restart the
/// store — not whatever events were seen before — says which conflicts are
/// open and how tasks ended.
sealed class LanSyncEvent {
  /// An engine event.
  const new();
}

/// Two devices changed the same entity without seeing each other's change.
final class SyncConflictDetected extends LanSyncEvent {
  /// A conflict detected under [policy].
  const new({required this.conflict, required this.policy});

  /// The conflicting versions, as persisted.
  final SyncConflict conflict;

  /// The policy the scope applies here. [ConflictPolicy.manual] means the
  /// conflict waits for the user; any other is attempted at once and
  /// followed by [SyncConflictResolved] — or by nothing, when the adapter
  /// escalated or refused and the conflict waits for the user after all.
  final ConflictPolicy policy;
}

/// A conflict was settled and its decision written as a new version.
final class SyncConflictResolved extends LanSyncEvent {
  /// A conflict settled by [resolution].
  const new({required this.conflict, required this.resolution, required this.automatic});

  /// The conflict as it was settled.
  final SyncConflict conflict;

  /// The decision.
  final SyncConflictResolution resolution;

  /// Whether a policy decided (true) or the user did (false).
  final bool automatic;
}

/// A conflict no longer needed a decision: a newer version that follows
/// both conflicting versions arrived — another device settled it first.
final class SyncConflictSuperseded extends LanSyncEvent {
  /// A conflict settled elsewhere.
  const new({required this.conflict});

  /// The conflict as it was recorded.
  final SyncConflict conflict;
}

/// A file transfer moved forward or ended; [transfer] says where it stands
/// (spec §17: progress, completion and failure in one event).
final class FileTransferUpdated extends LanSyncEvent {
  /// A transfer at its current state.
  const new(this.transfer);

  /// The transfer as persisted now.
  final FileTransferRecord transfer;
}
