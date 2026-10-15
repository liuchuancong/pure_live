/// Base of every error the platform layer reports upward.
///
/// Business modules pattern-match on these instead of catching raw
/// `FileSystemException`s or plugin errors; the adapters translate.
sealed class PlatformException implements Exception {
  /// A failure with a human-readable [message] and the optional
  /// underlying [cause].
  const new(this.message, {this.cause});

  /// What went wrong, safe to show or log.
  final String message;

  /// The underlying error, if an adapter surfaced one.
  final Object? cause;

  @override
  String toString() => message;
}

/// The requested storage area could not be resolved to a usable location —
/// every candidate failed probing.
final class StorageUnavailableException extends PlatformException {
  /// No writable location was found for the area.
  const new(super.message, {super.cause});
}

/// Permission was denied for the requested operation or directory.
final class StoragePermissionException extends PlatformException {
  /// The operation lacked permission.
  const new(super.message, {super.cause});
}

/// The disk is out of space for the requested write.
final class StorageCapacityException extends PlatformException {
  /// Not enough room to complete the operation.
  const new(super.message, {super.cause});
}

/// A concrete read/write/replace operation failed.
final class StorageOperationException extends PlatformException {
  /// The operation itself failed after a location was resolved.
  const new(super.message, {super.cause});
}

/// The user cancelled a picker or a confirmation — a normal outcome, not
/// an error condition; report it as flow control, never as a failure.
final class UserCancelledException extends PlatformException {
  /// The user backed out of the interaction.
  const new(super.message, {super.cause});
}

/// The platform does not support the requested capability.
final class UnsupportedCapabilityException extends PlatformException {
  /// The capability is unavailable on this platform or form factor.
  const new(super.message, {super.cause});
}
