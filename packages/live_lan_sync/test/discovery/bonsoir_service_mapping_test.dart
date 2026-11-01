import 'package:bonsoir_platform_interface/bonsoir_platform_interface.dart' show BonsoirService;
import 'package:live_lan_sync/src/infrastructure/discovery/bonsoir/bonsoir_service_mapping.dart';
import 'package:test/test.dart';

void main() {
  group('BonsoirServiceMapping.deviceFrom', () {
    test('maps a live_lan_sync service to a device', () {
      final service = BonsoirService(
        name: 'Desktop',
        type: '_purelive-sync._tcp',
        port: 46000,
        hostAddresses: ['192.168.1.5', 'fe80::1'],
        attributes: {
          ...BonsoirServiceMapping.localTxt(
            deviceId: 'device-b',
            protocolVersion: 1,
            appVersion: '4.0.0',
            platform: 'windows',
            capabilities: const {'files', 'history'},
          ),
        },
      );

      final device = BonsoirServiceMapping.deviceFrom(service)!;
      expect(device.deviceId, 'device-b');
      expect(device.deviceName, 'Desktop');
      expect(device.platform, 'windows');
      expect(device.appVersion, '4.0.0');
      expect(device.protocolVersion, 1);
      expect(device.addresses, ['192.168.1.5', 'fe80::1']);
      expect(device.port, 46000);
    });

    test('a foreign service without device id is ignored', () {
      final foreign = BonsoirService(name: 'Someone’s printer', type: '_purelive-sync._tcp', port: 631);
      expect(BonsoirServiceMapping.deviceFrom(foreign), isNull);
    });

    test('a malformed protocol version degrades to 0 without throwing', () {
      final service = BonsoirService(
        name: 'Desktop',
        type: '_purelive-sync._tcp',
        port: 46000,
        attributes: {LanSyncTxtKeys.deviceId: 'device-b', LanSyncTxtKeys.protocolVersion: 'not-a-number'},
      );
      expect(BonsoirServiceMapping.deviceFrom(service)!.protocolVersion, 0);
    });
  });

  group('BonsoirServiceMapping.localTxt', () {
    test('carries the five public facts and no secrets', () {
      final txt = BonsoirServiceMapping.localTxt(
        deviceId: 'device-a',
        protocolVersion: 1,
        appVersion: '4.0.0',
        platform: 'windows',
        capabilities: const {'files', 'history', 'favorites'},
      );
      expect(txt.keys, hasLength(5));
      expect(
        txt.keys,
        containsAll([
          LanSyncTxtKeys.deviceId,
          LanSyncTxtKeys.protocolVersion,
          LanSyncTxtKeys.appVersion,
          LanSyncTxtKeys.platform,
          LanSyncTxtKeys.capabilitiesHash,
        ]),
      );
      expect(txt[LanSyncTxtKeys.deviceId], 'device-a');
      expect(txt[LanSyncTxtKeys.protocolVersion], '1');
      expect(txt[LanSyncTxtKeys.platform], 'windows');
      expect(txt[LanSyncTxtKeys.capabilitiesHash], matches(RegExp(r'^[0-9a-f]{8}$')));
    });
  });

  group('capabilityHash', () {
    test('is order-independent and sensitive to membership', () {
      final a = BonsoirServiceMapping.capabilityHash(const {'files', 'history'});
      final b = BonsoirServiceMapping.capabilityHash(const {'history', 'files'});
      final c = BonsoirServiceMapping.capabilityHash(const {'files'});
      expect(a, b);
      expect(a, isNot(c));
    });
  });
}
