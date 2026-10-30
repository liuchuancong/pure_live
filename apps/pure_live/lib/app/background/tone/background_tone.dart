import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/background/settings/background_settings.dart';
import 'package:pure_live/app/background/tone/analysis/analysis.dart';
import 'package:pure_live/app/background/tone/background_analysis.dart';

/// What the app's text must be painted for over the current wallpaper.
///
/// The decision is made from the wallpaper's measured brightness, not from a
/// single dominant colour: both palettes are scored against the page and its
/// extreme regions, each with the wash it would actually wear, and the one
/// that reaches the contrast target with less wash wins. [dark] is that
/// choice after hysteresis, so a nearly balanced picture does not flip the
/// app back and forth.
final class BackgroundTone {
  /// The decision for one wallpaper.
  const BackgroundTone({required this.identity, required this.dark, required this.plans, required this.analysis});

  /// The wallpaper identity the decision belongs to.
  final String identity;

  /// Whether the light-ink palette (dark mode) is the one to paint.
  final bool dark;

  /// Both palettes' decisions, so the scrim can follow whichever palette the
  /// app is actually wearing — the wallpaper's recommendation or, when
  /// following is off, the viewer's own choice.
  final BackgroundTonePlans plans;

  /// The measurements the decision came from.
  final BackgroundAnalysisResult analysis;

  /// The chosen palette's own decision.
  BackgroundToneDecision get decision => dark ? plans.dark : plans.light;
}

/// The hysteresis carried across rebuilds: the same wallpaper keeps its
/// palette unless the other one scores clearly better.
final backgroundToneHysteresisProvider = Provider<BackgroundToneHysteresis>((_) => BackgroundToneHysteresis());

/// The tone under the pages: null while there is no wallpaper, nothing has
/// been measured yet, or a clip's frame is still on its way — which keeps the
/// viewer's own light/dark choice.
final backgroundToneProvider = Provider<BackgroundTone?>((ref) {
  final analysis = ref.watch(backgroundAnalysisProvider).value;
  if (analysis == null) return null;
  final identity = ref.watch(backgroundMediaIdentityProvider);
  final mode = ref.watch(backgroundSettingsProvider.select((settings) => settings.scrimMode));
  final custom = ref.watch(backgroundSettingsProvider.select((settings) => settings.scrimOpacity));
  // The page-wide mean alone hides a bright corner behind a dark picture, so
  // every cell of the grid is a guard.
  final guards = <Color>{analysis.representative, for (final region in analysis.regions) region.color};
  final plans = backgroundTonePlansFor(
    guards: guards,
    autoScrim: mode == BackgroundScrimMode.auto,
    customOpacity: mode == BackgroundScrimMode.off ? 0 : custom,
  );
  final decision = ref.watch(backgroundToneHysteresisProvider).resolve(identity: identity, plans: plans);
  return BackgroundTone(identity: identity, dark: decision.dark, plans: plans, analysis: analysis);
});

/// The wash the app paints for the palette it is wearing.
///
/// Auto takes the smallest opacity that keeps the text readable, but never
/// less than the viewer's custom value: a background that already reads well
/// at that value looks exactly as it always did, and only the ones that do
/// not get a stronger wash. Custom uses the value exactly; off paints none.
double backgroundScrimOpacityFor({
  required BackgroundSettings settings,
  required BackgroundTonePlans? plans,
  required bool dark,
}) {
  final custom = settings.scrimOpacity.clamp(0.0, kBackgroundScrimCap);
  return switch (settings.scrimMode) {
    BackgroundScrimMode.off => 0,
    BackgroundScrimMode.custom => custom,
    BackgroundScrimMode.auto => switch (plans) {
      // Nothing measured yet: today's wash stands rather than flashing bare.
      null => custom,
      _ => (dark ? plans.dark : plans.light).opacity.clamp(custom, kBackgroundScrimCap),
    },
  };
}
