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
    show PlatformScreenBrightnessService, ScreenBrightnessScope, ScreenBrightnessService;
import 'package:live_sites/live_sites.dart'
    show LivePlayLine, LiveRoom, LiveRoomRefIdentity, LiveStreamCodec, LiveStreamFormat;
import 'package:media_core/media_core.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/archive/archive_navigation.dart' show openArchives;
import 'package:pure_live/modules/live/favorites/data/follow_repository.dart' show followsProvider;
import 'package:pure_live/modules/live/recorder/recorder.dart';
import 'package:pure_live/modules/live/room/chat/room_message_actions.dart' show showRoomMessageActions;
import 'package:pure_live/modules/live/room/controller/room_controller.dart';
import 'package:pure_live/modules/live/room/page/audio_only_cover.dart' show AudioOnlyCover;
import 'package:pure_live/modules/live/room/page/room_details.dart' show shareRoom;
import 'package:pure_live/modules/live/room/page/room_follow.dart' show toggleRoomFollow;
import 'package:pure_live/modules/live/room/page/room_screenshot.dart' show takeRoomScreenshot;
import 'package:pure_live/modules/live/room/page/room_status.dart'
    show RoomPictureAction, RoomPictureDim, RoomPictureKind, pictureStateOf, roomSlowProvider;
import 'package:pure_live/modules/live/room/panels/room_panel.dart' show showRoomDetails, showRoomSleepTimer;
import 'package:pure_live/modules/live/room/player/room_switcher.dart' show showRoomSwitcher;
import 'package:pure_live/shared/shared.dart';
part 'player_surface_stage.dart';
part 'player_surface_top_bar.dart';
part 'player_surface_pickers.dart';
part 'player_surface_danmaku.dart';
part 'player_surface_gestures.dart';
part 'player_surface_pip.dart';
part 'player_surface_control_bar.dart';

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
        // The same word the bar above the page carries: leaving is leaving,
        // whatever surface asks for it.
        t.common.back,
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
        // Not the stream's retry: this opens the room again from its
        // detail — a different verb that used to borrow retry's word.
        t.room.reloadRoom,
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

/// The page's hand to the surface's adjustment readout: a volume a keyboard
/// step sets flashes through the same HUD the picture's drag and wheel use,
/// so every channel that moves the audio says so the same way. The surface
/// registers its readout on mount and clears it on disposal; a call with
/// none mounted is a no-op.
final class PlayerSurfaceHud {
  void Function(double value, {bool brightness})? _show;

  /// Flashes the readout: [value] 0–1, [brightness] switches the glyph to
  /// the screen brightness the left half adjusts.
  void show(double value, {bool brightness = false}) => _show?.call(value, brightness: brightness);

  // The registration is a property write by shape, but the call site reads
  // as a verb next to [_detach]; the setter lint wants a getter that has no
  // business existing here.
  // ignore: use_setters_to_change_properties
  void _attach(void Function(double value, {bool brightness}) show) => _show = show;

  void _detach(void Function(double value, {bool brightness}) show) {
    if (identical(_show, show)) _show = null;
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
    this.onMore,
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
    this.controlBarEndInset = 0,
    this.topBarEndInset = DsSpace.s12,
    this.onChatDrawer,
    this.chatDrawerOpen = false,
    this.hud,
    this.onFullscreen,
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

  /// How much of the picture's right edge a page layer covers: the theatre
  /// column and the immersive drawer ride over the frame's end, so the control
  /// bar stops short of them instead of drawing its scrim and buttons under a
  /// panel that hides them.
  final double controlBarEndInset;

  /// A page layer over the picture and under the surface's own controls: a
  /// layout that floats its chat over the frame hands it in here, so the
  /// stream's pickers, the bars and the statistics still draw above it.
  final Widget? overlay;

  /// The room's own actions (details, switch room, share, capture…), the same
  /// Opens the room's more container — the redesign's single more-entry,
  /// carried by the strips' ⋯ wherever they draw. The container itself lives
  /// at the page level, so it can dock over the chat column.
  final VoidCallback? onMore;

  /// The room left where the top strip's trailing verbs end: the floating
  /// chat drawer (方案B) reserves the picture's right edge, and the strip,
  /// the statistics panel and the pickers keep out from under it.
  final double topBarEndInset;

  /// Toggles the page's theatre chat drawer (the redesign's gbtn 聊天): the
  /// overlay drawer itself lives at the page level, over the whole stage.
  /// Null where the shape has none — the strip then carries no chat verb.
  final VoidCallback? onChatDrawer;

  /// Whether that drawer is open, so the verb can name its own next word.
  final bool chatDrawerOpen;

  /// The page's readout hand: the keyboard's volume steps flash the same
  /// figure the picture's own gestures do. Null leaves the keyboard silent
  /// (a surface hosted without a page around it).
  final PlayerSurfaceHud? hud;

  /// The page's own fullscreen verb — the shape-aware one, which a portrait
  /// stream's fullscreen answers with the portrait surface. The bar's
  /// fullscreen button and the picture's double tap call it when it is
  /// here; without it both fall back to the presentation's own toggle.
  final VoidCallback? onFullscreen;

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

  /// The video-area danmaku settings panel is open: the bars stay while it
  /// is, the same hold the pickers take.
  bool _danmakuSettingsOpen = false;

  /// The danmaku settings gear's box, for the panel host that hangs the
  /// settings above it.
  final GlobalKey _danmakuSettingsAnchor = GlobalKey(debugLabel: 'danmaku-settings-anchor');

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
    widget.hud?._attach(_showAdjust);
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
        final desktop =
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux;
        _brightnessWritable = !desktop && capabilities.canOfferBrightnessControl;
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
    // The lock now rides every surface the bars ride (the redesign's
    // full-surface guard), and its unlock button mounts wherever the lock
    // does — so a mode change never orphans a locked picture. Leaving the
    // room disposes the surface with the lock in it.
  }

  @override
  void dispose() {
    widget.hud?._detach(_showAdjust);
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

  /// Opens or closes the video-area danmaku settings panel; the bars stay up
  /// while it is out.
  void _toggleDanmakuSettings() {
    if (!_danmakuSettingsOpen) _hidePicker();
    final opening = !_danmakuSettingsOpen;
    setState(() {
      _danmakuSettingsOpen = opening;
      if (opening) {
        _controlsVisible = true;
        _hideTimer?.cancel();
      }
    });
    if (!opening) _scheduleHide();
  }

  void _closeDanmakuSettings() {
    if (!_danmakuSettingsOpen) return;
    setState(() => _danmakuSettingsOpen = false);
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_panelOpen || _danmakuSettingsOpen) return;
    if (!widget.roomState.playback.playing) return;
    // A TV room keeps its bars: with no pointer there is no way to wake a
    // hidden bar, and the focused control would go with it.
    if (widget.keepControls || _controlsFocus.hasFocus) return;
    // The viewer's own delay (the 画面与浮窗 setting); zero is 常显, no
    // timer at all.
    final seconds = ref.read(playbackSettingsProvider).controlsAutoHideSeconds;
    if (seconds <= 0) return;
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

  @override
  Widget build(BuildContext context) {
    ref.listen(roomStreamPickerAskProvider, (_, _) {
      final picked = ref.read(roomStreamPickerAskProvider.notifier).last;
      if (picked == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _togglePicker(switch (picked) {
          RoomStreamPicker.quality => _Picker.quality,
          RoomStreamPicker.line => _Picker.line,
          RoomStreamPicker.fit => _Picker.fit,
        });
      });
    });
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
    // The shapes that fold the room's identity into the picture itself (the
    // redesign's gcap capsule): the immersive modes, the portrait fullscreen
    // and the phone held sideways, whose room card has no column to sit in.
    final capsuleIdentity = !widget.tv && (widget.immersive || widget.portraitFullscreen || widget.onTitle != null);
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
      // An open picker panel or the danmaku settings is a layer the remote's
      // back peels first: the route only pops when no panel is open. The
      // dialogs above the room pop on their own and never reach this.
      canPop: !_panelOpen && !_danmakuSettingsOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_danmakuSettingsOpen) {
          _closeDanmakuSettings();
        } else {
          _hidePicker();
        }
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
                          // tap, its button and F are one toggle — the page's
                          // shape-aware one when it hands one over — and play and
                          // pause keep the bar's button. A catalogue left open would
                          // only float over the picture in its new box, so the double
                          // tap puts it away the way a single tap would.
                          _hidePicker();
                          if (widget.onFullscreen case final onFullscreen?) {
                            onFullscreen();
                            return;
                          }
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
                    Positioned.fill(
                      child: Center(
                        // The glyph names the figure, so a drag on the left half
                        // never reads as the volume it is not.
                        child: PlayerVolumeHud(value: volume, icon: _hudIsBrightness ? DsIcons.sun : null),
                      ),
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
                  // The stream's own figures (the more panel's 播放统计): the
                  // same overlay the other players hang, at the picture's
                  // top-right, under the bars so a bar over it still reads.
                  // A switch left on while no engine holds the picture waits:
                  // the handle arrives, the figures return.
                  if (ref.watch(playerStatsVisibleProvider) && handle != null)
                    PositionedDirectional(
                      top: DsSpace.s8,
                      end: DsSpace.s12,
                      child: PlayerStatsOverlay(handle: handle),
                    ),
                  // The inline room's caption: the title and its figures at the
                  // picture's top-left, the redesign's own home for them. The
                  // immersive shapes hang their capsule instead, and the mini
                  // window keeps its title strip — both cover the same ground.
                  if (showBar && !mini && !capsuleIdentity && !widget.tv)
                    const PositionedDirectional(top: 0, start: 0, child: _RoomTitleCaption()),
                  if (showBar && !mini && !capsuleIdentity && !widget.tv)
                    PositionedDirectional(
                      top: DsSpace.s12,
                      start: 0,
                      end: 0,
                      // The inline room's tool cluster floats at the picture's
                      // top-right (the redesign's tcluster): 截屏/录制/画中画/⋯ in
                      // one glass pill, text chips on a narrow picture. The page's
                      // own bar above carries the identity, the follow and the
                      // system verbs, so the picture carries none of them.
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: _TopToolCluster(room: room, onWake: _wake, onMore: widget.onMore),
                      ),
                    ),
                  // The capsule shapes (the immersive modes, the portrait
                  // fullscreen, the phone held sideways): the identity folds
                  // into a glass capsule at the picture's top-left (the
                  // redesign's gcap), and the exit verb plus the tool cluster
                  // stack at the top-right — the reference hangs the cluster
                  // beneath its text buttons when both are up.
                  if (showBar && !mini && capsuleIdentity) ...[
                    PositionedDirectional(
                      top: DsSpace.s12,
                      start: DsSpace.s12,
                      child: _ImmersiveCapsule(room: room, onWake: _wake, onTitle: widget.onTitle),
                    ),
                    PositionedDirectional(
                      top: DsSpace.s12,
                      end: DsSpace.s12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        spacing: DsSpace.s4,
                        children: [
                          // The theatre's chat verb (the gbtns row's first
                          // word): the overlay drawer it toggles lives at the
                          // page level, so it only shows where the page has
                          // one to open.
                          if (widget.onChatDrawer != null)
                            _ModeExitChip(
                              label: widget.chatDrawerOpen ? context.t.room.collapseChat : context.t.room.expandChat,
                              onPressed: widget.onChatDrawer!,
                              onWake: _wake,
                            ),
                          _ModeExitChip(
                            label: switch (presentation) {
                              PresentationMode.fullscreen => context.t.room.fullscreenOff,
                              PresentationMode.windowFullscreen => context.t.room.windowFullscreenOff,
                              // The normal mode's capsule shape is the phone
                              // held sideways: no presentation mode holds it,
                              // so the verb is the room's own close.
                              _ =>
                                widget.portraitFullscreen
                                    ? context.t.room.portraitFullscreenExit
                                    : context.t.common.close,
                            },
                            onPressed: widget.onLeave,
                            onWake: _wake,
                          ),
                          _TopToolCluster(room: room, onWake: _wake, onMore: widget.onMore),
                        ],
                      ),
                    ),
                  ],
                  // The TV keeps the full strip: the ten-foot room owns the
                  // whole screen, so the identity, the follow and the verbs all
                  // belong on it, on one reachable row.
                  if (showBar && !mini && widget.tv)
                    PositionedDirectional(
                      top: 0,
                      start: 0,
                      end: 0,
                      child: _PlayerTopBar(
                        room: room,
                        onLeave: widget.onLeave,
                        onWake: _wake,
                        onMore: widget.onMore,
                        endInset: widget.topBarEndInset,
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
                          label: context.t.room.stopRecording,
                          tv: widget.tv,
                          // Locked, it is a mark and not a switch: the figures
                          // stay, the accidental tap that would end the take does
                          // not. The verb is back in the bar the moment unlocks.
                          onStop: _locked ? null : () => unawaited(toggleRoomRecording(context, ref)),
                        ),
                      ),
                    ),
                  // The compact window's own chrome (the redesign's pip shape):
                  // the title strip at the top-left — a grab on it moves the
                  // window — and the full icon bar at the bottom. It never
                  // hides: without it the window would have no way back.
                  if (mini) ...[
                    PositionedDirectional(
                      top: DsSpace.s8,
                      start: DsSpace.s8,
                      child: _PipTitle(room: room, onRestore: widget.onLeave),
                    ),
                    PositionedDirectional(
                      bottom: 0,
                      start: 0,
                      end: 0,
                      child: _PipBar(
                        room: room,
                        locked: _locked,
                        onToggleLock: _toggleLock,
                        onRestore: widget.onLeave,
                        onClose: widget.onCloseRoom ?? widget.onLeave,
                      ),
                    ),
                  ],
                  if (showBar && !mini)
                    Positioned(
                      bottom: widget.bottomInset,
                      left: 0,
                      right: widget.controlBarEndInset,
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
                            onDanmakuSettings: _toggleDanmakuSettings,
                            danmakuSettingsAnchor: _danmakuSettingsAnchor,
                            streamPickers: ({required labelled, required fitOnly}) => _StreamPickerRow(
                              room: room,
                              open: _openPicker,
                              anchors: _pickerAnchors,
                              labelled: labelled,
                              fitOnly: fitOnly,
                              onToggle: _togglePicker,
                            ),
                            autofocusPlay: widget.autofocusFirstControl,
                            canEnterPortraitFullscreen: widget.canEnterPortraitFullscreen,
                            portraitFullscreen: widget.portraitFullscreen,
                            onPortraitFullscreen: widget.onPortraitFullscreen,
                            onFullscreen: widget.onFullscreen,
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
                      right: widget.controlBarEndInset,
                      child: _RestoreSwipe(
                        onRestore: widget.onPortraitRestore,
                        child: _IdleWakeStrip(onWake: _wake),
                      ),
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
                              anchorKey: _pickerAnchor(picker),
                              barKey: _barKey,
                              width: _panelWidth(picker),
                              child: _pickerPanel(context.t, picker),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // The danmaku settings panel, hung above the bar's gear: the
                  // quick sliders (area, size, opacity, speed) and the way to
                  // the advanced settings, the same panel layer the pickers
                  // take — an outside tap or Escape closes it, the picture
                  // behind it unchanged.
                  if (_danmakuSettingsOpen)
                    Positioned.fill(
                      child: Focus(
                        focusNode: _panelFocus,
                        autofocus: true,
                        onKeyEvent: (node, event) {
                          if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.escape) {
                            return KeyEventResult.ignored;
                          }
                          _closeDanmakuSettings();
                          return KeyEventResult.handled;
                        },
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _closeDanmakuSettings),
                            ),
                            PlayerPanelHost(
                              anchorKey: _danmakuSettingsAnchor,
                              barKey: _barKey,
                              width: 280,
                              child: PlayerOverlayPanel(
                                title: context.t.settings.navDanmaku,
                                width: 280,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(DsSpace.s12, 0, DsSpace.s12, DsSpace.s6),
                                    child: _DanmakuSettingsControls(
                                      onWake: _wake,
                                      onAdvanced: () {
                                        _closeDanmakuSettings();
                                        unawaited(
                                          context.push(
                                            SettingsSectionRoute(section: SettingsSection.danmaku.name).location,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // The lock, on the picture's right edge (the reference's
                  // LockButton): it comes with the bars, and once it is on it is
                  // the only thing drawn — whatever the room does next. A locked
                  // picture with no unlock on it is a door bricked from inside.
                  if (!mini && (_locked || showBar))
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
}
