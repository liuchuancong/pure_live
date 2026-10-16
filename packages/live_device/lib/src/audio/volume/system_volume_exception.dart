/// A normalized failure from a system-volume operation.
///
/// Use [code] for programmatic handling. The [message] and [details] fields are
/// intended for diagnostics and should not be shown raw to end users.
final class SystemVolumeException implements Exception {
  /// Creates a normalized system-volume exception.
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
  String toString() => 'SystemVolumeException($code): $message';
}
