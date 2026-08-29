import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/modules/live_play/states/ui_state.dart';
import 'package:pure_live/player/core/portrait_stream_support.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku/danmaku_tab.dart';
import 'package:pure_live/modules/live_play/widgets/layout/live_play_video.dart';
import 'package:pure_live/modules/live_play/widgets/layout/live_play_header.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/widgets/resolution_selector/resolutions_row.dart';
import 'package:pure_live/modules/live_play/widgets/layout/portrait_fullscreen_interaction.dart';

enum LivePlayNormalLayoutKind { portraitStack, desktopSplit }

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
    this.onEnterPortraitFullscreen,
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
  final VoidCallback? onEnterPortraitFullscreen;

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
              onEnterPortraitFullscreen: onEnterPortraitFullscreen,
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
    this.onEnterPortraitFullscreen,
  });

  final Widget video;
  final Widget resolution;
  final Widget danmaku;
  final PortraitLayoutMode mode;
  final VoidCallback? onEnterLandscapeFullscreen;
  final VoidCallback? onEnterPortraitFullscreen;

  @override
  State<PortraitLiveRoomLayout> createState() => _PortraitLiveRoomLayoutState();
}

class _PortraitLiveRoomLayoutState extends State<PortraitLiveRoomLayout> {
  double? _panelHeight;
  double _dismissOffset = 0;
  bool _settling = false;
  bool _entryPending = false;

  @override
  void didUpdateWidget(covariant PortraitLiveRoomLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _panelHeight = null;
      _dismissOffset = 0;
      _entryPending = false;
    }
  }

  void _updatePanelDrag(DragUpdateDetails details, double current, double minimum, double maximum) {
    if (_entryPending) return;
    final delta = details.delta.dy;
    if (delta == 0) return;
    setState(() {
      _settling = false;
      final panelHeight = (_panelHeight ?? current).clamp(minimum, maximum).toDouble();
      if (delta > 0) {
        final collapsible = (panelHeight - minimum).clamp(0.0, double.infinity).toDouble();
        final collapseDelta = delta.clamp(0.0, collapsible).toDouble();
        _panelHeight = panelHeight - collapseDelta;
        final remaining = delta - collapseDelta;
        if (widget.onEnterPortraitFullscreen != null && remaining > 0) {
          _dismissOffset = (_dismissOffset + remaining).clamp(0.0, panelHeight + 36).toDouble();
        }
        return;
      }

      var upward = -delta;
      final revealDelta = upward.clamp(0.0, _dismissOffset).toDouble();
      _dismissOffset -= revealDelta;
      upward -= revealDelta;
      if (upward > 0) {
        _panelHeight = (panelHeight + upward).clamp(minimum, maximum).toDouble();
      }
    });
  }

  void _finishPanelDrag(DragEndDetails details, double current, double minimum, double middle, double maximum) {
    if (_entryPending) return;
    final panelHeight = (_panelHeight ?? current).clamp(minimum, maximum).toDouble();
    final disposition = resolvePortraitPanelDragEnd(
      entryEnabled: widget.onEnterPortraitFullscreen != null,
      dismissOffset: _dismissOffset,
      panelHeight: panelHeight,
      velocity: details.primaryVelocity ?? 0,
    );
    if (disposition == PortraitPanelDragDisposition.enterFullscreen) {
      setState(() {
        _entryPending = true;
        _settling = true;
        _dismissOffset = panelHeight + 36;
      });
      Future<void>.delayed(const Duration(milliseconds: 180), () {
        if (mounted) widget.onEnterPortraitFullscreen?.call();
      });
      return;
    }

    final dragEndHeight = panelHeight;
    final stops = <double>[minimum, middle, maximum];
    stops.sort((a, b) => (a - dragEndHeight).abs().compareTo((b - dragEndHeight).abs()));
    setState(() {
      _settling = true;
      _dismissOffset = 0;
      _panelHeight = stops.first;
    });
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
              child: AnimatedSlide(
                offset: Offset(0, current <= 0 ? 0 : (_dismissOffset / current).clamp(0.0, 1.2).toDouble()),
                duration: _settling ? const Duration(milliseconds: 180) : Duration.zero,
                curve: Curves.easeOutCubic,
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
                        onVerticalDragUpdate: (details) =>
                            _updatePanelDrag(details, current, range.minimum, range.maximum),
                        onVerticalDragEnd: (details) =>
                            _finishPanelDrag(details, current, range.minimum, range.middle, range.maximum),
                        onVerticalDragCancel: () {
                          setState(() {
                            _settling = true;
                            _dismissOffset = 0;
                          });
                        },
                        child: SizedBox(
                          height: widget.onEnterPortraitFullscreen == null ? 24 : 40,
                          child: Center(
                            child: widget.onEnterPortraitFullscreen == null
                                ? Container(
                                    width: 38,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.30),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 20,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          i18n('portrait_fullscreen_enter_hint'),
                                          key: const ValueKey('portrait-fullscreen-enter-hint'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
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
            ),
            if (widget.onEnterLandscapeFullscreen != null)
              Positioned(
                right: 12,
                bottom: current + 12 - _dismissOffset,
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
      final isPortrait = manager.isVerticalVideo.value && settings.enablePortraitStreamAdaptation.v;
      Widget presentation;
      if (!isPortrait) {
        presentation = Container(
          key: const ValueKey('fullscreen-standard-video'),
          color: Colors.black,
          child: LivePlayVideo(controller: controller, expandToParent: true),
        );
      } else {
        final detail = controller.state.value.room.detail;
        final cover = resolvePortraitFullscreenBackgroundUrl(
          detailCover: detail?.cover,
          roomCover: controller.room.cover,
          detailAvatar: detail?.avatar,
          roomAvatar: controller.room.avatar,
        );
        presentation = PortraitFullscreenPresentation(
          coverUrl: cover,
          child: LivePlayVideo(
            controller: controller,
            expandToParent: true,
            transparentSurface: true,
            videoViewportAspectRatio: manager.currentPresentationAspectRatio,
          ),
        );
      }
      if (mode != VideoMode.portraitFullscreen) return presentation;
      return Stack(
        key: const ValueKey('portrait-panel-fullscreen'),
        fit: StackFit.expand,
        children: [presentation, const PortraitFullscreenEntryHint()],
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
            onEnterPortraitFullscreen: PlatformUtils.isAndroid
                ? () {
                    final videoController = controller.state.value.player.videoController;
                    if (videoController != null) unawaited(videoController.enterPortraitFullScreen());
                  }
                : null,
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

/// Fullscreen presentation for a portrait programme on a landscape display.
/// Controls still own the complete screen, while only the video texture is
/// fitted to its trusted portrait geometry. A dim cached cover replaces harsh
/// empty side columns without duplicating or continuously sampling video.
class PortraitFullscreenPresentation extends StatelessWidget {
  const PortraitFullscreenPresentation({super.key, required this.coverUrl, required this.child});

  final String coverUrl;
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
          if (coverUrl.isNotEmpty)
            ImageFiltered(
              key: const ValueKey('fullscreen-portrait-ambient-image'),
              imageFilter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Transform.scale(
                scale: 1.12,
                child: CachedNetworkImage(
                  imageUrl: coverUrl,
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
