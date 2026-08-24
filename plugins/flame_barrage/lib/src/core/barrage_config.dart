import 'package:flutter/material.dart';
import 'package:flame_barrage/flame_barrage.dart';

/// Configuration class managing the core hyper-parameters, cache sizing
/// limitations, and rendering rules of the barrage orchestration engine.
class BarrageConfig {
  const BarrageConfig({
    this.fontSize = 18,
    this.fontWeight = FontWeight.w500,
    this.fontStyle = FontStyle.normal,
    this.fontFamily,
    this.letterSpacing = 0,
    this.textColor = Colors.white,
    this.strokeColor = Colors.black,
    this.opacity = 1.0,
    this.showStroke = true,
    this.showShadow = false,
    this.shadowColor = Colors.black,
    this.shadowBlur = 0,
    this.shadowOffset = const Offset(1, 1),
    this.area = 1.0,
    this.topAreaDistance = 0,
    this.bottomAreaDistance = 0,
    this.fixedDuration = const Duration(seconds: 4),
    this.safeArea = true,
    this.fps = 60,
    this.trackHeight = 36,
    this.emojiSize = 24,
    this.maxVisibleCount = 80,
    this.maxPendingCount = 120,
    this.maxPendingAge = const Duration(seconds: 5),
    this.emitInterval = 0.1,
    this.baseSpeed = 120.0,
    this.strokeWidth = 1.0,
    this.overlapSafeGap = 40.0,
    this.noEmojiMode = false,
    this.barragePoolMaxSize = 150,
    this.pictureCacheMaxSize = 200,
    this.textCacheMaxSize = 1000,
    this.effectInterceptors = const [],
  });

  /// The baseline font size for typography fragments in pixels.
  final double fontSize;

  /// The structural thickness and weight configuration of the rendered font.
  final FontWeight fontWeight;

  /// Slant used for locally styled text.
  final FontStyle fontStyle;

  /// Additional spacing between glyphs in logical pixels.
  final double letterSpacing;

  /// The default text fill color applied during paragraph compilation.
  final Color textColor;

  /// The edge boundary outline color utilized for anti-invisible rendering.
  final Color strokeColor;

  final double strokeWidth;

  /// The default opacity level (alpha scale) for active view elements (0.0 to 1.0).
  final double opacity;

  /// Toggles the native C++ hardware-accelerated text outline rendering.
  final bool showStroke;

  /// Optional cached paragraph shadow. This adds no per-frame saveLayer.
  final bool showShadow;
  final Color shadowColor;
  final double shadowBlur;
  final Offset shadowOffset;

  /// The vertical proportion of screen space allowed for vertical lane allocation (0.1 to 1.0).
  final double area;

  /// Fixed buffer margin padding inset from the absolute top viewport edge.
  final double topAreaDistance;

  /// Fixed buffer margin padding inset from the absolute bottom viewport edge.
  final double bottomAreaDistance;

  /// Total presentation lifetime duration allowed for fixed top and bottom barrages.
  final Duration fixedDuration;

  /// Automatically adjusts allocation vertical layout based on device safe insets.
  final bool safeArea;

  /// The target frame rate frequency utilized for asynchronous telemetry calculations.
  final int fps;

  /// The total structural height allocated to a single track row layer row.
  final double trackHeight;

  /// The inline layout grid dimensions reserved for emoji/atlas bitmap drawing.
  final double emojiSize;

  /// Hard cap regulating max concurrent components allowed in the active layout rendering tree.
  final int maxVisibleCount;

  /// Hard cap for messages waiting on a free lane. Live streams can produce
  /// large bursts; an unbounded queue eventually renders minutes-old content.
  final int maxPendingCount;

  /// Maximum wall-clock age of a message before it enters the screen.
  final Duration maxPendingAge;

  /// The dispatch clock ticking time interval during normal concurrency traffic pumping.
  final double emitInterval;

  /// The internal pixel-per-second velocity reference mapping baseline tracking constraint.
  final double baseSpeed;

  /// The mandatory clearance width buffer required between tailgating elements to avoid overlap.
  final double overlapSafeGap;

  /// Toggles pure text rendering by completely culling and bypassing emoji fragments.
  final bool noEmojiMode;

  /// The structural recycling object count threshold kept inside the components recycler pool.
  final int barragePoolMaxSize;

  /// The maximum element size allocation allowed within the hardware LRU Picture bitmap cache map.
  final int pictureCacheMaxSize;

  /// The maximum element size threshold for caching compiled C++ Paragraph layout shapes.
  final int textCacheMaxSize;

  /// The list of plugin interceptor nodes hooked onto the pre-layout pipeline workspace.
  final List<BarrageEffectInterceptor> effectInterceptors;

  /// Computes the fixed duration length metric in milliseconds.
  int get fixedDurationMs => fixedDuration.inMilliseconds;

  /// fontFamily
  final String? fontFamily;

  BarrageConfig copyWith({
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    String? fontFamily,
    double? letterSpacing,
    Color? textColor,
    Color? strokeColor,
    double? opacity,
    bool? showStroke,
    bool? showShadow,
    Color? shadowColor,
    double? shadowBlur,
    Offset? shadowOffset,
    double? strokeWidth,
    double? area,
    double? topAreaDistance,
    double? bottomAreaDistance,
    Duration? fixedDuration,
    bool? hideTop,
    bool? hideBottom,
    bool? hideScroll,
    bool? safeArea,
    int? fps,
    double? trackHeight,
    double? emojiSize,
    int? maxVisibleCount,
    int? maxPendingCount,
    Duration? maxPendingAge,
    double? emitInterval,
    double? baseSpeed,
    double? overlapSafeGap,
    bool? noEmojiMode,
    int? barragePoolMaxSize,
    int? pictureCacheMaxSize,
    int? textCacheMaxSize,
    List<BarrageEffectInterceptor>? effectInterceptors,
  }) {
    return BarrageConfig(
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      fontStyle: fontStyle ?? this.fontStyle,
      fontFamily: fontFamily ?? this.fontFamily,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      textColor: textColor ?? this.textColor,
      strokeColor: strokeColor ?? this.strokeColor,
      opacity: opacity ?? this.opacity,
      showStroke: showStroke ?? this.showStroke,
      showShadow: showShadow ?? this.showShadow,
      shadowColor: shadowColor ?? this.shadowColor,
      shadowBlur: shadowBlur ?? this.shadowBlur,
      shadowOffset: shadowOffset ?? this.shadowOffset,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      area: area ?? this.area,
      topAreaDistance: topAreaDistance ?? this.topAreaDistance,
      bottomAreaDistance: bottomAreaDistance ?? this.bottomAreaDistance,
      fixedDuration: fixedDuration ?? this.fixedDuration,
      safeArea: safeArea ?? this.safeArea,
      fps: fps ?? this.fps,
      trackHeight: trackHeight ?? this.trackHeight,
      emojiSize: emojiSize ?? this.emojiSize,
      maxVisibleCount: maxVisibleCount ?? this.maxVisibleCount,
      maxPendingCount: maxPendingCount ?? this.maxPendingCount,
      maxPendingAge: maxPendingAge ?? this.maxPendingAge,
      emitInterval: emitInterval ?? this.emitInterval,
      baseSpeed: baseSpeed ?? this.baseSpeed,
      overlapSafeGap: overlapSafeGap ?? this.overlapSafeGap,
      noEmojiMode: noEmojiMode ?? this.noEmojiMode,
      barragePoolMaxSize: barragePoolMaxSize ?? this.barragePoolMaxSize,
      pictureCacheMaxSize: pictureCacheMaxSize ?? this.pictureCacheMaxSize,
      textCacheMaxSize: textCacheMaxSize ?? this.textCacheMaxSize,
      effectInterceptors: effectInterceptors ?? this.effectInterceptors,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BarrageConfig &&
        other.fontSize == fontSize &&
        other.fontWeight == fontWeight &&
        other.fontStyle == fontStyle &&
        other.letterSpacing == letterSpacing &&
        other.textColor == textColor &&
        other.strokeColor == strokeColor &&
        other.opacity == opacity &&
        other.showStroke == showStroke &&
        other.showShadow == showShadow &&
        other.shadowColor == shadowColor &&
        other.shadowBlur == shadowBlur &&
        other.shadowOffset == shadowOffset &&
        other.strokeWidth == strokeWidth &&
        other.area == area &&
        other.topAreaDistance == topAreaDistance &&
        other.fontFamily == fontFamily &&
        other.bottomAreaDistance == bottomAreaDistance &&
        other.safeArea == safeArea &&
        other.fixedDuration == fixedDuration &&
        other.fps == fps &&
        other.trackHeight == trackHeight &&
        other.emojiSize == emojiSize &&
        other.maxVisibleCount == maxVisibleCount &&
        other.maxPendingCount == maxPendingCount &&
        other.maxPendingAge == maxPendingAge &&
        other.emitInterval == emitInterval &&
        other.baseSpeed == baseSpeed &&
        other.overlapSafeGap == overlapSafeGap &&
        other.noEmojiMode == noEmojiMode &&
        other.barragePoolMaxSize == barragePoolMaxSize &&
        other.pictureCacheMaxSize == pictureCacheMaxSize &&
        other.textCacheMaxSize == textCacheMaxSize;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      fontSize,
      fontWeight,
      fontStyle,
      letterSpacing,
      textColor,
      strokeColor,
      opacity,
      showStroke,
      showShadow,
      shadowColor,
      shadowBlur,
      shadowOffset,
      strokeWidth,
      area,
      topAreaDistance,
      bottomAreaDistance,
      safeArea,
      fixedDuration,
      fps,
      fontFamily,
      trackHeight,
      emojiSize,
      maxVisibleCount,
      maxPendingCount,
      maxPendingAge,
      emitInterval,
      baseSpeed,
      overlapSafeGap,
      noEmojiMode,
      barragePoolMaxSize,
      pictureCacheMaxSize,
      textCacheMaxSize,
    ]);
  }
}
