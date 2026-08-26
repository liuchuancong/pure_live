import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/states/ui_state.dart';
import 'package:pure_live/player/core/portrait_stream_support.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku/danmaku_tab.dart';
import 'package:pure_live/modules/live_play/widgets/layout/live_play_video.dart';
import 'package:pure_live/modules/live_play/widgets/layout/live_play_header.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/widgets/resolution_selector/resolutions_row.dart';

enum LivePlayNormalLayoutKind { portraitStack, desktopSplit }

@immutable
class FullscreenVideoSurfaceStyle {
  const FullscreenVideoSurfaceStyle({
    required this.useAmbientBackground,
    required this.fitOverride,
    required this.surfaceColor,
  });

  final bool useAmbientBackground;
  final BoxFit? fitOverride;
  final Color surfaceColor;
}

/// Resolves the viewport policy before constructing any native video widget.
///
/// Portrait content in a landscape fullscreen must remain contained even when
/// the user's ordinary-room fit is `fill` or `cover`. Its unused viewport must
/// also be transparent so the ambient cover behind the native player remains
/// visible. Ordinary landscape rooms retain the selected global fit and black
/// surface exactly as before.
@visibleForTesting
FullscreenVideoSurfaceStyle resolveFullscreenVideoSurfaceStyle({
  required VideoPresentationGeometry geometry,
  required bool portraitAdaptationEnabled,
}) {
  final usePortraitPresentation = portraitAdaptationEnabled && geometry.orientation == VideoSourceOrientation.portrait;
  return usePortraitPresentation
      ? const FullscreenVideoSurfaceStyle(
          useAmbientBackground: true,
          fitOverride: BoxFit.contain,
          surfaceColor: Colors.transparent,
        )
      : const FullscreenVideoSurfaceStyle(useAmbientBackground: false, fitOverride: null, surfaceColor: Colors.black);
}

@visibleForTesting
String resolvePortraitFullscreenBackgroundUrl({
  String? detailCover,
  String? roomCover,
  String? detailAvatar,
  String? roomAvatar,
}) {
  for (final value in [detailCover, roomCover, detailAvatar, roomAvatar]) {
    final candidate = value?.trim() ?? '';
    if (candidate.isNotEmpty) return candidate;
  }
  return '';
}

LivePlayNormalLayoutKind resolveLivePlayNormalLayout(double width) {
  return width <= 680 ? LivePlayNormalLayoutKind.portraitStack : LivePlayNormalLayoutKind.desktopSplit;
}

/// Stable normal-room composition shared by production and widget tests.
///
/// The video, quality selector and danmaku list must remain simultaneously
/// visible on a phone. Hiding them behind a full-surface flip/drawer makes a
/// normal room indistinguishable from fullscreen and leaves no discoverable
/// interaction surface.
class LivePlayNormalLayout extends StatelessWidget {
  const LivePlayNormalLayout({
    super.key,
    required this.video,
    required this.resolution,
    required this.danmaku,
    this.showPanel = true,
    this.isPortraitSource = false,
    this.sourceAspectRatio = 16 / 9,
    this.adaptivePortraitHeight = false,
    this.portraitLayoutMode = PortraitLayoutMode.balanced,
    this.onEnterLandscapeFullscreen,
  });

  final Widget video;
  final Widget resolution;
  final Widget danmaku;
  final bool showPanel;
  final bool isPortraitSource;
  final double sourceAspectRatio;
  final bool adaptivePortraitHeight;
  final PortraitLayoutMode portraitLayoutMode;
  final VoidCallback? onEnterLandscapeFullscreen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!showPanel) {
          return Align(
            key: const ValueKey('live-play-video-only-layout'),
            alignment: Alignment.topCenter,
            child: video,
          );
        }
        if (resolveLivePlayNormalLayout(constraints.maxWidth) == LivePlayNormalLayoutKind.portraitStack) {
          final useAdaptivePortraitFrame =
              isPortraitSource && adaptivePortraitHeight && portraitLayoutMode != PortraitLayoutMode.compatibility;
          if (useAdaptivePortraitFrame) {
            return PortraitLiveRoomLayout(
              video: video,
              resolution: resolution,
              danmaku: danmaku,
              mode: portraitLayoutMode,
              onEnterLandscapeFullscreen: onEnterLandscapeFullscreen,
            );
          }
          return Column(
            key: const ValueKey('live-play-portrait-stack'),
            children: [
              video,
              resolution,
              const Divider(height: 1),
              Expanded(
                key: const ValueKey('live-play-portrait-danmaku'),
                child: ColoredBox(color: Theme.of(context).colorScheme.surface, child: danmaku),
              ),
            ],
          );
        }

        final panelWidth = (constraints.maxWidth * 0.34).clamp(300.0, 400.0);
        return Row(
          key: const ValueKey('live-play-desktop-split'),
          children: [
            Expanded(child: video),
            SizedBox(
              key: const ValueKey('live-play-desktop-panel'),
              width: panelWidth,
              child: Column(
                children: [
                  resolution,
                  const Divider(height: 1),
                  Expanded(child: danmaku),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Portrait programme presentation for a phone room.
///
/// The video owns the full available canvas while a three-stop interaction
/// sheet overlays its lower edge. Users can reveal more danmaku without
/// throwing away the tall video area, and the drag handle is isolated from the
/// list's own scroll recognizer.
class PortraitLiveRoomLayout extends StatefulWidget {
  const PortraitLiveRoomLayout({
    super.key,
    required this.video,
    required this.resolution,
    required this.danmaku,
    required this.mode,
    this.onEnterLandscapeFullscreen,
  });

  final Widget video;
  final Widget resolution;
  final Widget danmaku;
  final PortraitLayoutMode mode;
  final VoidCallback? onEnterLandscapeFullscreen;

  @override
  State<PortraitLiveRoomLayout> createState() => _PortraitLiveRoomLayoutState();
}

class _PortraitLiveRoomLayoutState extends State<PortraitLiveRoomLayout> {
  double? _panelHeight;

  @override
  void didUpdateWidget(covariant PortraitLiveRoomLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) _panelHeight = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final range = portraitPanelRange(constraints.maxHeight, widget.mode);
        final current = (_panelHeight ?? range.initial).clamp(range.minimum, range.maximum).toDouble();
        return Stack(
          key: const ValueKey('live-play-portrait-stack'),
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: ColoredBox(
                key: const ValueKey('live-play-adaptive-video-frame'),
                color: Colors.black,
                child: RepaintBoundary(child: widget.video),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: current,
              child: Material(
                key: const ValueKey('live-play-portrait-sheet'),
                color: Theme.of(context).colorScheme.surface,
                elevation: 10,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    GestureDetector(
                      key: const ValueKey('live-play-portrait-sheet-handle'),
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (details) {
                        setState(() {
                          _panelHeight = (current - details.delta.dy).clamp(range.minimum, range.maximum).toDouble();
                        });
                      },
                      onVerticalDragEnd: (_) {
                        final dragEndHeight = (_panelHeight ?? current).clamp(range.minimum, range.maximum).toDouble();
                        final stops = <double>[range.minimum, range.middle, range.maximum];
                        stops.sort((a, b) => (a - dragEndHeight).abs().compareTo((b - dragEndHeight).abs()));
                        setState(() => _panelHeight = stops.first);
                      },
                      child: SizedBox(
                        height: 24,
                        child: Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.30),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                    ),
                    widget.resolution,
                    const Divider(height: 1),
                    Expanded(key: const ValueKey('live-play-portrait-danmaku'), child: widget.danmaku),
                  ],
                ),
              ),
            ),
            if (widget.onEnterLandscapeFullscreen != null)
              Positioned(
                right: 12,
                bottom: current + 12,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(24),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: const ValueKey('portrait-landscape-fullscreen'),
                    onTap: widget.onEnterLandscapeFullscreen,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.screen_rotation_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 6),
                          Text(
                            '横屏全屏',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

@visibleForTesting
({double minimum, double middle, double maximum, double initial}) portraitPanelRange(
  double availableHeight,
  PortraitLayoutMode mode,
) {
  final minimum = (availableHeight * 0.27).clamp(190.0, 250.0).toDouble();
  final maximum = (availableHeight * 0.68).clamp(minimum, availableHeight - 120).toDouble();
  final middle = (availableHeight * 0.44).clamp(minimum, maximum).toDouble();
  final initial = mode == PortraitLayoutMode.immersive ? minimum : middle;
  return (minimum: minimum, middle: middle, maximum: maximum, initial: initial);
}

class LivePlayContent extends StatelessWidget {
  const LivePlayContent({super.key, required this.controller, required this.isInPip, required this.mode});

  final LivePlayController controller;
  final bool isInPip;
  final VideoMode mode;

  @override
  Widget build(BuildContext context) {
    final manager = GlobalPlayerService.instance.player;

    if (isInPip) {
      return Theme(
        data: ThemeData.dark(),
        child: Container(key: const ValueKey('pip'), color: Colors.transparent, child: manager.buildPiPOverlay()),
      );
    }

    if (mode == VideoMode.normal) {
      return ColoredBox(
        key: const ValueKey('normal'),
        color: Theme.of(context).scaffoldBackgroundColor,
        child: _buildNormalView(context),
      );
    }

    return Obx(() {
      final settings = SettingsService.to.player;
      manager.videoPresentationRevision.value;
      final geometry = manager.currentPresentationGeometry;
      final style = resolveFullscreenVideoSurfaceStyle(
        geometry: geometry,
        portraitAdaptationEnabled: settings.enablePortraitStreamAdaptation.v,
      );
      if (!style.useAmbientBackground) {
        return Container(
          key: const ValueKey('fullscreen-standard-video'),
          color: Colors.black,
          child: LivePlayVideo(controller: controller, expandToParent: true),
        );
      }
      final detail = controller.state.value.room.detail;
      final backgroundUrl = resolvePortraitFullscreenBackgroundUrl(
        detailCover: detail?.cover,
        roomCover: controller.room.cover,
        detailAvatar: detail?.avatar,
        roomAvatar: controller.room.avatar,
      );
      return PortraitFullscreenPresentation(
        backgroundUrl: backgroundUrl,
        child: LivePlayVideo(
          controller: controller,
          expandToParent: true,
          surfaceColor: style.surfaceColor,
          fitOverride: style.fitOverride,
        ),
      );
    });
  }

  Widget _buildNormalView(BuildContext context) {
    final compactHeader = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: LivePlayHeader(controller: controller, compactHeader: compactHeader),
      body: SafeArea(
        child: Obx(() {
          final manager = GlobalPlayerService.instance.player;
          final settings = SettingsService.to.player;
          final isPortrait = manager.isVerticalVideo.value;
          final useAdaptivePortraitFrame =
              MediaQuery.sizeOf(context).width <= 680 &&
              isPortrait &&
              settings.enablePortraitStreamAdaptation.v &&
              settings.portraitAdaptiveHeight.v &&
              settings.portraitLayoutMode != PortraitLayoutMode.compatibility;
          return LivePlayNormalLayout(
            video: LivePlayVideo(controller: controller, expandToParent: useAdaptivePortraitFrame),
            resolution: const ResolutionsRow(),
            danmaku: _buildDanmaku(),
            showPanel: controller.site != Sites.iptvSite,
            isPortraitSource: isPortrait,
            sourceAspectRatio: manager.currentPresentationAspectRatio,
            adaptivePortraitHeight: settings.enablePortraitStreamAdaptation.v && settings.portraitAdaptiveHeight.v,
            portraitLayoutMode: settings.portraitLayoutMode,
            onEnterLandscapeFullscreen: () {
              final videoController = controller.state.value.player.videoController;
              if (videoController != null) unawaited(videoController.enterLandscapeFullScreen());
            },
          );
        }),
      ),
    );
  }

  Widget _buildDanmaku() {
    return Obx(() {
      final state = controller.state.value;
      if (!state.room.success || controller.site == Sites.iptvSite) {
        return const SizedBox.shrink();
      }
      final globalState = GlobalPlayerState.to;
      if (globalState.isFullscreen.value || globalState.isWindowFullscreen.value) {
        return const SizedBox.shrink();
      }
      return const DanmakuTabView();
    });
  }
}

/// Fullscreen presentation for a portrait programme on a landscape display.
/// Controls still own the complete screen, while only the video texture is
/// fitted to its trusted portrait geometry. A dim cached cover replaces harsh
/// empty side columns without duplicating or continuously sampling video.
class PortraitFullscreenPresentation extends StatelessWidget {
  const PortraitFullscreenPresentation({super.key, required this.backgroundUrl, required this.child});

  final String backgroundUrl;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('fullscreen-portrait-presentation'),
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            key: ValueKey('fullscreen-portrait-ambient-fallback'),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF171A22), Color(0xFF07080B)],
              ),
            ),
          ),
          if (backgroundUrl.isNotEmpty)
            ImageFiltered(
              key: const ValueKey('fullscreen-portrait-ambient-image'),
              imageFilter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Transform.scale(
                scale: 1.12,
                child: CachedNetworkImage(
                  imageUrl: backgroundUrl,
                  fit: BoxFit.cover,
                  fadeInDuration: Duration.zero,
                  filterQuality: FilterQuality.low,
                  placeholder: (_, _) => const SizedBox.expand(),
                  errorWidget: (_, _, _) => const SizedBox.expand(),
                ),
              ),
            ),
          const ColoredBox(color: Color(0x73000000)),
          RepaintBoundary(child: child),
        ],
      ),
    );
  }
}
