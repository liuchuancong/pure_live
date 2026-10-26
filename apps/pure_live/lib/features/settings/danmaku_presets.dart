import 'package:pure_live/features/settings/danmaku_style_providers.dart'
    show DanmakuFrameRate, DanmakuFrameRateController, DanmakuStyle, DanmakuStyleController;

/// The reference's four viewing presets: one tap writes the look's nine
/// visual fields (area, both margins, speed, size, weight, border, opacity
/// and the outline switch) and leaves the rest — typeface, letter spacing,
/// same-screen cap, mass mode, pure-text mode and the manual rate — alone.
/// Auto frame pacing is turned on, as in the reference.
enum DanmakuPreset {
  /// The top fifth, balanced.
  best(area: 0.20, speed: 118, fontSize: 16, opacity: 0.92),

  /// The top third, a little larger and slower.
  comfort(area: 0.35, speed: 105, fontSize: 17, opacity: 0.90),

  /// A little over half, smaller and faster.
  dense(area: 0.55, speed: 138, fontSize: 15, fontBorder: 1.2, opacity: 0.88),

  /// The whole picture at the designed defaults.
  full(area: 1, speed: 120, fontSize: 16, opacity: 1);

  DanmakuPreset({
    required this.area,
    required this.speed,
    required this.fontSize,
    required this.opacity,
    this.fontBorder = 1.5,
  });

  /// The reference keeps both margins at zero for every preset.
  static const double top = 0;

  /// The reference keeps both margins at zero for every preset.
  static const double bottom = 0;

  /// The reference's presets all use the regular weight.
  static const int fontWeight = 500;

  /// The reference's presets all keep the outline on.
  static const bool stroke = true;

  /// Display area, 0 to 1.
  final double area;

  /// Pixels per second.
  final double speed;

  /// Font size in pixels.
  final double fontSize;

  /// Outline width in pixels.
  final double fontBorder;

  /// Opacity, 0 to 1.
  final double opacity;

  /// Whether [style] and [frameRate] are this preset (the reference requires
  /// auto pacing and compares the numbers within a thousandth).
  bool matches(DanmakuStyle style, DanmakuFrameRate frameRate) {
    bool close(double left, double right) => (left - right).abs() < 0.001;
    return frameRate.autoFps &&
        style.showStroke == stroke &&
        style.fontWeight == fontWeight &&
        close(style.area, area) &&
        close(style.topMargin, top) &&
        close(style.bottomMargin, bottom) &&
        close(style.baseSpeed, speed) &&
        close(style.fontSize, fontSize) &&
        close(style.strokeWidth, fontBorder) &&
        close(style.opacity, opacity);
  }

  /// The preset the current look matches, if any.
  static DanmakuPreset? matching(DanmakuStyle style, DanmakuFrameRate frameRate) {
    for (final preset in values) {
      if (preset.matches(style, frameRate)) return preset;
    }
    return null;
  }

  /// Writes this preset into the live look, keeping [noEmoji], the manual
  /// [fps] and turning auto frame pacing on.
  Future<void> apply({
    required DanmakuStyleController style,
    required DanmakuFrameRateController frameRate,
    required bool noEmoji,
    required int fps,
  }) async {
    await style.applyTemplate(
      area: area,
      topMargin: top,
      bottomMargin: bottom,
      baseSpeed: speed,
      fontSize: fontSize,
      fontWeight: fontWeight,
      strokeWidth: fontBorder,
      opacity: opacity,
      showStroke: stroke,
      noEmoji: noEmoji,
    );
    await frameRate.applyTemplate(fps: fps, autoFps: true);
  }
}
