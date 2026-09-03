import 'dart:ui';

class EmojiRenderer {
  const EmojiRenderer();

  void drawImage(Canvas canvas, Image image, Rect dst) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      Paint(),
    );
  }
}
