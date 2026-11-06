import 'dart:async';
import 'dart:math' as math;

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
  /// [onLost]. With [endpoints], every restart takes the next one around the
  /// list — an edge that is itself down does not get retried forever — and
  /// the socket only reports a loss once its own rotation is exhausted.
  DanmakuSocket({
    required this.config,
    required this.onHandshake,
    required this.onFrame,
    required this.onLost,
    required Uri uri,
    List<Uri>? endpoints,
    this.maxRotationAttempts = 8,
    this.rotationBaseDelay = const Duration(seconds: 1),
    this.channelFactory,
  }) : endpoints = (endpoints == null || endpoints.isEmpty) ? <Uri>[uri] : endpoints;

  /// Builds the raw channel; null uses the platform default. Tests inject
  /// one.
  final WebSocketChannelFactory? channelFactory;

  /// The danmaku endpoints, first to try first.
  final List<Uri> endpoints;

  /// The endpoint the rotation is at now (the first one before it moved).
  Uri get uri => endpoints[_attempt % endpoints.length];

  /// Failures in a row across the rotation before the loss is reported.
  final int maxRotationAttempts;

  /// The wait before the next endpoint; it grows by one step of itself
  /// after every full round of the list, at most six.
  final Duration rotationBaseDelay;

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
  int _attempt = 0;

  /// Whether the socket holds a connection right now.
  bool get isConnected => _client?.isConnected ?? false;

  /// Opens the socket; false when the endpoint could not be reached.
  Future<bool> start() async {
    await stop();
    _wasConnected = false;
    _lastError = null;
    _attempt = 0;
    final opened = await _openCurrent();
    return opened;
  }

  /// Opens the socket on the endpoint the rotation is at now; false when
  /// that endpoint could not be reached.
  Future<bool> _openCurrent() async {
    final client = LiveWebSocketClient(
      uri: endpoints[_attempt % endpoints.length],
      config: config,
      channelFactory: channelFactory,
    );
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
      // A socket that was live and whose reconnects ran out. With several
      // endpoints the socket rotates through the rest before giving up; a
      // first attempt that never connected is the caller's to report, not a
      // loss.
      if (state == WebSocketConnectionState.disconnected && _wasConnected) {
        _live = false;
        if (endpoints.length > 1 && _attempt + 1 < maxRotationAttempts) {
          unawaited(_rotateAfterLoss());
          return;
        }
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
      return await _afterFailedAttempt();
    }
    return true;
  }

  /// The next endpoint after a failed or lost one, while the rotation has
  /// attempts left; null when it is exhausted and the loss is the caller's.
  Future<bool> _afterFailedAttempt() async {
    await stop();
    _attempt++;
    if (endpoints.length <= 1 || _attempt >= maxRotationAttempts) {
      return false;
    }
    // A full round of the list means the edges themselves look down: the
    // wait grows a step, and stops growing after six.
    final round = _attempt ~/ endpoints.length;
    final delay = rotationBaseDelay * (1 + math.min(round, 5));
    _live = true;
    await Future<void>.delayed(delay);
    if (!_live) return false;
    await _openCurrent();
    return _client?.isConnected ?? false;
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

  /// The next endpoint after a live connection was lost: advance the
  /// rotation, wait out the round's step, and open again. A loss is only
  /// reported when the rotation itself is exhausted.
  Future<void> _rotateAfterLoss() async {
    await stop();
    _attempt++;
    final round = _attempt ~/ endpoints.length;
    final delay = rotationBaseDelay * (1 + math.min(round, 5));
    _live = true;
    await Future<void>.delayed(delay);
    if (!_live) return;
    await _openCurrent();
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
