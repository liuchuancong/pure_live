import 'package:pure_live/core/player/core/portrait_stream_support.dart' show PortraitDanmakuMode;

abstract final class PortraitDanmakuPolicy {
  static bool hidesDanmaku({required bool isVerticalVideo, required PortraitDanmakuMode mode}) =>
      isVerticalVideo && mode == PortraitDanmakuMode.hidden;

  static double effectiveArea({
    required double configuredArea,
    required bool isVerticalVideo,
    required PortraitDanmakuMode mode,
  }) {
    if (!isVerticalVideo) return configuredArea;
    return switch (mode) {
      PortraitDanmakuMode.upperQuarter => configuredArea.clamp(0.0, 0.25).toDouble(),
      PortraitDanmakuMode.reduced => configuredArea.clamp(0.0, 0.50).toDouble(),
      _ => configuredArea,
    };
  }
}
