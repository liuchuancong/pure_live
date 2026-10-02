import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/utils/compact_danmaku_metrics.dart';
import 'package:flame_barrage/flame_barrage.dart';
import 'package:pure_live/features/live/playback/widgets/video_player/video_controller.dart';

/// The compact (picture-in-picture / small-window) danmaku surface.
///
/// It renders with the MAIN danmaku configuration — size, weight, speed,
/// opacity, area, density all come from the regular danmaku settings — so
/// there is exactly one place to tune how danmaku looks. What compact mode
/// adds is a single scale factor: "auto" follows the window width against a
/// 350px reference so text stays proportional in a resizable window, or the
/// user pins a multiplier on top.
class CompactDanmakuOverlay extends StatelessWidget {
  const CompactDanmakuOverlay({super.key, required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final settings = SettingsService.to.danmaku;
      final hidden = controller.hideDanmaku.value;
      if (hidden) {
        return const SizedBox.shrink();
      }

      // Keep all reactive reads in the Obx callback. LayoutBuilder executes
      // later, outside GetX dependency collection, so deferred reads would
      // leave the active PiP overlay on its previous style until another UI
      // rebuild happened.
      final scaleAuto = settings.pipDanmakuScaleAuto.v;
      final fixedScale = settings.pipDanmakuScaleValue.v;
      final noEmojiMode = settings.noEmojiMode.v;
      final configuredFontSize = settings.danmakuFontSize.v;
      final configuredFontWeight = settings.danmakuFontWeight.value;
      final area = settings.danmakuArea.v;
      final speed = settings.danmakuSpeed.v;
      final opacity = settings.danmakuOpacity.v;
      final fps = settings.resolvedDanmakuFps(pip: true, refreshRateMode: SettingsService.to.app.refreshRateMode);
      final maxVisibleCount = settings.danmakuMaxVisibleCount.v;
      final fontFamily = controller.danmakuFontFamilyName.value;
      final showStroke = controller.enableDanmakuStroke.value;
      final strokeWidth = controller.danmakuFontBorder.value;
      final typography = CompactDanmakuTypography.resolve(
        configuredFontWeight: configuredFontWeight,
        configuredFontFamily: fontFamily,
        showStroke: showStroke,
        configuredStrokeWidth: strokeWidth,
      );

      return IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 350.0;
            final metrics = CompactDanmakuMetrics.resolve(
              width: width,
              autoScale: scaleAuto,
              configuredFontSize: configuredFontSize,
              configuredSpeed: speed,
              fixedScale: scaleAuto ? 1.0 : fixedScale,
            );

            return RepaintBoundary(
              child: FlameBarrageWidget(
                controller: controller.pipDanmakuController,
                config: BarrageConfig(
                  fontSize: metrics.fontSize,
                  fontWeight: FontWeight(typography.fontWeight),
                  fontFamily: typography.fontFamily,
                  letterSpacing: settings.danmakuLetterSpacing.value * metrics.scale,
                  area: area,
                  baseSpeed: metrics.baseSpeed,
                  opacity: opacity,
                  showStroke: typography.showStroke,
                  noEmojiMode: noEmojiMode,
                  strokeWidth: typography.strokeWidth,
                  fps: fps,
                  safeArea: false,
                  trackHeight: metrics.trackHeight,
                  emojiSize: metrics.emojiSize,
                  maxVisibleCount: maxVisibleCount,
                  maxPendingCount: 36,
                  maxPendingAge: const Duration(seconds: 3),
                  fixedDuration: Duration(seconds: 4),
                  realtimeMode: settings.danmakuRealtimeMode.value,
                  rasterizeItems: true,
                  overlapSafeGap: metrics.overlapSafeGap,
                  // PiP only exposes a handful of tracks. Keeping desktop-size
                  // pools here retained hundreds of paragraphs/pictures after
                  // an overnight compact session and made repeated PiP cycles
                  // look like a leak on both Windows and Android.
                  barragePoolMaxSize: 32,
                  pictureCacheMaxSize: 48,
                  textCacheMaxSize: 160,
                ),
                emojiAtlas: EmojiAtlas.instance,
              ),
            );
          },
        ),
      );
    });
  }
}
