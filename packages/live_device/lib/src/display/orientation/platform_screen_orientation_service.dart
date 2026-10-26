import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart' show DeviceOrientation, SystemChrome;

import 'package:live_device/src/display/orientation/screen_orientation.dart';
import 'package:live_device/src/display/orientation/screen_orientation_service.dart';

/// Orientation implementation backed by Flutter's own `SystemChrome` — the
/// reference's `ScreenOrientation` (landscape the pair, portrait upright,
/// free by clearing the preferred list).
///
/// Desktop and web are inert: those hosts have no accelerometer to prefer,
/// and their fullscreen is the window's own. The native extras the
/// reference adds on Android (`sensorLandscape`, an auto-rotate probe over
/// a platform channel) are not part of this app's native bridge; Flutter's
/// own pair lock is what lands here, honestly degraded rather than faked.
final class PlatformScreenOrientationService implements ScreenOrientationService {
  /// Creates the platform-backed service.
  const new();

  static bool get _mobile =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  bool get isSupported => _mobile;

  @override
  Future<void> apply(ScreenOrientationPreference preference) async {
    if (!_mobile) return;
    await SystemChrome.setPreferredOrientations(switch (preference) {
      // An empty list is the reference's "free": every rotation the device
      // knows becomes allowed again.
      ScreenOrientationPreference.followSystem => const <DeviceOrientation>[],
      ScreenOrientationPreference.portrait => const <DeviceOrientation>[DeviceOrientation.portraitUp],
      ScreenOrientationPreference.landscape => const <DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    });
  }
}
