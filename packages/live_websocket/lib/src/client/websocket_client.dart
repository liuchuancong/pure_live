import 'dart:async';

import 'package:live_websocket/src/client/default_channel_factory.dart';
import 'package:live_websocket/src/client/websocket_config.dart';
import 'package:live_websocket/src/connection/connection_state.dart';
import 'package:live_websocket/src/exceptions/websocket_exception.dart';
import 'package:live_websocket/src/heartbeat/heartbeat_config.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Creates the underlying [WebSocketChannel] for a connection attempt.
///
/// The default factory is platform-adaptive and applies the transport
/// options from [WebSocketConfig]. Inject a custom factory in tests, or to
/// attach platform-specific options the config does not cover.
typedef WebSocketChannelFactory = WebSocketChannel Function(Uri uri, WebSocketConfig config);

/// A reusable WebSocket client with connection lifecycle, heartbeat and
/// reconnection management.
///
/// The client is transport-only. It surfaces raw frames on [messages] and
/// never interprets them; business modules own authentication, platform
/// protocols, codecs and dispatch rules.
final class LiveWebSocketClient {
  /// Creates a client for [uri].
  ///
  /// [uri] must be a `ws://` or `wss://` address. [config] controls
  /// transport timeouts, heartbeats and the reconnection policy, and
  /// [channelFactory] replaces how raw channels are built.
  new({required this.uri, this.config = const WebSocketConfig(), WebSocketChannelFactory? channelFactory})
    : _channelFactory = channelFactory ?? createDefaultChannel {
    if (!uri.hasScheme || (uri.scheme != 'ws' && uri.scheme != 'wss')) {
      throw ArgumentError.value(uri, 'uri', 'Expected a ws:// or wss:// URI');
    }
  }

  /// The remote endpoint this client connects to.
  final Uri uri;

  /// Transport, heartbeat and reconnection settings.
  final WebSocketConfig config;

  final WebSocketChannelFactory _channelFactory;

  static const String _retryLimitReached = 'Reconnect limit reached';

  final StreamController<Object?> _messages = StreamController<Object?>.broadcast();
  final StreamController<Object> _errors = StreamController<Object>.broadcast();
  final StreamController<WebSocketConnectionState> _states = StreamController<WebSocketConnectionState>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  DateTime _lastReceivedAt = DateTime.fromMillisecondsSinceEpoch(0);

  WebSocketConnectionState _state = WebSocketConnectionState.disconnected;
  int _retryCount = 0;
  int _generation = 0;
  bool _disposed = false;
  bool _manualClose = false;
  Future<void>? _connecting;

  /// Incoming frames, as delivered by the underlying channel.
  ///
  /// The stream is broadcast; frames emitted before anyone listens are
  /// dropped, so subscribe before calling [connect].
  Stream<Object?> get messages => _messages.stream;

  /// Connection and heartbeat errors. The stream is broadcast.
  Stream<Object> get errors => _errors.stream;

  /// Connection state transitions. The stream is broadcast.
  Stream<WebSocketConnectionState> get states => _states.stream;

  /// The current connection state.
  WebSocketConnectionState get state => _state;

  /// Whether the client currently holds a healthy connection.
  bool get isConnected => _state == WebSocketConnectionState.connected;

  /// Reconnect attempts since the last successful connection.
  int get retryCount => _retryCount;

  /// Opens the connection.
  ///
  /// Concurrent calls share one attempt, and a call during a reconnection
  /// loop cancels the pending retry timer and starts a fresh attempt.
  Future<void> connect() {
    _ensureNotDisposed();

    if (isConnected) {
      return Future<void>.value();
    }

    final pending = _connecting;
    if (pending != null) {
      return pending;
    }

    _manualClose = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    return _launchOpen(reconnecting: false);
  }

  /// Sends a frame. Any payload the underlying channel accepts is allowed.
  ///
  /// Throws [WebSocketException] when the client is not connected, and
  /// rethrows send failures after reporting them on [errors].
  void send(Object data) {
    _ensureNotDisposed();

    final channel = _channel;
    if (!isConnected || channel == null) {
      throw const WebSocketException('WebSocket is not connected');
    }

    try {
      channel.sink.add(data);
    } on Object catch (error) {
      _errors.add(WebSocketException('Failed to send message', cause: error));
      rethrow;
    }
  }

  /// Closes the connection and stops all reconnection activity.
  ///
  /// Safe to call from any state and multiple times.
  Future<void> disconnect({int? closeCode, String? closeReason}) async {
    if (_disposed) {
      return;
    }

    _manualClose = true;
    _generation++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopHeartbeat();
    _connecting = null;

    await _subscription?.cancel();
    _subscription = null;
    final channel = _channel;
    _channel = null;

    try {
      await channel?.sink.close(closeCode, closeReason);
    } on Object {
      // A channel whose handshake never completed may refuse to close.
    } finally {
      _setState(WebSocketConnectionState.disconnected);
    }
  }

  /// Closes the connection and releases every resource. The client cannot
  /// be reused afterwards. Safe to call multiple times.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    await disconnect();
    _disposed = true;

    await _messages.close();
    await _errors.close();
    await _states.close();
  }

  Future<void> _launchOpen({required bool reconnecting}) {
    final future = _open(reconnecting: reconnecting);
    _connecting = future;
    return future.whenComplete(() {
      if (identical(_connecting, future)) {
        _connecting = null;
      }
    });
  }

  Future<void> _open({required bool reconnecting}) async {
    final generation = ++_generation;

    _setState(reconnecting ? WebSocketConnectionState.reconnecting : WebSocketConnectionState.connecting);

    WebSocketChannel? channel;
    try {
      channel = _channelFactory(uri, config);
      _channel = channel;

      await channel.ready.timeout(config.connectTimeout);

      if (_disposed || _manualClose || generation != _generation) {
        _channel = null;
        _closeQuietly(channel);
        return;
      }

      _retryCount = 0;
      _setState(WebSocketConnectionState.connected);
      _startHeartbeat();

      _subscription = channel.stream.listen(
        (dynamic message) {
          if (generation == _generation && !_disposed) {
            _lastReceivedAt = DateTime.now();
            _messages.add(message);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (generation == _generation && !_disposed) {
            _errors.add(error);
          }
        },
        onDone: () {
          if (generation == _generation && !_disposed) {
            _channel = null;
            _subscription = null;
            _stopHeartbeat();
            _scheduleReconnect();
          }
        },
        cancelOnError: false,
      );
    } on Object catch (error) {
      if (identical(_channel, channel)) {
        _channel = null;
      }
      _closeQuietly(channel);
      if (generation != _generation || _disposed) {
        return;
      }
      _errors.add(WebSocketException('Failed to connect to $uri', cause: error));
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _manualClose) {
      _setState(WebSocketConnectionState.disconnected);
      return;
    }

    final policy = config.reconnectPolicy;
    final nextAttempt = _retryCount + 1;

    if (!policy.shouldRetry(nextAttempt)) {
      _setState(WebSocketConnectionState.disconnected);
      _errors.add(const WebSocketException(_retryLimitReached));
      return;
    }

    _retryCount = nextAttempt;
    _setState(WebSocketConnectionState.reconnecting);

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(policy.delayForAttempt(nextAttempt), () {
      if (_disposed || _manualClose) {
        return;
      }
      unawaited(_launchOpen(reconnecting: true));
    });
  }

  void _startHeartbeat() {
    final heartbeat = config.heartbeat;
    if (heartbeat == null) {
      return;
    }

    _lastReceivedAt = DateTime.now();
    _heartbeatTimer = Timer.periodic(heartbeat.interval, (_) {
      unawaited(_onHeartbeatTick(heartbeat));
    });
  }

  Future<void> _onHeartbeatTick(HeartbeatConfig heartbeat) async {
    final channel = _channel;
    if (channel == null || !isConnected || _disposed) {
      return;
    }

    final timeout = heartbeat.timeout;
    if (timeout != null && DateTime.now().difference(_lastReceivedAt) > timeout) {
      _errors.add(const WebSocketException('Heartbeat timeout'));
      _stopHeartbeat();

      final subscription = _subscription;
      _subscription = null;
      _channel = null;
      if (subscription != null) {
        await subscription.cancel();
      }

      _closeQuietly(channel);
      _scheduleReconnect();
      return;
    }

    final payload = heartbeat.payload?.call();
    if (payload != null) {
      try {
        channel.sink.add(payload);
      } on Object catch (error) {
        _errors.add(WebSocketException('Failed to send heartbeat', cause: error));
      }
    }
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _setState(WebSocketConnectionState next) {
    if (_state == next || _states.isClosed) {
      return;
    }

    _state = next;
    _states.add(next);
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw const WebSocketException('WebSocket client has been disposed');
    }
  }

  void _closeQuietly(WebSocketChannel? channel) {
    if (channel == null) {
      return;
    }

    try {
      unawaited(channel.sink.close().then((_) {}, onError: (Object _) {}));
    } on Object {
      // Closing a channel whose handshake never completed can throw.
    }
  }
}
