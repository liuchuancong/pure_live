import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart' show IptvKeys;
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/settings/settings_refresh.dart' show refreshSettings;
import 'package:pure_live/features/backup/document/backup_repository.dart' show BackupRepository;
import 'package:pure_live/features/backup/document/backup_settings.dart';
import 'package:pure_live/features/backup/panes/backup_actions.dart' show includeSecretsAllowed;
import 'package:pure_live/features/backup/webdav/webdav_settings.dart' show appSecretStoreProvider;
import 'package:pure_live/features/lan_sync/data/scoped_sync.dart' show ScopeSource;
import 'package:pure_live/features/lan_sync/data/sync_scopes.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_controller.dart' show iptvLibraryProvider;
import 'package:pure_live/modules/live/areas/areas.dart' show areaFollowRepositoryProvider;
import 'package:pure_live/modules/live/history/history.dart' show historyRepositoryProvider;
import 'package:pure_live/modules/live/multiview/multiview_controller.dart'
    show multiviewProvider, multiviewRepositoryProvider;
import 'package:pure_live/modules/live/recorder/data/recording_repository.dart' show recordingRepositoryProvider;
import 'package:pure_live/modules/live/recorder/data/recording_task.dart';

/// Where each scope's data lives in this app, as the one [ScopeSource]
/// shape the adapter and the change detector share. The favorites are not
/// here: their repository records its own edits through the runtime.
///
/// Every source answers null while its store is not open yet; the adapter
/// then fails the batch per change and the engine retries next time.
Future<ScopeSource?> openScopeSource(Ref ref, LanSyncScope scope) async {
  try {
    return switch (scope) {
      LanSyncScope.favorites => null,
      LanSyncScope.areaFollows => _storeSource((await ref.read(areaFollowRepositoryProvider.future)).store),
      LanSyncScope.history => _storeSource((await ref.read(historyRepositoryProvider.future)).store),
      LanSyncScope.recordings => _recordingsSource((await ref.read(recordingRepositoryProvider.future)).store),
      LanSyncScope.iptv => _iptvSource(ref, await StorageStores.instance.openStore(IptvKeys.table)),
      LanSyncScope.multiview => _multiviewSource(ref, (await ref.read(multiviewRepositoryProvider.future)).store),
      LanSyncScope.secrets =>
        includeSecretsAllowed() ? _secretsSource(await ref.read(appSecretStoreProvider.future)) : null,
      _ => _settingsSource(ref, scope),
    };
  } on Object {
    return null;
  }
}

/// A keyed box as-is: the entry's JSON is the payload.
ScopeSource _storeSource(JsonStore store) => (
  current: () async => {
    for (final entry in store.entries.entries)
      if (entry.value case final Map<Object?, Object?> value) entry.key: Map<String, Object?>.from(value),
  },
  upsert: (id, payload) => store.put(id, payload),
  delete: store.delete,
  afterBatch: store.flush,
);

/// The IPTV setup: entity = one of the setup keys, payload `{items}`. The
/// fetched channels and programmes stay local; the library re-reads its
/// store after a batch.
ScopeSource _iptvSource(Ref ref, JsonStore store) => (
  current: () async => {
    for (final key in BackupRepository.iptvSetupKeys)
      if (store.entries[key] case final List<Object?> items) key: {'items': items},
  },
  upsert: (key, payload) async {
    if (!BackupRepository.iptvSetupKeys.contains(key)) return;
    final items = payload['items'];
    if (items is List) await store.put(key, items);
  },
  delete: (key) async {
    if (BackupRepository.iptvSetupKeys.contains(key)) await store.put(key, const <Object?>[]);
  },
  afterBatch: () async {
    await store.flush();
    ref.invalidate(iptvLibraryProvider);
  },
);

/// The multiview documents as-is; the controller re-reads after a batch.
ScopeSource _multiviewSource(Ref ref, JsonStore store) => (
  current: () async => {
    for (final entry in store.entries.entries)
      if (entry.value case final Map<Object?, Object?> value) entry.key: Map<String, Object?>.from(value),
  },
  upsert: (id, payload) => store.put(id, payload),
  delete: store.delete,
  afterBatch: () async {
    await store.flush();
    ref.invalidate(multiviewProvider);
  },
);

/// The setup fields of a recording task: what the user decided, not what a
/// machine was doing. Everything volatile — the take's state, progress,
/// file, error and post-processing — stays off the wire so a recording in
/// progress does not churn the log every second.
const Set<String> _recordingSetupKeys = {
  'id',
  'platform',
  'roomId',
  'roomTitle',
  'quality',
  'scheduleEnabled',
  'scheduleDays',
  'scheduleStart',
  'scheduleEnd',
  'stopAtWindowEnd',
};

Map<String, Object?> _recordingSetupOf(Map<String, Object?> json) => {
  for (final key in _recordingSetupKeys)
    if (json.containsKey(key)) key: json[key],
};

/// The recording tasks, projected to their setup. A remote task lands as
/// a waiting one; a remote edit of a task this device is recording right
/// now is refused for this round (the running take owns its entry).
ScopeSource _recordingsSource(JsonStore store) => (
  current: () async => {
    for (final entry in store.entries.entries)
      if (entry.value case final Map<Object?, Object?> value)
        entry.key: _recordingSetupOf(Map<String, Object?>.from(value)),
  },
  upsert: (id, payload) async {
    final existing = store.entries[id];
    if (existing is Map) {
      final local = RecordingTask.fromJson(Map<String, Object?>.from(existing));
      if (local.isRunning || local.postProcessing) throw StateError('the task is recording on this device');
      await store.put(id, {...Map<String, Object?>.from(existing), ..._recordingSetupOf(payload), 'id': id});
      return;
    }
    final task = RecordingTask.fromJson({...payload, 'id': id});
    if (task.platform.isEmpty || task.roomId.isEmpty) throw StateError('the task names no room');
    await store.put(id, task.copyWith(state: RecordingTaskState.waiting).toJson());
  },
  delete: (id) async {
    final existing = store.entries[id];
    if (existing is Map) {
      final local = RecordingTask.fromJson(Map<String, Object?>.from(existing));
      if (local.isRunning || local.postProcessing) throw StateError('the task is recording on this device');
    }
    await store.delete(id);
  },
  afterBatch: store.flush,
);

final Map<String, BackupPrefKind> _kindOf = {for (final (key, kind) in kBackedUpPrefs) key: kind};

/// One group of the settings prefs: entity = the pref key, payload
/// `{value}`. A remote delete means nothing for a pref and is ignored; the
/// batch ends with the window's providers re-reading the store.
ScopeSource _settingsSource(Ref ref, LanSyncScope scope) => (
  current: () async {
    final out = <String, Map<String, Object?>>{};
    for (final key in scope.prefKeys) {
      final value = _readPref(key);
      if (value != null) out[key] = {'value': value};
    }
    return out;
  },
  upsert: (key, payload) async {
    if (LanSyncScope.ofPrefKey(key) != scope) return;
    await _writePref(key, payload['value']);
  },
  delete: (_) async {},
  afterBatch: () async => refreshSettings(ref),
);

Object? _readPref(String key) {
  try {
    return switch (_kindOf[key]) {
      BackupPrefKind.string => StoragePrefs.getString(key),
      BackupPrefKind.boolean => StoragePrefs.getBool(key),
      BackupPrefKind.integer => StoragePrefs.getInt(key),
      BackupPrefKind.floating => StoragePrefs.getDouble(key),
      BackupPrefKind.stringList => StoragePrefs.getStringList(key),
      null => null,
    };
  } on Object {
    return null;
  }
}

Future<void> _writePref(String key, Object? value) async {
  if (value == null) return;
  switch (_kindOf[key]) {
    case BackupPrefKind.string:
      if (value is String) await StoragePrefs.setString(key, value);
    case BackupPrefKind.boolean:
      if (value is bool) await StoragePrefs.setBool(key, value);
    case BackupPrefKind.integer:
      if (value is int) await StoragePrefs.setInt(key, value);
    case BackupPrefKind.floating:
      if (value is num) await StoragePrefs.setDouble(key, value.toDouble());
    case BackupPrefKind.stringList:
      if (value is List && value.every((entry) => entry is String)) {
        await StoragePrefs.setStringList(key, List<String>.from(value));
      }
    case null:
      return;
  }
}

/// The vault: entity = the secret ref, payload `{value}`.
ScopeSource _secretsSource(SecretStore vault) => (
  current: () async => {
    for (final ref in vault.refs) ref: {'value': vault.value(ref) ?? ''},
  },
  upsert: (ref, payload) async {
    final value = payload['value'];
    if (value is! String || value.isEmpty) {
      await vault.remove(ref);
    } else {
      await vault.set(ref, value);
    }
  },
  delete: vault.remove,
  afterBatch: null,
);
