/// The storage error model: ten stable categories, per the storage
/// architecture spec.
///
/// Adapters translate raw platform exceptions into these; business
/// modules pattern-match on the type instead of parsing platform error
/// strings. A `cause` carries the underlying error for diagnostics — it
/// never replaces the typed category.
///
/// Read failures are failures: nothing in this model licenses swallowing
/// an exception and returning empty data. "Empty" is a value a store
/// returns only when the data genuinely does not exist
/// ([StorageNotFoundException] marks the opposite case explicitly).
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

/// The requested record or file does not exist.
final class StorageNotFoundException extends StorageException {
  /// Nothing exists under the requested key or path.
  const new(super.message, {super.cause});

  @override
  String get label => 'notFound';
}

/// The input, format or content failed validation.
final class StorageValidationException extends StorageException {
  /// The input was rejected before it touched storage.
  const new(super.message, {super.cause});

  @override
  String get label => 'validation';
}

/// Permission was denied for the requested operation.
final class StoragePermissionException extends StorageException {
  /// The operation lacked permission.
  const new(super.message, {super.cause});

  @override
  String get label => 'permissionDenied';
}

/// The storage backend is temporarily unusable (locked, unmounted,
/// failed to open).
final class StorageUnavailableException extends StorageException {
  /// Storage could not be reached right now.
  const new(super.message, {super.cause});

  @override
  String get label => 'unavailable';
}

/// The disk ran out of space.
final class StorageDiskFullException extends StorageException {
  /// Not enough room to complete the operation.
  const new(super.message, {super.cause});

  @override
  String get label => 'diskFull';
}

/// Stored data is damaged and cannot be read back.
final class StorageCorruptedException extends StorageException {
  /// The stored bytes no longer parse or fail their integrity check.
  const new(super.message, {super.cause});

  @override
  String get label => 'corrupted';
}

/// A schema migration failed; user data is left untouched.
final class StorageMigrationException extends StorageException {
  /// Moving schema [from] to [to] failed.
  const new(super.message, {this.from, this.to, super.cause});

  /// The schema version the migration started from.
  final int? from;

  /// The schema version the migration targeted.
  final int? to;

  @override
  String get label => 'migrationFailed';
}

/// A concrete read/write/replace operation failed after storage was
/// reached.
final class StorageOperationException extends StorageException {
  /// The operation itself failed.
  const new(super.message, {super.cause});

  @override
  String get label => 'operationFailed';
}

/// A version or concurrency conflict refused the operation.
final class StorageConflictException extends StorageException {
  /// The write conflicted with another version or writer.
  const new(super.message, {super.cause});

  @override
  String get label => 'conflict';
}

/// The operation was cancelled — flow control, not a failure.
final class StorageCancelledException extends StorageException {
  /// The caller or user cancelled the operation.
  const new(super.message, {super.cause});

  @override
  String get label => 'cancelled';
}

/// Anything the adapters could not classify.
final class StorageUnknownException extends StorageException {
  /// An unclassified storage failure.
  const new(super.message, {super.cause});

  @override
  String get label => 'unknown';
}
