import 'dart:ui' show Color;

import 'package:pure_live/app/background/library/background_presets.dart' show gradientAlignments;
import 'package:pure_live/app/background/tone/analysis/background_luminance.dart';
import 'package:pure_live/app/background/tone/analysis/background_models.dart';
import 'package:pure_live/app/background/tone/analysis/background_regions.dart';

/// Positions sampled along the gradient line for the overall profile.
const int _kGradientSamples = 24;

/// Side of the grid sampled for the 3×3 regions; three samples per cell.
const int _kGradientGrid = 9;

/// Measures a gradient the way the painter will show it: along its own angle,
/// its own stops and with its translucent stops composited over [underlay].
///
/// The old average of the stop colours ignored all three, so a gradient from
/// transparent black to white was scored as a mid gray that never appears.
BackgroundAnalysisResult backgroundAnalyzeGradient({
  required List<Color> colors,
  required List<double>? stops,
  required int deg,
  required Color underlay,
}) {
  final effective = colors.isEmpty ? <Color>[underlay] : colors;
  final positions = _stopsOf(effective.length, stops);

  final (begin, end) = gradientAlignments(deg);
  final startX = (begin.x + 1) / 2;
  final startY = (begin.y + 1) / 2;
  final endX = (end.x + 1) / 2;
  final endY = (end.y + 1) / 2;
  final dx = endX - startX;
  final dy = endY - startY;
  final lengthSquared = dx * dx + dy * dy;

  Color colorAt(double x, double y) {
    final stop = lengthSquared <= 0 ? 0.0 : (((x - startX) * dx + (y - startY) * dy) / lengthSquared).clamp(0.0, 1.0);
    return _compositeOver(_colorAt(effective, positions, stop), underlay);
  }

  final samples = <Color>[
    for (var index = 0; index < _kGradientSamples; index++)
      colorAt(startX + dx * _step(index, _kGradientSamples), startY + dy * _step(index, _kGradientSamples)),
  ];
  final gridColors = <Color>[
    for (var row = 0; row < _kGradientGrid; row++)
      for (var column = 0; column < _kGradientGrid; column++)
        colorAt(_step(column, _kGradientGrid), _step(row, _kGradientGrid)),
  ];
  final representative = averageColorOf(samples);
  return BackgroundAnalysisResult(
    source: BackgroundSampleSource.gradient,
    dominant: representative,
    representative: representative,
    profile: backgroundProfileOf([for (final color in samples) relativeLuminanceOf(color)]),
    regions: backgroundRegionsOf(
      width: _kGradientGrid,
      height: _kGradientGrid,
      lumas: [for (final color in gridColors) relativeLuminanceOf(color)],
      colors: gridColors,
    ),
  );
}

/// The position of [index] across [count] evenly spaced samples, 0 to 1.
double _step(int index, int count) => count <= 1 ? 0 : index / (count - 1);

/// The gradient's stop positions, made non-decreasing and clamped.
List<double> _stopsOf(int count, List<double>? stops) {
  if (stops == null || stops.length != count) {
    return [for (var index = 0; index < count; index++) _step(index, count)];
  }
  final positions = <double>[for (final stop in stops) stop.clamp(0.0, 1.0)];
  for (var index = 1; index < positions.length; index++) {
    if (positions[index] < positions[index - 1]) positions[index] = positions[index - 1];
  }
  return positions;
}

/// The colour at [stop] along [colors], interpolated in the same straight
/// sRGB the gradient painter uses.
Color _colorAt(List<Color> colors, List<double> positions, double stop) {
  if (colors.length == 1) return colors.first;
  if (stop <= positions.first) return colors.first;
  if (stop >= positions.last) return colors.last;
  var index = 0;
  while (index < positions.length - 2 && stop > positions[index + 1]) {
    index++;
  }
  final span = positions[index + 1] - positions[index];
  final local = span <= 0 ? 0.0 : ((stop - positions[index]) / span).clamp(0.0, 1.0);
  return _lerpColor(colors[index], colors[index + 1], local);
}

/// Interpolates in premultiplied alpha, the way the gradient shader does.
///
/// A straight-channel lerp fades a transparent stop's colour as it fades its
/// alpha, so a transparent-to-red gradient would never reach red. The shader
/// keeps the colour and fades only the coverage; measuring the same way keeps
/// the analysis faithful to what is on screen.
Color _lerpColor(Color from, Color to, double t) {
  final alpha = from.a + (to.a - from.a) * t;
  if (alpha <= 0) return const Color(0x00000000);
  double channel(double start, double end) => (start * from.a * (1 - t) + end * to.a * t) / alpha;
  return Color.from(
    alpha: alpha,
    red: channel(from.r, to.r),
    green: channel(from.g, to.g),
    blue: channel(from.b, to.b),
  );
}

/// [color] over [underlay]; a fully opaque or transparent colour skips the
/// blend so its exact value survives.
Color _compositeOver(Color color, Color underlay) {
  if (color.a >= 1) return color;
  if (color.a <= 0) return underlay;
  return Color.alphaBlend(color, underlay);
}
