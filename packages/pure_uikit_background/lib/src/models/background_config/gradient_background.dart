part of 'background_config.dart';

/// A two-or-more-stop linear gradient background.
///
/// The gradient itself is validated at render time via Flutter's own
/// `LinearGradient` assertions; a compile-time `.length` check is not
/// const-evaluable and would prevent pages from declaring gradients as
/// `const`, so this class intentionally keeps the constructor const and
/// pushes the "at least two colors" check to the view.
@immutable
final class GradientBackground extends BackgroundConfig {
  /// Paints a linear gradient from [begin] to [end] using [colors].
  ///
  /// [colors] must contain at least two entries; the rendering layer
  /// raises a framework assertion otherwise. [stops] is optional and,
  /// when provided, must have the same length as [colors].
  const new({
    required this.colors,
    this.stops,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
    super.overlay,
  });

  /// The gradient color stops, in order.
  final List<Color> colors;

  /// Optional positions for each stop, all in `[0, 1]` and non-decreasing.
  final List<double>? stops;

  /// The starting alignment of the linear gradient.
  final AlignmentGeometry begin;

  /// The ending alignment of the linear gradient.
  final AlignmentGeometry end;
}
