/// The storage error model.
///
/// Categories grow with the features that need them; everything shares
/// the [StorageException] base so modules pattern-match on type instead
/// of parsing platform error strings, and a `cause` carries the
/// underlying error for diagnostics without replacing the typed
/// category.
sealed class StorageException implements Exception {
  /// A failure with a human-readable [message] and the underlying
  /// [cause].
  const new(this.message, {this.cause});

  /// What went wrong, safe to show or log.
  final String message;

  /// The underlying error, if an adapter surfaced one.
  final Object? cause;

  /// Short machine-friendly category label.
  String get label;

  @override
  String toString() => '$label: $message';
}

/// The input was rejected before it touched storage.
final class StorageValidationException extends StorageException {
  /// The input, format or content failed validation.
  const new(super.message, {super.cause});

  @override
  String get label => 'validation';
}
