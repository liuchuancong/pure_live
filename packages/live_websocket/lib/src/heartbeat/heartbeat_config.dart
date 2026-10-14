/// Application-level heartbeat settings.
///
/// Protocol-level pings live in `WebSocketConfig.pingInterval`; configure
/// this only when the server expects a concrete payload or when liveness
/// must be judged from application traffic.
final class HeartbeatConfig {
  /// Creates heartbeat settings. `interval` must be positive, and `timeout`
  /// (when set) should be longer than `interval`.
  const new({required this.interval, this.payload, this.timeout});

  /// How often the heartbeat fires.
  final Duration interval;

  /// Builds the outgoing payload for every heartbeat tick.
  ///
  /// When null, nothing is sent and the heartbeat acts as a receive-only
  /// watchdog driven purely by `timeout`.
  final Object? Function()? payload;

  /// Marks the connection dead when no frame has arrived for this long and
  /// forces a reconnect.
  ///
  /// Only set this when the server answers heartbeats or streams traffic
  /// periodically; a server that never sends anything will otherwise be
  /// dropped on every check.
  final Duration? timeout;
}
