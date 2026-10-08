import 'dart:math' as math;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/src/utils/scan_window_utils.dart';

/// Calculate the scaling ratios for width and height to fit the provided
/// [cameraPreviewSize] into the specified [size],
/// based on the specified [boxFit].
///
/// Returns a record containing the width and height scaling ratios.
@Deprecated('Use ScanWindowUtils.calculateBoxFitRatio instead.')
({double widthRatio, double heightRatio}) calculateBoxFitRatio(
  BoxFit boxFit,
  Size cameraPreviewSize,
  Size size,
) {
  // TODO(navaronbracke): remove the deprecated method in the next release
  return ScanWindowUtils.calculateBoxFitRatio(
    boxFit: boxFit,
    cameraPreviewSize: cameraPreviewSize,
    size: size,
  );
}

/// A [CustomPainter] that draws the barcode as an outlined barcode box with
/// rounded corners and a displayed value.
class BarcodePainter extends CustomPainter {
  /// Construct a new [BarcodePainter] instance.
  const BarcodePainter({
    required this.barcodeCorners,
    required this.barcodeSize,
    required this.barcodeValue,
    required this.boxFit,
    required this.cameraPreviewSize,
    required this.color,
    required this.style,
    required this.textPainter,
    required this.deviceOrientation,
    this.strokeWidth = 4.0,
  });

  /// The corners of the barcode.
  final List<Offset> barcodeCorners;

  /// The size of the barcode.
  final Size barcodeSize;

  /// The barcode value to display inside the overlay.
  final String barcodeValue;

  /// The BoxFit mode for scaling the barcode bounding box.
  final BoxFit boxFit;

  /// The camera preview size.
  final Size cameraPreviewSize;

  /// The color of the outline.
  final Color color;

  /// The drawing style (stroke/fill).
  final PaintingStyle style;

  /// The painter which paints the text object in the overlay.
  final TextPainter textPainter;

  /// The width of the border.
  final double strokeWidth;

  /// The orientation of the device.
  final DeviceOrientation deviceOrientation;

  @override
  void paint(Canvas canvas, Size size) {
    if (barcodeCorners.length < 4 ||
        barcodeSize.isEmpty ||
        cameraPreviewSize.isEmpty) {
      return;
    }

    final isLandscape =
        deviceOrientation == DeviceOrientation.landscapeLeft ||
        deviceOrientation == DeviceOrientation.landscapeRight;

    final adjustedCameraPreviewSize =
        isLandscape ? cameraPreviewSize.flipped : cameraPreviewSize;

    final ratios = ScanWindowUtils.calculateBoxFitRatio(
      boxFit: boxFit,
      cameraPreviewSize: adjustedCameraPreviewSize,
      size: size,
    );

    final horizontalPadding =
        (adjustedCameraPreviewSize.width * ratios.widthRatio - size.width) / 2;
    final verticalPadding =
        (adjustedCameraPreviewSize.height * ratios.heightRatio - size.height) /
        2;

    final adjustedOffset = <Offset>[
      for (final offset in barcodeCorners)
        Offset(
          offset.dx * ratios.widthRatio - horizontalPadding,
          offset.dy * ratios.heightRatio - verticalPadding,
        ),
    ];

    if (adjustedOffset.length < 4) return;

    // Draw the rotated rectangle
    final path = Path()..addPolygon(adjustedOffset, true);

    final paint =
        Paint()
          ..color = color
          ..style = style
          ..strokeWidth = strokeWidth;

    canvas.drawPath(path, paint);

    // Find center point of the barcode
    final centerX = (adjustedOffset[0].dx + adjustedOffset[2].dx) / 2;
    final centerY = (adjustedOffset[0].dy + adjustedOffset[2].dy) / 2;
    final center = Offset(centerX, centerY);

    // Calculate rotation angle
    final angle = math.atan2(
      adjustedOffset[1].dy - adjustedOffset[0].dy,
      adjustedOffset[1].dx - adjustedOffset[0].dx,
    );

    // Set a smaller font size with auto-resizing logic
    final textSize =
        (barcodeSize.width * ratios.widthRatio) *
        0.08; // Scales with barcode size
    const double minTextSize = 6; // Minimum readable size
    const double maxTextSize = 12; // Maximum size
    final finalTextSize = textSize.clamp(minTextSize, maxTextSize);

    // Draw barcode value inside the overlay with rotation
    final textSpan = TextSpan(
      text: barcodeValue,
      style: TextStyle(
        color: Colors.black, // Ensuring black text
        fontSize: finalTextSize,
        fontWeight: FontWeight.bold,
      ),
    );

    textPainter.text = textSpan;
    textPainter.layout(maxWidth: barcodeSize.width * ratios.widthRatio * 0.6);

    final textWidth = textPainter.width;
    final textHeight = textPainter.height;

    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(angle) // Rotate the text to match the barcode
      ..translate(-center.dx, -center.dy);

    final textRect = Rect.fromCenter(
      center: center,
      width: textWidth * 1.1,
      height: textHeight * 1.1,
    );

    final textBackground = RRect.fromRectAndRadius(
      textRect,
      const Radius.circular(6),
    );

    final textBgPaint = Paint()..color = Colors.white.withValues(alpha: 0.8);
    canvas.drawRRect(textBackground, textBgPaint);

    textPainter.paint(
      canvas,
      Offset(center.dx - textWidth / 2, center.dy - textHeight / 2),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(BarcodePainter oldDelegate) {
    const listEquality = ListEquality<Offset>();

    return !listEquality.equals(oldDelegate.barcodeCorners, barcodeCorners) ||
        oldDelegate.barcodeSize != barcodeSize ||
        oldDelegate.boxFit != boxFit ||
        oldDelegate.cameraPreviewSize != cameraPreviewSize ||
        oldDelegate.color != color ||
        oldDelegate.style != style ||
        oldDelegate.barcodeValue != barcodeValue ||
        oldDelegate.deviceOrientation != deviceOrientation;
  }
}
