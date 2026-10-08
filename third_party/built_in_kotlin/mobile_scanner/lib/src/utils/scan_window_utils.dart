import 'dart:math';

import 'package:flutter/rendering.dart';

/// A utility class for calculating scan window sizes.
final class ScanWindowUtils {
  /// Calculate the scaling ratios for width and height
  /// to fit the provided [cameraPreviewSize] into the specified [size],
  /// based on the specified [boxFit].
  ///
  /// Returns a record containing the width and height scaling ratios.
  static ({double widthRatio, double heightRatio}) calculateBoxFitRatio({
    required BoxFit boxFit,
    required Size cameraPreviewSize,
    required Size size,
  }) {
    if (cameraPreviewSize.width <= 0 ||
        cameraPreviewSize.height <= 0 ||
        size.width <= 0 ||
        size.height <= 0) {
      return (widthRatio: 1.0, heightRatio: 1.0);
    }

    final widthRatio = size.width / cameraPreviewSize.width;
    final heightRatio = size.height / cameraPreviewSize.height;

    switch (boxFit) {
      case BoxFit.fill:
        // Stretch to fill the large box without maintaining aspect ratio.
        return (widthRatio: widthRatio, heightRatio: heightRatio);

      case BoxFit.contain:
        // Maintain aspect ratio,
        // ensure the content fits entirely within the large box.
        final double ratio = min(widthRatio, heightRatio);
        return (widthRatio: ratio, heightRatio: ratio);

      case BoxFit.cover:
        // Maintain aspect ratio, ensure the content fully covers the large box.
        final double ratio = max(widthRatio, heightRatio);
        return (widthRatio: ratio, heightRatio: ratio);

      case BoxFit.fitWidth:
        // Maintain aspect ratio, ensure the width matches the large box.
        return (widthRatio: widthRatio, heightRatio: widthRatio);

      case BoxFit.fitHeight:
        // Maintain aspect ratio, ensure the height matches the large box.
        return (widthRatio: heightRatio, heightRatio: heightRatio);

      case BoxFit.none:
        return (widthRatio: 1.0, heightRatio: 1.0);

      case BoxFit.scaleDown:
        // If the content is larger than the large box, scale down to fit.
        // Otherwise, no scaling is needed.
        final ratio = min(1, min(widthRatio, heightRatio)).toDouble();
        return (widthRatio: ratio, heightRatio: ratio);
    }
  }

  /// Calculate the scan window rectangle relative to the texture size.
  ///
  /// The [scanWindow] rectangle will be relative and scaled to [widgetSize],
  /// not [textureSize]. Depending on the given [fit],
  /// the [scanWindow] can partially overlap the [textureSize], or not at all.
  ///
  /// Due to using [BoxFit] the content will always be centered on its parent,
  /// which enables converting the rectangle to be relative to the texture.
  ///
  /// Because the size of the actual texture and the size of the texture in
  /// widget-space can be different, calculate the size of the scan window in
  /// percentages, rather than pixels.
  ///
  /// Returns a [Rect] that represents the position and size of the scan window
  /// in the texture.
  static Rect calculateScanWindowRelativeToTextureInPercentage(
    BoxFit fit,
    Rect scanWindow, {
    required Size textureSize,
    required Size widgetSize,
  }) {
    // Convert the texture size to a size in widget-space, with the box fit
    // applied.
    final fittedTextureSize = applyBoxFit(fit, textureSize, widgetSize);

    // Get the correct scaling values depending on the given BoxFit mode
    var sx = fittedTextureSize.destination.width / textureSize.width;
    var sy = fittedTextureSize.destination.height / textureSize.height;

    switch (fit) {
      case BoxFit.fill:
        // No-op, just use sx and sy.
        break;
      case BoxFit.contain:
        final double s = min(sx, sy);
        sx = s;
        sy = s;
      case BoxFit.cover:
        final double s = max(sx, sy);
        sx = s;
        sy = s;
      case BoxFit.fitWidth:
        sy = sx;
      case BoxFit.fitHeight:
        sx = sy;
      case BoxFit.none:
        sx = 1.0;
        sy = 1.0;
      case BoxFit.scaleDown:
        final double s = min(sx, sy);
        sx = s;
        sy = s;
    }

    // Fit the texture size to the widget rectangle given by the scaling values
    // above.
    final textureWindow = Alignment.center.inscribe(
      Size(textureSize.width * sx, textureSize.height * sy),
      Rect.fromLTWH(0, 0, widgetSize.width, widgetSize.height),
    );

    // Transform the scan window from widget coordinates to texture coordinates.
    final scanWindowInTexSpace = Rect.fromLTRB(
      (1 / sx) * (scanWindow.left - textureWindow.left),
      (1 / sy) * (scanWindow.top - textureWindow.top),
      (1 / sx) * (scanWindow.right - textureWindow.left),
      (1 / sy) * (scanWindow.bottom - textureWindow.top),
    );

    // Clip the scan window in texture coordinates with the texture bounds.
    // This prevents percentages outside the range [0; 1].
    final clippedScanWndInTexSpace = scanWindowInTexSpace.intersect(
      Rect.fromLTWH(0, 0, textureSize.width, textureSize.height),
    );

    // Compute relative rectangle coordinates,
    // with respect to the texture size, i.e. scan image.
    final percentageLeft = clippedScanWndInTexSpace.left / textureSize.width;
    final percentageTop = clippedScanWndInTexSpace.top / textureSize.height;
    final percentageRight = clippedScanWndInTexSpace.right / textureSize.width;
    final percentageBottom =
        clippedScanWndInTexSpace.bottom / textureSize.height;

    // This rectangle can be used to cut out a rectangle of the scan image.
    return Rect.fromLTRB(
      percentageLeft,
      percentageTop,
      percentageRight,
      percentageBottom,
    );
  }
}
