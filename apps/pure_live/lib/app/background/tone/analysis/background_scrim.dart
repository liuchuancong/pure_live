import 'dart:ui' show Color;

import 'package:pure_live/app/background/tone/analysis/background_luminance.dart';
import 'package:pure_live/app/background/tone/analysis/background_models.dart';

/// Contrast a body of text needs under WCAG AA.
const double kBackgroundBodyContrastTarget = 4.5;

/// Contrast a large heading needs under WCAG AA.
const double kBackgroundLargeContrastTarget = 3;

/// The strongest wash the app will add on its own; past it the wallpaper would
/// stop reading as a picture and the text needs a plate instead.
const double kBackgroundScrimCap = 0.8;

/// The wash a light palette lays down: near-white, like its own text surface.
const Color kBackgroundLightWash = Color(0xFFFFFFFF);

/// The wash a dark palette lays down.
const Color kBackgroundDarkWash = Color(0xFF000000);

/// The wash colour of [dark], applied over the wallpaper.
Color backgroundScrimWashFor({required bool dark}) => dark ? kBackgroundDarkWash : kBackgroundLightWash;

/// [base] under the palette's wash at [opacity], exactly as the overlay paints
/// it.
Color backgroundComposite(Color base, {required bool dark, required double opacity}) {
  final alpha = opacity.clamp(0.0, 1.0);
  if (alpha <= 0) return base;
  return Color.alphaBlend(backgroundScrimWashFor(dark: dark).withValues(alpha: alpha), base);
}

/// The worst contrast of the palette's ink across [bases] after the wash.
///
/// An empty guard set is treated as already readable, so a caller that has not
/// measured anything does not force a full-strength wash.
double backgroundWorstContrast(Iterable<Color> bases, {required bool dark, required double opacity}) {
  final ink = dark ? kBackgroundLightInk : kBackgroundDarkInk;
  var worst = 21.0;
  var seen = false;
  for (final base in bases) {
    final contrast = contrastRatioOf(backgroundComposite(base, dark: dark, opacity: opacity), ink);
    if (!seen || contrast < worst) {
      worst = contrast;
      seen = true;
    }
  }
  return worst;
}

/// The smallest opacity in `[0, maxOpacity]` that brings every guarded colour
/// to [target], re-checked on the composited colour.
///
/// The search walks 1% steps rather than assuming the worst case is monotonic:
/// a guard set can mix colours on both sides of the ink, where adding more
/// wash helps one and briefly hurts another.
BackgroundScrimPlan backgroundScrimPlanFor({
  required Iterable<Color> bases,
  required bool dark,
  double target = kBackgroundBodyContrastTarget,
  double maxOpacity = kBackgroundScrimCap,
}) {
  final colors = bases.toList(growable: false);
  if (colors.isEmpty) {
    return const BackgroundScrimPlan(opacity: 0, contrast: 21, meetsTarget: true, needsTextPlate: false);
  }
  final maximum = maxOpacity.clamp(0.0, 1.0);
  const steps = 100;
  for (var step = 0; step <= steps; step++) {
    final opacity = maximum * step / steps;
    final contrast = backgroundWorstContrast(colors, dark: dark, opacity: opacity);
    if (contrast >= target) {
      return BackgroundScrimPlan(opacity: opacity, contrast: contrast, meetsTarget: true, needsTextPlate: false);
    }
  }
  return BackgroundScrimPlan(
    opacity: maximum,
    contrast: backgroundWorstContrast(colors, dark: dark, opacity: maximum),
    meetsTarget: false,
    needsTextPlate: true,
  );
}
