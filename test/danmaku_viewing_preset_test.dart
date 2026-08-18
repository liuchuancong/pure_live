import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live_play/danmaku_viewing_preset.dart';

void main() {
  test('each viewing preset only matches its actual rendered values', () {
    for (final preset in DanmakuViewingPreset.values) {
      expect(
        preset.matches(
          area: preset.area,
          top: preset.top,
          bottom: preset.bottom,
          speed: preset.speed,
          fontSize: preset.fontSize,
          fontBorder: preset.fontBorder,
          opacity: preset.opacity,
          stroke: preset.stroke,
          autoFps: true,
        ),
        isTrue,
        reason: preset.id,
      );
      expect(
        preset.matches(
          area: preset.area + 0.01,
          top: preset.top,
          bottom: preset.bottom,
          speed: preset.speed,
          fontSize: preset.fontSize,
          fontBorder: preset.fontBorder,
          opacity: preset.opacity,
          stroke: preset.stroke,
          autoFps: true,
        ),
        isFalse,
        reason: '${preset.id} must clear selection after manual edits',
      );
    }
  });

  test('preset selection clears when dynamic FPS is disabled', () {
    final preset = DanmakuViewingPreset.values.first;
    expect(
      preset.matches(
        area: preset.area,
        top: preset.top,
        bottom: preset.bottom,
        speed: preset.speed,
        fontSize: preset.fontSize,
        fontBorder: preset.fontBorder,
        opacity: preset.opacity,
        stroke: preset.stroke,
        autoFps: false,
      ),
      isFalse,
    );
  });
}
