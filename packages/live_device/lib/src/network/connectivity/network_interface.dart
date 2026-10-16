/// Platform-neutral network interface types a connectivity backend can report.
///
/// `live_device` normalizes whatever the active backend reports into these
/// values, so callers never depend on a third-party connectivity enum. A single
/// reading can name several interfaces at once, and platforms differ in which
/// values they can ever produce; the per-value documentation records that.
enum NetworkInterface {
  /// A Bluetooth link used as a network transport.
  ///
  /// Only Android and Linux report this value.
  bluetooth,

  /// A Wi-Fi association with an access point.
  ///
  /// Every supported platform, including web, can report this value.
  wifi,

  /// A wired Ethernet link.
  ///
  /// Web never reports this value.
  ethernet,

  /// A cellular data connection.
  ///
  /// This is the name `live_device` uses for what some platforms call `mobile`.
  /// Only Android, iOS and macOS can report it.
  cellular,

  /// The platform explicitly reported that no interface is active.
  none,

  /// A VPN tunnel interface.
  ///
  /// iOS and web never report this value; those platforms fold a VPN into
  /// [other] or into the underlying interface.
  vpn,

  /// A highly constrained satellite link.
  ///
  /// Only Android and iOS report this value, and they may report it together
  /// with [cellular].
  satellite,

  /// An interface the platform could not classify.
  ///
  /// Web never reports this value.
  other,
}
