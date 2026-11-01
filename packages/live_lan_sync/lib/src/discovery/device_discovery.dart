import 'package:live_lan_sync/src/domain/device/device.dart' show SyncDevice;

/// Finds peers on the LAN and announces this device to them.
///
/// Bonsoir (mDNS / DNS-SD) implements this behind `src/`; application code
/// depends on this interface and never on Bonsoir's types (spec §8.1).
/// Discovery feeds the device list only — it never grants trust and never
/// opens sessions.
abstract interface class DeviceDiscovery {
  /// Starts browsing for peers. Safe to call again while running.
  Future<void> start();

  /// Stops browsing. Registered local services stay announced.
  Future<void> stop();

  /// Announces this device under the configured service type. [txt] carries
  /// public, non-sensitive metadata only — device id, protocol and app
  /// version, capability summary — never tokens, pairing codes or key
  /// material (spec §6.3, §20). An empty [txt] makes the implementation
  /// derive the standard facts from its own device configuration.
  Future<void> registerLocalService({
    required String deviceId,
    required int port,
    Map<String, String> txt = const <String, String>{},
  });

  /// Withdraws this device's announcement, e.g. when the server stops.
  Future<void> unregisterLocalService();

  /// Whether browsing is currently running.
  bool get isRunning;

  /// Devices as they are discovered, updated (address or metadata changes)
  /// and lost. The stream deduplicates by [SyncDevice.deviceId]; one device
  /// with several NICs produces updates, not duplicates.
  Stream<SyncDevice> get discoveredDevices;

  /// Failures discovery hits (network lost, OS permission refused). These
  /// are diagnostic events; discovery failing does not throw to callers of
  /// [start].
  Stream<Object> get discoveryErrors;

  /// Releases every underlying resource. After this, the instance is dead.
  Future<void> dispose();
}
