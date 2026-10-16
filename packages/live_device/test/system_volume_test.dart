import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:live_device/live_device.dart';

SystemVolumeCapabilities _capabilities({bool canRead = true, bool canWrite = true}) => SystemVolumeCapabilities(
  canRead: canRead,
  canWrite: canWrite,
  canObserve: true,
  canMute: true,
  canControlSystemUi: false,
  platformName: 'test',
);

Matcher _isVolumeFailure(String code) => isA<SystemVolumeException>().having((error) => error.code, 'code', code);

void main() {
  group('SystemVolumeCapabilities', () {
    test('offers volume control only when reading and writing both work', () {
      expect(_capabilities().canOfferVolumeControl, isTrue);
      expect(_capabilities(canRead: false).canOfferVolumeControl, isFalse);
      expect(_capabilities(canWrite: false).canOfferVolumeControl, isFalse);
    });
  });

  group('SystemVolumeException', () {
    test('prints its stable code and defaults to no details', () {
      const failure = SystemVolumeException(code: 'no_mixer', message: 'No audio endpoint is available.');
      expect(failure.toString(), contains('no_mixer'));
      expect(failure.details, isEmpty);
      expect(failure.cause, isNull);
    });
  });

  group('PlatformSystemVolumeService', () {
    const service = PlatformSystemVolumeService();

    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('rejects percentages outside 0-100 before calling the plugin', () {
      expect(() => service.setVolume(-1), throwsA(_isVolumeFailure('invalid_volume_value')));
      expect(() => service.setVolume(101), throwsA(_isVolumeFailure('invalid_volume_value')));
    });

    test('declares support for phone and desktop platforms but not fuchsia', () async {
      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        final capabilities = await service.getCapabilities();
        final isPhone = platform == TargetPlatform.android || platform == TargetPlatform.iOS;
        expect(capabilities.canRead, isTrue, reason: 'unexpected support on ${platform.name}');
        expect(capabilities.canOfferVolumeControl, isTrue, reason: 'unexpected support on ${platform.name}');
        expect(capabilities.canControlSystemUi, isPhone, reason: 'the overlay is a phone-only option');
        expect(capabilities.platformName, platform.name);
      }

      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
      expect((await service.getCapabilities()).canOfferVolumeControl, isFalse);
    });

    test('reports the phone-only overlay options separately per platform', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect((await service.getCapabilities()).canControlSystemUi, isFalse);
      expect(service.setSystemUiVisible(visible: false), isFalse);
    });
  });
}
