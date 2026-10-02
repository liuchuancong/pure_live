import 'dart:math' as math;

/// Geometry shared by the live compact danmaku renderer and its settings
/// preview.
///
/// Compact mode scales distance as well as text so a message takes roughly the
/// same time to cross PiP windows of different widths. Keeping these values in
/// one policy also prevents the preview from advertising denser lanes than the
/// barrage engine can allocate.
final class CompactDanmakuMetrics {
  const CompactDanmakuMetrics._({
    required this.scale,
    required this.fontSize,
    required this.baseSpeed,
    required this.trackHeight,
    required this.emojiSize,
    required this.overlapSafeGap,
  });

  static const double referenceWidth = 350;

  factory CompactDanmakuMetrics.resolve({
    required double width,
    required bool autoScale,
    required double configuredFontSize,
    required double configuredSpeed,
  }) {
    final safeWidth = width.isFinite && width > 0 ? width : referenceWidth;
    final scale = autoScale ? (safeWidth / referenceWidth).clamp(0.65, 1.0).toDouble() : 1.0;
    final fontSize = configuredFontSize * scale;

    // flame_barrage allocates tracks with at least fontSize + 10, but paints
    // their Y offsets with the configured trackHeight. Supplying that same
    // minimum keeps allocation and rendering geometry identical.
    final trackHeight = math.max(fontSize * 1.8, fontSize + 10).clamp(18.0, 44.0).toDouble();

    return CompactDanmakuMetrics._(
      scale: scale,
      fontSize: fontSize,
      baseSpeed: configuredSpeed * scale,
      trackHeight: trackHeight,
      emojiSize: (fontSize * 1.35).clamp(14.0, 32.0).toDouble(),
      overlapSafeGap: (fontSize * 1.5).clamp(16.0, 40.0).toDouble(),
    );
  }

  final double scale;
  final double fontSize;
  final double baseSpeed;
  final double trackHeight;
  final double emojiSize;
  final double overlapSafeGap;
}

/// Typography shared by the compact renderer and the settings preview.
///
/// PiP has independent size and weight controls, while the selected danmaku
/// font and outline remain global. Resolving those inherited values in one
/// place keeps the preview and the live compact surface on the same contract.
final class CompactDanmakuTypography {
  const CompactDanmakuTypography._({
    required this.fontWeight,
    required this.fontFamily,
    required this.showStroke,
    required this.strokeWidth,
  });

  factory CompactDanmakuTypography.resolve({
    required int configuredFontWeight,
    required String configuredFontFamily,
    required bool showStroke,
    required double configuredStrokeWidth,
  }) {
    final strokeWidth = configuredStrokeWidth.isFinite ? configuredStrokeWidth.clamp(0.0, 4.0).toDouble() : 1.5;
    return CompactDanmakuTypography._(
      fontWeight: configuredFontWeight.clamp(100, 900).toInt(),
      fontFamily: configuredFontFamily,
      showStroke: showStroke && strokeWidth > 0,
      strokeWidth: strokeWidth,
    );
  }

  final int fontWeight;
  final String fontFamily;
  final bool showStroke;
  final double strokeWidth;
}
