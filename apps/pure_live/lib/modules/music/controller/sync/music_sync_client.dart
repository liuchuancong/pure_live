/// The LX sync protocol's client: HTTP auth against a lx-music desktop
/// server, then one WebSocket over which the two ends trade message2call
/// frames (gzipped past 1 KiB). The server drives the sync; the client only
/// answers its calls and pushes local-change actions back.
library;

import 'dart:async' show Completer, StreamController, StreamSubscription, Timer, unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show Platform;

import 'package:live_net/live_net.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:live_websocket/live_websocket.dart' show LiveWebSocketClient, WebSocketConnectionState;

import 'package:pure_live/modules/music/controller/sync/music_sync_codec.dart';
import 'package:pure_live/modules/music/controller/sync/music_sync_wire.dart';

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
      return MusicSyncAddress(
        httpScheme: 'http',
        wsScheme: 'ws',
        hostPath: text.substring(7).replaceAll(RegExp(r'/+$'), ''),
      );
    }
    if (text.startsWith('https://')) {
      return MusicSyncAddress(
        httpScheme: 'https',
        wsScheme: 'wss',
        hostPath: text.substring(8).replaceAll(RegExp(r'/+$'), ''),
      );
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
  final Map<String, Object? Function(List<Object?> args)> _callbacks = <String, Object? Function(List<Object?> args)>{};
  final Map<String, List<String>> _callCallbacks = <String, List<String>>{};
  final Map<String, Timer> _callbackTimers = <String, Timer>{};
  final Map<String, Object? Function(List<Object?> args)> _handlers = <String, Object? Function(List<Object?> args)>{};
  final Map<String, Object? Function(List<Object?> args)> _pushHandlers =
      <String, Object? Function(List<Object?> args)>{};

  LiveWebSocketClient? _socket;
  // Both subscriptions are cancelled together by _cancelSocketListeners.
  // ignore: cancel_subscriptions
  StreamSubscription<Object?>? _messageSubscription;
  // The same teardown owns the state subscription.
  // ignore: cancel_subscriptions
  StreamSubscription<WebSocketConnectionState>? _stateSubscription;
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

  /// Registers a push-style handler whose return value is discarded after it
  /// completes; the remote still receives the acknowledgement afterwards.
  void registerPushHandler(String name, Object? Function(List<Object?> args) handler) => _pushHandlers[name] = handler;

  /// Unregisters everything — used on disconnect.
  void unregisterAll() {
    _handlers.clear();
    _pushHandlers.clear();
    _callbacks.clear();
    _callCallbacks.clear();
    _callbackTimers.values.forEach(_cancelTimer);
    _callbackTimers.clear();
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
    final message = musicSyncAesEncrypt(
      '$kMusicSyncAuthMsg\n${pair.publicSpkiBase64}\n$deviceName\nlx_music_desktop',
      key,
    );
    final text = await _http.getText(
      Uri(scheme: address.httpScheme, host: _host(address), port: _port(address), path: '/ah'),
      headers: {'m': message},
      timeout: const Duration(seconds: 10),
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
      timeout: const Duration(seconds: 10),
    );
    if (musicSyncAesDecrypt(text, keyInfo.key) != kMusicSyncHelloMsg) throw Exception('认证失败');
    return keyInfo;
  }

  /// Reads `/hello` and `/id` and checks both shapes before auth.
  Future<String> readServerId(MusicSyncAddress address) async {
    _emit(MusicSyncStatus.connecting);
    final hello = await _http.getText(
      Uri(scheme: address.httpScheme, host: _host(address), port: _port(address), path: '/hello'),
      timeout: const Duration(seconds: 10),
    );
    if (hello != kMusicSyncHelloMsg) throw Exception('不是 lx-music 同步服务');
    final id = await _http.getText(
      Uri(scheme: address.httpScheme, host: _host(address), port: _port(address), path: '/id'),
      timeout: const Duration(seconds: 10),
    );
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
    _messageSubscription = socket.messages.listen((data) => _onFrame(socket, data));
    _stateSubscription = socket.states.listen((state) {
      if (!identical(_socket, socket)) return;
      switch (state) {
        case WebSocketConnectionState.connected:
          _emit(MusicSyncStatus.connected);
        case WebSocketConnectionState.reconnecting:
          _failPending();
          _emit(MusicSyncStatus.connecting);
        case WebSocketConnectionState.disconnected:
          _onClosed(socket);
        case WebSocketConnectionState.connecting:
          _emit(MusicSyncStatus.connecting);
      }
    });
    await socket.connect();
    if (!identical(_socket, socket)) throw Exception('同步连接已关闭');
    if (!socket.isConnected) throw Exception('同步服务连接失败');
    _emit(MusicSyncStatus.connected);
    _armIdleWatch();
  }

  /// Closes the socket and clears the engine.
  /// Ends the session and closes the streams: a client the controller
  /// has stopped listening to leaves nothing behind to drain.
  Future<void> dispose() async {
    await disconnect();
    await _status.close();
    await _messages.close();
  }

  Future<void> disconnect() async {
    _idleTimer?.cancel();
    final socket = _socket;
    _socket = null;
    unregisterAll();
    _failPending();
    await _cancelSocketListeners();
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
    final callbackNames = <String>[];
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg is void Function(List<Object?>)) {
        final callbackName = 'func_${_callbackCounter++}_$callId';
        _callbacks[callbackName] = arg;
        callbackNames.add(callbackName);
        callbackIndexes.add(i);
        wireArgs.add(MusicSyncRpcCallback(callbackName));
      } else {
        wireArgs.add(arg);
      }
    }
    if (callbackNames.isNotEmpty) {
      _callCallbacks[callId] = callbackNames;
      _callbackTimers[callId] = Timer(timeout, () => _releaseCallbacks(callId));
    }
    try {
      socket.send(musicSyncEncodeFrame(musicSyncEncodeRequest(callId, wireArgs, callbackIndexes)));
    } on Object {
      _pending.remove(callId);
      _releaseCallbacks(callId);
      rethrow;
    }
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pending.remove(callId);
        _releaseCallbacks(callId);
        throw Exception('同步调用超时: $name');
      },
    );
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

  void _onFrame(LiveWebSocketClient socket, Object? data) {
    if (!identical(_socket, socket)) return;
    if (data is! String) return;
    if (data == 'ping') return;
    final Object? decoded;
    try {
      decoded = musicSyncParseMessage(musicSyncDecodeFrame(data));
    } on Object {
      _onClosed(socket);
      return;
    }
    _armIdleWatch();
    switch (decoded) {
      case final MusicSyncRpcRequest request:
        _answer(request);
      case final MusicSyncRpcResponse response:
        final completer = _pending.remove(response.name);
        if (completer == null) return;
        // The remote may invoke callbacks after the call response, so keep
        // their handlers until the call timeout.
        if (response.error == null) {
          completer.complete(response.result);
        } else {
          completer.completeError(Exception(response.errorMessage));
        }
      case final MusicSyncRpcCallbackRequest callback:
        _answerCallback(socket, callback);
      default:
        break;
    }
  }

  void _answerCallback(LiveWebSocketClient socket, MusicSyncRpcCallbackRequest callback) {
    final handler = _callbacks[callback.name];
    if (handler == null) {
      _sendCallbackError(socket, callback, '${callback.name} is released');
      return;
    }
    try {
      final result = handler(callback.args);
      if (result is Future) {
        unawaited(_completeCallback(socket, callback, result));
      } else {
        _sendCallbackReply(socket, callback, result);
      }
    } on Object catch (error) {
      _sendCallbackError(socket, callback, error.toString());
    }
  }

  Future<void> _completeCallback(
    LiveWebSocketClient socket,
    MusicSyncRpcCallbackRequest callback,
    Future<dynamic> future,
  ) async {
    try {
      final result = await future;
      _sendCallbackReply(socket, callback, result);
    } on Object catch (error) {
      _sendCallbackError(socket, callback, error.toString());
    }
  }

  void _sendCallbackReply(LiveWebSocketClient socket, MusicSyncRpcCallbackRequest callback, Object? result) {
    if (!identical(_socket, socket) || !socket.isConnected) return;
    try {
      socket.send(musicSyncEncodeFrame(callback.reply(result)));
    } on Object {
      _onClosed(socket);
    }
  }

  void _sendCallbackError(LiveWebSocketClient socket, MusicSyncRpcCallbackRequest callback, String message) {
    if (!identical(_socket, socket) || !socket.isConnected) return;
    try {
      socket.send(musicSyncEncodeFrame(callback.replyError(message)));
    } on Object {
      _onClosed(socket);
    }
  }

  void _answer(MusicSyncRpcRequest request) {
    final socket = _socket;
    if (socket == null) return;
    final push = _pushHandlers[request.name];
    if (push != null) {
      _invokeHandler(socket, request, push, discardResult: true);
      return;
    }
    final handler = _handlers[request.name];
    if (handler == null) {
      _sendError(socket, request, '${request.name} is not defined');
      return;
    }
    _invokeHandler(socket, request, handler, discardResult: false);
  }

  void _invokeHandler(
    LiveWebSocketClient socket,
    MusicSyncRpcRequest request,
    Object? Function(List<Object?> args) handler, {
    required bool discardResult,
  }) {
    try {
      final result = handler(request.args);
      if (result is Future) {
        unawaited(_completeHandler(socket, request, result, discardResult: discardResult));
      } else {
        _sendReply(socket, request, result, discardResult: discardResult);
      }
    } on Object catch (error) {
      _sendError(socket, request, error.toString());
    }
  }

  Future<void> _completeHandler(
    LiveWebSocketClient socket,
    MusicSyncRpcRequest request,
    Future<dynamic> future, {
    required bool discardResult,
  }) async {
    try {
      final result = await future;
      _sendReply(socket, request, result, discardResult: discardResult);
    } on Object catch (error) {
      _sendError(socket, request, error.toString());
    }
  }

  void _sendReply(
    LiveWebSocketClient socket,
    MusicSyncRpcRequest request,
    Object? result, {
    required bool discardResult,
  }) {
    if (!identical(_socket, socket) || !socket.isConnected) return;
    try {
      socket.send(musicSyncEncodeFrame(request.reply(discardResult ? null : result)));
    } on Object {
      _onClosed(socket);
    }
  }

  void _sendError(LiveWebSocketClient socket, MusicSyncRpcRequest request, String message) {
    if (!identical(_socket, socket) || !socket.isConnected) return;
    try {
      socket.send(musicSyncEncodeFrame(request.replyError(message)));
    } on Object {
      _onClosed(socket);
    }
  }

  void _armIdleWatch() {
    _idleTimer?.cancel();
    final socket = _socket;
    if (socket == null) return;
    _idleTimer = Timer(const Duration(seconds: 60), () => _onClosed(socket));
  }

  void _onClosed(LiveWebSocketClient socket) {
    if (!identical(_socket, socket)) return;
    _idleTimer?.cancel();
    _socket = null;
    unregisterAll();
    _failPending();
    unawaited(_cancelSocketListeners());
    unawaited(socket.disconnect());
    _emit(MusicSyncStatus.failed);
  }

  Future<void> _cancelSocketListeners() async {
    final messages = _messageSubscription;
    final states = _stateSubscription;
    _messageSubscription = null;
    _stateSubscription = null;
    await messages?.cancel();
    await states?.cancel();
  }

  void _failPending() {
    final pending = _pending.values.toList(growable: false);
    _callCallbacks.keys.toList(growable: false).forEach(_releaseCallbacks);
    _pending.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) completer.completeError(Exception('同步连接已断开'));
    }
  }

  void _releaseCallbacks(String callId) {
    _callbackTimers.remove(callId)?.cancel();
    final names = _callCallbacks.remove(callId);
    if (names == null) return;
    names.forEach(_callbacks.remove);
  }

  void _emit(MusicSyncStatus status) {
    if (!_status.isClosed) _status.add(status);
  }

  void _emitMessage(String message) {
    if (!_messages.isClosed) _messages.add(message);
  }

  String _host(MusicSyncAddress address) =>
      address.hostPath.contains(':') ? address.hostPath.substring(0, address.hostPath.indexOf(':')) : address.hostPath;

  int _port(MusicSyncAddress address) {
    final colon = address.hostPath.indexOf(':');
    if (colon < 0) return address.httpScheme == 'https' ? 443 : 80;
    return int.tryParse(address.hostPath.substring(colon + 1)) ?? (address.httpScheme == 'https' ? 443 : 80);
  }
}

void _cancelTimer(Timer timer) => timer.cancel();

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
