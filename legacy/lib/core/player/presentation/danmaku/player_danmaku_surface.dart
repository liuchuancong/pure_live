import 'package:flame_barrage/flame_barrage.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/player/presentation/danmaku/danmaku_surface_settings.dart';

/// The shared on-picture danmaku renderer.
///
/// A live room and a replayed recording show the same barrage over the same kind
/// of picture; only the pool it draws from differs (a socket, or the chat file
/// recorded beside the video). Everything a viewer can tune — size, weight,
/// speed, opacity, area, density, emoji, stroke — comes from the one danmaku
/// settings page, so the two surfaces cannot drift apart.
///
/// Responsibilities:
///
/// - render [controller]'s pool with the configuration resolved by [settings]
/// - repaint when the viewer changes that configuration
///
/// It does not:
///
/// - fill the pool (a transport, a room or a replay engine does)
/// - decide which messages are admitted (the barrage engine does)
/// - own gestures (the player's own gesture layer sits above it)
class PlayerDanmakuSurface extends StatelessWidget {
  const PlayerDanmakuSurface({
    super.key,
    required this.controller,
    required this.settings,
    this.isVerticalVideo = false,
  });

  /// The pool to draw.
  final BarrageController controller;

  /// Where the visual configuration comes from.
  final DanmakuSettingsSource settings;

  /// Whether the picture is taller than it is wide, which the portrait danmaku
  /// policy needs to decide how much of it the barrage may cover.
  final bool isVerticalVideo;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final danmaku = SettingsService.to.danmaku;
      final player = SettingsService.to.player;
      final fontSize = settings.danmakuFontSize.value;
      final area = PortraitDanmakuPolicy.effectiveArea(
        configuredArea: settings.danmakuArea.value,
        isVerticalVideo: isVerticalVideo,
        mode: player.portraitDanmakuMode,
      );
      return FlameBarrageWidget(
        controller: controller,
        // The player's gesture layer owns the full surface and forwards only
        // hits on actual barrage bounds, so volume/brightness/double-tap stay
        // responsive.
        enablePointerEvents: false,
        config: BarrageConfig(
          // Dispatching every frame allowed up to 60 new paragraphs per second
          // on busy rooms; a 50 ms admission interval bounds the layout and
          // paint pressure.
          emitInterval: 0.05,
          fontSize: fontSize,
          topAreaDistance: settings.danmakuTopArea.value,
          area: area,
          bottomAreaDistance: settings.danmakuBottomArea.value,
          baseSpeed: settings.danmakuSpeed.value,
          opacity: settings.danmakuOpacity.value,
          fontWeight: FontWeight(settings.danmakuFontWeight.value),
          letterSpacing: settings.danmakuLetterSpacing.value,
          strokeWidth: settings.danmakuFontBorder.value,
          showStroke: settings.enableDanmakuStroke.value,
          noEmojiMode: settings.noEmojiMode.value,
          realtimeMode: settings.danmakuMassMode.value,
          // One GPU-resident bitmap per visible message — the single most
          // effective switch on low-end GPUs re-rasterizing stroked CJK text
          // every frame.
          rasterizeItems: true,
          fps: danmaku.danmakuAutoFps.value
              ? danmaku.resolvedDanmakuFps(refreshRateMode: SettingsService.to.app.refreshRateMode)
              : settings.danmakuFps.value.clamp(30, 240).toInt(),
          maxVisibleCount: danmaku.effectiveMaxVisibleCount,
          maxPendingCount: 120,
          maxPendingAge: const Duration(seconds: 5),
          fontFamily: settings.danmakuFontFamilyName,
          trackHeight: (fontSize * 1.55).clamp(24.0, 64.0).toDouble(),
          emojiSize: (fontSize * 1.3).clamp(16.0, 48.0).toDouble(),
          pictureCacheMaxSize: 96,
          barragePoolMaxSize: 72,
          textCacheMaxSize: 320,
        ),
        emojiAtlas: EmojiAtlas.instance,
      );
    });
  }
}
