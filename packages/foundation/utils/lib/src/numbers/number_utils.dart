// Module: lib/src/numbers/number_utils.dart
// Purpose: The two arithmetic operations this repository repeats: hold a value inside a range, and map a
// value onto one.
// Author: liuchuancong
// Created: 2026-10-10
//
// Measured duplication: nine packages call `.clamp()` on the sdk directly, which returns num and forces a
// cast at the use site, and the progress-to-pixel mapping a player bar needs is the same arithmetic a
// volume slider has already written. [ClosedInterval] in the math module carries the range as a value; this
// is the free-function form for callers that only need the answer.

/// [value] forced into the closed range [lower]..[upper] as an int.
///
/// Throws when the range is inverted: `clamp(5, min: 9, max: 1)` silently returning 9 is how a mis-set
/// cache limit becomes a mysterious one.
int clampInt(num value, {required int lower, required int upper}) {
  if (lower > upper) {
    throw ArgumentError.value(upper, 'upper', 'must not be below lower ($lower)');
  }
  return value.clamp(lower, upper).toInt();
}

/// [value] forced into the closed range [lower]..[upper] as a double.
double clampDouble(num value, {required double lower, required double upper}) {
  if (lower > upper) {
    throw ArgumentError.value(upper, 'upper', 'must not be below lower ($lower)');
  }
  return value.clamp(lower, upper).toDouble();
}

/// The point [fraction] of the way from [from] to [to].
///
/// [fraction] is clamped, because it arrives from a ui or a progress ratio and an out-of-range one should
/// draw an end position rather than something off-screen.
double lerpDouble(double from, double to, double fraction) =>
    from + (to - from) * clampDouble(fraction, lower: 0, upper: 1);

/// [value] rounded to [decimals] places, as a double.
///
/// The scale-and-round dance is what a duration or a bitrate display keeps reimplementing; rounding a
/// double is lossy in a way callers should not have to discover per site.
double roundTo(double value, {int decimals = 2}) {
  if (value.isNaN || value.isInfinite) {
    return value;
  }
  final factor = _pow10(decimals);
  return (value * factor).roundToDouble() / factor;
}

double _pow10(int decimals) {
  var factor = 1.0;
  for (var i = 0; i < decimals; i++) {
    factor *= 10;
  }
  return factor;
}

/// The whole-number percentage [part] is of [whole], or 0 when [whole] is zero.
///
/// A zero total is normal here - an empty playlist still draws a progress line - so this answers 0 instead
/// of throwing or returning NaN, both of which a layout then has to guard anyway.
int percentOf(int part, int whole) {
  if (whole <= 0) {
    return 0;
  }
  return clampInt(part * 100 / whole, lower: 0, upper: 100);
}
