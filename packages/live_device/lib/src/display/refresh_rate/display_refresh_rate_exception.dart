/// A normalized failure from a display refresh-rate operation.
///
/// Use [code] for programmatic handling. The `unsupported_on_platform` code
/// means the current platform has no such API, which is distinct from a call
/// that was attempted and failed. A preferred-rate request that the backend
/// rejects is reported as a `DisplayRefreshRatePreference` value rather than as
/// a failure, so no exception means the platform refused the feature. [message]
/// and [details] are intended for diagnostics and should not be shown raw to
/// end users.
final class DisplayRefreshRateException implements Exception {
  /// Creates a normalized display refresh-rate exception.
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
  String toString() => 'DisplayRefreshRateException($code): $message';
}
