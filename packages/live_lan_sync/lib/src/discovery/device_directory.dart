import 'dart:async' show StreamController, Timer;

import 'package:live_lan_sync/src/domain/device/device.dart' show DeviceConnectionState, SyncDevice;

/// The deduplicated device list discovery feeds and the UI reads.
///
/// The directory owns three duties the spec pins on discovery: merging by
/// device id, expiring stale entries after the configured TTL, and keeping
/// manual entries alive. Every mutation is emitted on [changes] as the
/// updated (or removed, connection-state-offline) record; the stream is
/// broadcast, so any number of listeners may watch it.
final class DiscoveredDeviceDirectory {
  /// A directory with the given [ttl] for discovered entries.
  ///
  /// [now] and [sweepInterval] are injectable for tests; when
  /// [sweepInterval] is null no automatic timer runs and the host (or a
  /// test) drives [sweepStale] itself.
  new({
    this.ttl = const Duration(seconds: 120),
    DateTime Function()? now,
    this.sweepInterval = const Duration(seconds: 30),
  }) : _now = now ?? DateTime.now {
    if (sweepInterval != null) {
      _sweepTimer = Timer.periodic(sweepInterval!, (_) => sweepStale());
    }
  }

  /// How long a discovered entry survives without a refresh.
  final Duration ttl;

  /// How often the TTL sweep runs; null disables the automatic timer.
  final Duration? sweepInterval;

  final DateTime Function() _now;
  final Map<String, SyncDevice> _devices = <String, SyncDevice>{};
  final Set<String> _manualIds = <String>{};
  Timer? _sweepTimer;
  final StreamController<SyncDevice> _changes = StreamController<SyncDevice>.broadcast();

  /// Every mutation, as the new record; a removed or expired device is
  /// emitted once with [DeviceConnectionState.offline].
  Stream<SyncDevice> get changes => _changes.stream;

  /// The current snapshot, manual entries included.
  List<SyncDevice> get devices => List.unmodifiable(_devices.values);

  /// The record for [deviceId], or null.
  SyncDevice? device(String deviceId) => _devices[deviceId];

  /// Merges [device] into the record for its id and emits the result.
  ///
  /// A first sighting stamps [SyncDevice.firstSeenAt]; every sighting
  /// refreshes [SyncDevice.lastSeenAt], which the TTL sweep reads.
  void update(SyncDevice device) {
    final existing = _devices[device.deviceId];
    final stamped = SyncDevice(
      deviceId: device.deviceId,
      deviceName: device.deviceName,
      platform: device.platform,
      appVersion: device.appVersion,
      protocolVersion: device.protocolVersion,
      addresses: device.addresses,
      port: device.port,
      capabilities: device.capabilities,
      trustState: device.trustState,
      connectionState: device.connectionState == DeviceConnectionState.unknown
          ? DeviceConnectionState.online
          : device.connectionState,
      firstSeenAt: existing?.firstSeenAt ?? device.firstSeenAt ?? _now(),
      lastSeenAt: _now(),
    );
    final merged = existing == null ? stamped : existing.mergedWith(stamped);
    _devices[merged.deviceId] = merged;
    _changes.add(merged);
  }

  /// Adds or refreshes a manually entered device. Manual entries are exempt
  /// from the TTL sweep and stay until [remove].
  void addManual(SyncDevice device) {
    _manualIds.add(device.deviceId);
    update(device);
  }

  /// Emits [deviceId] as offline (address no longer answering, mDNS
  /// service lost) without dropping the record.
  void markOffline(String deviceId) {
    final existing = _devices[deviceId];
    if (existing == null || existing.connectionState == DeviceConnectionState.offline) {
      return;
    }
    final offline = SyncDevice(
      deviceId: existing.deviceId,
      deviceName: existing.deviceName,
      platform: existing.platform,
      appVersion: existing.appVersion,
      protocolVersion: existing.protocolVersion,
      addresses: existing.addresses,
      port: existing.port,
      capabilities: existing.capabilities,
      trustState: existing.trustState,
      connectionState: DeviceConnectionState.offline,
      firstSeenAt: existing.firstSeenAt,
      lastSeenAt: existing.lastSeenAt,
    );
    _devices[deviceId] = offline;
    _changes.add(offline);
  }

  /// Removes the record for [deviceId] entirely and emits it offline once.
  void remove(String deviceId) {
    if (_devices.remove(deviceId) == null) return;
    _manualIds.remove(deviceId);
    markOffline(deviceId);
  }

  /// Drops discovered entries not refreshed within [ttl]. Manual entries
  /// never expire.
  void sweepStale() {
    final cutoff = _now().subtract(ttl);
    for (final device in List.of(_devices.values)) {
      if (_manualIds.contains(device.deviceId)) continue;
      final lastSeen = device.lastSeenAt;
      if (lastSeen == null || lastSeen.isBefore(cutoff)) {
        remove(device.deviceId);
      }
    }
  }

  /// Releases the sweep timer and closes the change stream.
  Future<void> dispose() async {
    _sweepTimer?.cancel();
    _sweepTimer = null;
    await _changes.close();
  }
}
