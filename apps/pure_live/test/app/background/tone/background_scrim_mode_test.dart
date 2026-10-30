import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/app/background/settings/background_settings.dart';
import 'package:pure_live/app/background/tone/analysis/background_models.dart';
import 'package:pure_live/app/background/tone/background_tone.dart';

BackgroundTonePlans _plans({required double light, required double dark}) => BackgroundTonePlans(
  light: BackgroundToneDecision(dark: false, opacity: light, contrast: 4.5, meetsTarget: true, needsTextPlate: false),
  dark: BackgroundToneDecision(dark: true, opacity: dark, contrast: 4.5, meetsTarget: true, needsTextPlate: false),
);

void main() {
  test('a new install follows the wallpaper and starts on auto with a 0.45 floor', () {
    const settings = BackgroundSettings();
    expect(settings.scrimMode, BackgroundScrimMode.auto);
    expect(settings.scrimOpacity, 0.45);
    expect(settings.followTone, isTrue);
  });

  test('auto never paints less than the viewer set', () {
    const settings = BackgroundSettings();
    expect(backgroundScrimOpacityFor(settings: settings, plans: _plans(light: 0.2, dark: 0.3), dark: true), 0.45);
  });

  test('auto raises a wallpaper that needs more wash', () {
    const settings = BackgroundSettings();
    expect(backgroundScrimOpacityFor(settings: settings, plans: _plans(light: 0.2, dark: 0.7), dark: true), 0.7);
  });

  test('auto takes the plan of the palette actually worn, not the recommendation', () {
    const settings = BackgroundSettings(scrimOpacity: 0.1);
    expect(backgroundScrimOpacityFor(settings: settings, plans: _plans(light: 0.8, dark: 0.2), dark: false), 0.8);
  });

  test('auto with nothing measured keeps the custom wash instead of flashing bare', () {
    expect(
      backgroundScrimOpacityFor(settings: const BackgroundSettings(), plans: null, dark: false),
      0.45,
    );
  });

  test('custom uses the value exactly', () {
    const settings = BackgroundSettings(scrimMode: BackgroundScrimMode.custom, scrimOpacity: 0.1);
    expect(backgroundScrimOpacityFor(settings: settings, plans: _plans(light: 0.2, dark: 0.7), dark: true), 0.1);
  });

  test('off paints no wash at all', () {
    expect(
      backgroundScrimOpacityFor(
        settings: const BackgroundSettings(scrimMode: BackgroundScrimMode.off, scrimOpacity: 0.8),
        plans: _plans(light: 0.2, dark: 0.7),
        dark: false,
      ),
      0,
    );
  });
}
