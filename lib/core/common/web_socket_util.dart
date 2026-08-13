import 'dart:async';

import 'package:web_socket_channel/io.dart';

enum SocketStatus { connected, failed, closed }

/// WebSocket connection helper with endpoint failover and bounded reconnects.
///
/// The original implementation kept a periodic reconnect timer alive after a
/// successful connection. That could create parallel sockets every five
/// seconds and made danmaku delivery increasingly expensive. This helper uses
/// one-shot retries and rotates through all supplied endpoints instead.
class WebScoketUtils {
  SocketStatus status = SocketStatus.closed;

  /// Primary endpoint. Kept for source compatibility with existing sites.
  final String url;

  /// Legacy secondary endpoint.
  final String? backupUrl;

  /// Ordered endpoints used for connection and failover.
  final List<String> serverUrls;

  final int heartBeatTime;
  final Function(dynamic)? onMessage;
  final Function(String msg)? onClose;
  final Function()? onReconnect;
  final Function()? onReady;
  final Function()? onHeartBeat;
  final Map<String, dynamic>? headers;

  WebScoketUtils({
    required this.url,
    required this.heartBeatTime,
    this.onMessage,
    this.onClose,
    this.onReconnect,
    this.onReady,
    this.onHeartBeat,
    this.headers,
    this.backupUrl,
    List<String>? serverUrls,
  }) : serverUrls = _uniqueEndpoints(url, backupUrl, serverUrls);

  IOWebSocketChannel? webSocket;
  Timer? heartBeatTimer;
  Timer? reconnectTimer;
  StreamSubscription<dynamic>? streamSubscription;

  int reconnectTime = 0;
  int maxReconnectTime = 8;
  int _endpointIndex = 0;
  int _generation = 0;
  bool _manualClose = false;
  bool _connecting = false;

  static List<String> _uniqueEndpoints(String primary, String? backup, List<String>? candidates) {
    final endpoints = <String>[];
    for (final endpoint in <String>[primary, if (backup != null) backup, ...?candidates]) {
      final value = endpoint.trim();
      if (value.isNotEmpty && !endpoints.contains(value)) endpoints.add(value);
    }
    return endpoints;
  }

  Future<void> connect({bool retry = false}) async {
    if (_connecting || serverUrls.isEmpty) return;
    _manualClose = false;
    _connecting = true;
    final generation = ++_generation;

    reconnectTimer?.cancel();
    reconnectTimer = null;
    await _disposeSocket();

    if (retry && serverUrls.length > 1) {
      _endpointIndex = (_endpointIndex + 1) % serverUrls.length;
    }

    try {
      final endpoint = serverUrls[_endpointIndex % serverUrls.length];
      final channel = IOWebSocketChannel.connect(
        endpoint,
        connectTimeout: const Duration(seconds: 10),
        headers: headers,
      );
      webSocket = channel;
      await channel.ready;
      if (_manualClose || generation != _generation) {
        await channel.sink.close();
        return;
      }
      _ready(channel);
    } catch (error) {
      if (!_manualClose && generation == _generation) {
        _scheduleReconnect(error.toString());
      }
    } finally {
      if (generation == _generation) _connecting = false;
    }
  }

  void _ready(IOWebSocketChannel channel) {
    status = SocketStatus.connected;
    reconnectTimer?.cancel();
    reconnectTimer = null;

    streamSubscription = channel.stream.listen(
      receiveMessage,
      onError: (Object error, StackTrace stackTrace) => _scheduleReconnect(error.toString()),
      onDone: () {
        if (!_manualClose) _scheduleReconnect('WebSocket closed');
      },
      cancelOnError: true,
    );

    onReady?.call();
    _initHeartBeat();
  }

  void _initHeartBeat() {
    heartBeatTimer?.cancel();
    if (heartBeatTime <= 0) return;
    heartBeatTimer = Timer.periodic(Duration(milliseconds: heartBeatTime), (_) {
      if (status == SocketStatus.connected) onHeartBeat?.call();
    });
  }

  void receiveMessage(dynamic data) {
    reconnectTime = 0;
    onMessage?.call(data);
  }

  void _scheduleReconnect(String message) {
    if (_manualClose || reconnectTimer?.isActive == true) return;

    status = SocketStatus.failed;
    heartBeatTimer?.cancel();
    heartBeatTimer = null;
    if (reconnectTime == 0) onReconnect?.call();

    if (reconnectTime >= maxReconnectTime) {
      onClose?.call('重连超过最大次数，与服务器断开连接：$message');
      close();
      return;
    }

    reconnectTime++;
    _endpointIndex = (_endpointIndex + 1) % serverUrls.length;
    // Try the next server quickly; use a short backoff after every full round.
    final completedRounds = reconnectTime ~/ serverUrls.length;
    final delaySeconds = completedRounds.clamp(0, 5) + 1;
    reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      reconnectTimer = null;
      connect();
    });
  }

  void sendMessage(dynamic message) {
    if (status == SocketStatus.connected) webSocket?.sink.add(message);
  }

  Future<void> _disposeSocket() async {
    await streamSubscription?.cancel();
    streamSubscription = null;
    heartBeatTimer?.cancel();
    heartBeatTimer = null;
    final socket = webSocket;
    webSocket = null;
    try {
      await socket?.sink.close();
    } catch (_) {}
  }

  void close() {
    _manualClose = true;
    _generation++;
    status = SocketStatus.closed;
    reconnectTimer?.cancel();
    reconnectTimer = null;
    unawaited(_disposeSocket());
  }

  void reconnect() {
    if (!_manualClose) _scheduleReconnect('Reconnect requested');
  }
}
