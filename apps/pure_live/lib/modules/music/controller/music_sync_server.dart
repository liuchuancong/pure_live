/// The LX sync protocol's server half: one HTTP endpoint that answers the
/// reference's `/hello`, `/id` and `/ah` auth routes, upgrades its
/// WebSocket, keeps a device key registry and drives the module syncs —
/// lists and dislike rules — against the app's own stores.
library;

import 'dart:async' show Completer, Timer, unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io'
    show ContentType, HttpRequest, HttpServer, InternetAddress, InternetAddressType, NetworkInterface, Platform,
        WebSocket, WebSocketTransformer;
import 'dart:math' show Random;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/modules/music/controller/music_library.dart'
    show musicFavouritesProvider, musicRecentProvider;
import 'package:pure_live/modules/music/controller/music_playlists.dart' show musicPlaylistsProvider;
import 'package:pure_live/modules/music/controller/music_settings.dart' show musicSettingsProvider;
import 'package:pure_live/modules/music/controller/music_sync.dart'
    show kMusicDislikeRemoteRulesKey, musicSyncProvider;
import 'package:pure_live/modules/music/controller/music_sync_client.dart'
    show
        kMusicSyncAuthMsg,
        kMusicSyncCloseFailed,
        kMusicSyncHelloMsg,
        kMusicSyncIdPrefix,
        kMusicSyncMsgConnect;
import 'package:pure_live/modules/music/controller/music_sync_codec.dart';
import 'package:pure_live/modules/music/controller/music_sync_data.dart';
import 'package:pure_live/modules/music/controller/music_sync_wire.dart';

/// The preference keys the server keeps.
const String kMusicSyncServerEnabledKey = 'music.sync.server.enabled';
const String kMusicSyncServerPortKey = 'music.sync.server.port';
const String kMusicSyncServerLanKey = 'music.sync.server.lan';
const String kMusicSyncServerAuthCodeKey = 'music.sync.server.authCode';
const String kMusicSyncServerIdKey = 'music.sync.server.id';
const String kMusicSyncServerDevicesKey = 'music.sync.server.devices';

/// The reference's default `sync.server.port`.
const int kMusicSyncServerDefaultPort = 9527;

/// The registry cap the reference enforces on new devices.
const int kMusicSyncServerDeviceLimit = 101;

/// One authorized device, the reference's server key info.
final class MusicSyncServerDevice {
  MusicSyncServerDevice({
    required this.clientId,
    required this.key,
    required this.deviceName,
    required this.isMobile,
    required this.lastConnectDate,
  });

  factory MusicSyncServerDevice.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('device info is not an object');
    final clientId = json['clientId'];
    final key = json['key'];
    if (clientId is! String || key is! String) throw const FormatException('device info is incomplete');
    return MusicSyncServerDevice(
      clientId: clientId,
      key: key,
      deviceName: json['deviceName'] is String ? json['deviceName'] as String : '',
      isMobile: json['isMobile'] == true,
      lastConnectDate: json['lastConnectDate'] is int ? json['lastConnectDate'] as int : 0,
    );
  }

  final String clientId;
  final String key;
  String deviceName = '';
  bool isMobile = false;
  int lastConnectDate = 0;

  Map<String, Object?> toJson() => <String, Object?>{
    'clientId': clientId,
    'key': key,
    'deviceName': deviceName,
    'isMobile': isMobile,
    'lastConnectDate': lastConnectDate,
  };
}

/// What the settings surface watches: whether the endpoint answers, why it
/// does not, and the devices authorized so far.
final class MusicSyncServerStatus {
  const MusicSyncServerStatus({required this.running, required this.devices, this.error});

  final bool running;
  final String? error;
  final List<MusicSyncServerDevice> devices;
}

/// One connected client: the socket, its key info and the RPC engine. The
/// server only calls out (`list_sync_*`, `dislike_sync_*`, `finished`); the
/// client pushes its local edits back through `onListSyncAction` and
/// `onDislikeSyncAction`.
final class MusicSyncServerSocket {
  MusicSyncServerSocket(this._socket, this.device) {
    _socket.listen(_onData, onDone: _onDone, onError: (Object _) => _onDone());
    _pinger = Timer.periodic(const Duration(seconds: 30), (_) {
      try {
        _socket.add('ping');
      } on Object {
        unawaited(close(kMusicSyncCloseFailed));
      }
    });
  }

  final WebSocket _socket;
  final MusicSyncServerDevice device;

  /// The module flags, the reference's `moduleReadys`: a module's sync must
  /// finish before that module's pushes reach the client.
  bool listReady = false;
  bool dislikeReady = false;

  /// Set when the connection is gone for any reason.
  void Function()? onClosed;

  final Map<String, Completer<Object?>> _pending = <String, Completer<Object?>>{};
  final Map<String, void Function(List<Object?> args)> _pushHandlers = <String, void Function(List<Object?> args)>{};
  Timer? _pinger;
  var _callId = 0;
  var _closed = false;

  bool get isClosed => _closed;

  /// Registers the server-side push target (`onListSyncAction`).
  void registerPushHandler(String name, void Function(List<Object?> args) handler) => _pushHandlers[name] = handler;

  /// Calls one of the client's exposed methods.
  Future<Object?> call(String name, List<Object?> args, {Duration timeout = const Duration(seconds: 120)}) {
    if (_closed) return Future.error(Exception('同步连接已断开'));
    final callName = '${name}_${DateTime.now().microsecondsSinceEpoch}_$_callId';
    _callId++;
    final completer = Completer<Object?>();
    _pending[callName] = completer;
    _send(musicSyncEncodeFrame(musicSyncEncodeRequest(callName, args, const <int>[])));
    return completer.future.timeout(timeout, onTimeout: () {
      _pending.remove(callName);
      throw Exception('同步调用超时: $name');
    });
  }

  /// Pushes an action at the client; failures close the connection, the way
  /// the reference treats a failed broadcast.
  Future<void> push(String name, List<Object?> args) async {
    try {
      await call(name, args);
    } on Object {
      await close(kMusicSyncCloseFailed);
    }
  }

  /// Closes the socket and fails everything outstanding.
  Future<void> close(int code) async {
    if (_closed) return;
    _closed = true;
    _pinger?.cancel();
    for (final completer in _pending.values) {
      completer.completeError(Exception('同步连接已断开'));
    }
    _pending.clear();
    onClosed?.call();
    try {
      await _socket.close(code, 'close');
    } on Object {
      // The peer is already gone.
    }
  }

  void _onData(Object? data) {
    if (data is! String || _closed) return;
    if (data == 'ping') return;
    final Object? decoded;
    try {
      decoded = musicSyncParseMessage(musicSyncDecodeFrame(data));
    } on Object {
      unawaited(close(kMusicSyncCloseFailed));
      return;
    }
    switch (decoded) {
      case final MusicSyncRpcRequest request:
        final handler = _pushHandlers[request.name];
        _send(musicSyncEncodeFrame(request.reply(null)));
        if (handler != null) handler(request.args);
      case final MusicSyncRpcResponse response:
        final completer = _pending.remove(response.name);
        if (completer == null) return;
        if (response.error == null) {
          completer.complete(response.result);
        } else {
          completer.completeError(Exception(response.errorMessage));
        }
      default:
        break;
    }
  }

  void _send(String frame) {
    if (_closed) return;
    try {
      _socket.add(frame);
    } on Object {
      unawaited(close(kMusicSyncCloseFailed));
    }
  }

  void _onDone() {
    unawaited(close(1000));
  }
}

/// The sync server: owns the HTTP endpoint, the device registry and the
/// module syncs. Data access goes through the injected closures so the
/// provider wires the app's stores in.
final class MusicSyncServer {
  MusicSyncServer({
    required this._readSyncMode,
    required this._readAddToTop,
    required this._readListData,
    required this._applyListData,
    required this._storeDislikeRules,
  });

  final String Function() _readSyncMode;
  final bool Function() _readAddToTop;
  final Map<String, Object?> Function() _readListData;
  final Future<void> Function(Object? listData) _applyListData;
  final Future<void> Function(String rules) _storeDislikeRules;

  /// Reports running state and device list changes to the status provider.
  void Function(MusicSyncServerStatus status)? onStatus;

  HttpServer? _http;
  int? _boundPort;
  var _lanHost = '127.0.0.1';
  final Map<String, MusicSyncServerDevice> _devices = <String, MusicSyncServerDevice>{};
  final Map<String, MusicSyncServerSocket> _sockets = <String, MusicSyncServerSocket>{};
  final Map<String, int> _authAttempts = <String, int>{};
  Timer? _attemptTimer;
  var _applyingRemote = false;
  var _syncingClientId = '';

  bool get running => _http != null;

  /// The bound address, valid while running; LAN shows the machine's LAN
  /// IPv4, loopback otherwise.
  String address(int port) => 'http://$_lanHost:$port';

  /// The devices authorized so far, newest connection first.
  List<MusicSyncServerDevice> deviceView() {
    final devices = [..._devices.values]..sort((a, b) => b.lastConnectDate.compareTo(a.lastConnectDate));
    return devices;
  }

  /// Starts the endpoint on [port]; LAN access widens the bind.
  Future<void> start(int port, {required bool lan}) async {
    if (_http != null && _boundPort == port && _isLanBound == lan) return;
    await stop();
    _loadState();
    _boundPort = port;
    _isLanBound = lan;
    _lanHost = await _hostOf(lan);
    try {
      _http = await HttpServer.bind(lan ? InternetAddress.anyIPv4 : InternetAddress.loopbackIPv4, port);
    } on Object {
      _http = null;
      _boundPort = null;
      _isLanBound = false;
      _emitStatus(error: '端口被占用或不可用');
      rethrow;
    }
    _attemptTimer = Timer.periodic(const Duration(minutes: 1), (_) => _authAttempts.clear());
    _emitStatus();
    _http!.listen(
      (request) => unawaited(_onRequest(request)),
      onError: (_) => _emitStatus(),
      onDone: _emitStatus,
    );
  }

  var _isLanBound = false;

  /// The address to advertise: the first non-loopback IPv4 on LAN, the
  /// loopback otherwise.
  Future<String> _hostOf(bool lan) async {
    if (!lan) return InternetAddress.loopbackIPv4.address;
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4) return address.address;
        }
      }
    } on Object {
      // Fall through to the host name.
    }
    return Platform.localHostname;
  }

  /// Stops the endpoint and every connected client.
  Future<void> stop() async {
    _attemptTimer?.cancel();
    _attemptTimer = null;
    for (final socket in [..._sockets.values]) {
      await socket.close(kMusicSyncCloseFailed);
    }
    _sockets.clear();
    final http = _http;
    _http = null;
    _boundPort = null;
    _isLanBound = false;
    if (http != null) {
      try {
        await http.close(force: true);
      } on Object {
        // The listener is already gone.
      }
    }
    _authAttempts.clear();
    _emitStatus();
  }

  /// Revokes one device: closes its socket and drops its key.
  Future<void> removeDevice(String clientId) async {
    final socket = _sockets.remove(clientId);
    if (socket != null) await socket.close(kMusicSyncCloseFailed);
    if (_devices.remove(clientId) != null) _saveDevices();
    _emitStatus();
  }

  /// Pushes the module's current lists at every connected client — the
  /// local-change path, suppressed while a sync itself writes the stores.
  void pushLocalListChanges() {
    if (_applyingRemote || _http == null) return;
    final action = <String, Object?>{'action': 'list_data_overwrite', 'data': _readListData()};
    for (final socket in _sockets.values) {
      if (!socket.listReady) continue;
      unawaited(socket.push('onListSyncAction', [action]));
    }
  }

  // --- state ---

  void _loadState() {
    final storedId = StoragePrefs.getString(kMusicSyncServerIdKey);
    _serverId = storedId == null || storedId.isEmpty ? _newServerId() : storedId;
    _devices
      ..clear()
      ..addAll(_readDevices());
  }

  var _serverId = '';

  String _newServerId() {
    final id = musicSyncRandomToken();
    try {
      unawaited(StoragePrefs.setString(kMusicSyncServerIdKey, id));
    } on Object {
      // A preference; a closed store regenerates next boot.
    }
    return id;
  }

  Map<String, MusicSyncServerDevice> _readDevices() {
    try {
      final raw = StoragePrefs.getString(kMusicSyncServerDevicesKey);
      if (raw == null || raw.isEmpty) return <String, MusicSyncServerDevice>{};
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String, MusicSyncServerDevice>{};
      return <String, MusicSyncServerDevice>{
        for (final entry in decoded)
          if (entry is Map && entry['clientId'] is String)
            entry['clientId'] as String: MusicSyncServerDevice.fromJson(entry),
      };
    } on Object {
      return <String, MusicSyncServerDevice>{};
    }
  }

  void _saveDevices() {
    try {
      unawaited(
        StoragePrefs.setString(
          kMusicSyncServerDevicesKey,
          jsonEncode([for (final device in _devices.values) device.toJson()]),
        ),
      );
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  String _readAuthCode() => StoragePrefs.getString(kMusicSyncServerAuthCodeKey) ?? '';

  /// The module's dislike rules, the same preference the client half keeps.
  String _readDislikeRules() {
    try {
      return StoragePrefs.getString(kMusicDislikeRemoteRulesKey) ?? '';
    } on Object {
      return '';
    }
  }

  void _emitStatus({String? error}) => onStatus?.call(
    MusicSyncServerStatus(running: _http != null, error: error, devices: deviceView()),
  );

  // --- HTTP ---

  Future<void> _onRequest(HttpRequest request) async {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      await _upgrade(request);
      return;
    }
    switch (request.uri.path) {
      case '/hello':
        _answerText(request, kMusicSyncHelloMsg);
      case '/id':
        _answerText(request, kMusicSyncIdPrefix + _serverId);
      case '/ah':
        await _auth(request);
      default:
        request.response.statusCode = 401;
        await request.response.close();
    }
  }

  void _answerText(HttpRequest request, String body, {int status = 200}) {
    request.response.statusCode = status;
    request.response.headers.contentType = _textPlain;
    request.response.write(body);
    unawaited(request.response.close());
  }

  static final ContentType _textPlain = ContentType('text', 'plain', charset: 'utf-8');

  // --- auth ---

  Future<void> _auth(HttpRequest request) async {
    final ip = request.connectionInfo?.remoteAddress.address ?? '';
    final attempts = (_authAttempts[ip] ?? 0) + 1;
    _authAttempts[ip] = attempts;
    if (attempts > 10) {
      _answerText(request, 'Blocked IP', status: 403);
      return;
    }
    final message = request.headers.value('m');
    if (message == null || message.isEmpty) {
      _answerText(request, 'Missing auth code', status: 401);
      return;
    }
    final clientId = request.headers.value('i');
    if (clientId != null && clientId.isNotEmpty) {
      _reauth(request, clientId, message);
      return;
    }
    final authCode = _readAuthCode();
    try {
      final plain = musicSyncAesDecrypt(message, musicSyncAuthKey(authCode));
      final lines = plain.split('\n');
      if (lines.length < 3 || lines.first.trim() != kMusicSyncMsgConnect) {
        throw const FormatException('not a connect message');
      }
      final publicKey = MusicSyncPeerPublicKey.parseSpki(lines[1].trim());
      final deviceName = lines[2].trim();
      final isMobile = lines.length > 3 && lines[3].trim() == 'lx_music_mobile';
      if (_devices.length >= kMusicSyncServerDeviceLimit) throw Exception('max keys');
      final keyInfo = MusicSyncServerDevice(
        clientId: musicSyncRandomToken(),
        key: musicSyncRandomToken(),
        deviceName: deviceName,
        isMobile: isMobile,
        lastConnectDate: DateTime.now().millisecondsSinceEpoch,
      );
      _devices[keyInfo.clientId] = keyInfo;
      _saveDevices();
      _emitStatus();
      _answerText(
        request,
        publicKey.encryptOaepBase64(
          jsonEncode(<String, Object?>{
            'clientId': keyInfo.clientId,
            'key': keyInfo.key,
            'serverName': Platform.localHostname,
          }),
        ),
      );
    } on Object {
      _answerText(request, 'Auth failed', status: 401);
    }
  }

  void _reauth(HttpRequest request, String clientId, String message) {
    final keyInfo = _devices[clientId];
    if (keyInfo == null) {
      _answerText(request, 'Auth failed', status: 401);
      return;
    }
    try {
      final plain = musicSyncAesDecrypt(message, keyInfo.key);
      if (!plain.startsWith(kMusicSyncAuthMsg)) throw const FormatException('not an auth message');
      final deviceName = plain.substring(kMusicSyncAuthMsg.length).trim();
      if (deviceName.isNotEmpty && deviceName != keyInfo.deviceName) {
        keyInfo.deviceName = deviceName;
        _saveDevices();
        _emitStatus();
      }
      _answerText(request, musicSyncAesEncrypt(kMusicSyncHelloMsg, keyInfo.key));
    } on Object {
      _answerText(request, 'Auth failed', status: 401);
    }
  }

  // --- connection ---

  Future<void> _upgrade(HttpRequest request) async {
    final clientId = request.uri.queryParameters['i'];
    final token = request.uri.queryParameters['t'];
    final keyInfo = clientId == null ? null : _devices[clientId];
    if (keyInfo == null || token == null) {
      request.response.statusCode = 401;
      await request.response.close();
      return;
    }
    try {
      if (musicSyncAesDecrypt(token, keyInfo.key) != kMusicSyncMsgConnect) {
        throw const FormatException('bad connect token');
      }
    } on Object {
      request.response.statusCode = 401;
      await request.response.close();
      return;
    }
    final WebSocket socket;
    try {
      socket = await WebSocketTransformer.upgrade(request);
    } on Object {
      return;
    }
    await _serve(socket, keyInfo);
  }

  Future<void> _serve(WebSocket socket, MusicSyncServerDevice keyInfo) async {
    final old = _sockets[keyInfo.clientId];
    if (old != null) await old.close(kMusicSyncCloseFailed);
    keyInfo.lastConnectDate = DateTime.now().millisecondsSinceEpoch;
    _saveDevices();
    final connection = MusicSyncServerSocket(socket, keyInfo);
    connection.onClosed = () {
      if (_sockets[keyInfo.clientId] == connection) _sockets.remove(keyInfo.clientId);
      _emitStatus();
    };
    connection
      ..registerPushHandler('onListSyncAction', (args) => unawaited(_onRemoteListAction(connection, args)))
      ..registerPushHandler('onDislikeSyncAction', (args) => unawaited(_onRemoteDislikeAction(connection, args)));
    _sockets[keyInfo.clientId] = connection;
    _emitStatus();
    unawaited(_runSync(connection));
  }

  /// The handshake: ask the client's enabled features, then run each
  /// module's sync; one sync at a time, the reference's `syncingId` lock.
  Future<void> _runSync(MusicSyncServerSocket connection) async {
    var failed = false;
    while (_syncingClientId.isNotEmpty) {
      if (connection.isClosed) return;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    _syncingClientId = connection.device.clientId;
    try {
      final features = await connection.call(
        'getEnabledFeatures',
        <Object?>['desktop-app', <String, Object?>{'list': 1, 'dislike': 1}],
      );
      if (connection.isClosed) return;
      final enabled = features is Map ? features : const <String, Object?>{};
      if (enabled['list'] != null && enabled['list'] != false) {
        try {
          await _syncList(connection);
          connection.listReady = true;
        } on Object {
          failed = true;
        }
      }
      if (connection.isClosed) return;
      if (enabled['dislike'] != null && enabled['dislike'] != false) {
        try {
          await _syncDislike(connection);
          connection.dislikeReady = true;
        } on Object {
          failed = true;
        }
      }
      if (connection.isClosed) return;
      await connection.call('finished', const <Object?>[]);
    } on Object {
      failed = true;
    } finally {
      if (_syncingClientId == connection.device.clientId) _syncingClientId = '';
    }
    if (failed || connection.isClosed) await connection.close(kMusicSyncCloseFailed);
  }

  // --- list sync ---

  Future<void> _syncList(MusicSyncServerSocket connection) async {
    final remoteData = musicSyncPatchListData(await connection.call('list_sync_get_list_data', const <Object?>[]));
    final localData = musicSyncPatchListData(_readListData());
    final clientId = connection.device.clientId;
    final localEmpty = musicSyncListDataIsEmpty(localData);
    final remoteEmpty = musicSyncListDataIsEmpty(remoteData);
    if (!localEmpty && !remoteEmpty) {
      final result = musicSyncMergeListData(localData, remoteData, _readSyncMode(), addToTop: _readAddToTop());
      if (result == null) throw Exception('cancel');
      if (result.updateLocal) {
        await _applyRemoteList(result.data);
        await _broadcastListOverwrite(result.data, exclude: clientId);
      }
      if (result.updateRemote) {
        await connection.call('list_sync_set_list_data', [result.data]);
      }
    } else if (!localEmpty) {
      await connection.call('list_sync_set_list_data', [localData]);
    } else if (!remoteEmpty) {
      await _applyRemoteList(remoteData);
      await _broadcastListOverwrite(remoteData, exclude: clientId);
    }
    await connection.call('list_sync_finished', const <Object?>[]);
  }

  Future<void> _applyRemoteList(Object? listData) async {
    _applyingRemote = true;
    try {
      await _applyListData(listData);
    } finally {
      _applyingRemote = false;
    }
  }

  Future<void> _broadcastListOverwrite(Object? listData, {required String exclude}) async {
    final action = <String, Object?>{'action': 'list_data_overwrite', 'data': listData};
    for (final socket in _sockets.values) {
      if (socket.device.clientId == exclude || !socket.listReady) continue;
      await socket.push('onListSyncAction', [action]);
    }
  }

  Future<void> _onRemoteListAction(MusicSyncServerSocket connection, List<Object?> args) async {
    final action = args.firstOrNull;
    if (action is! Map || action['action'] != 'list_data_overwrite') return;
    await _applyRemoteList(action['data']);
    await _broadcastListOverwrite(action['data'], exclude: connection.device.clientId);
  }

  // --- dislike sync ---

  Future<void> _syncDislike(MusicSyncServerSocket connection) async {
    final remoteRules = await connection.call('dislike_sync_get_list_data', const <Object?>[]);
    final localRules = _readDislikeRules();
    final remoteText = remoteRules is String ? remoteRules : '';
    final clientId = connection.device.clientId;
    if (localRules.isNotEmpty && remoteText.isNotEmpty) {
      final mode = _readSyncMode();
      var merged = '';
      var updateLocal = true;
      var updateRemote = true;
      switch (mode) {
        case 'merge_local_remote' || 'merge_remote_local':
          merged = musicSyncDislikeMerge(localRules, remoteText);
        case 'overwrite_local_remote' || 'overwrite_local_remote_full':
          merged = localRules;
          updateLocal = false;
        case 'overwrite_remote_local' || 'overwrite_remote_local_full':
          merged = remoteText;
          updateRemote = false;
        default:
          return;
      }
      if (updateLocal) {
        await _storeDislikeRules(merged);
        await _broadcastDislikeOverwrite(merged, exclude: clientId);
      }
      if (updateRemote) {
        await connection.call('dislike_sync_set_list_data', [merged]);
      }
    } else if (localRules.isNotEmpty) {
      await connection.call('dislike_sync_set_list_data', [localRules]);
    } else if (remoteText.isNotEmpty) {
      await _storeDislikeRules(remoteText);
      await _broadcastDislikeOverwrite(remoteText, exclude: clientId);
    }
    await connection.call('dislike_sync_finished', const <Object?>[]);
  }

  Future<void> _broadcastDislikeOverwrite(String rules, {required String exclude}) async {
    final action = <String, Object?>{'action': 'dislike_data_overwrite', 'data': rules};
    for (final socket in _sockets.values) {
      if (socket.device.clientId == exclude || !socket.dislikeReady) continue;
      await socket.push('onDislikeSyncAction', [action]);
    }
  }

  Future<void> _onRemoteDislikeAction(MusicSyncServerSocket connection, List<Object?> args) async {
    final action = args.firstOrNull;
    if (action is! Map || action['action'] != 'dislike_data_overwrite') return;
    final data = action['data'];
    await _storeDislikeRules(data is String ? data : '');
    await _broadcastDislikeOverwrite(data is String ? data : '', exclude: connection.device.clientId);
  }
}

/// A fresh six-digit connection code, the reference's `generateCode`.
String musicSyncGenerateAuthCode() => [for (var i = 0; i < 6; i++) Random.secure().nextInt(10)].join();

// --- providers ---

/// The server's on/off switch, persisted like the rest of the module's
/// settings. Changing it restarts the endpoint.
final class MusicSyncServerGate extends Notifier<bool> {
  @override
  bool build() => StoragePrefs.getBool(kMusicSyncServerEnabledKey) ?? false;

  /// Turns the endpoint on or off.
  Future<void> set({required bool enabled}) async {
    state = enabled;
    await StoragePrefs.setBool(kMusicSyncServerEnabledKey, enabled);
  }
}

/// The server's port, persisted; a change restarts the endpoint.
final class MusicSyncServerPort extends Notifier<int> {
  @override
  int build() => StoragePrefs.getInt(kMusicSyncServerPortKey) ?? kMusicSyncServerDefaultPort;

  /// Sets the listening port; a value outside the unprivileged range keeps
  /// the previous one.
  Future<void> set(int port) async {
    if (port < 1 || port > 65535) return;
    state = port;
    await StoragePrefs.setInt(kMusicSyncServerPortKey, port);
  }
}

/// The server's LAN switch; a change rebinds the endpoint.
final class MusicSyncServerLan extends Notifier<bool> {
  @override
  bool build() => StoragePrefs.getBool(kMusicSyncServerLanKey) ?? false;

  /// Turns LAN access on or off.
  Future<void> set({required bool lan}) async {
    state = lan;
    await StoragePrefs.setBool(kMusicSyncServerLanKey, lan);
  }
}

/// The server's connection code, generated on first read; clients need it
/// for their first authorization.
final class MusicSyncServerAuthCode extends Notifier<String> {
  @override
  String build() {
    final stored = StoragePrefs.getString(kMusicSyncServerAuthCodeKey);
    if (stored != null && stored.isNotEmpty) return stored;
    final code = musicSyncGenerateAuthCode();
    unawaited(StoragePrefs.setString(kMusicSyncServerAuthCodeKey, code));
    return code;
  }

  /// Saves an edited code.
  Future<void> set(String code) async {
    final next = code.trim();
    if (next.isEmpty) return;
    state = next;
    await StoragePrefs.setString(kMusicSyncServerAuthCodeKey, next);
  }

  /// Replaces the code with a fresh one, the reference's refresh; the new
  /// code comes back so callers need no provider read to show it.
  Future<String> refresh() async {
    final code = musicSyncGenerateAuthCode();
    state = code;
    await StoragePrefs.setString(kMusicSyncServerAuthCodeKey, code);
    return code;
  }
}

/// The server's live status, pushed by the server object.
final class MusicSyncServerStatusNotifier extends Notifier<MusicSyncServerStatus> {
  @override
  MusicSyncServerStatus build() => const MusicSyncServerStatus(running: false, devices: <MusicSyncServerDevice>[]);

  /// Applies one status report.
  // The lint wants a setter; a method reads better next to Riverpod's API.
  // ignore: use_setters_to_change_properties
  void update(MusicSyncServerStatus status) => state = status;
}

final musicSyncServerGateProvider = NotifierProvider<MusicSyncServerGate, bool>(MusicSyncServerGate.new);
final musicSyncServerPortProvider = NotifierProvider<MusicSyncServerPort, int>(MusicSyncServerPort.new);
final musicSyncServerLanProvider = NotifierProvider<MusicSyncServerLan, bool>(MusicSyncServerLan.new);
final musicSyncServerAuthCodeProvider = NotifierProvider<MusicSyncServerAuthCode, String>(MusicSyncServerAuthCode.new);
final musicSyncServerStatusProvider = NotifierProvider<MusicSyncServerStatusNotifier, MusicSyncServerStatus>(
  MusicSyncServerStatusNotifier.new,
);

/// The module's sync server, started and stopped by the gate, port and LAN
/// switch; the module's stores feed the syncs and local changes push out.
final musicSyncServerProvider = Provider<MusicSyncServer>((ref) {
  final server = MusicSyncServer(
        readSyncMode: () => ref.read(musicSyncProvider).syncMode,
        readAddToTop: () => ref.read(musicSettingsProvider).addToTop,
        readListData: () => musicSyncListDataFromState(
          ref.read(musicRecentProvider),
          ref.read(musicFavouritesProvider),
          ref.read(musicPlaylistsProvider),
        ),
        applyListData: (listData) async {
          final decoded = musicSyncApplyListData(listData);
          await ref.read(musicRecentProvider.notifier).replaceAll(decoded.recent);
          await ref.read(musicFavouritesProvider.notifier).replaceAll(decoded.favourites);
          await ref.read(musicPlaylistsProvider.notifier).replaceAll(decoded.playlists);
        },
        storeDislikeRules: (rules) => StoragePrefs.setString(kMusicDislikeRemoteRulesKey, rules),
      )
      ..onStatus = (status) {
        if (ref.mounted) ref.read(musicSyncServerStatusProvider.notifier).update(status);
      };

  Future<void> sync() async {
    if (!ref.watch(musicSyncServerGateProvider)) {
      await server.stop();
      return;
    }
    try {
      await server.start(ref.watch(musicSyncServerPortProvider), lan: ref.watch(musicSyncServerLanProvider));
    } on Object {
      // The status carries the bind failure to the pane.
    }
  }

  unawaited(sync());
  Timer(const Duration(seconds: 2), () => unawaited(sync()));
  ref
    ..listen(musicRecentProvider, (_, _) => server.pushLocalListChanges())
    ..listen(musicFavouritesProvider, (_, _) => server.pushLocalListChanges())
    ..listen(musicPlaylistsProvider, (_, _) => server.pushLocalListChanges())
    ..onDispose(() {
      server.onStatus = null;
      unawaited(server.stop());
    });
  return server;
});
