/// A normalized failure from a device-identity read.
///
/// Use [code] for programmatic handling. The [message] and [details] fields are
/// intended for diagnostics and should not be shown raw to end users.
final class DeviceIdentityException implements Exception {
  /// Creates a normalized device-identity exception.
  const new({required this.code, required this.message, this.details = const <String, Object?>{}, this.cause});

  /// Stable machine-readable code.
  ///
  /// `unsupported_on_platform` means the runtime has no identity backend, either
  /// because the platform has no information class or because the native side
  /// answered `notImplemented`. Any other code is a real read failure.
  final String code;

  /// Developer-facing explanation.
  final String message;

  /// Optional structured information about the failed read.
  final Map<String, Object?> details;

  /// Original exception for logging and debugging.
  final Object? cause;

  @override
  String toString() => 'DeviceIdentityException($code): $message';
}
