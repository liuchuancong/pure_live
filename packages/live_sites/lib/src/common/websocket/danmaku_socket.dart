import 'dart:async';

import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Runs onHandshake on each connection a DanmakuSocket establishes.
typedef DanmakuHandshake = void Function(DanmakuSocket socket);

/// Receives one raw frame of a [DanmakuSocket] connection.
typedef DanmakuFrame = void Function(Object frame);

/// Reports that a [DanmakuSocket] gave up on its connection for good, with
/// the transport's last word on why.
typedef DanmakuLost = void Function(String cause);

/// The WebSocket transport every site's danmaku session shares.
///
/// It wraps [LiveWebSocketClient] with the three things a session must not
/// repeat per platform: subscribe before [start] (the frame stream drops what
/// arrives first), re-run the protocol's handshake after every reconnect, and
/// report a socket the transport gave up on exactly once.
///
/// Heartbeats, silence watchdogs and reconnect back off are configured on the
/// [config], not hand-timed here. A protocol that wants to pick a new
/// endpoint per attempt (an edge that may itself be down) disables
/// [WebSocketConfig.reconnectPolicy] and restarts the socket from its
/// [onLost].
final class DanmakuSocket {
  /// A socket for [uri] running [onHandshake] per connection, forwarding
  /// frames to [onFrame] and reporting an unrecoverable loss through
  /// [onLost].
  DanmakuSocket({
    required this.uri,
    required this.config,
    required this.onHandshake,
    required this.onFrame,
    required this.onLost,
  });

  /// The danmaku endpoint.
  final Uri uri;

  /// Transport, heartbeat and reconnection settings for this protocol.
  final WebSocketConfig config;

  /// Called after every successful connection, including a reconnect.
  final DanmakuHandshake onHandshake;

  /// Called for every incoming frame while the socket is live.
  final DanmakuFrame onFrame;

  /// Called once when a connection that was live is not coming back.
  final DanmakuLost onLost;

  LiveWebSocketClient? _client;
  StreamSubscription<Object?>? _frames;
  StreamSubscription<Object>? _errors;
  StreamSubscription<WebSocketConnectionState>? _states;
  bool _live = false;
  bool _wasConnected = false;
  String? _lastError;

  /// Whether the socket holds a connection right now.
  bool get isConnected => _client?.isConnected ?? false;

  /// Opens the socket; false when the endpoint could not be reached.
  Future<bool> start() async {
    await stop();
    _wasConnected = false;
    _lastError = null;
    final client = LiveWebSocketClient(uri: uri, config: config);
    _client = client;
    // Subscribed before connect: the frame stream drops what arrives first.
    _frames = client.messages.listen((frame) {
      if (frame != null) onFrame(frame);
    });
    _errors = client.errors.listen((error) {
      _lastError = error is WebSocketException ? error.message : '$error';
    });
    _states = client.states.listen((state) {
      if (!_live) return;
      if (state == WebSocketConnectionState.connected) {
        _wasConnected = true;
        onHandshake(this);
        return;
      }
      // A socket that was live and whose reconnects ran out. A first attempt
      // that never connected is the caller's to report, not a loss.
      if (state == WebSocketConnectionState.disconnected && _wasConnected) {
        _live = false;
        onLost(_lastError ?? 'connection closed');
        unawaited(stop());
      }
    });
    _live = true;
    await client.connect();
    // The client's own answer, not the state event: a broadcast stream delivers
    // `connected` a microtask after `connect` returns, so reading `_wasConnected`
    // here decided "no connection" for a socket that had just opened and tore it
    // down — every site's danmaku then retried forever.
    if (!client.isConnected) {
      await stop();
      return false;
    }
    return true;
  }

  /// Sends [data] while connected; a sink that is not ready is the transport's
  /// to recover, so this drops the frame instead of throwing.
  void send(Object data) {
    final client = _client;
    if (client == null || !client.isConnected) return;
    try {
      client.send(data);
    } on Object {
      // A send racing a dropped connection is not the session's problem.
    }
  }

  /// Stops the socket without reporting a loss — an explicit disconnect, or a
  /// room whose broadcast ended.
  Future<void> stop() async {
    _live = false;
    await _frames?.cancel();
    _frames = null;
    await _errors?.cancel();
    _errors = null;
    await _states?.cancel();
    _states = null;
    final client = _client;
    _client = null;
    await client?.dispose();
  }
}
