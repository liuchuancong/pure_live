import 'package:pure_live/common/index.dart';
import 'package:flame_barrage/flame_barrage.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';

class CompactDanmakuOverlay extends StatelessWidget {
  const CompactDanmakuOverlay({super.key, required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final settings = SettingsService.to.danmaku;
      if (!settings.enablePipDanmaku.v || controller.hideDanmaku.value) {
        return const SizedBox.shrink();
      }

      return IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 350.0;
            final scale = settings.pipDanmakuAutoScale.v ? (width / 350.0).clamp(0.65, 1.0).toDouble() : 1.0;
            final fontSize = settings.pipDanmakuFontSize.v * scale;

            return FlameBarrageWidget(
              controller: controller.pipDanmakuController,
              config: BarrageConfig(
                fontSize: fontSize,
                fontFamily: controller.danmakuFontFamilyName.value,
                area: settings.pipDanmakuArea.v,
                baseSpeed: settings.pipDanmakuSpeed.v * scale,
                opacity: settings.pipDanmakuOpacity.v,
                showStroke: controller.enableDanmakuStroke.value,
                strokeWidth: 1.0,
                fps: settings.pipDanmakuFps.v,
                safeArea: false,
                trackHeight: (fontSize * 1.8).clamp(18.0, 44.0).toDouble(),
                emojiSize: (fontSize * 1.35).clamp(14.0, 32.0).toDouble(),
                maxVisibleCount: settings.pipDanmakuMaxVisibleCount.v,
                emitInterval: settings.pipDanmakuEmitInterval.v,
                overlapSafeGap: (fontSize * 1.5).clamp(16.0, 40.0).toDouble(),
                barragePoolMaxSize: 60,
                pictureCacheMaxSize: 300,
              ),
              emojiAtlas: EmojiAtlas.instance,
            );
          },
        ),
      );
    });
  }
}
