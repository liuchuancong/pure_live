/// Connection states exposed to consumers.
enum WebSocketConnectionState {
  /// No connection. The client is idle, stopped after an explicit
  /// `disconnect`, or gave up after exhausting the reconnect policy.
  disconnected,

  /// A connection attempt started through `LiveWebSocketClient.connect`
  /// is in flight.
  connecting,

  /// The handshake completed and frames may flow.
  connected,

  /// A retry is scheduled or in flight after an abnormal disconnect.
  reconnecting,
}
