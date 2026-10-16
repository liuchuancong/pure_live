import 'package:flutter_test/flutter_test.dart';
import 'package:live_device/live_device.dart';

ScreenBrightnessCapabilities _capabilities({
  ScreenBrightnessWriteSupport writeSupport = ScreenBrightnessWriteSupport.supported,
  Set<ScreenBrightnessScope> supportedScopes = const {ScreenBrightnessScope.application},
}) => ScreenBrightnessCapabilities(
  canRead: true,
  canWrite: true,
  canObserve: false,
  writeSupport: writeSupport,
  supportedScopes: supportedScopes,
  targetsPrimaryDisplay: false,
  requiresSystemPermission: true,
  backend: 'test-backend',
);

Matcher _isBrightnessFailure(String code) =>
    isA<ScreenBrightnessException>().having((error) => error.code, 'code', code);

void main() {
  group('ScreenBrightnessCapabilities', () {
    test('copies the reported scopes and stays unmodifiable', () {
      final capabilities = _capabilities();
      expect(capabilities.supportsScope(ScreenBrightnessScope.application), isTrue);
      expect(capabilities.supportsScope(ScreenBrightnessScope.system), isFalse);
      expect(() => capabilities.supportedScopes.add(ScreenBrightnessScope.system), throwsUnsupportedError);
    });

    test('offers a write unless the backend has no writable path', () {
      expect(_capabilities().canOfferBrightnessControl, isTrue);
      expect(
        _capabilities(writeSupport: ScreenBrightnessWriteSupport.bestEffort).canOfferBrightnessControl,
        isTrue,
        reason: 'best effort may still fail at runtime, but the UI should offer it',
      );
      expect(_capabilities(writeSupport: ScreenBrightnessWriteSupport.unsupported).canOfferBrightnessControl, isFalse);
      expect(
        ScreenBrightnessCapabilities(
          canRead: true,
          canWrite: false,
          canObserve: false,
          writeSupport: ScreenBrightnessWriteSupport.supported,
          supportedScopes: const <ScreenBrightnessScope>{},
          targetsPrimaryDisplay: true,
          requiresSystemPermission: false,
          backend: 'read-only',
        ).canOfferBrightnessControl,
        isFalse,
      );
    });
  });

  group('PlatformScreenBrightnessService', () {
    const service = PlatformScreenBrightnessService();

    test('rejects percentages outside 0-100 before calling the plugin', () {
      expect(() => service.setBrightness(-5), throwsA(_isBrightnessFailure('invalid_brightness_value')));
      expect(() => service.setBrightness(101), throwsA(_isBrightnessFailure('invalid_brightness_value')));
    });

    test('never needs the system write permission for the app window scope', () async {
      expect(await service.hasPermission(scope: ScreenBrightnessScope.application), isTrue);
      expect(await service.requestPermission(scope: ScreenBrightnessScope.application), isTrue);
    });
  });
}
