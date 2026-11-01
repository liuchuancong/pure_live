import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:test/test.dart';

void main() {
  group('LanSyncConfig validation', () {
    test('defaults pass', () {
      const config = LanSyncConfig(
        device: LanSyncDeviceConfig(
          deviceId: 'device-a',
          deviceName: 'Desktop',
          platform: 'windows',
          appVersion: '4.0.0',
        ),
      );
      expect(config.validate(), isEmpty);
    });

    test('collects problems across areas', () {
      const config = LanSyncConfig(
        device: LanSyncDeviceConfig(deviceId: ' bad id ', deviceName: ' ', platform: 'windows', appVersion: '4.0.0'),
        discovery: LanSyncDiscoveryConfig(serviceType: 'not-mdns'),
        server: LanSyncServerConfig(port: 70000),
        security: LanSyncSecurityConfig(allowedProtocolVersions: {}),
        transfer: LanSyncTransferConfig(verifyFileHash: false),
        logging: LanSyncLoggingConfig(redactSecrets: false),
      );
      final problems = config.validate();
      expect(problems, everyElement(contains('.')));
      expect(problems.where((p) => p.startsWith('device.')), isNotEmpty);
      expect(problems.where((p) => p.startsWith('discovery.')), isNotEmpty);
      expect(problems.where((p) => p.startsWith('server.')), isNotEmpty);
      expect(problems.where((p) => p.startsWith('security.')), isNotEmpty);
      expect(problems.where((p) => p.startsWith('transfer.')), isNotEmpty);
      expect(problems.where((p) => p.startsWith('logging.')), isNotEmpty);
    });

    test('device id rejects whitespace, accepts plain ids', () {
      const bad = LanSyncDeviceConfig(
        deviceId: 'my device',
        deviceName: 'Desktop',
        platform: 'windows',
        appVersion: '1',
      );
      expect(bad.validate(), isNotEmpty);

      const good = LanSyncDeviceConfig(
        deviceId: 'my-device',
        deviceName: 'Desktop',
        platform: 'windows',
        appVersion: '1',
      );
      expect(good.validate(), isEmpty);
    });

    test('discovery service type must be a DNS-SD type', () {
      const good = LanSyncDiscoveryConfig();
      expect(good.validate(), isEmpty);

      const udp = LanSyncDiscoveryConfig(serviceType: '_purelive-sync._udp');
      expect(udp.validate(), isEmpty);
    });

    test('security refuses a long pairing code lifetime', () {
      const config = LanSyncSecurityConfig(pairingCodeTtl: Duration(minutes: 11));
      expect(config.validate(), isNotEmpty);
    });

    test('transfer refuses turning the whole-file hash off', () {
      const config = LanSyncTransferConfig(verifyFileHash: false);
      expect(config.validate(), isNotEmpty);
    });
  });
}
