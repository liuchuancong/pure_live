import 'package:qr/qr.dart';
import 'package:flutter/material.dart';

class QrCodeWidget extends StatelessWidget {
  const QrCodeWidget({
    super.key,
    required this.data,
    this.size = 180,
    this.padding = const EdgeInsets.all(12),
    this.backgroundColor = Colors.white,
    this.foregroundColor = Colors.black,
  });

  final String data;
  final double size;
  final EdgeInsets padding;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final qrCode = QrCode(payload: QrPayload.fromString(data), errorCorrectLevel: QrErrorCorrectLevel.low);

    final qrImage = QrImage(qrCode);

    return Container(
      width: size,
      height: size,
      padding: padding,
      color: backgroundColor,
      child: CustomPaint(
        painter: _QrCodePainter(qrImage: qrImage, foregroundColor: foregroundColor),
        size: Size.infinite,
      ),
    );
  }
}

class _QrCodePainter extends CustomPainter {
  const _QrCodePainter({required this.qrImage, required this.foregroundColor});

  final QrImage qrImage;
  final Color foregroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final moduleCount = qrImage.moduleCount;
    final moduleSize = size.width / moduleCount;

    final paint = Paint()
      ..color = foregroundColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;

    for (var row = 0; row < moduleCount; row++) {
      for (var col = 0; col < moduleCount; col++) {
        if (qrImage.isDark(row, col)) {
          canvas.drawRect(
            Rect.fromLTRB(col * moduleSize, row * moduleSize, (col + 1) * moduleSize, (row + 1) * moduleSize),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrCodePainter oldDelegate) {
    return oldDelegate.qrImage != qrImage || oldDelegate.foregroundColor != foregroundColor;
  }
}
