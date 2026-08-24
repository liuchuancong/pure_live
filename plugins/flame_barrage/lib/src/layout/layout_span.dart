import 'dart:ui' as ui;

abstract class LayoutSpan {
  const LayoutSpan({required this.x, required this.y, required this.width, required this.height});

  final double x;
  final double y;
  final double width;
  final double height;

  void paint(ui.Canvas canvas);
}

class TextLayoutSpan extends LayoutSpan {
  const TextLayoutSpan({
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required this.text,
    required this.paragraph,
    this.strokeParagraph,
  });

  final String text;
  final ui.Paragraph paragraph;
  final ui.Paragraph? strokeParagraph;

  @override
  void paint(ui.Canvas canvas) {
    final currentStroke = strokeParagraph;
    if (currentStroke != null) {
      // The paragraph already contains a native stroked glyph path. Painting
      // four offset copies thickens semi-transparent edges unevenly and makes
      // CJK text look blurred on bright video frames.
      canvas.drawParagraph(currentStroke, ui.Offset(x, y));
    }
    canvas.drawParagraph(paragraph, ui.Offset(x, y));
  }
}
