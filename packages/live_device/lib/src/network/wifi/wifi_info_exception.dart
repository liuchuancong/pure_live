/// A normalized failure from a Wi-Fi information operation.
///
/// Use [code] for programmatic handling. The [message] and [details] fields are
/// intended for diagnostics and should not be shown raw to end users.
final class WifiInfoException implements Exception {
  /// Creates a normalized Wi-Fi information exception.
  const new({required this.code, required this.message, this.details = const <String, Object?>{}, this.cause});

  /// Stable machine-readable code.
  final String code;

  /// Developer-facing explanation.
  final String message;

  /// Optional structured information about the failed operation.
  final Map<String, Object?> details;

  /// Original exception for logging and debugging.
  final Object? cause;

  @override
  String toString() => 'WifiInfoException($code): $message';
}
