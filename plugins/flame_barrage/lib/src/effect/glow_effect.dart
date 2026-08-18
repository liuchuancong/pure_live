import 'dart:ui' as ui;

class GlowEffect {
  const GlowEffect({this.glowColor = const ui.Color(0xFFFFD700), this.blurRadius = 8.0});

  final ui.Color glowColor;
  final double blurRadius;

  ui.Paint createGlowPaint() {
    return ui.Paint()
      ..color = glowColor
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.outer, blurRadius)
      ..isAntiAlias = true;
  }
}
