import 'dart:math' as math;
import 'dart:ui' show Color, Rect;

import 'package:pure_live/app/background/tone/analysis/background_luminance.dart';
import 'package:pure_live/app/background/tone/analysis/background_models.dart';

/// Rows and columns of the wallpaper's local grid: nine cells are enough to
/// notice a bright corner without turning the analysis into a region map.
const int kBackgroundRegionGrid = 3;

/// Cells of the grid in row-major order.
const int kBackgroundRegionCount = kBackgroundRegionGrid * kBackgroundRegionGrid;

/// The normalized rectangle of [index], row-major.
Rect backgroundRegionRect(int index) {
  final row = index ~/ kBackgroundRegionGrid;
  final column = index % kBackgroundRegionGrid;
  const size = 1 / kBackgroundRegionGrid;
  return Rect.fromLTWH(column * size, row * size, size, size);
}

/// Splits [lumas] and [colors] into the 3×3 grid and measures each cell.
///
/// Both lists are row-major and the same length as `width * height`. A surface
/// narrower than three pixels has fewer pixels than cells; every cell then
/// samples the nearest pixel rather than coming back empty.
List<ImageRegionResult> backgroundRegionsOf({
  required int width,
  required int height,
  required List<double> lumas,
  required List<Color> colors,
}) {
  assert(width > 0 && height > 0, 'A sample needs a positive size.');
  assert(lumas.length == width * height, 'One luminance per pixel.');
  assert(colors.length == lumas.length, 'One colour per luminance.');

  final regions = <ImageRegionResult>[];
  for (var index = 0; index < kBackgroundRegionCount; index++) {
    final row = index ~/ kBackgroundRegionGrid;
    final column = index % kBackgroundRegionGrid;
    final startX = column * width ~/ kBackgroundRegionGrid;
    final endX = math.min(width, math.max(startX + 1, (column + 1) * width ~/ kBackgroundRegionGrid));
    final startY = row * height ~/ kBackgroundRegionGrid;
    final endY = math.min(height, math.max(startY + 1, (row + 1) * height ~/ kBackgroundRegionGrid));

    final regionLumas = <double>[];
    final regionColors = <Color>[];
    for (var y = startY; y < endY; y++) {
      for (var x = startX; x < endX; x++) {
        final offset = y * width + x;
        regionLumas.add(lumas[offset]);
        regionColors.add(colors[offset]);
      }
    }
    final average = averageColorOf(regionColors);
    final ink = backgroundInkOn(average);
    regions.add(
      ImageRegionResult(
        index: index,
        rect: backgroundRegionRect(index),
        color: average,
        profile: backgroundProfileOf(regionLumas),
        dark: ink.dark,
        ink: ink.color,
        contrast: ink.contrast,
      ),
    );
  }
  return regions;
}
