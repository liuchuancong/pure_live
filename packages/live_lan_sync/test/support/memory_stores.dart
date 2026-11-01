import 'package:live_lan_sync/live_lan_sync.dart';

/// An in-memory [LanSyncStore] for tests: real semantics, no I/O. Not
/// final, so fault-injection tests can override single operations.
class MemoryLanSyncStore implements LanSyncStore {
  String? _deviceId;
  int _sequence = 0;
  final Map<String, DeviceTrust> _trusts = {};
  final Map<String, Map<String, LoggedChange>> _log = {};
  final Set<String> _processed = <String>{};
  final Map<String, SyncCursor> _cursors = <String, SyncCursor>{};
  final Map<String, SyncTask> _tasks = <String, SyncTask>{};
  final Map<String, SyncConflict> _conflicts = <String, SyncConflict>{};

  @override
  Future<void> saveLocalDeviceId(String deviceId) async => _deviceId = deviceId;

  @override
  Future<String?> loadLocalDeviceId() async => _deviceId;

  @override
  Future<void> putDeviceTrust(DeviceTrust trust) async => _trusts[trust.deviceId] = trust;

  @override
  Future<List<DeviceTrust>> loadDeviceTrusts() async => List.unmodifiable(_trusts.values);

  @override
  Future<DeviceTrust?> deviceTrust(String deviceId) async => _trusts[deviceId];

  @override
  Future<void> removeDeviceTrust(String deviceId) async => _trusts.remove(deviceId);

  @override
  Future<LoggedChange> recordLocalChange(SyncChange change) async {
    _processed.add(change.operationId);
    return _append(change);
  }

  @override
  Future<LoggedChange?> latestChange({required String scope, required String entityId}) async => _log[scope]?[entityId];

  @override
  Future<List<LoggedChange>> changesAfter({
    required String scope,
    required int afterSequence,
    required int limit,
  }) async {
    final entries = [
      for (final entry in _log[scope]?.values ?? const <LoggedChange>[])
        if (entry.sequence > afterSequence) entry,
    ]..sort((a, b) => a.sequence.compareTo(b.sequence));
    return entries.take(limit).toList(growable: false);
  }

  @override
  Future<int> latestSequence({required String scope}) async =>
      (_log[scope]?.values ?? const <LoggedChange>[]).fold<int>(0, (top, e) => e.sequence > top ? e.sequence : top);

  @override
  Future<bool> hasProcessedOperation(String operationId) async => _processed.contains(operationId);

  @override
  Future<void> commitBatch(SyncBatchCommit commit) async {
    for (final change in commit.relayed) {
      _processed.add(change.operationId);
      _append(change);
    }
    _processed.addAll(commit.processedOperationIds);
    for (final conflict in commit.conflicts) {
      _conflicts[conflict.key] = conflict;
    }
    final cursor = commit.cursor;
    if (cursor != null) {
      _cursors['${cursor.peerDeviceId}/${cursor.scope}'] = cursor;
    }
  }

  @override
  Future<void> saveCursor(SyncCursor cursor) async => _cursors['${cursor.peerDeviceId}/${cursor.scope}'] = cursor;

  @override
  Future<SyncCursor?> cursorFor({required String peerDeviceId, required String scope}) async =>
      _cursors['$peerDeviceId/$scope'];

  @override
  Future<void> saveTask(SyncTask task) async => _tasks[task.taskId] = task;

  @override
  Future<SyncTask?> task(String taskId) async => _tasks[taskId];

  @override
  Future<List<SyncTask>> tasks({int? limit}) async {
    final all = _tasks.values.toList().reversed;
    return (limit == null ? all : all.take(limit)).toList(growable: false);
  }

  @override
  Future<void> saveConflict(SyncConflict conflict) async => _conflicts[conflict.key] = conflict;

  @override
  Future<SyncConflict?> conflict(String key) async => _conflicts[key];

  @override
  Future<List<SyncConflict>> pendingConflicts() async => List.unmodifiable(_conflicts.values);

  @override
  Future<void> removeConflict(String key) async => _conflicts.remove(key);

  @override
  Future<List<LoggedChange>> commitResolution({required String conflictKey, required List<SyncChange> changes}) async {
    final entries = [for (final change in changes) _append(change)];
    _processed.addAll(changes.map((change) => change.operationId));
    _conflicts.remove(conflictKey);
    return entries;
  }

  final Map<String, FileTransferRecord> _transfers = <String, FileTransferRecord>{};

  @override
  Future<void> saveFileTransfer(FileTransferRecord record) async => _transfers[record.transferId] = record;

  @override
  Future<FileTransferRecord?> fileTransfer(String transferId) async => _transfers[transferId];

  @override
  Future<List<FileTransferRecord>> fileTransfers({FileTransferDirection? direction}) async => [
    for (final record in _transfers.values)
      if (direction == null || record.direction == direction) record,
  ];

  @override
  Future<void> removeFileTransfer(String transferId) async => _transfers.remove(transferId);

  LoggedChange _append(SyncChange change) {
    final entry = LoggedChange(sequence: ++_sequence, change: change);
    _log.putIfAbsent(change.scope, () => <String, LoggedChange>{})[change.entityId] = entry;
    return entry;
  }
}

/// An in-memory [SecureCredentialStore] for tests; it records deletions so
/// revocation tests can assert the wipe.
final class MemoryCredentialStore implements SecureCredentialStore {
  final Map<String, List<int>> _secrets = {};

  /// Every key deleted so far, in order.
  final List<SecureKey> deletedKeys = <SecureKey>[];

  @override
  Future<void> write(SecureKey key, List<int> bytes) async => _secrets[key.id] = bytes;

  @override
  Future<List<int>?> read(SecureKey key) async => _secrets[key.id];

  @override
  Future<void> delete(SecureKey key) async {
    _secrets.remove(key.id);
    deletedKeys.add(key);
  }
}
