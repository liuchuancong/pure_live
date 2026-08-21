import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/services/display_mode_service.dart';
import 'package:pure_live/common/services/settings/danmaku_settings_controller.dart';

void main() {
  group('danmaku settings', () {
    test('adaptive FPS bounds barrage work without lowering the app display mode', () {
      const display = DisplayModeInfo(
        enabled: true,
        currentRefreshRate: 120,
        maxRefreshRate: 144,
        preferredRefreshRate: 144,
        supportedRefreshRates: [60, 120, 144],
      );

      expect(DanmakuSettingsController.resolveAdaptiveDanmakuFps(display), 60);
      expect(DanmakuSettingsController.resolveAdaptiveDanmakuFps(display, pip: true), 30);
    });

    test('adaptive FPS still follows a display below its renderer ceiling', () {
      const display = DisplayModeInfo(
        enabled: true,
        currentRefreshRate: 50,
        maxRefreshRate: 50,
        preferredRefreshRate: 50,
        supportedRefreshRates: [50],
      );

      expect(DanmakuSettingsController.resolveAdaptiveDanmakuFps(display), 50);
      expect(DanmakuSettingsController.resolveAdaptiveDanmakuFps(display, pip: true), 30);
    });

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
      expect(config['noEmojiMode'], isFalse);
      expect(config['pipDanmakuNoEmojiMode'], isFalse);
      expect(config['collapseRepeatedDanmaku'], isFalse);
      expect(config['repeatedDanmakuWindowSeconds'], 5);
      expect(config['danmakuFontWeight'], 500);
      expect(config['pipDanmakuFontWeight'], 500);
      expect(config['enableDanmakuSimilarityFilter'], isTrue);
      expect(config['danmakuSimilarityThreshold'], 85);
    });

    test('normalizes imported font weights and similarity bounds', () {
      final config = DanmakuSettingsController.extractConfig({
        'danmaku': {
          'danmakuFontWeight': 549,
          'pipDanmakuFontWeight': 9999,
          'danmakuSimilarityThreshold': 12,
          'danmakuSimilarityCacheDuration': 99,
          'danmakuSimilarityMaxCacheSize': 5,
        },
      });

      expect(config['danmakuFontWeight'], 500);
      expect(config['pipDanmakuFontWeight'], 900);
      expect(config['danmakuSimilarityThreshold'], 50);
      expect(config['danmakuSimilarityCacheDuration'], 60);
      expect(config['danmakuSimilarityMaxCacheSize'], 20);
    });

    test('clamps the repeated-text merge window from imported settings', () {
      final short = DanmakuSettingsController.extractConfig({
        'danmaku': {'collapseRepeatedDanmaku': true, 'repeatedDanmakuWindowSeconds': 0},
      });
      final long = DanmakuSettingsController.extractConfig({
        'danmaku': {'repeatedDanmakuWindowSeconds': 99},
      });

      expect(short['collapseRepeatedDanmaku'], isTrue);
      expect(short['repeatedDanmakuWindowSeconds'], 1);
      expect(long['repeatedDanmakuWindowSeconds'], 30);
    });

    test('migrates the upstream compact pure-text backup key', () {
      final config = DanmakuSettingsController.extractConfig({
        'danmaku': {'noEmojiMode': true, 'pipDanmaNoEmojiMode': true},
      });

      expect(config['noEmojiMode'], isTrue);
      expect(config['pipDanmakuNoEmojiMode'], isTrue);
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
