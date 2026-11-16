/// The sync feature's controller: keeps the server address, auth code and
/// sync mode as preferences, owns one client session and answers the
/// server's calls against the module's providers.
library;

import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile;
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:pure_live/app/providers/network/network_providers.dart' show networkFactoryProvider;
import 'package:pure_live/modules/music/controller/music_library.dart'
    show musicFavouritesProvider, musicRecentProvider;
import 'package:pure_live/modules/music/controller/music_playlists.dart' show musicPlaylistsProvider;
import 'package:pure_live/modules/music/controller/music_sync_client.dart';
import 'package:pure_live/modules/music/controller/music_sync_data.dart';

export 'package:pure_live/modules/music/controller/music_sync_client.dart' show MusicSyncStatus;
export 'package:pure_live/modules/music/controller/music_sync_data.dart' show kMusicSyncModes;

/// The preference keys the feature keeps.
const String kMusicSyncHostKey = 'music.sync.host';
const String kMusicSyncAuthCodeKey = 'music.sync.authCode';
const String kMusicSyncModeKey = 'music.sync.mode';
const String kMusicSyncAutoKey = 'music.sync.auto';

/// The connection history's preference, the reference's `@sync_host_history`.
const String kMusicSyncHostHistoryKey = 'music.sync.hostHistory';

/// The history's cap, the reference's 最多存储20个.
const int kMusicSyncHostHistoryLimit = 20;

/// The module's answer to the reference's sync-mode dialog; the server
/// merges on the viewer's behalf using this choice.
const String kMusicSyncDefaultMode = 'merge_remote_local';

/// The preference the module keeps remote dislike rules under.
const String kMusicDislikeRemoteRulesKey = 'music.sync.dislikeRules';

/// What the settings surface watches.
final class MusicSyncState {
  const MusicSyncState({
    required this.host,
    required this.authCode,
    required this.syncMode,
    required this.status,
    required this.hostHistory,
    this.message,
    this.serverName,
  });

  final String host;
  final String authCode;
  final String syncMode;
  final MusicSyncStatus status;

  /// Addresses used before, newest first, the reference's syncHostHistory.
  final List<String> hostHistory;
  final String? message;
  final String? serverName;

  MusicSyncState copyWith({
    String? host,
    String? authCode,
    String? syncMode,
    MusicSyncStatus? status,
    List<String>? hostHistory,
    String? message,
    String? serverName,
  }) => MusicSyncState(
    host: host ?? this.host,
    authCode: authCode ?? this.authCode,
    syncMode: syncMode ?? this.syncMode,
    status: status ?? this.status,
    hostHistory: hostHistory ?? this.hostHistory,
    message: message,
    serverName: serverName ?? this.serverName,
  );
}

/// The sync session's controller.
final class MusicSyncController extends Notifier<MusicSyncState> {
  MusicSyncClient? _client;

  @override
  MusicSyncState build() {
    ref.onDispose(_teardown);
    return MusicSyncState(
      host: StoragePrefs.getString(kMusicSyncHostKey) ?? '',
      authCode: StoragePrefs.getString(kMusicSyncAuthCodeKey) ?? '',
      syncMode: _readMode(),
      status: MusicSyncStatus.idle,
      hostHistory: _readHostHistory(),
    );
  }

  String _readMode() {
    final stored = StoragePrefs.getString(kMusicSyncModeKey);
    return kMusicSyncModes.contains(stored) ? stored! : kMusicSyncDefaultMode;
  }

  /// Saves the server address.
  Future<void> setHost(String host) async {
    state = state.copyWith(host: host);
    try {
      await StoragePrefs.setString(kMusicSyncHostKey, host.trim());
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Saves the auth code.
  Future<void> setAuthCode(String code) async {
    state = state.copyWith(authCode: code);
    try {
      await StoragePrefs.setString(kMusicSyncAuthCodeKey, code.trim());
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Saves the answer to the reference's sync-mode dialog.
  Future<void> setSyncMode(String mode) async {
    if (!kMusicSyncModes.contains(mode)) return;
    state = state.copyWith(syncMode: mode);
    try {
      await StoragePrefs.setString(kMusicSyncModeKey, mode);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// The stored connection history; anything not a string list reads as
  /// empty, a damaged store must not break the pane.
  List<String> _readHostHistory() {
    try {
      final raw = StoragePrefs.getString(kMusicSyncHostHistoryKey);
      if (raw == null || raw.isEmpty) return const [];
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final entry in decoded)
          if (entry is String) entry,
      ];
    } on FormatException {
      return const [];
    }
  }

  /// Records an address at connect time, the reference's add-on-enable:
  /// a duplicate stays where it is (the reference returns early), newest
  /// first, at most twenty kept.
  Future<void> _recordHostHistory(String host) async {
    final history = musicSyncNextHostHistory(state.hostHistory, host);
    if (identical(history, state.hostHistory)) return;
    state = state.copyWith(hostHistory: history);
    try {
      await StoragePrefs.setString(kMusicSyncHostHistoryKey, jsonEncode(history));
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Drops one address from the history.
  Future<void> removeHostHistory(int index) async {
    if (index < 0 || index >= state.hostHistory.length) return;
    final history = [...state.hostHistory]..removeAt(index);
    state = state.copyWith(hostHistory: history);
    try {
      await StoragePrefs.setString(kMusicSyncHostHistoryKey, jsonEncode(history));
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Disconnects and forgets the stored key, so the next connect re-auths
  /// with the code.
  Future<void> forgetKey() async {
    await musicSyncWriteKeyInfo(null);
    // copyWith clears by assignment; passing null is deliberate.
    // ignore: avoid_redundant_argument_values
    state = state.copyWith(serverName: null, message: '已清除服务器授权');
  }

  /// Connects, auths, opens the socket and wires the handlers.
  Future<void> connect() async {
    final address = MusicSyncAddress.parse(state.host);
    if (address == null) {
      state = state.copyWith(status: MusicSyncStatus.failed, message: '服务器地址不合法');
      return;
    }
    // The reference records the address the moment sync is switched on,
    // whether or not the connection then succeeds.
    unawaited(_recordHostHistory(state.host.trim()));
    await _teardown();
    final http = ref.read(networkFactoryProvider).create(profile: ClientProfile.api);
    final client = MusicSyncClient(http: http, deviceName: musicSyncDeviceName());
    _client = client;
    client.status.listen((status) {
      if (_client == client) state = state.copyWith(status: status);
    });
    _registerHandlers(client);
    try {
      await client.readServerId(address);
      final keyInfo = await client.auth(address, state.authCode, musicSyncReadKeyInfo());
      await musicSyncWriteKeyInfo(keyInfo);
      await client.connect(address, keyInfo);
      if (_client == client) {
        // copyWith clears by assignment; passing null is deliberate.
        // ignore: avoid_redundant_argument_values
        state = state.copyWith(status: MusicSyncStatus.connected, serverName: keyInfo.serverName, message: null);
      }
    } on Object catch (error) {
      if (_client == client) state = state.copyWith(status: MusicSyncStatus.failed, message: error.toString());
      await _teardown();
    }
  }

  /// Closes the session.
  Future<void> disconnect() => _teardown();

  void _registerHandlers(MusicSyncClient client) {
    client
      ..registerHandler(
        'getEnabledFeatures',
        (args) => <String, Object?>{
          'list': <String, Object?>{'skipSnapshot': false},
          'dislike': <String, Object?>{'skipSnapshot': false},
        },
      )
      ..registerHandler('finished', (args) => null)
      // The next registrations answer the server's pull-based sync calls.
      ..registerPushHandler('onListSyncAction', (args) => _applyListAction(args.firstOrNull))
      ..registerHandler('list_sync_get_md5', (args) => musicSyncMd5Of(_localListData()))
      ..registerHandler('list_sync_get_sync_mode', (args) => state.syncMode)
      ..registerHandler('list_sync_get_list_data', (args) => _localListData())
      ..registerHandler('list_sync_set_list_data', (args) {
        unawaited(_overwriteLocalLists(args.firstOrNull));
        return null;
      })
      ..registerHandler('list_sync_finished', (args) => null)
      // --- dislike ---
      ..registerPushHandler('onDislikeSyncAction', (args) => _applyDislikeAction(args.firstOrNull))
      ..registerHandler('dislike_sync_get_md5', (args) => musicSyncMd5Of(_dislikeRules()))
      ..registerHandler('dislike_sync_get_sync_mode', (args) => state.syncMode)
      ..registerHandler('dislike_sync_get_list_data', (args) => _dislikeRules())
      ..registerHandler('dislike_sync_set_list_data', (args) {
        unawaited(_storeRemoteDislikeRules(args.firstOrNull));
        return null;
      })
      ..registerHandler('dislike_sync_finished', (args) => null);
  }

  /// The module's list data in the reference's shape.
  Map<String, Object?> _localListData() => musicSyncListDataFromState(
    ref.read(musicRecentProvider),
    ref.read(musicFavouritesProvider),
    ref.read(musicPlaylistsProvider),
  );

  Future<void> _overwriteLocalLists(Object? listData) async {
    final decoded = musicSyncApplyListData(listData);
    await ref.read(musicRecentProvider.notifier).replaceAll(decoded.recent);
    await ref.read(musicFavouritesProvider.notifier).replaceAll(decoded.favourites);
    await ref.read(musicPlaylistsProvider.notifier).replaceAll(decoded.playlists);
  }

  Object? _dislikeRules() {
    try {
      return StoragePrefs.getString(kMusicDislikeRemoteRulesKey) ?? '';
    } on Object {
      return '';
    }
  }

  Future<void> _storeRemoteDislikeRules(Object? rules) async {
    final text = rules is String ? rules : '';
    try {
      await StoragePrefs.setString(kMusicDislikeRemoteRulesKey, text);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// The reference's list actions arrive as `{action, data}` maps; the
  /// overwrite form replaces the module's lists wholesale. The fine-grained
  /// per-list actions are not produced by the module's own editing surface,
  /// so they are honoured as full refreshes.
  void _applyListAction(Object? action) {
    if (action is! Map) return;
    final data = action['data'];
    if (action['action'] == 'list_data_overwrite') {
      unawaited(_overwriteLocalLists(data));
    }
  }

  void _applyDislikeAction(Object? action) {
    if (action is! Map) return;
    if (action['action'] == 'dislike_data_overwrite') {
      unawaited(_storeRemoteDislikeRules(action['data']));
    }
  }

  Future<void> _teardown() async {
    final client = _client;
    _client = null;
    if (client != null) await client.disconnect();
  }

  /// Pushes the module's current lists at the server — the local-change
  /// path, called after the viewer edits a list.
  void pushListsChanged() {
    final client = _client;
    if (client == null || !client.isConnected) return;
    client.push('onListSyncAction', [
      <String, Object?>{'action': 'list_data_overwrite', 'data': _localListData()},
    ]);
  }

  /// Pushes the module's dislike rules at the server.
  void pushDislikesChanged() {
    final client = _client;
    if (client == null || !client.isConnected) return;
    client.push('onDislikeSyncAction', [
      <String, Object?>{'action': 'dislike_data_overwrite', 'data': _dislikeRules()},
    ]);
  }
}

/// The sync session.
final musicSyncProvider = NotifierProvider<MusicSyncController, MusicSyncState>(MusicSyncController.new);

/// The next connection history for a used address, the reference's
/// addSyncHostHistory: a duplicate leaves the list untouched, a new address
/// goes to the front, and at most [kMusicSyncHostHistoryLimit] survive.
List<String> musicSyncNextHostHistory(List<String> history, String host) {
  if (host.isEmpty || history.contains(host)) return history;
  final next = [host, ...history];
  return next.length > kMusicSyncHostHistoryLimit ? next.sublist(0, kMusicSyncHostHistoryLimit) : next;
}
