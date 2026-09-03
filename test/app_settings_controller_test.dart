import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/app_refresh_rate_mode.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';

void main() {
  group('app settings migration', () {
    test('uses power saving for a backup without a refresh preference', () {
      final config = AppSettingsController.extractConfig({'app': <String, dynamic>{}});

      expect(config['refreshRateMode'], AppRefreshRateMode.powerSaving.storageValue);
      expect(config['enableHighRefreshRate'], isFalse);
      expect(config['enableAsmrSleepMode'], isFalse);
      expect(config['asmrSleepMinutes'], 60);
      expect(config['realOnlinePlatforms'], AppSettingsController.defaultRealOnlinePlatforms);
      expect(config['useGitHubOriginForUpdates'], isFalse);
      expect(config['enableMultiView'], isTrue);
      expect(config['enableNewWindowPlay'], isTrue);
    });

    test('preserves explicit disabled desktop entry points', () {
      final config = AppSettingsController.extractConfig({
        'app': {'enableMultiView': false, 'enableNewWindowPlay': false},
      });

      expect(config['enableMultiView'], isFalse);
      expect(config['enableNewWindowPlay'], isFalse);
    });

    test('migrates the legacy high refresh switch to balanced', () {
      final config = AppSettingsController.extractConfig({
        'app': {'enableHighRefreshRate': true},
      });

      expect(config['refreshRateMode'], AppRefreshRateMode.balanced.storageValue);
      expect(config['enableHighRefreshRate'], isTrue);
    });

    test('prefers an explicit refresh-rate mode over the legacy switch', () {
      final config = AppSettingsController.extractConfig({
        'app': {
          'refreshRateMode': AppRefreshRateMode.performance.storageValue,
          'enableHighRefreshRate': false,
        },
      });

      expect(config['refreshRateMode'], AppRefreshRateMode.performance.storageValue);
      expect(config['enableHighRefreshRate'], isTrue);
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

    test('removes platforms whose public values are heat only', () {
      final config = AppSettingsController.extractConfig({
        'app': {
          'realOnlinePlatforms': ['huya', 'douyin', 'kuaishou', 'cc'],
        },
      });

      expect(config['realOnlinePlatforms'], ['douyin', 'kuaishou', 'cc']);
    });

    test('normalizes concurrent platform ids and includes SOOP for new installs', () {
      expect(AppSettingsController.defaultRealOnlinePlatforms, contains('soop'));
      expect(
        AppSettingsController.normalizeRealOnlinePlatforms(['DOUYIN', ' soop ', 'YY', 'SOOP']),
        ['douyin', 'soop'],
      );
    });
  });
}
