import 'dart:ui' as ui;

class GradientEffect {
  const GradientEffect({required this.colors, this.stops});

  final List<ui.Color> colors;
  final List<double>? stops;

  ui.Paint createGradientPaint({required ui.Rect textBounds}) {
    final shader = ui.Gradient.linear(textBounds.topLeft, textBounds.bottomLeft, colors, stops);
    return ui.Paint()
      ..shader = shader
      ..isAntiAlias = true;
  }
}
