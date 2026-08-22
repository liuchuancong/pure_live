import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/services/settings/player_settings_controller.dart';

void main() {
  group('player settings migration', () {
    test('uses IJK only for a new iOS configuration', () {
      expect(defaultVideoPlayerKeyForPlatform(TargetPlatform.iOS), 'ijk');
      expect(defaultVideoPlayerKeyForPlatform(TargetPlatform.android), 'mpv');
      expect(defaultVideoPlayerKeyForPlatform(TargetPlatform.windows), 'mpv');
    });

    test('retires the legacy global audio-only default', () {
      final config = PlayerSettingsController.extractConfig({
        'player': <String, dynamic>{'audioOnly': true, 'floatPlay': true},
      });

      expect(config['audioOnly'], isFalse);
      expect(config['floatPlay'], isTrue);
    });

    test('keeps audio-only disabled for older backups without the field', () {
      final config = PlayerSettingsController.extractConfig({'player': <String, dynamic>{}});

      expect(config['audioOnly'], isFalse);
      expect(config['windowsPipAlwaysOnTop'], isFalse);
    });

    test('preserves the Windows mini-player stacking preference', () {
      final config = PlayerSettingsController.extractConfig({
        'player': <String, dynamic>{'windowsPipAlwaysOnTop': true},
      });

      expect(config['windowsPipAlwaysOnTop'], isTrue);
    });

    test('enables Windows mini-player geometry restore for old settings', () {
      final oldConfig = PlayerSettingsController.extractConfig({'player': <String, dynamic>{}});
      final optedOutConfig = PlayerSettingsController.extractConfig({
        'player': <String, dynamic>{'rememberPipPosition': false},
      });

      expect(oldConfig['rememberPipPosition'], isTrue);
      expect(optedOutConfig['rememberPipPosition'], isFalse);
    });
  });
}
