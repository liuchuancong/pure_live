/// The LX sync protocol's client: HTTP auth against a lx-music desktop
/// server, then one WebSocket over which the two ends trade message2call
/// frames (gzipped past 1 KiB). The server drives the sync; the client only
/// answers its calls and pushes local-change actions back.
library;

import 'dart:async' show Completer, StreamController, Timer, unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show Platform;

import 'package:live_net/live_net.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:live_websocket/live_websocket.dart' show LiveWebSocketClient;

import 'package:pure_live/modules/music/controller/music_sync_codec.dart';
import 'package:pure_live/modules/music/controller/music_sync_wire.dart';

/// The LX sync protocol's client: HTTP auth against a lx-music desktop

/// server, then one WebSocket over which the two ends trade message2call
/// frames (gzipped past 1 KiB). The server drives the sync; the client only
/// answers its calls and pushes local-change actions back.
/// The reference's `helloMsg`.
const String kMusicSyncHelloMsg = 'Hello~::^-^::~v4~';

/// The reference's `idPrefix`, prefixing the server id in `/id`.
const String kMusicSyncIdPrefix = 'OjppZDo6';

/// The reference's `authMsg`.
const String kMusicSyncAuthMsg = 'lx-music auth::';

/// The reference's `msgConnect`.
const String kMusicSyncMsgConnect = 'lx-music connect';

/// The close code the reference uses for auth/protocol failures.
const int kMusicSyncCloseFailed = 4100;

/// The parsed sync server address: scheme plus `host[:port]`.
final class MusicSyncAddress {
  const MusicSyncAddress({required this.httpScheme, required this.wsScheme, required this.hostPath});

  final String httpScheme;
  final String wsScheme;
  final String hostPath;

  /// Parses `http(s)://host:port` or bare `host:port` (http assumed);
  /// null on a shape the protocol cannot use.
  static MusicSyncAddress? parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    if (text.startsWith('http://')) {
      return MusicSyncAddress(httpScheme: 'http', wsScheme: 'ws', hostPath: text.substring(7).replaceAll(RegExp(r'/+$'), ''));
    }
    if (text.startsWith('https://')) {
      return MusicSyncAddress(httpScheme: 'https', wsScheme: 'wss', hostPath: text.substring(8).replaceAll(RegExp(r'/+$'), ''));
    }
    if (text.startsWith('ws://') || text.startsWith('wss://')) return null;
    return MusicSyncAddress(httpScheme: 'http', wsScheme: 'ws', hostPath: text.replaceAll(RegExp(r'/+$'), ''));
  }
}

/// The key info the server hands out on first auth and the client keeps.
final class MusicSyncKeyInfo {
  const MusicSyncKeyInfo({required this.clientId, required this.key, required this.serverName});

  factory MusicSyncKeyInfo.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('key info is not an object');
    final clientId = json['clientId'];
    final key = json['key'];
    if (clientId is! String || key is! String) throw const FormatException('key info is incomplete');
    return MusicSyncKeyInfo(
      clientId: clientId,
      key: key,
      serverName: json['serverName'] is String ? json['serverName'] as String : '',
    );
  }

  final String clientId;
  final String key;
  final String serverName;

  Map<String, Object?> toJson() => <String, Object?>{'clientId': clientId, 'key': key, 'serverName': serverName};
}

/// The connection's phase, reported to the settings surface.
enum MusicSyncStatus { idle, connecting, authing, connected, failed }

/// One sync server session. Owns the HTTP auth, the socket and the RPC
/// engine; handlers are wired by the controller.
final class MusicSyncClient {
  // The HTTP transport arrives under a public name; the private field
  // cannot be an initializing formal for a named parameter.
  // ignore: prefer_initializing_formals
  MusicSyncClient({required LiveHttp http, required this.deviceName}) : _http = http;

  final LiveHttp _http;
  final String deviceName;

  final StreamController<MusicSyncStatus> _status = StreamController<MusicSyncStatus>.broadcast();
  final StreamController<String> _messages = StreamController<String>.broadcast();
  final Map<String, Completer<Object?>> _pending = <String, Completer<Object?>>{};
  final Map<String, void Function(List<Object?> args)> _callbacks = <String, void Function(List<Object?> args)>{};
  final Map<String, Object? Function(List<Object?> args)> _handlers = <String, Object? Function(List<Object?> args)>{};
  final Map<String, void Function(List<Object?> args)> _pushHandlers = <String, void Function(List<Object?> args)>{};

  LiveWebSocketClient? _socket;
  Timer? _idleTimer;
  int _callbackCounter = 0;
  var _callbackId = 0;

  /// Connection phase changes.
  Stream<MusicSyncStatus> get status => _status.stream;

  /// Human-readable progress and failure notes.
  Stream<String> get messages => _messages.stream;

  /// Whether the socket is up and the module handshake done.
  bool get isConnected => _socket?.isConnected ?? false;

  /// Registers a handler the server may call; returning a value answers the
  /// call; fire-and-forget actions go through [registerPushHandler].
  void registerHandler(String name, Object? Function(List<Object?> args) handler) => _handlers[name] = handler;

  /// Registers a push-style handler whose return value is not awaited.
  void registerPushHandler(String name, void Function(List<Object?> args) handler) => _pushHandlers[name] = handler;

  /// Unregisters everything — used on disconnect.
  void unregisterAll() {
    _handlers.clear();
    _pushHandlers.clear();
    _callbacks.clear();
  }

  // --- auth ---

  /// Runs the auth against [address]: key auth first when key info is
  /// stored, code auth (asking the server for a new key) otherwise.
  Future<MusicSyncKeyInfo> auth(MusicSyncAddress address, String authCode, MusicSyncKeyInfo? storedKeyInfo) async {
    _emit(MusicSyncStatus.authing);
    return storedKeyInfo != null ? await _keyAuth(address, storedKeyInfo) : await _codeAuth(address, authCode);
  }

  Future<MusicSyncKeyInfo> _codeAuth(MusicSyncAddress address, String authCode) async {
    if (authCode.trim().isEmpty) throw Exception('auth code is empty');
    final key = musicSyncAuthKey(authCode.trim());
    final pair = MusicSyncRsaKeyPair.generate();
    final message = musicSyncAesEncrypt('$kMusicSyncAuthMsg\n${pair.publicSpkiBase64}\n$deviceName\nlx_music_desktop', key);
    final text = await _http.getText(
      Uri(scheme: address.httpScheme, host: _host(address), port: _port(address), path: '/ah'),
      headers: {'m': message},
    );
    final answer = pair.decryptOaep(text);
    final keyInfo = MusicSyncKeyInfo.fromJson(jsonDecode(answer));
    _emitMessage('已获得服务器授权（${keyInfo.serverName}）');
    return keyInfo;
  }

  Future<MusicSyncKeyInfo> _keyAuth(MusicSyncAddress address, MusicSyncKeyInfo keyInfo) async {
    final message = musicSyncAesEncrypt(kMusicSyncAuthMsg + deviceName, keyInfo.key);
    final text = await _http.getText(
      Uri(scheme: address.httpScheme, host: _host(address), port: _port(address), path: '/ah'),
      headers: {'i': keyInfo.clientId, 'm': message},
    );
    if (musicSyncAesDecrypt(text, keyInfo.key) != kMusicSyncHelloMsg) throw Exception('认证失败');
    return keyInfo;
  }

  /// Reads `/hello` and `/id` and checks both shapes before auth.
  Future<String> readServerId(MusicSyncAddress address) async {
    _emit(MusicSyncStatus.connecting);
    final hello = await _http.getText(Uri(scheme: address.httpScheme, host: _host(address), port: _port(address), path: '/hello'));
    if (hello != kMusicSyncHelloMsg) throw Exception('不是 lx-music 同步服务');
    final id = await _http.getText(Uri(scheme: address.httpScheme, host: _host(address), port: _port(address), path: '/id'));
    return id.startsWith(kMusicSyncIdPrefix) ? id.substring(kMusicSyncIdPrefix.length) : id;
  }

  // --- socket + RPC ---

  /// Opens the socket and starts answering frames. Handlers must already be
  /// registered.
  Future<void> connect(MusicSyncAddress address, MusicSyncKeyInfo keyInfo) async {
    _emit(MusicSyncStatus.connecting);
    final token = musicSyncAesEncrypt(kMusicSyncMsgConnect, keyInfo.key);
    final uri = Uri(
      scheme: address.wsScheme,
      host: _host(address),
      port: _port(address),
      path: '/socket',
      queryParameters: <String, String>{'i': keyInfo.clientId, 't': token},
    );
    final socket = LiveWebSocketClient(uri: uri);
    _socket = socket;
    socket.messages.listen(_onFrame, onDone: _onClosed, onError: (Object error) => _onClosed());
    await socket.connect();
    _emit(MusicSyncStatus.connected);
    _armIdleWatch();
  }

  /// Closes the socket and clears the engine.
  Future<void> disconnect() async {
    _idleTimer?.cancel();
    final socket = _socket;
    _socket = null;
    unregisterAll();
    _pending.clear();
    if (socket != null) await socket.disconnect();
    _emit(MusicSyncStatus.idle);
  }

  /// Calls one of the server's exposed methods; the answer future resolves
  /// with the remote's reply or throws on failure.
  Future<Object?> call(String name, List<Object?> args, {Duration timeout = const Duration(seconds: 30)}) {
    final socket = _socket;
    if (socket == null || !socket.isConnected) return Future.error(Exception('未连接到同步服务'));
    final callId = '${name}_${DateTime.now().microsecondsSinceEpoch}_$_callbackId';
    _callbackId++;
    final completer = Completer<Object?>();
    _pending[callId] = completer;
    // Function arguments go out under generated callback names, the way the
    // reference turns local functions into proxy callbacks.
    final wireArgs = <Object?>[];
    final callbackIndexes = <int>[];
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg is void Function(List<Object?>)) {
        final callbackName = 'func_${_callbackCounter++}_$callId';
        _callbacks[callbackName] = arg;
        callbackIndexes.add(i);
        wireArgs.add(MusicSyncRpcCallback(callbackName));
      } else {
        wireArgs.add(arg);
      }
    }
    socket.send(musicSyncEncodeFrame(musicSyncEncodeRequest(callId, wireArgs, callbackIndexes)));
    return completer.future.timeout(timeout, onTimeout: () {
      _pending.remove(callId);
      throw Exception('同步调用超时: $name');
    });
  }

  Future<void> _swallow(Future<Object?> future) async {
    try {
      await future;
    } on Object {
      // A fire-and-forget push; the next sync resolves the difference.
    }
  }

  /// Pushes a local-change action at the server without waiting.
  void push(String name, List<Object?> args) {
    unawaited(_swallow(call(name, args)));
  }

  void _onFrame(Object? data) {
    if (data is! String) return;
    if (data == 'ping') return;
    _armIdleWatch();
    final payload = musicSyncDecodeFrame(data);
    final decoded = musicSyncParseMessage(payload);
    switch (decoded) {
      case final MusicSyncRpcRequest request:
        _answer(request);
      case final MusicSyncRpcResponse response:
        final completer = _pending.remove(response.name);
        if (completer == null) return;
        if (response.error == null) {
          completer.complete(response.result);
        } else {
          completer.completeError(Exception(response.errorMessage));
        }
      case final MusicSyncRpcCallbackRequest callback:
        final handler = _callbacks[callback.name];
        if (handler != null) handler(callback.args);
      default:
        break;
    }
  }

  void _answer(MusicSyncRpcRequest request) {
    final push = _pushHandlers[request.name];
    if (push != null) {
      push(request.args);
      _socket?.send(musicSyncEncodeFrame(request.reply(null)));
      return;
    }
    final handler = _handlers[request.name];
    if (handler == null) {
      _socket?.send(musicSyncEncodeFrame(request.replyError('${request.name} is not defined')));
      return;
    }
    try {
      final result = handler(request.args);
      _socket?.send(musicSyncEncodeFrame(request.reply(result)));
    } on Object catch (error) {
      _socket?.send(musicSyncEncodeFrame(request.replyError(error.toString())));
    }
  }

  void _armIdleWatch() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 60), _onClosed);
  }

  void _onClosed() {
    _idleTimer?.cancel();
    final socket = _socket;
    _socket = null;
    for (final completer in _pending.values) {
      completer.completeError(Exception('同步连接已断开'));
    }
    _pending.clear();
    if (socket != null) unawaited(socket.disconnect());
    _emit(isConnected ? MusicSyncStatus.connected : MusicSyncStatus.failed);
  }

  void _emit(MusicSyncStatus status) {
    if (!_status.isClosed) _status.add(status);
  }

  void _emitMessage(String message) {
    if (!_messages.isClosed) _messages.add(message);
  }

  String _host(MusicSyncAddress address) => address.hostPath.contains(':')
      ? address.hostPath.substring(0, address.hostPath.indexOf(':'))
      : address.hostPath;

  int _port(MusicSyncAddress address) {
    final colon = address.hostPath.indexOf(':');
    if (colon < 0) return address.httpScheme == 'https' ? 443 : 80;
    return int.tryParse(address.hostPath.substring(colon + 1)) ?? (address.httpScheme == 'https' ? 443 : 80);
  }
}

/// The device name the protocol sends in auth messages.
String musicSyncDeviceName() => Platform.localHostname;

/// Reads the stored key info; null when absent or damaged.
MusicSyncKeyInfo? musicSyncReadKeyInfo() {
  try {
    final raw = StoragePrefs.getString('music.sync.keyInfo');
    if (raw == null || raw.isEmpty) return null;
    return MusicSyncKeyInfo.fromJson(jsonDecode(raw));
  } on Object {
    return null;
  }
}

/// Stores or clears the key info.
Future<void> musicSyncWriteKeyInfo(MusicSyncKeyInfo? keyInfo) async {
  try {
    await StoragePrefs.setString('music.sync.keyInfo', keyInfo == null ? '' : jsonEncode(keyInfo.toJson()));
  } on Object {
    // A preference; a closed store loses it.
  }
}
