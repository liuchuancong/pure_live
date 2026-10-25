/// An operating-system auto-start entry the app can read and change.
///
/// The contract owns only the launch-at-login registration; when the app
/// should offer it, and what the setting means to the viewer, stay with the
/// application. Unsupported platforms report it through [capabilities].
abstract interface class StartupService {
  /// What this platform can do with auto-start.
  StartupCapabilities get capabilities;

  /// Whether the current build is registered to start at login.
  ///
  /// Throws [StartupException] when the platform cannot be read.
  Future<bool> isEnabled();

  /// Registers or removes this build's auto-start entry.
  ///
  /// Throws [StartupException] when the platform has no such entry path or
  /// the change could not be written.
  Future<void> setEnabled({required bool enabled});
}

/// What the active platform supports for auto-start.
final class StartupCapabilities {
  /// Creates a capability description.
  const new({required this.supported, required this.platformName});

  /// Whether [StartupService] can read and change the entry.
  final bool supported;

  /// Runtime platform label for diagnostics, not feature branching.
  final String platformName;
}

/// A normalized failure from an auto-start operation.
final class StartupException implements Exception {
  /// Creates an auto-start exception.
  const new({required this.code, required this.message, this.cause});

  /// Stable machine-readable code.
  final String code;

  /// Developer-facing explanation.
  final String message;

  /// Original platform error.
  final Object? cause;

  @override
  String toString() => 'StartupException($code): $message';
}
