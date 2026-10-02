import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// High-contrast QR rendering for the current `qr` matrix API.
class BilibiliLoginQrCode extends StatelessWidget {
  const BilibiliLoginQrCode({required this.data, required this.size, super.key});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = QrImage(QrCode(payload: QrPayload.fromString(data), errorCorrectLevel: QrErrorCorrectLevel.low));

    return SizedBox.square(
      key: const ValueKey('bilibili-login-qr-code'),
      dimension: size,
      child: ColoredBox(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: CustomPaint(painter: _QrMatrixPainter(image)),
        ),
      ),
    );
  }
}

class _QrMatrixPainter extends CustomPainter {
  const _QrMatrixPainter(this.image);

  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    final moduleWidth = size.width / image.moduleCount;
    final moduleHeight = size.height / image.moduleCount;
    final dark = Paint()
      ..color = Colors.black
      ..isAntiAlias = false;

    for (var row = 0; row < image.moduleCount; row++) {
      for (var col = 0; col < image.moduleCount; col++) {
        if (!image.isDark(row, col)) continue;
        canvas.drawRect(
          Rect.fromLTRB(col * moduleWidth, row * moduleHeight, (col + 1) * moduleWidth, (row + 1) * moduleHeight),
          dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrMatrixPainter oldDelegate) => !identical(image, oldDelegate.image);
}
