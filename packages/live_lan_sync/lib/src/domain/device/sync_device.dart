import 'package:meta/meta.dart';

/// A device this one has seen on the network, or has paired with.
///
/// Discovery never equals trust: a freshly discovered device reports
/// [DeviceTrustState.unknown] until the pairing ceremony promotes it. The
/// identity for deduplication and persistence is [deviceId] — never an
/// address, which changes with DHCP and networks (spec §8.4).
@immutable
final class SyncDevice {
  /// A device seen on the network or registered as trusted.
  const new({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.appVersion,
    required this.protocolVersion,
    this.addresses = const <String>[],
    this.port,
    this.capabilities = const <String>{},
    this.trustState = DeviceTrustState.unknown,
    this.connectionState = DeviceConnectionState.unknown,
    this.firstSeenAt,
    this.lastSeenAt,
  });

  /// The device's stable installation id. The deduplication key: the same
  /// id always merges into one record regardless of how many addresses it
  /// advertises.
  final String deviceId;

  /// The peer's user-visible name.
  final String deviceName;

  /// The peer's platform label.
  final String platform;

  /// The peer's application version.
  final String appVersion;

  /// The sync protocol version the peer speaks.
  final int protocolVersion;

  /// Every address the device has been seen on, most recently reachable
  /// first. One device may legitimately have several (multiple NICs,
  /// IPv4 and IPv6).
  final List<String> addresses;

  /// The port the peer's sync server listens on, when known.
  final int? port;

  /// The capability tokens the peer advertises.
  final Set<String> capabilities;

  /// Where this device stands in the trust relationship.
  final DeviceTrustState trustState;

  /// The live connection hint, as of [lastSeenAt].
  final DeviceConnectionState connectionState;

  /// When this device was first seen.
  final DateTime? firstSeenAt;

  /// When this device was last seen or heard from.
  final DateTime? lastSeenAt;

  /// A copy of this device with the fields of [other] where this one has
  /// none: discovery updates arrive as patches over the record already held.
  SyncDevice mergedWith(SyncDevice other) => SyncDevice(
    deviceId: deviceId,
    deviceName: other.deviceName.isNotEmpty ? other.deviceName : deviceName,
    platform: other.platform.isNotEmpty ? other.platform : platform,
    appVersion: other.appVersion.isNotEmpty ? other.appVersion : appVersion,
    protocolVersion: other.protocolVersion != 0 ? other.protocolVersion : protocolVersion,
    addresses: <String>{...addresses, ...other.addresses}.toList(),
    port: other.port ?? port,
    capabilities: <String>{...capabilities, ...other.capabilities},
    trustState: other.trustState != DeviceTrustState.unknown ? other.trustState : trustState,
    connectionState: other.connectionState,
    firstSeenAt: firstSeenAt ?? other.firstSeenAt,
    lastSeenAt: other.lastSeenAt ?? lastSeenAt,
  );

  @override
  bool operator ==(Object other) => other is SyncDevice && other.deviceId == deviceId;

  @override
  int get hashCode => deviceId.hashCode;

  @override
  String toString() => 'SyncDevice($deviceId, $deviceName, $platform)';
}

/// Where a device stands in the trust relationship.
enum DeviceTrustState {
  /// Seen but never paired: no data may flow.
  unknown,

  /// Paired and trusted.
  paired,

  /// Paired once, revoked since: old credentials must stop working.
  revoked,
}

/// The live connection hint for a device.
enum DeviceConnectionState {
  /// Nothing known yet.
  unknown,

  /// Addressed but not answering.
  offline,

  /// A session is being established.
  connecting,

  /// A session is established.
  online,
}
