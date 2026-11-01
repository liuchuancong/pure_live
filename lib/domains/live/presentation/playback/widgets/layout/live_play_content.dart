import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/platform/platform_utils.dart';
import 'package:pure_live/domains/live/presentation/playback/states/ui_state.dart';
import 'package:pure_live/core/player/core/portrait_stream_support.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/danmaku/danmaku_tab.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/layout/live_play_video.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/video_player/picture_cover.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/layout/live_play_header.dart';
import 'package:pure_live/domains/live/presentation/playback/controllers/live_play_controller.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/resolution_selector/resolutions_row.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/layout/portrait_fullscreen_interaction.dart';
import 'package:pure_live/domains/live/domain/global_player_service.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';

enum LivePlayNormalLayoutKind { portraitStack, landscapeStack, desktopSplit }

/// Width up to which the room stacks video above the danmaku panel.
const double livePlayPortraitStackMaxWidth = 680;

/// Picks the page split topology from the current window state together with
/// the live source's own orientation.
///
/// A phone-sized window always keeps the single stacked column. A large window
/// keeps the side-by-side panel only for a portrait programme: a landscape
/// programme leaves most of that panel's height unused, so it stacks the same
/// way a folded phone does. The orientation comes from the decoded frame size,
/// never from the device's physical rotation, and the window width is the only
/// window-state signal available (the repository has no hinge/fold API).
LivePlayNormalLayoutKind resolveLivePlayNormalLayout({
  required double width,
  required bool isPortraitSource,
  bool splitBySourceOrientation = false,
}) {
  if (width <= livePlayPortraitStackMaxWidth) return LivePlayNormalLayoutKind.portraitStack;
  if (splitBySourceOrientation && !isPortraitSource) return LivePlayNormalLayoutKind.landscapeStack;
  return LivePlayNormalLayoutKind.desktopSplit;
}

/// Height of the video area in「兼容 16:9」mode.
///
/// v3.1.2 computed `min(width / sourceAspectRatio, 0.6 * availableHeight)`:
/// the source's own aspect decides the height while the danmaku list keeps at
/// least 40% of the page. The "约 6:4" in Issue #927 is that 0.6 ceiling, not a
/// fixed container ratio — a landscape source therefore still gets its plain
/// 16:9 box, and the picture is never cropped to fill the area.
@visibleForTesting
double resolveCompatibilityVideoHeight({
  required double availableWidth,
  required double availableHeight,
  required double sourceAspectRatio,
  double danmakuShare = 0.4,
  double resolutionReserve = 56,
  double fallbackAspectRatio = 16 / 9,
}) {
  if (!availableWidth.isFinite || availableWidth <= 0) return 0;
  final ratio = sourceAspectRatio.isFinite && sourceAspectRatio > 0 ? sourceAspectRatio : fallbackAspectRatio;
  final preferred = availableWidth / ratio;
  if (!availableHeight.isFinite || availableHeight <= 0) return preferred;
  final cap = availableHeight * (1 - danmakuShare.clamp(0.0, 1.0));
  // Degenerate bounds must not push the quality row and the danmaku list out
  // of the page: the fixed siblings always keep their reserve.
  final ceiling = (availableHeight - resolutionReserve).clamp(0.0, availableHeight);
  return preferred < cap ? preferred.clamp(0.0, ceiling) : cap.clamp(0.0, ceiling);
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
    this.splitBySourceOrientation = false,
    this.landscapeDanmakuHeight = defaultLandscapeDanmakuHeight,
    this.onEnterLandscapeFullscreen,
    this.onEnterPortraitFullscreen,
  });

  /// Default floor for the danmaku list in the stacked landscape topology.
  static const double defaultLandscapeDanmakuHeight = 220;

  /// Smallest list the stacked landscape topology will leave usable, even when
  /// the configured floor is smaller or the page is very short.
  static const double minimumLandscapeDanmakuHeight = 96;

  /// Width the side panel keeps in the portrait-source split.
  static const double minimumDesktopSplitPanelWidth = 240;

  final Widget video;
  final Widget resolution;
  final Widget danmaku;
  final bool showPanel;
  final bool isPortraitSource;
  final double sourceAspectRatio;
  final bool adaptivePortraitHeight;
  final PortraitLayoutMode portraitLayoutMode;

  /// Whether a large window may choose its split topology from the source
  /// orientation. Enabled on Android only, so the desktop player keeps its
  /// long-standing side panel.
  final bool splitBySourceOrientation;

  /// Height reserved for the danmaku list under a stacked landscape source.
  ///
  /// The video keeps the remaining height, so a wide-and-short window (an
  /// unfolded foldable rotated 90°) can no longer push the list to nothing.
  final double landscapeDanmakuHeight;
  final VoidCallback? onEnterLandscapeFullscreen;
  final VoidCallback? onEnterPortraitFullscreen;

  /// Source aspect with a safe fallback for unknown or degenerate values.
  double get _sourceAspectRatio => sourceAspectRatio.isFinite && sourceAspectRatio > 0 ? sourceAspectRatio : 16 / 9;

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
        switch (resolveLivePlayNormalLayout(
          width: constraints.maxWidth,
          isPortraitSource: isPortraitSource,
          splitBySourceOrientation: splitBySourceOrientation,
        )) {
          case LivePlayNormalLayoutKind.portraitStack:
            return _buildPortraitStack(context, constraints);
          case LivePlayNormalLayoutKind.landscapeStack:
            // A landscape programme in a large window stacks like a folded
            // phone, but the list keeps a guaranteed floor so a rotated
            // unfolded window cannot starve it.
            return _buildLandscapeStack(context, constraints);
          case LivePlayNormalLayoutKind.desktopSplit:
            return _buildDesktopSplit(context, constraints);
        }
      },
    );
  }

  Widget _buildPortraitStack(BuildContext context, BoxConstraints constraints) {
    if (portraitLayoutMode == PortraitLayoutMode.compatibility) {
      // 「兼容 16:9」owns the video height itself instead of falling back to a
      // fixed 16:9 box, which is what shrank a portrait programme into a
      // letterboxed strip after v3.1.3.
      return _buildStackedColumn(
        context,
        key: 'live-play-portrait-stack',
        videoArea: SizedBox(
          key: const ValueKey('live-play-compatibility-video'),
          width: constraints.maxWidth,
          height: resolveCompatibilityVideoHeight(
            availableWidth: constraints.maxWidth,
            availableHeight: constraints.maxHeight,
            sourceAspectRatio: sourceAspectRatio,
          ),
          child: ColoredBox(color: Colors.black, child: video),
        ),
      );
    }
    if (isPortraitSource && adaptivePortraitHeight) {
      return PortraitLiveRoomLayout(
        video: video,
        resolution: resolution,
        danmaku: danmaku,
        mode: portraitLayoutMode,
        onEnterLandscapeFullscreen: onEnterLandscapeFullscreen,
        onEnterPortraitFullscreen: onEnterPortraitFullscreen,
      );
    }
    return _buildStackedColumn(context, key: 'live-play-portrait-stack', videoArea: video);
  }

  Widget _buildStackedColumn(BuildContext context, {required String key, required Widget videoArea}) {
    return Column(
      key: ValueKey(key),
      children: [
        videoArea,
        resolution,
        const Divider(height: 1),
        Expanded(
          key: const ValueKey('live-play-portrait-danmaku'),
          child: ColoredBox(color: Theme.of(context).colorScheme.surface, child: danmaku),
        ),
      ],
    );
  }

  Widget _buildLandscapeStack(BuildContext context, BoxConstraints constraints) {
    final availableHeight = constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0;
    final configured = landscapeDanmakuHeight.isFinite ? landscapeDanmakuHeight : defaultLandscapeDanmakuHeight;
    // Keep the list readable, but never take more than 60% of a short page:
    // a rotated unfolded window is wide and shallow, so an unclamped floor
    // would invert the problem and starve the video instead.
    final upperBound = math.max(minimumLandscapeDanmakuHeight, availableHeight * 0.6);
    final reserved = configured.clamp(minimumLandscapeDanmakuHeight, upperBound);
    return Column(
      key: const ValueKey('live-play-landscape-stack'),
      children: [
        // The video keeps the leftover height and is laid out from the source
        // aspect, so a wide window no longer lets the 16:9 box claim the page.
        Expanded(
          child: Center(
            child: AspectRatio(aspectRatio: _sourceAspectRatio, child: video),
          ),
        ),
        resolution,
        const Divider(height: 1),
        SizedBox(
          key: const ValueKey('live-play-landscape-danmaku'),
          height: reserved,
          child: ColoredBox(color: Theme.of(context).colorScheme.surface, child: danmaku),
        ),
      ],
    );
  }

  Widget _buildDesktopSplit(BuildContext context, BoxConstraints constraints) {
    final maxWidth = constraints.maxWidth;
    final maxHeight = constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0;
    final panelWidth = (maxWidth * 0.34).clamp(300.0, 400.0);
    final double videoWidth;
    if (_sourceAspectRatio < 1) {
      // A portrait programme is taller than it is wide. Deriving the video
      // column from the source aspect keeps the picture edge-to-edge instead
      // of centring a 9:16 strip inside a 16:9 letterbox, and the width it
      // frees up goes to the danmaku list.
      final byHeight = maxHeight * _sourceAspectRatio;
      final ceiling = math.max(minimumDesktopSplitPanelWidth, maxWidth - minimumDesktopSplitPanelWidth);
      videoWidth = byHeight.clamp(0.0, ceiling);
    } else {
      videoWidth = math.max(0.0, maxWidth - panelWidth);
    }
    return Row(
      key: const ValueKey('live-play-desktop-split'),
      children: [
        SizedBox(
          key: const ValueKey('live-play-desktop-video'),
          width: videoWidth,
          child: Center(
            child: AspectRatio(aspectRatio: _sourceAspectRatio, child: video),
          ),
        ),
        Expanded(
          child: SizedBox(
            key: const ValueKey('live-play-desktop-panel'),
            child: Column(
              children: [
                resolution,
                const Divider(height: 1),
                Expanded(child: danmaku),
              ],
            ),
          ),
        ),
      ],
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
    if (oldWidget.mode != widget.mode ||
        (oldWidget.onEnterPortraitFullscreen != null && widget.onEnterPortraitFullscreen == null)) {
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
          // Leave a final animated travel segment for the fullscreen request.
          // If dragging reaches the animation target, AnimatedSlide has no
          // transition to finish and its onEnd callback never fires.
          _dismissOffset = (_dismissOffset + remaining).clamp(0.0, panelHeight).toDouble();
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
      _requestPortraitFullscreen(panelHeight);
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

  void _requestPortraitFullscreen(double panelHeight) {
    if (_entryPending || widget.onEnterPortraitFullscreen == null) return;
    setState(() {
      _entryPending = true;
      _settling = true;
      _dismissOffset = panelHeight + 36;
    });
  }

  void _settlePanelHeight(double panelHeight) {
    if (_entryPending) return;
    setState(() {
      _settling = true;
      _dismissOffset = 0;
      _panelHeight = panelHeight;
    });
  }

  void _completePanelAnimation() {
    if (!_entryPending || !mounted) return;
    // The animation, not an independent timer, owns the request. A changed
    // mode/disabled action clears the pending state in didUpdateWidget.
    _entryPending = false;
    try {
      widget.onEnterPortraitFullscreen?.call();
    } finally {
      // The controller may decline entry after its current-source check.
      // If this layout remains mounted, restore a usable sheet. Accepted
      // navigation replaces this layout on the same next build.
      if (mounted) {
        setState(() {
          _settling = true;
          _dismissOffset = 0;
        });
      }
    }
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
            // Backdrop for the dismiss slide: the video area stops at the
            // sheet's top edge, so the gap the sheet uncovers must stay black
            // instead of showing the page behind the room.
            const ColoredBox(color: Colors.black),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              // The video owns only the space the danmaku sheet leaves. Tying
              // it to the live sheet height is what makes resizing the list
              // re-lay-out the picture instead of covering it.
              bottom: current,
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
                onEnd: _completePanelAnimation,
                child: Material(
                  key: const ValueKey('live-play-portrait-sheet'),
                  color: Theme.of(context).colorScheme.surface,
                  elevation: 10,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    key: const ValueKey('live-play-portrait-sheet-scroll'),
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      // Keep controls and the input usable when the keyboard,
                      // split screen or PiP animation reduces the room bounds.
                      // This wrapper stays mounted even when no scrolling is
                      // needed, preserving input focus and the video sibling.
                      height: current.clamp(240.0, double.infinity),
                      child: Column(
                        children: [
                          Semantics(
                            label: i18n('portrait_panel_resize'),
                            value: '${current.round()} px',
                            hint: i18n('portrait_panel_resize_hint'),
                            increasedValue: current < range.maximum
                                ? '${(current < range.middle ? range.middle : range.maximum).round()} px'
                                : null,
                            decreasedValue: current > range.minimum
                                ? '${(current > range.middle ? range.middle : range.minimum).round()} px'
                                : widget.onEnterPortraitFullscreen == null
                                ? null
                                : i18n('portrait_fullscreen_enter_hint'),
                            onTap: widget.onEnterPortraitFullscreen == null
                                ? null
                                : () => _requestPortraitFullscreen(current),
                            onIncrease: current < range.maximum
                                ? () => _settlePanelHeight(current < range.middle ? range.middle : range.maximum)
                                : null,
                            onDecrease: current > range.minimum
                                ? () => _settlePanelHeight(current > range.middle ? range.middle : range.minimum)
                                : widget.onEnterPortraitFullscreen == null
                                ? null
                                : () => _requestPortraitFullscreen(current),
                            child: GestureDetector(
                              key: const ValueKey('live-play-portrait-sheet-handle'),
                              behavior: HitTestBehavior.opaque,
                              dragStartBehavior: DragStartBehavior.down,
                              onTap: widget.onEnterPortraitFullscreen == null
                                  ? null
                                  : () => _requestPortraitFullscreen(current),
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
                                height: kMinInteractiveDimension,
                                child: Center(
                                  child: widget.onEnterPortraitFullscreen == null
                                      ? Container(
                                          width: 38,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.onSurfaceVariant
                                                .withValues(alpha: 0.30),
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
                          ),
                          widget.resolution,
                          const Divider(height: 1),
                          Expanded(key: const ValueKey('live-play-portrait-danmaku'), child: widget.danmaku),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.onEnterLandscapeFullscreen != null && constraints.maxWidth >= 72 && constraints.maxHeight >= 72)
              Positioned.fill(
                child: CustomSingleChildLayout(
                  delegate: _PortraitFullscreenActionLayout(bottom: current + 12 - _dismissOffset),
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.68),
                    borderRadius: BorderRadius.circular(24),
                    clipBehavior: Clip.antiAlias,
                    child: Tooltip(
                      message: i18nOr('enter_landscape_fullscreen', '横屏全屏'),
                      child: InkWell(
                        key: const ValueKey('portrait-landscape-fullscreen'),
                        onTap: widget.onEnterLandscapeFullscreen,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: kMinInteractiveDimension,
                            minHeight: kMinInteractiveDimension,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.screen_rotation_rounded, color: Colors.white, size: 20),
                                if (constraints.maxWidth >= 160) ...[
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      i18nOr('enter_landscape_fullscreen', '横屏全屏'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
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

class _PortraitFullscreenActionLayout extends SingleChildLayoutDelegate {
  const _PortraitFullscreenActionLayout({required this.bottom});

  final double bottom;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(Size((constraints.maxWidth - 24).clamp(48.0, 180.0), constraints.maxHeight));

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    (size.width - childSize.width - 12).clamp(0.0, size.width - childSize.width),
    // Anchor using the measured height, not a fixed icon-button estimate: large
    // accessibility text must stay inside the viewport during a PiP resize.
    (size.height - bottom - childSize.height).clamp(0.0, size.height - childSize.height),
  );

  @override
  bool shouldRelayout(_PortraitFullscreenActionLayout oldDelegate) => bottom != oldDelegate.bottom;
}

@visibleForTesting
({double minimum, double middle, double maximum, double initial}) portraitPanelRange(
  double availableHeight,
  PortraitLayoutMode mode,
) {
  final height = availableHeight.isFinite ? availableHeight.clamp(0.0, double.infinity).toDouble() : 0.0;
  final minimum = (height * 0.27).clamp(190.0, 250.0).clamp(0.0, height).toDouble();
  // Preserve 120 dp of video whenever the controls also fit. Transient small
  // bounds must never pass an inverted range to clamp.
  final maximumAllowed = (height - 120).clamp(minimum, height).toDouble();
  final maximum = (height * 0.68).clamp(minimum, maximumAllowed).toDouble();
  final middle = (height * 0.44).clamp(minimum, maximum).toDouble();
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
        child: Container(
          key: const ValueKey('pip'),
          color: Colors.transparent,
          child: manager.buildPiPOverlay(
            pictureCover: Obx(
              () =>
                  pictureCoverFor(
                    audioOnly: manager.isAudioOnlyMode,
                    dummyVideo: manager.isDummyVideo.value,
                    room: controller.state.value.room.detail,
                  ) ??
                  const SizedBox.shrink(),
            ),
          ),
        ),
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
        final fullscreenDisplayMode = mode == VideoMode.portraitFullscreen
            ? settings.portraitFullscreenDisplayMode
            : PortraitFullscreenDisplayMode.ambient;
        final cover = resolvePortraitFullscreenBackgroundUrl(
          detailCover: detail?.cover,
          roomCover: controller.room.cover,
          detailAvatar: detail?.avatar,
          roomAvatar: controller.room.avatar,
        );
        presentation = PortraitFullscreenPresentation(
          coverUrl: cover,
          mode: fullscreenDisplayMode,
          child: LivePlayVideo(
            controller: controller,
            expandToParent: true,
            transparentSurface: true,
            videoViewportAspectRatio: manager.currentPresentationAspectRatio,
            portraitFullscreenDisplayMode: mode == VideoMode.portraitFullscreen ? fullscreenDisplayMode : null,
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
          final layoutMode = settings.portraitLayoutMode;
          final narrowWindow = MediaQuery.sizeOf(context).width <= livePlayPortraitStackMaxWidth;
          final useAdaptivePortraitFrame =
              narrowWindow &&
              isPortrait &&
              settings.enablePortraitStreamAdaptation.v &&
              settings.portraitAdaptiveHeight.v &&
              layoutMode != PortraitLayoutMode.compatibility;
          // 「兼容 16:9」derives the video area from the source aspect, so the
          // surface has to fill that box instead of adding its own 16:9 frame.
          final useCompatibilityFrame = narrowWindow && layoutMode == PortraitLayoutMode.compatibility;
          // A wide window owns its video box too: both topologies lay the
          // surface out from the source aspect (side split) or inside a
          // reserved-height column (stacked landscape).
          final useWideWindowFrame = !narrowWindow;
          return LivePlayNormalLayout(
            video: LivePlayVideo(
              controller: controller,
              expandToParent: useAdaptivePortraitFrame || useCompatibilityFrame || useWideWindowFrame,
            ),
            resolution: ResolutionsRow(controller: controller),
            danmaku: _buildDanmaku(),
            showPanel: controller.site != Sites.iptvSite,
            isPortraitSource: isPortrait,
            sourceAspectRatio: manager.currentPresentationAspectRatio,
            adaptivePortraitHeight: settings.enablePortraitStreamAdaptation.v && settings.portraitAdaptiveHeight.v,
            portraitLayoutMode: layoutMode,
            splitBySourceOrientation: PlatformUtils.isAndroid,
            landscapeDanmakuHeight: settings.landscapeDanmakuHeight.v,
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
      final player = GlobalPlayerService.instance.player;
      if (player.isSystemFullscreen.value || player.isWindowFullscreen.value) {
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
  const PortraitFullscreenPresentation({
    super.key,
    required this.coverUrl,
    required this.child,
    this.mode = PortraitFullscreenDisplayMode.ambient,
  });

  final String coverUrl;
  final Widget child;
  final PortraitFullscreenDisplayMode mode;

  @override
  Widget build(BuildContext context) {
    final showAmbient = mode == PortraitFullscreenDisplayMode.ambient || mode == PortraitFullscreenDisplayMode.balanced;
    return ColoredBox(
      key: const ValueKey('fullscreen-portrait-presentation'),
      color: Colors.black,
      child: Stack(
        key: ValueKey('fullscreen-portrait-mode-${mode.name}'),
        fit: StackFit.expand,
        children: [
          if (showAmbient) ...[
            const DecoratedBox(
              key: ValueKey('fullscreen-portrait-ambient-fallback'),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF342B3A), Color(0xFF171B27), Color(0xFF2A202B)],
                ),
              ),
            ),
            if (coverUrl.isNotEmpty)
              ImageFiltered(
                key: const ValueKey('fullscreen-portrait-ambient-image'),
                imageFilter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28, tileMode: TileMode.mirror),
                child: Transform.scale(
                  scale: 1.14,
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
            const ColoredBox(key: ValueKey('fullscreen-portrait-ambient-veil'), color: Color(0x26000000)),
          ],
          RepaintBoundary(child: child),
        ],
      ),
    );
  }
}
