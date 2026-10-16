/// Charging state of the device battery, independent of any plugin backend.
///
/// The values are stable `live_device` names; the plugin's own enum is never
/// exposed to callers.
enum BatteryStatus {
  /// The battery is fully charged.
  full,

  /// The battery is charging.
  charging,

  /// External power is connected, but the battery is not charging.
  connectedNotCharging,

  /// The battery is discharging.
  discharging,

  /// The platform cannot determine the charging state.
  ///
  /// Machines without a battery report this value instead of failing.
  unknown,
}
