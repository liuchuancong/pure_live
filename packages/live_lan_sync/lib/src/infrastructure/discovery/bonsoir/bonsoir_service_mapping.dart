import 'package:bonsoir_platform_interface/bonsoir_platform_interface.dart' show BonsoirService;
import 'package:live_lan_sync/src/domain/device/device.dart' show SyncDevice;

/// The TXT record keys this package's services carry (spec §8.2).
///
/// Only public, non-sensitive metadata: device id, protocol version, app
/// version, platform and a capability summary hash. Tokens, pairing codes
/// and key material must never ride discovery (spec §6.3, §20).
abstract final class LanSyncTxtKeys {
  /// The stable device id — the deduplication key.
  static const deviceId = 'device_id';

  /// The sync protocol version.
  static const protocolVersion = 'protocol_version';

  /// The host application's version.
  static const appVersion = 'app_version';

  /// The platform label.
  static const platform = 'platform';

  /// A hash summarizing the capability set.
  static const capabilitiesHash = 'capabilities_hash';
}

/// The mDNS mapping layer: Bonsoir services in, domain devices out.
///
/// Everything the wire format decides lives here so the adapter stays thin
/// and both directions are testable without a network.
abstract final class BonsoirServiceMapping {
  /// The TXT record for [deviceId] and its published facts.
  static Map<String, String> localTxt({
    required String deviceId,
    required int protocolVersion,
    required String appVersion,
    required String platform,
    required Set<String> capabilities,
  }) => <String, String>{
    LanSyncTxtKeys.deviceId: deviceId,
    LanSyncTxtKeys.protocolVersion: '$protocolVersion',
    LanSyncTxtKeys.appVersion: appVersion,
    LanSyncTxtKeys.platform: platform,
    LanSyncTxtKeys.capabilitiesHash: capabilityHash(capabilities),
  };

  /// Maps a resolved Bonsoir service to a device, or returns null when the
  /// service is not a live_lan_sync peer: foreign services on the same
  /// mDNS type carry no `device_id` TXT and must not pollute the list.
  ///
  /// The mapped device always starts at the unknown trust state:
  /// discovery never decides trust. The pairing layer overrides the state
  /// through the directory when the id is already paired or revoked.
  static SyncDevice? deviceFrom(BonsoirService service) {
    final attributes = service.attributes;
    final deviceId = attributes[LanSyncTxtKeys.deviceId];
    if (deviceId == null || deviceId.isEmpty) return null;
    final addresses = service.hostAddresses.where((a) => a.isNotEmpty).toList();
    return SyncDevice(
      deviceId: deviceId,
      deviceName: service.name,
      platform: attributes[LanSyncTxtKeys.platform] ?? '',
      appVersion: attributes[LanSyncTxtKeys.appVersion] ?? '',
      protocolVersion: int.tryParse(attributes[LanSyncTxtKeys.protocolVersion] ?? '') ?? 0,
      addresses: addresses,
      port: service.port,
    );
  }

  /// A stable hash over the capability set, order-independent.
  ///
  /// A 32-bit FNV-1a over the sorted, joined tokens: short enough for a
  /// TXT record, stable across runs, never used as a security primitive.
  static String capabilityHash(Set<String> capabilities) {
    var hash = 0x811c9dc5;
    for (final unit in (capabilities.toList()..sort()).join(',').codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
