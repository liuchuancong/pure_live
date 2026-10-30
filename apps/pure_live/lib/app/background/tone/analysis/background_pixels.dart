import 'dart:typed_data' show Uint8List;
import 'dart:ui' show Color;

import 'package:pure_live/app/background/tone/analysis/background_luminance.dart';
import 'package:pure_live/app/background/tone/analysis/background_models.dart';
import 'package:pure_live/app/background/tone/analysis/background_regions.dart';

/// Measures straight-alpha RGBA pixels: luminance profile, 3×3 regions and a
/// representative colour.
///
/// The pixels are expected in `ImageByteFormat.rawStraightRgba` order. A
/// translucent pixel is composited over [underlay] first, because that is what
/// the page will show; measuring the uncomposited colour would report a dark
/// PNG as bright.
///
/// The palette's dominant colour is filled in later, by the caller that owns
/// the decoded image.
BackgroundAnalysisResult backgroundAnalyzeRgba({
  required Uint8List rgba,
  required int width,
  required int height,
  required Color underlay,
  BackgroundSampleSource source = BackgroundSampleSource.image,
}) {
  if (width <= 0 || height <= 0 || rgba.length < width * height * 4) {
    final luma = relativeLuminanceOf(underlay);
    return BackgroundAnalysisResult(
      source: source,
      dominant: underlay,
      representative: underlay,
      profile: backgroundProfileOf([luma]),
      regions: backgroundRegionsOf(width: 1, height: 1, lumas: [luma], colors: [underlay]),
    );
  }

  final colors = <Color>[];
  final lumas = <double>[];
  final pixelCount = width * height;
  for (var index = 0; index < pixelCount; index++) {
    final offset = index * 4;
    final alpha = rgba[offset + 3] / 255;
    final pixel = Color.from(
      alpha: alpha,
      red: rgba[offset] / 255,
      green: rgba[offset + 1] / 255,
      blue: rgba[offset + 2] / 255,
    );
    final composited = alpha >= 1
        ? pixel
        : alpha <= 0
        ? underlay
        : Color.alphaBlend(pixel, underlay);
    colors.add(composited);
    lumas.add(relativeLuminanceOf(composited));
  }

  final representative = averageColorOf(colors);
  return BackgroundAnalysisResult(
    source: source,
    dominant: representative,
    representative: representative,
    profile: backgroundProfileOf(lumas),
    regions: backgroundRegionsOf(width: width, height: height, lumas: lumas, colors: colors),
  );
}
