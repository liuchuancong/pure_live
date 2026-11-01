import 'package:live_lan_sync/src/domain/conflict/conflict.dart'
    show ConflictPolicy, SyncConflict, SyncConflictResolution;
import 'package:live_lan_sync/src/domain/errors/errors.dart' show LanSyncError, LanSyncErrorCategory;
import 'package:live_lan_sync/src/domain/sync/sync.dart' show SyncChange, SyncOperation;

/// One synchronizable area of the host's data, e.g. `favorites`: the
/// translator between generic changes and the host's business repository
/// (spec §12).
///
/// The engine keeps the change log and does all the bookkeeping — batches,
/// cursors, duplicates, causality — so an adapter does two things: declare
/// what its data supports, and apply changes that arrive.
///
/// Local edits reach the log through the engine's `recordLocalChange`,
/// called right after the business write commits. A host whose storage
/// cannot commit both together keeps a durable "unsynced" mark with the
/// business write and records again on start-up (spec §10.2): an upsert
/// carries the entity's full state, so recording it twice is harmless.
abstract interface class LanSyncDataAdapter {
  /// The stable scope name. Identical on every device and every schema
  /// version; never derived from UI copy.
  String get scope;

  /// The payload schema version this adapter reads and writes. A peer on a
  /// different version is refused for this scope explicitly.
  int get schemaVersion;

  /// What this adapter's data supports, including the conflict policies it
  /// can honestly honour.
  ScopeSyncCapabilities get capabilities;

  /// Applies remote changes to the business store, in order.
  ///
  /// The engine only hands over changes that are causally new here: never a
  /// duplicate, never an older version, never a concurrent edit (those
  /// become conflicts). An upsert's payload is the entity's full state; a
  /// [SyncOperation.delete] removes it. Applying must still be idempotent —
  /// after a crash between this call and the engine's commit, the same
  /// changes arrive again.
  ///
  /// Per-change refusals (validation, references) land in
  /// [SyncApplyResult.failures]; the engine stops the scope's cursor before
  /// the first refused change and retries it on the next sync. Throwing
  /// fails the whole batch and commits nothing.
  Future<SyncApplyResult> applyChanges({required List<SyncChange> changes});

  /// Settles one detected concurrent modification with the merge semantics
  /// only this scope knows. Adapters that declare no merge support throw a
  /// [LanSyncError] with [LanSyncErrorCategory.conflict]; the engine then
  /// falls back to the configured policy.
  Future<SyncConflictResolution> resolveConflict({required SyncChange local, required SyncChange remote});
}

/// What a scope's data supports, and how clashes should be settled.
final class ScopeSyncCapabilities {
  /// The capability declaration.
  const new({
    required this.supportsDelete,
    required this.supportsBidirectional,
    required this.supportsMerge,
    this.containsSensitiveData = false,
    this.allowsFileReferences = false,
    this.supportedPolicies = const <ConflictPolicy>{},
    this.expectedMaxBytes,
  });

  /// Whether deletions are syncable (tombstoned) or the scope is append-only.
  final bool supportsDelete;

  /// Whether peers may write into this scope here. False keeps the scope
  /// serve-only: peers can pull it, nothing is accepted into it.
  final bool supportsBidirectional;

  /// Whether [LanSyncDataAdapter.resolveConflict] can actually merge.
  final bool supportsMerge;

  /// Whether payloads carry data the user should explicitly opt into
  /// syncing (tokens, cookies, credentials). The engine surfaces this so a
  /// host can gate the scope behind a confirmation.
  final bool containsSensitiveData;

  /// Whether payloads may reference files the transfer subsystem must move.
  final bool allowsFileReferences;

  /// The conflict policies this adapter honours. [ConflictPolicy.merge]
  /// without [supportsMerge] is contradictory and fails validation.
  final Set<ConflictPolicy> supportedPolicies;

  /// A rough upper bound of the scope's size, so the engine can warn before
  /// a gigabyte of settings decides to travel.
  final int? expectedMaxBytes;

  /// Whether [policy] may be applied to this scope. [ConflictPolicy.manual]
  /// is always available: it hands the decision to the host's UI.
  bool honours(ConflictPolicy policy) => policy == ConflictPolicy.manual || supportedPolicies.contains(policy);
}

/// What applying a batch did.
final class SyncApplyResult {
  /// The outcome of one applied batch.
  const new({
    required this.appliedCount,
    this.duplicateCount = 0,
    this.conflicts = const <SyncConflict>[],
    this.failures = const <SyncChangeFailure>[],
  });

  /// Changes durably applied to the business store.
  final int appliedCount;

  /// Changes recognized as already applied and skipped.
  final int duplicateCount;

  /// Concurrent modifications the adapter detected but did not settle.
  final List<SyncConflict> conflicts;

  /// Changes refused, with the reason each.
  final List<SyncChangeFailure> failures;

  /// Whether the batch fully applied with nothing left to decide.
  bool get isClean => conflicts.isEmpty && failures.isEmpty;
}

/// One change's refusal, with the reason.
final class SyncChangeFailure {
  /// A refused change.
  const new({required this.change, required this.reason});

  /// The refused change.
  final SyncChange change;

  /// A safe, user-presentable reason (validation rule name, schema
  /// mismatch); never the payload itself.
  final String reason;
}
