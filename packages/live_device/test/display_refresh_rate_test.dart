import 'package:flutter_test/flutter_test.dart';
import 'package:live_device/src/display/refresh_rate/display_refresh_rate.dart';
import 'package:live_device/src/display/refresh_rate/display_refresh_rate_exception.dart';
import 'package:live_device/src/display/refresh_rate/display_refresh_rate_preference.dart';
import 'package:live_device/src/display/refresh_rate/platform_display_refresh_rate_service.dart';

DisplayRefreshRate _rate({
  required double? maxHz,
  double currentHz = 60,
  bool isLowPowerMode = false,
  int? monitorCount,
}) => DisplayRefreshRate(
  currentHz: currentHz,
  supportedHz: const <double>[24, 30, 60],
  maxHz: maxHz,
  isLowPowerMode: isLowPowerMode,
  thermalState: DisplayThermalState.nominal,
  monitorCount: monitorCount,
);

Matcher _isRefreshRateFailure(String code) =>
    isA<DisplayRefreshRateException>().having((error) => error.code, 'code', code);

void main() {
  group('DisplayRefreshRate', () {
    test('only treats a reported maximum above sixty hertz as high refresh', () {
      expect(_rate(maxHz: 120).canExceedSixtyHertz, isTrue);
      expect(_rate(maxHz: 90).canExceedSixtyHertz, isTrue);
      expect(_rate(maxHz: 60).canExceedSixtyHertz, isFalse);
      expect(_rate(maxHz: 59.94).canExceedSixtyHertz, isFalse);
      expect(_rate(maxHz: null).canExceedSixtyHertz, isFalse, reason: 'an unknown maximum is not evidence');
    });

    test('copies the reported rates into an unmodifiable snapshot', () {
      final rate = _rate(maxHz: 120, currentHz: 119.85, isLowPowerMode: true);
      expect(rate.currentHz, 119.85);
      expect(rate.supportedHz, <double>[24, 30, 60]);
      expect(rate.isLowPowerMode, isTrue);
      expect(rate.thermalState, DisplayThermalState.nominal);
      expect(rate.monitorCount, isNull, reason: 'a mobile or web read reports no monitor count');
      expect(() => rate.supportedHz.add(144), throwsUnsupportedError);
    });

    test('carries the monitor count that signals more than one display exists', () {
      expect(_rate(maxHz: 120, monitorCount: 2).monitorCount, 2);
    });
  });

  group('DisplayRefreshRatePreference', () {
    test('collapses a superseded request into failed without a fifth outcome', () {
      expect(DisplayRefreshRatePreference.values, <DisplayRefreshRatePreference>[
        DisplayRefreshRatePreference.submitted,
        DisplayRefreshRatePreference.unsupported,
        DisplayRefreshRatePreference.unavailable,
        DisplayRefreshRatePreference.failed,
      ]);
      expect(DisplayRefreshRatePreference.values.map((preference) => preference.name), isNot(contains('superseded')));
    });
  });

  group('DisplayRefreshRateException', () {
    test('prints its stable code and defaults to no details', () {
      const failure = DisplayRefreshRateException(
        code: 'unsupported_on_platform',
        message: 'No refresh-rate request path exists here.',
      );
      expect(failure.toString(), contains('unsupported_on_platform'));
      expect(failure.details, isEmpty);
      expect(failure.cause, isNull);
    });

    test('keeps structured details and the original cause for diagnostics', () {
      final failure = DisplayRefreshRateException(
        code: 'refresh_rate_operation_failed',
        message: 'The display refresh-rate operation failed.',
        details: <String, Object?>{'value': 90.0},
        cause: StateError('native failure'),
      );
      expect(failure.details, <String, Object?>{'value': 90.0});
      expect(failure.cause, isA<StateError>());
      expect(failure.toString(), isNot(contains('value')));
    });
  });

  group('PlatformDisplayRefreshRateService', () {
    const service = PlatformDisplayRefreshRateService();

    test('rejects a non-positive or non-finite content rate before calling the plugin', () {
      expect(() => service.matchContent(hz: 0), throwsA(_isRefreshRateFailure('invalid_refresh_rate')));
      expect(() => service.matchContent(hz: -120), throwsA(_isRefreshRateFailure('invalid_refresh_rate')));
      expect(() => service.matchContent(hz: double.nan), throwsA(_isRefreshRateFailure('invalid_refresh_rate')));
      expect(() => service.matchContent(hz: double.infinity), throwsA(_isRefreshRateFailure('invalid_refresh_rate')));
    });
  });
}
