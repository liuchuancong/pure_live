/// The decision that settles one conflict — returned by an adapter's
/// `resolveConflict`, chosen by a policy, or made by the user.
///
/// Whatever the decision, the engine writes it as a new version that
/// causally follows *both* conflicting versions, so every device that held
/// either one adopts the decision instead of conflicting again.
sealed class SyncConflictResolution {
  /// A decision for one conflict.
  const new();
}

/// Keep this device's version.
final class UseLocalResolution extends SyncConflictResolution {
  /// Keep this device's version.
  const new();
}

/// Keep the other device's version.
final class UseRemoteResolution extends SyncConflictResolution {
  /// Keep the other device's version.
  const new();
}

/// Keep a payload merged from both versions.
final class MergedResolution extends SyncConflictResolution {
  /// Keep the merged [payload].
  const new(this.payload);

  /// The merged entity state, in the scope's current schema version.
  final Map<String, Object?> payload;
}

/// Keep both versions: the entity takes [localPayload] and a new entity
/// [copyEntityId] takes [remotePayload], for the user to sort out.
final class KeepBothResolution extends SyncConflictResolution {
  /// Keep both versions.
  const new({required this.copyEntityId, required this.localPayload, required this.remotePayload});

  /// The id of the copy that receives the other device's version. The
  /// adapter chooses it, because only it knows its id scheme.
  final String copyEntityId;

  /// The state the conflicting entity keeps.
  final Map<String, Object?> localPayload;

  /// The state the copy receives.
  final Map<String, Object?> remotePayload;
}

/// No automatic decision is honest here: leave the conflict for the user.
final class EscalateResolution extends SyncConflictResolution {
  /// Leave the conflict for the user.
  const new();
}
