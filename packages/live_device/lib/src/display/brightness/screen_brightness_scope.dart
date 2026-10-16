/// Selects the intended scope of a brightness operation.
///
/// [application] adjusts only the current app window on Android. The selected
/// plugin documents that the mode is ignored on iOS, Windows, macOS and Linux,
/// where brightness operations affect the system/display instead.
enum ScreenBrightnessScope {
  /// Prefer current-app-window brightness where the platform supports it.
  application,

  /// Change the global/system display brightness.
  ///
  /// On Android, writing this value requires the special `WRITE_SETTINGS`
  /// access to be granted by the user.
  system,
}
