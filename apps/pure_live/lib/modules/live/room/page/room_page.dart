import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:math' as math;
import 'dart:ui' show clampDouble;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show AppBar, InputBorder, InputDecoration, Scaffold, TextField, TextInputAction;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_device/live_device.dart'
    show PlatformScreenAwakeService, PlatformScreenOrientationService, ScreenAwakeService, ScreenOrientationService;
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:live_sites/live_sites.dart';
import 'package:media_core/media_core.dart' show PlayerHandleLifecycle, PlayerId, PresentationMode;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/favorites/favorites.dart';
import 'package:pure_live/modules/live/history/history.dart';
import 'package:pure_live/modules/live/room/chat/room_chat.dart' show RoomChatPanel, RoomEmotePanel;
import 'package:pure_live/modules/live/room/chat/room_chat_overlay.dart' show RoomChatOverlay;
import 'package:pure_live/modules/live/room/controller/room_controller.dart';
import 'package:pure_live/modules/live/room/identity/room_identity_bar.dart';
import 'package:pure_live/modules/live/room/layout/room_layout.dart';
import 'package:pure_live/modules/live/room/more/room_more_menu.dart' show showRoomMore;
import 'package:pure_live/modules/live/room/page/chat_splitter.dart' show ChatSplitter;
import 'package:pure_live/modules/live/room/page/player_surface.dart'
    show PlayerSurface, PlayerSurfaceHud, kPlayerStageColor;
import 'package:pure_live/modules/live/room/page/room_bottom_panel.dart';
import 'package:pure_live/modules/live/room/page/room_details.dart' show shareRoom;
import 'package:pure_live/modules/live/room/page/room_follow.dart' show toggleRoomFollow;
import 'package:pure_live/modules/live/room/page/room_frame.dart' show kRoomFrameRatioMax, kRoomFrameRatioMin;
import 'package:pure_live/modules/live/room/page/room_glass_card.dart';
import 'package:pure_live/modules/live/room/page/room_refresh_rate.dart' show roomRefreshRateProvider;
import 'package:pure_live/modules/live/room/page/room_screenshot.dart' show takeRoomScreenshot;
import 'package:pure_live/modules/live/room/page/room_shortcuts.dart'
    show RoomShortcutAction, roomShortcutBindings, showRoomShortcuts;
import 'package:pure_live/modules/live/room/page/room_status.dart' show roomSlowProvider, slowAfter;
import 'package:pure_live/modules/live/room/panels/room_panel.dart'
    show
        RoomPanelController,
        RoomPanelKind,
        RoomPanelScope,
        isRoomPanelRoute,
        roomPanelRouteName,
        roomPanelSheet,
        showRoomDetails;
import 'package:pure_live/modules/live/room/player/floating_room_player.dart' show FloatingRoomPlayer;
import 'package:pure_live/modules/live/room/player/room_playlist.dart'
    show RoomPlaylistController, roomPlaylistProvider;
import 'package:pure_live/modules/live/room/player/room_switcher.dart' show roomSwipeList;
import 'package:pure_live/modules/live/room/player/sleep_timer.dart';
import 'package:pure_live/shared/navigation/room_seed.dart' show takeRoomSeed;
import 'package:pure_live/shared/shared.dart';
part 'room_page_bar.dart';
part 'room_page_compact.dart';
part 'room_page_hero.dart';
part 'room_page_lifecycle.dart';
part 'room_page_layouts.dart';

/// The live room: media_core's picture with the app's control layer over
/// it, the room's facts under it, and the chat beside it on a wide window.
///
/// The layout follows the reference's inline shapes: from 840 px the
/// picture and its facts take the left and the chat a column of the
/// viewer's own width on the right; narrower windows stack the chat under
/// the picture. A phone held sideways — a window under 480 px tall — keeps
/// the picture at the full height instead, with the chat's list in a narrow
/// column beside it, whatever its width. Fullscreen,
/// window fullscreen and PiP hand the whole page to the picture — those
/// modes are media_core's presentation drivers, so the page only follows the
/// state they publish.
final class RoomPage extends ConsumerStatefulWidget {
  /// The room to open, by platform and room id.
  const RoomPage({required this.platform, required this.roomId, this.room, super.key});

  /// The room's platform id.
  final String platform;

  /// The room's platform room id.
  final String roomId;

  /// The card the room was opened from, when the opener had it in hand: the
  /// page draws the title and cover from it while the detail request runs.
  final LiveRoom? room;

  @override
  ConsumerState<RoomPage> createState() => _RoomPageState();
}

final class _RoomPageState extends ConsumerState<RoomPage> with WidgetsBindingObserver, RouteAware {
  Timer? _slowTimer;

  /// The presentation controller and player in hand, kept so the page's
  /// disposal can leave a fullscreen or a small window even when the viewer
  /// left by a route pop rather than the room's own controls.
  RoomPresentationController? _presentationController;
  PlayerId? _player;

  // Riverpod refuses `ref` once the element is defunct, and State.dispose()
  // runs exactly there: the leaving page says its goodbyes through
  // notifiers captured while it was alive.
  late final RoomController _roomNotifier;
  late final RoomImmersiveController _immersiveNotifier;
  late final RoomPlaylistController _playlistNotifier;
  late final SleepTimerController _sleepTimerNotifier;

  /// The room's side panels (details, sleep timer): one at a time, hosted
  /// by the page through [RoomPanelScope].
  final RoomPanelController _panels = RoomPanelController();
  RoomPanelKind? _openPanelKind;

  /// The window-level navigator, captured while the page can still look
  /// its ancestors up: the panel routes live there, and the sweep on open
  /// and close has to reach them after dispose-time lookups are gone.
  NavigatorState? _rootNav;

  /// The screen wakelock while the picture plays: a live room is watched,
  /// not read, and the display should not sleep under it.
  final ScreenAwakeService _screenAwake = const PlatformScreenAwakeService();
  bool _screenHeld = false;

  /// The phone's orientation while the room is system-fullscreen
  /// (POR-04's policy target); inert on desktop.
  final ScreenOrientationService _screenOrientation = const PlatformScreenOrientationService();

  /// Whether the Android small window is armed for the next leave, and the
  /// size it was armed for (arming is a channel call per change, not per
  /// frame).
  bool _floatingArmed = false;
  Size? _floatingArmedSize;

  /// Whether this visit already handled the auto-fullscreen preference: the
  /// room asks once, when its stream first plays, and a later exit stays.
  bool _autoFullscreenDone = false;

  /// How much of the narrow room's window its chat sheet covers, once settled.
  /// The picture keeps its full bleed and the bars stand above this, so a drag
  /// moves the sheet without moving the buttons under it.
  double _panelCover = 0;

  /// Whether the page is showing its portrait full-screen surface.
  bool _portraitFullscreen = false;

  /// Whether the immersive room's chat drawer is up: the overlay pills are
  /// the glance, and the drawer — the panel with its tabs and composer — is
  /// where a viewer goes when the glance is not enough.
  bool _immersiveChatOpen = false;

  /// Whether the immersive room is showing its clean screen: the overlay
  /// chat and the composer bar give way to the picture alone, and a pill at
  /// the picture's side takes them back.
  bool _cleanScreen = false;

  /// Whether a room switch from the portrait full screen is in flight; the
  /// page keeps its surface while the next room opens on the same controller.
  bool _switchingPortraitRoom = false;

  /// The room the viewer swiped to, kept in the portrait surface even when
  /// its stream is landscape (the reference's ambient surface).
  String? _portraitSwipeTarget;

  /// The room this page shows; the source list is cleared on the way out.
  String _currentRoomKey = '';

  /// The auto-fullscreen preference this open started with; flipping it
  /// mid-room applies to the next room, as in the reference.
  bool _autoFullscreenArmed = false;

  /// The Android background-playback gate and the room it paused.
  BackgroundPlaybackGate? _backgroundGate;
  String? _backgroundPausedKey;

  /// Whether this route pop hands the live handle to the app-level floating
  /// player instead of stopping the room.
  bool _leaveToFloating = false;

  /// Whether the room is being stopped by a small window's ✕. That close
  /// leaves the route like any other pop, so without this the page would read
  /// the still-playing room as a leave and hand it to the floating player.
  bool _closingRoom = false;

  /// Whether a leave's pop is already in flight. The navigator stays locked
  /// for the whole exit transition, so a second leave inside it — a double
  /// press on the back verb, a held Escape — would pop into the locked
  /// navigator and assert. One leave wins; the page is going away either way.
  bool _leaving = false;

  /// Whether going to the background applied audio-only, and the room's own
  /// mode to restore when it returns (V5-21).
  bool _backgroundAudioOnlyApplied = false;
  bool _audioOnlyBeforeBackground = false;
  bool _backgroundDanmakuPaused = false;

  /// Whether the room was paused by closing the picture-in-picture window,
  /// so returning to the app can resume it (V5-23).
  bool _pausedByPipClose = false;
  bool _appInForeground = true;
  bool _pipWasActive = false;
  StreamSubscription<bool>? _pipSubscription;

  /// The route this page asked the observer about, so a theme change does not
  /// subscribe it twice.
  ModalRoute<void>? _observedRoute;

  /// The window's observer, kept for `dispose` where the provider scope may
  /// already be gone.
  RouteObserver<ModalRoute<void>>? _routeObserver;

  /// The room's width at which the chat moves beside the picture (the
  /// reference's `wide` layout). The measure lives in the layout machine.
  static const double _wideBreakpoint = kRoomWideBreakpoint;

  /// The stage's floor while the chat column is dragged wide: at the wide
  /// layout's own edge the column tops out under its 520 px cap rather than
  /// squeezing the picture into a strip.
  static const double _wideStageFloor = 420;

  /// The strips the picture's own top bar and control bar take at its edges.
  /// The TV's glass column starts and ends clear of them, so neither the
  /// bars nor what rises from them (a picker's catalogue) ever lands on the
  /// chat's words.
  ///
  /// Both follow the bars' own geometry rather than a look: the top is the
  /// presentation pill the strip keeps in-page (8 px of padding + a 32 px
  /// control + the pill's own air), since C7 left the identity in the page
  /// header; the bottom is the control bar's padding (8 + 8) plus one row of
  /// 32 px buttons — the live progress line C3 removed used to add 10 of them.

  /// The player's own identity across the page's layout branches: normal,
  /// immersive (fullscreen/window fullscreen/PiP) and the portrait surface
  /// all embed the same [PlayerSurface] state, so a mode switch reparents
  /// the subtree instead of tearing the video texture down and back.
  final GlobalKey _playerKey = GlobalKey();

  /// The keyboard's hand to the surface's adjustment readout: the arrows'
  /// volume steps flash the same HUD the picture's drag and wheel use.
  final PlayerSurfaceHud _surfaceHud = PlayerSurfaceHud();

  /// The phone's view of this room, registered for as long as the page is.
  late final RemotePlaybackTarget _remoteTarget;

  @override
  void initState() {
    super.initState();
    _roomNotifier = ref.read(roomProvider.notifier);
    _immersiveNotifier = ref.read(roomImmersiveProvider.notifier);
    _playlistNotifier = ref.read(roomPlaylistProvider.notifier);
    _sleepTimerNotifier = ref.read(sleepTimerProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    _panels.addListener(_onRoomPanelChanged);
    _currentRoomKey = '${widget.platform.trim().toLowerCase()}:${widget.roomId.trim()}';
    // A new room page supersedes any older floating handoff; open() below
    // tears the old handle down.
    FloatingRoomPlayer.hide();
    // The sleep timer must stop this room, not some global notion of one.
    ref.read(sleepTimerProvider.notifier).onFire_ = _onSleepFire;
    _autoFullscreenArmed = ref.read(playbackSettingsProvider).fullscreenDefault;
    // ASMR mode auto-arms the sleep timer with the chosen duration on
    // Android; the room itself starts audio-only in RoomController.open.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final settings = ref.read(playbackSettingsProvider);
      if (settings.asmrSleepMode) {
        ref.read(sleepTimerProvider.notifier).start(settings.asmrSleepMinutes);
      }
    }
    _backgroundGate = BackgroundPlaybackGate(
      backgroundEnabled: () => ref.read(playbackSettingsProvider).backgroundPlay,
      shouldPause: () {
        // A sleep session asked the room to keep playing until its timer.
        if (ref.read(sleepTimerProvider).endsAt != null) return false;
        final room = ref.read(roomProvider);
        final presentation = ref.read(roomPresentationProvider);
        return room.playback.playing && presentation != PresentationMode.pip;
      },
      pause: () async {
        _backgroundPausedKey = ref.read(roomProvider).room?.ref.identityKey;
        await ref.read(roomProvider.notifier).pause();
      },
      canResume: () {
        final key = _backgroundPausedKey;
        if (key == null) return false;
        final room = ref.read(roomProvider);
        return room.handle != null && room.room?.ref.identityKey == key && !room.playback.playing;
      },
      resume: () async {
        _backgroundPausedKey = null;
        await ref.read(roomProvider.notifier).togglePlayPause();
      },
    );
    // The room never opens from inside its own build; the page asks. The
    // card the opener passed (or the seed a room window left on the shared
    // shelf) is the page's first frame; the detail request replaces it.
    final seed = widget.room ?? takeRoomSeed(widget.platform, widget.roomId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(roomProvider.notifier).open(platform: widget.platform, roomId: widget.roomId, known: seed));
    });
    // A PiP window closed while the app is away means "stop", when the
    // setting says so; the system ends the window without a lifecycle event.
    _pipSubscription = ref.read(pipDriverProvider).onPipChanged.listen(_onPipChanged);
    // The Android small window takes the screen when the app is left; the
    // room's floating player is what fills it.
    FloatingOverlay.listen();
    FloatingOverlay.active.addListener(_onFloatingWindowChanged);
    FloatingOverlay.permitted.addListener(_onFloatingWindowPermitted);
    // The phone's view of this room: the same verbs the bar carries. The
    // closures read the controller at call time, so a room switch inside
    // the page cannot answer with the room that was there before.
    _remoteTarget = RemotePlaybackTarget(
      available: () => mounted && (ModalRoute.isCurrentOf(context) ?? true),
      scope: () => ref.read(roomProvider).room?.ref.identityKey ?? '${widget.platform}:${widget.roomId}',
      snapshot: () {
        final room = ref.read(roomProvider);
        final detail = room.room;
        return {
          'nick': detail?.anchor?.name ?? '',
          'title': detail?.content.title ?? '',
          'platform': room.room?.ref.platform ?? widget.platform,
          'paused': !room.playback.playing,
          'volume': ref.read(roomProvider.notifier).volume,
          'commands': [
            'play',
            'pause',
            'refresh',
            'volume',
            'mute',
            'danmaku',
            'fullscreen',
            'previous',
            'next',
            'up',
            'down',
          ],
        };
      },
      execute: (command, value) async {
        if (!mounted) return false;
        final room = ref.read(roomProvider);
        final controller = ref.read(roomProvider.notifier);
        switch (command) {
          case 'play':
            if (!room.playback.playing) await controller.togglePlayPause();
            return true;
          case 'pause':
            if (room.playback.playing) await controller.togglePlayPause();
            return true;
          case 'refresh':
            await controller.refreshRoom();
            return true;
          case 'volume':
            if (value == null) return false;
            await controller.setVolume(value);
            return true;
          case 'mute':
            await controller.setMuted(value: !controller.muted);
            return true;
          case 'danmaku':
            await ref
                .read(playbackSettingsProvider.notifier)
                .setDanmakuVisible(value: !ref.read(playbackSettingsProvider).danmakuVisible);
            return true;
          case 'fullscreen':
            _toggleFullscreenVerb();
            return true;
          case 'previous':
          case 'up':
            _switchRoomByStep(-1);
            return true;
          case 'next':
          case 'down':
            _switchRoomByStep(1);
            return true;
        }
        return false;
      },
    );
    playbackRemote.register(_remoteTarget);
  }

  /// Remembers where the chat sheet settled: the bars over the picture stand
  /// that much higher, so a control row is never under a panel the viewer cannot
  /// see through.
  ///
  /// The first report arrives while the panel is still building, so the state
  /// change waits for the frame that is finishing.
  void _setPanelCover(double height) {
    if (height == _panelCover) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || height == _panelCover) return;
      setState(() => _panelCover = height);
    });
  }

  /// The sheet's pill: the room's own full screen, routed by the picture's
  /// shape — the fullscreen verb follows the frame. A portrait stream takes
  /// the portrait full-screen surface (its chat door and its swipe list
  /// live there); a landscape one takes the system's own fullscreen, the
  /// shape the verb has always meant.
  void _enterFullscreen() {
    final state = ref.read(roomProvider);
    final handle = state.handle;
    if (handle == null) return;
    if (_pictureRatio(state) < 1) {
      _setPortraitFullscreen(true);
      return;
    }
    unawaited(ref.read(roomPresentationProvider.notifier).toggleFullscreen(handle.id));
  }

  /// The system's own fullscreen, unconditionally: the immersive layouts'
  /// fullscreen verb. They are already the page's full-bleed layout — there
  /// is no surface under them — so the verb means the presentation's own
  /// mode, whatever the stream's shape (a portrait stream locks the phone's
  /// portrait side and hides the status bar; a landscape one takes the
  /// screen's long side).
  void _enterSystemFullscreen() {
    final handle = ref.read(roomProvider).handle;
    if (handle == null) return;
    unawaited(ref.read(roomPresentationProvider.notifier).toggleFullscreen(handle.id));
  }

  /// The fullscreen verb as a toggle, for the key, the bar's button and the
  /// picture's double tap: out of the portrait surface first, out of the
  /// system's fullscreen next, and into the one the picture's shape asks
  /// for last.
  void _toggleFullscreenVerb() {
    if (_portraitFullscreen) {
      _setPortraitFullscreen(false);
      return;
    }
    final state = ref.read(roomProvider);
    final handle = state.handle;
    if (handle == null) return;
    final mode = ref.read(roomPresentationProvider);
    if (mode != PresentationMode.normal) {
      unawaited(ref.read(roomPresentationProvider.notifier).toggleFullscreen(handle.id));
      return;
    }
    // 手机的沉浸式布局已是满铺（键盘的 F 也能到）：全屏动词在那里就是系统
    // 自己的全屏，竖屏全屏表面不再是手机的一条路。平板走桌面骨架，它的
    // 全屏动词是窗口全屏。
    final formFactor = ref.read(platformRuntimeProvider).environment.runtime.formFactor;
    final size = MediaQuery.sizeOf(context);
    final mobile = formFactor == FormFactor.phone || formFactor == FormFactor.tablet;
    final phone = mobile && !isTabletSized(size);
    final phoneImmersive =
        phone &&
        size.width < kRoomCompactBreakpoint &&
        size.height >= kRoomLandscapeMaxHeight;
    if (phoneImmersive) {
      _enterSystemFullscreen();
      return;
    }
    _enterFullscreen();
  }

  /// Shows or leaves the portrait full-screen surface and publishes it: the
  /// route's chrome hides the window strip while this page owns the window,
  /// exactly as it does for fullscreen, and the page's own layout is the only
  /// thing that can know.
  void _setPortraitFullscreen(bool value) {
    if (_portraitFullscreen == value) return;
    if (mounted) {
      setState(() {
        _portraitFullscreen = value;
        // Leaving the surface closes its panel with it; a fresh entry starts
        // with the picture alone.
        if (!value) _immersiveChatOpen = false;
      });
    } else {
      _portraitFullscreen = value;
    }
    try {
      ref.read(roomImmersiveProvider.notifier).set(value: value);
    } on Object {
      // The window's container is already gone with the page.
    }
  }

  /// The timer fired: pause the stream (never resume a paused room) and say
  /// so.
  void _onSleepFire() {
    unawaited(ref.read(roomProvider.notifier).pause());
    if (mounted) {
      showDsToast(context: context, title: context.t.room.sleepDone);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rootNav = Navigator.of(context, rootNavigator: true);
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void> && route != _observedRoute) {
      // The field is not promoted by flow analysis, so name the type.
      // ignore: omit_local_variable_types
      final RouteObserver<ModalRoute<void>> observer = _routeObserver ?? ref.read(routeObserverProvider);
      _routeObserver = observer;
      observer.unsubscribe(this);
      _observedRoute = route;
      observer.subscribe(this, route);
    }
  }

  @override
  void didPop() {
    if (_shouldFloatOnExit) _leaveToFloating = true;
  }

  /// Whether this leave should hand the live handle to the floating player.
  /// A room window's own close, a fullscreen/PiP exit and an already stopped
  /// room are not handoffs.
  bool get _shouldFloatOnExit {
    final room = ref.read(roomProvider);
    return !_closingRoom &&
        ref.read(playbackSettingsProvider).floatPlay &&
        room.playback.playing &&
        room.handle != null &&
        ref.read(roomLeaveProvider) == null &&
        ref.read(roomPresentationProvider) == PresentationMode.normal;
  }

  @override
  void dispose() {
    playbackRemote.unregister(_remoteTarget);
    // The page may be destroyed while it fills the window; the next route
    // must get its window strip back.
    _writeAfterFrame(() => _immersiveNotifier.set(value: false));
    _writeAfterFrame(() => _playlistNotifier.clearIfCurrent(_currentRoomKey));
    if (_openPanelKind != null) {
      _rootNav?.popUntil((route) => !isRoomPanelRoute(route));
      _openPanelKind = null;
    }
    _panels
      ..removeListener(_onRoomPanelChanged)
      ..dispose();
    _routeObserver?.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_pipSubscription?.cancel() ?? Future<void>.value());
    _pipSubscription = null;
    FloatingOverlay.active.removeListener(_onFloatingWindowChanged);
    FloatingOverlay.permitted.removeListener(_onFloatingWindowPermitted);
    // The page that owned the arm is going; a room kept in the floating
    // player arms nothing until it opens a page again.
    _floatingArmed = false;
    if (FloatingOverlay.supported) unawaited(FloatingOverlay.disarm());
    _backgroundGate?.dispose();
    _backgroundGate = null;
    _slowTimer?.cancel();
    unawaited(_screenAwake.disable().catchError((Object _) {}));
    _sleepTimerNotifier.onFire_ = null;
    _writeAfterFrame(() => _sleepTimerNotifier.start(null));
    if (_leaveToFloating && FloatingRoomPlayer.canShow) {
      // The room controller outlives this page; the overlay takes over its
      // handle until the viewer closes or re-enters the room. A handoff
      // that did not land (a same-frame hide won, the host is gone) stops
      // the room here instead of leaving it playing behind the pages.
      final controller = _presentationController;
      final player = _player;
      unawaited(
        FloatingRoomPlayer.show().then((shown) {
          if (shown) return;
          unawaited(_roomNotifier.close());
          if (controller != null && player != null) unawaited(controller.exit(player));
        }),
      );
    } else {
      // Leaving the route stops the stream rather than keeping it behind
      // the next page.
      _roomNotifier.closeFromPage();
      final controller = _presentationController;
      final player = _player;
      if (controller != null && player != null) {
        _writeAfterFrame(() => unawaited(controller.exit(player)));
      }
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) _appInForeground = false;
    if (state == AppLifecycleState.resumed) _appInForeground = true;
    _backgroundGate?.handleLifecycle(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _applyBackgroundAudioOnly();
      _pauseBackgroundDanmaku();
    }
    if (state == AppLifecycleState.resumed) {
      _restoreBackgroundAudioOnly();
      _resumeBackgroundDanmaku();
      _resumeAfterPipClose();
      // The viewer may have granted "display over other apps" while away.
      unawaited(FloatingOverlay.refresh());
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    // The Android small window shows the room through its floating player;
    // the page behind it would only be laid out for the window's few hundred
    // pixels and draw underneath it.
    if (FloatingOverlay.active.value) return const ColoredBox(color: kPlayerStageColor);
    final t = context.t;
    final room = ref.watch(roomProvider);
    // Declares the playing line's frame rate to the display while this page
    // exists; disposing the page releases it.
    ref.watch(roomRefreshRateProvider);
    _syncScreenWake(room.playback.playing && ref.watch(keepScreenOnProvider));
    final presentation = ref.watch(roomPresentationProvider);
    _maybeAutoFullscreen(room, presentation);
    _syncFloatingWindowArm(
      room,
      screen: MediaQuery.sizeOf(context),
      // The room must be what the viewer sees: leaving the app from settings
      // or a dialog pushed over the room is not leaving the room.
      onTop: ModalRoute.of(context)?.isCurrent ?? true,
      autoSmallWindow: ref.watch(playbackSettingsProvider.select((settings) => settings.autoPipOnLeave)),
      floating: ref.watch(floatingWindowSettingsProvider),
    );
    // POR-04: the orientation policy is asked once per entry into system
    // fullscreen — the driver's own exit path puts the lock back to the
    // side the device was held in.
    ref.listen(roomPresentationProvider, (previous, next) {
      if (next == PresentationMode.fullscreen && previous != PresentationMode.fullscreen) {
        // Any fullscreen entry — the viewer's own hand included — is the
        // auto-fullscreen's job done. The latch only lives in the auto path,
        // so a room where the viewer fullscreened first kept it armed and the
        // next rebuild fired a toggle into the just-entered fullscreen:
        // racing the exit click, the window bounced between sizes and the
        // exit landed on a half-transitioned layout.
        _autoFullscreenDone = true;
        _applyFullscreenOrientation();
      }
      if (next != PresentationMode.normal && _portraitFullscreen) {
        _setPortraitFullscreen(false);
      }
    });
    // What the room says about a login (a Bilibili connection that only sees
    // masked names, a Twitch cookie the server refused): the controller has
    // no context to toast with, so the visible page carries its hints.
    ref.listen(roomHintProvider, (previous, next) {
      if (next == null || previous?.id == next.id) return;
      showDsToast(context: context, title: next.text, status: DsStatus.warning);
    });
    final colors = DsTheme.colorsOf(context);
    // A TV remote uses the arrows to move focus and its own volume keys
    // for sound; a desktop keyboard keeps the arrows on the volume.
    final formFactor = ref.watch(platformRuntimeProvider).environment.runtime.formFactor;
    final tv = formFactor == FormFactor.tv;
    final mobile = formFactor == FormFactor.phone || formFactor == FormFactor.tablet;
    // The wide room fills the route, and this route can own the window, so
    // the page's own width is the measure its layout will take.
    final windowSize = MediaQuery.sizeOf(context);
    // 平板按设备最短边认定（≥600dp）：它走桌面的双栏骨架，跟手机的沉浸
    // 式和横持分栏无关。手机才是沉浸式的读者。
    final tabletSized = mobile && isTabletSized(windowSize);
    final phone = mobile && !tabletSized;
    // The machine resolves both axes once and the page's branches read it —
    // the policy table's whole point (P1's fold): a phone held sideways in a
    // short window takes the landscape arrangement before any width is asked
    // (the compact height wins over the wide breakpoint), and the wide
    // arrangement is the wide class minus that sideways take. A desktop
    // window as short keeps the layout its width gives it.
    final roomLayout = RoomLayout.resolve(width: windowSize.width, height: windowSize.height, phoneLike: phone);
    final landscapePhone = roomLayout.landscapePhone;
    // 平板在 600–840 的竖窗里也走宽布局：双栏的桌面骨架是它的形态，
    // 分栏底板只属于桌面窄窗与手机。
    final wideWindow = tabletSized || (roomLayout.windowClass == RoomWindowClass.wide && !landscapePhone);

    /// T 键与栏上按钮共用：宽屏把聊天列收起/展开——收起时回到列（必要时
    /// 从弹幕流切回），开着时收起。一个方向一对动作，不再是单程门。
    void toggleChatColumn() {
      final opening = ref.read(chatCollapsedProvider);
      if (opening) {
        unawaited(ref.read(chatCollapsedProvider.notifier).set(value: false));
      } else {
        unawaited(ref.read(chatCollapsedProvider.notifier).set(value: true));
      }
    }

    _watchSlow(room);
    final presentationController = ref.read(roomPresentationProvider.notifier);
    _presentationController = presentationController;
    _player = room.handle?.id;
    // Fullscreen and the desktop compact window take the app's window and
    // lay out the bare picture. A phone's picture-in-picture is the system's
    // window over the app, so this page keeps the layout it had.
    final ownsWindow = presentationController.modeOwnsWindow(presentation);

    /// The picture bar's gear asks the chat panel for its settings body. The
    /// panel answers on its own build; the page's part of the ask is making
    /// the chat face visible first — a folded column or a stream gives way to
    /// the column, the immersive room slides its drawer out, the TV's
    /// floating column unfolds. The stacked rooms carry the panel always, so
    /// a narrow window has nothing to open.
    /// The back arrow and Escape: leave the presentation mode while one
    /// holds the page, otherwise leave the room — where "leave" is the
    /// host's verb: a route pop in the app, a window close in a room window.
    void leave() {
      if (_portraitFullscreen) {
        _setPortraitFullscreen(false);
        return;
      }
      final player = room.handle?.id;
      final mode = ref.read(roomPresentationProvider);
      if (mode == PresentationMode.windowFullscreen && player != null) {
        unawaited(presentationController.toggleWindowFullscreen(player));
      } else if (ownsWindow && player != null) {
        unawaited(presentationController.exit(player));
      } else if (ref.read(roomLeaveProvider) case final closeWindow?) {
        // A room window's native close may take the view away before this
        // page's dispose runs; stop the room first so its sound cannot
        // outlive the window.
        unawaited(_roomNotifier.close());
        unawaited(closeWindow());
      } else if (context.canPop()) {
        if (_leaving) return;
        _leaving = true;
        if (_shouldFloatOnExit) _leaveToFloating = true;
        context.pop();
      } else {
        if (_shouldFloatOnExit) _leaveToFloating = true;
        context.go(RouteNames.popular);
      }
    }

    /// Stops the room from a compact window: leave the mode, then leave the
    /// room itself. The window's close button means "I am done watching",
    /// where the back arrow means "put the page back".
    void closeRoom() {
      _closingRoom = true;
      final player = room.handle?.id;
      if (player != null) unawaited(presentationController.exit(player));
      if (ref.read(roomLeaveProvider) case final closeWindow?) {
        unawaited(_roomNotifier.close());
        unawaited(closeWindow());
      } else if (context.canPop()) {
        if (_leaving) return;
        _leaving = true;
        context.pop();
      } else {
        context.go(RouteNames.popular);
      }
    }

    // F enters/leaves fullscreen, Escape leaves the mode (or, in the page's
    // own layout, the room), Space plays and pauses. A focused text field
    // consumes the keys first, so the composer never flips the playback.
    void nudgeVolume(double delta) {
      final handle = room.handle;
      if (handle == null) return;
      final next = (handle.volume + delta).clamp(0.0, 1.0);
      _surfaceHud.show(next);
      unawaited(ref.read(roomProvider.notifier).setVolume(next));
    }

    // The arrows take the wheel's step (the 画质与音频 setting); watching it
    // keeps the bindings honest after a change.
    final volumeStep = ref.watch(playbackSettingsProvider.select((settings) => settings.volumeWheelStepPercent)) / 100;

    // One table feeds the keys this page answers to and the `?` help sheet:
    // a line the sheet shows is a key that works. Its conditions are the
    // same ones the verbs run under — a TV remote keeps the arrows on focus,
    // a narrow window has no chat column to fold, and a backend without a
    // capture route has no frame to save.
    final shortcuts = roomShortcutBindings(
      t,
      tv: tv,
      chatColumn: wideWindow,
      canCaptureScreenshot: room.handle?.canCaptureScreenshot ?? false,
    );
    VoidCallback shortcutAction(RoomShortcutAction action) => switch (action) {
      RoomShortcutAction.playPause => () => unawaited(ref.read(roomProvider.notifier).togglePlayPause()),
      RoomShortcutAction.fullscreen => _toggleFullscreenVerb,
      RoomShortcutAction.leave => leave,
      RoomShortcutAction.volumeUp => () => nudgeVolume(volumeStep),
      RoomShortcutAction.volumeDown => () => nudgeVolume(-volumeStep),
      RoomShortcutAction.chatColumn => toggleChatColumn,
      // A frame of the stream, for when it misbehaves.
      RoomShortcutAction.screenshot => () {
        final handle = ref.read(roomProvider).handle;
        if (handle == null || !handle.canCaptureScreenshot) return;
        unawaited(takeRoomScreenshot(context, ref, handle));
      },
      RoomShortcutAction.stats => () => ref.read(playerStatsVisibleProvider.notifier).toggle(),
      RoomShortcutAction.retry => () => unawaited(ref.read(roomProvider.notifier).retry()),
      RoomShortcutAction.help => () => unawaited(showRoomShortcuts(context, shortcuts)),
    };
    final keys = <SingleActivator, VoidCallback>{
      for (final binding in shortcuts)
        for (final activator in binding.keys) activator: shortcutAction(binding.action),
    };

    final pictureRatio = _pictureRatio(room);
    final swipeSwitch = ref.watch(portraitSwipeSwitchProvider);
    final roomKey = room.room?.ref.identityKey ?? '';
    // A source that rotates back to landscape leaves the portrait surface,
    // unless the viewer swiped to it: the reference keeps that room on the
    // portrait surface (ambient) while the list still has neighbours. The
    // post-frame callback keeps setState out of build.
    final keepPortrait = swipeSwitch && _portraitSwipeTarget == roomKey;
    if (_portraitFullscreen && room.handle != null && !keepPortrait && !_switchingPortraitRoom && pictureRatio >= 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _portraitFullscreen) _setPortraitFullscreen(false);
      });
    }
    final chatCollapsed = ref.watch(chatCollapsedProvider);
    // The reference-layout stream: plain talk over the picture. It is the
    // glance presentation of the full-bleed layouts only — the stacked and
    // sheet rooms keep their panel — and it yields to the fold switch and to
    // the TV's own two-column room.
    // The chat is always the side column now; the stream presentation and
    // its settings are gone.

    /// The picture surface, with the layout's own chat (the TV's glass
    /// column, the stream over the picture) handed in as a page layer: the
    /// surface draws its own bars and catalogues above that layer. [onTitle]
    /// is the sideways phone's: the strip names the room where its card used
    /// to, and the name opens the details.
    ///
    /// The immersive layouts override the portrait-surface bits through the
    /// trailing arguments: [portraitSurface] puts the capsule and the
    /// swipe-to-switch zones on a surface the page does not track as
    /// `_portraitFullscreen` (the immersive room is the layout, not a mode),
    /// [showModeExit] silences a chip that would lie (an always-on surface
    /// has no layout under itself to exit to), and [onMoreOverride] lets the
    /// immersive shapes carry the clean-screen switch in the sheet.
    Widget playerWith({
      Widget? overlay,
      double bottomInset = 0,
      double controlBarEndInset = 0,
      VoidCallback? onTitle,
      double topBarEndInset = DsSpace.s12,
      bool? portraitSurface,
      bool? ambientOverride,
      bool showModeExit = true,
      double topInset = 0,
      bool liftsOverKeyboard = false,
      bool danmakuInput = false,
      bool allowPortraitRestore = true,
      VoidCallback? fullscreenVerb,
      VoidCallback? onMoreOverride,
    }) => PlayerSurface(
      key: _playerKey,
      roomState: room,
      barrage: ref.read(roomProvider.notifier).barrage,
      onLeave: leave,
      onCloseRoom: closeRoom,
      immersive: ownsWindow || _portraitFullscreen,
      // The TV room starts on its play button and keeps its bars: a remote
      // has no pointer to wake them, and arrows must walk controls.
      keepControls: tv,
      autofocusFirstControl: tv,
      // The remote's Up and Down on the picture switch rooms — the same
      // step walk the portrait full screen's swipe runs, the playlist when
      // the room came from one, the switcher's list otherwise.
      onSwitchRoom: tv ? _switchRoomByStep : null,
      // A TV's bars take their own tier: larger controls, wider gaps and a
      // focus ring, since the remote has no pointer and the viewer sits back.
      tv: tv,
      portraitFullscreen: portraitSurface ?? _portraitFullscreen,
      // The swipe up from the portrait full screen's bottom band, back to the
      // panel: a touch screen's gesture, where the surface is the whole of it.
      onTitle: onTitle,
      // The room's own framing, not only the source's: a portrait frame the
      // viewer chose sits over the room's art too, a landscape one keeps the
      // stage's black — except on the immersive surfaces, where whatever the
      // stream's shape the room's art stands behind the frame.
      ambient: ambientOverride ?? (pictureRatio < 1 || _portraitFullscreen),
      overlay: overlay,
      bottomInset: bottomInset,
      controlBarEndInset: controlBarEndInset,
      // A presentation mode that owns the window has no chat to float, and a
      // narrow page stacks it under the picture.
      onMore: onMoreOverride ?? () => unawaited(showRoomMore(context, shortcuts: shortcuts)),
      topBarEndInset: topBarEndInset,
      hud: _surfaceHud,
      // The portrait full screen's own verbs, now reachable: the swipe up
      // along the picture's lowest band puts the page's layout back, the
      // sideways swipe in the middle third walks the room list where the
      // viewer asked for one, and the fullscreen verb follows the frame's
      // shape — the page owns all three. The immersive surfaces answer the
      // verb with the system's own fullscreen directly: they are already the
      // page's full-bleed layout, and there is no surface under them.
      showModeExit: showModeExit,
      topInset: topInset,
      liftsOverKeyboard: liftsOverKeyboard,
      danmakuInput: danmakuInput,
      // The restore band listens only where a restore exists: an immersive
      // layout has no page layout under it, and its lowest band keeps the
      // volume drag the band would otherwise swallow.
      onPortraitRestore: allowPortraitRestore ? () => _setPortraitFullscreen(false) : null,
      onPortraitSwipe: swipeSwitch && phone ? _switchRoomByStep : null,
      onFullscreen: fullscreenVerb ?? _toggleFullscreenVerb,
    );

    // The docked chat column's width while the wide inline room shows it:
    // the app bar pins the follow pill to the picture's right edge, this
    // many pixels from the window's end.
    final barChatWidth =
        !tv &&
        !landscapePhone &&
        (MediaQuery.sizeOf(context).width >= _wideBreakpoint || tabletSized) &&
        !chatCollapsed
        ? ref
              .watch(chatPanelWidthProvider)
              .clamp(
                kChatPanelWidthMin,
                math.max(
                  kChatPanelWidthMin,
                  math.min(kChatPanelWidthMax, MediaQuery.sizeOf(context).width - _wideStageFloor),
                ),
              )
              .toDouble()
        : 0.0;

    final body = _portraitFullscreen
        ? _buildPortraitFullscreen(
            context,
            // The portrait full screen has no column of its own: the stream
            // is the chat there, unless the stats panel owns the corner.
            playerWith(),
            canSwipeRooms: swipeSwitch && phone,
          )
        : LayoutBuilder(
            builder: (context, constraints) {
              // 手机横持的沉浸式房间（对齐参考横屏）：满铺画面，控制条带发送，
              // 竖直滑动照旧换直播间。聊天列不再横持分栏——飞行弹幕与条上的
              // 输入就是这里的全部对话。
              if (landscapePhone) {
                return _buildPhoneLandscapeImmersive(
                  context,
                  player: playerWith(
                    portraitSurface: true,
                    ambientOverride: true,
                    showModeExit: false,
                    topInset: MediaQuery.paddingOf(context).top,
                    liftsOverKeyboard: true,
                    danmakuInput: true,
                    allowPortraitRestore: false,
                    fullscreenVerb: _enterSystemFullscreen,
                  ),
                  canSwipeRooms: swipeSwitch && phone,
                );
              }
              final wide = constraints.maxWidth >= _wideBreakpoint || tabletSized;
              if (!wide) {
                // 手机竖屏的沉浸式房间（宽 < 600）：满铺画面，聊天以胶囊浮层
                // 贴在左下，输入条常驻底部，顶部是主播胶囊。清屏一行把浮层
                // 收起，更多菜单携带它的开关。
                if (phone && constraints.maxWidth < kRoomCompactBreakpoint) {
                  void setCleanScreen({required bool value}) {
                    setState(() {
                      _cleanScreen = value;
                      // 清屏收起抽屉：一张谈话表面在场的规则。
                      if (value) _immersiveChatOpen = false;
                    });
                  }

                  VoidCallback openMore() => () => unawaited(
                    showRoomMore(
                      context,
                      shortcuts: shortcuts,
                      cleanScreen: true,
                      onCleanScreen: (value) => setCleanScreen(value: value),
                    ),
                  );
                  final padding = MediaQuery.paddingOf(context);
                  final keyboard = MediaQuery.viewInsetsOf(context).bottom;
                  return _buildPhoneImmersivePortrait(
                    context,
                    player: playerWith(
                      portraitSurface: true,
                      ambientOverride: true,
                      showModeExit: false,
                      topInset: padding.top,
                      liftsOverKeyboard: true,
                      allowPortraitRestore: false,
                      // The control bar stands on the composer bar — and on
                      // the keyboard with it; a clean screen has no bar under
                      // it, so the floor drops away with the pills.
                      bottomInset: _cleanScreen ? 0 : padding.bottom + keyboard + _kImmersiveComposerBarHeight,
                      fullscreenVerb: _enterSystemFullscreen,
                      onMoreOverride: openMore(),
                    ),
                    canSwipeRooms: swipeSwitch && phone,
                    onMore: openMore(),
                  );
                }
                // 桌面窄窗（600–840）保持分栏：竖屏流全铺画面加拖拽面板
                // （平衡停靠），其余流堆叠分栏。竖屏全屏表面仍是这一档的
                // 竖屏出口。
                final portraitStream = pictureRatio < 1;
                if (portraitStream) {
                  return RoomBottomPanel(
                    // The balanced opening is the room's own: the least
                    // picture covered still shows the talk where a chat is
                    // readable (the layout mode setting is gone).
                    preferred: RoomPanelStop.middle,
                    onCoverChanged: _setPanelCover,
                    // Pulling the sheet past its lowest stop is the handle's own
                    // way into the portrait full screen — the verb follows the
                    // picture's shape, and the sheet only shows for a portrait
                    // stream, so the pull always lands on the portrait surface.
                    onPortraitFullscreen: _enterFullscreen,
                    picture: ColoredBox(
                      color: kPlayerStageColor,
                      child: playerWith(bottomInset: _panelCover),
                    ),
                    pill: DsButton(
                      variant: DsButtonVariant.ghost,
                      size: DsSize.xs,
                      onPressed: _enterFullscreen,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: DsSpace.s4,
                        children: [const DsIcon(DsIcons.fullscreen, size: 14), Text(t.room.fullscreenOn)],
                      ),
                    ),
                    panel: const Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // The sheet's head is the facts row (the redesign's
                        // pinfo): the identity lives in the bar above, the
                        // title and its figures here, and the talk keeps the
                        // height the hero card used to take.
                        _RoomPanelInfo(),
                        // The sheet paints its own frosted surface; a second
                        // opaque one under it would hide the glass.
                        Expanded(child: RoomChatPanel(translucent: true)),
                      ],
                    ),
                  );
                }
                // The reference's own compact column (the fCompact shape): the
                // picture takes what the panel leaves, the grip drags the panel
                // between its three stops, and the panel is the facts row over
                // the chat with the docks' chips at its foot. A pull past the
                // lowest stop — or a downward flick — hands the room to its
                // portrait full screen.
                return _CompactRoomBody(
                  player: playerWith(),
                  ratio: pictureRatio,
                  chat: const RoomChatPanel(),
                  onPortraitFullscreen: _enterFullscreen,
                );
              }
              // 宽屏桌面：像直播站本站一样的满铺排版。画面贴边占满内容区，
              // 聊天列沿右缘（宽度由聊天设置保管，可拖可折），房间的事实在
              // 顶上的应用栏（返回、标题、关注与房间菜单）；弹幕流模式或
              // 收起的聊天列让画面独占整行。
              if (!tv) {
                final columnMaxWidth = math.max(
                  kChatPanelWidthMin,
                  math.min(kChatPanelWidthMax, constraints.maxWidth - _wideStageFloor),
                );
                // The column's width is the chat setting's own: the seam's
                // drag previews it, the gesture's end stores it, and a
                // double-tap puts the default back.
                final columnWidth = ref.watch(chatPanelWidthProvider).clamp(kChatPanelWidthMin, columnMaxWidth);
                // A room that owns the window (window fullscreen) fills it with
                // the picture alone — no docked chat column.
                final columnOpen = !ownsWindow && !chatCollapsed;
                // The wide room reads like the live sites: the picture fills the
                // content area edge to edge, the chat down the right, and the
                // room's facts ride the bar above — no card, no inset. The chat
                // column folds and unfolds from the bar's toggle only; the
                // picture keeps no floating sidebar button of its own.
                final stage = ColoredBox(color: kPlayerStageColor, child: playerWith());
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: stage),
                    if (columnOpen) ...[
                      ChatSplitter(
                        width: columnWidth,
                        minWidth: kChatPanelWidthMin,
                        maxWidth: columnMaxWidth,
                        onResize: ref.read(chatPanelWidthProvider.notifier).preview,
                        onResizeEnd: (value) => unawaited(ref.read(chatPanelWidthProvider.notifier).set(value)),
                        onReset: () => unawaited(ref.read(chatPanelWidthProvider.notifier).set(kChatPanelWidthDefault)),
                        label: t.room.chatColumnWidth,
                      ),
                      SizedBox(
                        width: columnWidth,
                        // The column is the panel's own: its tabs lead it, and
                        // the identity lives once, in the bar above — the
                        // redesign's single-owner rule for the anchor's card.
                        child: const RoomChatPanel(),
                      ),
                    ],
                  ],
                );
              }
              // TV 房间保持满铺舞台与浮动玻璃列：遥控没有指针去唤卡片，
              // 双栏卡片是给有指针的桌面准备的。标题玻璃是画面左上的浮层，
              // 弹幕列是右缘可折叠的浮层——折叠后只剩画面和一个展开按钮，
              // 即影院。列宽仍是弹幕设置自己的。
              final maxChatWidth = math.max(
                kChatPanelWidthMin,
                math.min(kChatPanelWidthMax, constraints.maxWidth - _wideStageFloor),
              );
              final chatWidth = kChatPanelWidthFixed.clamp(kChatPanelWidthMin, maxChatWidth);
              void toggleChat() {
                unawaited(ref.read(chatCollapsedProvider.notifier).set(value: !chatCollapsed));
              }

              // The full chat column as a floating layer over the TV's stage:
              // the glass, with the close verb at the tab row's end where it
              // cannot cover the last tab.
              Widget chatColumn({required VoidCallback onClose}) => PositionedDirectional(
                top: 0,
                bottom: 0,
                end: 0,
                child: SizedBox(
                  width: chatWidth,
                  child: RoomGlassCard(
                    child: RoomChatPanel(
                      translucent: true,
                      trailing: DsButton.icon(
                        variant: DsButtonVariant.ghost,
                        size: DsSize.sm,
                        onPressed: onClose,
                        icon: const DsIcon(DsIcons.panelRightClose),
                        semanticLabel: t.room.collapseChat,
                      ),
                    ),
                  ),
                ),
              );
              if (chatCollapsed) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(color: kPlayerStageColor, child: playerWith()),
                    ),
                    PositionedDirectional(
                      top: DsSpace.s8,
                      end: DsSpace.s8,
                      child: DsButton.icon(
                        variant: DsButtonVariant.secondary,
                        size: DsSize.sm,
                        onPressed: toggleChat,
                        icon: const DsIcon(DsIcons.panelRightOpen),
                        semanticLabel: t.room.expandChat,
                      ),
                    ),
                  ],
                );
              }
              return ColoredBox(
                color: kPlayerStageColor,
                child: playerWith(
                  topBarEndInset: chatWidth + DsSpace.s12,
                  // The bar stops where the glass column begins: its scrim and
                  // buttons would otherwise draw over the column's composer.
                  controlBarEndInset: chatWidth,
                  overlay: chatColumn(onClose: toggleChat),
                ),
              );
            },
          );

    // The page, not the body, holds the shortcuts: Space and the arrows
    // must work while an AppBar action or a chat field has focus too.
    Widget withShortcuts(Widget child) => Focus(
      // A mouse/keyboard room keeps the page itself as the shortcut
      // holder; the TV room leaves the focus to the player's first control.
      autofocus: !tv,
      child: CallbackShortcuts(bindings: keys, child: child),
    );

    // A presentation mode that owns the window keeps the whole page; the
    // inline room (and a phone's picture-in-picture, whose window floats over
    // the app) keeps the app bar with its header, follow button and menu.
    // Both branches keep the same root (an opaque stage under a Scaffold), so
    // a mode change never unmounts the player's ancestors wholesale and a
    // transition's missing frame paints the picture's own black instead of
    // the theme's surface.
    final ownChrome = WindowChromeState.drawsCaptionControls;
    // 手机的沉浸式表面：页面自己的满铺布局（竖屏 < 600、横持的矮窗）——
    // 应用栏与 SafeArea 都不参与，系统栏的空隙由浮层自己让出，键盘由表
    // 面自己抬（页面不随键盘缩放，画面不跳）。
    final immersiveSurface =
        phone && !landscapePhone && !_portraitFullscreen && windowSize.width < kRoomCompactBreakpoint;
    return withShortcuts(
      RoomPanelScope(
        notifier: _panels,
        child: ColoredBox(
          color: kPlayerStageColor,
          child: ownsWindow
              ? Scaffold(
                  backgroundColor: kPlayerStageColor,
                  body: presentation == PresentationMode.windowFullscreen
                      ? Column(
                          children: [
                            _WindowFullscreenCaption(onBack: leave),
                            Expanded(child: playerWith()),
                          ],
                        )
                      : playerWith(),
                )
              : PopScope(
                  // The portrait full screen holds the back gesture: a pop here
                  // would leave the room itself, and the mode has its own way
                  // out first — the same first step `leave` takes. Any other
                  // layout pops as the route always did.
                  canPop: !_portraitFullscreen,
                  onPopInvokedWithResult: (didPop, _) {
                    if (!didPop && _portraitFullscreen) _setPortraitFullscreen(false);
                  },
                  child: Scaffold(
                    // The portrait full-screen surface is the page's own way of
                    // filling the window: it keeps its black stage and drops the
                    // app bar with it, so no header survives into the mode. The
                    // immersive phone's surfaces are the same kind of layout —
                    // the page's own full-bleed — and drop the chrome with it.
                    backgroundColor: _portraitFullscreen || immersiveSurface ? kPlayerStageColor : colors.canvas,
                    resizeToAvoidBottomInset: immersiveSurface ? false : null,
                    appBar: _portraitFullscreen || immersiveSurface
                        ? null
                        : _roomAppBar(
                            context,
                            colors: colors,
                            ownChrome: ownChrome,
                            leave: leave,
                            chatColumnWidth: barChatWidth,
                          ),
                    body: _portraitFullscreen || immersiveSurface ? body : SafeArea(child: body),
                  ),
                ),
        ),
      ),
    );
  }
}
