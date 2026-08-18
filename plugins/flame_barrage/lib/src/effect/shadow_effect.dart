import 'dart:ui' as ui;

class ShadowEffect {
  const ShadowEffect({
    this.shadowColor = const ui.Color(0xFF000000),
    this.offset = const ui.Offset(1.5, 1.5),
    this.blurRadius = 2.0,
  });

  final ui.Color shadowColor;
  final ui.Offset offset;
  final double blurRadius;

  ui.Shadow toShadow() {
    return ui.Shadow(color: shadowColor, offset: offset, blurRadius: blurRadius);
  }

  List<ui.Shadow> createMultiShadows() {
    return [
      ui.Shadow(color: shadowColor, offset: ui.Offset(-offset.dx, -offset.dy), blurRadius: blurRadius),
      ui.Shadow(color: shadowColor, offset: ui.Offset(offset.dx, -offset.dy), blurRadius: blurRadius),
      ui.Shadow(color: shadowColor, offset: ui.Offset(-offset.dx, offset.dy), blurRadius: blurRadius),
      ui.Shadow(color: shadowColor, offset: ui.Offset(offset.dx, offset.dy), blurRadius: blurRadius),
    ];
  }
}
