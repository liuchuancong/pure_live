import 'package:live_device/src/network/adapter/network_adapter_service.dart';

/// A point-in-time description of the Wi-Fi network a device is joined to.
///
/// Every value is nullable because platforms simply do not see some of this:
/// a simulator returns nothing, a wired or cellular device has no Wi-Fi to
/// describe, and a lookup that does not exist on the running platform is
/// reported as `null` instead of failing the whole read. Treat `null` as "not
/// known here", never as "the device is not on Wi-Fi".
final class WifiNetworkInfo {
  /// Creates a Wi-Fi information snapshot.
  const new({
    this.ssid,
    this.bssid,
    this.primaryIpv4Address,
    this.primaryIpv6Address,
    this.subnetMask,
    this.gatewayAddress,
    this.broadcastName,
  });

  /// The network name (SSID) exactly as the operating system reports it.
  ///
  /// Android wraps the name in double quotes and only answers while location
  /// services are on and location access is granted. iOS answers only when the
  /// app holds the Wi-Fi information entitlement or has been given the network
  /// through another mechanism, and never on a simulator.
  final String? ssid;

  /// The MAC address of the access point this device is joined to.
  ///
  /// Carries the same Android and iOS prerequisites as [ssid].
  final String? bssid;

  /// The one IPv4 address the platform names for the Wi-Fi network.
  ///
  /// Called `primary` because the underlying plugin can report only one address
  /// per family on every platform — Android takes the first `linkAddresses`
  /// entry that looks like IPv4, iOS keeps the first row of its interface walk,
  /// macOS only reads `en0`, Windows the first unicast address, and Linux takes
  /// the first entry of a NetworkManager list that may hold several. A host that
  /// also holds a VPN or bridge address, such as a `10.x` beside this `192.168.x`,
  /// does not show it here; use [NetworkAdapterService] for the full set.
  final String? primaryIpv4Address;

  /// The one IPv6 address the platform names for the Wi-Fi network.
  ///
  /// Same single-value limit as [primaryIpv4Address]. Platforms that hide the
  /// interface prefix report only the address, and many home networks have no
  /// global IPv6 address at all.
  final String? primaryIpv6Address;

  /// The subnet mask of the Wi-Fi network as a dotted-quad string.
  final String? subnetMask;

  /// The gateway address of the Wi-Fi network as a dotted-quad string.
  ///
  /// Some Android builds report the device's own interface address here instead
  /// of the real gateway, so use this value for diagnostics, not for routing.
  final String? gatewayAddress;

  /// The broadcast value the platform reports for the Wi-Fi network.
  ///
  /// This is normally the dotted-quad broadcast address, for example
  /// `192.168.1.255`, and it is derived from the interface address and subnet
  /// mask on platforms that do not expose it directly.
  final String? broadcastName;

  /// Whether the platform identified which network this device is on.
  bool get hasNetworkIdentity => ssid != null || bssid != null;
}
