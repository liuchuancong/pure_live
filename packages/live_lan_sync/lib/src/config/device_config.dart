import 'package:live_lan_sync/src/domain/protocol/lan_sync_protocol.dart';

/// The device identity the host publishes about itself.
///
/// `deviceId` is a stable installation id the host generates and persists —
/// never an IP, MAC address or hardware serial, which change or leak. The
/// display name may change at runtime; the id must not.
final class LanSyncDeviceConfig {
  /// The identity a host publishes about itself.
  const new({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.appVersion,
    this.protocolVersion = LanSyncProtocol.current,
    this.capabilities = const <String>{},
  });

  /// The stable installation id. Randomly generated and persisted by the
  /// host; not derived from network or hardware facts.
  final String deviceId;

  /// The user-visible device name, free to change at any time.
  final String deviceName;

  /// The host platform label, e.g. `windows`, `android`, `android_tv`.
  final String platform;

  /// The host application's version string, shown to peers.
  final String appVersion;

  /// The sync protocol version this device speaks.
  final int protocolVersion;

  /// The capability tokens this device advertises to peers.
  final Set<String> capabilities;

  /// Returns the human-readable problems with this configuration, or an
  /// empty list when it is usable as is.
  List<String> validate() {
    final problems = <String>[];
    if (deviceId.isEmpty || deviceId.length > 128) {
      problems.add('device.deviceId must be 1..128 characters');
    }
    if (deviceId.trim() != deviceId || deviceId.contains(RegExp(r'\s'))) {
      problems.add('device.deviceId must not contain whitespace');
    }
    if (deviceName.trim().isEmpty) {
      problems.add('device.deviceName must not be blank');
    }
    if (deviceName.length > 128) {
      problems.add('device.deviceName must be at most 128 characters');
    }
    if (platform.trim().isEmpty) {
      problems.add('device.platform must not be blank');
    }
    if (appVersion.trim().isEmpty) {
      problems.add('device.appVersion must not be blank');
    }
    if (protocolVersion < 1) {
      problems.add('device.protocolVersion must be a positive integer');
    }
    return problems;
  }
}
