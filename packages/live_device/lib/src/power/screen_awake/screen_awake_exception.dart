/// A normalized failure from a screen-awake operation.
final class ScreenAwakeException implements Exception {
  /// Creates a screen-awake exception.
  const new({required this.code, required this.message, this.cause});

  /// Stable machine-readable failure code.
  final String code;

  /// Developer-facing description of the failed operation.
  final String message;

  /// Original platform or plugin error.
  final Object? cause;

  @override
  String toString() => 'ScreenAwakeException($code): $message';
}
