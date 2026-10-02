import 'dart:async';
import 'dart:io' as io;

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef WebSocketConnector = WebSocketChannel Function(
  String endpoint, {
  Duration? connectTimeout,
  Iterable<String>? protocols,
  Map<String, dynamic>? headers,
  io.HttpClient? customClient,
});

typedef WebSocketProxyDirectiveProvider = String Function(Uri uri);

WebSocketProxyDirectiveProvider? _webSocketProxyDirectiveProvider;

/// Makes every danmaku WebSocket use the same live proxy setting as API and
/// image requests. The provider is evaluated for each handshake, so changing
/// the setting does not require recreating every site adapter.
void configureWebSocketProxyRouting(WebSocketProxyDirectiveProvider? provider) {
  _webSocketProxyDirectiveProvider = provider;
}

String resolveWebSocketProxyDirective(Uri uri) {
  try {
    return _webSocketProxyDirectiveProvider?.call(uri) ?? 'DIRECT';
  } catch (_) {
    return 'DIRECT';
  }
}

WebSocketChannel _connectIoWebSocket(
  String endpoint, {
  Duration? connectTimeout,
  Iterable<String>? protocols,
  Map<String, dynamic>? headers,
  io.HttpClient? customClient,
}) {
  return IOWebSocketChannel.connect(
    endpoint,
    connectTimeout: connectTimeout,
    protocols: protocols,
    headers: headers,
    customClient: customClient,
  );
}

io.HttpClient? _createWebSocketHttpClient(Uri endpoint) {
  final provider = _webSocketProxyDirectiveProvider;
  if (provider == null) return null;
  // The app registers one dynamic provider even while proxying is disabled.
  // Creating a custom HttpClient whose findProxy callback only returns DIRECT
  // is unnecessary and, on Android's dart:io WebSocket path, can leave the
  // HTTP upgrade future pending until connectTimeout on otherwise reachable
  // hosts. Keep the SDK's default client for DIRECT and create a custom client
  // only when this endpoint really needs a proxy.
  if (resolveWebSocketProxyDirective(endpoint) == 'DIRECT') return null;
  final client = io.HttpClient()..idleTimeout = const Duration(seconds: 30);
  client.findProxy = resolveWebSocketProxyDirective;
  return client;
}

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
  final Function(String message)? onFailure;
  final Function()? onReconnect;
  final Function()? onReady;
  final Function()? onHeartBeat;
  final Map<String, dynamic>? headers;
  final Iterable<String>? protocols;
  final Duration? inactivityTimeout;
  final Duration reconnectBaseDelay;
  final Duration shutdownTimeout;
  final WebSocketConnector connector;

  WebScoketUtils({
    required this.url,
    required this.heartBeatTime,
    this.onMessage,
    this.onClose,
    this.onFailure,
    this.onReconnect,
    this.onReady,
    this.onHeartBeat,
    this.headers,
    this.backupUrl,
    this.protocols,
    this.inactivityTimeout,
    this.reconnectBaseDelay = const Duration(seconds: 1),
    this.shutdownTimeout = const Duration(seconds: 2),
    this.connector = _connectIoWebSocket,
    List<String>? serverUrls,
  }) : serverUrls = _uniqueEndpoints(url, backupUrl, serverUrls);

  WebSocketChannel? webSocket;
  Timer? heartBeatTimer;
  Timer? reconnectTimer;
  StreamSubscription<dynamic>? streamSubscription;

  int reconnectTime = 0;
  int maxReconnectTime = 8;
  int _endpointIndex = 0;
  int _generation = 0;
  bool _manualClose = false;
  bool _connecting = false;
  Completer<void>? _connectAbort;
  Completer<void>? _connectDone;
  DateTime? _lastMessageAt;

  static List<String> _uniqueEndpoints(String primary, String? backup, List<String>? candidates) {
    final endpoints = <String>[];
    for (final endpoint in <String>[primary, ?backup, ...?candidates]) {
      final value = endpoint.trim();
      if (value.isNotEmpty && !endpoints.contains(value)) endpoints.add(value);
    }
    return endpoints;
  }

  Future<void> connect({bool retry = false}) async {
    if (_connecting) {
      await _connectDone?.future;
      return;
    }
    if (serverUrls.isEmpty) return;
    _manualClose = false;
    _connecting = true;
    final generation = ++_generation;
    final abort = Completer<void>();
    final done = Completer<void>();
    _connectAbort = abort;
    _connectDone = done;

    try {
      reconnectTimer?.cancel();
      reconnectTimer = null;
      await _disposeSocket();
      if (abort.isCompleted || _manualClose || generation != _generation) return;

      if (retry && serverUrls.length > 1) {
        _endpointIndex = (_endpointIndex + 1) % serverUrls.length;
      }

      final endpoint = serverUrls[_endpointIndex % serverUrls.length];
      final customClient = _createWebSocketHttpClient(Uri.parse(endpoint));
      final channel = connector(
        endpoint,
        connectTimeout: const Duration(seconds: 10),
        protocols: protocols,
        headers: headers,
        customClient: customClient,
      );
      webSocket = channel;
      try {
        await Future.any<void>([channel.ready, abort.future]);
      } finally {
        // The HTTP client is only needed for the upgrade handshake. Closing it
        // gracefully releases idle proxy connections without terminating the
        // detached WebSocket transport.
        customClient?.close(force: abort.isCompleted);
      }
      if (abort.isCompleted || _manualClose || generation != _generation) {
        // `close()` may already have detached and started closing this channel.
        // Only the remaining owner should request the sink close.
        if (identical(webSocket, channel)) {
          webSocket = null;
          unawaited(_closeSocket(channel));
        }
        return;
      }
      _ready(channel, generation);
    } catch (error) {
      if (!_manualClose && generation == _generation) {
        _scheduleReconnect(error.toString());
      }
    } finally {
      if (identical(_connectAbort, abort)) _connectAbort = null;
      if (identical(_connectDone, done)) {
        _connectDone = null;
        _connecting = false;
      }
      if (!done.isCompleted) done.complete();
    }
  }

  void _ready(WebSocketChannel channel, int generation) {
    status = SocketStatus.connected;
    reconnectTimer?.cancel();
    reconnectTimer = null;
    _lastMessageAt = DateTime.now();

    streamSubscription = channel.stream.listen(
      (data) {
        if (!_manualClose && generation == _generation) receiveMessage(data);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_manualClose && generation == _generation) _scheduleReconnect(error.toString());
      },
      onDone: () {
        if (!_manualClose && generation == _generation) {
          final code = channel.closeCode;
          final reason = channel.closeReason?.trim();
          _scheduleReconnect(
            'WebSocket closed'
            '${code == null ? '' : ' (code=$code)'}'
            '${reason == null || reason.isEmpty ? '' : ': $reason'}',
          );
        }
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
      if (status != SocketStatus.connected) return;
      final lastMessageAt = _lastMessageAt;
      if (lastMessageAt != null && DateTime.now().difference(lastMessageAt) >= _resolvedInactivityTimeout) {
        _scheduleReconnect('WebSocket heartbeat timed out');
        return;
      }
      onHeartBeat?.call();
    });
  }

  Duration get _resolvedInactivityTimeout {
    final configured = inactivityTimeout;
    if (configured != null) return configured;
    final heartbeatWindow = Duration(milliseconds: heartBeatTime * 3);
    const minimumWindow = Duration(seconds: 90);
    return heartbeatWindow > minimumWindow ? heartbeatWindow : minimumWindow;
  }

  void receiveMessage(dynamic data) {
    reconnectTime = 0;
    _lastMessageAt = DateTime.now();
    onMessage?.call(data);
  }

  void _scheduleReconnect(String message) {
    if (_manualClose || reconnectTimer?.isActive == true) return;

    onFailure?.call(message);
    status = SocketStatus.failed;
    heartBeatTimer?.cancel();
    heartBeatTimer = null;
    if (reconnectTime == 0) onReconnect?.call();

    if (reconnectTime >= maxReconnectTime) {
      onClose?.call('重连超过最大次数，与服务器断开连接：$message');
      unawaited(close());
      return;
    }

    reconnectTime++;
    _endpointIndex = (_endpointIndex + 1) % serverUrls.length;
    // Try the next server quickly; use a short backoff after every full round.
    final completedRounds = reconnectTime ~/ serverUrls.length;
    final delayMultiplier = completedRounds.clamp(0, 5) + 1;
    final delay = Duration(microseconds: reconnectBaseDelay.inMicroseconds * delayMultiplier);
    reconnectTimer = Timer(delay, () {
      reconnectTimer = null;
      connect();
    });
  }

  void sendMessage(dynamic message) {
    if (status != SocketStatus.connected) return;
    try {
      webSocket?.sink.add(message);
    } catch (error) {
      _scheduleReconnect(error.toString());
    }
  }

  Future<void> _disposeSocket({bool awaitSocketClose = true}) async {
    final subscription = streamSubscription;
    streamSubscription = null;
    try {
      await subscription?.cancel().timeout(shutdownTimeout);
    } catch (_) {}
    heartBeatTimer?.cancel();
    heartBeatTimer = null;
    final socket = webSocket;
    webSocket = null;
    _lastMessageAt = null;
    if (socket == null) return;
    final closeFuture = _closeSocket(socket);
    if (awaitSocketClose) {
      try {
        await closeFuture.timeout(shutdownTimeout);
      } on TimeoutException {
        // The close future remains observed by `_closeSocket`; release the
        // room operation after the bounded graceful-shutdown window.
      }
    } else {
      // `WebSocketSink.close` may wait for an HTTP upgrade which has not
      // completed yet. The connect-abort signal owns that attempt; keeping
      // room teardown behind the graceful close would recreate the stalled
      // handshake leak this path is meant to stop.
      unawaited(closeFuture);
    }
  }

  Future<void> _closeSocket(WebSocketChannel socket) async {
    try {
      await socket.sink.close();
    } catch (_) {}
  }

  Future<void> close() async {
    _manualClose = true;
    _generation++;
    status = SocketStatus.closed;
    reconnectTimer?.cancel();
    reconnectTimer = null;
    final pendingConnect = _connectDone?.future;
    final abort = _connectAbort;
    if (abort != null && !abort.isCompleted) abort.complete();
    await _disposeSocket(awaitSocketClose: pendingConnect == null);
    await pendingConnect;
  }

  void reconnect() {
    if (!_manualClose) _scheduleReconnect('Reconnect requested');
  }
}
