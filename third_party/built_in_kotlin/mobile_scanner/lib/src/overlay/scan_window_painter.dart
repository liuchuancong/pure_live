import 'package:flutter/material.dart';

/// This class represents a [CustomPainter] that draws a [scanWindow] rectangle.
class ScanWindowPainter extends CustomPainter {
  /// Construct a new [ScanWindowPainter] instance.
  const ScanWindowPainter({
    required this.borderColor,
    required this.borderRadius,
    required this.borderStrokeCap,
    required this.borderStrokeJoin,
    required this.borderStyle,
    required this.borderWidth,
    required this.color,
    required this.scanWindow,
  });

  /// The color for the scan window border.
  final Color borderColor;

  /// The border radius for the scan window and its border.
  final BorderRadius borderRadius;

  /// The stroke cap for the border around the scan window.
  final StrokeCap borderStrokeCap;

  /// The stroke join for the border around the scan window.
  final StrokeJoin borderStrokeJoin;

  /// The style for the border around the scan window.
  final PaintingStyle borderStyle;

  /// The width for the border around the scan window.
  final double borderWidth;

  /// The color for the scan window box.
  final Color color;

  /// The rectangle that defines the scan window.
  final Rect scanWindow;

  @override
  void paint(Canvas canvas, Size size) {
    if (scanWindow.isEmpty || scanWindow.isInfinite) {
      return;
    }

    // The cutout rect depends on the border radius.
    final cutoutRect =
        borderRadius == BorderRadius.zero
            ? RRect.fromRectAndCorners(scanWindow)
            : RRect.fromRectAndCorners(
              scanWindow,
              topLeft: borderRadius.topLeft,
              topRight: borderRadius.topRight,
              bottomLeft: borderRadius.bottomLeft,
              bottomRight: borderRadius.bottomRight,
            );

    final borderPaint =
        Paint()
          ..color = borderColor
          ..style = borderStyle
          ..strokeWidth = borderWidth
          ..strokeCap = borderStrokeCap
          ..strokeJoin = borderStrokeJoin;

    // Use a layer so that BlendMode.clear punches a transparent hole through
    // the dark overlay. This works correctly on all platforms including web,
    // where Path.combine(PathOperation.difference) may not render correctly.
    canvas
      ..saveLayer(Offset.zero & size, Paint())
      ..drawRect(
        Offset.zero & size,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      )
      ..drawRRect(cutoutRect, Paint()..blendMode = BlendMode.clear)
      ..restore()
      // Draw the border around the cutout area.
      ..drawRRect(cutoutRect, borderPaint);
  }

  @override
  bool shouldRepaint(ScanWindowPainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow ||
        oldDelegate.color != color ||
        oldDelegate.borderRadius != borderRadius;
  }
}
