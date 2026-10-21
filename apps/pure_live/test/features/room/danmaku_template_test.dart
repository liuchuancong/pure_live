import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/features/room/danmaku_template.dart';
import 'package:pure_live/system/configuration/app_preferences.dart';

void main() {
  group('BarrageTemplate', () {
    test('of() reads the look out of the stored answers', () {
      final preferences = AppPreferences().copyWith(barrageArea: 0.35, barrageSpeed: 105, barrageFontSize: 17);
      final template = BarrageTemplate.of(preferences);
      expect(template.area, 0.35);
      expect(template.speed, 105);
      expect(template.fontSize, 17);
    });

    test('applyTo() writes the look back onto the answers', () {
      final preset = BarrageTemplate.presets.first.$2;
      final applied = preset.applyTo(AppPreferences());
      expect(BarrageTemplate.of(applied).presetKey, 'best');
    });

    test('encode/tryDecode round-trips a look exactly', () {
      const template = BarrageTemplate(
        area: 0.42,
        top: 12,
        bottom: 30,
        speed: 133,
        fontSize: 15.5,
        fontWeight: 700,
        strokeWidth: 2.5,
        stroke: false,
        opacity: 0.86,
      );
      final decoded = BarrageTemplate.tryDecode(template.encode());
      expect(decoded, isNotNull);
      expect(decoded!.area, template.area);
      expect(decoded.top, template.top);
      expect(decoded.bottom, template.bottom);
      expect(decoded.speed, template.speed);
      expect(decoded.fontSize, template.fontSize);
      expect(decoded.fontWeight, template.fontWeight);
      expect(decoded.strokeWidth, template.strokeWidth);
      expect(decoded.stroke, isFalse);
      expect(decoded.opacity, template.opacity);
    });

    test('tryDecode rejects a broken or out-of-range save', () {
      expect(BarrageTemplate.tryDecode(''), isNull);
      expect(BarrageTemplate.tryDecode('area=9;speed=120;fontSize=16;strokeWidth=1;opacity=1;fontWeight=500'), isNull);
      expect(BarrageTemplate.tryDecode('nonsense'), isNull);
    });

    test('presetKey is null for a look of the viewer\u2019s own', () {
      const custom = BarrageTemplate(area: 0.5, speed: 121, fontSize: 16, strokeWidth: 1.5, opacity: 1);
      expect(custom.presetKey, isNull);
      const reset = BarrageTemplate(area: 1, speed: 120, fontSize: 16, strokeWidth: 1.5, opacity: 1);
      expect(reset.presetKey, 'reset');
    });
  });
}
