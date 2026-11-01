import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:test/test.dart';

void main() {
  group('DiscoveredDeviceDirectory', () {
    test('merges updates by device id and stamps sightings', () {
      var now = DateTime.utc(2026, 11, 3, 12);
      final directory = DiscoveredDeviceDirectory(now: () => now, sweepInterval: null)
        ..update(
          const SyncDevice(
            deviceId: 'device-b',
            deviceName: 'Phone',
            platform: 'android',
            appVersion: '4.0.0',
            protocolVersion: 1,
            addresses: ['192.168.1.5'],
            port: 46000,
          ),
        );
      now = now.add(const Duration(seconds: 5));
      directory.update(
        const SyncDevice(
          deviceId: 'device-b',
          deviceName: 'Phone',
          platform: 'android',
          appVersion: '4.0.0',
          protocolVersion: 1,
          addresses: ['192.168.1.9'],
          port: 46000,
        ),
      );

      expect(directory.devices, hasLength(1));
      final merged = directory.device('device-b')!;
      expect(merged.addresses, containsAll(['192.168.1.5', '192.168.1.9']));
      expect(merged.firstSeenAt, DateTime.utc(2026, 11, 3, 12));
      expect(merged.lastSeenAt, DateTime.utc(2026, 11, 3, 12, 0, 5));
      expect(merged.connectionState, DeviceConnectionState.online);
    });

    test('emits every mutation on the broadcast stream', () async {
      final directory = DiscoveredDeviceDirectory(sweepInterval: null);
      final events = <SyncDevice>[];
      final subscription = directory.changes.listen(events.add);
      addTearDown(subscription.cancel);

      directory
        ..update(_device('device-b'))
        ..markOffline('device-b');
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(2));
      expect(events[0].connectionState, DeviceConnectionState.online);
      expect(events[1].connectionState, DeviceConnectionState.offline);
      // Offline keeps the record for a later refresh.
      expect(directory.devices, hasLength(1));
    });

    test('sweep drops stale discovered entries after the ttl', () {
      var now = DateTime.utc(2026, 11, 3, 12);
      final directory = DiscoveredDeviceDirectory(now: () => now, sweepInterval: null)..update(_device('device-b'));
      now = now.add(const Duration(minutes: 5));
      directory
        ..update(_device('device-c'))
        ..sweepStale();

      expect(directory.device('device-b'), isNull);
      expect(directory.device('device-c'), isNotNull);
    });

    test('manual entries survive the sweep until removed', () {
      var now = DateTime.utc(2026, 11, 3, 12);
      final directory = DiscoveredDeviceDirectory(now: () => now, sweepInterval: null)..addManual(_device('device-b'));
      now = now.add(const Duration(hours: 2));
      directory.sweepStale();
      expect(directory.device('device-b'), isNotNull);

      directory
        ..remove('device-b')
        ..sweepStale();
      expect(directory.device('device-b'), isNull);
      expect(directory.devices, isEmpty);
    });
  });

  group('manual address entry points', () {
    test('a manual device with a host address is immediately usable', () {
      final directory = DiscoveredDeviceDirectory(sweepInterval: null)
        ..addManual(
          const SyncDevice(
            deviceId: 'manual-1',
            deviceName: 'Living room TV',
            platform: 'android_tv',
            appVersion: '4.0.0',
            protocolVersion: 1,
            addresses: ['192.168.1.40'],
            port: 46001,
          ),
        );
      final device = directory.device('manual-1')!;
      expect(device.addresses, ['192.168.1.40']);
      expect(device.port, 46001);
      expect(device.connectionState, DeviceConnectionState.online);
    });
  });
}

SyncDevice _device(String deviceId) => SyncDevice(
  deviceId: deviceId,
  deviceName: 'Device $deviceId',
  platform: 'windows',
  appVersion: '4.0.0',
  protocolVersion: 1,
  addresses: const ['10.0.0.1'],
  port: 46000,
);
