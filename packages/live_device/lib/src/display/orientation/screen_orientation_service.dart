import 'package:live_device/src/display/orientation/screen_orientation.dart';

/// Contract for putting the device into one of the orientation
/// preferences. The concrete implementation owns the platform call;
/// playback and settings code depend on this contract only.
abstract interface class ScreenOrientationService {
  /// Whether this platform answers orientation locks at all
  /// (Android and iOS do; desktop and web are inert).
  bool get isSupported;

  /// Asks the platform to hold the device in [preference].
  ///
  /// Inert on an unsupported platform. An Android display too large to lock
  /// (a tablet or an unfolded foldable) is left alone, as in the reference.
  Future<void> apply(ScreenOrientationPreference preference);
}
