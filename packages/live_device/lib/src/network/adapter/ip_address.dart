/// The IP version of an [IpAddress].
enum IpAddressVersion {
  /// An IPv4 address, such as the `192.168.1.23` and `10.8.0.6` a machine can
  /// hold at the same time.
  ipv4,

  /// An IPv6 address, including link-local and unique-local forms.
  ipv6,

  /// A family the operating system reported that is neither of the above.
  ///
  /// The interface table only yields IPv4 and IPv6 today; this exists so a new
  /// family becomes an honest `unknown` rather than a wrong IPv4.
  unknown,
}

/// One address bound to a network adapter.
///
/// A machine answers with a set of these per adapter and often more than one
/// adapter, which is why `NetworkAdapterService` exists: the Wi-Fi association
/// lookups in `WifiInfoService` can only ever name a single address.
final class IpAddress {
  /// Creates one address reading.
  const new({required this.value, required this.version, this.prefixLength, this.broadcast});

  /// The address in the textual form the operating system gave us; an IPv6
  /// value may carry a scope suffix such as `%en0`.
  final String value;

  /// Which address family this is.
  final IpAddressVersion version;

  /// Network prefix length in bits, when the operating system reports one.
  final int? prefixLength;

  /// Broadcast address of the link, when the operating system reports one.
  final String? broadcast;

  @override
  String toString() => 'IpAddress(${version.name}, $value${prefixLength == null ? '' : '/$prefixLength'})';
}
