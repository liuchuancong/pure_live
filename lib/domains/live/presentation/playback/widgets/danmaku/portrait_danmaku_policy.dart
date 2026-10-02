import 'package:pure_live/core/player/core/portrait_stream_support.dart' show PortraitDanmakuMode;

/// 竖屏源的弹幕呈现策略。
///
/// 房间画面（`DanmakuViewer`）与小窗 / 画中画弹幕层（`CompactDanmakuOverlay`）
/// 必须用同一份判定：此前只有房间画面读了 `portraitDanmakuMode`，于是同一个设置在
/// 小窗里既不会在 `hidden` 模式下隐藏弹幕，也不会按 `upperQuarter` / `reduced`
/// 收窄显示区域。
abstract final class PortraitDanmakuPolicy {
  /// 竖屏源在 [PortraitDanmakuMode.hidden] 下完全不显示弹幕。
  static bool hidesDanmaku({required bool isVerticalVideo, required PortraitDanmakuMode mode}) =>
      isVerticalVideo && mode == PortraitDanmakuMode.hidden;

  /// 竖屏源在主配置的显示区域之上再收窄：上四分之一 (0.25) 或减半 (0.50)。
  ///
  /// 非竖屏源与 [PortraitDanmakuMode.followGlobal] 都原样使用主配置。
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
