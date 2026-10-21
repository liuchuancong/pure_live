import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveRoom;
import 'package:pure_live/features/room/danmaku_pane.dart' show DanmakuPane;
import 'package:pure_live/features/room/portrait_rules.dart';
import 'package:pure_live/features/room/room_controller.dart' show RoomController, RoomPresentation, RoomState;
import 'package:pure_live/features/room/room_providers.dart' show RoomIdentity;
import 'package:pure_live/features/room/widgets/room_bar_parts.dart' show PortraitEntryHint;
import 'package:pure_live/features/room/widgets/room_header_parts.dart';
import 'package:pure_live/features/room/widgets/room_on_video_controls.dart';
import 'package:pure_live/features/room/widgets/room_resolution_row.dart';
import 'package:pure_live/features/room/widgets/room_video_surface.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/system/configuration/app_preferences.dart';
import 'package:pure_live/system/configuration/app_preferences_providers.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The upright phone room — the reference's `portraitStack` and, for a vertical
/// source, its `PortraitLiveRoomLayout`.
///
/// Two shapes share this file because they are the same device answering the
/// same question — where does the chat go when the picture is tall — and a
/// phone cannot spare the width for a rail. A landscape phone, a tablet and a
/// desktop window each answer it differently, and they live in their own files.
///
/// The sheet's own state lives here, in the layout, not in the controller: the
/// reference keeps the panel height, the dismiss travel and the pending
/// fullscreen entry in `_PortraitLiveRoomLayoutState`, because they are facts
/// about this shape of screen, and a rotation disposes them with it.
final class RoomPhonePortraitLayout extends ConsumerStatefulWidget {
  /// The phone layout for [identity].
  const new({
    required this.identity,
    required this.controller,
    required this.state,
    required this.room,
    required this.siteName,
    super.key,
  });

  /// The room on screen.
  final RoomIdentity identity;

  /// The page logic.
  final RoomController controller;

  /// The snapshot it renders.
  final RoomState state;

  /// The detail, or the route's stub before it arrives.
  final LiveRoom room;

  /// The platform's display name for the header's second line.
  final String siteName;

  @override
  ConsumerState<RoomPhonePortraitLayout> createState() => _RoomPhonePortraitLayoutState();
}

final class _RoomPhonePortraitLayoutState extends ConsumerState<RoomPhonePortraitLayout> {
  double? _panelHeight;
  double _dismissOffset = 0;
  bool _settling = false;
  bool _entryPending = false;

  /// Portrait fullscreen entry is the reference's Android affordance — a
  /// sideways rotation the OS owns, offered from the sheet handle itself.
  bool get _entryEnabled =>
      defaultTargetPlatform == TargetPlatform.android && widget.state.presentation == RoomPresentation.normal;

  AppPreferences get _preferences => ref.watch(appPreferencesProvider);

  /// The barrage bounds the vertical picture gets (竖屏弹幕布局).
  ({int rows, double? area, bool hidden}) get _barrage =>
      portraitBarrage(_preferences, globalRows: widget.state.presentation == RoomPresentation.normal ? 2 : 3);

  @override
  void didUpdateWidget(covariant RoomPhonePortraitLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A source that stopped being vertical (a stream switch) rebuilds the plain
    // stack; the panel draft is meaningless in the new shape.
    if (oldWidget.state.isVerticalSource != widget.state.isVerticalSource ||
        oldWidget.state.presentation != widget.state.presentation) {
      _panelHeight = null;
      _dismissOffset = 0;
      _entryPending = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state.presentation != RoomPresentation.normal) {
      return _immersive(context);
    }
    final bar = _bar(context);
    // A vertical source cannot be letterboxed into 16/9 without losing half of
    // it, so it takes the canvas and the pane rides a sheet over its foot —
    // when the adaptation and the layout-mode answers allow that shape.
    if (usesPortraitShape(_preferences, verticalSource: widget.state.isVerticalSource)) {
      return Column(
        children: [
          bar,
          Expanded(child: _sheet(context)),
        ],
      );
    }
    return Column(
      children: [
        bar,
        RoomVideoSurface(
          identity: widget.identity,
          controller: widget.controller,
          state: widget.state,
          aspectRatio: widget.state.sourceAspectRatio,
          compact: true,
        ),
        RoomResolutionRow(identity: widget.identity, controller: widget.controller, state: widget.state),
        const PureDivider(),
        Expanded(
          child: ColoredBox(
            color: PureTheme.of(context).colors.bgContainer,
            child: DanmakuPane(identity: widget.identity, dark: false),
          ),
        ),
      ],
    );
  }

  /// The header row: who is streaming, and the three actions a phone can afford.
  Widget _bar(BuildContext context) {
    final theme = PureTheme.of(context);
    return Material(
      color: theme.colors.bgElevated,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 58,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: RoomIdentityBadge(room: widget.room, siteName: widget.siteName, size: 38),
                ),
                RoomFollowButton(room: widget.room, compact: true),
                RoomRecordButton(identity: widget.identity, room: widget.room),
                RoomOverflowMenu(identity: widget.identity, controller: widget.controller, state: widget.state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The tall-source shape: the picture fills, the pane is a three-stop sheet
  /// over its foot — the reference's `PortraitLiveRoomLayout`.
  ///
  /// The drag answers in two currencies: the panel's height between the three
  /// stops, and, past the lowest stop, the dismiss travel that ends in
  /// portrait fullscreen. A downward fling first collapses the sheet to the
  /// minimum, and only the overflow past it counts toward the exit.
  Widget _sheet(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final stops = applyPanelStops(portraitPanelRange(height), _preferences);
        final current = (_panelHeight ?? stops.initial).clamp(stops.minimum, stops.maximum);
        return Stack(
          key: const ValueKey('live-play-portrait-stack'),
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: ColoredBox(
                key: const ValueKey('live-play-adaptive-video-frame'),
                color: Colors.black,
                child: RepaintBoundary(
                  child: RoomVideoSurface(
                    identity: widget.identity,
                    controller: widget.controller,
                    state: widget.state,
                    compact: true,
                    barrageRows: _barrage.rows,
                    barrageArea: _barrage.area,
                    barrageHidden: _barrage.hidden,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: current,
              child: AnimatedSlide(
                offset: Offset(0, current <= 0 ? 0 : (_dismissOffset / current).clamp(0.0, 1.2)),
                duration: _settling ? const Duration(milliseconds: 180) : Duration.zero,
                curve: Curves.easeOutCubic,
                onEnd: _completePanelAnimation,
                child: Material(
                  key: const ValueKey('live-play-portrait-sheet'),
                  color: PureTheme.of(context).colors.bgContainer,
                  elevation: 10,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    key: const ValueKey('live-play-portrait-sheet-scroll'),
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      // Keep controls and the input usable when the keyboard,
                      // split screen or a PiP animation reduces the bounds —
                      // the wrapper stays mounted even when nothing scrolls.
                      height: current.clamp(240.0, double.infinity),
                      child: Column(
                        children: [
                          _handle(context, current, stops),
                          RoomResolutionRow(
                            identity: widget.identity,
                            controller: widget.controller,
                            state: widget.state,
                            dense: true,
                          ),
                          const PureDivider(),
                          Expanded(
                            key: const ValueKey('live-play-portrait-danmaku'),
                            child: DanmakuPane(identity: widget.identity, dark: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // The landscape escape the reference floats over the video,
            // hugging the sheet's top edge as it moves.
            if (constraints.maxWidth >= 72 && constraints.maxHeight >= 72)
              Positioned.fill(
                child: CustomSingleChildLayout(
                  delegate: _LandscapeActionLayout(bottom: current + 12 - _dismissOffset),
                  child: _LandscapePill(
                    onTap: () => widget.controller.setPresentation(RoomPresentation.fullscreen),
                    visible: widget.state.presentation == RoomPresentation.normal,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// The grab bar: a drag handle, and on Android the entry hint — the
  /// reference's handle answers to tap, drag and semantics alike.
  Widget _handle(
    BuildContext context,
    double current,
    ({double minimum, double middle, double maximum, double initial}) stops,
  ) {
    final theme = PureTheme.of(context);
    return Semantics(
      label: context.t.room.portraitPanelResize,
      value: '${current.round()} px',
      hint: context.t.room.portraitPanelResizeHint,
      increasedValue: current < stops.maximum
          ? '${(current < stops.middle ? stops.middle : stops.maximum).round()} px'
          : null,
      decreasedValue: current > stops.minimum
          ? '${(current > stops.middle ? stops.middle : stops.minimum).round()} px'
          : !_entryEnabled
          ? null
          : context.t.room.enterPortraitFullscreenHint,
      onTap: !_entryEnabled ? null : () => _requestPortraitFullscreen(current),
      onIncrease: current < stops.maximum
          ? () => _settlePanelHeight(current < stops.middle ? stops.middle : stops.maximum)
          : null,
      onDecrease: current > stops.minimum
          ? () => _settlePanelHeight(current > stops.middle ? stops.middle : stops.minimum)
          : !_entryEnabled
          ? null
          : () => _requestPortraitFullscreen(current),
      child: GestureDetector(
        key: const ValueKey('live-play-portrait-sheet-handle'),
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onTap: !_entryEnabled ? null : () => _requestPortraitFullscreen(current),
        onVerticalDragUpdate: (details) => _updatePanelDrag(details, current, stops.minimum, stops.maximum),
        onVerticalDragEnd: (details) => _finishPanelDrag(details, current, stops),
        onVerticalDragCancel: () => setState(() {
          _settling = true;
          _dismissOffset = 0;
        }),
        child: SizedBox(
          height: kMinInteractiveDimension,
          child: Center(
            child: !_entryEnabled
                ? Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colors.textSecondary.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: theme.colors.primary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          context.t.room.enterPortraitFullscreenHint,
                          key: const ValueKey('portrait-fullscreen-enter-hint'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: theme.colors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  void _updatePanelDrag(DragUpdateDetails details, double current, double minimum, double maximum) {
    if (_entryPending) {
      return;
    }
    final delta = details.delta.dy;
    if (delta == 0) {
      return;
    }
    setState(() {
      _settling = false;
      final panelHeight = (_panelHeight ?? current).clamp(minimum, maximum);
      if (delta > 0) {
        // Downward: collapse toward the minimum first; only the overflow past
        // it dismisses, and dismissal is the fullscreen entry's travel. Leave a
        // final animated segment for the request — AnimatedSlide's onEnd never
        // fires on a transition it does not have to make.
        final collapsible = (panelHeight - minimum).clamp(0.0, double.infinity);
        final collapseDelta = delta.clamp(0.0, collapsible);
        _panelHeight = panelHeight - collapseDelta;
        final remaining = delta - collapseDelta;
        if (_entryEnabled && remaining > 0) {
          _dismissOffset = (_dismissOffset + remaining).clamp(0.0, panelHeight);
        }
        return;
      }
      var upward = -delta;
      final revealDelta = upward.clamp(0.0, _dismissOffset);
      _dismissOffset -= revealDelta;
      upward -= revealDelta;
      if (upward > 0) {
        _panelHeight = (panelHeight + upward).clamp(minimum, maximum);
      }
    });
  }

  void _finishPanelDrag(
    DragEndDetails details,
    double current,
    ({double minimum, double middle, double maximum, double initial}) stops,
  ) {
    if (_entryPending) {
      return;
    }
    final panelHeight = (_panelHeight ?? current).clamp(stops.minimum, stops.maximum);
    final velocity = details.primaryVelocity ?? 0;
    if (_entryEnabled && (velocity > 600 && _dismissOffset > 24 || _dismissOffset >= panelHeight * 0.5)) {
      _requestPortraitFullscreen(panelHeight);
      return;
    }
    // Snap to the stop closest to wherever the drag ended.
    final candidates = <double>[stops.minimum, stops.middle, stops.maximum];
    final snapped = candidates.reduce(
      (best, stop) => (stop - panelHeight).abs() < (best - panelHeight).abs() ? stop : best,
    );
    setState(() {
      _settling = true;
      _dismissOffset = 0;
      _panelHeight = snapped;
    });
  }

  void _requestPortraitFullscreen(double panelHeight) {
    if (_entryPending || !_entryEnabled) {
      return;
    }
    setState(() {
      _entryPending = true;
      _settling = true;
      _dismissOffset = panelHeight + 36;
    });
  }

  void _settlePanelHeight(double panelHeight) {
    if (_entryPending) {
      return;
    }
    setState(() {
      _settling = true;
      _dismissOffset = 0;
      _panelHeight = panelHeight;
    });
  }

  void _completePanelAnimation() {
    if (!_entryPending || !mounted) {
      return;
    }
    // The animation, not an independent timer, owns the request.
    _entryPending = false;
    widget.controller.setPresentation(RoomPresentation.portraitFullscreen);
  }

  /// The immersive phone. A vertical source keeps the reference's ambient
  /// presentation — the picture fitted over its blurred cover; a sideways one
  /// fills the window and lets the surface's own bars own the chrome.
  Widget _immersive(BuildContext context) {
    final state = widget.state;
    if (state.presentation == RoomPresentation.portraitFullscreen && state.isVerticalSource) {
      final preferences = _preferences;
      final displayMode = preferences.portraitDisplayMode;
      final cover = displayMode == 'ambient' || displayMode == 'balanced' ? _ambientCover() : '';
      final veil = switch (displayMode) {
        'balanced' => const Color(0x14000000),
        'complete' || 'cover' => null,
        _ => const Color(0x26000000),
      };
      final barrage = portraitBarrage(preferences, globalRows: 3);
      Widget picture = RepaintBoundary(
        child: RoomVideoSurface(
          identity: widget.identity,
          controller: widget.controller,
          state: state,
          immersive: true,
          compact: true,
          twoRows: true,
          // A07.2: the sheet comes back with a deliberate upward fling on
          // the leading half of the picture, as the entry hint says.
          onPortraitRestore: () => widget.controller.setPresentation(RoomPresentation.normal),
          barrageRows: barrage.rows,
          barrageArea: barrage.area,
          barrageHidden: barrage.hidden,
        ),
      );
      // 铺满裁剪 crops the tall picture to the window; the rest fit it and
      // let the backdrop answer for what is left over.
      if (displayMode != 'cover') {
        picture = AspectRatio(aspectRatio: state.sourceAspectRatio, child: picture);
      }
      return ColoredBox(
        key: const ValueKey('fullscreen-portrait-presentation'),
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cover.isNotEmpty)
              ImageFiltered(
                key: const ValueKey('fullscreen-portrait-ambient-image'),
                imageFilter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28, tileMode: ui.TileMode.mirror),
                child: Transform.scale(
                  scale: displayMode == 'balanced' ? 1.0 : 1.14,
                  child: CachedNetworkImage(
                    imageUrl: cover,
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    placeholder: (_, _) => const SizedBox.expand(),
                    errorWidget: (_, _, _) => const SizedBox.expand(),
                  ),
                ),
              ),
            if (cover.isEmpty)
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
            if (veil case final shade?)
              ColoredBox(key: const ValueKey('fullscreen-portrait-ambient-veil'), color: shade),
            SafeArea(child: displayMode == 'cover' ? picture : Center(child: picture)),
            if (preferences.showPortraitDiagnostics) _diagnostics(context, state),
            // The hint after entering (3.x `PortraitFullscreenEntryHint`):
            // what the fling does, above the bars, gone in three seconds.
            const PortraitEntryHint(key: ValueKey('portrait-entry-hint'), bottom: 76),
          ],
        ),
      );
    }
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: RoomVideoSurface(
          identity: widget.identity,
          controller: widget.controller,
          state: state,
          immersive: true,
          compact: true,
          barrageRows: 3,
        ),
      ),
    );
  }

  /// The 显示识别状态 read-out: the raw frame, its ratio, the shape decision and
  /// the rule that produced it — what the reference's diagnostics chip says.
  Widget _diagnostics(BuildContext context, RoomState state) {
    final width = state.videoWidth;
    final height = state.videoHeight;
    final ratio = state.sourceAspectRatio;
    final verdict = state.isVerticalSource ? 'portrait' : 'landscape';
    final rules =
        '${_preferences.portraitLayoutMode}/${_preferences.portraitFullscreenPolicy}'
        '/${_preferences.portraitDisplayMode}';
    final text = '${width ?? 0}×${height ?? 0}  ${ratio.toStringAsFixed(2)} · $verdict \n$rules';
    return Positioned(
      key: const ValueKey('portrait-diagnostics-chip'),
      left: 12,
      top: 60,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFFB9F6CA), fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
        ),
      ),
    );
  }

  /// The ambient cover, the reference's `resolvePortraitFullscreenBackgroundUrl`:
  /// the room's cover first, the anchor's avatar as the fallback.
  String _ambientCover() {
    final content = widget.room.content;
    for (final value in [content.coverUrl, widget.room.anchor?.avatarUrl]) {
      final candidate = value?.trim() ?? '';
      if (candidate.isNotEmpty) {
        return candidate;
      }
    }
    return '';
  }
}

/// The three stops and the opening height, for a body of [availableHeight] —
/// the reference's `portraitPanelRange`, pixel-faithful: a 27% floor clamped
/// to 190..250, a 68% ceiling that never leaves less than 120 of video, a 44%
/// middle, and the middle to open on.
({double minimum, double middle, double maximum, double initial}) portraitPanelRange(double availableHeight) {
  final height = availableHeight.isFinite ? availableHeight.clamp(0.0, double.infinity) : 0.0;
  final minimum = (height * 0.27).clamp(190.0, 250.0).clamp(0.0, height);
  // Preserve 120 dp of video whenever the controls also fit. Transient small
  // bounds must never pass an inverted range to clamp.
  final maximumAllowed = (height - 120).clamp(minimum, height);
  final maximum = (height * 0.68).clamp(minimum, maximumAllowed);
  final middle = (height * 0.44).clamp(minimum, maximum);
  return (minimum: minimum, middle: middle, maximum: maximum, initial: middle);
}

/// The landscape-fullscreen pill, the reference's `enter_landscape_fullscreen`
/// chip: a dark capsule floating over the video, hugging the sheet's top.
final class _LandscapePill extends StatelessWidget {
  const new({required this.onTap, required this.visible});

  final VoidCallback onTap;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: visible ? 1 : 0,
        child: RoomOnVideoChip(
          key: const ValueKey('portrait-landscape-fullscreen'),
          label: t.room.enterLandscapeFullscreen,
          icon: Icons.screen_rotation_rounded,
          maxLabelWidth: 220,
          onTap: visible ? onTap : null,
        ),
      ),
    );
  }
}

/// Places the pill centred horizontally, 12 above the sheet's top edge — the
/// reference's `_PortraitFullscreenActionLayout`, anchoring on the measured
/// height so large accessibility text stays inside the viewport.
final class _LandscapeActionLayout extends SingleChildLayoutDelegate {
  const new({required this.bottom});

  final double bottom;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(Size((constraints.maxWidth - 24).clamp(48.0, 180.0), constraints.maxHeight));

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    (size.width - childSize.width) / 2,
    (size.height - bottom - childSize.height).clamp(0.0, size.height - childSize.height),
  );

  @override
  bool shouldRelayout(_LandscapeActionLayout oldDelegate) => bottom != oldDelegate.bottom;
}
