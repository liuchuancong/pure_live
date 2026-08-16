import 'dart:ui' as ui;

class StrokeEffect {
  const StrokeEffect({this.strokeColor = const ui.Color(0xFF000000), this.strokeWidth = 2.0});

  final ui.Color strokeColor;
  final double strokeWidth;

  ui.Paint createStrokePaint() {
    return ui.Paint()
      ..color = strokeColor
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = ui.StrokeJoin.round
      ..isAntiAlias = true;
  }
}
