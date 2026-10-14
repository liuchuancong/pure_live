import 'package:live_websocket/src/connection/reconnect_policy.dart';
import 'package:live_websocket/src/heartbeat/heartbeat_config.dart';

/// Configuration for a WebSocket connection.
final class WebSocketConfig {
  /// Creates transport settings.
  const new({
    this.protocols,
    this.headers,
    this.connectTimeout = const Duration(seconds: 15),
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
