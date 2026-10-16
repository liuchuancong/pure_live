import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:live_device/src/network/wifi/platform_wifi_info_service.dart';
import 'package:live_device/src/network/wifi/wifi_info_capabilities.dart';
import 'package:live_device/src/network/wifi/wifi_info_exception.dart';
import 'package:live_device/src/network/wifi/wifi_info_service.dart';
import 'package:live_device/src/network/wifi/wifi_network_info.dart';

WifiInfoCapabilities _capabilities({
  bool canReadSsid = true,
  bool canReadAddressing = true,
  bool canReadBroadcastName = true,
  bool requiresAndroidLocationPermission = false,
}) => WifiInfoCapabilities(
  canReadSsid: canReadSsid,
  canReadAddressing: canReadAddressing,
  canReadBroadcastName: canReadBroadcastName,
  requiresAndroidLocationPermission: requiresAndroidLocationPermission,
  platformName: 'test',
);

Matcher _isWifiFailure(String code) => isA<WifiInfoException>().having((error) => error.code, 'code', code);

void main() {
  group('WifiNetworkInfo', () {
    test('knows nothing when no value was reported', () {
      const info = WifiNetworkInfo();

      expect(info.ssid, isNull);
      expect(info.bssid, isNull);
      expect(info.ipv4Address, isNull);
      expect(info.ipv6Address, isNull);
      expect(info.subnetMask, isNull);
      expect(info.gatewayAddress, isNull);
      expect(info.broadcastName, isNull);
      expect(info.hasNetworkIdentity, isFalse);
    });

    test('keeps every reported value as given', () {
      const info = WifiNetworkInfo(
        ssid: '"PureLive Studio"',
        bssid: '11:22:33:44:55:66',
        ipv4Address: '192.168.1.43',
        ipv6Address: '2001:db8::1',
        subnetMask: '255.255.255.0',
        gatewayAddress: '192.168.1.1',
        broadcastName: '192.168.1.255',
      );

      expect(info.ssid, '"PureLive Studio"');
      expect(info.bssid, '11:22:33:44:55:66');
      expect(info.ipv4Address, '192.168.1.43');
      expect(info.ipv6Address, '2001:db8::1');
      expect(info.subnetMask, '255.255.255.0');
      expect(info.gatewayAddress, '192.168.1.1');
      expect(info.broadcastName, '192.168.1.255');
      expect(info.hasNetworkIdentity, isTrue);
    });

    test('names a network only when the identity lookups answered', () {
      expect(const WifiNetworkInfo(ssid: 'Studio').hasNetworkIdentity, isTrue);
      expect(const WifiNetworkInfo(bssid: '11:22:33:44:55:66').hasNetworkIdentity, isTrue);
      expect(
        const WifiNetworkInfo(ipv4Address: '192.168.1.43').hasNetworkIdentity,
        isFalse,
        reason: 'an address says where the device is, not which network it joined',
      );
    });
  });

  group('WifiInfoCapabilities', () {
    test('offers network details once a name or an address can be read', () {
      expect(_capabilities().canOfferNetworkDetails, isTrue);
      expect(_capabilities(canReadSsid: false).canOfferNetworkDetails, isTrue);
      expect(_capabilities(canReadAddressing: false).canOfferNetworkDetails, isTrue);
      expect(_capabilities(canReadSsid: false, canReadAddressing: false).canOfferNetworkDetails, isFalse);
    });

    test('keeps the broadcast lookup and the location prerequisite separate', () {
      final capabilities = _capabilities(canReadSsid: false, requiresAndroidLocationPermission: true);

      expect(capabilities.canReadSsid, isFalse);
      expect(capabilities.canReadBroadcastName, isTrue);
      expect(capabilities.requiresAndroidLocationPermission, isTrue);
      expect(capabilities.platformName, 'test');
    });
  });

  group('WifiInfoException', () {
    test('prints its stable code and defaults to no details', () {
      const failure = WifiInfoException(
        code: 'unsupported_on_platform',
        message: 'The Wi-Fi information API is not available on this platform.',
      );

      expect(failure, _isWifiFailure('unsupported_on_platform'));
      expect(failure.toString(), contains('unsupported_on_platform'));
      expect(failure.details, isEmpty);
      expect(failure.cause, isNull);
    });

    test('keeps the failing field and the original cause for diagnostics', () {
      final failure = WifiInfoException(
        code: 'wifi_info_read_failed',
        message: 'Reading the Wi-Fi "ssid" value failed.',
        details: <String, Object?>{'field': 'ssid', 'errorType': 'StateError'},
        cause: StateError('native failure'),
      );

      expect(failure, _isWifiFailure('wifi_info_read_failed'));
      expect(failure.details, <String, Object?>{'field': 'ssid', 'errorType': 'StateError'});
      expect(failure.cause, isA<StateError>());
      expect(failure.toString(), isNot(contains('field')));
    });
  });

  group('PlatformWifiInfoService', () {
    const service = PlatformWifiInfoService();

    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('implements the Wi-Fi information contract', () {
      expect(service, isA<WifiInfoService>());
    });

    test('declares every lookup on platforms that have a Wi-Fi stack', () async {
      for (final platform in <TargetPlatform>[
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        final capabilities = await service.getCapabilities();

        expect(capabilities.canReadSsid, isTrue, reason: 'unexpected name support on ${platform.name}');
        expect(capabilities.canReadAddressing, isTrue, reason: 'unexpected address support on ${platform.name}');
        expect(capabilities.canReadBroadcastName, isTrue, reason: 'unexpected broadcast on ${platform.name}');
        expect(capabilities.canOfferNetworkDetails, isTrue, reason: 'unexpected support on ${platform.name}');
        expect(capabilities.platformName, platform.name);
      }
    });

    test('marks Android as the platform that needs location for names', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect((await service.getCapabilities()).requiresAndroidLocationPermission, isTrue);

      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect((await service.getCapabilities()).requiresAndroidLocationPermission, isFalse);
    });

    test('gives up on fuchsia, where no network-info backend is registered', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
      final capabilities = await service.getCapabilities();

      expect(capabilities.canReadSsid, isFalse);
      expect(capabilities.canReadAddressing, isFalse);
      expect(capabilities.canReadBroadcastName, isFalse);
      expect(capabilities.canOfferNetworkDetails, isFalse);
      expect(capabilities.requiresAndroidLocationPermission, isFalse);
      expect(capabilities.platformName, TargetPlatform.fuchsia.name);
    });
  });
}
