// Module: lib/src/math/interval.dart
// Purpose: A closed double range that can clamp, position and re-express a value.
// Author: liuchuancong
// Created: 2026-10-10
//
// The player bar, the volume slider and the buffering indicator all do the same two conversions: hold a
// measurement inside a range, and translate a value between a source range and a 0..1 fraction. Each one
// wrote it inline against its own min and max, so a duration of zero - a stream that has not reported
// bounds yet - produced NaN in one place and Infinity in another.
//
// A range is a value here rather than two parameters because the pair travels together: passing a width
// that no longer matches its origin is the mistake this shape makes impossible.

/// The closed range [lower]..[upper].
final class ClosedInterval {
  /// Throws when [lower] exceeds [upper]; an inverted range has no points, and letting one through turns
  /// every later clamp into a silent choice of an endpoint.
  const ClosedInterval(this.lower, this.upper) : assert(lower <= upper, 'lower must not exceed upper');

  /// The unit range every fraction is expressed against.
  static const ClosedInterval unit = ClosedInterval(0, 1);

  final double lower;
  final double upper;

  double get width => upper - lower;

  bool get isEmpty => width == 0;

  /// True when [value] lies inside the range, endpoints included.
  bool contains(double value) => value >= lower && value <= upper;

  /// [value] forced into the range.
  ///
  /// A NaN stays NaN instead of becoming an endpoint: an unknown progress position must not be drawn as
  /// "at the start", which is what a clamp would report.
  double clamp(double value) => value.isNaN ? value : value.clamp(lower, upper).toDouble();

  /// The fraction of the width at which [value] sits, clamped to 0..1.
  ///
  /// A zero-width range answers 0: the position is undefined, and 0 is the value a layout can use without
  /// producing an infinite or NaN offset.
  double fractionOf(double value) {
    if (isEmpty) {
      return 0;
    }
    return ((value - lower) / width).clamp(0.0, 1.0).toDouble();
  }

  /// The point [fraction] of the way across the range.
  double pointAt(double fraction) => lower + width * fraction.clamp(0.0, 1.0);

  @override
  bool operator ==(Object other) => other is ClosedInterval && other.lower == lower && other.upper == upper;

  @override
  int get hashCode => Object.hash(lower, upper);

  @override
  String toString() => 'ClosedInterval($lower..$upper)';
}
