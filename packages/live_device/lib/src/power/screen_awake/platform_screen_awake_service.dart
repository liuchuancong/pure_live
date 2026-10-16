import 'package:live_device/src/power/screen_awake/screen_awake_exception.dart';
import 'package:live_device/src/power/screen_awake/screen_awake_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart' as plugin;

/// Screen-awake implementation backed by `wakelock_plus`.
///
/// The application or playback layer owns when to enable and disable the
/// wakelock. This service deliberately does not infer policy from playback
/// state or app lifecycle.
final class PlatformScreenAwakeService implements ScreenAwakeService {
  /// Creates the platform-backed service.
  const new();

  @override
  Future<void> enable() => _guard('enable', plugin.WakelockPlus.enable);

  @override
  Future<void> disable() => _guard('disable', plugin.WakelockPlus.disable);

  @override
  Future<void> setEnabled({required bool enabled}) => enabled ? enable() : disable();

  @override
  Future<bool> get isEnabled async {
    try {
      return await plugin.WakelockPlus.enabled;
    } catch (error) {
      throw ScreenAwakeException(
        code: 'read_state_failed',
        message: 'Could not read the screen wakelock state.',
        cause: error,
      );
    }
  }

  Future<void> _guard(String operation, Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      throw ScreenAwakeException(
        code: '${operation}_failed',
        message: 'Could not $operation the screen wakelock.',
        cause: error,
      );
    }
  }
}
