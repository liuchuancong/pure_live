import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'package:desen_ui/desen_ui.dart';
import 'package:flame_barrage/flame_barrage.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/gestures.dart' show PointerScrollEvent, kTouchSlop;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart' show LivePlayLine, LiveStreamCodec, LiveStreamFormat;
import 'package:media_core/media_core.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/recorder/recorder.dart';
import 'package:pure_live/modules/live/room/chat/room_message_actions.dart' show showRoomMessageActions;
import 'package:pure_live/modules/live/room/controller/room_controller.dart';
import 'package:pure_live/modules/live/room/page/audio_only_cover.dart' show AudioOnlyCover;
import 'package:pure_live/modules/live/room/page/room_status.dart'
    show RoomPictureAction, RoomPictureDim, RoomPictureKind, pictureStateOf, roomSlowProvider;
import 'package:pure_live/modules/live/room/player/cast_dialog.dart' show showCastDialog;
import 'package:pure_live/modules/live/room/player/compact_danmaku_metrics.dart' show CompactDanmakuMetrics;
import 'package:pure_live/modules/live/room/player/room_barrage_config.dart' show roomBarrageConfig;
import 'package:pure_live/shared/shared.dart';

/// The picture's own ink: the frame is dark whatever the app's theme, so
/// the bars, the state overlay and the position line never borrow the
/// surface's ink (which turns dark-on-dark in a light theme).
const Color _onVideo = playerInk;
const Color _onVideoMuted = playerInkMuted;
const Color _onVideoSubtle = playerInkSubtle;
const Color _onVideoHover = playerInkHover;

/// The stage around and behind the video: always black, in every theme —
/// a missing frame reads as a dark screen, never as a flash of the theme's
/// surface while the window changes size.
const Color kPlayerStageColor = Color(0xFF000000);

/// One action the overlay offers, pressed through the room controller.
final class PictureActionButton extends ConsumerWidget {
  const PictureActionButton({required this.action, this.autofocus = false, super.key});

  final RoomPictureAction action;

  /// Takes the focus when first built (the TV room's first stop while the
  /// stream is not playable).
  final bool autofocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final controller = ref.read(roomProvider.notifier);
    final room = ref.read(roomProvider).room;
    final (label, onPressed) = switch (action) {
      RoomPictureAction.back => (
        t.common.close,
        () async {
          final presentation = ref.read(roomPresentationProvider);
          final player = ref.read(roomProvider).handle?.id;
          if (presentation != PresentationMode.normal && player != null) {
            await ref.read(roomPresentationProvider.notifier).exit(player);
          } else if (ref.read(roomLeaveProvider) case final closeWindow?) {
            // A room window's native close may take the view away before the
            // page's dispose runs; stopping the room first is what keeps the
            // sound from outliving it.
            await controller.close();
            await closeWindow();
          } else if (context.mounted) {
            // A clone starts at the room route, so there is nothing to pop;
            // the picture's back still has to leave the room.
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RouteNames.popular);
            }
          }
        },
      ),
      RoomPictureAction.refresh => (
        t.common.retry,
        room == null ? null : () => unawaited(controller.open(platform: room.ref.platform, roomId: room.ref.roomId)),
      ),
      RoomPictureAction.retry => (t.common.retry, () => unawaited(controller.retry())),
      RoomPictureAction.switchLine => (
        t.room.lineLabel,
        () {
          final current = ref.read(roomProvider);
          if (current.lines.length < 2) return;
          unawaited(controller.selectLine((current.lineIndex + 1) % current.lines.length));
        },
      ),
      RoomPictureAction.playAgain => (t.room.play, () => unawaited(controller.retry())),
    };
    return TvFocusScale(
      child: DsButton(onPressed: onPressed, autofocus: autofocus, child: Text(label)),
    );
  }
}

/// The player surface the room owns: media_core's bare picture
/// (`MediaPlayerView`) with the app's own control layer over it.
///
/// The layer carries what a live room needs: play/pause, mute and volume,
/// the live position, the quality and the line (menus over the site's own
/// catalogues), the flying danmaku's switch, the DLNA cast entry, and the
/// three presentation buttons — system fullscreen, window fullscreen and
/// picture-in-picture — each routed through media_core's presentation
/// drivers. It hides while the stream plays and a tap wakes it.
final class PlayerSurface extends ConsumerStatefulWidget {
  /// Shows [roomState]'s stream with the room's own controls.
  const PlayerSurface({
    required this.roomState,
    required this.barrage,
    required this.onLeave,
    this.onCloseRoom,
    this.immersive = false,
    this.keepControls = false,
    this.autofocusFirstControl = false,
    this.portraitFullscreen = false,
    this.portraitDisplay = PortraitFullscreenMode.ambient,
    this.portraitDanmaku = PortraitDanmakuMode.followGlobal,
    this.canEnterPortraitFullscreen = false,
    this.onPortraitFullscreen,
    this.onPortraitSwipe,
    super.key,
  });

  /// The room's state (the picture and the playback facts).
  final RoomState roomState;

  /// The room's flying danmaku engine; null until the pipeline exists.
  final BarrageController? barrage;

  /// Leaves the surface: the page pops in its inline layout, and leaves the
  /// presentation mode while one holds the window.
  final VoidCallback onLeave;

  /// Stops the room and leaves it. The compact window's close button uses
  /// this: closing a small window means "I am done", not "return to the
  /// page". Null falls back to [onLeave].
  final VoidCallback? onCloseRoom;

  /// Whether the surface fills the page (fullscreen, window fullscreen or
  /// PiP), where the bar starts visible and the top bar carries the way out.
  final bool immersive;

  /// Keeps the bars on screen (a TV room): a remote has no pointer to wake
  /// them, so hidden controls would strand the focus.
  final bool keepControls;

  /// Focuses the play button (or the first picture action) when the bars
  /// first build: the TV room's starting stop for the remote.
  final bool autofocusFirstControl;

  /// Whether the room is in its portrait full-screen presentation.
  final bool portraitFullscreen;

  /// How the portrait picture fills that surface.
  final PortraitFullscreenMode portraitDisplay;

  /// Where the flying layer sits in that surface.
  final PortraitDanmakuMode portraitDanmaku;

  /// Whether a portrait stream offers the entry button.
  final bool canEnterPortraitFullscreen;

  /// Enter portrait full screen (the page owns the presentation).
  final VoidCallback? onPortraitFullscreen;

  /// A vertical swipe in the middle third of the portrait full screen: +1
  /// for the next room, -1 for the previous (the page owns the list).
  final ValueChanged<int>? onPortraitSwipe;

  @override
  ConsumerState<PlayerSurface> createState() => _PlayerSurfaceState();
}

final class _PlayerSurfaceState extends ConsumerState<PlayerSurface> {
  bool _controlsVisible = true;
  Timer? _hideTimer;

  /// A stream picker panel is open over the picture: the bars stay while it
  /// is, or the panel would vanish under the pointer that is using it.
  bool _panelOpen = false;

  StreamSubscription<PlayerTransportState>? _transportSub;

  /// The volume the viewer is dragging, and the bar that shows it; null
  /// when no drag or wheel is in flight.
  double? _volumeHud;
  Timer? _volumeHudTimer;
  double _dragVolume = 0;

  /// A vertical drag in the portrait full screen's middle third that may
  /// switch rooms instead of changing the volume.
  double _portraitSwipeDy = 0;
  bool _swipingPortrait = false;

  /// The flying danmaku held under the finger from pointer-down until the
  /// tap is confirmed (its panel opens) or the gesture turns out to be a
  /// double tap, a drag or a scroll (it is released).
  BarrageItem? _heldDanmaku;
  Offset? _holdOrigin;
  Offset? _pressLocal;

  /// Watches the bars' controls: while one of them holds the focus the
  /// bars stay (a remote cannot tap the picture to bring them back).
  final FocusNode _controlsFocus = FocusNode(
    debugLabel: 'player controls',
    canRequestFocus: false,
    skipTraversal: true,
  );

  /// The transport facts the bar reads (position, buffer, volume); the
  /// handle's ValueStream updates faster than the room state's rebuilds.
  PlayerTransportState? _transport;

  PlayerHandle? _boundHandle;

  @override
  void initState() {
    super.initState();
    _controlsFocus.addListener(_onControlsFocus);
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _volumeHudTimer?.cancel();
    _releaseDanmaku();
    _controlsFocus
      ..removeListener(_onControlsFocus)
      ..dispose();
    unawaited(_transportSub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  void _onControlsFocus() {
    if (_controlsFocus.hasFocus) {
      _wake();
      return;
    }
    // The remote left the bars: let them settle away as before.
    _scheduleHide();
  }

  void _watchTransport(PlayerHandle? handle) {
    if (identical(handle, _boundHandle)) return;
    unawaited(_transportSub?.cancel() ?? Future<void>.value());
    _boundHandle = handle;
    _transportSub = handle?.playbackStream.listen((state) {
      if (mounted) setState(() => _transport = state);
    });
  }

  /// Shows the bar and, while the stream plays, lets it settle away again.
  ///
  /// The pointer calls this on every move, so a bar that is already up only
  /// restarts its timer instead of rebuilding the surface.
  void _wake() {
    if (mounted && !_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  /// A picker panel opened or closed: an open one holds the bars up until it
  /// is done with.
  void _setPanelOpen(bool open) {
    if (_panelOpen == open) return;
    _panelOpen = open;
    if (open) {
      _hideTimer?.cancel();
    } else {
      _scheduleHide();
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_panelOpen) return;
    if (!widget.roomState.playback.playing) return;
    // A TV room keeps its bars: with no pointer there is no way to wake a
    // hidden bar, and the focused control would go with it.
    if (widget.keepControls || _controlsFocus.hasFocus) return;
    // The viewer's own delay (the 画面与浮窗 setting).
    final seconds = ref.read(playbackSettingsProvider).controlsAutoHideSeconds;
    _hideTimer = Timer(Duration(seconds: seconds), () {
      if (mounted && widget.roomState.playback.playing && !_controlsFocus.hasFocus) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    // The TV room cannot tap: its bars never hide, so a control always
    // exists for the remote to come back to.
    if (widget.keepControls) {
      _wake();
      return;
    }
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _wake();
    }
  }

  /// A tap on the picture: with tap actions on, a message under the finger
  /// is held while its panel shows; a tap that hits nothing — or every tap
  /// with the switch off — wakes or dismisses the bars as before.
  Future<void> _onPictureTap() async {
    if (!ref.read(danmakuTapInteractionProvider)) {
      _releaseDanmaku();
      _toggleControls();
      return;
    }
    final item = _takeHeldDanmaku();
    if (item == null) {
      _toggleControls();
      return;
    }
    await _showDanmakuActions(item);
  }

  /// A long press pins the message under the finger and opens the same
  /// actions as a tap; empty space keeps the normal controls behaviour.
  Future<void> _onPictureLongPress() async {
    if (!ref.read(danmakuLongPressInteractionProvider)) {
      _releaseDanmaku();
      return;
    }
    final item = _takeHeldDanmaku();
    if (item == null) return;
    await _showDanmakuActions(item);
  }

  BarrageItem? _takeHeldDanmaku() {
    var item = _heldDanmaku;
    final press = _pressLocal;
    if (item == null && !ref.read(danmakuHoldProvider) && press != null) {
      // Holding is off, so the message was not frozen on pointer-down; find
      // it under the press now, just before the panel opens.
      item = widget.barrage?.pauseItemAt(press.dx, press.dy);
    }
    _heldDanmaku = null;
    _holdOrigin = null;
    _pressLocal = null;
    return item;
  }

  Future<void> _showDanmakuActions(BarrageItem item) async {
    try {
      await showRoomMessageActions(
        context,
        ref,
        text: item.content,
        userName: item.userName ?? '',
        // The viewer's own echo is the only local message on the flying
        // layer; it carries no platform identity to block.
        isLocal: item.id?.startsWith('local-') ?? false,
      );
    } finally {
      widget.barrage?.resumeAllPaused();
    }
  }

  /// Pins the flying danmaku under a finger the moment it goes down, so the
  /// actions target the message the tap started on rather than the one that
  /// has flown there by the time the gesture resolves. Either interaction
  /// switch may own the press: a long press still targets its message with
  /// tap actions off.
  void _holdDanmaku(PointerDownEvent event) {
    if (_holdOrigin != null) return;
    if (!ref.read(danmakuTapInteractionProvider) && !ref.read(danmakuLongPressInteractionProvider)) return;
    _holdOrigin = event.position;
    _pressLocal = event.localPosition;
    if (!ref.read(danmakuHoldProvider)) return;
    final item = widget.barrage?.pauseItemAt(event.localPosition.dx, event.localPosition.dy);
    if (item != null) _heldDanmaku = item;
  }

  /// A finger that moves past the touch slop is a drag, not a press: the
  /// message flies on and the release wakes or dismisses the bars instead.
  void _releaseDanmakuOnMove(PointerMoveEvent event) {
    final origin = _holdOrigin;
    if (origin != null && (event.position - origin).distance > kTouchSlop) _releaseDanmaku();
  }

  /// Lets a held message fly on when the gesture turned out not to be its
  /// tap (a double tap plays or pauses, a drag sets the volume).
  void _releaseDanmaku() {
    _holdOrigin = null;
    _pressLocal = null;
    if (_heldDanmaku == null) return;
    _heldDanmaku = null;
    widget.barrage?.resumeAllPaused();
  }

  /// Shows the volume the viewer is setting and lets the bar go after a
  /// moment on its own.
  void _showVolume(double value) {
    _volumeHudTimer?.cancel();
    setState(() => _volumeHud = value.clamp(0.0, 1.0));
    _volumeHudTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _volumeHud = null);
    });
  }

  /// A vertical drag takes the volume from where it is: up is louder, the
  /// whole picture is the track (no brightness half to confuse the pinch).
  void _beginVolumeDrag() {
    _dragVolume = ref.read(roomProvider.notifier).volume;
    _showVolume(_dragVolume);
  }

  void _dragVolumeBy(double delta) {
    final next = (_dragVolume - delta / 220).clamp(0.0, 1.0);
    _dragVolume = next;
    _showVolume(next);
    unawaited(ref.read(roomProvider.notifier).setVolume(next));
  }

  /// A wheel step takes the viewer's chosen share of the range (the
  /// 画质与音频 setting), so a desktop mouse has a usable granularity
  /// without a slider.
  void _wheelVolume(double delta) {
    final step = ref.read(playbackSettingsProvider).volumeWheelStepPercent / 100;
    final next = (ref.read(roomProvider.notifier).volume + (delta > 0 ? -step : step)).clamp(0.0, 1.0);
    _showVolume(next);
    unawaited(ref.read(roomProvider.notifier).setVolume(next));
  }

  /// The flying layer's config from the live look; a compact surface passes
  /// its scaled geometry and the reference's smaller pending queue/caches,
  /// everything else comes from the one main configuration.
  BarrageConfig _barrageConfig(
    DanmakuStyle style,
    int fps, {
    String? family,
    double? area,
    CompactDanmakuMetrics? compact,
  }) => roomBarrageConfig(
    style,
    fps,
    family: family,
    area: area,
    fixedDuration: Duration(milliseconds: (ref.read(danmakuFixedDurationProvider) * 1000).round()),
    compact: compact,
  );

  BoxFit _portraitFit() => switch (widget.portraitDisplay) {
    PortraitFullscreenMode.complete || PortraitFullscreenMode.ambient => BoxFit.contain,
    PortraitFullscreenMode.balanced || PortraitFullscreenMode.cover => BoxFit.cover,
  };

  Alignment _portraitAlignment() =>
      widget.portraitDisplay == PortraitFullscreenMode.balanced ? Alignment.topCenter : Alignment.center;

  @override
  Widget build(BuildContext context) {
    final room = widget.roomState;
    final handle = room.handle;
    final transport = _transport;
    final picture = pictureStateOf(context.t, room, slow: ref.watch(roomSlowProvider));
    final style = ref.watch(danmakuStyleProvider);
    final danmakuFps = ref.watch(danmakuEffectiveFpsProvider);
    final pipScale = ref.watch(pipDanmakuScaleProvider);
    final danmakuFamily = resolvedFontFamily(style.fontFamily);
    final playback = ref.watch(playbackSettingsProvider);
    final presentation = ref.watch(roomPresentationProvider);
    // The compact, bare surface belongs to a picture-in-picture window this
    // app lays out (the desktop one). A phone's system window leaves the page
    // — and this surface — exactly as it was.
    final mini = presentation == PresentationMode.pip && ref.read(roomPresentationProvider.notifier).pipOwnsWindow;
    final portraitHidden = widget.portraitFullscreen && widget.portraitDanmaku == PortraitDanmakuMode.hidden;
    final showDanmaku = playback.danmakuVisible && (!mini || playback.miniDanmakuVisible) && !portraitHidden;
    final danmakuArea = widget.portraitFullscreen
        ? switch (widget.portraitDanmaku) {
            PortraitDanmakuMode.upperQuarter => 0.25,
            PortraitDanmakuMode.reduced => style.area * 0.5,
            PortraitDanmakuMode.hidden => 0.0,
            PortraitDanmakuMode.followGlobal => style.area,
          }
        : style.area;
    final longPressInteraction = showDanmaku && ref.watch(danmakuLongPressInteractionProvider);
    final playing = room.playback.playing;
    // A paused or failed stream keeps the bar up; a playing one lets it go.
    final showBar = handle != null && picture.kind == RoomPictureKind.none && (_controlsVisible || !playing);
    // A pointer drag over the picture moves the window: desktop only, and only
    // while the room is an ordinary window — a fullscreen or compact surface
    // has its own rules. The volume swipe is a phone gesture and gives the
    // drag the whole picture here (the wheel still sets the volume).
    final desktopDrag = _desktop && presentation == PresentationMode.normal;
    _watchTransport(handle);
    ref.listen(roomProvider.select((state) => state.playback.playing), (previous, next) {
      if (next) {
        _scheduleHide();
      } else if (mounted) {
        _hideTimer?.cancel();
        setState(() => _controlsVisible = true);
      }
    });
    return Focus(
      focusNode: _controlsFocus,
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      // The reference's own rule: moving the pointer over the picture brings
      // the overlay back, a click is not needed. A touch screen never hovers,
      // so phones keep the tap.
      child: MouseRegion(
        onHover: mini ? null : (_) => _wake(),
        onExit: mini ? null : (_) => _scheduleHide(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (handle == null)
              const ColoredBox(color: kPlayerStageColor, child: SizedBox.expand())
            else if (room.audioOnly && room.room != null)
              AudioOnlyCover(room: room.room!)
            else if (widget.portraitFullscreen && widget.portraitDisplay == PortraitFullscreenMode.ambient)
              DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF17191E), kPlayerStageColor],
                  ),
                ),
                child: MediaPlayerView(handle: handle, fit: _portraitFit(), alignment: _portraitAlignment()),
              )
            else
              MediaPlayerView(
                handle: handle,
                fit: widget.portraitFullscreen ? _portraitFit() : playback.fit.boxFit,
                alignment: widget.portraitFullscreen ? _portraitAlignment() : Alignment.center,
              ),
            if (widget.barrage case final barrage? when showDanmaku)
              Positioned.fill(
                child: IgnorePointer(
                  child: mini
                      ? LayoutBuilder(
                          builder: (context, constraints) => FlameBarrageWidget(
                            // The compact (PiP) surface keeps the main look and
                            // adds one width-derived or pinned factor; its own
                            // lane geometry and smaller caches follow the
                            // reference's CompactDanmakuMetrics.
                            config: _barrageConfig(
                              style,
                              danmakuFps,
                              family: danmakuFamily,
                              area: danmakuArea,
                              compact: CompactDanmakuMetrics.resolve(
                                width: constraints.maxWidth,
                                auto: pipScale.auto,
                                pinnedScale: pipScale.scale,
                                configuredFontSize: style.fontSize,
                                configuredSpeed: style.baseSpeed,
                              ),
                            ),
                            emojiAtlas: EmojiAtlas.instance,
                            controller: barrage,
                          ),
                        )
                      : FlameBarrageWidget(
                          config: _barrageConfig(style, danmakuFps, family: danmakuFamily, area: danmakuArea),
                          emojiAtlas: EmojiAtlas.instance,
                          controller: barrage,
                        ),
                ),
              ),
            // The gesture layer: a tap shows or hides the bar, a double tap
            // plays or pauses, a vertical drag and the wheel set the volume.
            // The compact window keeps only the window verbs: dragging the
            // picture moves the small window (its native caption is hidden) and
            // a double press brings it back.
            if (picture.kind == RoomPictureKind.none)
              Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent && event.scrollDelta.dy != 0) {
                    _wheelVolume(event.scrollDelta.dy);
                  }
                },
                onPointerDown: _holdDanmaku,
                onPointerMove: _releaseDanmakuOnMove,
                onPointerCancel: (_) => _releaseDanmaku(),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: mini ? null : (_) => unawaited(_onPictureTap()),
                  // With the switch off no long-press recognizer is registered,
                  // so it never holds back a drag.
                  onLongPressStart: longPressInteraction ? (_) => unawaited(_onPictureLongPress()) : null,
                  // A long press cancels the tap first; releasing here would
                  // drop the message before _onPictureLongPress can take it.
                  onLongPressCancel: _releaseDanmaku,
                  onDoubleTap: () {
                    _releaseDanmaku();
                    if (mini) {
                      widget.onLeave();
                      return;
                    }
                    unawaited(ref.read(roomProvider.notifier).togglePlayPause());
                  },
                  onPanStart: mini
                      ? (_) {
                          final window = ref.read(windowsPipWindowProvider);
                          if (window != null) unawaited(window.startDragging());
                        }
                      : desktopDrag
                      ? (_) => unawaited(
                          ref.read(desktopWindowHostProvider).startDragging().catchError((Object _) {}),
                        )
                      : null,
                  onVerticalDragStart: mini || desktopDrag
                      ? null
                      : (details) {
                          _releaseDanmaku();
                          final width = MediaQuery.sizeOf(context).width;
                          final swipe = widget.onPortraitSwipe;
                          if (widget.portraitFullscreen &&
                              swipe != null &&
                              details.localPosition.dx >= width / 3 &&
                              details.localPosition.dx <= width * 2 / 3) {
                            _swipingPortrait = true;
                            _portraitSwipeDy = 0;
                            return;
                          }
                          _beginVolumeDrag();
                        },
                  onVerticalDragUpdate: mini || desktopDrag
                      ? null
                      : (details) {
                          if (_swipingPortrait) {
                            _portraitSwipeDy += details.delta.dy;
                            return;
                          }
                          _dragVolumeBy(details.delta.dy);
                        },
                  onVerticalDragEnd: mini || desktopDrag
                      ? null
                      : (details) {
                          if (!_swipingPortrait) return;
                          _swipingPortrait = false;
                          final dy = _portraitSwipeDy + (details.primaryVelocity ?? 0) * 0.08;
                          _portraitSwipeDy = 0;
                          if (dy.abs() < 80) return;
                          widget.onPortraitSwipe?.call(dy < 0 ? 1 : -1);
                        },
                  onVerticalDragCancel: mini || desktopDrag
                      ? null
                      : () {
                          _swipingPortrait = false;
                          _portraitSwipeDy = 0;
                        },
                  child: const SizedBox.expand(),
                ),
              ),
            if (_volumeHud case final volume?)
              PositionedDirectional(
                end: DsSpace.s20,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.s16, vertical: DsSpace.s12),
                      decoration: DsBoxDecoration(
                        color: const Color(0xCC000000),
                        borderRadius: BorderRadius.circular(DsTheme.of(context).radii.card),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        spacing: DsSpace.s4,
                        children: [
                          DsIcon(volume <= 0.001 ? DsIcons.volumeX : DsIcons.volume2, size: 24, color: _onVideo),
                          Text(
                            '${(volume * 100).round()}%',
                            style: DsTheme.of(context).typography
                                .numeric(DsTheme.of(context).typography.caption.copyWith(color: _onVideo)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (picture.kind != RoomPictureKind.none)
              ColoredBox(
                color: switch (picture.dim) {
                  RoomPictureDim.none => const Color(0x00000000),
                  RoomPictureDim.light => const Color(0x66000000),
                  RoomPictureDim.heavy => const Color(0xB3000000),
                  RoomPictureDim.cover => const Color(0xE6000000),
                },
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: DsSpace.s12,
                    children: [
                      if (picture.busy) const DsSpinner(style: DsSpinnerStyle(size: 20, color: _onVideoSubtle)),
                      Text(
                        picture.title,
                        textAlign: TextAlign.center,
                        style: DsTheme.of(context).typography.title.copyWith(color: _onVideo),
                      ),
                      if (picture.reason case final reason?)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Text(
                            reason,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: DsTheme.of(context).typography.caption.copyWith(color: _onVideoMuted),
                          ),
                        ),
                      if (picture.actions.isNotEmpty)
                        Wrap(
                          spacing: DsSpace.s8,
                          runSpacing: DsSpace.s8,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final (index, action) in picture.actions.indexed)
                              PictureActionButton(
                                action: action,
                                autofocus: widget.autofocusFirstControl && index == 0,
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            if (showBar && !mini)
              PositionedDirectional(
                top: 0,
                start: 0,
                end: 0,
                child: _PlayerTopBar(room: room, onLeave: widget.onLeave, onHold: _setPanelOpen, onWake: _wake),
              ),
            // The compact window's own strip: its caption is hidden, so this is
            // the only place that carries the window verbs. It never hides —
            // without it the small window would have no way back.
            if (mini)
              PositionedDirectional(
                top: 0,
                start: 0,
                end: 0,
                child: _PipBar(room: room, onRestore: widget.onLeave, onClose: widget.onCloseRoom ?? widget.onLeave),
              ),
            if (showBar && !mini)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: MouseRegion(
                  onEnter: (_) => _hideTimer?.cancel(),
                  onExit: (_) => _scheduleHide(),
                  child: _ControlBar(
                    handle: handle,
                    transport: transport,
                    onWake: _wake,
                    autofocusPlay: widget.autofocusFirstControl,
                    canEnterPortraitFullscreen: widget.canEnterPortraitFullscreen,
                    portraitFullscreen: widget.portraitFullscreen,
                    onPortraitFullscreen: widget.onPortraitFullscreen,
                  ),
                ),
              )
            // The bar away, the picture keeps one thin line on its bottom
            // edge; resting on it brings the bar back.
            else if (playing && !mini && handle != null)
              Positioned(bottom: 0, left: 0, right: 0, child: PlayerIdleProgress(onWake: _wake)),
          ],
        ),
      ),
    );
  }
}

/// The strip over the picture: the way out in a glass pill, the room's name
/// in the viewer's own type, the live state and the audience beside it, and —
/// the reference's own arrangement — the stream's choices on the far end: the
/// flying danmaku's switch, the quality, the line and the picture's shape.
///
/// A picker drops its catalogue *under* the strip as a panel: resting the
/// pointer on a picker opens it, a press toggles it, a choice closes it. That
/// keeps one overlay over the picture instead of a menu per control, and lets
/// the button read "线路 2" while the panel says what that line is.
final class _PlayerTopBar extends ConsumerStatefulWidget {
  const _PlayerTopBar({required this.room, required this.onLeave, required this.onHold, required this.onWake});

  final RoomState room;
  final VoidCallback onLeave;

  /// Whether a picker panel is open: the bars must not settle away under it.
  final ValueChanged<bool> onHold;

  /// Resets the bars' auto-hide timer after a press.
  final VoidCallback onWake;

  @override
  ConsumerState<_PlayerTopBar> createState() => _PlayerTopBarState();
}

/// The catalogues the strip above the picture offers.
enum _Picker { quality, line, fit }

final class _PlayerTopBarState extends ConsumerState<_PlayerTopBar> {
  _Picker? _open;
  Timer? _hoverTimer;
  Timer? _leaveTimer;

  @override
  void dispose() {
    _hoverTimer?.cancel();
    _leaveTimer?.cancel();
    // The strip is leaving the tree (a tap dismissed the bars): an open
    // panel's hold must not outlive it, or the bars would never settle away
    // again.
    if (_open != null) widget.onHold(false);
    super.dispose();
  }

  void _show(_Picker picker) {
    _hoverTimer?.cancel();
    _leaveTimer?.cancel();
    if (_open == picker) return;
    final wasClosed = _open == null;
    setState(() => _open = picker);
    if (wasClosed) widget.onHold(true);
  }

  void _hide() {
    _hoverTimer?.cancel();
    _leaveTimer?.cancel();
    if (_open == null) return;
    setState(() => _open = null);
    widget.onHold(false);
  }

  void _toggle(_Picker picker) {
    widget.onWake();
    if (_open == picker) {
      _hide();
    } else {
      _show(picker);
    }
  }

  /// Resting the pointer on a picker opens it after a breath, so crossing the
  /// strip on the way somewhere else does not flash every catalogue.
  void _hoverOpen(_Picker picker) {
    _leaveTimer?.cancel();
    _hoverTimer?.cancel();
    _hoverTimer = Timer(const Duration(milliseconds: 160), () {
      if (mounted) _show(picker);
    });
  }

  /// The pointer leaving the strip gets a moment to reach the panel under it.
  void _hoverClose() {
    _hoverTimer?.cancel();
    _leaveTimer?.cancel();
    _leaveTimer = Timer(const Duration(milliseconds: 260), () {
      if (mounted) _hide();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final detail = widget.room.room;
    final title = detail?.content.title;
    final anchor = (detail?.anchor?.name ?? '').trim();
    // The streamer's name leads: in fullscreen the room is a person, and the
    // title alone does not say whose stream this is.
    final label = title == null
        ? null
        : anchor.isEmpty || anchor == title
        ? title
        : '$anchor · $title';
    final audience = detail?.audience.onlineViewers ?? detail?.audience.popularity ?? detail?.audience.totalViewers;
    final live = detail?.broadcast.isLiveNow ?? false;
    final replay = detail?.broadcast.isRecord ?? false;
    final lines = widget.room.lines;
    final lineIndex = widget.room.lineIndex.clamp(0, lines.isEmpty ? 0 : lines.length - 1);
    final line = lines.isEmpty ? null : lines[lineIndex];
    final quality = widget.room.quality ?? (widget.room.qualities.isEmpty ? null : widget.room.qualities.first);
    final settings = ref.watch(playbackSettingsProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        // A phone strip is too narrow for words: the pickers keep the glyph,
        // the panel under them still says everything.
        final labelled = constraints.maxWidth >= 720;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(DsSpace.s8, DsSpace.s8, DsSpace.s12, DsSpace.s12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topCenter,
                  end: AlignmentDirectional.bottomCenter,
                  colors: [Color(0xB3000000), Color(0x00000000)],
                ),
              ),
              child: Row(
                spacing: DsSpace.s8,
                children: [
                  PlayerGlassPill(
                    child: _BarIcon(icon: DsIcons.chevronLeft, label: t.common.close, onPressed: widget.onLeave),
                  ),
                  if (label != null)
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.title.copyWith(color: _onVideo),
                      ),
                    )
                  else
                    const Spacer(),
                  if (live)
                    const PlayerGlassPill(child: _VideoLiveBadge())
                  else if (replay)
                    PlayerGlassPill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s3),
                        child: Text(
                          t.favorites.statusReplay,
                          style: theme.typography.caption.copyWith(color: _onVideo, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  if (audience != null && constraints.maxWidth >= 480)
                    PlayerGlassPill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s3),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: DsSpace.s3,
                          children: [
                            DsIcon(DsIcons.eye, size: theme.sizes.iconXs, color: _onVideoSubtle),
                            Text(
                              AudienceFormat.format(audience),
                              style: theme.typography.numeric(theme.typography.caption.copyWith(color: _onVideo)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  PlayerGlassPill(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: DsSpace.s4,
                      children: [
                        _BarIcon(
                          icon: settings.danmakuVisible ? DsIcons.captions : DsIcons.captionsOff,
                          label: settings.danmakuVisible ? t.room.danmakuOff : t.room.danmakuOn,
                          selected: settings.danmakuVisible,
                          onPressed: () {
                            widget.onWake();
                            unawaited(
                              ref
                                  .read(playbackSettingsProvider.notifier)
                                  .setDanmakuVisible(value: !settings.danmakuVisible),
                            );
                          },
                        ),
                        if (quality != null)
                          _pickerButton(
                            picker: _Picker.quality,
                            icon: DsIcons.gauge,
                            label: quality.label,
                            semanticLabel: t.room.quality,
                            labelled: labelled,
                          ),
                        if (line != null && lines.length > 1)
                          _pickerButton(
                            picker: _Picker.line,
                            icon: DsIcons.route,
                            label: _lineShortLabel(t, line, lineIndex),
                            semanticLabel: t.room.lineLabel,
                            labelled: labelled,
                          ),
                        _pickerButton(
                          picker: _Picker.fit,
                          icon: DsIcons.aspectRatio,
                          label: fitLabels(t)[settings.fit.index],
                          semanticLabel: t.settings.fit,
                          labelled: labelled,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_open case final picker?)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: DsSpace.s4, end: DsSpace.s12),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: MouseRegion(
                    onEnter: (_) => _leaveTimer?.cancel(),
                    onExit: (_) => _hoverClose(),
                    child: _pickerPanel(t, picker),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// One picker on the strip: the glyph, the current choice's words when the
  /// strip is wide enough, and the chevron that says a panel hangs under it.
  Widget _pickerButton({
    required _Picker picker,
    required DsIconData icon,
    required String label,
    required String semanticLabel,
    required bool labelled,
  }) {
    final theme = DsTheme.of(context);
    final open = _open == picker;
    return MouseRegion(
      onEnter: (_) => _hoverOpen(picker),
      onExit: (_) => _hoverClose(),
      child: TvFocusScale(
        child: DsPressable(
          semanticLabel: semanticLabel,
          onPressed: () => _toggle(picker),
          builder: (context, states, _) {
            final lit = open || states.contains(WidgetState.hovered);
            return Container(
              height: theme.sizes.sm,
              padding: EdgeInsets.symmetric(horizontal: labelled ? DsSpace.s8 : DsSpace.s6),
              decoration: DsBoxDecoration(
                color: lit ? _onVideoHover : null,
                borderRadius: theme.radii.controlCorners(null, theme.sizes.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: DsSpace.s4,
                children: [
                  DsIcon(icon, size: theme.sizes.iconSm, color: _onVideoMuted),
                  if (labelled)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 96),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: _onVideo),
                      ),
                    ),
                  DsIcon(open ? DsIcons.chevronDown : DsIcons.chevronUp, size: 12, color: _onVideoMuted),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// The open picker's catalogue.
  Widget _pickerPanel(Translations t, _Picker picker) {
    final room = widget.room;
    final controller = ref.read(roomProvider.notifier);
    switch (picker) {
      case _Picker.quality:
        final current = room.quality ?? (room.qualities.isEmpty ? null : room.qualities.first);
        return PlayerOverlayPanel(
          title: t.room.quality,
          width: 200,
          children: [
            for (final option in room.qualities)
              PlayerPanelOption(
                label: option.label,
                selected: option == current,
                onPressed: () {
                  _hide();
                  unawaited(controller.selectQuality(option));
                },
              ),
          ],
        );
      case _Picker.line:
        return PlayerOverlayPanel(
          title: t.room.lineLabel,
          width: 240,
          children: [
            for (final (index, option) in room.lines.indexed)
              PlayerPanelOption(
                label: _lineShortLabel(t, option, index),
                detail: _lineDetail(option),
                selected: index == room.lineIndex,
                onPressed: () {
                  _hide();
                  unawaited(controller.selectLine(index));
                },
              ),
          ],
        );
      case _Picker.fit:
        final current = ref.read(playbackSettingsProvider).fit;
        return PlayerOverlayPanel(
          title: t.settings.fit,
          width: 200,
          children: [
            for (final (index, option) in PlaybackFit.values.indexed)
              PlayerPanelOption(
                label: fitLabels(t)[index],
                selected: option == current,
                onPressed: () {
                  _hide();
                  unawaited(ref.read(playbackSettingsProvider.notifier).setFit(option));
                },
              ),
          ],
        );
    }
  }
}

/// The line's words on the strip: the platform's own label when it reads as
/// one, the position otherwise. Bilibili labels a line
/// `host|protocol|format|codec`, which never belongs on a button.
String _lineShortLabel(Translations t, LivePlayLine line, int index) {
  final own = (line.lineLabel ?? '').trim();
  if (own.isEmpty || own.contains('|') || own.length > 14) return t.room.line(n: index + 1);
  return own;
}

/// What a line is, under its name in the panel: the container and the codec,
/// the two facts a viewer compares lines by.
String? _lineDetail(LivePlayLine line) {
  final format = switch (line.format) {
    LiveStreamFormat.mpegts => 'MPEG-TS',
    LiveStreamFormat.webrtc => 'WebRTC',
    _ => line.format.name.toUpperCase(),
  };
  final codec = switch (line.codec) {
    LiveStreamCodec.avc => 'H.264',
    LiveStreamCodec.hevc => 'H.265',
    LiveStreamCodec.av1 => 'AV1',
    LiveStreamCodec.vp9 => 'VP9',
    LiveStreamCodec.unknown || null => '',
  };
  return codec.isEmpty ? format : '$format · $codec';
}

/// The live pill over the picture: the red dot and the word in video ink.
final class _VideoLiveBadge extends StatelessWidget {
  const _VideoLiveBadge();

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: DsSpace.s3,
        children: [
          Container(width: 5, height: 5, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFF3B5C))),
          Text(
            t.favorites.statusLiveNow,
            style: theme.typography.caption.copyWith(color: _onVideo, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// The compact window's strip.
///
/// A small window has no native caption, so this row carries every window
/// verb: the drag handle and the picture move it, the double press (here or
/// on the picture) restores the page, and play, mute, restore and close sit
/// at the far end. It never hides — without it the window would have no way
/// back — and it stays 28 px tall so the picture keeps the rest.
final class _PipBar extends ConsumerWidget {
  const _PipBar({required this.room, required this.onRestore, required this.onClose});

  final RoomState room;
  final VoidCallback onRestore;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final controller = ref.read(roomProvider.notifier);
    final window = ref.read(windowsPipWindowProvider);
    final playing = room.playback.playing;
    final muted = controller.muted;
    final anchor = (room.room?.anchor?.name ?? '').trim();
    final caption = anchor.isEmpty ? (room.room?.content.title ?? '') : anchor;
    void drag() {
      if (window != null) unawaited(window.startDragging());
    }

    return Container(
      height: 28,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topCenter,
          end: AlignmentDirectional.bottomCenter,
          colors: [Color(0xB3000000), Color(0x00000000)],
        ),
      ),
      child: Row(
        spacing: DsSpace.s3,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => drag(),
            onDoubleTap: onRestore,
            child: const SizedBox(
              width: 28,
              height: 28,
              child: Center(child: DsIcon(DsIcons.dragHandle, size: 14, color: _onVideoSubtle)),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => drag(),
              onDoubleTap: onRestore,
              child: Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption.copyWith(color: _onVideoMuted),
              ),
            ),
          ),
          _PipButton(
            icon: playing ? DsIcons.pause : DsIcons.play,
            label: playing ? t.room.pause : t.room.play,
            onPressed: () => unawaited(controller.togglePlayPause()),
          ),
          _PipButton(
            icon: muted ? DsIcons.volumeOff : DsIcons.volume,
            label: muted ? t.room.unmute : t.room.mute,
            onPressed: () => unawaited(controller.setMuted(value: !muted)),
          ),
          _PipButton(icon: DsIcons.expand, label: t.room.pipOff, onPressed: onRestore),
          _PipButton(icon: DsIcons.x, label: t.common.close, onPressed: onClose),
        ],
      ),
    );
  }
}

/// One control on the compact window's strip: 28 px square, no tooltip (there
/// is no room for one in a small window), the label kept for screen readers.
final class _PipButton extends StatelessWidget {
  const _PipButton({required this.icon, required this.label, required this.onPressed});

  final DsIconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Center(child: DsIcon(icon, size: 14, color: _onVideoMuted)),
        ),
      ),
    );
  }
}

/// The bar itself: the live position over the buffer, then the transport,
/// the stream pickers, the danmaku switch and the presentation buttons.
final class _ControlBar extends ConsumerWidget {
  const _ControlBar({
    required this.handle,
    required this.transport,
    required this.onWake,
    this.autofocusPlay = false,
    this.canEnterPortraitFullscreen = false,
    this.portraitFullscreen = false,
    this.onPortraitFullscreen,
  });

  final PlayerHandle handle;

  /// The latest transport snapshot, null until the first event.
  final PlayerTransportState? transport;

  /// Resets the bar's auto-hide timer after an interaction.
  final VoidCallback onWake;

  /// Focuses the play button when it first builds (the TV room's start).
  final bool autofocusPlay;

  /// Whether a portrait stream offers the entry button.
  final bool canEnterPortraitFullscreen;

  /// Whether the portrait full-screen surface is already showing.
  final bool portraitFullscreen;

  /// Enters portrait full screen.
  final VoidCallback? onPortraitFullscreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final room = ref.watch(roomProvider);
    final presentation = ref.watch(roomPresentationProvider);
    final controller = ref.read(roomProvider.notifier);
    final presentationController = ref.read(roomPresentationProvider.notifier);
    final player = room.handle?.id;
    final playing = room.playback.playing;
    final muted = controller.muted;
    final volume = transport?.volume ?? controller.volume;
    final position = transport?.position ?? Duration.zero;
    final buffered = transport?.buffer.bufferedDuration ?? Duration.zero;
    final duration = transport?.duration ?? Duration.zero;
    final line = room.lines.isEmpty ? null : room.lines[room.lineIndex.clamp(0, room.lines.length - 1)];
    final immersive = presentationController.modeOwnsWindow(presentation);
    return Container(
      padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s8, DsSpace.s12, DsSpace.s8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.bottomCenter,
          end: AlignmentDirectional.topCenter,
          colors: [Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s6,
        children: [
          _LiveBar(position: position, buffered: buffered, duration: duration),
          LayoutBuilder(
            builder: (context, constraints) {
              // The compact window (and a phone's 16:9 strip) has no room
              // for labels: the pickers keep their icons, and a small
              // window only keeps the transport and the way out.
              final pip = presentation == PresentationMode.pip && presentationController.pipOwnsWindow;
              final compact = constraints.maxWidth < 560;
              final narrow = constraints.maxWidth < 420;
              final bar = Row(
                mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
                spacing: DsSpace.s4,
                children: [
                  _BarIcon(
                    icon: playing ? DsIcons.pause : DsIcons.play,
                    label: playing ? t.room.pause : t.room.play,
                    autofocus: autofocusPlay,
                    onPressed: () {
                      onWake();
                      unawaited(controller.togglePlayPause());
                    },
                  ),
                  _BarIcon(
                    icon: muted ? DsIcons.volumeOff : DsIcons.volume,
                    label: muted ? t.room.unmute : t.room.mute,
                    onPressed: () {
                      onWake();
                      unawaited(controller.setMuted(value: !muted));
                    },
                  ),
                  _BarIcon(
                    icon: room.audioOnly ? DsIcons.video : DsIcons.headphones,
                    label: room.audioOnly ? t.room.restoreVideo : t.room.audioOnlyMode,
                    onPressed: () {
                      onWake();
                      unawaited(controller.setAudioOnly(value: !room.audioOnly));
                    },
                  ),
                  if (!compact)
                    SizedBox(
                      width: 90,
                      child: DsSlider(
                        value: volume,
                        onChanged: (value) {
                          onWake();
                          unawaited(controller.setVolume(value));
                        },
                        semanticLabel: t.room.volume,
                      ),
                    ),
                  // A fitted bar keeps a gap before the room's own verbs; a
                  // compact one scrolls, so the buttons cannot push the last
                  // one off the picture. The fitted bar also splits its
                  // clusters: a hair divider between the transport and the
                  // rest. The stream pickers (quality, line, shape) live in
                  // the strip above the picture, where the reference keeps
                  // them.
                  if (compact) const SizedBox(width: DsSpace.s4) else ...[const _BarDivider(), const Spacer()],
                  if (!pip && line != null) _RecordButton(room: room),
                  if (!pip && !narrow && line != null)
                    _BarIcon(
                      icon: DsIcons.cast,
                      label: t.room.cast,
                      onPressed: () {
                        onWake();
                        unawaited(showCastDialog(context, line: line, title: room.room?.content.title));
                      },
                    ),
                  if (!pip && !narrow && _desktop && player != null)
                    _BarIcon(
                      icon: DsIcons.rectangleHorizontal,
                      label: presentation == PresentationMode.windowFullscreen
                          ? t.room.windowFullscreenOff
                          : t.room.windowFullscreenOn,
                      selected: presentation == PresentationMode.windowFullscreen,
                      onPressed: () {
                        onWake();
                        unawaited(presentationController.toggleWindowFullscreen(player));
                      },
                    ),
                  if (!pip &&
                      canEnterPortraitFullscreen &&
                      !portraitFullscreen &&
                      presentation == PresentationMode.normal)
                    _BarIcon(
                      icon: DsIcons.rectangleVertical,
                      label: t.room.portraitFullscreen,
                      onPressed: () {
                        onWake();
                        onPortraitFullscreen?.call();
                      },
                    ),
                  if (!pip && player != null)
                    _BarIcon(
                      icon: immersive ? DsIcons.minimize2 : DsIcons.fullscreen,
                      label: immersive ? t.room.fullscreenOff : t.room.fullscreenOn,
                      selected: immersive,
                      onPressed: () {
                        onWake();
                        unawaited(presentationController.toggleFullscreen(player));
                      },
                    ),
                  if (player != null && presentationController.pipAvailable)
                    _BarIcon(
                      icon: presentation == PresentationMode.pip
                          ? DsIcons.pictureInPictureExit
                          : DsIcons.pictureInPicture,
                      label: presentation == PresentationMode.pip ? t.room.pipOff : t.room.pipOn,
                      selected: presentation == PresentationMode.pip,
                      onPressed: () {
                        onWake();
                        // A phone's system window can refuse (no on-screen
                        // player layer, a device that cannot present it):
                        // saying so beats a button that did nothing.
                        unawaited(() async {
                          final accepted = await presentationController.togglePip(player);
                          if (accepted || !context.mounted) return;
                          showDsToast(context: context, title: t.common.pipUnavailable);
                        }());
                      },
                    ),
                ],
              );
              return compact ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: bar) : bar;
            },
          ),
        ],
      ),
    );
  }
}

/// Whether this host offers the desktop-only window-fullscreen button.
bool get _desktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux);

/// A hair divider between the fitted bar's clusters: the transport on one
/// side, the stream's own menus on the other.
final class _BarDivider extends StatelessWidget {
  const _BarDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 16,
    margin: const EdgeInsets.symmetric(horizontal: DsSpace.s4),
    color: const Color(0x40FFFFFF),
  );
}

/// The record toggle: a disc while idle, a stop square while this room is
/// being captured. The task store is the truth the button follows, so a
/// recording started in an earlier visit still reads as running.
final class _RecordButton extends ConsumerWidget {
  const _RecordButton({required this.room});

  final RoomState room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final detail = room.room;
    final id = detail == null ? null : '${detail.ref.platform}:${detail.ref.roomId}';
    final task = id == null ? null : ref.watch(recordingTasksProvider).tasks.where((task) => task.id == id).firstOrNull;
    final recording = task?.state == RecordingTaskState.recording;
    return _BarIcon(
      icon: recording ? DsIcons.squareStop : DsIcons.disc,
      label: recording ? t.room.stopRecording : t.room.record,
      selected: recording,
      onPressed: () async {
        final failure = await ref.read(roomProvider.notifier).toggleRecording();
        if (!context.mounted) return;
        showDsToast(
          context: context,
          title: failure == null ? (recording ? t.room.recordStopped : t.room.recordStarted) : t.room.recordFailed,
          status: failure == null ? DsStatus.success : DsStatus.danger,
        );
      },
    );
  }
}

/// One icon button on the dark bar: a slight hover fill, the selected
/// state's tint, and the label a screen reader reads.
final class _BarIcon extends StatelessWidget {
  const _BarIcon({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.autofocus = false,
  });

  final DsIconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool selected;

  /// Takes the focus when first built (the TV room's first control).
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return MediaBarButton(icon: icon, label: label, onPressed: onPressed, selected: selected, autofocus: autofocus);
  }
}

/// The live position bar: the buffered span behind, the position over it, a
/// red head dot where the live edge sits. A nominal or unknown duration
/// keeps the bar at its start, which is the truth of a live stream.
final class _LiveBar extends StatelessWidget {
  const _LiveBar({required this.position, required this.buffered, required this.duration});

  final Duration position;
  final Duration buffered;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final total = duration.inMilliseconds;
    if (total <= 0) {
      return const SizedBox(height: 4, child: DsLine(color: Color(0x2EFFFFFF)));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final bufferedFraction = (buffered.inMilliseconds / total).clamp(0.0, 1.0);
        final positionFraction = (position.inMilliseconds / total).clamp(0.0, 1.0);
        return SizedBox(
          height: 4,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              FractionallySizedBox(
                widthFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: const Color(0x2EFFFFFF), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              FractionallySizedBox(
                widthFactor: bufferedFraction,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: const Color(0x4DFFFFFF), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              FractionallySizedBox(
                widthFactor: positionFraction,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: _onVideo, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              PositionedDirectional(
                start: (width * positionFraction).clamp(5.0, width - 5.0) - 5,
                top: -3,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF3B5C),
                    border: Border.all(color: _onVideo, width: 2),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
