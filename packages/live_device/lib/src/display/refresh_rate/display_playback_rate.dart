import 'dart:math' as math;

/// How the refresh-rate mode treats a playing video (the reference's
/// `matchVideoFrameRate` policy).
enum DisplayPlaybackRefreshMode {
  /// Declare the video's own frame rate and let the system pick a multiple.
  powerSaving,

  /// A whole multiple of the frame rate, kept low while idle.
  balanced,

  /// The highest whole multiple of the frame rate.
  performance,
}

/// 23.976 → 24, 29.97 → 30, 59.94 → 60: a rate within 0.5 % of a whole
/// number is that number.
double normalizePlaybackFrameRate(double frameRate) {
  if (!frameRate.isFinite || frameRate <= 0) return 0;
  final whole = frameRate.roundToDouble();
  return (frameRate - whole).abs() <= whole * 0.005 ? whole : frameRate;
}

/// The rates in [supportedHz] that are a whole multiple of [frameRate]
/// (within 0.5 %), ascending: 60 and 120 for 30 frames on a 60/90/120 Hz
/// display.
List<double> playbackFrameRateMultiples({required double frameRate, required Iterable<double> supportedHz}) {
  if (!frameRate.isFinite || frameRate <= 0) return const [];
  final rates = [...supportedHz]..sort();
  return [
    for (final rate in rates)
      if (rate >= frameRate * 0.995 && (rate - (rate / frameRate).round() * frameRate).abs() <= rate * 0.005) rate,
  ];
}

/// The rate to declare on the surface while [frameRate] plays.
///
/// This mirrors the reference's `playbackRefreshRate`, including its
/// fallback: power saving declares the video's own rate so the system picks
/// a multiple; balanced at rest keeps the highest multiple up to 60 (or the
/// lowest one when none fits); balanced while interacting and performance
/// take the highest whole multiple. A display with no whole multiple, or
/// with no reported rates, gets the video's own rate — the shortest period
/// judders least, and the system can still choose.
double playbackRefreshRateForDisplay({
  required double frameRate,
  required DisplayPlaybackRefreshMode mode,
  required bool high,
  required Iterable<double> supportedHz,
}) {
  final normalized = normalizePlaybackFrameRate(frameRate);
  if (normalized <= 0) return 0;
  final rates = [...supportedHz]..sort();
  if (mode == DisplayPlaybackRefreshMode.powerSaving || rates.isEmpty) return normalized;
  final multiples = playbackFrameRateMultiples(frameRate: normalized, supportedHz: rates);
  if (multiples.isEmpty) return rates.reduce(math.max);
  if (high || mode == DisplayPlaybackRefreshMode.performance) return multiples.last;
  return multiples.where((rate) => rate <= 60.5).lastOrNull ?? multiples.first;
}
