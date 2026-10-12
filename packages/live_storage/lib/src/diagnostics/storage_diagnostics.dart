/// Describes the current health of the storage subsystem.
enum StorageHealth {
  /// Storage has not been initialized.
  uninitialized,

  /// Storage is initialized and operating normally.
  healthy,

  /// Storage is operational but has reported a non-fatal issue.
  degraded,

  /// Storage cannot currently be used.
  unavailable,
}

/// Describes a diagnostic snapshot of the storage subsystem.
final class StorageDiagnostics {
  /// Creates a storage diagnostic snapshot.
  const new({required this.health, required this.initialized, this.message, this.lastError});

  /// The current storage health.
  final StorageHealth health;

  /// Whether storage initialization has completed.
  final bool initialized;

  /// An optional human-readable diagnostic message.
  final String? message;

  /// The most recent storage error, if available.
  final Object? lastError;
}
