import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:live_device/src/power/battery/battery_exception.dart';
import 'package:live_device/src/power/battery/battery_status.dart';
import 'package:live_device/src/power/battery/platform_battery_service.dart';

void main() {
  group('BatteryStatus', () {
    test('covers every charging state a platform can report, including unknown', () {
      expect(BatteryStatus.values, <BatteryStatus>[
        BatteryStatus.full,
        BatteryStatus.charging,
        BatteryStatus.connectedNotCharging,
        BatteryStatus.discharging,
        BatteryStatus.unknown,
      ]);
    });
  });

  group('BatteryException', () {
    test('prints its stable code and defaults to no details', () {
      const failure = BatteryException(code: 'unsupported_on_platform', message: 'No battery API exists here.');
      expect(failure.toString(), contains('unsupported_on_platform'));
      expect(failure.details, isEmpty);
      expect(failure.cause, isNull);
    });
  });

  group('PlatformBatteryService', () {
    const service = PlatformBatteryService();

    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('declares battery-saver status only where the plugin implements it', () async {
      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        final capabilities = await service.getCapabilities();
        final hasSaverApi = platform != TargetPlatform.linux;
        final foldsPowerSources =
            platform == TargetPlatform.linux || platform == TargetPlatform.macOS || platform == TargetPlatform.windows;
        expect(capabilities.canReadLevel, isTrue, reason: 'unexpected support on ${platform.name}');
        expect(capabilities.canReadStatus, isTrue, reason: 'unexpected support on ${platform.name}');
        expect(capabilities.canObserve, isTrue, reason: 'unexpected support on ${platform.name}');
        expect(capabilities.canReadPowerSaveMode, hasSaverApi, reason: 'battery saver is not read on ${platform.name}');
        expect(
          capabilities.aggregatesPowerSources,
          foldsPowerSources,
          reason: 'only desktops collapse several power sources into one reading',
        );
        expect(capabilities.platformName, platform.name);
      }

      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
      final capabilities = await service.getCapabilities();
      expect(capabilities.canReadLevel, isFalse);
      expect(capabilities.canReadStatus, isFalse);
      expect(capabilities.canObserve, isFalse);
      expect(capabilities.canReadPowerSaveMode, isFalse);
      expect(capabilities.aggregatesPowerSources, isFalse, reason: 'a platform with no backend folds nothing');
    });
  });
}
