import 'dart:ui';

class SpriteSheet {
  const SpriteSheet({required this.imageWidth, required this.imageHeight, required this.rows, required this.columns});

  final double imageWidth;
  final double imageHeight;
  final int rows;
  final int columns;

  double get srcWidth => imageWidth / columns;
  double get srcHeight => imageHeight / rows;

  Rect getSpriteRect(int index) {
    if (index < 0 || index >= rows * columns) {
      return Rect.zero;
    }

    final int row = index ~/ columns;
    final int col = index % columns;

    final double left = col * srcWidth;
    final double top = row * srcHeight;

    return Rect.fromLTWH(left, top, srcWidth, srcHeight);
  }

  List<Rect> generateAllRects() {
    final rects = <Rect>[];
    final total = rows * columns;
    for (int i = 0; i < total; i++) {
      rects.add(getSpriteRect(i));
    }
    return rects;
  }
}
