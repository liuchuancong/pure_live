import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:live_device/live_device.dart';

void main() {
  group('NetworkAdapter', () {
    test('splits its addresses by family and keeps the list unmodifiable', () {
      final adapter = NetworkAdapter(
        name: 'en0',
        index: 7,
        addresses: const <IpAddress>[
          IpAddress(value: '192.168.1.23', version: IpAddressVersion.ipv4, prefixLength: 24),
          IpAddress(value: '10.8.0.6', version: IpAddressVersion.ipv4),
          IpAddress(value: 'fe80::1%en0', version: IpAddressVersion.ipv6, prefixLength: 64),
        ],
      );

      // A host holding a LAN and a VPN address is the normal case, so neither
      // reading may hide the other.
      expect(adapter.ipv4Addresses.map((address) => address.value), <String>['192.168.1.23', '10.8.0.6']);
      expect(adapter.ipv6Addresses.single.value, 'fe80::1%en0');
      expect(adapter.ipv4Addresses.length + adapter.ipv6Addresses.length, adapter.addresses.length);
      expect(adapter.addresses.clear, throwsUnsupportedError);
    });

    test('prints the family and the prefix it was given', () {
      expect(
        const IpAddress(value: '10.0.0.1', version: IpAddressVersion.ipv4, prefixLength: 8).toString(),
        'IpAddress(ipv4, 10.0.0.1/8)',
      );
      expect(const IpAddress(value: '::1', version: IpAddressVersion.ipv6).toString(), 'IpAddress(ipv6, ::1)');
    });
  });

  group('NetworkAdapterException', () {
    test('prints its stable code and defaults to no details', () {
      const failure = NetworkAdapterException(code: 'unsupported_on_platform', message: 'No adapter API here.');
      expect(failure.toString(), contains('unsupported_on_platform'));
      expect(failure.details, isEmpty);
      expect(failure.cause, isNull);
    });
  });

  group('PlatformNetworkAdapterService', () {
    const service = PlatformNetworkAdapterService();

    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('reads the host table without inventing addresses', () async {
      final adapters = await service.read();

      for (final adapter in adapters) {
        expect(adapter.name, isNotEmpty);
        expect(adapter.ipv4Addresses.length + adapter.ipv6Addresses.length, adapter.addresses.length);
        for (final address in adapter.addresses) {
          expect(address.value, isNotEmpty);
        }
      }
    });

    test('leaves loopback out until it is asked for', () async {
      final filtered = await service.read();
      final including = await service.read(includeLoopback: true);

      expect(including.length, greaterThanOrEqualTo(filtered.length));
      expect(
        filtered.expand((adapter) => adapter.addresses).map((address) => address.value),
        isNot(contains('127.0.0.1')),
      );
    });

    test('declares enumeration everywhere the interface table exists', () async {
      for (final platform in <TargetPlatform>[
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        final capabilities = await service.getCapabilities();
        expect(capabilities.canEnumerateAdapters, isTrue, reason: 'no enumeration on ${platform.name}');
        expect(capabilities.platformName, platform.name);
      }

      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
      expect((await service.getCapabilities()).canEnumerateAdapters, isFalse);
    });
  });
}
