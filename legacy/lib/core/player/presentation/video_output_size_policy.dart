import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Chooses the smallest native video texture that fully covers the visible
/// viewport without upscaling beyond the decoded source dimensions.
Size calculateVideoOutputSize({
  required Size logicalViewport,
  required double devicePixelRatio,
  int? sourceWidth,
  int? sourceHeight,
  BoxFit fit = BoxFit.contain,
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
  final validSource = sourceWidth != null && sourceWidth > 0 && sourceHeight != null && sourceHeight > 0;
  // Use a conservative 1080p provisional source before mpv publishes video
  // parameters. It is replaced immediately when the real dimensions arrive.
  final source = validSource ? Size(sourceWidth.toDouble(), sourceHeight.toDouble()) : const Size(1920, 1080);
  final widthScale = viewportWidth / source.width;
  final heightScale = viewportHeight / source.height;
  // Keep the native texture at the source aspect ratio so Flutter remains the
  // sole owner of fitting/cropping. Use the fit's dominant axis to ensure the
  // fitted texture is never enlarged above the visible physical viewport.
  final requestedScale = switch (fit) {
    BoxFit.contain || BoxFit.scaleDown => math.min(widthScale, heightScale),
    BoxFit.cover || BoxFit.fill => math.max(widthScale, heightScale),
    BoxFit.fitWidth => widthScale,
    BoxFit.fitHeight => heightScale,
    BoxFit.none => 1.0,
  };
  final scale = math.min(1.0, requestedScale);

  int evenPixel(double value) {
    final rounded = math.max(2, value.round());
    return rounded.isEven ? rounded : rounded + 1;
  }

  return Size(evenPixel(source.width * scale).toDouble(), evenPixel(source.height * scale).toDouble());
}
