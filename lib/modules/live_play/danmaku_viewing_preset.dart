class DanmakuViewingPreset {
  const DanmakuViewingPreset({
    required this.id,
    required this.labelKey,
    required this.area,
    required this.top,
    required this.bottom,
    required this.speed,
    required this.fontSize,
    required this.fontWeight,
    required this.fontBorder,
    required this.opacity,
    required this.stroke,
  });

  final String id;
  final String labelKey;
  final double area;
  final double top;
  final double bottom;
  final double speed;
  final double fontSize;
  final int fontWeight;
  final double fontBorder;
  final double opacity;
  final bool stroke;

  static const values = <DanmakuViewingPreset>[
    DanmakuViewingPreset(
      id: 'best',
      labelKey: 'danmaku_template_best',
      area: 0.20,
      top: 0,
      bottom: 0,
      speed: 118,
      fontSize: 16,
      fontWeight: 500,
      fontBorder: 1.5,
      opacity: 0.92,
      stroke: true,
    ),
    DanmakuViewingPreset(
      id: 'comfort',
      labelKey: 'danmaku_template_comfort',
      area: 0.35,
      top: 0,
      bottom: 0,
      speed: 105,
      fontSize: 17,
      fontWeight: 500,
      fontBorder: 1.5,
      opacity: 0.90,
      stroke: true,
    ),
    DanmakuViewingPreset(
      id: 'dense',
      labelKey: 'danmaku_template_dense',
      area: 0.55,
      top: 0,
      bottom: 0,
      speed: 138,
      fontSize: 15,
      fontWeight: 500,
      fontBorder: 1.2,
      opacity: 0.88,
      stroke: true,
    ),
    DanmakuViewingPreset(
      id: 'default',
      labelKey: 'reset',
      area: 1,
      top: 0,
      bottom: 0,
      speed: 120,
      fontWeight: 500,
      fontSize: 16,
      fontBorder: 1.5,
      opacity: 1,
      stroke: true,
    ),
  ];

  bool matches({
    required double area,
    required double top,
    required double bottom,
    required double speed,
    required double fontSize,
    required int fontWeight,
    required double fontBorder,
    required double opacity,
    required bool stroke,
    required bool autoFps,
  }) {
    bool close(double left, double right) => (left - right).abs() < 0.001;
    return autoFps &&
        stroke == this.stroke &&
        fontWeight == this.fontWeight &&
        close(area, this.area) &&
        close(top, this.top) &&
        close(bottom, this.bottom) &&
        close(speed, this.speed) &&
        close(fontSize, this.fontSize) &&
        close(fontBorder, this.fontBorder) &&
        close(opacity, this.opacity);
  }
}
