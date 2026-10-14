import 'dart:async';

import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Runs onHandshake on each connection a DanmakuSocket establishes.
typedef DanmakuHandshake = void Function(DanmakuSocket socket);

/// Receives one raw frame of a [DanmakuSocket] connection.
typedef DanmakuFrame = void Function(Object frame);

/// Reports that a [DanmakuSocket] gave up on its connection for good.
typedef DanmakuLost = void Function();

/// The WebSocket transport every site's danmaku session shares.
///
/// It wraps [LiveWebSocketClient] with the three things a session must not
/// repeat per platform: subscribe before [start] (the frame stream drops what
/// arrives first), re-run the protocol's handshake after every reconnect, and
/// report a socket the transport gave up on exactly once.
///
/// Heartbeats, silence watchdogs and reconnect back off are configured on the
/// [config], not hand-timed here.
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

  /// Called once when the transport stops retrying.
  final DanmakuLost onLost;

  LiveWebSocketClient? _client;
  StreamSubscription<Object?>? _frames;
  StreamSubscription<WebSocketConnectionState>? _states;
  bool _live = false;

  /// Whether the socket holds a connection right now.
  bool get isConnected => _client?.isConnected ?? false;

  /// Opens the socket; false when the endpoint could not be reached.
  Future<bool> start() async {
    await stop();
    final client = LiveWebSocketClient(uri: uri, config: config);
    _client = client;
    _frames = client.messages.listen((frame) {
      if (frame != null) onFrame(frame);
    });
    _states = client.states.listen((state) {
      if (!_live) return;
      if (state == WebSocketConnectionState.connected) {
        onHandshake(this);
        return;
      }
      if (state == WebSocketConnectionState.disconnected) {
        // The transport exhausted its reconnects.
        _live = false;
        onLost();
        unawaited(stop());
      }
    });
    _live = true;
    await client.connect();
    if (!client.isConnected) {
      _live = false;
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
    await _states?.cancel();
    _states = null;
    final client = _client;
    _client = null;
    await client?.dispose();
  }
}
