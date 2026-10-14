/// Base exception for WebSocket client operations.
final class WebSocketException implements Exception {
  /// Creates an exception with a human-readable `message` and the optional
  /// underlying `cause`.
  const new(this.message, {this.cause});

  /// Human-readable description of what went wrong. Never embed tokens or
  /// other secrets here.
  final String message;

  /// The underlying error, when there is one.
  final Object? cause;

  @override
  String toString() {
    return 'WebSocketException: $message'
        '${cause == null ? '' : ' ($cause)'}';
  }
}
