import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:live_storage/live_storage.dart' show JsonStore, StoragePrefs, StorageStores;

/// The engine's [LanSyncStore] over the app's Drift database: one
/// `JsonStore` namespace per fact family, the sequence counter in
/// `StoragePrefs`.
///
/// Layout (spec §15.2):
///
/// * `lan_sync_log` — the change log; key `scope/entityId`, value the
///   `LoggedChange` JSON. The latest change per entity, per spec.
/// * `lan_sync_cursors` — key `peer/scope`, value the cursor JSON.
/// * `lan_sync_processed` — key operation id; the idempotency ledger.
/// * `lan_sync_tasks` — key task id, value the task JSON.
/// * `lan_sync_conflicts` — key `scope/entityId`, value the conflict JSON.
/// * `lan_sync_transfers` — key transfer id, value the record JSON.
/// * `StoragePrefs['lan_sync.sequence']` — the sequence counter.
/// * `StoragePrefs['lan_sync.deviceId']` and
///   `StoragePrefs['lan_sync.trust.<id>']` — identity and trust records.
///
/// Atomicity follows the plan's §3.2: a batch commit writes the log
/// entries first (`putAll`, one database batch), then the ledger, cursor
/// and conflicts. A crash in between leaves the cursor behind the applied
/// changes; the next sync re-delivers them and the adapter's idempotent
/// apply absorbs the replay — the compensation path spec §15.3 names for
/// stores without cross-store transactions.
final class DriftLanSyncStore implements LanSyncStore {
  /// A store over the given namespaces, opened through
  /// `StorageStores.instance.openStore`.
  DriftLanSyncStore({
    required JsonStore logStore,
    required JsonStore cursorStore,
    required JsonStore processedStore,
    required JsonStore taskStore,
    required JsonStore conflictStore,
    required JsonStore transferStore,
  }) : _log = logStore,
       _cursors = cursorStore,
       _processed = processedStore,
       _tasks = taskStore,
       _conflicts = conflictStore,
       _transfers = transferStore;

  /// Opens every namespace this store needs.
  static Future<DriftLanSyncStore> open() async {
    Future<JsonStore> open(String namespace) => StorageStores.instance.openStore(namespace);
    return DriftLanSyncStore(
      logStore: await open('lan_sync_log'),
      cursorStore: await open('lan_sync_cursors'),
      processedStore: await open('lan_sync_processed'),
      taskStore: await open('lan_sync_tasks'),
      conflictStore: await open('lan_sync_conflicts'),
      transferStore: await open('lan_sync_transfers'),
    );
  }

  static const String _sequenceKey = 'lan_sync.sequence';
  static const String _deviceIdKey = 'lan_sync.deviceId';
  static String _trustKey(String deviceId) => 'lan_sync.trust.$deviceId';

  final JsonStore _log;
  final JsonStore _cursors;
  final JsonStore _processed;
  final JsonStore _tasks;
  final JsonStore _conflicts;
  final JsonStore _transfers;

  int _sequence = 0;
  bool _sequenceLoaded = false;

  @override
  Future<void> saveLocalDeviceId(String deviceId) => StoragePrefs.setAnyPref(_deviceIdKey, deviceId);

  @override
  Future<String?> loadLocalDeviceId() async => switch (StoragePrefs.getAnyPref(_deviceIdKey)) {
    final String id when id.isNotEmpty => id,
    _ => null,
  };

  @override
  Future<void> putDeviceTrust(DeviceTrust trust) => StoragePrefs.setAnyPref(_trustKey(trust.deviceId), trust.encode());

  @override
  Future<List<DeviceTrust>> loadDeviceTrusts() async => [
    for (final entry in StoragePrefs.snapshot().entries)
      if (entry.key.startsWith('lan_sync.trust.') && entry.value is String) DeviceTrust.decode(entry.value! as String),
  ];

  @override
  Future<DeviceTrust?> deviceTrust(String deviceId) async => switch (StoragePrefs.getAnyPref(_trustKey(deviceId))) {
    final String encoded => DeviceTrust.decode(encoded),
    _ => null,
  };

  @override
  Future<void> removeDeviceTrust(String deviceId) => StoragePrefs.setAnyPref(_trustKey(deviceId), null);

  @override
  Future<LoggedChange> recordLocalChange(SyncChange change) async {
    await _loadSequence();
    final entry = LoggedChange(sequence: ++_sequence, change: change);
    await _log.put('${change.scope}/${change.entityId}', entry.toJson());
    await _processed.put(change.operationId, true);
    _processedIds.add(change.operationId);
    await StoragePrefs.setAnyPref(_sequenceKey, _sequence);
    return entry;
  }

  @override
  Future<LoggedChange?> latestChange({required String scope, required String entityId}) async =>
      _readEntry(_log, '$scope/$entityId');

  @override
  Future<List<LoggedChange>> changesAfter({
    required String scope,
    required int afterSequence,
    required int limit,
  }) async {
    // The store is a KV, not a table: collect the scope's entries and sort
    // by sequence. The log keeps one row per entity, so a scope's scan is
    // bounded by its entity count.
    final entries = <LoggedChange>[];
    final prefix = '$scope/';
    for (final key in _log.keys) {
      if (!key.startsWith(prefix)) continue;
      final entry = _readEntry(_log, key);
      if (entry != null && entry.sequence > afterSequence) {
        entries.add(entry);
      }
    }
    entries.sort((a, b) => a.sequence.compareTo(b.sequence));
    return entries.take(limit).toList(growable: false);
  }

  @override
  Future<int> latestSequence({required String scope}) async {
    var latest = 0;
    final prefix = '$scope/';
    for (final key in _log.keys) {
      if (!key.startsWith(prefix)) continue;
      final entry = _readEntry(_log, key);
      if (entry != null && entry.sequence > latest) latest = entry.sequence;
    }
    return latest;
  }

  @override
  Future<bool> hasProcessedOperation(String operationId) async {
    if (_processedIds.contains(operationId)) return true;
    await _loadProcessed();
    return _processedIds.contains(operationId);
  }

  @override
  Future<void> commitBatch(SyncBatchCommit commit) async {
    // The log first: a crash here leaves the cursor where it was, and the
    // next sync re-delivers the batch.
    final logEntries = <String, Object?>{
      for (final change in commit.relayed) '${change.scope}/${change.entityId}': _nextEntry(change).toJson(),
    };
    if (logEntries.isNotEmpty) {
      await _log.putAll(logEntries);
    }
    // Then the ledger, cursor and conflicts.
    if (commit.processedOperationIds.isNotEmpty) {
      await _processed.putAll({for (final id in commit.processedOperationIds) id: true});
      _processedIds.addAll(commit.processedOperationIds);
    }
    for (final conflict in commit.conflicts) {
      await _conflicts.put(conflict.key, conflict.toJson());
    }
    final cursor = commit.cursor;
    if (cursor != null) {
      await _cursors.put('${cursor.peerDeviceId}/${cursor.scope}', cursor.toJson());
    }
    if (logEntries.isNotEmpty) {
      await _loadSequence();
      await StoragePrefs.setAnyPref(_sequenceKey, _sequence);
      await _log.flush();
    }
  }

  @override
  Future<void> saveCursor(SyncCursor cursor) => _cursors.put('${cursor.peerDeviceId}/${cursor.scope}', cursor.toJson());

  @override
  Future<SyncCursor?> cursorFor({required String peerDeviceId, required String scope}) async =>
      switch (_cursors.get('$peerDeviceId/$scope')) {
        final Map<Object?, Object?> json => SyncCursor.fromJson(json.cast<String, Object?>()),
        _ => null,
      };

  @override
  Future<void> saveTask(SyncTask task) => _tasks.put(task.taskId, task.toJson());

  @override
  Future<SyncTask?> task(String taskId) async => _readJson(_tasks, taskId, SyncTask.fromJson);

  @override
  Future<List<SyncTask>> tasks({int? limit}) async {
    final all = <SyncTask>[];
    for (final key in _tasks.keys) {
      final task = _readJson(_tasks, key, SyncTask.fromJson);
      if (task != null) all.add(task);
    }
    all.sort((a, b) => (b.startedAt ?? DateTime.utc(1970)).compareTo(a.startedAt ?? DateTime.utc(1970)));
    return limit == null ? all : all.take(limit).toList(growable: false);
  }

  @override
  Future<void> saveConflict(SyncConflict conflict) => _conflicts.put(conflict.key, conflict.toJson());

  @override
  Future<SyncConflict?> conflict(String key) async => _readJson(_conflicts, key, SyncConflict.fromJson);

  @override
  Future<List<SyncConflict>> pendingConflicts() async => [
    for (final key in _conflicts.keys)
      if (_readJson(_conflicts, key, SyncConflict.fromJson) case final SyncConflict conflict) conflict,
  ];

  @override
  Future<void> removeConflict(String key) => _conflicts.delete(key);

  @override
  Future<List<LoggedChange>> commitResolution({required String conflictKey, required List<SyncChange> changes}) async {
    await _loadSequence();
    final entries = <LoggedChange>[];
    final logEntries = <String, Object?>{};
    for (final change in changes) {
      final entry = _nextEntry(change);
      entries.add(entry);
      logEntries['${change.scope}/${change.entityId}'] = entry.toJson();
    }
    if (logEntries.isNotEmpty) {
      await _log.putAll(logEntries);
      await _processed.putAll({for (final change in changes) change.operationId: true});
      _processedIds.addAll(changes.map((change) => change.operationId));
      await StoragePrefs.setAnyPref(_sequenceKey, _sequence);
      await _log.flush();
    }
    await _conflicts.delete(conflictKey);
    return entries;
  }

  @override
  Future<void> saveFileTransfer(FileTransferRecord record) => _transfers.put(record.transferId, record.toJson());

  @override
  Future<FileTransferRecord?> fileTransfer(String transferId) async =>
      _readJson(_transfers, transferId, FileTransferRecord.fromJson);

  @override
  Future<List<FileTransferRecord>> fileTransfers({FileTransferDirection? direction}) async {
    final records = <FileTransferRecord>[];
    for (final key in _transfers.keys) {
      final record = _readJson(_transfers, key, FileTransferRecord.fromJson);
      if (record != null && (direction == null || record.direction == direction)) {
        records.add(record);
      }
    }
    return records;
  }

  @override
  Future<void> removeFileTransfer(String transferId) => _transfers.delete(transferId);

  // ---- internals ----

  final Set<String> _processedIds = <String>{};
  bool _processedLoaded = false;

  LoggedChange? _readEntry(JsonStore store, String key) => switch (store.get(key)) {
    final Map<Object?, Object?> json => LoggedChange.fromJson(json.cast<String, Object?>()),
    _ => null,
  };

  T? _readJson<T>(JsonStore store, String key, T Function(Map<String, Object?>) fromJson) => switch (store.get(key)) {
    final Map<Object?, Object?> json => fromJson(json.cast<String, Object?>()),
    _ => null,
  };

  /// Loads the sequence counter once: the stored value, or the log's
  /// highest sequence when the counter was lost while the log survived.
  Future<void> _loadSequence() async {
    if (_sequenceLoaded) return;
    var stored = 0;
    if (StoragePrefs.getAnyPref(_sequenceKey) case final num value) {
      stored = value.toInt();
    }
    var highest = 0;
    for (final key in _log.keys) {
      final entry = _readEntry(_log, key);
      if (entry != null && entry.sequence > highest) highest = entry.sequence;
    }
    _sequence = stored > highest ? stored : highest;
    _sequenceLoaded = true;
  }

  /// Loads the idempotency ledger once per process: the whole namespace is
  /// read eagerly because [hasProcessedOperation] is called per change.
  Future<void> _loadProcessed() async {
    if (_processedLoaded) return;
    for (final key in _processed.keys) {
      if (_processed.get(key) == true) _processedIds.add(key);
    }
    _processedLoaded = true;
  }

  LoggedChange _nextEntry(SyncChange change) => LoggedChange(sequence: ++_sequence, change: change);
}
