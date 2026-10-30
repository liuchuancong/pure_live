import 'dart:ui' show Color;

import 'package:pure_live/app/background/tone/analysis/background_models.dart';
import 'package:pure_live/app/background/tone/analysis/background_scrim.dart';

/// How much better a new palette has to score before the app switches while
/// the background is unchanged: without this, a nearly balanced photo flips
/// back and forth as its sampled pixels move by a hair.
const double kBackgroundToneHysteresis = 0.35;

/// Scores both palettes against [guards] (the page and its extreme regions).
///
/// [autoScrim] asks each palette for the smallest wash that reaches [target];
/// otherwise [customOpacity] is applied to both, leaving the choice, and any
/// readability shortfall, to the viewer.
BackgroundTonePlans backgroundTonePlansFor({
  required Iterable<Color> guards,
  required bool autoScrim,
  required double customOpacity,
  double target = kBackgroundBodyContrastTarget,
}) {
  final colors = guards.toList(growable: false);
  return BackgroundTonePlans(
    light: _decisionFor(
      colors: colors,
      dark: false,
      autoScrim: autoScrim,
      customOpacity: customOpacity,
      target: target,
    ),
    dark: _decisionFor(colors: colors, dark: true, autoScrim: autoScrim, customOpacity: customOpacity, target: target),
  );
}

BackgroundToneDecision _decisionFor({
  required List<Color> colors,
  required bool dark,
  required bool autoScrim,
  required double customOpacity,
  required double target,
}) {
  if (autoScrim) {
    final plan = backgroundScrimPlanFor(bases: colors, dark: dark, target: target);
    return BackgroundToneDecision(
      dark: dark,
      opacity: plan.opacity,
      contrast: plan.contrast,
      meetsTarget: plan.meetsTarget,
      needsTextPlate: plan.needsTextPlate,
    );
  }
  final opacity = customOpacity.clamp(0.0, 1.0);
  final contrast = backgroundWorstContrast(colors, dark: dark, opacity: opacity);
  final meetsTarget = contrast >= target;
  return BackgroundToneDecision(
    dark: dark,
    opacity: opacity,
    contrast: contrast,
    meetsTarget: meetsTarget,
    needsTextPlate: !meetsTarget,
  );
}

/// Keeps the applied palette across an unchanged wallpaper unless the other
/// one scores clearly better.
///
/// A new wallpaper resets the memory, so the first decision for it is always
/// the unconstrained one; a new frame of the same clip only nudges the wash or,
/// past [window], flips the palette once.
final class BackgroundToneHysteresis {
  /// Creates a policy with [window] contrast units of slack.
  BackgroundToneHysteresis({this.window = kBackgroundToneHysteresis});

  /// How far the other palette must lead before a switch is allowed.
  final double window;

  String? _identity;
  BackgroundToneDecision? _applied;

  /// The palette to paint for [identity] given both freshly scored plans.
  BackgroundToneDecision resolve({required String identity, required BackgroundTonePlans plans}) {
    final preferred = plans.preferred;
    final applied = _applied;
    if (_identity != identity || applied == null) {
      _identity = identity;
      _applied = preferred;
      return preferred;
    }
    final current = applied.dark ? plans.dark : plans.light;
    if (preferred.dark == applied.dark) {
      _applied = current;
      return current;
    }
    final comparable = current.meetsTarget == preferred.meetsTarget;
    if (comparable && (preferred.contrast - current.contrast).abs() < window) {
      _applied = current;
      return current;
    }
    _applied = preferred;
    return preferred;
  }

  /// Forgets the applied palette; the next resolve starts fresh.
  void reset() {
    _identity = null;
    _applied = null;
  }
}
