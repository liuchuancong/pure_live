import 'dart:ui' show Color, Rect;

/// The side a wallpaper is decoded to before it is measured.
///
/// Wide enough for a stable histogram over a 3×3 grid, small enough that the
/// per-pixel loop is trivial and a 4K photo never lives in memory in full.
const int kBackgroundAnalysisSampleWidth = 64;

/// Bump when a change to the analysis would make an old result misleading; the
/// cache key carries it, so the next call re-measures instead of reusing it.
const int kBackgroundAnalysisVersion = 1;

/// Where an analysis sample came from, so a cached result can be read back
/// without guessing whether it describes a picture, a clip or a flat paint.
enum BackgroundSampleSource {
  /// A flat colour; the statistics are one value.
  solid,

  /// A gradient sampled along its own line, stops and angle.
  gradient,

  /// A picture or an online image.
  image,

  /// A still taken from the headless decoder for a wallpaper clip.
  videoStill,

  /// A frame the playing wallpaper decoded.
  videoFrame,
}

/// The luminance distribution of a sampled surface.
///
/// The values are relative luminance in `[0, 1]`, not RGB averages: a red
/// channel at full strength contributes about 0.213, not a third.
final class BackgroundLuminanceProfile {
  /// Creates a profile from already computed statistics.
  const BackgroundLuminanceProfile({
    required this.mean,
    required this.median,
    required this.p10,
    required this.p25,
    required this.p75,
    required this.p90,
    required this.darkRatio,
    required this.brightRatio,
    required this.histogram,
  });

  /// The arithmetic mean of the sampled relative luminance values.
  final double mean;

  /// The 50th percentile.
  final double median;

  /// The 10th percentile.
  final double p10;

  /// The 25th percentile.
  final double p25;

  /// The 75th percentile.
  final double p75;

  /// The 90th percentile.
  final double p90;

  /// The share of samples below the dark threshold.
  final double darkRatio;

  /// The share of samples above the bright threshold.
  final double brightRatio;

  /// Normalized counts across the luminance range, darkest bin first.
  final List<double> histogram;

  /// How wide the middle 80% of the surface spreads; a small spread is a
  /// uniform patch, a wide one needs a worst-case decision.
  double get spread => p90 - p10;
}

/// One cell of the wallpaper's 3×3 grid.
///
/// A region answers "what does the text that sits over this part of the
/// wallpaper need", separately from the page-wide theme. It is a hint, not a
/// replacement for the global decision.
final class ImageRegionResult {
  /// Creates one region result.
  const ImageRegionResult({
    required this.index,
    required this.rect,
    required this.color,
    required this.profile,
    required this.dark,
    required this.ink,
    required this.contrast,
  });

  /// The cell in row-major order: `row * 3 + column`.
  final int index;

  /// The cell in normalized wallpaper coordinates.
  final Rect rect;

  /// The mean composited colour of the cell.
  final Color color;

  /// The cell's own luminance distribution.
  final BackgroundLuminanceProfile profile;

  /// Whether the light-ink palette reads better on this cell.
  final bool dark;

  /// The recommended ink for this cell.
  final Color ink;

  /// The contrast of [ink] against [color], without an extra scrim.
  final double contrast;

  /// The cell's row, 0 to 2.
  int get row => index ~/ 3;

  /// The cell's column, 0 to 2.
  int get column => index % 3;
}

/// What one decode measured: the palette colour, the brightness distribution
/// and the 3×3 regions.
///
/// The result is deliberately measurement-only. Theme choice, scrim size and
/// local ink are policies applied on top of it, so changing the scrim or the
/// user's theme never forces the wallpaper to be decoded again.
final class BackgroundAnalysisResult {
  /// Creates an analysis result.
  const BackgroundAnalysisResult({
    required this.source,
    required this.dominant,
    required this.representative,
    required this.profile,
    required this.regions,
  });

  /// Where the sample came from.
  final BackgroundSampleSource source;

  /// The most populated palette colour; the flat mean is the fallback.
  final Color dominant;

  /// The mean composited colour of the whole surface.
  final Color representative;

  /// The whole-surface luminance distribution.
  final BackgroundLuminanceProfile profile;

  /// The 3×3 regions, row-major.
  final List<ImageRegionResult> regions;

  /// The same measurements with the palette's own dominant colour.
  BackgroundAnalysisResult copyWithDominant(Color value) => BackgroundAnalysisResult(
    source: source,
    dominant: value,
    representative: representative,
    profile: profile,
    regions: regions,
  );
}

/// The smallest scrim that reaches the requested contrast, and whether it did.
final class BackgroundScrimPlan {
  /// Creates a scrim plan.
  const BackgroundScrimPlan({
    required this.opacity,
    required this.contrast,
    required this.meetsTarget,
    required this.needsTextPlate,
  });

  /// The wash opacity, 0 to the cap.
  final double opacity;

  /// The worst-case contrast after the wash.
  final double contrast;

  /// Whether every guarded colour reaches the target.
  final bool meetsTarget;

  /// Whether the target is out of reach even at the cap, so the text needs a
  /// plate of its own.
  final bool needsTextPlate;
}

/// One palette's theme decision: the ink side, the scrim and its score.
final class BackgroundToneDecision {
  /// Creates a tone decision.
  const BackgroundToneDecision({
    required this.dark,
    required this.opacity,
    required this.contrast,
    required this.meetsTarget,
    required this.needsTextPlate,
  });

  /// Whether the light-ink palette is the one to paint.
  final bool dark;

  /// The wash opacity this decision uses.
  final double opacity;

  /// The worst-case contrast this decision reaches.
  final double contrast;

  /// Whether the decision reaches the target.
  final bool meetsTarget;

  /// Whether even the strongest allowed wash is not enough.
  final bool needsTextPlate;
}

/// Both palettes scored for the same guards, before hysteresis picks one.
final class BackgroundTonePlans {
  /// Creates the pair of plans.
  const BackgroundTonePlans({required this.light, required this.dark});

  /// The light-ink palette with its own wash.
  final BackgroundToneDecision light;

  /// The dark-ink palette with its own wash.
  final BackgroundToneDecision dark;

  /// The plan to use when there is no history to keep: a plan that reaches the
  /// target beats one that does not; otherwise the cheaper wash wins, and the
  /// higher contrast breaks the tie.
  BackgroundToneDecision get preferred {
    if (light.meetsTarget != dark.meetsTarget) return light.meetsTarget ? light : dark;
    if (light.meetsTarget && (light.opacity - dark.opacity).abs() > 0.001) {
      return light.opacity < dark.opacity ? light : dark;
    }
    return light.contrast >= dark.contrast ? light : dark;
  }
}
