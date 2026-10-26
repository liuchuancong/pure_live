/// Which way the device should be held while a room plays fullscreen
/// (the reference's `ScreenOrientation.landscape / portrait / free`).
enum ScreenOrientationPreference {
  /// Release the lock; the accelerometer decides, as outside fullscreen.
  followSystem,

  /// Lock the upright side (a portrait live stream).
  portrait,

  /// Lock the two sideways rotations (a landscape live stream).
  landscape;
}
