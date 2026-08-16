import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/services/settings/danmaku_settings_controller.dart';

void main() {
  group('danmaku settings', () {
    test('uses compact defaults for an older backup', () {
      final config = DanmakuSettingsController.extractConfig({'danmaku': <String, dynamic>{}});

      expect(config['enablePipDanmaku'], isTrue);
      expect(config['pipDanmakuAutoScale'], isTrue);
      expect(config['pipDanmakuUseOriginalColor'], isTrue);
      expect(config['pipDanmakuFontSize'], 12.0);
      expect(config['pipDanmakuSpeed'], 90.0);
      expect(config['pipDanmakuMaxVisibleCount'], 6);
      expect(config['pipDanmakuFps'], 30);
      expect(config['danmakuAutoFps'], isTrue);
      expect(config['pipDanmakuAutoFps'], isTrue);
      expect(config['danmakuSpeed'], 120.0);
      expect(config['danmakuFontBorder'], 1.5);
      expect(config['enableDanmakuTapInteraction'], isTrue);
      expect(config['enableDanmakuLongPressInteraction'], isTrue);
    });

    test('clamps legacy main-player speed to the supported range', () {
      final slow = DanmakuSettingsController.extractConfig({
        'danmaku': {'danmakuSpeed': 8},
      });
      final fast = DanmakuSettingsController.extractConfig({
        'danmaku': {'danmakuSpeed': 800},
      });

      expect(slow['danmakuSpeed'], 20.0);
      expect(fast['danmakuSpeed'], 400.0);
    });

    test('clamps imported stroke width to the renderer range', () {
      final config = DanmakuSettingsController.extractConfig({
        'danmaku': {'danmakuFontBorder': 8},
      });

      expect(config['danmakuFontBorder'], 4.0);
    });

    test('clamps imported compact values to supported ranges', () {
      final config = DanmakuSettingsController.extractConfig({
        'danmaku': {
          'pipDanmakuFontSize': 100,
          'pipDanmakuSpeed': 1,
          'pipDanmakuOpacity': 0,
          'pipDanmakuArea': 5,
          'pipDanmakuMaxVisibleCount': 99,
          'pipDanmakuEmitInterval': 9,
          'pipDanmakuFps': 240,
        },
      });

      expect(config['pipDanmakuFontSize'], 24.0);
      expect(config['pipDanmakuSpeed'], 20.0);
      expect(config['pipDanmakuOpacity'], 0.1);
      expect(config['pipDanmakuArea'], 1.0);
      expect(config['pipDanmakuMaxVisibleCount'], 20);
      expect(config['pipDanmakuEmitInterval'], 2.0);
      expect(config['pipDanmakuFps'], 240);
    });

    test('merges compact settings without dropping existing fields', () {
      final root = <String, dynamic>{
        'danmaku': {'hideDanmaku': false},
        'player': {'engine': 'mpv'},
      };

      final merged = DanmakuSettingsController.mergeConfig(root, {
        'enablePipDanmaku': true,
        'pipDanmakuColor': 0xFFFF0000,
      });

      expect(merged['player'], {'engine': 'mpv'});
      expect(merged['danmaku']['hideDanmaku'], isFalse);
      expect(merged['danmaku']['enablePipDanmaku'], isTrue);
      expect(merged['danmaku']['pipDanmakuColor'], 0xFFFF0000);
    });
  });
}
