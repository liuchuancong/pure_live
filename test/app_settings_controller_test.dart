import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';

void main() {
  group('app settings migration', () {
    test('enables high refresh rate for an older backup', () {
      final config = AppSettingsController.extractConfig({'app': <String, dynamic>{}});

      expect(config['enableHighRefreshRate'], isTrue);
      expect(config['enableAsmrSleepMode'], isFalse);
      expect(config['asmrSleepMinutes'], 60);
      expect(config['realOnlinePlatforms'], AppSettingsController.defaultRealOnlinePlatforms);
    });

    test('preserves unrelated app fields when updating refresh mode', () {
      final root = <String, dynamic>{
        'app': {'showSplashPage': false},
        'player': {'engine': 'mpv'},
      };

      final merged = AppSettingsController.mergeConfig(root, {'enableHighRefreshRate': false});

      expect(merged['player'], {'engine': 'mpv'});
      expect(merged['app']['showSplashPage'], isFalse);
      expect(merged['app']['enableHighRefreshRate'], isFalse);
    });

    test('accepts long sleep timers and clamps them to one year', () {
      final custom = AppSettingsController.extractConfig({
        'app': {'asmrSleepMinutes': 10080},
      });
      final excessive = AppSettingsController.extractConfig({
        'app': {'asmrSleepMinutes': AppSettingsController.maxSleepMinutes + 1},
      });

      expect(custom['asmrSleepMinutes'], 10080);
      expect(excessive['asmrSleepMinutes'], AppSettingsController.maxSleepMinutes);
    });
  });
}
