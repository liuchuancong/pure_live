import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:live_device/src/system/device_identity/device_identity.dart';
import 'package:live_device/src/system/device_identity/device_identity_exception.dart';
import 'package:live_device/src/system/device_identity/device_identity_memory.dart';
import 'package:live_device/src/system/device_identity/platform_device_identity_service.dart';

const int _megabyte = 1024 * 1024;
const int _gibibyte = 1024 * _megabyte;

Matcher _isIdentityFailure(String code) => isA<DeviceIdentityException>().having((error) => error.code, 'code', code);

void main() {
  group('memory normalization', () {
    test('passes megabyte platforms through and drops their unknown sentinels', () {
      expect(positiveMegabytes(8192), 8192);
      expect(positiveMegabytes(0), isNull, reason: 'zero is how a platform reports no reading');
      expect(positiveMegabytes(-1), isNull, reason: '-1 is the plugin unknown sentinel');
      expect(positiveMegabytes(null), isNull);
    });

    test('converts a byte count to whole megabytes', () {
      expect(megabytesFromBytes(16 * _gibibyte), 16 * 1024);
      expect(megabytesFromBytes(_megabyte), 1);
      expect(megabytesFromBytes(_megabyte + 1), 2, reason: 'any reported memory rounds up');
      expect(megabytesFromBytes(1), 1);
      expect(megabytesFromBytes(-1), isNull);
      expect(megabytesFromBytes(null), isNull);
    });

    test('converts the browser gibibyte estimate to megabytes', () {
      expect(megabytesFromGibibytes(8), 8192);
      expect(megabytesFromGibibytes(0.5), 512);
      expect(megabytesFromGibibytes(0), isNull);
      expect(megabytesFromGibibytes(null), isNull);
      expect(megabytesFromGibibytes(double.nan), isNull);
      expect(megabytesFromGibibytes(double.infinity), isNull);
    });
  });

  group('DeviceIdentity', () {
    test('leaves every platform field unset by default', () {
      const identity = DeviceIdentity(platformName: 'test');
      expect(identity.platformName, 'test');
      expect(identity.model, isNull);
      expect(identity.manufacturer, isNull);
      expect(identity.marketingName, isNull);
      expect(identity.hostname, isNull);
      expect(identity.systemName, isNull);
      expect(identity.systemVersion, isNull);
      expect(identity.majorVersion, isNull);
      expect(identity.minorVersion, isNull);
      expect(identity.processorCount, isNull);
      expect(identity.memoryMegabytes, isNull);
      expect(identity.isPhysicalDevice, isNull);
    });
  });

  group('DeviceIdentityException', () {
    test('prints its stable code and defaults to no details', () {
      const failure = DeviceIdentityException(
        code: 'unsupported_on_platform',
        message: 'The runtime does not expose device identity information.',
      );
      expect(failure.toString(), contains('unsupported_on_platform'));
      expect(failure.details, isEmpty);
      expect(failure.cause, isNull);
    });
  });

  group('PlatformDeviceIdentityService', () {
    const service = PlatformDeviceIdentityService();

    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('reports phones as physical devices with memory but no core count', () async {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        debugDefaultTargetPlatformOverride = platform;
        final capabilities = await service.getCapabilities();
        expect(capabilities.canReadIdentity, isTrue, reason: 'unexpected support on ${platform.name}');
        expect(capabilities.reportsPhysicalDevice, isTrue, reason: 'emulator support on ${platform.name}');
        expect(capabilities.reportsMemory, isTrue, reason: 'memory support on ${platform.name}');
        expect(capabilities.reportsProcessorCount, isFalse, reason: 'no core count on ${platform.name}');
        expect(capabilities.platformName, platform.name);
      }
    });

    test('reports desktop platforms as machines with cores and memory', () async {
      for (final platform in [TargetPlatform.macOS, TargetPlatform.windows]) {
        debugDefaultTargetPlatformOverride = platform;
        final capabilities = await service.getCapabilities();
        expect(capabilities.canReadIdentity, isTrue, reason: 'unexpected support on ${platform.name}');
        expect(capabilities.reportsPhysicalDevice, isFalse, reason: 'no emulator flag on ${platform.name}');
        expect(capabilities.reportsMemory, isTrue, reason: 'memory support on ${platform.name}');
        expect(capabilities.reportsProcessorCount, isTrue, reason: 'core count on ${platform.name}');
        expect(capabilities.platformName, platform.name);
      }
    });

    test('reports Linux as OS release information only', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final capabilities = await service.getCapabilities();
      expect(capabilities.canReadIdentity, isTrue);
      expect(capabilities.reportsPhysicalDevice, isFalse);
      expect(capabilities.reportsMemory, isFalse);
      expect(capabilities.reportsProcessorCount, isFalse);
      expect(capabilities.platformName, 'linux');
    });

    test('refuses identity reads on fuchsia without touching a channel', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
      expect((await service.getCapabilities()).canReadIdentity, isFalse);
      await expectLater(service.read(), throwsA(_isIdentityFailure('unsupported_on_platform')));
    });
  });
}
