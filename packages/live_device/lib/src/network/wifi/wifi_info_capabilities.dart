/// Wi-Fi lookups available on the current runtime platform.
///
/// These flags say which lookups the platform implements at all. A supported
/// lookup can still return no value, for example on an iOS simulator, on a
/// desktop with no Wi-Fi interface, or on Android before the user grants the
/// location prerequisites.
final class WifiInfoCapabilities {
  /// Creates an immutable capability description.
  const new({
    required this.canReadSsid,
    required this.canReadAddressing,
    required this.canReadBroadcastName,
    required this.requiresAndroidLocationPermission,
    required this.platformName,
  });

  /// Whether the platform can look up the network name and access-point address.
  final bool canReadSsid;

  /// Whether the platform can look up addresses, prefixes and the gateway.
  final bool canReadAddressing;

  /// Whether the platform can look up the broadcast value.
  final bool canReadBroadcastName;

  /// Whether location services and location access are prerequisites for the
  /// name lookups.
  ///
  /// This is true on Android only. iOS gates the same lookups behind its Wi-Fi
  /// information entitlement or a location grant instead.
  final bool requiresAndroidLocationPermission;

  /// Runtime platform label for diagnostics, not intended for feature branching.
  final String platformName;

  /// Whether a read is expected to produce anything the UI can show.
  bool get canOfferNetworkDetails => canReadSsid || canReadAddressing;
}
