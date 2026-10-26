import 'dart:async' show StreamSubscription, Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flame_barrage/flame_barrage.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/gestures.dart' show PointerScrollEvent, kTouchSlop;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:media_core/media_core.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/recorder/recorder.dart';
import 'package:pure_live/features/room/chat/room_message_actions.dart' show showRoomMessageActions;
import 'package:pure_live/features/room/controller/room_controller.dart';
import 'package:pure_live/features/room/page/audio_only_cover.dart' show AudioOnlyCover;
import 'package:pure_live/features/room/page/room_status.dart'
    show RoomPictureAction, RoomPictureDim, RoomPictureKind, pictureStateOf, roomSlowProvider;
import 'package:pure_live/features/room/player/cast_dialog.dart' show showCastDialog;
import 'package:pure_live/features/room/player/compact_danmaku_metrics.dart' show CompactDanmakuMetrics;
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart';

/// The picture's own ink: the frame is dark whatever the app's theme, so
/// the bars, the state overlay and the position line never borrow the
/// surface's ink (which turns dark-on-dark in a light theme).
const Color _onVideo = Color(0xFFFFFFFF);
const Color _onVideoMuted = Color(0xCCFFFFFF);
const Color _onVideoSubtle = Color(0x99FFFFFF);
const Color _onVideoHover = Color(0x24FFFFFF);

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
  void _wake() {
    if (mounted) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!widget.roomState.playback.playing) return;
    // A TV room keeps its bars: with no pointer there is no way to wake a
    // hidden bar, and the focused control would go with it.
    if (widget.keepControls || _controlsFocus.hasFocus) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
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

  /// A wheel step takes a twentieth of the range, so a desktop mouse has a
  /// usable granularity without a slider.
  void _wheelVolume(double delta) {
    final next = (ref.read(roomProvider.notifier).volume + (delta > 0 ? -0.05 : 0.05)).clamp(0.0, 1.0);
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
  }) {
    final scale = compact?.scale ?? 1.0;
    return BarrageConfig(
      fontSize: compact?.fontSize ?? style.fontSize,
      // The reference's 字体粗细: 100–900, the flame layout's own default
      // being w500.
      fontWeight: FontWeight(style.fontWeight),
      // The reference's 文字间距 (danmakuLetterSpacing): pixels of extra space
      // between glyphs, negative to tighten; the compact factor scales it
      // with the text.
      letterSpacing: style.letterSpacing * scale,
      baseSpeed: compact?.baseSpeed ?? style.baseSpeed,
      area: area ?? style.area,
      // The reference's 顶部留白: pixels kept message-free at the top edge
      // before the area's share is measured.
      topAreaDistance: style.topMargin,
      // The reference's 底部留白: pixels kept message-free at the bottom edge,
      // so subtitles stay readable.
      bottomAreaDistance: style.bottomMargin,
      opacity: style.opacity,
      showStroke: style.showStroke,
      // The reference's 描边宽度 (danmakuFontBorder): the flame layout strokes
      // each glyph with this width when the outline is on.
      strokeWidth: style.strokeWidth,
      // The reference's 纯文字模式: the flame layout skips the emoji pictures
      // and keeps the words.
      noEmojiMode: style.noEmoji,
      fontFamily: family ?? style.fontFamily,
      // The reference's 海量模式: realtime dispatch and a fixed 1000-message
      // ceiling; otherwise the chosen 10–120 cap.
      realtimeMode: style.massMode,
      maxVisibleCount: style.massMode ? kDanmakuMassModeMaxVisibleCount : style.maxVisibleCount,
      // The reference's 弹幕帧率: the manual rate, or the display policy's cap
      // (60 FPS in power saving/balanced).
      fps: fps,
      // The room surface keeps the engine defaults; the compact surface's
      // lane geometry and pool sizes come from CompactDanmakuMetrics.
      trackHeight: compact?.trackHeight ?? 36,
      emojiSize: compact?.emojiSize ?? 24,
      overlapSafeGap: compact?.overlapSafeGap ?? 40,
      safeArea: compact == null,
      maxPendingCount: compact == null ? 120 : CompactDanmakuMetrics.maxPendingCount,
      maxPendingAge: compact == null ? const Duration(seconds: 5) : CompactDanmakuMetrics.maxPendingAge,
      fixedDuration: compact == null ? const Duration(seconds: 4) : CompactDanmakuMetrics.fixedDuration,
      barragePoolMaxSize: compact == null ? 150 : CompactDanmakuMetrics.barragePoolMaxSize,
      pictureCacheMaxSize: compact == null ? 200 : CompactDanmakuMetrics.pictureCacheMaxSize,
      textCacheMaxSize: compact == null ? 1000 : CompactDanmakuMetrics.textCacheMaxSize,
    );
  }

  BoxFit _portraitFit() => switch (widget.portraitDisplay) {
    PortraitFullscreenMode.complete || PortraitFullscreenMode.ambient => BoxFit.contain,
    PortraitFullscreenMode.balanced || PortraitFullscreenMode.cover => BoxFit.cover,
  };

  Alignment _portraitAlignment() =>
      widget.portraitDisplay == PortraitFullscreenMode.balanced ? Alignment.topCenter : Alignment.center;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final room = widget.roomState;
    final handle = room.handle;
    final transport = _transport;
    final picture = pictureStateOf(context.t, room, slow: ref.watch(roomSlowProvider));
    final style = ref.watch(danmakuStyleProvider);
    final danmakuFps = ref.watch(danmakuEffectiveFpsProvider);
    final pipScale = ref.watch(pipDanmakuScaleProvider);
    final danmakuFamily = effectiveFontFamily(style.fontFamily, ref.watch(danmakuFontFaceProvider));
    final playback = ref.watch(playbackSettingsProvider);
    final presentation = ref.watch(roomPresentationProvider);
    final localBarrage = ref.watch(localBarrageProvider);
    final mini = presentation == PresentationMode.pip;
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (handle == null)
            ColoredBox(color: colors.overlay, child: const SizedBox.expand())
          else if (room.audioOnly && room.room != null)
            AudioOnlyCover(room: room.room!)
          else if (widget.portraitFullscreen && widget.portraitDisplay == PortraitFullscreenMode.ambient)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [colors.channel, colors.overlay],
                ),
              ),
              child: MediaPlayerView(
                handle: handle,
                fit: _portraitFit(),
                alignment: _portraitAlignment(),
                backgroundColor: colors.overlay,
              ),
            )
          else
            MediaPlayerView(
              handle: handle,
              fit: widget.portraitFullscreen ? _portraitFit() : playback.fit.boxFit,
              alignment: widget.portraitFullscreen ? _portraitAlignment() : Alignment.center,
              backgroundColor: colors.overlay,
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
          // The local interaction's echo layer: the same look, with no
          // player pause binding, so "暂停时的弹幕" never freezes the
          // viewer's own messages.
          if (showDanmaku)
            Positioned.fill(
              child: IgnorePointer(
                child: mini
                    ? LayoutBuilder(
                        builder: (context, constraints) => FlameBarrageWidget(
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
                          controller: localBarrage,
                        ),
                      )
                    : FlameBarrageWidget(
                        config: _barrageConfig(style, danmakuFps, family: danmakuFamily, area: danmakuArea),
                        emojiAtlas: EmojiAtlas.instance,
                        controller: localBarrage,
                      ),
              ),
            ),
          // The gesture layer: a tap shows or hides the bar, a double tap
          // plays or pauses, a vertical drag and the wheel set the volume.
          // The overlay's own buttons stay above it.
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
                onTapUp: (_) => unawaited(_onPictureTap()),
                // With the switch off no long-press recognizer is registered,
                // so it never holds back a drag.
                onLongPressStart: longPressInteraction ? (_) => unawaited(_onPictureLongPress()) : null,
                // A long press cancels the tap first; releasing here would
                // drop the message before _onPictureLongPress can take it.
                onLongPressCancel: _releaseDanmaku,
                onDoubleTap: () {
                  _releaseDanmaku();
                  unawaited(ref.read(roomProvider.notifier).togglePlayPause());
                },
                onVerticalDragStart: (details) {
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
                onVerticalDragUpdate: (details) {
                  if (_swipingPortrait) {
                    _portraitSwipeDy += details.delta.dy;
                    return;
                  }
                  _dragVolumeBy(details.delta.dy);
                },
                onVerticalDragEnd: (details) {
                  if (!_swipingPortrait) return;
                  _swipingPortrait = false;
                  final dy = _portraitSwipeDy + (details.primaryVelocity ?? 0) * 0.08;
                  _portraitSwipeDy = 0;
                  if (dy.abs() < 80) return;
                  widget.onPortraitSwipe?.call(dy < 0 ? 1 : -1);
                },
                onVerticalDragCancel: () {
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
                            PictureActionButton(action: action, autofocus: widget.autofocusFirstControl && index == 0),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          if (showBar)
            PositionedDirectional(
              top: 0,
              start: 0,
              end: 0,
              child: _PlayerTopBar(room: room, onLeave: widget.onLeave),
            ),
          if (showBar)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
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
        ],
      ),
    );
  }
}

/// The strip over the picture: the way out (back to the page, or out of a
/// presentation mode) and the room's name in the viewer's own type.
final class _PlayerTopBar extends StatelessWidget {
  const _PlayerTopBar({required this.room, required this.onLeave});

  final RoomState room;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final title = room.room?.content.title;
    return Container(
      padding: const EdgeInsets.fromLTRB(DsSpace.s8, DsSpace.s8, DsSpace.s12, DsSpace.s8),
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
          _BarIcon(icon: DsIcons.chevronLeft, label: t.common.close, onPressed: onLeave),
          if (title != null)
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.title.copyWith(color: _onVideo),
              ),
            )
          else
            const Spacer(),
        ],
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
    final settings = ref.watch(playbackSettingsProvider);
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
    final quality = room.quality ?? (room.qualities.isEmpty ? null : room.qualities.first);
    final line = room.lines.isEmpty ? null : room.lines[room.lineIndex.clamp(0, room.lines.length - 1)];
    final immersive = presentation != PresentationMode.normal;
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
              final pip = presentation == PresentationMode.pip;
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
                  // A fitted bar keeps a gap before the stream menus; a
                  // compact one scrolls, so nine controls cannot push the
                  // last button off the picture.
                  if (compact) const SizedBox(width: DsSpace.s4) else const Spacer(),
                  if (!pip && quality != null)
                    _StreamMenu(
                      label: quality.label,
                      showLabel: !compact,
                      icon: DsIcons.gauge,
                      semanticLabel: t.room.quality,
                      items: [
                        for (final option in room.qualities)
                          DsMenuItem(
                            label: Text(option.label),
                            checked: option == quality,
                            onPressed: () {
                              onWake();
                              unawaited(controller.selectQuality(option));
                            },
                          ),
                      ],
                    ),
                  if (!pip && line != null && room.lines.length > 1)
                    _StreamMenu(
                      label: line.lineLabel ?? t.room.line(n: room.lineIndex + 1),
                      showLabel: !compact,
                      icon: DsIcons.route,
                      semanticLabel: t.room.lineLabel,
                      items: [
                        for (final (index, option) in room.lines.indexed)
                          DsMenuItem(
                            label: Text(option.lineLabel ?? t.room.line(n: index + 1)),
                            checked: index == room.lineIndex,
                            onPressed: () {
                              onWake();
                              unawaited(controller.selectLine(index));
                            },
                          ),
                      ],
                    ),
                  // The picture's shape: the reference's 画面比例 button on the
                  // control bar, six entries, the tick on the one in force;
                  // the choice writes the setting every surface reads.
                  if (!pip)
                    _StreamMenu(
                      label: fitLabels(context.t)[settings.fit.index],
                      showLabel: !compact,
                      icon: DsIcons.aspectRatio,
                      semanticLabel: context.t.settings.fit,
                      items: [
                        for (final (index, option) in PlaybackFit.values.indexed)
                          DsMenuItem(
                            label: Text(fitLabels(context.t)[index]),
                            checked: option == settings.fit,
                            onPressed: () {
                              onWake();
                              unawaited(ref.read(playbackSettingsProvider.notifier).setFit(option));
                            },
                          ),
                      ],
                    ),
                  if (!pip && line != null) _RecordButton(room: room),
                  if (!pip)
                    _BarIcon(
                      icon: settings.danmakuVisible ? DsIcons.captions : DsIcons.captionsOff,
                      label: settings.danmakuVisible ? t.room.danmakuOff : t.room.danmakuOn,
                      selected: settings.danmakuVisible,
                      onPressed: () {
                        onWake();
                        unawaited(
                          ref
                              .read(playbackSettingsProvider.notifier)
                              .setDanmakuVisible(value: !settings.danmakuVisible),
                        );
                      },
                    ),
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
                        unawaited(presentationController.togglePip(player));
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

/// A labelled menu over a stream dimension: the current quality or line,
/// its catalogue, the tick on the one playing.
final class _StreamMenu extends StatelessWidget {
  const _StreamMenu({
    required this.label,
    required this.icon,
    required this.semanticLabel,
    required this.items,
    this.showLabel = true,
  });

  /// The current choice; shown when [showLabel], the tooltip otherwise.
  final String label;
  final DsIconData icon;
  final String semanticLabel;
  final List<Widget> items;

  /// Whether the bar has room for the choice's words (a narrow strip and
  /// the small window keep only the icon).
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return TvFocusScale(
      child: DsMenuAnchor(
        side: DsSide.top,
        semanticLabel: semanticLabel,
        items: items,
        builder: (context, controller, child) => DsPressable(
          semanticLabel: semanticLabel,
          onPressed: controller.toggle,
          builder: (context, states, _) {
            final hovered = states.contains(WidgetState.hovered);
            return DsTooltip(
              message: '$label · $semanticLabel',
              child: Container(
                height: theme.sizes.sm,
                padding: EdgeInsets.symmetric(horizontal: showLabel ? DsSpace.s8 : DsSpace.s6),
                decoration: DsBoxDecoration(
                  color: hovered ? _onVideoHover : null,
                  borderRadius: theme.radii.controlCorners(null, theme.sizes.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: DsSpace.s4,
                  children: [
                    DsIcon(icon, size: theme.sizes.iconSm, color: _onVideoMuted),
                    if (showLabel) Text(label, style: theme.typography.caption.copyWith(color: _onVideo)),
                    const DsIcon(DsIcons.chevronUp, size: 12, color: _onVideoMuted),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
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
    final theme = DsTheme.of(context);
    return TvFocusScale(
      child: DsTooltip(
        message: label,
        child: DsPressable(
          semanticLabel: label,
          onPressed: onPressed,
          autofocus: autofocus,
          builder: (context, states, _) {
            final hovered = states.contains(WidgetState.hovered);
            return Container(
              width: theme.sizes.sm,
              height: theme.sizes.sm,
              decoration: DsBoxDecoration(
                color: hovered ? _onVideoHover : null,
                borderRadius: theme.radii.controlCorners(null, theme.sizes.sm),
              ),
              child: Center(
                child: DsIcon(icon, size: theme.sizes.iconSm, color: selected ? _onVideo : _onVideoMuted),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The live position bar: the buffered span behind, the position over it.
/// A nominal or unknown duration keeps the bar at its start, which is the
/// truth of a live stream.
final class _LiveBar extends StatelessWidget {
  const _LiveBar({required this.position, required this.buffered, required this.duration});

  final Duration position;
  final Duration buffered;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final total = duration.inMilliseconds;
    if (total <= 0) {
      return const DsLine(color: _onVideoSubtle);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final bufferedFraction = (buffered.inMilliseconds / total).clamp(0.0, 1.0);
        final positionFraction = (position.inMilliseconds / total).clamp(0.0, 1.0);
        return SizedBox(
          height: 3,
          child: Stack(
            children: [
              const ColoredBox(color: Color(0x33FFFFFF), child: SizedBox.expand()),
              FractionallySizedBox(
                widthFactor: bufferedFraction,
                child: const ColoredBox(color: _onVideoSubtle, child: SizedBox.expand()),
              ),
              FractionallySizedBox(
                widthFactor: positionFraction,
                child: const ColoredBox(color: _onVideo, child: SizedBox.expand()),
              ),
              PositionedDirectional(
                start: width * positionFraction - 4,
                top: -2.5,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: DsBoxDecoration(color: _onVideo, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
