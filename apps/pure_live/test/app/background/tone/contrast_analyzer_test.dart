import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/app/background/tone/analysis/background_luminance.dart';
import 'package:pure_live/app/background/tone/analysis/background_scrim.dart';

void main() {
  group('relative luminance', () {
    test('black is 0 and white is 1', () {
      expect(relativeLuminanceOf(const Color(0xFF000000)), 0);
      expect(relativeLuminanceOf(const Color(0xFFFFFFFF)), 1);
    });

    test('a saturated channel is linearized, not averaged', () {
      final red = relativeLuminanceOf(const Color(0xFFFF0000));
      expect(red, closeTo(0.2126, 0.0005));
      expect(red, isNot(closeTo(1 / 3, 0.01)));
    });
  });

  group('contrast ratio', () {
    test('black on white is 21:1', () {
      expect(contrastRatioOf(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 1e-9));
    });

    test('a colour against itself is 1:1', () {
      expect(contrastRatioOf(const Color(0xFF336699), const Color(0xFF336699)), 1);
    });

    test('the ink picker prefers dark ink on white, the light palette', () {
      final ink = backgroundInkOn(const Color(0xFFFFFFFF));
      expect(ink.color, kBackgroundDarkInk);
      expect(ink.dark, isFalse);
      expect(ink.contrast, greaterThanOrEqualTo(4.5));
    });

    test('the ink picker prefers light ink on black, the dark palette', () {
      final ink = backgroundInkOn(const Color(0xFF000000));
      expect(ink.color, kBackgroundLightInk);
      expect(ink.dark, isTrue);
    });
  });

  group('automatic scrim', () {
    test('a readable surface needs no wash', () {
      final plan = backgroundScrimPlanFor(bases: [const Color(0xFF000000)], dark: true);
      expect(plan.opacity, 0);
      expect(plan.meetsTarget, isTrue);
      expect(plan.needsTextPlate, isFalse);
    });

    test('a dark mid gray gains just enough wash and is re-checked after compositing', () {
      const gray = Color(0xFF767676);
      final plan = backgroundScrimPlanFor(bases: [gray], dark: false);
      expect(plan.opacity, greaterThan(0));
      expect(plan.opacity, lessThanOrEqualTo(kBackgroundScrimCap));
      expect(plan.meetsTarget, isTrue);
      final composited = backgroundComposite(gray, dark: false, opacity: plan.opacity);
      expect(contrastRatioOf(composited, kBackgroundDarkInk), greaterThanOrEqualTo(4.5));
    });

    test('the worst guarded colour decides the wash', () {
      const black = Color(0xFF000000);
      const white = Color(0xFFFFFFFF);
      final onlyBlack = backgroundScrimPlanFor(bases: [black], dark: true);
      final both = backgroundScrimPlanFor(bases: [black, white], dark: true);
      expect(both.opacity, greaterThan(onlyBlack.opacity));
      expect(both.meetsTarget, isTrue);
    });

    test('a target out of reach at the cap asks for a text plate', () {
      final plan = backgroundScrimPlanFor(bases: [const Color(0xFF808080)], dark: false, target: 21, maxOpacity: 0.1);
      expect(plan.opacity, 0.1);
      expect(plan.meetsTarget, isFalse);
      expect(plan.needsTextPlate, isTrue);
    });
  });
}
