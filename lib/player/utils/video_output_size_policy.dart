import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Chooses the smallest native video texture that fully covers the visible
/// viewport without upscaling beyond the decoded source dimensions.
Size calculateVideoOutputSize({
  required Size logicalViewport,
  required double devicePixelRatio,
  int? sourceWidth,
  int? sourceHeight,
}) {
  if (!logicalViewport.width.isFinite ||
      !logicalViewport.height.isFinite ||
      logicalViewport.isEmpty ||
      !devicePixelRatio.isFinite ||
      devicePixelRatio <= 0) {
    return Size.zero;
  }

  final viewportWidth = logicalViewport.width * devicePixelRatio;
  final viewportHeight = logicalViewport.height * devicePixelRatio;
  final validSource =
      sourceWidth != null && sourceWidth > 0 && sourceHeight != null && sourceHeight > 0;
  // Use a conservative 1080p provisional source before mpv publishes video
  // parameters. It is replaced immediately when the real dimensions arrive.
  final source = validSource
      ? Size(sourceWidth.toDouble(), sourceHeight.toDouble())
      : const Size(1920, 1080);
  final scale = math.min(
    1.0,
    math.min(viewportWidth / source.width, viewportHeight / source.height),
  );

  int evenPixel(double value) {
    final rounded = math.max(2, value.round());
    return rounded.isEven ? rounded : rounded + 1;
  }

  return Size(
    evenPixel(source.width * scale).toDouble(),
    evenPixel(source.height * scale).toDouble(),
  );
}
