import 'package:live_device/src/network/adapter/ip_address.dart';

/// One network adapter on this machine and every address bound to it.
///
/// Adapters are what a machine actually has — a Wi-Fi interface, an Ethernet
/// port, a VPN tunnel, a container bridge — and each can carry several
/// addresses. `192.168.x.x` and `10.x.x.x` on one host is the ordinary case,
/// not an error to pick between.
final class NetworkAdapter {
  /// Creates an adapter reading with its address list copied defensively.
  new({required this.name, required this.index, required Iterable<IpAddress> addresses})
    : addresses = List<IpAddress>.unmodifiable(addresses);

  /// Operating-system interface name, for example `en0`, `wlan0` or `Ethernet`.
  ///
  /// Diagnostic only: the spelling differs per platform and per OS release, so
  /// never branch on it.
  final String name;

  /// Operating-system interface index.
  final int index;

  /// Every address currently bound to this adapter.
  final List<IpAddress> addresses;

  /// The IPv4 subset of [addresses], in the order the operating system reported them.
  List<IpAddress> get ipv4Addresses =>
      addresses.where((address) => address.version == IpAddressVersion.ipv4).toList(growable: false);

  /// The IPv6 subset of [addresses], in the order the operating system reported them.
  List<IpAddress> get ipv6Addresses =>
      addresses.where((address) => address.version == IpAddressVersion.ipv6).toList(growable: false);
}
