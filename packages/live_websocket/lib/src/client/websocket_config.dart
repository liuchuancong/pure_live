import 'package:live_websocket/src/connection/reconnect_policy.dart';
import 'package:live_websocket/src/heartbeat/heartbeat_config.dart';

/// Configuration for a WebSocket connection.
final class WebSocketConfig {
  /// Creates transport settings.
  const new({
    this.protocols,
    this.headers,
    this.connectTimeout = const Duration(seconds: 15),
    this.shutdownTimeout = const Duration(seconds: 2),
    this.pingInterval,
    this.reconnectPolicy = const ReconnectPolicy(),
    this.heartbeat,
  });

  /// Subprotocols to offer during the opening handshake.
  final Iterable<String>? protocols;

  /// Extra HTTP headers for the opening handshake.
  ///
  /// Native platforms only; browsers cannot set arbitrary headers on a
  /// WebSocket handshake.
  final Map<String, dynamic>? headers;

  /// Maximum time to wait for the handshake before treating the attempt as
  /// failed. Must be positive.
  final Duration connectTimeout;

  /// Longest wait for the closing handshake before the socket is dropped.
  ///
  /// A peer that answers nothing cannot be allowed to decide when the caller
  /// finishes: `disconnect` waits this long for the close to be acknowledged
  /// and then reports the connection as closed regardless. Must be positive.
  final Duration shutdownTimeout;

  /// WebSocket protocol-level ping interval.
  ///
  /// Leave null when the server uses an application-level heartbeat
  /// ([heartbeat]) or when the platform manages pings itself (web).
  final Duration? pingInterval;

  /// Reconnection behaviour after an abnormal disconnect.
  final ReconnectPolicy reconnectPolicy;

  /// Optional application-level heartbeat; null disables it.
  final HeartbeatConfig? heartbeat;
}
