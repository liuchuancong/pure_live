import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/live/domain/global_player_service.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/danmaku/compact_danmaku_metrics.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/danmaku/portrait_danmaku_policy.dart';
import 'package:flame_barrage/flame_barrage.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/video_player/video_controller.dart';

/// The compact (picture-in-picture / small-window) danmaku surface.
///
/// It renders with the MAIN danmaku configuration — size, weight, speed,
/// opacity, area, top/bottom insets, the portrait policy and density all come
/// from the regular danmaku settings — so there is exactly one place to tune how
/// danmaku looks. What compact mode adds is a single scale factor: "auto"
/// follows the window width against a 350px reference so text stays
/// proportional in a resizable window, or the user pins a multiplier on top.
/// Only the compact-specific pool sizes and admission interval differ from the
/// room's renderer.
class CompactDanmakuOverlay extends StatelessWidget {
  const CompactDanmakuOverlay({super.key, required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final settings = SettingsService.to.danmaku;
      final isVerticalVideo = GlobalPlayerService.instance.player.isVerticalVideo.value;
      final portraitMode = SettingsService.to.player.portraitDanmakuMode;
      // 竖屏隐藏与主画面同一判定：否则同一个「竖屏弹幕：隐藏」设置只关掉房间画面，
      // 小窗里仍在滚动。
      final hidden =
          controller.hideDanmaku.value ||
          PortraitDanmakuPolicy.hidesDanmaku(isVerticalVideo: isVerticalVideo, mode: portraitMode);
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
      // 竖屏源的区域收窄也要跟着来，否则小窗会用主配置的完整区域。
      final area = PortraitDanmakuPolicy.effectiveArea(
        configuredArea: settings.danmakuArea.v,
        isVerticalVideo: isVerticalVideo,
        mode: portraitMode,
      );
      // 距离顶部/底部是主弹幕设置里的绝对像素内缩，主画面、多画面和控制面板都传了它们；
      // 小窗这一层此前漏传，于是同一个设置在小窗里完全没有效果。
      final topAreaDistance = settings.danmakuTopArea.v;
      final bottomAreaDistance = settings.danmakuBottomArea.v;
      final speed = settings.danmakuSpeed.v;
      final opacity = settings.danmakuOpacity.v;
      final fps = settings.resolvedDanmakuFps(pip: true, refreshRateMode: SettingsService.to.app.refreshRateMode);
      final maxVisibleCount = settings.effectiveMaxVisibleCount;
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
                  topAreaDistance: topAreaDistance,
                  bottomAreaDistance: bottomAreaDistance,
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
                  realtimeMode: settings.danmakuMassMode.value,
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
