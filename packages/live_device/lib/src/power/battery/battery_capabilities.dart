import 'package:live_device/src/power/battery/battery_status.dart';

/// Battery API support declared for the current runtime platform.
///
/// These flags describe the platform API, not the hardware: a desktop without a
/// battery still exposes the read and observe APIs, and reports `-1` or
/// [BatteryStatus.unknown] instead of failing.
final class BatteryCapabilities {
  /// Creates an immutable battery capability description.
  const new({
    required this.canReadLevel,
    required this.canReadStatus,
    required this.canObserve,
    required this.canReadPowerSaveMode,
    required this.platformName,
  });

  /// Whether a battery percentage can be read.
  final bool canReadLevel;

  /// Whether the charging state can be read.
  final bool canReadStatus;

  /// Whether charging-state changes can be observed.
  final bool canObserve;

  /// Whether the platform exposes battery-saver status.
  ///
  /// This is unavailable on Linux, web and fuchsia; those platforms raise
  /// `BatteryException` with the `unsupported_on_platform` code instead.
  final bool canReadPowerSaveMode;

  /// Runtime platform label for diagnostics, not intended for feature branching.
  final String platformName;
}
