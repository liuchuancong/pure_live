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
  const CompactDanmakuOverlay({super.key, this.controller, this.barrage, this.respectPortraitPolicy = true});

  /// The room's controller, while it is alive: its per-room style (font, stroke,
  /// the room's own danmaku toggle) wins, exactly as in the full-size player.
  ///
  /// Null once the room's route is gone — the small window outlives it, and its
  /// danmaku must not disappear with the page.
  final VideoController? controller;

  /// The controller to render. Defaults to the room controller's compact pool;
  /// the small window passes the facade's own controller so the surface keeps
  /// rendering after the room's controller is gone.
  final BarrageController? barrage;

  /// Whether the room's portrait rule may hide this surface.
  ///
  /// The room hides danmaku over a portrait video when the viewer asked it to;
  /// the in-app small window is a deliberate watch surface the viewer sized and
  /// placed themselves, so it keeps showing danmaku (the master danmaku switch
  /// still applies) and turns this off.
  final bool respectPortraitPolicy;

  BarrageController get _barrage => barrage ?? controller!.pipDanmakuController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final settings = SettingsService.to.danmaku;
      final room = controller;
      final isVerticalVideo = GlobalPlayerService.instance.player.isVerticalVideo.value;
      final portraitMode = SettingsService.to.player.portraitDanmakuMode;
      final hidden =
          (room?.hideDanmaku.value ?? settings.hideDanmaku.v) ||
          (respectPortraitPolicy &&
              PortraitDanmakuPolicy.hidesDanmaku(isVerticalVideo: isVerticalVideo, mode: portraitMode));
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
      final area = PortraitDanmakuPolicy.effectiveArea(
        configuredArea: settings.danmakuArea.v,
        isVerticalVideo: isVerticalVideo,
        mode: portraitMode,
      );
      final topAreaDistance = settings.danmakuTopArea.v;
      final bottomAreaDistance = settings.danmakuBottomArea.v;
      final speed = settings.danmakuSpeed.v;
      final opacity = settings.danmakuOpacity.v;
      final fps = settings.resolvedDanmakuFps(pip: true, refreshRateMode: SettingsService.to.app.refreshRateMode);
      final maxVisibleCount = settings.effectiveMaxVisibleCount;
      final fontFamily = room?.roomDanmakuFontFamily.value ?? settings.danmakuFontFamilyName.v;
      final showStroke = room?.enableDanmakuStroke.value ?? settings.enableDanmakuStroke.v;
      final strokeWidth = room?.danmakuFontBorder.value ?? settings.danmakuFontBorder.v;
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
                controller: _barrage,
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
