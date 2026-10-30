import 'dart:ui' show Color;

import 'package:pure_live/app/background/tone/analysis/background_models.dart';

/// The ink the light palette paints with, near its own text colour rather
/// than pure black: readability is scored with what the eye will read.
const Color kBackgroundDarkInk = Color(0xFF14181C);

/// The ink the dark palette paints with.
const Color kBackgroundLightInk = Color(0xFFF4F6F8);

/// Bins of the luminance histogram: enough to tell a two-tone poster from a
/// photo without carrying a per-pixel array around.
const int kBackgroundHistogramBins = 16;

/// Below this relative luminance a sample counts as dark.
const double kBackgroundDarkLuma = 0.18;

/// Above this relative luminance a sample counts as bright.
const double kBackgroundBrightLuma = 0.82;

/// The ink a background prefers, its contrast, and whether that is the dark
/// palette.
typedef BackgroundInk = ({Color color, double contrast, bool dark});

/// The WCAG relative luminance of [color], on the sRGB scale.
double relativeLuminanceOf(Color color) => color.computeLuminance();

/// The WCAG contrast ratio between [a] and [b], from 1 to 21.
double contrastRatioOf(Color a, Color b) {
  final first = relativeLuminanceOf(a) + 0.05;
  final second = relativeLuminanceOf(b) + 0.05;
  return first > second ? first / second : second / first;
}

/// The better-reading of the app's two inks on [background].
BackgroundInk backgroundInkOn(Color background) {
  final lightContrast = contrastRatioOf(background, kBackgroundLightInk);
  final darkContrast = contrastRatioOf(background, kBackgroundDarkInk);
  return darkContrast >= lightContrast
      ? (color: kBackgroundDarkInk, contrast: darkContrast, dark: false)
      : (color: kBackgroundLightInk, contrast: lightContrast, dark: true);
}

/// The mean of [colors] in straight sRGB, alpha included.
///
/// This is a representative colour, never a luminance: averaging the channels
/// of a red and a green patch says nothing about how bright the result reads.
Color averageColorOf(Iterable<Color> colors) {
  var count = 0;
  var alpha = 0.0;
  var red = 0.0;
  var green = 0.0;
  var blue = 0.0;
  for (final color in colors) {
    count++;
    alpha += color.a;
    red += color.r;
    green += color.g;
    blue += color.b;
  }
  if (count == 0) return const Color(0x00000000);
  return Color.from(alpha: alpha / count, red: red / count, green: green / count, blue: blue / count);
}

/// The luminance profile of [values], after clamping them into `[0, 1]`.
///
/// Percentiles are linearly interpolated between neighbouring samples, so a
/// two-value surface answers 0.5 at the median rather than snapping to one
/// side.
BackgroundLuminanceProfile backgroundProfileOf(Iterable<double> values) {
  final samples = [
    for (final value in values)
      if (value.isFinite) value.clamp(0.0, 1.0) else 0.0,
  ]..sort();
  final bins = List<double>.filled(kBackgroundHistogramBins, 0);
  if (samples.isEmpty) {
    return BackgroundLuminanceProfile(
      mean: 0,
      median: 0,
      p10: 0,
      p25: 0,
      p75: 0,
      p90: 0,
      darkRatio: 0,
      brightRatio: 0,
      histogram: bins,
    );
  }

  var total = 0.0;
  var dark = 0;
  var bright = 0;
  for (final value in samples) {
    total += value;
    if (value < kBackgroundDarkLuma) dark++;
    if (value > kBackgroundBrightLuma) bright++;
    final index = value >= 1 ? bins.length - 1 : (value * bins.length).floor();
    bins[index] += 1;
  }
  final count = samples.length;
  for (var index = 0; index < bins.length; index++) {
    bins[index] /= count;
  }
  return BackgroundLuminanceProfile(
    mean: total / count,
    median: _percentile(samples, 0.5),
    p10: _percentile(samples, 0.1),
    p25: _percentile(samples, 0.25),
    p75: _percentile(samples, 0.75),
    p90: _percentile(samples, 0.9),
    darkRatio: dark / count,
    brightRatio: bright / count,
    histogram: bins,
  );
}

/// The [percentile] of an already sorted, non-empty list.
double _percentile(List<double> sorted, double percentile) {
  if (sorted.length == 1) return sorted.first;
  final position = percentile * (sorted.length - 1);
  final lower = position.floor();
  final upper = position.ceil();
  if (lower == upper) return sorted[lower];
  return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - lower);
}
