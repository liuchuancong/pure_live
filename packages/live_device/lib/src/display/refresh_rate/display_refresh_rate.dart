/// Thermal condition reported by the operating system.
///
/// A state of [DisplayThermalState.serious] or [DisplayThermalState.critical]
/// lets the OS clamp the refresh rate regardless of what the app requested.
enum DisplayThermalState {
  /// The device is within thermal limits; full performance is available.
  nominal,

  /// The device is warm; minor throttling may apply.
  fair,

  /// The device is hot; significant throttling is likely.
  serious,

  /// The device is critically hot; the OS may force a lower refresh rate.
  critical,

  /// The thermal state could not be determined on this platform.
  unknown,
}

/// A point-in-time snapshot of display refresh capability and device health.
///
/// Rates are hertz values reported by the operating system, not measurements of
/// the frames this app actually presented. A rate is `0` or `null` when the
/// backend has no qualified value.
final class DisplayRefreshRate {
  /// Creates an immutable refresh-rate snapshot.
  new({
    required this.currentHz,
    required Iterable<double> supportedHz,
    required this.maxHz,
    required this.isLowPowerMode,
    required this.thermalState,
  }) : supportedHz = List<double>.unmodifiable(supportedHz);

  /// Refresh rate currently reported by the operating system.
  ///
  /// `0` when the platform has no value to report.
  final double currentHz;

  /// Mode rates reported as compatible with the current display.
  ///
  /// This is not an exhaustive physical panel range. The list is a copied,
  /// unmodifiable snapshot, so later plugin updates cannot mutate it.
  final List<double> supportedHz;

  /// Highest refresh rate the display reports, or `null` when unknown.
  final double? maxHz;

  /// Whether the device is in a low-power configuration.
  ///
  /// Platforms that cannot tell report `false`.
  final bool isLowPowerMode;

  /// Thermal state read alongside this snapshot.
  final DisplayThermalState thermalState;

  /// Whether the display reports a maximum above 60 hertz.
  bool get canExceedSixtyHertz {
    final maximum = maxHz;
    return maximum != null && maximum > 60;
  }
}
