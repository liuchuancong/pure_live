import 'package:live_device/src/power/battery/battery_capabilities.dart';
import 'package:live_device/src/power/battery/battery_exception.dart';
import 'package:live_device/src/power/battery/battery_status.dart';

/// Reads and observes the battery of the device the app is running on.
///
/// Depend on this contract in playback or application services so the concrete
/// plugin can be replaced without changing those callers. Battery level is a
/// point-in-time read; only charging state has a platform event stream.
abstract interface class BatteryService {
  /// Reads the battery charge level as an integer percentage in the range 0–100.
  ///
  /// Returns `-1` when the platform reports that it has no battery, which is
  /// the normal answer on desktop machines; it is not a failure. Values outside
  /// the range are clamped by the platform implementation.
  Future<int> readLevel();

  /// Reads the current charging state.
  ///
  /// A machine without a battery reports [BatteryStatus.unknown].
  Future<BatteryStatus> readStatus();

  /// Reads whether the operating system is in battery-saver mode.
  ///
  /// This API exists only on Android, iOS, macOS and Windows. Other platforms
  /// throw [BatteryException] with the `unsupported_on_platform` code, so check
  /// [BatteryCapabilities.canReadPowerSaveMode] before offering the value.
  Future<bool> isInPowerSaveMode();

  /// Emits charging-state changes observed from the platform.
  ///
  /// The stream carries no initial value; call [readStatus] first when the UI
  /// needs both a snapshot and subsequent updates. Cancel the subscription when
  /// the consumer no longer needs updates — the last cancelled subscription
  /// tears down the native listener.
  Stream<BatteryStatus> watchStatus();

  /// Returns support declared for the current runtime platform.
  ///
  /// Declared support does not guarantee usable hardware; a runtime failure is
  /// surfaced as [BatteryException].
  Future<BatteryCapabilities> getCapabilities();
}
