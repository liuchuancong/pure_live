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
    required this.aggregatesPowerSources,
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

  /// Whether one reading silently folds every power source the OS can see.
  ///
  /// The plugin surfaces a single battery value even where the platform tracks
  /// several sources, so an extra battery or a UPS is invisible through it.
  /// macOS calls `IOPSCopyPowerSourcesList` and then reads only `sources[0]`;
  /// Linux uses UPower's single `DisplayDevice` rather than `client.devices`;
  /// Windows uses `GetSystemPowerStatus`, which is already a system-wide
  /// aggregate. On those three a second source cannot be reported separately.
  /// Android and iOS are single-battery by API, so the flag is false there and
  /// on the web and fuchsia, where nothing is being collapsed.
  final bool aggregatesPowerSources;

  /// Runtime platform label for diagnostics, not intended for feature branching.
  final String platformName;
}
