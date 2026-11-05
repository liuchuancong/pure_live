import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:ui' show ImageFilter;

import 'package:desen_ui/desen_ui.dart';
import 'package:flame_barrage/flame_barrage.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/gestures.dart' show PointerScrollEvent, kTouchSlop;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_device/live_device.dart'
    show PlatformBatteryService, PlatformScreenBrightnessService, ScreenBrightnessScope, ScreenBrightnessService;
import 'package:live_sites/live_sites.dart' show LivePlayLine, LiveRoom, LiveStreamCodec, LiveStreamFormat;
import 'package:media_core/media_core.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/recorder/recorder.dart';
import 'package:pure_live/modules/live/room/chat/room_message_actions.dart' show showRoomMessageActions;
import 'package:pure_live/modules/live/room/controller/room_controller.dart';
import 'package:pure_live/modules/live/room/page/audio_only_cover.dart' show AudioOnlyCover;
import 'package:pure_live/modules/live/room/page/room_screenshot.dart' show takeRoomScreenshot;
import 'package:pure_live/modules/live/room/page/room_status.dart'
    show RoomPictureAction, RoomPictureDim, RoomPictureKind, pictureStateOf, roomSlowProvider;
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
        room == null
            ? null
            : () => unawaited(controller.open(platform: room.ref.platform, roomId: room.ref.roomId, known: room)),
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
    required this.roomMenu,
    this.onCloseRoom,
    this.immersive = false,
    this.keepControls = false,
    this.autofocusFirstControl = false,
    this.tv = false,
    this.portraitFullscreen = false,
    this.canEnterPortraitFullscreen = false,
    this.onPortraitFullscreen,
    this.onPortraitSwipe,
    this.overlay,
    this.bottomInset = 0,
    this.theater = false,
    this.onTheater,
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

  /// Sizes the bars for a TV screen: larger controls, wider gaps, larger
  /// label type and a focus ring, because a remote has no pointer and the
  /// viewer sits far from the picture (§10.5).
  final bool tv;

  /// Whether the room is in its portrait full-screen presentation.
  final bool portraitFullscreen;

  /// Whether a portrait stream offers the entry button.
  final bool canEnterPortraitFullscreen;

  /// Enter portrait full screen (the page owns the presentation).
  final VoidCallback? onPortraitFullscreen;

  /// A vertical swipe in the middle third of the portrait full screen: +1
  /// for the next room, -1 for the previous (the page owns the list).
  final ValueChanged<int>? onPortraitSwipe;

  /// How much of the picture's bottom edge a page layer covers: the narrow
  /// room's chat sheet rides over the stream, so the control bar and the strip
  /// that wakes it stand above the sheet instead of under a panel the viewer
  /// cannot see through.
  ///
  /// The settled height, not the live one: dragging the sheet moves the sheet,
  /// not the buttons, so the control row never jitters along with a finger.
  final double bottomInset;

  /// A page layer over the picture and under the surface's own controls: the
  /// wide room's theatre floats its chat here, so the stream's pickers, the
  /// bars and the statistics still draw above it.
  final Widget? overlay;

  /// Whether the page is showing its theatre arrangement.
  final bool theater;

  /// Shows or hides the theatre; null where the page has none to offer (a
  /// narrow window, a presentation mode that owns the window).
  final VoidCallback? onTheater;

  /// The room's own actions (details, switch room, share, capture…), the same
  /// list the page header's menu shows: in fullscreen the header is gone and
  /// these have to stay reachable.
  final List<Widget> roomMenu;

  @override
  ConsumerState<PlayerSurface> createState() => _PlayerSurfaceState();
}

final class _PlayerSurfaceState extends ConsumerState<PlayerSurface> {
  bool _controlsVisible = true;
  Timer? _hideTimer;

  /// The fullscreen lock: the picture answers nothing but its own unlock
  /// button.
  bool _locked = false;

  /// A stream picker panel is open over the picture: the bars stay while it
  /// is, or the panel would vanish under the pointer that is using it.
  bool _panelOpen = false;

  StreamSubscription<PlayerTransportState>? _transportSub;

  /// The volume the viewer is dragging, and the bar that shows it; null
  /// when no drag or wheel is in flight.
  double? _volumeHud;
  Timer? _volumeHudTimer;
  double _dragVolume = 0;

  /// Which figure the chip is showing: the volume, or the screen brightness the
  /// picture's left half adjusts.
  bool _hudIsBrightness = false;
  bool _dragIsBrightness = false;

  /// The screen brightness the left half adjusts, and whether this platform will
  /// take the write at all. Asked once: a desktop with no DDC-capable monitor
  /// answers `unsupported`, and there the whole picture stays the volume rather
  /// than offering a gesture that does nothing.
  final ScreenBrightnessService _screenBrightness = const PlatformScreenBrightnessService();
  bool? _brightnessWritable;
  ScreenBrightnessScope _brightnessScope = ScreenBrightnessScope.application;
  int _brightness = 100;
  double _dragBrightness = 100;

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
    unawaited(_syncBrightness());
  }

  /// Asks the display what it can do, and where the brightness stands now.
  Future<void> _syncBrightness() async {
    try {
      final capabilities = await _screenBrightness.getCapabilities();
      final scope = capabilities.supportsScope(ScreenBrightnessScope.application)
          ? ScreenBrightnessScope.application
          : ScreenBrightnessScope.system;
      final value = capabilities.canRead ? await _screenBrightness.getBrightness(scope: scope) : null;
      if (!mounted) return;
      setState(() {
        _brightnessWritable = capabilities.canOfferBrightnessControl;
        _brightnessScope = scope;
        if (value != null) _brightness = value.clamp(0, 100);
      });
    } on Object {
      // A display that will not answer simply has no brightness half.
      if (mounted) setState(() => _brightnessWritable = false);
    }
  }

  @override
  void didUpdateWidget(PlayerSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The lock belongs to a picture that fills the window. Leaving fullscreen
    // releases it, or its unlock button would go on floating over the page's
    // own picture with the wheel, the drag and the tap switched off under it.
    if (_locked && !widget.immersive) setState(() => _locked = false);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _volumeHudTimer?.cancel();
    _pickerHover?.cancel();
    _pickerLeave?.cancel();
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

  /// Saves the frame on screen into the viewer's screenshot folder.
  ///
  /// The action only exists while the handle says it can capture (an engine
  /// route or the rendered surface); the toast names the file, because a frame
  /// that saves silently is a frame the viewer has to go looking for.
  Future<void> _screenshot() async {
    final handle = widget.roomState.handle;
    if (handle == null) return;
    await takeRoomScreenshot(context, ref, handle);
  }

  // -- The stream's catalogues ----------------------------------------------
  // The quality, the line and the picture's fit belong beside the transport,
  // not in the strip that names the room: they change *what is playing*, and
  // the bottom bar is where a viewer reaching for them already is. Their cards
  // open upwards, over the bar that raised them.
  _Picker? _openPicker;
  Timer? _pickerHover;
  Timer? _pickerLeave;
  final GlobalKey _barKey = GlobalKey(debugLabel: 'room-bar');
  final Map<_Picker, GlobalKey> _pickerAnchors = {
    for (final picker in _Picker.values) picker: GlobalKey(debugLabel: 'room-picker-${picker.name}'),
  };

  void _showPicker(_Picker picker) {
    _pickerHover?.cancel();
    _pickerLeave?.cancel();
    if (_openPicker == picker) return;
    final wasClosed = _openPicker == null;
    setState(() => _openPicker = picker);
    if (wasClosed) _setPanelOpen(true);
  }

  void _hidePicker() {
    _pickerHover?.cancel();
    _pickerLeave?.cancel();
    if (_openPicker == null) return;
    setState(() => _openPicker = null);
    _setPanelOpen(false);
  }

  void _togglePicker(_Picker picker) {
    _wake();
    if (_openPicker == picker) {
      _hidePicker();
    } else {
      _showPicker(picker);
    }
  }

  /// A pointer resting on a picker opens it after a breath, so crossing the bar
  /// on the way to the transport does not flash every catalogue.
  void _hoverPicker(_Picker picker) {
    _pickerLeave?.cancel();
    _pickerHover?.cancel();
    _pickerHover = Timer(const Duration(milliseconds: 160), () {
      if (mounted) _showPicker(picker);
    });
  }

  /// The pointer leaving gets a moment to reach the card above it.
  void _hoverPickerClose() {
    _pickerHover?.cancel();
    _pickerLeave?.cancel();
    _pickerLeave = Timer(const Duration(milliseconds: 260), () {
      if (mounted) _hidePicker();
    });
  }

  /// The width each catalogue asks for; the host centres the card on its
  /// picker with this measure.
  static double _panelWidth(_Picker picker) => switch (picker) {
    _Picker.quality => 200,
    _Picker.line => 240,
    _Picker.fit => 200,
  };

  /// The open picker's catalogue.
  Widget _pickerPanel(Translations t, _Picker picker) {
    final room = widget.roomState;
    final controller = ref.read(roomProvider.notifier);
    switch (picker) {
      case _Picker.quality:
        final current = room.quality ?? (room.qualities.isEmpty ? null : room.qualities.first);
        return PlayerOverlayPanel(
          title: t.room.quality,
          width: _panelWidth(picker),
          children: [
            for (final option in room.qualities)
              PlayerPanelOption(
                label: option.displayLabel,
                selected: option == current,
                onPressed: () {
                  _hidePicker();
                  unawaited(controller.selectQuality(option));
                },
              ),
          ],
        );
      case _Picker.line:
        return PlayerOverlayPanel(
          title: t.room.lineLabel,
          width: _panelWidth(picker),
          children: [
            for (final (index, option) in room.lines.indexed)
              PlayerPanelOption(
                label: _lineShortLabel(t, option, index),
                detail: _lineDetail(option),
                selected: index == room.lineIndex,
                onPressed: () {
                  _hidePicker();
                  unawaited(controller.selectLine(index));
                },
              ),
          ],
        );
      case _Picker.fit:
        final current = ref.read(playbackSettingsProvider).fit;
        return PlayerOverlayPanel(
          title: t.settings.fit,
          width: _panelWidth(picker),
          children: [
            for (final (index, option) in PlaybackFit.values.indexed)
              PlayerPanelOption(
                label: fitLabels(t)[index],
                selected: option == current,
                onPressed: () {
                  _hidePicker();
                  unawaited(ref.read(playbackSettingsProvider.notifier).setFit(option));
                },
              ),
          ],
        );
    }
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
      _hidePicker();
      setState(() => _controlsVisible = false);
    } else {
      _wake();
    }
  }

  /// Locks or unlocks the picture.
  ///
  /// Locked, the bars are gone, the picture takes no wheel, no drag, no tap
  /// and no danmaku, and only this button stays on screen — the reference's
  /// reason for the control: a viewer who leans on the wheel, or reaches
  /// across the keyboard, should not be left having changed the volume or
  /// paused the stream they were watching.
  void _toggleLock() {
    // An open catalogue is a control the lock is meant to put away, and it
    // holds the bars up behind it.
    if (!_locked) _hidePicker();
    setState(() => _locked = !_locked);
    _scheduleHide();
  }

  /// A tap on the picture: the reference's D-038 rule. With lines flying,
  /// nearly every tap lands on one, so a tap that finds the bars away brings
  /// them back whatever it hit; a message opens its actions only while the
  /// bars already show, and not on a picture that is stopped — there the tap
  /// is the way back to play.
  Future<void> _onPictureTap() async {
    // Locked, the picture answers nothing: a tap must neither open the
    // message under the finger nor bring the bars back.
    if (_locked) return;
    if (_openPicker != null) {
      // The catalogue is the thing the viewer is done with; a tap on the
      // picture closes it the way tapping anywhere else would.
      _hidePicker();
      return;
    }
    final shownBefore = _controlsVisible;
    if (!ref.read(danmakuTapInteractionProvider)) {
      _releaseDanmaku();
      _toggleControls();
      return;
    }
    final item = _takeHeldDanmaku();
    if (item == null || !shownBefore || !widget.roomState.playback.playing) {
      // The message was frozen on pointer-down; this tap was never going to
      // open it, so it flies on and the bars take the tap instead.
      if (item != null) widget.barrage?.resumeAllPaused();
      _toggleControls();
      return;
    }
    await _showDanmakuActions(item);
  }

  /// A long press pins the message under the finger and opens the same
  /// actions as a tap; empty space keeps the normal controls behaviour.
  Future<void> _onPictureLongPress() async {
    if (_locked) return;
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
    if (_locked) return;
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

  /// Shows the figure the picture's gesture is setting; [brightness] says which
  /// one it is, so the glyph and the number always agree.
  void _showAdjust(double value, {bool brightness = false}) {
    _volumeHudTimer?.cancel();
    setState(() {
      _volumeHud = value.clamp(0.0, 1.0);
      _hudIsBrightness = brightness;
    });
    _volumeHudTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _volumeHud = null);
    });
  }

  /// A vertical drag takes the volume from where it is: up is louder, the
  /// whole picture is the track (no brightness half to confuse the pinch).
  /// A vertical drag on the picture: the right half is the volume, the left half
  /// the screen's brightness — the arrangement every video surface the viewer
  /// already knows uses. The brightness half exists only where the display will
  /// take the write; elsewhere the whole picture is the volume, so no half is
  /// ever a gesture that does nothing.
  void _beginPictureDrag(double dx, double width) {
    _dragIsBrightness = _brightnessWritable == true && dx < width / 2;
    if (_dragIsBrightness) {
      _dragBrightness = _brightness.toDouble();
      _showAdjust(_brightness / 100, brightness: true);
      return;
    }
    _dragVolume = ref.read(roomProvider.notifier).volume;
    _showAdjust(_dragVolume);
  }

  void _dragPictureBy(double delta) {
    if (_dragIsBrightness) {
      // The same travel as the volume: a full-height drag crosses the range.
      final next = (_dragBrightness - delta / 2.2).clamp(0.0, 100.0);
      _dragBrightness = next;
      _showAdjust(next / 100, brightness: true);
      // A native write only when the whole percent actually moved — a drag
      // reports a delta per frame, and the display takes one value per percent.
      if (next.round() != _brightness) {
        _brightness = next.round();
        unawaited(
          _screenBrightness.setBrightness(_brightness, scope: _brightnessScope).catchError((Object _) => _brightness),
        );
      }
      return;
    }
    final next = (_dragVolume - delta / 220).clamp(0.0, 1.0);
    _dragVolume = next;
    _showAdjust(next);
    unawaited(ref.read(roomProvider.notifier).setVolume(next));
  }

  /// A wheel step takes the viewer's chosen share of the range (the
  /// 画质与音频 setting), so a desktop mouse has a usable granularity
  /// without a slider.
  void _wheelVolume(double delta) {
    final step = ref.read(playbackSettingsProvider).volumeWheelStepPercent / 100;
    final next = (ref.read(roomProvider.notifier).volume + (delta > 0 ? -step : step)).clamp(0.0, 1.0);
    _showAdjust(next);
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
  }) => playerBarrageConfig(
    style,
    fps,
    family: family,
    area: area,
    fixedDuration: Duration(milliseconds: (ref.read(danmakuFixedDurationProvider) * 1000).round()),
    compact: compact,
  );

  @override
  Widget build(BuildContext context) {
    final room = widget.roomState;
    // A local for the room itself: a record field is not promotable, and the
    // picture states need to know the cover's owner is there.
    final roomInfo = room.room;
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
    final showDanmaku = playback.danmakuVisible && (!mini || playback.miniDanmakuVisible);
    final longPressInteraction = showDanmaku && ref.watch(danmakuLongPressInteractionProvider);
    final playing = room.playback.playing;
    // The capture that has to outlive the chrome (see the pill below).
    final liveCapture = roomRecordingTaskOf(ref.watch(recordingTasksProvider).tasks, room.room);
    final recording = liveCapture?.state == RecordingTaskState.recording;
    // A paused or failed stream keeps the bar up; a playing one lets it go.
    //
    // The pause's own card counts as one: it carries no verb of its own, so a
    // bar that disappeared with the play button left the viewer with no way back
    // on a touch screen — the picture would be paused and silent of controls.
    final barOverPicture = picture.kind == RoomPictureKind.none || picture.kind == RoomPictureKind.paused;
    // Locked, no bar is drawn: the lock's whole word is that the picture is
    // not to be adjusted, and a bar that stayed up under the lock would offer
    // the adjustments anyway.
    final showBar = handle != null && barOverPicture && !_locked && (_controlsVisible || !playing);
    _watchTransport(handle);
    ref.listen(roomProvider.select((state) => state.playback.playing), (previous, next) {
      if (next) {
        _scheduleHide();
      } else if (mounted) {
        _hideTimer?.cancel();
        setState(() => _controlsVisible = true);
      }
    });
    return PlayerBarTier(
      tv: widget.tv,
      child: Focus(
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
              else
                MediaPlayerView(handle: handle, fit: playback.fit.boxFit),
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
                                area: style.area,
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
                            config: _barrageConfig(style, danmakuFps, family: danmakuFamily, area: style.area),
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
              //
              // A paused picture keeps this too: the double tap is how the viewer
              // comes back, and a stream that answers no gesture while it is
              // stopped reads as a frozen player.
              if (barOverPicture)
                Listener(
                  onPointerSignal: (event) {
                    if (_locked) return;
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
                      if (_locked) return;
                      if (mini) {
                        widget.onLeave();
                        return;
                      }
                      unawaited(ref.read(roomProvider.notifier).togglePlayPause());
                    },
                    // The compact window is dragged by its picture: it has no
                    // caption of its own to grab. The main window is not — its
                    // title band is the handle (see _roomAppBar), which frees the
                    // whole picture for the two adjustment halves below.
                    onPanStart: mini
                        ? (_) {
                            final window = ref.read(windowsPipWindowProvider);
                            if (window != null) unawaited(window.startDragging());
                          }
                        : null,
                    onVerticalDragStart: mini
                        ? null
                        : (details) {
                            _releaseDanmaku();
                            if (_locked) return;
                            final width = context.size?.width ?? MediaQuery.sizeOf(context).width;
                            final swipe = widget.onPortraitSwipe;
                            if (widget.portraitFullscreen &&
                                swipe != null &&
                                details.localPosition.dx >= width / 3 &&
                                details.localPosition.dx <= width * 2 / 3) {
                              _swipingPortrait = true;
                              _portraitSwipeDy = 0;
                              return;
                            }
                            _beginPictureDrag(details.localPosition.dx, width);
                          },
                    onVerticalDragUpdate: mini
                        ? null
                        : (details) {
                            if (_swipingPortrait) {
                              _portraitSwipeDy += details.delta.dy;
                              return;
                            }
                            _dragPictureBy(details.delta.dy);
                          },
                    onVerticalDragEnd: mini
                        ? null
                        : (details) {
                            if (!_swipingPortrait) return;
                            _swipingPortrait = false;
                            final dy = _portraitSwipeDy + (details.primaryVelocity ?? 0) * 0.08;
                            _portraitSwipeDy = 0;
                            if (dy.abs() < 80) return;
                            widget.onPortraitSwipe?.call(dy < 0 ? 1 : -1);
                          },
                    onVerticalDragCancel: mini
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
                  // The glyph names the figure, so a drag on the left half never
                  // reads as the volume it is not.
                  child: PlayerVolumeHud(value: volume, icon: _hudIsBrightness ? DsIcons.sun : null),
                ),
              if (picture.kind != RoomPictureKind.none)
                Stack(
                  fit: StackFit.expand,
                  children: [
                    // The reference draws the room's own cover behind a picture
                    // that is not there: an offline room reads as *that room*, not
                    // as a black screen with a sentence on it.
                    if (picture.dim == RoomPictureDim.cover && roomInfo != null) _RoomCoverBackdrop(room: roomInfo),
                    // A card that offers no verb must not eat the pointer: the
                    // pause's own word is not a control, and the tap or double
                    // tap that ends the pause has to reach the gesture layer
                    // under it. A card that does carry buttons keeps its scrim.
                    IgnorePointer(
                      ignoring: picture.actions.isEmpty,
                      child: ColoredBox(
                        color: _veilOf(picture.dim, withCover: picture.dim == RoomPictureDim.cover && roomInfo != null),
                      ),
                    ),
                    Center(
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
                  ],
                ),
              // The page's own layer: the theatre's chat sits over the picture
              // but under the bars and panels, so choosing a quality while the
              // glass column is open still shows the catalogue.
              ?widget.overlay,
              if (showBar && !mini)
                PositionedDirectional(
                  top: 0,
                  start: 0,
                  end: 0,
                  child: _PlayerTopBar(
                    room: room,
                    onLeave: widget.onLeave,
                    onWake: _wake,
                    menuItems: widget.immersive ? widget.roomMenu : const [],
                    fullscreen: widget.immersive,
                    portraitExit: widget.portraitFullscreen,
                    // The page's own header already carries the avatar, the live
                    // ring, the counts and the title above the picture, so the
                    // strip only names the room once the chrome is gone — or on
                    // a TV, where the title belongs on the screen itself.
                    identity: widget.immersive || widget.tv,
                  ),
                ),
              // The compact window's own strip: its caption is hidden, so this is
              // the only place that carries the window verbs. It never hides —
              // without it the small window would have no way back.
              // A running capture outlives the chrome: whether the disk is
              // still filling must not need a mouse wiggle to answer, and the
              // strip's own copy hides with the bar. This is the quiet-hours
              // version of it — the same control, so tapping it stops.
              if (recording && !showBar && !mini)
                PositionedDirectional(
                  // The left corner: the right one belongs to the stats panel
                  // when that is open, and two glass pills stacked in one
                  // corner read as a bug. With the bar away, nothing else
                  // lives here — the strip that would is hidden with the bar.
                  top: DsSpace.s8,
                  start: DsSpace.s12,
                  child: PlayerGlassPill(
                    child: RecordingIndicator(
                      startedAt: liveCapture?.startedAt,
                      figures: liveCapture == null || liveCapture.bytes <= 0
                          ? null
                          : formatRecordingBytes(liveCapture.bytes),
                      label: context.t.room.stopRecording,
                      tv: widget.tv,
                      // Locked, it is a mark and not a switch: the figures
                      // stay, the accidental tap that would end the take does
                      // not. The verb is back in the bar the moment unlocks.
                      onStop: _locked ? null : () => unawaited(toggleRoomRecording(context, ref)),
                    ),
                  ),
                ),
              if (mini)
                PositionedDirectional(
                  top: 0,
                  start: 0,
                  end: 0,
                  child: _PipBar(room: room, onRestore: widget.onLeave, onClose: widget.onCloseRoom ?? widget.onLeave),
                ),
              if (showBar && !mini)
                Positioned(
                  bottom: widget.bottomInset,
                  left: 0,
                  right: 0,
                  child: MouseRegion(
                    onEnter: (_) => _hideTimer?.cancel(),
                    onExit: (_) => _scheduleHide(),
                    child: _ControlBar(
                      key: _barKey,
                      handle: handle,
                      transport: transport,
                      onWake: _wake,
                      onScreenshot: () => unawaited(_screenshot()),
                      canScreenshot: handle.canCaptureScreenshot,
                      streamPickers: ({required labelled}) => _StreamPickerRow(
                        room: room,
                        open: _openPicker,
                        anchors: _pickerAnchors,
                        labelled: labelled,
                        onToggle: _togglePicker,
                        onHoverOpen: _hoverPicker,
                        onHoverClose: _hoverPickerClose,
                      ),
                      autofocusPlay: widget.autofocusFirstControl,
                      canEnterPortraitFullscreen: widget.canEnterPortraitFullscreen,
                      portraitFullscreen: widget.portraitFullscreen,
                      onPortraitFullscreen: widget.onPortraitFullscreen,
                      theater: widget.theater,
                      onTheater: widget.onTheater,
                    ),
                  ),
                )
              // The bar away, the picture keeps an invisible strip along its
              // bottom edge as the place to wake it from — not the shared idle
              // progress line, because a live stream has no played share to
              // draw and a line of its own would read as a timeline.
              else if (playing && !mini && handle != null && !_locked)
                Positioned(
                  bottom: widget.bottomInset,
                  left: 0,
                  right: 0,
                  child: _IdleWakeStrip(onWake: _wake),
                ),
              // The stream's own numbers when the viewer asked for them: a small
              // glass panel under the top bar, over the picture and out of the
              // buttons' way.
              if (handle != null &&
                  picture.kind == RoomPictureKind.none &&
                  !_locked &&
                  ref.watch(playerStatsVisibleProvider))
                PositionedDirectional(
                  // The strip's own height, from the same tier that sizes it:
                  // 8 of padding, the control, 12 below it. A literal here sat
                  // under the strip the moment the TV tier grew the controls.
                  top: showBar && !mini ? DsSpace.s8 + PlayerBarTier.controlSize(context) + DsSpace.s12 : DsSpace.s12,
                  end: 12,
                  child: PlayerStatsOverlay(handle: handle),
                ),
              // The open catalogue, above the bar that raised it: the host only
              // paints its card, so the picture stays tappable around it.
              if (_openPicker case final picker?)
                Positioned.fill(
                  child: PlayerPanelHost(
                    anchorKey: _pickerAnchors[picker]!,
                    barKey: _barKey,
                    width: _panelWidth(picker),
                    child: MouseRegion(
                      onEnter: (_) => _pickerLeave?.cancel(),
                      onExit: (_) => _hoverPickerClose(),
                      child: _pickerPanel(context.t, picker),
                    ),
                  ),
                ),
              // The lock, on the picture's right edge (the reference's
              // LockButton): it comes with the bars, and once it is on it is
              // the only thing drawn — whatever the room does next. A locked
              // picture with no unlock on it is a door bricked from inside.
              if (widget.immersive && !mini && (_locked || showBar))
                PositionedDirectional(
                  end: 20,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: PlayerGlassPill(
                      child: PlayerBarButton(
                        icon: _locked ? DsIcons.unlock : DsIcons.lock,
                        label: _locked ? context.t.room.unlockControls : context.t.room.lockControls,
                        size: 50,
                        iconSize: 22,
                        onPressed: _toggleLock,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The veil over a picture state's backdrop.
///
/// `cover` normally means "this state has the room's picture to show", so the
/// veil is lighter when the cover is actually drawn — otherwise the image would
/// be there only to be hidden. Every other level is the same dark the state has
/// always used.
Color _veilOf(RoomPictureDim dim, {required bool withCover}) => switch (dim) {
  RoomPictureDim.none => const Color(0x00000000),
  RoomPictureDim.light => const Color(0x66000000),
  RoomPictureDim.heavy => const Color(0xB3000000),
  RoomPictureDim.cover => withCover ? const Color(0x99000000) : const Color(0xE6000000),
};

/// The room's own cover, blurred, behind a picture that is not there.
///
/// It is the same image the feed and the follow list show, so a viewer who
/// opened this room recognises it; the blur keeps the state's text legible
/// without a second dark card on top of it.
final class _RoomCoverBackdrop extends StatelessWidget {
  const _RoomCoverBackdrop({required this.room});

  final LiveRoom room;

  @override
  Widget build(BuildContext context) {
    final cover = room.content.coverUrl.trim();
    if (cover.isEmpty) return const SizedBox.shrink();
    return RepaintBoundary(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: kLiveGlassCoverFrostSigma, sigmaY: kLiveGlassCoverFrostSigma),
        child: Image(
          image: cachedImage(cover),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// The stream's own catalogues: quality, line and the picture's fit.
///
/// They live in the bottom bar, beside the transport, because they change what
/// is playing rather than who is playing: the strip above the picture names the
/// room and carries its state, and a viewer looking for "why is this blurry"
/// reaches for the bar they just used to unmute it.
final class _StreamPickerRow extends ConsumerWidget {
  const _StreamPickerRow({
    required this.room,
    required this.open,
    required this.anchors,
    required this.labelled,
    required this.onToggle,
    required this.onHoverOpen,
    required this.onHoverClose,
  });

  final RoomState room;

  /// The catalogue currently open, if any.
  final _Picker? open;

  /// Each picker's box: the card opens over the button that raised it.
  final Map<_Picker, GlobalKey> anchors;

  /// Whether the current choice's words fit beside the glyph.
  final bool labelled;

  final ValueChanged<_Picker> onToggle;
  final ValueChanged<_Picker> onHoverOpen;
  final VoidCallback onHoverClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final lines = room.lines;
    final lineIndex = room.lineIndex.clamp(0, lines.isEmpty ? 0 : lines.length - 1);
    final line = lines.isEmpty ? null : lines[lineIndex];
    final quality = room.quality ?? (room.qualities.isEmpty ? null : room.qualities.first);
    final fit = ref.watch(playbackSettingsProvider).fit;
    final tv = PlayerBarTier.tvOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: tv ? DsSpace.s8 : DsSpace.s4,
      children: [
        if (room.qualities.isNotEmpty && quality != null)
          _button(
            context,
            picker: _Picker.quality,
            icon: DsIcons.gauge,
            label: quality.displayLabel,
            semanticLabel: t.room.quality,
          ),
        if (line != null && lines.length > 1)
          _button(
            context,
            picker: _Picker.line,
            icon: DsIcons.route,
            label: _lineShortLabel(t, line, lineIndex),
            semanticLabel: t.room.lineLabel,
          ),
        _button(
          context,
          picker: _Picker.fit,
          icon: DsIcons.aspectRatio,
          // The picker is named for what it chooses; the panel under it says
          // which fit is on.
          label: labelled ? t.room.fitShort : fitLabels(t)[fit.index],
          semanticLabel: t.settings.fit,
        ),
      ],
    );
  }

  /// One picker: the glyph, the current choice's words when there is room, and
  /// the chevron that points the way the card opens — up, over the bar.
  Widget _button(
    BuildContext context, {
    required _Picker picker,
    required DsIconData icon,
    required String label,
    required String semanticLabel,
  }) {
    final theme = DsTheme.of(context);
    final tv = PlayerBarTier.tvOf(context);
    final isOpen = open == picker;
    final side = tv ? theme.sizes.lg : theme.sizes.sm;
    return KeyedSubtree(
      key: anchors[picker],
      child: MouseRegion(
        onEnter: (_) => onHoverOpen(picker),
        onExit: (_) => onHoverClose(),
        child: TvFocusScale(
          child: DsPressable(
            semanticLabel: semanticLabel,
            onPressed: () => onToggle(picker),
            builder: (context, states, _) {
              final focused = states.contains(WidgetState.focused);
              final lit = isOpen || states.contains(WidgetState.hovered) || focused;
              final corners = theme.radii.controlCorners(null, side);
              return Container(
                height: side,
                padding: EdgeInsets.symmetric(
                  horizontal: tv
                      ? DsSpace.s12
                      : labelled
                      ? DsSpace.s8
                      : DsSpace.s6,
                ),
                decoration: DsBoxDecoration(color: lit ? _onVideoHover : null, borderRadius: corners),
                foregroundDecoration: tv && focused
                    ? BoxDecoration(
                        border: Border.all(color: playerInk, width: 2),
                        borderRadius: corners,
                      )
                    : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: DsSpace.s4,
                  children: [
                    // With room for words the glyph steps aside: 「原画
                    // 1080P60 ⌄」 reads as the reference draws it.
                    if (!labelled)
                      DsIcon(icon, size: tv ? theme.sizes.iconLg : theme.sizes.iconSm, color: _onVideoMuted),
                    if (labelled)
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: tv ? 128 : 96),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          // A TV reads from across the room: the value takes
                          // the control-label size instead of the caption.
                          style: (tv ? theme.typography.label : theme.typography.caption).copyWith(color: _onVideo),
                        ),
                      ),
                    DsIcon(isOpen ? DsIcons.chevronDown : DsIcons.chevronUp, size: tv ? 14 : 12, color: _onVideoMuted),
                  ],
                ),
              );
            },
          ),
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
  const _PlayerTopBar({
    required this.room,
    required this.onLeave,
    required this.onWake,
    required this.menuItems,
    this.fullscreen = false,
    this.portraitExit = false,
    this.identity = true,
  });

  final RoomState room;
  final VoidCallback onLeave;

  /// Resets the bars' auto-hide timer after a press.
  final VoidCallback onWake;

  /// The room's own actions, shared with the page header's menu.
  final List<Widget> menuItems;

  /// Whether the picture fills the window: the strip then carries the clock
  /// and the battery, because the window's own chrome — and with it the
  /// system's tray — is not on screen to be read.
  final bool fullscreen;

  /// Whether that window is the portrait full screen: the back arrow is then
  /// the only way out, so its name says which of the two it leaves.
  final bool portraitExit;

  /// Whether the strip names the room. The page's own header already carries
  /// the avatar, the live ring, the counts and the title above the picture, so
  /// in-page the strip keeps only the presentation cluster; once the chrome is
  /// gone (fullscreen, window fullscreen, portrait) the identity comes back.
  final bool identity;

  @override
  ConsumerState<_PlayerTopBar> createState() => _PlayerTopBarState();
}

/// The catalogues the control bar offers: the stream's quality, the line behind
/// it and how the picture is fitted into its box.
enum _Picker { quality, line, fit }

/// The strip above the picture: the room's presentation, and — where the page
/// has no header of its own — who is streaming and whether it is live.
///
/// The identity half appears only when the strip is told to carry it: in-page
/// the room's avatar, live ring, counts and title already sit in the header
/// above the picture, and
/// repeating them over the image is a band of noise on top of what the viewer
/// came to look at. In fullscreen, window fullscreen and portrait the chrome is
/// gone, so the strip takes it back. Nothing here changes what is playing — the
/// transport, the stream's quality and the picture's fit all live on the bar
/// below, where a viewer reaching for "it looks wrong" already is. The right
/// half is the cluster of *how the picture is being shown*: recording, the small
/// window and the cast target all move or copy the stream rather than choosing
/// it, and each has a state worth seeing at a glance — so a running capture
/// breathes up here beside them. The far end carries the room's own menu, so the
/// actions the page header offers do not vanish in fullscreen; under the narrow
/// tier the three presentation verbs leave the strip for that menu, which keeps
/// the title readable.
final class _PlayerTopBarState extends ConsumerState<_PlayerTopBar> {
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
    final tv = PlayerBarTier.tvOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // The same floor the control bar uses for its medium tier: below it a
        // strip has room for status, not for three more verbs.
        final narrow = constraints.maxWidth < 460;
        final cluster = _PresentationCluster(room: widget.room, onWake: widget.onWake, narrow: narrow);
        final menuPill = widget.menuItems.isEmpty
            ? const SizedBox.shrink()
            : PlayerGlassPill(
                child: DsMenuAnchor(
                  semanticLabel: t.common.more,
                  align: DsAlign.end,
                  items: widget.menuItems,
                  builder: (context, controller, _) => PlayerBarButton(
                    icon: DsIcons.ellipsisVertical,
                    label: t.common.more,
                    onPressed: () {
                      widget.onWake();
                      controller.toggle();
                    },
                  ),
                ),
              );
        if (!widget.identity) {
          // The page header above already names the room, so over the picture
          // only the verbs stay — each in a glass disc of its own (the
          // reference's row of four), the flying danmaku's switch first — and
          // no gradient band darkening an image the viewer is watching.
          return Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s8, DsSpace.s12, DsSpace.s12, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: DsSpace.s8,
              children: [
                _DanmakuTogglePill(onWake: widget.onWake),
                _PresentationCluster(room: widget.room, onWake: widget.onWake, narrow: narrow, split: true),
                menuPill,
              ],
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.fromLTRB(DsSpace.s8, DsSpace.s8, DsSpace.s12, DsSpace.s12),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topCenter,
              end: AlignmentDirectional.bottomCenter,
              colors: [Color(0xB3000000), Color(0x00000000)],
            ),
          ),
          child: Row(
            spacing: tv ? DsSpace.s12 : DsSpace.s8,
            children: [
              PlayerGlassPill(
                child: PlayerBarButton(
                  icon: DsIcons.chevronLeft,
                  label: widget.portraitExit ? t.room.portraitFullscreenExit : t.common.close,
                  onPressed: widget.onLeave,
                ),
              ),
              if (widget.fullscreen) const _PlayerClockBattery(),
              if (label != null)
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // The room's name takes the next size up on a TV: it is the
                    // one line the viewer reads from the sofa.
                    style: (tv ? theme.typography.heading : theme.typography.title).copyWith(color: _onVideo),
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
              // The danmaku's switch, in every tier: a viewer who came for the
              // lines and wants them off does not leave the picture to find
              // the one control that is about the picture.
              _DanmakuTogglePill(onWake: widget.onWake),
              cluster,
              menuPill,
            ],
          ),
        );
      },
    );
  }
}

/// The flying danmaku's own switch, as the strip draws it in both tiers.
///
/// One preference and one control, drawn twice: in-page it leads the row of
/// overlay verbs, and in fullscreen the reference keeps it on the bar beside
/// the play button — a viewer who wants the lines gone should not have to
/// leave the picture to say so.
final class _DanmakuTogglePill extends ConsumerWidget {
  const _DanmakuTogglePill({required this.onWake});

  /// Resets the bars' auto-hide timer after the press.
  final VoidCallback onWake;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(playbackSettingsProvider);
    final t = context.t;
    return PlayerGlassPill(
      child: PlayerBarButton(
        icon: settings.danmakuVisible ? DsIcons.captions : DsIcons.captionsOff,
        label: settings.danmakuVisible ? t.room.danmakuOff : t.room.danmakuOn,
        selected: settings.danmakuVisible,
        onPressed: () {
          onWake();
          unawaited(ref.read(playbackSettingsProvider.notifier).setDanmakuVisible(value: !settings.danmakuVisible));
        },
      ),
    );
  }
}

/// The capture task that belongs to [detail], or null.
///
/// The task store is the truth both the strip's indicator and the page menu's
/// row follow, so a capture started in an earlier visit or by the schedule
/// reads the same in every one of them.
RecordingTask? roomRecordingTaskOf(Iterable<RecordingTask> tasks, LiveRoom? detail) {
  if (detail == null) return null;
  final id = '${detail.ref.platform}:${detail.ref.roomId}';
  return tasks.where((task) => task.id == id).firstOrNull;
}

/// Starts or stops this room's capture and answers which happened.
Future<void> toggleRoomRecording(BuildContext context, WidgetRef ref) async {
  final t = context.t;
  final recording =
      roomRecordingTaskOf(ref.read(recordingTasksProvider).tasks, ref.read(roomProvider).room)?.state ==
      RecordingTaskState.recording;
  final failure = await ref.read(roomProvider.notifier).toggleRecording();
  if (!context.mounted) return;
  showDsToast(
    context: context,
    title: failure == null ? (recording ? t.room.recordStopped : t.room.recordStarted) : t.room.recordFailed,
    status: failure == null ? DsStatus.success : DsStatus.danger,
  );
}

/// Enters or leaves the small window. A phone's system window can refuse (no
/// on-screen player layer, a device that cannot present it): saying so beats a
/// button that did nothing.
Future<void> toggleRoomPip(BuildContext context, WidgetRef ref) async {
  final t = context.t;
  final player = ref.read(roomProvider).handle?.id;
  if (player == null) return;
  final accepted = await ref.read(roomPresentationProvider.notifier).togglePip(player);
  if (accepted || !context.mounted) return;
  showDsToast(context: context, title: t.common.pipUnavailable);
}

/// The strip's presentation cluster: the capture, the small window and the cast
/// target — the three verbs about where this picture goes rather than which
/// stream it is.
///
/// A running capture replaces its own button with the breathing indicator, so
/// the strip never shows two red things for one fact and the elapsed count sits
/// where the viewer already looks for the room's state.
final class _PresentationCluster extends ConsumerWidget {
  const _PresentationCluster({required this.room, required this.onWake, required this.narrow, this.split = false});

  final RoomState room;

  /// Resets the bars' auto-hide timer after a press.
  final VoidCallback onWake;

  /// Whether the strip has room for the verbs; below it they live in the menu.
  final bool narrow;

  /// One glass disc per verb instead of one pill holding them: the in-page
  /// strip's form. The running capture is then said on the control bar
  /// below (its red dot and word), so the disc here only starts or stops it.
  final bool split;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final detail = room.room;
    final line = room.lines.isEmpty ? null : room.lines[room.lineIndex.clamp(0, room.lines.length - 1)];
    final presentation = ref.watch(roomPresentationProvider);
    final pipAvailable = room.handle != null && ref.read(roomPresentationProvider.notifier).pipAvailable;
    final task = roomRecordingTaskOf(ref.watch(recordingTasksProvider).tasks, detail);
    final recording = task?.state == RecordingTaskState.recording;
    // A take that is not writing is still a fact about this room: a subscription
    // armed and waiting for its streamer, a capture whose segments are still
    // being joined, and a take that ended in failure. None of them had a word on
    // the bar, which showed the plain record button instead — the strip that
    // reads as "nothing is happening here" while a take is queued or unfinished.
    final pending = recording ? null : task;
    final joining = pending?.postProcessing ?? false;
    // A joining take says how far the join got, the way the reference's badge
    // does (合成中 45%): a join runs minutes, the strip has no progress bar,
    // and a word alone cannot answer "is it moving or stuck".
    String joinWord(RecordingTask take) {
      if (take.postProcessingProgress < 0) return t.recorder.stateProcessing;
      return '${t.recorder.stateProcessing} ${(take.postProcessingProgress.clamp(0.0, 1.0) * 100).round()}%';
    }

    final pendingWord = switch (pending) {
      null => null,
      final RecordingTask take when take.postProcessing => joinWord(take),
      final RecordingTask take when take.state == RecordingTaskState.waiting => t.recorder.stateWaiting,
      final RecordingTask take when take.state == RecordingTaskState.failed => t.recorder.stateFailed,
      _ => null,
    };
    // What the strip has room for. A narrow tier with nothing running shows no
    // cluster at all — an empty glass pill would be a hole in the strip — and a
    // word is wider than the icon it replaces, so it waits for room.
    final showRecord = recording || (!narrow && (line != null || pendingWord != null));
    final showPip = !narrow && pipAvailable;
    // Casting needs a stream to cast at, and the narrow tier has no room for
    // the verb: the line is what the picker is aimed at.
    final castLine = narrow ? null : line;
    if (!showRecord && !showPip && castLine == null) return const SizedBox.shrink();
    final tv = PlayerBarTier.tvOf(context);
    if (split) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        spacing: DsSpace.s8,
        children: [
          if (showRecord)
            PlayerGlassPill(
              child: PlayerBarButton(
                icon: DsIcons.disc,
                label: recording ? t.room.stopRecording : t.room.record,
                selected: recording,
                onPressed: () {
                  onWake();
                  unawaited(toggleRoomRecording(context, ref));
                },
              ),
            ),
          if (castLine != null)
            PlayerGlassPill(
              child: PlayerBarButton(
                icon: DsIcons.cast,
                label: t.room.cast,
                onPressed: () {
                  onWake();
                  unawaited(showCastDialog(context, line: castLine, title: detail?.content.title));
                },
              ),
            ),
          if (showPip)
            PlayerGlassPill(
              child: PlayerBarButton(
                icon: presentation == PresentationMode.pip ? DsIcons.pictureInPictureExit : DsIcons.pictureInPicture,
                label: presentation == PresentationMode.pip ? t.room.pipOff : t.room.pipOn,
                selected: presentation == PresentationMode.pip,
                onPressed: () {
                  onWake();
                  unawaited(toggleRoomPip(context, ref));
                },
              ),
            ),
        ],
      );
    }
    return PlayerGlassPill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: tv ? DsSpace.s8 : DsSpace.s4,
        children: [
          if (recording || pendingWord != null)
            RecordingIndicator(
              startedAt: recording ? task?.startedAt : null,
              showTimer: !narrow,
              // The take's size beside its clock: a growing number is the only
              // proof that a capture is still writing, and the engine's own
              // progress write is what makes it move once a second.
              figures: task == null || !recording || task.bytes <= 0 ? null : formatRecordingBytes(task.bytes),
              word: pendingWord,
              // The TV tier grows every control on the bar; the indicator is
              // one of them, or it reads as a smudge from the sofa (§10.5).
              tv: tv,
              label: recording ? t.room.stopRecording : t.room.record,
              // A joining take has nothing to press: starting again now would
              // answer a question the viewer did not ask.
              onStop: joining
                  ? null
                  : () {
                      onWake();
                      unawaited(toggleRoomRecording(context, ref));
                    },
            )
          else if (showRecord)
            PlayerBarButton(
              icon: DsIcons.disc,
              label: t.room.record,
              onPressed: () {
                onWake();
                unawaited(toggleRoomRecording(context, ref));
              },
            ),
          if (showPip)
            PlayerBarButton(
              icon: presentation == PresentationMode.pip ? DsIcons.pictureInPictureExit : DsIcons.pictureInPicture,
              label: presentation == PresentationMode.pip ? t.room.pipOff : t.room.pipOn,
              selected: presentation == PresentationMode.pip,
              onPressed: () {
                onWake();
                unawaited(toggleRoomPip(context, ref));
              },
            ),
          if (castLine != null)
            PlayerBarButton(
              icon: DsIcons.cast,
              label: t.room.cast,
              onPressed: () {
                onWake();
                unawaited(showCastDialog(context, line: castLine, title: detail?.content.title));
              },
            ),
        ],
      ),
    );
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

/// The clock and the battery of a fullscreen strip (the reference's
/// `PlayerClock` and `PlayerBattery`, beside its back button).
///
/// Fullscreen has no system bar to read: how late it is, and on a phone how
/// long the picture has left before the battery gives out, are questions a
/// tray answers everywhere else. The clock redraws when the minute turns and
/// nothing else; the battery is read once and then every minute, and a machine
/// that reports no battery at all — a desktop answers `-1` — draws no figure,
/// rather than a 0 a viewer would read as a laptop about to die.
final class _PlayerClockBattery extends StatefulWidget {
  const _PlayerClockBattery();

  @override
  State<_PlayerClockBattery> createState() => _PlayerClockBatteryState();
}

final class _PlayerClockBatteryState extends State<_PlayerClockBattery> {
  static const PlatformBatteryService _battery = PlatformBatteryService();

  DateTime _now = DateTime.now();
  int? _level;
  Timer? _minute;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _scheduleClock();
    unawaited(_readBattery());
    _poll = Timer.periodic(const Duration(minutes: 1), (_) => unawaited(_readBattery()));
  }

  /// Fires on the minute's turn, not 60 s after the strip opened: a timer
  /// started at 21:04:30 would otherwise still say 21:05 half a minute into
  /// the next one.
  void _scheduleClock() {
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
    _minute = Timer(next.difference(now) + const Duration(milliseconds: 50), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _scheduleClock();
    });
  }

  Future<void> _readBattery() async {
    try {
      final level = await _battery.readLevel();
      if (!mounted || level < 0) return;
      setState(() => _level = level);
    } on Object {
      // A platform that will not answer the call gets no figure, not a zero.
    }
  }

  @override
  void dispose() {
    _minute?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final figure = theme.typography
        .numeric(theme.typography.caption)
        .copyWith(color: _onVideo, fontWeight: FontWeight.w600);
    final level = _level;
    String two(int value) => value.toString().padLeft(2, '0');
    return PlayerGlassPill(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: DsSpace.s6,
          children: [
            Text('${two(_now.hour)}:${two(_now.minute)}', style: figure),
            if (level != null) ...[
              DsIcon(_batteryGlyph(level), size: 14, color: _onVideo),
              Text('$level%', style: figure),
            ],
          ],
        ),
      ),
    );
  }
}

/// The case that fits the reading: the figure carries the number, so the
/// glyph only has to say how near either end of it the battery stands.
DsIconData _batteryGlyph(int level) => switch (level) {
  <= 10 => DsIcons.batteryEmpty,
  <= 25 => DsIcons.batteryLow,
  <= 75 => DsIcons.batteryMedium,
  _ => DsIcons.batteryHigh,
};

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
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: playerSignal),
          ),
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
    // A capture keeps breathing in the small window too: shrinking the picture
    // must not hide the one state that is still writing to disk. No timer here
    // — the strip is 28 px and the dot is the news.
    final detail = room.room;
    final capture = detail == null
        ? null
        : ref
              .watch(recordingTasksProvider)
              .tasks
              .where((item) => item.id == '${detail.ref.platform}:${detail.ref.roomId}')
              .firstOrNull;
    final recordingFrom = capture?.state == RecordingTaskState.recording ? capture?.startedAt : null;
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
          // The small window carries no menu of its own, so the dot has to be
          // the stop control: a recording started before the window shrank must
          // end from where the viewer is looking at it.
          RecordingIndicator(
            startedAt: recordingFrom,
            showTimer: false,
            label: t.room.stopRecording,
            onStop: () => unawaited(toggleRoomRecording(context, ref)),
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
    // The pressable draws the focus ring itself, so a remote can reach what a
    // pointer used to tap; the visuals stay the 28 px square they were.
    return DsPressable(
      semanticLabel: label,
      onPressed: onPressed,
      builder: (context, states, child) => SizedBox(
        width: 28,
        height: 28,
        child: Center(child: DsIcon(icon, size: 14, color: _onVideoMuted)),
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
    this.onScreenshot,
    this.canScreenshot = false,
    this.streamPickers,
    this.autofocusPlay = false,
    this.canEnterPortraitFullscreen = false,
    this.portraitFullscreen = false,
    this.onPortraitFullscreen,
    this.theater = false,
    this.onTheater,
    super.key,
  });

  final PlayerHandle handle;

  /// The latest transport snapshot, null until the first event.
  final PlayerTransportState? transport;

  /// Resets the bar's auto-hide timer after an interaction.
  final VoidCallback onWake;

  /// Saves the frame on screen; null when the surface offers no action.
  final VoidCallback? onScreenshot;

  /// Whether the handle can capture a frame at all.
  final bool canScreenshot;

  /// The stream's own catalogues (quality, line, fit), placed beside the
  /// transport where a viewer looks for them.
  ///
  /// Built with the bar's own width, because that is the box the result has to
  /// fit: a theatre arrangement or an open chat panel leaves a narrow stage
  /// inside a wide window, and words chosen from the window's size overflowed
  /// the strip. `labelled` says whether the current choice's words fit beside
  /// the glyph.
  final Widget Function({required bool labelled})? streamPickers;

  /// Focuses the play button when it first builds (the TV room's start).
  final bool autofocusPlay;

  /// Whether a portrait stream offers the entry button.
  final bool canEnterPortraitFullscreen;

  /// Whether the portrait full-screen surface is already showing.
  final bool portraitFullscreen;

  /// Enters portrait full screen.
  final VoidCallback? onPortraitFullscreen;

  /// Whether the page is showing its theatre arrangement.
  final bool theater;

  /// Shows or hides the theatre; null where the page offers none.
  final VoidCallback? onTheater;

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
    final immersive = presentationController.modeOwnsWindow(presentation);
    final tv = PlayerBarTier.tvOf(context);
    final task = roomRecordingTaskOf(ref.watch(recordingTasksProvider).tasks, room.room);
    final recordingTask = task?.state == RecordingTaskState.recording ? task : null;
    return Container(
      padding: EdgeInsets.fromLTRB(
        tv ? DsSpace.s16 : DsSpace.s12,
        tv ? DsSpace.s12 : DsSpace.s8,
        tv ? DsSpace.s16 : DsSpace.s12,
        tv ? DsSpace.s12 : DsSpace.s8,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.bottomCenter,
          end: AlignmentDirectional.topCenter,
          colors: [Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      // A live stream has no timeline to draw: what used to sit above these
      // buttons was a seek bar that could not seek. The buffer and latency
      // facts live in the stats overlay and in the picture's own buffering
      // state, so the bar is the buttons alone.
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The compact window (and a phone's 16:9 strip) has no room
          // for labels: the pickers keep their icons, and a small
          // window only keeps the transport and the way out.
          final pip = presentation == PresentationMode.pip && presentationController.pipOwnsWindow;
          // Two widths, each a superset of the other: a phone keeps the
          // verbs a live room cannot do without, and a desktop bar has room
          // for the volume slider, the capture and the window verbs. The
          // presentation cluster — record, small window, cast — left for
          // the strip above, so the 460 floor has no decisions of its own
          // here any more.
          final wide = constraints.maxWidth >= 720;
          // Below the width the transport, the divider, the danmaku toggle and
          // the icon-only pickers all fit side by side, the bar sheds the
          // danmaku verb and its divider: the picture's own catalogues are the
          // cluster a viewer reaches for when the picture looks wrong, and the
          // danmaku has a home in the chat panel's header too.
          final crowded = constraints.maxWidth < 320;
          final bar = Row(
            // A TV bar spaces its controls wider: the remote jumps
            // between them, and a distant viewer needs the separation.
            spacing: tv ? DsSpace.s8 : DsSpace.s4,
            children: [
              PlayerBarButton(
                icon: playing ? DsIcons.pause : DsIcons.play,
                label: playing ? t.room.pause : t.room.play,
                autofocus: autofocusPlay,
                onPressed: () {
                  onWake();
                  unawaited(controller.togglePlayPause());
                },
              ),
              // Mute is core at every width: a room that opens loud has to
              // be silencable with one thumb.
              PlayerBarButton(
                icon: muted ? DsIcons.volumeOff : DsIcons.volume,
                label: muted ? t.room.unmute : t.room.mute,
                onPressed: () {
                  onWake();
                  unawaited(controller.setMuted(value: !muted));
                },
              ),
              if (wide) ...[
                SizedBox(
                  width: tv ? 140 : 90,
                  child: DsSlider(
                    value: volume,
                    onChanged: (value) {
                      onWake();
                      unawaited(controller.setVolume(value));
                    },
                    semanticLabel: t.room.volume,
                  ),
                ),
                PlayerBarButton(
                  icon: room.audioOnly ? DsIcons.video : DsIcons.headphones,
                  label: room.audioOnly ? t.room.restoreVideo : t.room.audioOnlyMode,
                  onPressed: () {
                    onWake();
                    unawaited(controller.setAudioOnly(value: !room.audioOnly));
                  },
                ),
                // A running capture is said here, beside the transport, as
                // the reference does: the red dot and the word, the elapsed
                // count with them, and a press ends it.
                if (recordingTask != null) ...[
                  const SizedBox(width: DsSpace.s4),
                  RecordingIndicator(
                    startedAt: recordingTask.startedAt,
                    figures: recordingTask.bytes <= 0 ? null : formatRecordingBytes(recordingTask.bytes),
                    tv: tv,
                    label: t.room.stopRecording,
                    onStop: () {
                      onWake();
                      unawaited(toggleRoomRecording(context, ref));
                    },
                  ),
                ],
              ],
              const Spacer(),
              if (!crowded) const _BarDivider(),
              // -- What is playing: the stream's own catalogues. This is the
              // cluster a viewer reaches for when the picture looks wrong, so
              // it sits beside the transport. (The flying danmaku's switch
              // lives on the strip above, with the other overlay verbs.)
              if (!pip) ?streamPickers?.call(labelled: wide),
              // -- Capture, then the window verbs, then the way out of the
              // picture's box. Recording and casting sit in the strip above
              // with the room's state: they say where this picture goes, and
              // a running capture has a state worth seeing at a glance.
              if (wide && !pip && canScreenshot && onScreenshot != null)
                PlayerBarButton(
                  icon: DsIcons.camera,
                  label: t.room.screenshot,
                  onPressed: () {
                    onWake();
                    onScreenshot!();
                  },
                ),
              if (wide && !pip && _desktop && player != null)
                PlayerBarButton(
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
              if (wide &&
                  !pip &&
                  canEnterPortraitFullscreen &&
                  !portraitFullscreen &&
                  presentation == PresentationMode.normal)
                PlayerBarButton(
                  icon: DsIcons.rectangleVertical,
                  label: t.room.portraitFullscreen,
                  onPressed: () {
                    onWake();
                    onPortraitFullscreen?.call();
                  },
                ),
              // The theatre is the page's own arrangement, so the page
              // decides where it exists; the bar only carries the verb.
              if (wide && !pip && onTheater != null)
                PlayerBarButton(
                  icon: DsIcons.layoutHeaderSidebarRight,
                  label: theater ? t.room.theaterOff : t.room.theaterOn,
                  selected: theater,
                  onPressed: () {
                    onWake();
                    onTheater!();
                  },
                ),
              if (!pip && player != null)
                PlayerBarButton(
                  icon: immersive ? DsIcons.minimize2 : DsIcons.fullscreen,
                  label: immersive ? t.room.fullscreenOff : t.room.fullscreenOn,
                  selected: immersive,
                  onPressed: () {
                    onWake();
                    unawaited(presentationController.toggleFullscreen(player));
                  },
                ),
            ],
          );
          return bar;
        },
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
  Widget build(BuildContext context) {
    final tv = PlayerBarTier.tvOf(context);
    return Container(
      width: 1,
      height: tv ? 20 : 16,
      margin: EdgeInsets.symmetric(horizontal: tv ? DsSpace.s8 : DsSpace.s4),
      color: const Color(0x40FFFFFF),
    );
  }
}

/// The strip the live room keeps while its bar is hidden: the same hit height
/// as the shared idle line, with nothing drawn. Hovering or tapping it wakes
/// the controls; a live picture has no progress to show in the meantime.
final class _IdleWakeStrip extends StatelessWidget {
  const _IdleWakeStrip({required this.onWake});

  /// Wakes the bar this strip belongs to.
  final VoidCallback onWake;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => onWake(),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onWake,
      child: const SizedBox(height: 14, width: double.infinity),
    ),
  );
}
