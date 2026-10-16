/// A normalized brightness-operation failure exposed by `live_device`.
///
/// [code] is stable enough for programmatic handling. [message] and [details]
/// are intended for diagnostics; do not show raw native errors directly to users.
final class ScreenBrightnessException implements Exception {
  /// Creates a normalized brightness exception.
  const new({required this.code, required this.message, this.details = const <String, Object?>{}, this.cause});

  /// Machine-readable error code.
  final String code;

  /// Developer-facing explanation.
  final String message;

  /// Optional structured data from the platform implementation.
  final Map<String, Object?> details;

  /// Original exception, retained for logging and debugging.
  final Object? cause;

  @override
  String toString() => 'ScreenBrightnessException($code): $message';
}
