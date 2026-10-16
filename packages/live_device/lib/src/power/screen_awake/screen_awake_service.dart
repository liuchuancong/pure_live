/// Controls whether the operating system may automatically turn the display off.
///
/// This is a screen wakelock only. It does not keep the Dart isolate or CPU
/// running after the application is backgrounded.
abstract interface class ScreenAwakeService {
  /// Enables the screen wakelock.
  Future<void> enable();

  /// Disables the screen wakelock.
  Future<void> disable();

  /// Sets the requested wakelock state.
  Future<void> setEnabled({required bool enabled});

  /// Reads the wakelock state reported by the platform backend.
  Future<bool> get isEnabled;
}
