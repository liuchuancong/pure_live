import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:ui' show ImageFilter;

import 'package:desen_ui/desen_ui.dart';
import 'package:flame_barrage/flame_barrage.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/gestures.dart' show PointerScrollEvent, kTouchSlop;
import 'package:flutter/services.dart' show KeyDownEvent, KeyUpEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:live_device/live_device.dart'
    show PlatformBatteryService, PlatformScreenBrightnessService, ScreenBrightnessScope, ScreenBrightnessService;
import 'package:live_sites/live_sites.dart'
    show LivePlayLine, LiveRoom, LiveRoomRefIdentity, LiveStreamCodec, LiveStreamFormat;
import 'package:media_core/media_core.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/archive/archive_navigation.dart' show openArchives;
import 'package:pure_live/modules/live/favorites/data/follow_repository.dart' show followsProvider;
import 'package:pure_live/modules/live/recorder/recorder.dart';
import 'package:pure_live/modules/live/room/chat/room_chat.dart' show roomChatSettingsAskProvider;
import 'package:pure_live/modules/live/room/chat/room_message_actions.dart' show showRoomMessageActions;
import 'package:pure_live/modules/live/room/controller/room_controller.dart';
import 'package:pure_live/modules/live/room/page/audio_only_cover.dart' show AudioOnlyCover;
import 'package:pure_live/modules/live/room/page/room_follow.dart' show toggleRoomFollow;
import 'package:pure_live/modules/live/room/page/room_screenshot.dart' show takeRoomScreenshot;
import 'package:pure_live/modules/live/room/page/room_status.dart'
    show RoomPictureAction, RoomPictureDim, RoomPictureKind, pictureStateOf, roomSlowProvider;
import 'package:pure_live/modules/live/room/panels/room_panel.dart' show showRoomDetails;
// The replay bar's clock words: the one duration formatter the app keeps
// ("12:34" or "1:02:03"), the same the vod player's own bar reads.
import 'package:pure_live/modules/vod/widgets/vod_widgets.dart' show vodDurationText;
import 'package:pure_live/shared/shared.dart';

/// Opens the creator's replay catalog from the room: the covered decoder
/// goes quiet when a recording opens, and the room reads its own picture
/// again after the walk to resume what it parked.
Future<void> _openReplays(BuildContext context, WidgetRef ref, LiveRoom room) async {
  final controller = ref.read(roomProvider.notifier);
  final walked = await openArchives(
    context,
    room: room,
    push: (arguments) => context.push<Object?>(RouteNames.archive, extra: arguments),
    beforePlay: controller.pause,
  );
  if (!walked || !context.mounted) return;
  // A decoder parked by the walk plays again; a room the viewer had
  // personally paused keeps their choice.
  if (pictureStateOf(context.t, ref.read(roomProvider)).kind == RoomPictureKind.paused) {
    await controller.togglePlayPause();
  }
}

/// The picture's own ink: the frame is dark whatever the app's theme, so
/// the bars, the state overlay and the position line never borrow the
/// surface's ink (which turns dark-on-dark in a light theme).
const Color _onVideo = OnVideoColors.foreground;
const Color _onVideoMuted = OnVideoColors.inkMuted;
const Color _onVideoSubtle = OnVideoColors.inkSubtle;
const Color _onVideoHover = OnVideoColors.inkHover;

/// The stage around and behind the video: always black, in every theme —
/// a missing frame reads as a dark screen, never as a flash of the theme's
/// surface while the window changes size.
const Color kPlayerStageColor = OnVideoColors.ground;

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
      RoomPictureAction.openReplays => (
        t.room.replayOpen,
        room == null ? null : () => unawaited(_openReplays(context, ref, room)),
      ),
    };
    return DsButton(onPressed: onPressed, autofocus: autofocus, child: Text(label));
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
    this.onPortraitRestore,
    this.onTitle,
    this.onSwitchRoom,
    this.ambient = false,
    this.overlay,
    this.bottomInset = 0,
    this.topBarEndInset = DsSpace.s12,
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

  /// The portrait full screen's way back to the page's own layout: an upward
  /// swipe that starts in the picture's lowest band, or along its bottom bar
  /// (the reference's swipe up to the panel). The page owns the presentation;
  /// null where the swipe means nothing.
  final VoidCallback? onPortraitRestore;

  /// Opens the room's details from its name on the strip. A phone held
  /// sideways has no column for the room's own card, so the strip names the
  /// room in-page and its name takes the card's press; null leaves the strip
  /// as its layout draws it.
  final VoidCallback? onTitle;

  /// Switches to the room `step` places away in the list this room came
  /// from (+1 the next, -1 the previous). The TV room's scope hands it a
  /// held Up or Down; the page answers with its own room switch, so the
  /// surface stays mounted and only the room changes. Null leaves the
  /// arrows to the dpad's own traversal.
  final ValueChanged<int>? onSwitchRoom;

  /// Whether the frame sits over the room's own art instead of black bars (the
  /// reference's ambient presentation): the page asks for it where the room
  /// frames its stream as portrait, and on the portrait full screen whatever
  /// the stream's shape. Only the viewer's contain fit takes it — the others
  /// crop, stretch or size the frame on their own terms.
  final bool ambient;

  /// How much of the picture's bottom edge a page layer covers: the narrow
  /// room's chat sheet rides over the stream, so the control bar and the strip
  /// that wakes it stand above the sheet instead of under a panel the viewer
  /// cannot see through.
  ///
  /// The settled height, not the live one: dragging the sheet moves the sheet,
  /// not the buttons, so the control row never jitters along with a finger.
  final double bottomInset;

  /// A page layer over the picture and under the surface's own controls: a
  /// layout that floats its chat over the frame hands it in here, so the
  /// stream's pickers, the bars and the statistics still draw above it.
  final Widget? overlay;

  /// The room's own actions (details, switch room, share, capture…), the same
  /// list the page header's menu shows: in fullscreen the header is gone and
  /// these have to stay reachable.
  final List<Widget> roomMenu;

  /// The room left where the top strip's trailing verbs end: the floating
  /// chat drawer (方案B) reserves the picture's right edge, and the strip,
  /// the statistics panel and the pickers keep out from under it.
  final double topBarEndInset;

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

  /// The TV room switch's debounce: a held Up or Down adds its step to
  /// [_switchStep], and only when the remote has been quiet for the window
  /// does the room switch — by as many places as the hold gathered, the way
  /// the reference's channel keys walk a long list.
  Timer? _switchDebounce;
  int _switchStep = 0;

  /// The scope's own stop: the keyboard lands here when no bar control
  /// holds it, and the scope's Up and Down switch rooms from there.
  late final FocusNode _scopeFocus = FocusNode(debugLabel: 'tv room scope');

  /// The open catalogue's stop: while a picker panel is up it holds the
  /// keyboard, so Escape closes the card and does not fall through to the
  /// page's own Escape — which would leave the presentation with the panel
  /// still meaning to be closed.
  late final FocusNode _panelFocus = FocusNode(debugLabel: 'player panel');

  /// The remote's Up and Down on the TV room's picture: they switch rooms
  /// instead of moving focus, because a bar that never hides has no row the
  /// arrows should walk to first. An open picker panel owns the keys until
  /// it is done with them.
  KeyEventResult _onScopeKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (_panelOpen) return KeyEventResult.ignored;
    final step = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => -1,
      LogicalKeyboardKey.arrowDown => 1,
      _ => 0,
    };
    if (step == 0 || widget.onSwitchRoom == null) return KeyEventResult.ignored;
    _switchStep += step;
    _switchDebounce?.cancel();
    _switchDebounce = Timer(const Duration(milliseconds: 300), () {
      final gathered = _switchStep;
      _switchStep = 0;
      if (gathered != 0) widget.onSwitchRoom?.call(gathered);
    });
    return KeyEventResult.handled;
  }

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

  /// What the picture's vertical drag in flight does, decided where it began;
  /// null for nothing at all (a locked picture, or one begun on a system
  /// gesture edge).
  _PictureDrag? _pictureDrag;

  /// Where that drag's finger went down. The system's gesture edges and the
  /// portrait full screen's restore band are judged by where the gesture
  /// started, not by where the finger had got to once it read as a drag.
  DragDownDetails? _dragDown;

  /// The room switch's travel down the picture (upwards negative), in the
  /// portrait full screen's middle third.
  double _portraitSwipeDy = 0;

  /// The restore swipe's travel up the picture, never below zero.
  double _restoreTravel = 0;

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
    _switchDebounce?.cancel();
    _scopeFocus.dispose();
    _panelFocus.dispose();
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

  // -- The stream's catalogues ----------------------------------------------
  // The quality, the line and the picture's fit belong beside the transport,
  // not in the strip that names the room: they change *what is playing*, and
  // the bottom bar is where a viewer reaching for them already is. Their cards
  // open upwards, over the bar that raised them.
  _Picker? _openPicker;
  final GlobalKey _barKey = GlobalKey(debugLabel: 'room-bar');
  final Map<_Picker, GlobalKey> _pickerAnchors = {
    for (final picker in _Picker.values) picker: GlobalKey(debugLabel: 'room-picker-${picker.name}'),
  };

  void _showPicker(_Picker picker) {
    if (_openPicker == picker) return;
    final wasClosed = _openPicker == null;
    setState(() => _openPicker = picker);
    if (wasClosed) _setPanelOpen(true);
  }

  void _hidePicker() {
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

  /// The width each catalogue asks for; the host centres the card on its
  /// picker with this measure.
  static double _panelWidth(_Picker picker) => switch (picker) {
    _Picker.quality => 200,
    _Picker.line => 240,
    _Picker.fit => 180,
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
        final labels = fitLabels(t);
        return PlayerOverlayPanel(
          title: t.settings.fit,
          width: _panelWidth(picker),
          children: [
            for (final option in PlaybackFit.values)
              PlayerPanelOption(
                label: labels[option.index],
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
  /// tap (a double tap enters or leaves fullscreen, a drag sets the volume).
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

  /// The band along the portrait full screen's bottom edge an upward swipe
  /// restores the page's layout from (the reference's `portraitRestoreZone`):
  /// the bottom bar and as much again over it.
  static const double _restoreZone = 96;

  /// The bottom band an Android phone keeps for going home when the system
  /// reports none (the reference's `androidGestureFallback`): HyperOS reports
  /// only its top band while its bottom edge still goes home.
  static const double _androidGestureFallback = 32;

  /// What a vertical drag that went down at [down] and read as a drag at
  /// [start] does (the reference's gesture layer).
  ///
  /// The portrait full screen's restore band is asked first, so the way back to
  /// the chat is never read as a volume change. A drag that began on a system
  /// gesture edge is the system's and changes nothing here. In the portrait
  /// full screen the middle third switches rooms where the page offers it, as
  /// it always has; the halves set the volume and the brightness everywhere.
  _PictureDrag? _pictureDragAt(DragDownDetails? down, DragStartDetails start) {
    if (_locked) return null;
    final size = context.size ?? MediaQuery.sizeOf(context);
    final origin = down?.localPosition ?? start.localPosition;
    if (widget.onPortraitRestore != null && origin.dy >= size.height - _restoreZone) return _PictureDrag.restore;
    if (_onSystemGestureEdge(down?.globalPosition.dy ?? start.globalPosition.dy)) return null;
    final dx = start.localPosition.dx;
    final middleThird = dx >= size.width / 3 && dx <= size.width * 2 / 3;
    if (widget.portraitFullscreen && widget.onPortraitSwipe != null && middleThird) return _PictureDrag.switchRoom;
    return _PictureDrag.adjust;
  }

  /// Whether a drag that went down [globalY] down the window began in the
  /// system's own gesture band at its bottom or top edge (the reference's
  /// A07.15): going home, or pulling the status bar down, must not also change
  /// the volume, the brightness or the room. Global, because the picture need
  /// not fill the window. The side edges are Back's, a sideways gesture no
  /// vertical drag competes with, and are left alone. A desktop reports no
  /// bands, so every drag there stays as it was.
  bool _onSystemGestureEdge(double globalY) {
    final insets = MediaQuery.systemGestureInsetsOf(context);
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final fallback = android ? _androidGestureFallback : 0.0;
    final bottom = insets.bottom > 0 ? insets.bottom : fallback;
    final height = MediaQuery.sizeOf(context).height;
    return (bottom > 0 && globalY >= height - bottom) || (insets.top > 0 && globalY < insets.top);
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
    // The player the picture mounts on: the committed handle when it exists,
    // else the open's staged player (the sweep's engine, publishing itself
    // through RoomState.player from the moment it accepts a line). Mounting
    // for the staged engine is what lets the connect/probe window's frames
    // paint the moment they are decoded, instead of waiting for the commit —
    // which is itself that same player, so the mount never rebinds.
    final player = handle ?? room.player;
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
    final barOverPicture =
        picture.kind == RoomPictureKind.none ||
        picture.kind == RoomPictureKind.paused ||
        // Buffering, connecting and opening carry no verb of their own (their
        // cards ignore the pointer): a bar that vanished mid-stall left the
        // touch viewer with no way back, and the wheel went dead with it.
        // The failed and slow cards keep their own buttons, so the gesture
        // layer stays off there.
        picture.kind == RoomPictureKind.buffering ||
        picture.kind == RoomPictureKind.connecting ||
        picture.kind == RoomPictureKind.entering;
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
    return PopScope(
      // An open picker panel is a layer the remote's back peels first: the
      // route only pops when no panel is open. The dialogs above the room
      // pop on their own and never reach this.
      canPop: !_panelOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _hidePicker();
      },
      child: PlayerBarTier(
        tv: widget.tv,
        child: Focus(
          focusNode: _controlsFocus,
          canRequestFocus: false,
          skipTraversal: true,
          includeSemantics: false,
          // The reference's own rule: moving the pointer over the picture brings
          // the overlay back, a click is not needed. A touch screen never hovers,
          // so phones keep the tap.
          child: _tvScope(
            MouseRegion(
              onHover: mini ? null : (_) => _wake(),
              onExit: mini ? null : (_) => _scheduleHide(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (player == null)
                    const ColoredBox(color: kPlayerStageColor, child: SizedBox.expand())
                  else if (room.audioOnly && room.room != null)
                    AudioOnlyCover(room: room.room!)
                  else
                    // The room's art fills the bars only under the contain fit, the
                    // one that keeps the whole frame and leaves bars to fill; the
                    // small window is cut to the frame's own shape by its driver.
                    _AmbientPicture(
                      player: player,
                      art: widget.ambient && playback.fit == PlaybackFit.contain && !mini
                          ? _ambientArtOf(roomInfo)
                          : '',
                      child: MediaPlayerView(handle: player, fit: playback.fit.boxFit),
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
                  // enters or leaves fullscreen, a vertical drag and the wheel set
                  // the volume. The compact window keeps only the window verbs:
                  // dragging the picture moves the small window (its native caption
                  // is hidden) and a double press brings it back.
                  //
                  // A paused picture keeps this too: the tap still answers it, and a
                  // stream that answers no gesture while it is stopped reads as a
                  // frozen player. The way back to play is the bar's own button,
                  // which stays up for as long as the pause does.
                  if (barOverPicture)
                    Listener(
                      onPointerSignal: (event) {
                        // The lock and the open catalogue both own the wheel:
                        // scrolling over a quality card must not turn the
                        // volume under it.
                        if (_locked || _panelOpen) return;
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
                          // The fullscreen button's own verb: the reference's double
                          // tap, its button and F are one toggle, and play and pause
                          // keep the bar's button. A catalogue left open would only
                          // float over the picture in its new box, so the double
                          // tap puts it away the way a single tap would.
                          _hidePicker();
                          final committed = widget.roomState.handle?.id;
                          if (committed == null) return;
                          unawaited(ref.read(roomPresentationProvider.notifier).toggleFullscreen(committed));
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
                        // Where the finger went down decides what the drag is (see
                        // _pictureDragAt); by its start it has already moved.
                        onVerticalDragDown: mini ? null : (details) => _dragDown = details,
                        onVerticalDragStart: mini
                            ? null
                            : (details) {
                                _releaseDanmaku();
                                final drag = _pictureDragAt(_dragDown, details);
                                _pictureDrag = drag;
                                switch (drag) {
                                  case _PictureDrag.adjust:
                                    final width = context.size?.width ?? MediaQuery.sizeOf(context).width;
                                    _beginPictureDrag(details.localPosition.dx, width);
                                  case _PictureDrag.switchRoom:
                                    _portraitSwipeDy = 0;
                                  case _PictureDrag.restore:
                                    _restoreTravel = 0;
                                  case null:
                                    // Locked, or the system's edge: the drag is not
                                    // the picture's.
                                    break;
                                }
                              },
                        onVerticalDragUpdate: mini
                            ? null
                            : (details) {
                                switch (_pictureDrag) {
                                  case _PictureDrag.adjust:
                                    _dragPictureBy(details.delta.dy);
                                  case _PictureDrag.switchRoom:
                                    _portraitSwipeDy += details.delta.dy;
                                  case _PictureDrag.restore:
                                    _restoreTravel = (_restoreTravel - details.delta.dy).clamp(0.0, double.infinity);
                                  case null:
                                    break;
                                }
                              },
                        onVerticalDragEnd: mini
                            ? null
                            : (details) {
                                final drag = _pictureDrag;
                                _pictureDrag = null;
                                _dragDown = null;
                                final velocity = details.primaryVelocity ?? 0;
                                switch (drag) {
                                  case _PictureDrag.switchRoom:
                                    final dy = _portraitSwipeDy + velocity * 0.08;
                                    _portraitSwipeDy = 0;
                                    if (dy.abs() < 80) return;
                                    widget.onPortraitSwipe?.call(dy < 0 ? 1 : -1);
                                  case _PictureDrag.restore:
                                    final upward = _restoreTravel;
                                    _restoreTravel = 0;
                                    if (_swipeRestoresPanel(upward: upward, velocity: velocity)) {
                                      widget.onPortraitRestore?.call();
                                    }
                                  case _PictureDrag.adjust || null:
                                    break;
                                }
                              },
                        onVerticalDragCancel: mini
                            ? null
                            : () {
                                _pictureDrag = null;
                                _dragDown = null;
                                _portraitSwipeDy = 0;
                                _restoreTravel = 0;
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
                        // pause's own word is not a control, and the picture's tap,
                        // double tap and drags have to reach the gesture layer
                        // under it. A card that does carry buttons keeps its scrim.
                        IgnorePointer(
                          ignoring: picture.actions.isEmpty,
                          child: ColoredBox(
                            color: _veilOf(
                              picture.dim,
                              withCover: picture.dim == RoomPictureDim.cover && roomInfo != null,
                            ),
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
                  // The page's own layer: a chat that floats over the picture sits
                  // under the bars and panels, so choosing a quality while it is
                  // open still shows the catalogue.
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
                        endInset: widget.topBarEndInset,
                        // The page's own header already carries the avatar, the live
                        // ring, the counts and the title above the picture, so the
                        // strip only names the room once the chrome is gone — or on
                        // a TV, where the title belongs on the screen itself, or on a
                        // phone held sideways, whose room card has no column to sit
                        // in and folds into the strip instead.
                        identity: widget.immersive || widget.tv || widget.onTitle != null,
                        onTitle: widget.onTitle,
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
                      child: _PipBar(
                        room: room,
                        onRestore: widget.onLeave,
                        onClose: widget.onCloseRoom ?? widget.onLeave,
                      ),
                    ),
                  if (showBar && !mini)
                    Positioned(
                      bottom: widget.bottomInset,
                      left: 0,
                      right: 0,
                      child: MouseRegion(
                        onEnter: (_) => _hideTimer?.cancel(),
                        onExit: (_) => _scheduleHide(),
                        // The bar stands over the gesture layer and keeps the pointer
                        // from it, yet it is the floor of the portrait full screen's
                        // restore band: the swipe up is listened for here as well.
                        child: _RestoreSwipe(
                          onRestore: widget.onPortraitRestore,
                          child: _ControlBar(
                            key: _barKey,
                            handle: handle,
                            transport: transport,
                            onWake: _wake,
                            streamPickers: ({required labelled}) => _StreamPickerRow(
                              room: room,
                              open: _openPicker,
                              anchors: _pickerAnchors,
                              labelled: labelled,
                              onToggle: _togglePicker,
                            ),
                            autofocusPlay: widget.autofocusFirstControl,
                            canEnterPortraitFullscreen: widget.canEnterPortraitFullscreen,
                            portraitFullscreen: widget.portraitFullscreen,
                            onPortraitFullscreen: widget.onPortraitFullscreen,
                          ),
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
                      child: _RestoreSwipe(
                        onRestore: widget.onPortraitRestore,
                        child: _IdleWakeStrip(onWake: _wake),
                      ),
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
                      top: showBar && !mini
                          ? DsSpace.s8 + PlayerBarTier.controlSize(context) + DsSpace.s12
                          : DsSpace.s12,
                      end: widget.topBarEndInset,
                      child: PlayerStatsOverlay(handle: handle),
                    ),
                  // The open catalogue, above the bar that raised it. The layer
                  // is the panel's own modal: the keyboard lands on it (Escape
                  // puts the card away instead of leaving the presentation), and
                  // the transparent fill under the card takes an outside tap —
                  // the picture behind it unchanged, the panel gone with the
                  // click.
                  if (_openPicker case final picker?)
                    Positioned.fill(
                      child: Focus(
                        focusNode: _panelFocus,
                        autofocus: true,
                        onKeyEvent: (node, event) {
                          if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.escape) {
                            return KeyEventResult.ignored;
                          }
                          _hidePicker();
                          return KeyEventResult.handled;
                        },
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _hidePicker),
                            ),
                            PlayerPanelHost(
                              anchorKey: _pickerAnchors[picker]!,
                              barKey: _barKey,
                              width: _panelWidth(picker),
                              child: _pickerPanel(context.t, picker),
                            ),
                          ],
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
                            onPressed: _toggleLock,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The TV room's key scope: the one stop that holds the keyboard when no
  /// control does, so the remote's Up and Down switch rooms instead of
  /// dying on the picture. The pointer builds pass through.
  Widget _tvScope(Widget child) {
    if (!widget.keepControls) return child;
    return Focus(focusNode: _scopeFocus, autofocus: true, onKeyEvent: _onScopeKey, child: child);
  }
}

/// The veil over a picture state's backdrop.
///
/// `cover` normally means "this state has the room's picture to show", so the
/// veil is lighter when the cover is actually drawn — otherwise the image would
/// be there only to be hidden. Every other level is the same dark the state has
/// always used.
Color _veilOf(RoomPictureDim dim, {required bool withCover}) => switch (dim) {
  RoomPictureDim.none => OnVideoColors.clear,
  RoomPictureDim.light => OnVideoColors.dimLight,
  RoomPictureDim.heavy => OnVideoColors.scrim,
  RoomPictureDim.cover => withCover ? OnVideoColors.paneGlass : OnVideoColors.coverDimHeavy,
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
          image: cachedImage(cover, policy: ImageCachePolicies.liveRoomCover),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// The art a portrait frame sits over: the room's cover, else the streamer's
/// avatar (the reference's chain after its one platform's blurred frame, which
/// no site here sends). Empty when the room has neither.
String _ambientArtOf(LiveRoom? room) {
  if (room == null) return '';
  final cover = room.content.coverUrl.trim();
  if (cover.isNotEmpty) return cover;
  return (room.anchor?.avatarUrl ?? '').trim();
}

/// The largest box of [ratio] (width over height) inside [box]: where a frame
/// fitted whole lands.
Size _containedSize(double ratio, Size box) {
  final byHeight = box.height * ratio;
  return byHeight <= box.width ? Size(byHeight, box.height) : Size(box.width, box.width / ratio);
}

/// The picture, over the room's own art when [art] is given (the reference's
/// ambient presentation of a portrait stream).
///
/// The engine paints its own black around a fitted frame, so art stacked
/// behind a view the size of the stage would never be seen. The view is sized
/// to the frame's own shape instead — the engine then has no bars left to
/// paint — and the art takes the stage around it. Without art, or before the
/// engine reports a shape, the view keeps the stage's full size, so the
/// viewer's fit decides how the frame meets it exactly as before.
///
/// The tree keeps one shape whichever of the two it draws: a view that moved
/// in and out of a wrapper would rebuild the engine's surface every time the
/// frame's shape arrived or changed.
final class _AmbientPicture extends StatelessWidget {
  const _AmbientPicture({required this.player, required this.art, required this.child});

  /// The player whose frame's shape the view follows.
  final PlayerHandle player;

  /// The art behind the frame; empty for none.
  final String art;

  /// The view itself.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final geometry = player.geometryController;
    // The stream only says when to look again; the shape is read from the
    // controller itself, so a player handed over mid-subscription is never
    // drawn with the previous player's shape.
    return StreamBuilder<GeometryState>(
      stream: geometry.state,
      builder: (context, _) {
        final state = geometry.current;
        final ratio = state.hasVideo ? state.aspectRatio : 0.0;
        final framed = art.isNotEmpty && ratio > 0 && ratio.isFinite;
        return Stack(
          fit: StackFit.expand,
          children: [
            _AmbientBackdrop(art: framed ? art : ''),
            LayoutBuilder(
              builder: (context, constraints) {
                final box = constraints.biggest;
                final size = framed ? _containedSize(ratio, box) : box;
                return Center(
                  child: SizedBox(width: size.width, height: size.height, child: child),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// The room's art behind a portrait frame (the reference's `AmbientBackdrop`).
///
/// The image is decoded a couple of dozen pixels wide and drawn across the
/// stage, which blurs it once, at decode time: a blur filter under a live
/// picture would run again on every frame the picture paints. It is blown up a
/// little past the stage so the soft image never shows an edge, under a light
/// veil that keeps it the stage and the frame the thing on it.
final class _AmbientBackdrop extends StatelessWidget {
  const _AmbientBackdrop({required this.art});

  /// The image's address; empty leaves the stage its own black.
  final String art;

  /// The width the art is decoded at, in physical pixels (the reference's 24):
  /// small enough that drawn large it reads as a blur.
  static const int _decodeWidth = 24;

  @override
  Widget build(BuildContext context) {
    if (art.isEmpty) return const SizedBox.shrink();
    // Clipped to the stage: the blown-up image would otherwise paint over the
    // chat column or the room card beside it.
    return RepaintBoundary(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Transform.scale(
              scale: 1.14,
              child: Image(
                image: cachedImage(art, policy: ImageCachePolicies.albumCover, width: _decodeWidth),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (context, error, stack) => const SizedBox.shrink(),
              ),
            ),
            const ColoredBox(color: OnVideoColors.veil),
          ],
        ),
      ),
    );
  }
}

/// The stream's own catalogues: quality and line.
///
/// They live in the bottom bar, beside the transport, because they change what
/// is playing rather than who is playing: the strip above the picture names the
/// room and carries its state, and a viewer looking for "why is this blurry"
/// reaches for the bar they just used to unmute it. The picture's fit sits
/// beside them on the wide bar, its catalogue the same card the
/// quality and the line drop — one popup language for the bar.
/// The picture's fit on the wide bar: the current fit's words and the chevron
/// that points the way its list opens — up, over the bar — drawn like the
/// stream's own pickers beside it, wired to the surface's picker machinery
/// rather than a menu of its own.
final class _StreamPickerRow extends ConsumerWidget {
  const _StreamPickerRow({
    required this.room,
    required this.open,
    required this.anchors,
    required this.labelled,
    required this.onToggle,
  });

  final RoomState room;

  /// The catalogue currently open, if any.
  final _Picker? open;

  /// Each picker's box: the card opens over the button that raised it.
  final Map<_Picker, GlobalKey> anchors;

  /// Whether the current choice's words fit beside the glyph.
  final bool labelled;

  final ValueChanged<_Picker> onToggle;

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
          label: fitLabels(t)[fit.index],
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
        // The whole current value rides the tooltip: the words beside the
        // glyph truncate, and the glyph-only pass carries none of it.
        child: DsTooltip(
          message: label,
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
                        border: Border.all(color: OnVideoColors.foreground, width: 2),
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
    this.onTitle,
    this.endInset = DsSpace.s12,
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
  /// gone (fullscreen, window fullscreen, portrait) the identity comes back,
  /// and so it does on a phone held sideways, whose room card has no column.
  final bool identity;

  /// The room left where the strip's trailing verbs end: the floating chat
  /// drawer (方案B) reserves the picture's end edge, and the strip keeps out
  /// from under it.
  final double endInset;

  /// Opens the room's details from its name: the strip of a phone held
  /// sideways stands in for the room card, so the name takes the card's press
  /// and the page's own app bar keeps the way back. Null for a strip whose
  /// name is only a name.
  final VoidCallback? onTitle;

  @override
  ConsumerState<_PlayerTopBar> createState() => _PlayerTopBarState();
}

/// The catalogues the control bar offers: the stream's quality and the line
/// behind it. The picture's fit is the page's menu row, not a catalogue.
enum _Picker { quality, line, fit }

/// What a vertical drag on the picture changes, decided where it began.
enum _PictureDrag {
  /// The volume, or on the left half the screen's brightness.
  adjust,

  /// The portrait full screen's middle third: the next or the previous room.
  switchRoom,

  /// The portrait full screen's lowest band: back to the page's own layout.
  restore,
}

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
    final audience = detail?.audience.onlineViewers ?? detail?.audience.popularity ?? detail?.audience.totalViewers;
    final replay = detail?.broadcast.isRecord ?? false;
    final tv = PlayerBarTier.tvOf(context);
    final onTitle = widget.onTitle;
    // The wide chat column's own header carries the follow pill; wherever
    // that header stands, the picture's chip would be a second door to the
    // same verb — the chip is for the column that is not there.
    final columnCarriesFollow = ref.watch(chatModeProvider) == ChatMode.column && !ref.watch(chatCollapsedProvider);
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
        final capture = widget.room.handle;
        final audioPill = PlayerGlassPill(
          child: PlayerBarButton(
            icon: widget.room.audioOnly ? DsIcons.video : DsIcons.headphones,
            label: widget.room.audioOnly ? t.room.restoreVideo : t.room.audioOnlyMode,
            selected: widget.room.audioOnly,
            onPressed: () {
              widget.onWake();
              unawaited(ref.read(roomProvider.notifier).setAudioOnly(value: !widget.room.audioOnly));
            },
          ),
        );
        final screenshotPill = capture != null && capture.canCaptureScreenshot
            ? PlayerGlassPill(
                child: PlayerBarButton(
                  icon: DsIcons.camera,
                  label: t.room.screenshot,
                  onPressed: () {
                    widget.onWake();
                    unawaited(takeRoomScreenshot(context, ref, capture));
                  },
                ),
              )
            : null;
        if (!widget.identity) {
          // The page header above already names the room, so over the picture
          // only the verbs stay: the sound mode, a frame copy, and the three
          // picture destinations — one control per function, not a merged sheet.
          return Padding(
            padding: EdgeInsets.fromLTRB(DsSpace.s8, DsSpace.s12, widget.endInset, 0),
            child: Row(
              spacing: DsSpace.s8,
              children: [
                // The anchor and the follow verb ride the picture's top-left so
                // a folded column still offers them.
                if (!narrow && !columnCarriesFollow) _AnchorFollowChip(room: widget.room, onWake: widget.onWake),
                const Spacer(),
                audioPill,
                ?screenshotPill,
                _PresentationCluster(room: widget.room, onWake: widget.onWake, narrow: narrow, split: true),
              ],
            ),
          );
        }
        return Container(
          padding: EdgeInsets.fromLTRB(DsSpace.s8, DsSpace.s8, widget.endInset, DsSpace.s12),
          decoration: BoxDecoration(gradient: OnVideoColors.shade(edge: VerticalDirection.up)),
          child: Row(
            spacing: tv ? DsSpace.s12 : DsSpace.s8,
            children: [
              // A strip that stands in for the room card sits under the page's
              // own app bar, which already carries the way back.
              if (onTitle == null)
                PlayerGlassPill(
                  child: PlayerBarButton(
                    icon: DsIcons.chevronLeft,
                    label: widget.portraitExit ? t.room.portraitFullscreenExit : t.common.close,
                    onPressed: widget.onLeave,
                  ),
                ),
              if (widget.fullscreen) const _PlayerClockBattery(),
              // The strip's left is the anchor's identity and the follow verb —
              // a fullscreen room's only follow surface, its column folded away.
              // A press on the name opens the details where the strip stands in
              // for the card.
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _AnchorFollowChip(room: widget.room, onWake: widget.onWake, onTitle: onTitle),
                ),
              ),
              if (replay)
                PlayerGlassPill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s3),
                    child: Text(
                      t.favorites.statusReplay,
                      style: theme.typography.caption.copyWith(color: _onVideo, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              // The audience pill is a broadcast's number: a replay names
              // itself instead, and its figures stay in the room card and
              // the details panel.
              if (audience != null && !replay && constraints.maxWidth >= 480)
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
              // The sound mode and a frame copy keep their own controls; the
              // strip stays one control per function.
              ?screenshotPill,
              audioPill,
              cluster,
              menuPill,
            ],
          ),
        );
      },
    );
  }
}

/// The anchor's identity and the follow verb over the picture's top-left: a
/// glass pill the control bar's own show/hide carries, so a room whose column
/// is folded away — fullscreen above all — still offers follow and unfollow.
/// The name opens the details where the strip stands in for the room card.
final class _AnchorFollowChip extends ConsumerWidget {
  const _AnchorFollowChip({required this.room, required this.onWake, this.onTitle});

  final RoomState room;

  /// Resets the bar's auto-hide timer after a press.
  final VoidCallback onWake;

  /// Opens the room's details, where the strip folds the card into itself.
  final VoidCallback? onTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final detail = room.room;
    if (detail == null) return const SizedBox.shrink();
    final anchor = (detail.anchor?.name ?? '').trim();
    final name = anchor.isEmpty ? detail.content.title : anchor;
    final avatar = (detail.anchor?.avatarUrl ?? detail.content.coverUrl).trim();
    final key = detail.ref.identityKey;
    final followed = ref.watch(
      followsProvider.select((follows) => follows.rooms.any((room) => room.ref.identityKey == key)),
    );
    final tv = PlayerBarTier.tvOf(context);
    final onTitle = this.onTitle;
    return PlayerGlassPill(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s4, DsSpace.s3, DsSpace.s4, DsSpace.s3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: DsSpace.s6,
          children: [
            DsPressable(
              semanticLabel: t.room.detailsHint,
              onPressed: () {
                onWake();
                if (onTitle != null) {
                  onTitle();
                } else {
                  unawaited(showRoomDetails(context));
                }
              },
              builder: (context, states, _) {
                final lit = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.s4, vertical: DsSpace.s3),
                  decoration: DsBoxDecoration(
                    color: lit ? _onVideoHover : null,
                    borderRadius: BorderRadius.circular(DsRadii.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: DsSpace.s6,
                    children: [
                      DsAvatar(
                        initials: avatarInitials(name),
                        image: avatar.isEmpty ? null : cachedImage(avatar, policy: ImageCachePolicies.avatar),
                        size: tv ? DsSize.md : DsSize.sm,
                        semanticLabel: name,
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: tv ? 220 : 140),
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: (tv ? theme.typography.title : theme.typography.bodyStrong).copyWith(color: _onVideo),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            DsPressable(
              semanticLabel: followed ? t.room.unfollow : t.room.follow,
              onPressed: () {
                onWake();
                unawaited(toggleRoomFollow(context, ref));
              },
              builder: (context, states, _) {
                final lit = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
                final ink = followed ? _onVideo : OnVideoColors.foreground;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s4),
                  decoration: BoxDecoration(
                    color: followed ? _onVideoHover : colors.accent,
                    borderRadius: BorderRadius.circular(DsRadii.pill),
                    border: Border.all(
                      color: lit ? OnVideoColors.foreground.withValues(alpha: 0.6) : OnVideoColors.clear,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: DsSpace.s4,
                    children: [
                      DsIcon(followed ? DsIcons.heart : DsIcons.heartCrack, size: theme.sizes.iconXs, color: ink),
                      Text(
                        followed ? t.room.unfollow : t.room.follow,
                        style: theme.typography.caption.copyWith(color: ink, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The flying danmaku's controls on the bar: the 「弹」 switch beside the
/// nut-badged glyph that opens its settings — the pair the reference draws at
/// the bar's reading end. A viewer toggles the lines and tunes them without
/// leaving the bar, and the switch's letter reads at every tier the bar is
/// drawn at.
final class _DanmakuBarCluster extends ConsumerWidget {
  const _DanmakuBarCluster({required this.onWake, this.showSettings = true});

  /// Resets the bar's auto-hide timer after a press.
  final VoidCallback onWake;

  /// Whether the gear rides beside the switch. A narrow bar leaves it to the
  /// chat column's own settings tab.
  final bool showSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final settings = ref.watch(playbackSettingsProvider);
    final side = PlayerBarTier.controlSize(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: DsSpace.s4,
      children: [
        DsTooltip(
          message: settings.danmakuVisible ? t.room.danmakuOff : t.room.danmakuOn,
          child: DsPressable(
            semanticLabel: settings.danmakuVisible ? t.room.danmakuOff : t.room.danmakuOn,
            onPressed: () {
              onWake();
              unawaited(ref.read(playbackSettingsProvider.notifier).setDanmakuVisible(value: !settings.danmakuVisible));
            },
            builder: (context, states, _) {
              final on = settings.danmakuVisible;
              final lit = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
              // The pair the reference serves: the off glyph wears the barred
              // circle, the on glyph the check — the badge says which, so both
              // take the bar's ink and the off one only steps back a shade.
              // The switch lights the way the strip's other switches do: a
              // pointer or the keyboard's ring raises the fill behind the glyph.
              return Container(
                width: side,
                height: side,
                alignment: Alignment.center,
                decoration: DsBoxDecoration(
                  color: lit ? _onVideoHover : null,
                  borderRadius: theme.radii.controlCorners(null, side),
                ),
                child: SvgPicture.asset(
                  on ? 'assets/icons/danmaku-on.svg' : 'assets/icons/danmaku-off.svg',
                  width: side * .5,
                  height: side * .5,
                  colorFilter: ColorFilter.mode(on ? _onVideo : _onVideoMuted, BlendMode.srcIn),
                ),
              );
            },
          ),
        ),
        if (showSettings)
          PlayerBarButton(
            iconAsset: 'assets/icons/danmaku-settings.svg',
            label: t.settings.navDanmaku,
            onPressed: () {
              onWake();
              // The ask, not a route: the chat panel carries the display
              // settings as its own tab, and the page opens the door its host
              // has — the folded column, the stream, the immersive drawer.
              ref.read(roomChatSettingsAskProvider.notifier).ask();
            },
          ),
      ],
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
    // The word the strip carries for a take that is not writing — the same
    // mapping the recorder centre shows, so the two surfaces cannot call
    // one task different things. A joining take says how far the join got,
    // the way the reference's badge does (合成中 45%): a join runs minutes,
    // the strip has no progress bar, and a word alone cannot answer "is it
    // moving or stuck".
    final pendingDisplay = pending == null ? null : RecordingDisplayState.of(pending);
    final pendingWord = pendingDisplay == null || !pendingDisplay.showsOnBar
        ? null
        : pendingDisplay.word(
            context,
            joinPercent: pendingDisplay == RecordingDisplayState.joining && pending!.postProcessingProgress >= 0
                ? (pending.postProcessingProgress.clamp(0.0, 1.0) * 100).round()
                : null,
          );
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
          // A running capture is the red control itself here — the breathing
          // dot and the elapsed count on the strip, a press ends it — and the
          // plain disc returns once nothing is writing.
          if (recording && task != null)
            RecordingIndicator(
              startedAt: task.startedAt,
              figures: task.bytes <= 0 ? null : formatRecordingBytes(task.bytes),
              tv: tv,
              label: t.room.stopRecording,
              onStop: () {
                onWake();
                unawaited(toggleRoomRecording(context, ref));
              },
            )
          else if (showRecord)
            PlayerGlassPill(
              child: PlayerBarButton(
                icon: DsIcons.disc,
                label: t.room.record,
                onPressed: () {
                  onWake();
                  unawaited(toggleRoomRecording(context, ref));
                },
              ),
            ),
          if (showPip)
            PlayerGlassPill(
              child: PlayerBarButton(
                iconAsset: presentation == PresentationMode.pip ? 'assets/icons/pip-exit.svg' : 'assets/icons/pip.svg',
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
              iconAsset: presentation == PresentationMode.pip ? 'assets/icons/pip-exit.svg' : 'assets/icons/pip.svg',
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
      decoration: BoxDecoration(gradient: OnVideoColors.shade(edge: VerticalDirection.up)),
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
            iconAsset: playing ? 'assets/icons/pause.svg' : 'assets/icons/play.svg',
            label: playing ? t.room.pause : t.room.play,
            onPressed: () => unawaited(controller.togglePlayPause()),
          ),
          _PipButton(
            iconAsset: muted ? 'assets/icons/volume-muted.svg' : 'assets/icons/volume.svg',
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
  const _PipButton({required this.label, required this.onPressed, this.icon, this.iconAsset})
    : assert((icon == null) != (iconAsset == null), 'give exactly one glyph source: icon or iconAsset');

  final DsIconData? icon;

  /// A bundled svg glyph drawn instead of [icon].
  final String? iconAsset;
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
        child: Center(
          child: switch (iconAsset) {
            final String asset => SvgPicture.asset(
              asset,
              width: 14,
              height: 14,
              colorFilter: const ColorFilter.mode(_onVideoMuted, BlendMode.srcIn),
            ),
            _ => DsIcon(icon!, size: 14, color: _onVideoMuted),
          },
        ),
      ),
    );
  }
}

/// The bar itself: the live position over the buffer, then the transport,
/// the stream pickers, the danmaku switch and the presentation buttons.
///
/// A replay room (the platform labels the broadcast a recording, or the
/// loaded media reports a length) plays its own surface instead: the seek
/// line over the buttons — position, the slider, duration — the vod page's
/// bar shape. A live room keeps the buttons alone even when its engine
/// reports a growing duration, which several HLS edges do.
final class _ControlBar extends ConsumerStatefulWidget {
  const _ControlBar({
    required this.handle,
    required this.transport,
    required this.onWake,
    this.streamPickers,
    this.autofocusPlay = false,
    this.canEnterPortraitFullscreen = false,
    this.portraitFullscreen = false,
    this.onPortraitFullscreen,
    super.key,
  });

  final PlayerHandle handle;

  /// The latest transport snapshot, null until the first event.
  final PlayerTransportState? transport;

  /// Resets the bar's auto-hide timer after an interaction.
  final VoidCallback onWake;

  /// The stream's own catalogues (quality, line), placed beside the
  /// transport where a viewer looks for them.
  ///
  /// Built with the bar's own width, because that is the box the result has to
  /// fit: a narrow stage inside a wide window — an open chat panel, say —
  /// leaves little room for words beside the glyph, and words chosen from the
  /// window's size overflowed the strip. `labelled` says whether the current
  /// choice's words fit beside the glyph.
  final Widget Function({required bool labelled})? streamPickers;

  /// Focuses the play button when it first builds (the TV room's start).
  final bool autofocusPlay;

  /// Whether a portrait stream offers the entry button.
  final bool canEnterPortraitFullscreen;

  /// Whether the portrait full-screen surface is already showing.
  final bool portraitFullscreen;

  /// Enters portrait full screen.
  final VoidCallback? onPortraitFullscreen;

  @override
  ConsumerState<_ControlBar> createState() => _ControlBarState();
}

final class _ControlBarState extends ConsumerState<_ControlBar> {
  /// The replay seek the thumb is dragging, in seconds; null when the thumb
  /// is not held. While it is held the readout follows the finger and the
  /// transport's own position keeps arriving underneath — the vod page's
  /// drag idiom, whose engine-side throttle keeps the stream of positions
  /// smooth enough to drag against.
  double? _dragSeconds;

  @override
  void didUpdateWidget(_ControlBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A thumb held over a handle that is no longer the playing one drops its
    // drag: the readout belongs to the engine that is on screen now.
    if (!identical(oldWidget.handle, widget.handle) && _dragSeconds != null) {
      _dragSeconds = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final room = ref.watch(roomProvider);
    final presentation = ref.watch(roomPresentationProvider);
    final controller = ref.read(roomProvider.notifier);
    final presentationController = ref.read(roomPresentationProvider.notifier);
    final transport = widget.transport;
    final player = room.handle?.id;
    final playing = room.playback.playing;
    // The state echo of a mute switch rebuilds this bar, so the icon reads
    // fresh without its own stream.
    final muted = controller.muted;
    final immersive = presentationController.modeOwnsWindow(presentation);
    final tv = PlayerBarTier.tvOf(context);
    // The replay's surface: a room the platform labels a recording, or a
    // room that is not on air whose loaded media reports a length (a VOD
    // the label missed). A live room never flips, whatever its engine says,
    // and a room still loading its detail keeps the live bar until it knows
    // what it is.
    final detail = room.room;
    final liveRoom = detail?.broadcast.isLiveNow ?? true;
    final replay = (detail?.broadcast.isRecord ?? false) || (!liveRoom && (transport?.hasDuration ?? false));
    final duration = transport?.duration ?? Duration.zero;
    final seekable = replay && duration.inMilliseconds > 0;
    final position = _dragSeconds != null
        ? Duration(milliseconds: (_dragSeconds! * 1000).round())
        : transport?.position ?? Duration.zero;
    final timeStyle = theme.typography.numeric(theme.typography.caption.copyWith(color: _onVideo));
    return Container(
      padding: EdgeInsets.fromLTRB(
        tv ? DsSpace.s16 : DsSpace.s12,
        tv ? DsSpace.s12 : DsSpace.s8,
        tv ? DsSpace.s16 : DsSpace.s12,
        tv ? DsSpace.s12 : DsSpace.s8,
      ),
      decoration: BoxDecoration(
        gradient: OnVideoColors.shade(edge: VerticalDirection.down, strong: OnVideoColors.scrimDeep),
      ),
      // A live stream has no timeline to draw: what used to sit above these
      // buttons was a seek bar that could not seek. The buffer and latency
      // facts live in the stats overlay and in the picture's own buffering
      // state, so the live bar is the buttons alone — and a replay's one
      // extra row is the timeline it can actually move.
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
          // The replay's timeline, the vod page's own shape: the position,
          // the slider, the duration — numeric ink, a drag that shows the
          // finger's spot at once and seeks on the release.
          final seekLine = seekable
              ? Row(
                  spacing: DsSpace.s8,
                  children: [
                    SizedBox(
                      width: 54,
                      child: Text(vodDurationText(position), textAlign: TextAlign.center, style: timeStyle),
                    ),
                    Expanded(
                      child: DsSlider(
                        value: position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble(),
                        max: duration.inMilliseconds.toDouble(),
                        onChanged: (value) {
                          widget.onWake();
                          setState(() => _dragSeconds = value / 1000);
                        },
                        onChangeEnd: (value) {
                          final seconds = value / 1000;
                          setState(() => _dragSeconds = null);
                          unawaited(widget.handle.seek(Duration(milliseconds: (seconds * 1000).round())));
                        },
                        semanticLabel: t.vod.progress,
                      ),
                    ),
                    SizedBox(
                      width: 54,
                      child: Text(vodDurationText(duration), textAlign: TextAlign.center, style: timeStyle),
                    ),
                  ],
                )
              : null;
          final bar = Row(
            // A TV bar spaces its controls wider: the remote jumps
            // between them, and a distant viewer needs the separation.
            spacing: tv ? DsSpace.s8 : DsSpace.s4,
            children: [
              PlayerBarButton(
                iconAsset: playing ? 'assets/icons/pause.svg' : 'assets/icons/play.svg',
                label: playing ? t.room.pause : t.room.play,
                autofocus: widget.autofocusPlay,
                onPressed: () {
                  widget.onWake();
                  unawaited(controller.togglePlayPause());
                },
              ),
              // Reload the stream beside play; the volume lives on the wheel,
              // the mute is the one sound verb the wheel cannot spell. A narrow
              // bar leaves the retry to the error card and `R`.
              if (wide)
                PlayerBarButton(
                  icon: DsIcons.refreshCw,
                  label: t.common.retry,
                  onPressed: () {
                    widget.onWake();
                    unawaited(controller.retry());
                  },
                ),
              PlayerBarButton(
                iconAsset: muted ? 'assets/icons/volume-muted.svg' : 'assets/icons/volume.svg',
                label: muted ? t.room.unmute : t.room.mute,
                onPressed: () {
                  widget.onWake();
                  unawaited(controller.setMuted(value: !muted));
                },
              ),
              // The flying danmaku's switch rides with the transport on the
              // left; the recording state lives on the strip above and in the
              // persistent pill, not twice on this bar.
              if (!crowded && !pip) _DanmakuBarCluster(onWake: widget.onWake, showSettings: wide),
              const Spacer(),
              if (!crowded) const _BarDivider(),
              // -- What is playing: the stream's own catalogues, each its own
              // control with its current value in words (1080P / 线路1 / 适应).
              if (!pip) ?widget.streamPickers?.call(labelled: true),
              // -- The window verbs, then the way out of the picture's box.
              if (!pip && player != null && wide)
                PlayerBarButton(
                  iconAsset: presentation == PresentationMode.windowFullscreen
                      ? 'assets/icons/fullscreen-exit.svg'
                      : 'assets/icons/fullscreen-enter.svg',
                  label: presentation == PresentationMode.windowFullscreen
                      ? t.room.windowFullscreenOff
                      : t.room.windowFullscreenOn,
                  selected: presentation == PresentationMode.windowFullscreen,
                  onPressed: () {
                    widget.onWake();
                    unawaited(presentationController.toggleWindowFullscreen(player));
                  },
                ),
              if (wide &&
                  !pip &&
                  widget.canEnterPortraitFullscreen &&
                  !widget.portraitFullscreen &&
                  presentation == PresentationMode.normal)
                PlayerBarButton(
                  icon: DsIcons.rectangleVertical,
                  label: t.room.portraitFullscreen,
                  onPressed: () {
                    widget.onWake();
                    widget.onPortraitFullscreen?.call();
                  },
                ),
              // The bar's own reading order as the reference draws it:
              // transport, the stream's catalogues, the danmaku pair, then
              // the two ways out of the box.
              if (!pip && player != null)
                PlayerBarButton(
                  icon: immersive ? DsIcons.minimize : DsIcons.maximize,
                  label: immersive ? t.room.fullscreenOff : t.room.fullscreenOn,
                  selected: immersive,
                  onPressed: () {
                    widget.onWake();
                    unawaited(presentationController.toggleFullscreen(player));
                  },
                ),
            ],
          );
          // The timeline rides over the buttons, the vod bar's own order —
          // and a live room's column keeps exactly the shape it had.
          return seekLine == null
              ? bar
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: DsSpace.s4, children: [seekLine, bar]);
        },
      ),
    );
  }
}

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
      color: OnVideoColors.track,
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

/// Whether an upward swipe of [upward] pixels that ended at [velocity] (upwards
/// negative) restores the page's layout from the portrait full screen (the
/// reference's `swipeRestoresPanel`): 64 px of travel, or a flick of 850 px/s
/// once 24 of them are behind it.
bool _swipeRestoresPanel({required double upward, required double velocity}) =>
    upward >= 64 || (velocity <= -850 && upward >= 24);

/// The portrait full screen's bottom bar, or the strip that wakes it, taking
/// the upward swipe back to the page's panel as well (the reference's
/// `_SwipeUpRegion`).
///
/// Both stand over the picture's gesture layer and keep the pointer from it,
/// yet they are the floor of the band the swipe starts from. The buttons under
/// it keep their taps: a drag only wins once the finger moves. Without
/// [onRestore] it listens for nothing, and the tree keeps its shape either way.
final class _RestoreSwipe extends StatefulWidget {
  const _RestoreSwipe({required this.onRestore, required this.child});

  /// Restores the page's layout; null where the swipe means nothing.
  final VoidCallback? onRestore;

  /// The bar or the strip.
  final Widget child;

  @override
  State<_RestoreSwipe> createState() => _RestoreSwipeState();
}

final class _RestoreSwipeState extends State<_RestoreSwipe> {
  /// The swipe's travel up the bar, never below zero.
  double _upward = 0;

  @override
  Widget build(BuildContext context) {
    final restore = widget.onRestore;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: restore == null ? null : (_) => _upward = 0,
      onVerticalDragUpdate: restore == null
          ? null
          : (details) => _upward = (_upward - details.delta.dy).clamp(0.0, double.infinity),
      onVerticalDragEnd: restore == null
          ? null
          : (details) {
              final upward = _upward;
              _upward = 0;
              if (_swipeRestoresPanel(upward: upward, velocity: details.primaryVelocity ?? 0)) restore();
            },
      onVerticalDragCancel: restore == null ? null : () => _upward = 0,
      child: widget.child,
    );
  }
}
