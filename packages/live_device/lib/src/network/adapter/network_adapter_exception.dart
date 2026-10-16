/// A normalized failure from network-adapter enumeration.
///
/// Use [code] for programmatic handling; [message] and [details] are for
/// diagnostics and should not be shown raw to end users.
final class NetworkAdapterException implements Exception {
  /// Creates a normalized adapter-enumeration exception.
  const new({required this.code, required this.message, this.details = const <String, Object?>{}, this.cause});

  /// Stable machine-readable code.
  final String code;

  /// Developer-facing explanation.
  final String message;

  /// Optional structured information about the failed enumeration.
  final Map<String, Object?> details;

  /// Original error for logging and debugging.
  final Object? cause;

  @override
  String toString() => 'NetworkAdapterException($code): $message';
}
