import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// This widget represents an overlay that paints the bounding boxes of detected
/// barcodes.
class BarcodeOverlay extends StatefulWidget {
  /// Construct a new [BarcodeOverlay] instance.
  const BarcodeOverlay({
    required this.boxFit,
    required this.controller,
    super.key,
    this.color = const Color(0x4DF44336),
    this.style = PaintingStyle.fill,
  });

  /// The [BoxFit] to use when painting the barcode box.
  final BoxFit boxFit;

  /// The controller that provides the barcodes to display.
  final MobileScannerController controller;

  /// The color to use when painting the barcode box.
  ///
  /// Defaults to [Colors.red], with an opacity of 30%.
  final Color color;

  /// The style to use when painting the barcode box.
  ///
  /// Defaults to [PaintingStyle.fill].
  final PaintingStyle style;

  @override
  State<BarcodeOverlay> createState() => _BarcodeOverlayState();
}

class _BarcodeOverlayState extends State<BarcodeOverlay> {
  final _textPainter = TextPainter(
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  );

  DeviceOrientation? _lastOrientation;
  int _orientationResetKey = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant BarcodeOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _lastOrientation = null;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _textPainter.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final orientation = widget.controller.value.deviceOrientation;
    if (_lastOrientation != null && _lastOrientation != orientation) {
      setState(() {
        _orientationResetKey++;
      });
    }
    _lastOrientation = orientation;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.controller,
      builder: (context, value, child) {
        // Not ready.
        if (!value.isInitialized || !value.isRunning || value.error != null) {
          return const SizedBox();
        }

        return StreamBuilder<BarcodeCapture>(
          key: ValueKey(_orientationResetKey),
          stream: widget.controller.barcodes,
          builder: (context, snapshot) {
            final barcodeCapture = snapshot.data;

            // No barcode or preview size.
            if (barcodeCapture == null ||
                barcodeCapture.size.isEmpty ||
                barcodeCapture.barcodes.isEmpty) {
              return const SizedBox();
            }

            final overlays = <Widget>[
              for (final Barcode barcode in barcodeCapture.barcodes)
                if (!barcode.size.isEmpty && barcode.corners.isNotEmpty)
                  CustomPaint(
                    painter: BarcodePainter(
                      barcodeCorners: barcode.corners,
                      barcodeSize: barcode.size,
                      boxFit: widget.boxFit,
                      cameraPreviewSize: barcodeCapture.size,
                      color: widget.color,
                      style: widget.style,
                      barcodeValue: barcode.displayValue ?? '',
                      textPainter: _textPainter,
                      deviceOrientation: value.deviceOrientation,
                    ),
                  ),
            ];

            return Stack(fit: StackFit.expand, children: overlays);
          },
        );
      },
    );
  }
}
