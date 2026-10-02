import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/utils/compact_danmaku_metrics.dart';
import 'package:flame_barrage/flame_barrage.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';

class CompactDanmakuOverlay extends StatelessWidget {
  const CompactDanmakuOverlay({super.key, required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final settings = SettingsService.to.danmaku;
      final enabled = settings.enablePipDanmaku.v;
      final hidden = controller.hideDanmaku.value;
      if (!enabled || hidden) {
        return const SizedBox.shrink();
      }

      // Keep all reactive reads in the Obx callback. LayoutBuilder executes
      // later, outside GetX dependency collection, so deferred reads would
      // leave the active PiP overlay on its previous style until another UI
      // rebuild happened.
      final autoScale = settings.pipDanmakuAutoScale.v;
      final noEmojiMode = settings.pipDanmakuNoEmojiMode.v;
      final configuredFontSize = settings.pipDanmakuFontSize.v;
      final configuredFontWeight = settings.pipDanmakuFontWeight.value;
      final area = settings.pipDanmakuArea.v;
      final speed = settings.pipDanmakuSpeed.v;
      final opacity = settings.pipDanmakuOpacity.v;
      final fps = settings.resolvedDanmakuFps(pip: true, refreshRateMode: SettingsService.to.app.refreshRateMode);
      final maxVisibleCount = settings.pipDanmakuMaxVisibleCount.v;
      final emitInterval = settings.pipDanmakuEmitInterval.v;
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
              autoScale: autoScale,
              configuredFontSize: configuredFontSize,
              configuredSpeed: speed,
            );

            return RepaintBoundary(
              child: FlameBarrageWidget(
                controller: controller.pipDanmakuController,
                config: BarrageConfig(
                  fontSize: metrics.fontSize,
                  fontWeight: FontWeight(typography.fontWeight),
                  fontFamily: typography.fontFamily,
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
                  fixedDuration: Duration(seconds: settings.pipDanmakuDuration.v),
                  emitInterval: emitInterval,
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
