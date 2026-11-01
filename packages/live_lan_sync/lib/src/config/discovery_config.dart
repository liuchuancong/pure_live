/// The default mDNS service type, overridable so another application can
/// run this engine beside this one on the same network.
const String kDefaultLanSyncServiceType = '_purelive-sync._tcp';

/// How the device is discovered on the LAN.
///
/// mDNS can be blocked by routers, guest-network policies or OS permission
/// dialogs, so manual addresses and QR pairing are first-class capabilities,
/// not debug fallbacks.
final class LanSyncDiscoveryConfig {
  /// The discovery defaults.
  const new({
    this.enabled = true,
    this.serviceType = kDefaultLanSyncServiceType,
    this.scanInterval = const Duration(seconds: 15),
    this.serviceTtl = const Duration(seconds: 120),
    this.enableManualAddress = true,
    this.enableQrPairing = true,
    this.ipv4Enabled = true,
    this.ipv6Enabled = false,
    this.preferredNetworkInterfaces = const <String>[],
  });

  /// Whether background discovery runs at all.
  final bool enabled;

  /// The DNS-SD service type to register and browse.
  final String serviceType;

  /// How often the browser re-scans for missed announcements.
  final Duration scanInterval;

  /// How long a discovered device stays listed without a refresh.
  final Duration serviceTtl;

  /// Whether connecting by a manually entered address is offered.
  final bool enableManualAddress;

  /// Whether QR-code pairing is offered.
  final bool enableQrPairing;

  /// Whether IPv4 discovery is performed.
  final bool ipv4Enabled;

  /// Whether IPv6 discovery is performed.
  final bool ipv6Enabled;

  /// Interface names discovery should prefer, when the host must pin one.
  final List<String> preferredNetworkInterfaces;

  /// Returns the human-readable problems with this configuration, or an
  /// empty list when it is usable as is.
  List<String> validate() {
    final problems = <String>[];
    if (!RegExp(r'^_[A-Za-z0-9-]+\._(tcp|udp)$').hasMatch(serviceType)) {
      problems.add('discovery.serviceType must look like "_name._tcp"');
    }
    if (scanInterval <= Duration.zero) {
      problems.add('discovery.scanInterval must be positive');
    }
    if (serviceTtl <= Duration.zero) {
      problems.add('discovery.serviceTtl must be positive');
    }
    if (!ipv4Enabled && !ipv6Enabled) {
      problems.add('discovery must enable at least one of IPv4 or IPv6');
    }
    return problems;
  }
}
