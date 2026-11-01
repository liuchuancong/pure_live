import 'package:live_lan_sync/src/domain/conflict/conflict.dart' show SyncConflict;
import 'package:live_lan_sync/src/domain/device/device.dart' show DeviceTrust;
import 'package:live_lan_sync/src/domain/sync/sync.dart' show LoggedChange, SyncChange, SyncCursor, SyncTask;
import 'package:live_lan_sync/src/domain/transfer/transfer.dart' show FileTransferDirection, FileTransferRecord;

/// Everything one received batch changes in the store, committed as one
/// unit by [LanSyncStore.commitBatch] (spec §15.3).
final class SyncBatchCommit {
  /// One batch's effects.
  const new({
    required this.peerDeviceId,
    required this.scope,
    this.relayed = const <SyncChange>[],
    this.processedOperationIds = const <String>{},
    this.conflicts = const <SyncConflict>[],
    this.cursor,
  });

  /// The device the batch came from.
  final String peerDeviceId;

  /// The scope the batch belongs to.
  final String scope;

  /// Remote changes the adapter applied. Each is appended to this device's
  /// change log (taking the next sequence, replacing the entity's previous
  /// entry) so other devices can follow it here, and its operation id is
  /// recorded as processed.
  final List<SyncChange> relayed;

  /// Operations handled without being applied — duplicates, stale
  /// versions, conflicts — recorded as processed so they never return.
  final Set<String> processedOperationIds;

  /// Concurrent modifications to keep for the user to settle.
  final List<SyncConflict> conflicts;

  /// The advanced cursor, or null when the batch made no progress.
  final SyncCursor? cursor;
}

/// Every durable fact the sync engine owns, provided by the host.
///
/// The engine never opens a database: identity, trust, the change log, the
/// idempotency ledger, cursors, tasks and open conflicts all go through this
/// interface (spec §15). A host binds whatever it already has (Hive CE,
/// SQLite, files) behind it; the package forces none.
///
/// **The change log** keeps the latest change per (scope, entity), ordered
/// by one strictly increasing sequence counter: appending a change for an
/// entity replaces its previous entry and gives it the next sequence. Deletes
/// are entries like any other — tombstones — and stay until a newer change
/// of the same entity replaces them, so a delete propagates to every device
/// and an older version can never resurrect the entity (spec §11.4).
///
/// **Consistency duties** (spec §15.3), each the implementation's to keep:
///
/// - [recordLocalChange] and [commitBatch] are atomic: all of their effects
///   land, or none do. A crash in between must not leave a cursor ahead of
///   the changes it vouches for, nor a relayed change without its
///   processed mark.
/// - The processed-operation ledger is never lost; it is what makes a
///   peer's retry harmless.
/// - Sequences only ever grow, across restarts.
///
/// Calls may arrive from any isolate the host runs the engine on.
abstract interface class LanSyncStore {
  /// Persists the local device id this installation keeps forever.
  Future<void> saveLocalDeviceId(String deviceId);

  /// The local device id, or null before the first boot.
  Future<String?> loadLocalDeviceId();

  /// Adds or updates a trust record for its device.
  Future<void> putDeviceTrust(DeviceTrust trust);

  /// Every trust record, revoked ones included.
  Future<List<DeviceTrust>> loadDeviceTrusts();

  /// The trust record for [deviceId], or null when never paired.
  Future<DeviceTrust?> deviceTrust(String deviceId);

  /// Removes the trust record entirely. Prefer [putDeviceTrust] with a
  /// revoked record when the refusal reason should survive.
  Future<void> removeDeviceTrust(String deviceId);

  /// Atomically appends a change this device made to the change log and
  /// records its operation id as processed, so the change never echoes back
  /// as new. Returns the entry with its assigned sequence.
  Future<LoggedChange> recordLocalChange(SyncChange change);

  /// The current entry for one entity, or null when the log never saw it.
  /// Its change carries the entity's current version vector.
  Future<LoggedChange?> latestChange({required String scope, required String entityId});

  /// Up to [limit] entries of [scope] with a sequence above
  /// [afterSequence], in sequence order. Must not load the whole log into
  /// memory to answer.
  Future<List<LoggedChange>> changesAfter({required String scope, required int afterSequence, required int limit});

  /// The highest sequence in [scope]'s log, or 0 when it is empty.
  Future<int> latestSequence({required String scope});

  /// Whether [operationId] was already handled here — the idempotency check
  /// every incoming change goes through (spec §10.4).
  Future<bool> hasProcessedOperation(String operationId);

  /// Atomically commits one received batch: relayed changes, processed
  /// operation ids, conflicts and the advanced cursor.
  Future<void> commitBatch(SyncBatchCommit commit);

  /// Persists a cursor. Overwrites the previous position for the same
  /// (peer, scope).
  Future<void> saveCursor(SyncCursor cursor);

  /// The cursor for [peerDeviceId] and [scope], or null before the first
  /// exchange.
  Future<SyncCursor?> cursorFor({required String peerDeviceId, required String scope});

  /// Adds or updates a task record.
  Future<void> saveTask(SyncTask task);

  /// The task with [taskId], or null when unknown.
  Future<SyncTask?> task(String taskId);

  /// Task records, newest first; at most [limit] when given. Implementations
  /// should cap history; the retention choice is the host's.
  Future<List<SyncTask>> tasks({int? limit});

  /// Atomically writes a conflict's resolution: appends [changes] to the
  /// change log as local changes (processed, each taking the next sequence)
  /// and drops the conflict record [conflictKey]. Returns the entries.
  Future<List<LoggedChange>> commitResolution({required String conflictKey, required List<SyncChange> changes});

  /// Records an open conflict for the host's UI to settle.
  Future<void> saveConflict(SyncConflict conflict);

  /// The open conflict with [key], or null.
  Future<SyncConflict?> conflict(String key);

  /// Every still-open conflict.
  Future<List<SyncConflict>> pendingConflicts();

  /// Drops the conflict record for [key] once it is settled.
  Future<void> removeConflict(String key);

  /// Adds or updates a file transfer record — including which chunks are
  /// durably here, the state a resumed transfer starts from.
  Future<void> saveFileTransfer(FileTransferRecord record);

  /// The transfer [transferId], or null.
  Future<FileTransferRecord?> fileTransfer(String transferId);

  /// Every transfer record, of one [direction] when given.
  Future<List<FileTransferRecord>> fileTransfers({FileTransferDirection? direction});

  /// Removes the record [transferId].
  Future<void> removeFileTransfer(String transferId);
}
