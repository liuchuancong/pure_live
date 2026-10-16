import 'package:live_device/src/display/brightness/screen_brightness_capabilities.dart';
import 'package:live_device/src/display/brightness/screen_brightness_scope.dart';

/// Unified interface for reading, changing and observing screen brightness.
///
/// Depend on this contract in playback or application services so the concrete
/// plugin can be replaced without changing those callers.
abstract interface class ScreenBrightnessService {
  /// Reads current brightness as an integer percentage in the range 0–100.
  Future<int> getBrightness({ScreenBrightnessScope scope = ScreenBrightnessScope.application});

  /// Sets brightness and returns the value reported as applied by the backend.
  ///
  /// [percentage] must be within 0–100.
  Future<int> setBrightness(int percentage, {ScreenBrightnessScope scope = ScreenBrightnessScope.application});

  /// Increases brightness by one native platform step.
  Future<int> increase({ScreenBrightnessScope scope = ScreenBrightnessScope.application});

  /// Decreases brightness by one native platform step.
  Future<int> decrease({ScreenBrightnessScope scope = ScreenBrightnessScope.application});

  /// Emits the current brightness first, then subsequent observed changes.
  Stream<int> watchBrightness({ScreenBrightnessScope scope = ScreenBrightnessScope.application});

  /// Reads capabilities of the active display backend.
  Future<ScreenBrightnessCapabilities> getCapabilities();

  /// Checks whether the requested scope can be written without prompting.
  ///
  /// Application scope does not require Android's global-write permission.
  Future<bool> hasPermission({ScreenBrightnessScope scope = ScreenBrightnessScope.system});

  /// Requests permission if the requested scope requires it, then rechecks.
  ///
  /// On Android, system scope can open the system settings page. The user may
  /// decline; callers must check the returned boolean before retrying a write.
  Future<bool> requestPermission({ScreenBrightnessScope scope = ScreenBrightnessScope.system});
}
