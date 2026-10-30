import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/app/background/tone/analysis/background_models.dart';
import 'package:pure_live/app/background/tone/analysis/background_tone_policy.dart';

BackgroundToneDecision _decision({required bool dark, required double contrast, bool meetsTarget = true}) =>
    BackgroundToneDecision(
      dark: dark,
      opacity: 0.4,
      contrast: contrast,
      meetsTarget: meetsTarget,
      needsTextPlate: !meetsTarget,
    );

BackgroundTonePlans _plans({
  required double light,
  required double dark,
  bool lightMeets = true,
  bool darkMeets = true,
}) => BackgroundTonePlans(
  light: _decision(dark: false, contrast: light, meetsTarget: lightMeets),
  dark: _decision(dark: true, contrast: dark, meetsTarget: darkMeets),
);

void main() {
  group('palette planning', () {
    test('a black wallpaper picks the dark palette without a wash', () {
      final plans = backgroundTonePlansFor(guards: const [Color(0xFF000000)], autoScrim: true, customOpacity: 0.45);
      expect(plans.preferred.dark, isTrue);
      expect(plans.preferred.opacity, 0);
      expect(plans.preferred.meetsTarget, isTrue);
    });

    test('a white wallpaper picks the light palette without a wash', () {
      final plans = backgroundTonePlansFor(guards: const [Color(0xFFFFFFFF)], autoScrim: true, customOpacity: 0.45);
      expect(plans.preferred.dark, isFalse);
      expect(plans.preferred.opacity, 0);
      expect(plans.preferred.meetsTarget, isTrue);
    });

    test('a dark mid gray under a custom zero wash is reported as unreadable', () {
      final plans = backgroundTonePlansFor(guards: const [Color(0xFF767676)], autoScrim: false, customOpacity: 0);
      expect(plans.preferred.meetsTarget, isFalse);
      expect(plans.preferred.needsTextPlate, isTrue);
      expect(plans.preferred.opacity, 0);
    });

    test('custom mode keeps the viewer opacity for both palettes', () {
      final plans = backgroundTonePlansFor(guards: const [Color(0xFF000000)], autoScrim: false, customOpacity: 0.45);
      expect(plans.light.opacity, 0.45);
      expect(plans.dark.opacity, 0.45);
    });
  });

  group('hysteresis', () {
    test('the first decision for a wallpaper is unconstrained', () {
      final policy = BackgroundToneHysteresis();
      final applied = policy.resolve(identity: 'clip-a', plans: _plans(light: 5, dark: 5.2));
      expect(applied.dark, isTrue);
    });

    test('a small lead does not flip the palette', () {
      final policy = BackgroundToneHysteresis()..resolve(identity: 'clip-a', plans: _plans(light: 5, dark: 5.2));
      final applied = policy.resolve(identity: 'clip-a', plans: _plans(light: 5.2, dark: 5));
      expect(applied.dark, isTrue);
    });

    test('a clear lead flips once', () {
      final policy = BackgroundToneHysteresis()..resolve(identity: 'clip-a', plans: _plans(light: 5, dark: 5.2));
      final applied = policy.resolve(identity: 'clip-a', plans: _plans(light: 6.5, dark: 5));
      expect(applied.dark, isFalse);
    });

    test('a new wallpaper forgets the old palette', () {
      final policy = BackgroundToneHysteresis()..resolve(identity: 'clip-a', plans: _plans(light: 6.5, dark: 5));
      final applied = policy.resolve(identity: 'clip-b', plans: _plans(light: 5, dark: 6.5));
      expect(applied.dark, isTrue);
    });

    test('a failing palette is left even when the lead is small', () {
      final policy = BackgroundToneHysteresis()
        ..resolve(identity: 'clip-a', plans: _plans(light: 5, dark: 4, darkMeets: false));
      final applied = policy.resolve(identity: 'clip-a', plans: _plans(light: 4, dark: 4.2, lightMeets: false));
      expect(applied.dark, isTrue);
    });
  });
}
