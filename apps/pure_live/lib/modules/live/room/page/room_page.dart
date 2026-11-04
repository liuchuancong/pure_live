import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show AppBar, Scaffold, kToolbarHeight;
import 'package:flutter/scheduler.dart' show SchedulerBinding;
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
import 'package:pure_live/layouts/app_switcher.dart' show AppMark;
import 'package:pure_live/modules/live/favorites/favorites.dart';
import 'package:pure_live/modules/live/history/history.dart';
import 'package:pure_live/modules/live/recorder/recorder.dart';
import 'package:pure_live/modules/live/room/chat/room_chat.dart' show RoomChatPanel;
import 'package:pure_live/modules/live/room/controller/room_controller.dart';
import 'package:pure_live/modules/live/room/page/chat_splitter.dart' show ChatSplitter;
import 'package:pure_live/modules/live/room/page/player_surface.dart'
    show PlayerSurface, kPlayerStageColor, toggleRoomPip, toggleRoomRecording;
import 'package:pure_live/modules/live/room/page/room_bottom_panel.dart';
import 'package:pure_live/modules/live/room/page/room_details.dart'
    show copyRoomLink, openRoomExternally, roomLinkOf, shareRoom, showRoomDetails;
import 'package:pure_live/modules/live/room/page/room_glass_card.dart';
import 'package:pure_live/modules/live/room/page/room_orientation.dart'
    show
        RoomOrientation,
        kRoomFrameRatioMax,
        kRoomFrameRatioMin,
        roomFramedRatio,
        roomOrientationProvider,
        showRoomOrientationDialog;
import 'package:pure_live/modules/live/room/page/room_refresh_rate.dart' show roomRefreshRateProvider;
import 'package:pure_live/modules/live/room/page/room_screenshot.dart' show takeRoomScreenshot;
import 'package:pure_live/modules/live/room/page/room_shortcuts.dart'
    show RoomShortcutAction, RoomShortcutBinding, roomShortcutBindings, showRoomShortcuts;
import 'package:pure_live/modules/live/room/page/room_status.dart' show roomSlowProvider, slowAfter;
import 'package:pure_live/modules/live/room/page/room_theater.dart' show roomTheaterProvider;
import 'package:pure_live/modules/live/room/player/floating_room_player.dart' show FloatingRoomPlayer;
import 'package:pure_live/modules/live/room/player/room_playlist.dart'
    show RoomPlaylistController, roomPlaylistProvider;
import 'package:pure_live/modules/live/room/player/room_switcher.dart' show roomSwipeList, showRoomSwitcher;
import 'package:pure_live/modules/live/room/player/sleep_timer.dart';
import 'package:pure_live/shared/shared.dart';

/// The live room: media_core's picture with the app's control layer over
/// it, the room's facts under it, and the chat beside it on a wide window.
///
/// The layout follows the reference's inline shapes: from 840 px the
/// picture and its facts take the left and the chat a column of the
/// viewer's own width on the right; narrower windows stack the chat under
/// the picture. Fullscreen,
/// window fullscreen and PiP hand the whole page to the picture — those
/// modes are media_core's presentation drivers, so the page only follows the
/// state they publish.
final class RoomPage extends ConsumerStatefulWidget {
  /// The room to open, by platform and room id.
  const RoomPage({required this.platform, required this.roomId, super.key});

  /// The room's platform id.
  final String platform;

  /// The room's platform room id.
  final String roomId;

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
  /// reference's `wide` layout).
  static const double _wideBreakpoint = 840;

  /// The stage's floor while the chat column is dragged wide: at the wide
  /// layout's own edge the column tops out under its 520 px cap rather than
  /// squeezing the picture into a strip.
  static const double _wideStageFloor = 420;

  /// The strips the picture's own top bar and control bar take at its edges.
  /// The theatre's glass column starts and ends clear of them, so neither the
  /// bars nor what rises from them (a picker's catalogue) ever lands on the
  /// chat's words.
  ///
  /// Both follow the bars' own geometry rather than a look: the top is the
  /// presentation pill the strip keeps in-page (8 px of padding + a 32 px
  /// control + the pill's own air), since C7 left the identity in the page
  /// header; the bottom is the control bar's padding (8 + 8) plus one row of
  /// 32 px buttons — the live progress line C3 removed used to add 10 of them.
  static const double _theaterTopInset = 44;
  static const double _theaterBottomInset = 52;

  /// The player's own identity across the page's layout branches: normal,
  /// immersive (fullscreen/window fullscreen/PiP) and the portrait surface
  /// all embed the same [PlayerSurface] state, so a mode switch reparents
  /// the subtree instead of tearing the video texture down and back.
  final GlobalKey _playerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _roomNotifier = ref.read(roomProvider.notifier);
    _immersiveNotifier = ref.read(roomImmersiveProvider.notifier);
    _playlistNotifier = ref.read(roomPlaylistProvider.notifier);
    _sleepTimerNotifier = ref.read(sleepTimerProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
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
    // The room never opens from inside its own build; the page asks.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(roomProvider.notifier).open(platform: widget.platform, roomId: widget.roomId));
    });
    // A PiP window closed while the app is away means "stop", when the
    // setting says so; the system ends the window without a lifecycle event.
    _pipSubscription = ref.read(pipDriverProvider).onPipChanged.listen(_onPipChanged);
    // The Android small window takes the screen when the app is left; the
    // room's floating player is what fills it.
    FloatingOverlay.listen();
    FloatingOverlay.active.addListener(_onFloatingWindowChanged);
    FloatingOverlay.permitted.addListener(_onFloatingWindowPermitted);
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

  /// The sheet's pill: the room's own full screen, the same verb the bar carries.
  void _enterFullscreen() {
    final handle = ref.read(roomProvider).handle;
    if (handle == null) return;
    unawaited(ref.read(roomPresentationProvider.notifier).toggleFullscreen(handle.id));
  }

  /// Shows or leaves the portrait full-screen surface and publishes it: the
  /// route's chrome hides the window strip while this page owns the window,
  /// exactly as it does for fullscreen, and the page's own layout is the only
  /// thing that can know.
  void _setPortraitFullscreen(bool value) {
    if (_portraitFullscreen == value) return;
    if (mounted) {
      setState(() => _portraitFullscreen = value);
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
    // The page may be destroyed while it fills the window; the next route
    // must get its window strip back.
    _writeAfterFrame(() => _immersiveNotifier.set(value: false));
    _playlistNotifier.clearIfCurrent(_currentRoomKey);
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
    _sleepTimerNotifier
      ..onFire_ = null
      ..start(null);
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

  /// Runs a provider write this leaving page may not make in place.
  ///
  /// The route unmounts while the tree is being torn down, and Riverpod
  /// rejects a notification in that phase — it left the page half unmounted
  /// with the route transition reading a dead element. The write therefore
  /// rides the end of the frame, and it goes through a notifier captured
  /// while this page still existed, never through its own `ref`.
  void _writeAfterFrame(void Function() write) => SchedulerBinding.instance.addPostFrameCallback((_) => write());

  /// The reference's `applyFullscreenOrientationPolicy`: on a phone the
  /// fullscreen orientation policy decides which way the device turns as
  /// the room goes system-fullscreen — upright for a portrait stream (or
  /// always, per the choice), sideways for the rest, or the lock released
  /// to follow the accelerometer. Desktop and web answer inert there. VOD and
  /// IPTV ask the same rule for themselves.
  void _applyFullscreenOrientation() {
    applyFullscreenOrientation(
      _screenOrientation,
      aspectRatio: ref.read(roomProvider).handle?.combinedSnapshot.geometry.aspectRatio ?? 0,
    );
  }

  void _watchSlow(RoomState room) {
    final connecting = room.room != null && room.handle == null && !room.playback.playing;
    if (connecting && _slowTimer == null) {
      _slowTimer = Timer(slowAfter, () {
        if (mounted) ref.read(roomSlowProvider.notifier).slow = true;
      });
    } else if (!connecting && _slowTimer != null) {
      _slowTimer?.cancel();
      _slowTimer = null;
      // The flag feeds the overlay this build reads; flipping it after the
      // frame avoids modifying a provider mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(roomSlowProvider.notifier).slow = false;
      });
    }
  }

  /// The reference's auto-fullscreen: a room whose stream starts playing
  /// enters fullscreen once. A viewer already in another presentation mode
  /// (or one who leaves it) keeps their choice; a paused or failed room
  /// never asks.
  void _maybeAutoFullscreen(RoomState room, PresentationMode presentation) {
    if (_autoFullscreenDone) return;
    if (!_autoFullscreenArmed) return;
    final handle = room.handle;
    if (handle == null || !room.playback.playing) return;
    _autoFullscreenDone = true;
    if (presentation != PresentationMode.normal) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(roomPresentationProvider) != PresentationMode.normal) return;
      if (!ref.read(roomProvider).playback.playing) return;
      unawaited(ref.read(roomPresentationProvider.notifier).toggleFullscreen(handle.id));
    });
  }

  /// Holds the display awake exactly while frames are playing and the
  /// preference allows it: a paused room, a failed room, or the setting off
  /// lets the display sleep as usual.
  void _syncScreenWake(bool hold) {
    if (hold == _screenHeld) return;
    _screenHeld = hold;
    unawaited((hold ? _screenAwake.enable() : _screenAwake.disable()).catchError((Object _) {}));
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

  /// The PiP window went away: pause only when the room would otherwise keep
  /// playing in the background, as the reference's "关闭画中画时暂停".
  ///
  /// On iOS the system window is the one that closes this way; on Android the
  /// switch lives next to background playback, which already keeps the app
  /// quiet when it is off.
  void _onPipChanged(bool active) {
    if (active) {
      _pipWasActive = true;
      return;
    }
    if (!_pipWasActive) return;
    _pipWasActive = false;
    final platform = defaultTargetPlatform;
    if (_appInForeground || kIsWeb || (platform != TargetPlatform.android && platform != TargetPlatform.iOS)) return;
    final settings = ref.read(playbackSettingsProvider);
    if (!settings.pauseOnPipClose) return;
    if (platform == TargetPlatform.android && !settings.backgroundPlay) return;
    final room = ref.read(roomProvider);
    if (room.handle == null || !room.playback.playing) return;
    _pausedByPipClose = true;
    unawaited(ref.read(roomProvider.notifier).pause());
  }

  void _resumeAfterPipClose() {
    if (!_pausedByPipClose) return;
    _pausedByPipClose = false;
    final room = ref.read(roomProvider);
    if (room.handle == null || room.playback.playing) return;
    unawaited(ref.read(roomProvider.notifier).togglePlayPause());
  }

  /// Android background playback may keep only the audio: the video decoder
  /// stops, the sound and the room's session stay, and the pre-background
  /// mode is remembered for the return.
  void _applyBackgroundAudioOnly() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final settings = ref.read(playbackSettingsProvider);
    if (!settings.backgroundPlay || !settings.backgroundAudioOnly) return;
    final room = ref.read(roomProvider);
    if (room.handle == null || !room.playback.playing || room.audioOnly) return;
    _audioOnlyBeforeBackground = room.audioOnly;
    _backgroundAudioOnlyApplied = true;
    unawaited(ref.read(roomProvider.notifier).setAudioOnly(value: true));
  }

  void _restoreBackgroundAudioOnly() {
    if (!_backgroundAudioOnlyApplied) return;
    _backgroundAudioOnlyApplied = false;
    if (_audioOnlyBeforeBackground) return;
    unawaited(ref.read(roomProvider.notifier).setAudioOnly(value: false));
  }

  /// Pauses the site's danmaku connection in the background when the viewer
  /// asked for it; the room's chat list keeps what it already has.
  void _pauseBackgroundDanmaku() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final settings = ref.read(playbackSettingsProvider);
    if (!settings.backgroundPlay || !settings.backgroundPauseDanmaku) return;
    if (_backgroundDanmakuPaused) return;
    _backgroundDanmakuPaused = true;
    unawaited(ref.read(roomProvider.notifier).pauseDanmakuConnection());
  }

  void _resumeBackgroundDanmaku() {
    if (!_backgroundDanmakuPaused) return;
    _backgroundDanmakuPaused = false;
    unawaited(ref.read(roomProvider.notifier).resumeDanmakuConnection());
  }

  /// The Android small window took the screen, or gave it back: while it shows,
  /// the room's floating player is the whole content of the window; with it
  /// gone, the page behind — still mounted and playing — is what the viewer
  /// sees again.
  void _onFloatingWindowChanged() {
    if (FloatingOverlay.active.value) {
      unawaited(FloatingRoomPlayer.show());
    } else {
      FloatingRoomPlayer.hide();
      // The window takes its arm with it when it closes itself; re-decide for
      // the next leave once the page draws again.
      _floatingArmed = false;
      _floatingArmedSize = null;
    }
    if (mounted) setState(() {});
  }

  /// "离开应用时自动小窗": keeps the small window armed while a room plays, so
  /// leaving the app (home, recents) shows the picture over the other apps.
  ///
  /// Armed here, ahead of the leave, because the native side decides in
  /// `onUserLeaveHint` — before any Dart call could run. Phones only, and only
  /// with the draw-over-other-apps grant: without it the app simply leaves.
  void _syncFloatingWindowArm(
    RoomState room, {
    required Size screen,
    required bool onTop,
    required bool autoSmallWindow,
    required FloatingWindowSettings floating,
  }) {
    if (!FloatingOverlay.supported) return;
    final wanted =
        onTop && autoSmallWindow && room.handle != null && room.playback.playing && !FloatingOverlay.active.value;
    final size = wanted ? _floatingWindowSize(_floatingWindowRatio(room), floating, screen) : Size.zero;
    if (wanted == _floatingArmed && (!wanted || size == _floatingArmedSize)) return;
    _floatingArmed = wanted;
    _floatingArmedSize = wanted ? size : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!wanted) {
        unawaited(FloatingOverlay.disarm());
        return;
      }
      unawaited(_armFloatingWindow(size));
    });
  }

  Future<void> _armFloatingWindow(Size size) async {
    if (!await FloatingOverlay.refresh()) {
      // No grant yet: leave the arm open so the next build arms the window
      // once the viewer grants it (the setting's toggle asks for it).
      _floatingArmed = false;
      _floatingArmedSize = null;
      return;
    }
    if (!mounted || !_floatingArmed) return;
    await FloatingOverlay.arm(width: size.width, height: size.height);
  }

  /// The grant can arrive while the app is away (the system page) or after the
  /// page armed without it: re-run the arm decision.
  void _onFloatingWindowPermitted() {
    if (mounted) setState(() {});
  }

  /// The small window's size: the floating player's, for the picture's shape,
  /// kept inside [screen] the way the in-app window is.
  Size _floatingWindowSize(double ratio, FloatingWindowSettings floating, Size screen) {
    final portrait = ratio < 1;
    final base =
        kFloatingWindowBaseWidth *
        floatingWindowSizeFactor(floating.size) *
        (portrait ? floating.portraitScale : floating.landscapeScale);
    final maxWidth = math.min(screen.width - 16, math.max(220, (screen.height - 16) * ratio)).toDouble();
    final width = base.clamp(200, math.max(200, maxWidth)).toDouble();
    return Size(width, width / ratio);
  }

  double _floatingWindowRatio(RoomState room) {
    final detected = room.handle?.combinedSnapshot.geometry.aspectRatio ?? 0;
    return detected > 0 && detected.isFinite ? detected.clamp(kRoomFrameRatioMin, kRoomFrameRatioMax) : 16 / 9;
  }

  /// The frame's ratio: the room's own orientation choice when it made
  /// one, else the picture's width over height once the engine reports it,
  /// else the usual 16:9. A portrait stream keeps its tall shape instead of
  /// sitting letterboxed in a landscape box.
  /// The portrait full-screen surface: the same player filling the page. The
  /// picture fills it exactly as the 画面 setting says, and the flying layer
  /// keeps the one danmaku configuration.
  ///
  /// Two buttons used to float here at the top right, and the player's strip
  /// draws its back arrow, its danmaku switch, its presentation cluster and
  /// its ⋮ across the same band — the two rows stood on one another. Both
  /// verbs the row carried are on the strip already: the back arrow leaves the
  /// portrait full screen (`leave` answers that first) and 切换直播间 sits in
  /// the ⋮ beside it.
  Widget _buildPortraitFullscreen(BuildContext context, Widget player, {required bool canSwipeRooms}) {
    return ColoredBox(
      color: const Color(0xFF000000),
      child: Stack(
        children: [
          Positioned.fill(child: player),
          if (canSwipeRooms)
            const PositionedDirectional(
              start: DsSpace.s12,
              end: DsSpace.s12,
              bottom: 28,
              child: IgnorePointer(child: _PortraitSwipeHint()),
            ),
        ],
      ),
    );
  }

  double _pictureRatio(RoomState room) {
    final detected = room.handle?.combinedSnapshot.geometry.aspectRatio ?? 0;
    final ratio = detected <= 0 || !detected.isFinite ? 16 / 9 : detected;
    final key = room.room?.ref.identityKey;
    final orientation = key == null ? RoomOrientation.automatic : ref.watch(roomOrientationProvider(key));
    return roomFramedRatio(orientation, detected: ratio);
  }

  /// The portrait fullscreen's vertical swipe: +1 for the next room in the
  /// list the room was opened from, -1 for the previous. A room opened from
  /// no list swipes through the switcher's followed-on-air/history rooms.
  /// The new room opens on this page's controller, so the portrait surface
  /// and the player stay.
  void _switchPortraitRoom(int step) {
    if (_switchingPortraitRoom) return;
    final current = ref.read(roomProvider).room;
    if (current == null) return;
    final playlist = ref.read(roomPlaylistProvider);
    final fromSource = playlist != null && playlist.current.ref.identityKey == current.ref.identityKey;
    final target = fromSource ? playlist.neighbour(step) : _switcherSwipeTarget(current, step);
    if (target == null) return;
    _switchingPortraitRoom = true;
    _portraitSwipeTarget = target.ref.identityKey;
    _currentRoomKey = target.ref.identityKey;
    if (fromSource) ref.read(roomPlaylistProvider.notifier).move(step);
    unawaited(
      ref.read(roomProvider.notifier).open(platform: target.ref.platform, roomId: target.ref.roomId).whenComplete(() {
        if (mounted) _switchingPortraitRoom = false;
      }),
    );
  }

  /// The neighbour in the switcher's list when the room carries no source
  /// list; a current room absent from it starts from the first/last, as the
  /// switcher panel does.
  LiveRoom? _switcherSwipeTarget(LiveRoom current, int step) {
    final rooms = roomSwipeList(
      follows: ref.read(followsProvider).rooms,
      history: [for (final (room, _) in ref.read(historyProvider).records) room],
      current: current,
    );
    if (rooms.isEmpty) return null;
    final index = rooms.indexWhere((room) => room.ref.identityKey == current.ref.identityKey);
    if (index < 0) return step > 0 ? rooms.first : rooms.last;
    return rooms[(index + step) % rooms.length];
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
    // The theatre is the wide room's arrangement, and this route owns the
    // window, so the page's own width is the measure its layout will take.
    final wideWindow = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final theater = ref.watch(roomTheaterProvider);

    /// Shows or hides the theatre. Turning it on unfolds the chat: the glass
    /// column is what the mode exists for.
    void toggleTheater() {
      final shown = ref.read(roomTheaterProvider.notifier).toggle();
      if (shown && ref.read(chatCollapsedProvider)) {
        unawaited(ref.read(chatCollapsedProvider.notifier).set(value: false));
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

    /// The back arrow and Escape: leave the presentation mode while one
    /// holds the page, otherwise leave the room — where "leave" is the
    /// host's verb: a route pop in the app, a window close in a room window.
    void leave() {
      if (_portraitFullscreen) {
        _setPortraitFullscreen(false);
        return;
      }
      final player = room.handle?.id;
      if (ownsWindow && player != null) {
        unawaited(presentationController.exit(player));
      } else if (ref.read(roomLeaveProvider) case final closeWindow?) {
        // A room window's native close may take the view away before this
        // page's dispose runs; stop the room first so its sound cannot
        // outlive the window.
        unawaited(_roomNotifier.close());
        unawaited(closeWindow());
      } else if (context.canPop()) {
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
      unawaited(ref.read(roomProvider.notifier).setVolume(handle.volume + delta));
    }

    // The arrows take the wheel's step (the 画质与音频 setting); watching it
    // keeps the bindings honest after a change.
    final volumeStep = ref.watch(playbackSettingsProvider.select((settings) => settings.volumeWheelStepPercent)) / 100;

    // One table feeds the keys this page answers to and the `?` help sheet:
    // a line the sheet shows is a key that works. Its conditions are the
    // same ones the verbs run under — a TV remote keeps the arrows on focus,
    // a narrow window has no theatre, and a backend without a capture route
    // has no frame to save.
    final shortcuts = roomShortcutBindings(
      t,
      tv: tv,
      theater: wideWindow,
      canCaptureScreenshot: room.handle?.canCaptureScreenshot ?? false,
    );
    VoidCallback shortcutAction(RoomShortcutAction action) => switch (action) {
      RoomShortcutAction.playPause => () => unawaited(ref.read(roomProvider.notifier).togglePlayPause()),
      RoomShortcutAction.fullscreen => () {
        final player = room.handle?.id;
        if (player != null) unawaited(presentationController.toggleFullscreen(player));
      },
      RoomShortcutAction.leave => leave,
      RoomShortcutAction.volumeUp => () => nudgeVolume(volumeStep),
      RoomShortcutAction.volumeDown => () => nudgeVolume(-volumeStep),
      RoomShortcutAction.theater => toggleTheater,
      // The two verbs a viewer reaches for when a stream misbehaves: the
      // numbers behind it, and a frame of it.
      RoomShortcutAction.stats => () => ref.read(playerStatsVisibleProvider.notifier).toggle(),
      RoomShortcutAction.screenshot => () {
        final handle = ref.read(roomProvider).handle;
        if (handle == null || !handle.canCaptureScreenshot) return;
        unawaited(takeRoomScreenshot(context, ref, handle));
      },
      RoomShortcutAction.retry => () => unawaited(ref.read(roomProvider.notifier).retry()),
      RoomShortcutAction.help => () => unawaited(showRoomShortcuts(context, shortcuts)),
    };
    final keys = <SingleActivator, VoidCallback>{
      for (final binding in shortcuts)
        for (final activator in binding.keys) activator: shortcutAction(binding.action),
    };

    final pictureRatio = _pictureRatio(room);
    final portraitLayout = ref.watch(portraitLayoutModeProvider);
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

    /// The picture surface, with the theatre's chat handed in as a page layer
    /// when the layout has one: the surface draws its own bars and catalogues
    /// above that layer.
    Widget playerWith({Widget? overlay, double bottomInset = 0}) => PlayerSurface(
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
      // A TV's bars take their own tier: larger controls, wider gaps and a
      // focus ring, since the remote has no pointer and the viewer sits back.
      tv: tv,
      portraitFullscreen: _portraitFullscreen,
      canEnterPortraitFullscreen: pictureRatio < 1,
      onPortraitFullscreen: () => _setPortraitFullscreen(true),
      onPortraitSwipe: _portraitFullscreen && swipeSwitch && mobile ? _switchPortraitRoom : null,
      overlay: overlay,
      bottomInset: bottomInset,
      theater: theater,
      // A presentation mode that owns the window has no chat to float, and a
      // narrow page stacks it under the picture.
      onTheater: wideWindow && !ownsWindow && !_portraitFullscreen ? toggleTheater : null,
      roomMenu: roomMenuItems(context, ref, room, onClose: leave, shortcuts: shortcuts),
    );

    final body = _portraitFullscreen
        ? _buildPortraitFullscreen(context, playerWith(), canSwipeRooms: swipeSwitch && mobile)
        : LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= _wideBreakpoint;
              if (!wide) {
                // The reference's narrow room: the picture, the strip with the
                // room's facts, then the chat below it. The picture keeps its
                // shape but never takes the chat's last 150 px: a short window
                // shrinks it instead of overflowing the column.
                final maxPicture = math.max<double>(
                  0,
                  (constraints.maxHeight.isFinite ? constraints.maxHeight - 150 : 480).toDouble(),
                );
                final portraitStream = pictureRatio < 1;
                // The engine reports the picture's own ratio, so a portrait
                // source takes the tall panel unless the viewer chose the
                // regular 16:9 room page.
                final tallPortrait = portraitStream && portraitLayout != PortraitLayoutMode.compatibility;
                // The reference's narrow room for a portrait stream: the picture
                // fills the window and the room's facts and chat ride over it on
                // a sheet with three stops. A stream that is not portrait keeps
                // the stacked room, because a 16:9 frame stretched over a phone is
                // either cropped or a black band with a title on it.
                if (tallPortrait) {
                  return RoomBottomPanel(
                    // The immersive layout opens on the least picture covered;
                    // the balanced one opens where a chat is readable.
                    preferred: portraitLayout == PortraitLayoutMode.immersive
                        ? RoomPanelStop.minimum
                        : RoomPanelStop.middle,
                    onCoverChanged: _setPanelCover,
                    picture: ColoredBox(
                      color: kPlayerStageColor,
                      child: playerWith(bottomInset: _panelCover),
                    ),
                    // A thumb gets the way into the room's own full screen, which
                    // is what the bar's entry costs at this width — the bar hides
                    // it below its own floor. A pointer gets the grip that says
                    // the sheet holds.
                    handle: mobile
                        ? DsButton(
                            variant: DsButtonVariant.ghost,
                            size: DsSize.xs,
                            onPressed: () => _setPortraitFullscreen(true),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: DsSpace.s4,
                              children: [
                                const DsIcon(DsIcons.rectangleVertical, size: 14),
                                Text(t.room.portraitFullscreen),
                              ],
                            ),
                          )
                        : null,
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
                    panel: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _RoomHero(room: room),
                        // The sheet paints its own frosted surface; a second
                        // opaque one under it would hide the glass.
                        const Expanded(child: RoomChatPanel(translucent: true)),
                      ],
                    ),
                  );
                }
                final ratio = tallPortrait
                    ? pictureRatio.clamp(0.5, 0.8)
                    : portraitStream
                    ? 16 / 9
                    : pictureRatio < 1.0
                    ? 1.0
                    : pictureRatio;
                final desired = tallPortrait
                    ? constraints.maxHeight * (portraitLayout == PortraitLayoutMode.immersive ? 0.72 : 0.58)
                    // A 16:9 frame in a tall window is letterboxed, not stretched:
                    // three fifths of the height at most, so the chat under it keeps
                    // a readable count instead of one line and a button.
                    : math.min(constraints.maxWidth / ratio, constraints.maxHeight * 0.6);
                final picture = SizedBox(
                  height: math.min(desired, maxPicture),
                  child: ColoredBox(
                    color: kPlayerStageColor,
                    child: Center(
                      child: AspectRatio(aspectRatio: ratio, child: playerWith()),
                    ),
                  ),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    picture,
                    _RoomHero(room: room),
                    const Expanded(child: RoomChatPanel()),
                  ],
                );
              }
              // The reference's wide room: the picture centred in the stage at its
              // own shape, and the chat column with the strip above it. The
              // column can fold away; the choice is remembered for the next room.
              // Its width is the viewer's own (the 弹幕 setting) and the seam
              // between the two drags it.
              final maxChatWidth = math.max(
                kChatPanelWidthMin,
                math.min(kChatPanelWidthMax, constraints.maxWidth - _wideStageFloor),
              );
              final chatWidth = ref.watch(chatPanelWidthProvider).clamp(kChatPanelWidthMin, maxChatWidth);
              void toggleChat() {
                unawaited(ref.read(chatCollapsedProvider.notifier).set(value: !chatCollapsed));
              }

              if (theater) {
                // The theatre: the picture owns the stage and the chat floats
                // over its end edge as a glass column. The page hands that
                // layer to the surface, which draws its bars, its pickers and
                // the statistics above it.
                if (chatCollapsed) {
                  return Stack(
                    children: [
                      Positioned.fill(child: playerWith()),
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
                return playerWith(
                  overlay: PositionedDirectional(
                    top: _theaterTopInset,
                    bottom: _theaterBottomInset,
                    end: DsSpace.s12,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ChatSplitter(
                          width: chatWidth,
                          minWidth: kChatPanelWidthMin,
                          maxWidth: maxChatWidth,
                          onResize: (value) => ref.read(chatPanelWidthProvider.notifier).preview(value),
                          onResizeEnd: (value) => unawaited(ref.read(chatPanelWidthProvider.notifier).set(value)),
                          onReset: () =>
                              unawaited(ref.read(chatPanelWidthProvider.notifier).set(kChatPanelWidthDefault)),
                          label: t.room.resizeChat,
                          keyboard: !tv,
                          onDark: true,
                        ),
                        SizedBox(
                          width: chatWidth,
                          child: RoomGlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _RoomHero(room: room)),
                                    DsButton.icon(
                                      variant: DsButtonVariant.ghost,
                                      size: DsSize.sm,
                                      onPressed: toggleChat,
                                      icon: const DsIcon(DsIcons.panelRightClose),
                                      semanticLabel: t.room.collapseChat,
                                    ),
                                  ],
                                ),
                                const Expanded(child: RoomChatPanel(translucent: true)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // The picture sits in its own rounded box inset from the page,
              // the chat beside it in a card of the same corners: the page
              // reads as two panels on the canvas rather than a stage bleeding
              // to the edges.
              //
              // The stage — not the frame — is what the surface is given: the
              // player's own fit keeps the picture at the stream's shape inside
              // it, so the bars are part of the surface and its controls span
              // the stage's full width and height. Sizing the surface to the
              // ratio instead (the Center + AspectRatio this used to hold) left
              // the bars outside it, and every control, picker and corner button
              // with them: a wide stage read as a small player.
              final stageCorners = BorderRadius.circular(DsTheme.of(context).radii.card);
              Widget stageBox(Widget child) => ClipRRect(
                borderRadius: stageCorners,
                child: ColoredBox(color: kPlayerStageColor, child: child),
              );
              if (chatCollapsed) {
                return Padding(
                  padding: const EdgeInsets.all(DsSpace.s16),
                  child: Stack(
                    children: [
                      Positioned.fill(child: stageBox(playerWith())),
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
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: DsSpace.s16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(start: DsSpace.s16),
                        child: stageBox(playerWith()),
                      ),
                    ),
                    ChatSplitter(
                      width: chatWidth,
                      minWidth: kChatPanelWidthMin,
                      maxWidth: maxChatWidth,
                      onResize: (value) => ref.read(chatPanelWidthProvider.notifier).preview(value),
                      onResizeEnd: (value) => unawaited(ref.read(chatPanelWidthProvider.notifier).set(value)),
                      onReset: () => unawaited(ref.read(chatPanelWidthProvider.notifier).set(kChatPanelWidthDefault)),
                      label: t.room.resizeChat,
                      keyboard: !tv,
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: DsSpace.s16),
                      child: SizedBox(
                        width: chatWidth,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: stageCorners,
                            border: Border.all(color: colors.border),
                          ),
                          child: ClipRRect(
                            borderRadius: stageCorners,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _RoomHero(room: room)),
                                    Padding(
                                      padding: const EdgeInsets.all(DsSpace.s4),
                                      child: DsButton.icon(
                                        variant: DsButtonVariant.ghost,
                                        size: DsSize.sm,
                                        onPressed: toggleChat,
                                        icon: const DsIcon(DsIcons.panelRightClose),
                                        semanticLabel: t.room.collapseChat,
                                      ),
                                    ),
                                  ],
                                ),
                                const Expanded(child: RoomChatPanel()),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
    return withShortcuts(
      ColoredBox(
        color: kPlayerStageColor,
        child: ownsWindow
            ? Scaffold(backgroundColor: kPlayerStageColor, body: playerWith())
            : Scaffold(
                // The portrait full-screen surface is the page's own way of
                // filling the window: it keeps its black stage and drops the
                // app bar with it, so no header survives into the mode.
                backgroundColor: _portraitFullscreen ? kPlayerStageColor : colors.canvas,
                appBar: _portraitFullscreen
                    ? null
                    : _roomAppBar(context, colors: colors, ownChrome: ownChrome, shortcuts: shortcuts, leave: leave),
                body: _portraitFullscreen ? body : SafeArea(child: body),
              ),
      ),
    );
  }
}

/// The follows the room page reads (the follow button's watched list).
final followsRoomProvider = Provider<List<LiveRoom>>((ref) {
  ref.watch(followsProvider);
  return ref.read(followsProvider).rooms;
});

/// The app bar's own line: the room's title and where it plays. The
/// anchor's identity — the avatar, the live ring, the counts — lives on the
/// hero card under the picture; the bar keeps what it is the only surface
/// for while the page scrolls the picture away: which room, which platform.
/// The room page's app bar: the app's mark where the window is wide enough
/// to carry it beside the way back, the room as the caption (the title over
/// the platform and area, its icon leading), and at the end the follow, the
/// room's menu and — where the app draws its own caption — the window's
/// three buttons. On a desktop that draws its own caption the bar *is* the
/// caption: its header doubles as the drag band, so the page never stacks
/// two title bars.
PreferredSizeWidget _roomAppBar(
  BuildContext context, {
  required DsColors colors,
  required bool ownChrome,
  required List<RoomShortcutBinding> shortcuts,
  required VoidCallback leave,
}) {
  final t = context.t;
  final wide = LiveWindow.isExpanded(MediaQuery.sizeOf(context).width);
  // The bar grows on a wide window to carry the two-line title; the caption
  // buttons fill whatever height it has, so their hover reaches both edges.
  final height = wide ? 64.0 : kToolbarHeight;
  final leading = Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (wide) ...[
        const AppMark(size: 26),
        const SizedBox(width: DsSpace.s8),
        Text(t.common.appTitle, style: DsTheme.of(context).typography.bodyStrong.copyWith(color: colors.text)),
        const SizedBox(width: DsSpace.s12),
      ],
      DsButton.icon(
        variant: DsButtonVariant.secondary,
        size: DsSize.sm,
        onPressed: leave,
        icon: const DsIcon(DsIcons.chevronLeft, size: 20),
        semanticLabel: t.common.back,
      ),
    ],
  );
  return AppBar(
    backgroundColor: colors.surface,
    surfaceTintColor: const Color(0x00000000),
    elevation: 0,
    automaticallyImplyLeading: false,
    toolbarHeight: height,
    leadingWidth: wide ? 190 : 56,
    leading: Padding(
      padding: const EdgeInsetsDirectional.only(start: DsSpace.s12, end: DsSpace.s4),
      child: leading,
    ),
    titleSpacing: DsSpace.s8,
    // The whole middle band is the window's handle, not just the two lines of
    // text: a Column sized to its own words leaves the space beside them inert,
    // and a viewer reaching for "the title bar" grabs that space. The buttons
    // keep their own taps — the band only claims a drag.
    title: ownChrome
        ? const SizedBox(
            width: double.infinity,
            child: WindowDragArea(
              child: Align(alignment: AlignmentDirectional.centerStart, child: _RoomHeader()),
            ),
          )
        : const _RoomHeader(),
    actions: [
      const _FollowPill(),
      _RoomMenu(onClose: leave, shortcuts: shortcuts),
      if (ownChrome) ...[
        const SizedBox(width: DsSpace.s8),
        const SizedBox(height: 20, child: DsDivider.vertical()),
        WindowCaptionControls(height: height),
      ],
      const SizedBox(width: DsSpace.s4),
    ],
  );
}

/// The word shown on entering the portrait full screen: the one gesture there
/// cannot be seen. Swiping up or down over the picture's middle third moves to
/// the next or previous room in the list this one came from, and nothing else
/// on the surface says so — the ✕ and the switcher button both show
/// themselves.
///
/// It borrows the reference's shape (a pill above the bottom rows, gone after
/// three seconds) and keeps its honesty: it is drawn only where the swipe is
/// actually live, so it can never teach a gesture the settings turned off.
final class _PortraitSwipeHint extends StatefulWidget {
  const _PortraitSwipeHint();

  @override
  State<_PortraitSwipeHint> createState() => _PortraitSwipeHintState();
}

final class _PortraitSwipeHintState extends State<_PortraitSwipeHint> {
  static const Duration _visibleFor = Duration(seconds: 3);

  bool _visible = true;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _hide = Timer(_visibleFor, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The fade is the whole animation; with reduce-motion on, the pill is
    // simply gone when its seconds are up.
    final still = MediaQuery.disableAnimationsOf(context);
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: still ? Duration.zero : const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      child: Center(
        child: PlayerGlassPill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12, vertical: DsSpace.s6),
            child: Text(
              context.t.room.portraitSwipeHint,
              textAlign: TextAlign.center,
              style: DsTheme.of(context).typography.caption.copyWith(color: playerInk),
            ),
          ),
        ),
      ),
    );
  }
}

final class _RoomHeader extends ConsumerWidget {
  const _RoomHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final detail = ref.watch(roomProvider.select((room) => room.room));
    if (detail == null) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: DsSpace.s3,
        children: [DsSkeleton(width: 180, height: 15), DsSkeleton(width: 120, height: 12)],
      );
    }
    final site = ref.watch(sitesProvider).all.where((site) => site.manifest.id == detail.ref.platform).firstOrNull;
    final platform = site == null ? detail.ref.platform : localizedSiteName(site);
    final area = (detail.area?.areaName ?? '').trim();
    final icon = localizedSiteIcon(site, size: 14);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Text(
          detail.content.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.typography.title.copyWith(color: colors.text),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: DsSpace.s4,
          children: [
            ?icon,
            Flexible(
              child: Text(
                area.isEmpty ? platform : '$platform · $area',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption.copyWith(color: colors.textMuted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The follow action in the app bar: a labelled pill on a wide window, the
/// same pill on a phone (it gives way only if the header needs the room).
final class _FollowPill extends ConsumerWidget {
  const _FollowPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final detail = ref.watch(roomProvider.select((room) => room.room));
    if (detail == null) return const SizedBox.shrink();
    final followed = ref.watch(
      followsRoomProvider.select((follows) {
        final key = detail.ref.identityKey;
        return follows.any((followed_) => followed_.ref.identityKey == key);
      }),
    );
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: DsSpace.s8),
      child: DsButton(
        variant: followed ? DsButtonVariant.secondary : DsButtonVariant.primary,
        size: DsSize.sm,
        onPressed: () => unawaited(ref.read(roomProvider.notifier).toggleFollow()),
        leading: DsIcon(followed ? DsIcons.heart : DsIcons.heartCrack, size: theme.sizes.iconSm),
        child: Text(followed ? t.room.unfollow : t.room.follow),
      ),
    );
  }
}

/// The room's own actions, in one list.
///
/// The page header's ⋮ and the player's overlay ⋮ show the same menu: in
/// fullscreen there is no header, and a room action that disappeared with the
/// chrome would be a control the viewer has to leave fullscreen to reach.
List<Widget> roomMenuItems(
  BuildContext context,
  WidgetRef ref,
  RoomState room, {
  required VoidCallback onClose,
  required List<RoomShortcutBinding> shortcuts,
}) {
  final t = context.t;
  final detail = room.room;
  final link = detail == null ? '' : roomLinkOf(detail);
  final existing = detail == null
      ? null
      : ref
            .watch(recordingTasksProvider)
            .tasks
            .where((task) => task.id == '${detail.ref.platform}:${detail.ref.roomId}')
            .firstOrNull;
  final waiting = existing?.state == RecordingTaskState.waiting;
  final recording = existing?.state == RecordingTaskState.recording;
  // The follow verb's state, read the way the header's pill reads it: the menu
  // carries the same single switch, so the two can never disagree about whether
  // this room is followed.
  final followed =
      detail != null &&
      ref.watch(
        followsRoomProvider.select(
          (follows) => follows.any((candidate) => candidate.ref.identityKey == detail.ref.identityKey),
        ),
      );
  final pipOn = ref.watch(roomPresentationProvider) == PresentationMode.pip;
  // Whether this host can put the room in a window of its own: a desktop shell
  // that runs secondary windows, the viewer's rooms-in-windows habit left on,
  // and a page that is not itself one of those windows — raising the window the
  // room already lives in would be a verb that does nothing.
  final offersRoomWindow =
      ref.read(roomLeaveProvider) == null &&
      ref.watch(secondaryWindowsProvider) != null &&
      ref.watch(roomWindowsProvider) &&
      ref.read(platformRuntimeProvider).environment.runtime.formFactor == FormFactor.desktop;
  final sleepMinutes = ref.watch(sleepTimerProvider).minutes;
  final sleepRunning = sleepMinutes != null;
  final line = room.lines.isEmpty ? null : room.lines[room.lineIndex.clamp(0, room.lines.length - 1)];
  final external =
      detail != null &&
      ((detail.links.webUrl?.trim().isNotEmpty ?? false) || (detail.links.appUrl?.trim().isNotEmpty ?? false));
  // Four sections, each a kind of errand, so the list reads as a place to look
  // rather than a pile: the room and its facts; what the picture does (record,
  // small window, cast, framing, capture, the scheduled capture, the numbers on
  // the stream); keeping it running and passing it on; and finally the keys and
  // the way out. A section that has no eligible row disappears, and the
  // divider with it — two hairlines in a row read as a bug.
  final sections = <List<Widget>>[
    [
      DsMenuItem(
        leading: const DsIcon(DsIcons.info),
        label: Text(t.room.details),
        onPressed: () => unawaited(showRoomDetails(context)),
      ),
      if (detail != null)
        DsMenuItem(
          leading: const DsIcon(DsIcons.arrowLeftRight),
          label: Text(t.room.switchRoom),
          onPressed: () => unawaited(showRoomSwitcher(context, current: detail)),
        ),
      if (detail != null)
        DsMenuItem(
          leading: DsIcon(followed ? DsIcons.heart : DsIcons.heartCrack),
          label: Text(followed ? t.room.unfollow : t.room.follow),
          onPressed: () => unawaited(ref.read(roomProvider.notifier).toggleFollow()),
        ),
    ],
    [
      // The presentation verbs the strip carries, in the menu too: the narrow
      // tier leaves only the breathing dot on the picture, and a viewer who never
      // looks at the strip must still reach the capture, the small window and
      // the cast target.
      if (line != null || recording)
        DsMenuItem(
          leading: DsIcon(recording ? DsIcons.squareStop : DsIcons.disc),
          label: Text(recording ? t.room.stopRecording : t.room.record),
          onPressed: () => unawaited(toggleRoomRecording(context, ref)),
        ),
      if (room.handle != null && ref.read(roomPresentationProvider.notifier).pipAvailable)
        DsMenuItem(
          leading: const DsIcon(DsIcons.pictureInPicture),
          label: Text(pipOn ? t.room.pipOff : t.room.pipOn),
          onPressed: () => unawaited(toggleRoomPip(context, ref)),
        ),
      // The room in a window of its own: the desktop's way to watch two rooms
      // at once, and the list the room came from goes with it so the new
      // window's portrait swipe has the same neighbours. A room that already
      // has its window is raised to the front rather than opened twice.
      if (detail != null && offersRoomWindow)
        DsMenuItem(
          leading: const DsIcon(DsIcons.appWindow),
          label: Text(t.room.openInNewWindow),
          onPressed: () => unawaited(
            openRoom(
              context,
              platform: detail.ref.platform,
              roomId: detail.ref.roomId,
              playlist: ref.read(roomPlaylistProvider)?.rooms,
            ),
          ),
        ),
      if (line != null)
        DsMenuItem(
          leading: const DsIcon(DsIcons.cast),
          label: Text(t.room.cast),
          onPressed: () => unawaited(showCastDialog(context, line: line, title: detail?.content.title)),
        ),
      if (detail != null)
        DsMenuItem(
          leading: const DsIcon(DsIcons.rectangleVertical),
          label: Text(t.room.orientation),
          onPressed: () => unawaited(
            showRoomOrientationDialog(
              context,
              detail,
              detected: room.handle?.combinedSnapshot.geometry.aspectRatio ?? 0,
            ),
          ),
        ),
      // Only where a capture has a route: a backend without one would offer
      // a button that always answers "nothing".
      if (room.handle?.canCaptureScreenshot ?? false)
        DsMenuItem(
          leading: const DsIcon(DsIcons.camera),
          label: Text(t.room.screenshot),
          onPressed: () => unawaited(takeRoomScreenshot(context, ref, room.handle!)),
        ),
      if (detail != null && waiting)
        DsMenuItem(
          leading: const DsIcon(DsIcons.clock),
          label: Text(t.room.autoRecordOff),
          onPressed: () => unawaited(_toggleAutoRecord(context, ref, detail, existing)),
        )
      else if (detail != null && !detail.broadcast.isLiveNow && existing?.state != RecordingTaskState.recording)
        DsMenuItem(
          leading: const DsIcon(DsIcons.clock),
          label: Text(t.room.autoRecordOn),
          onPressed: () => unawaited(_toggleAutoRecord(context, ref, detail, existing)),
        ),
      // The chip that carries this sits in the page header, and the header is
      // gone the moment the picture owns the window — which is exactly when a
      // viewer is most likely to want the room to stop on its own.
      DsMenuItem(
        leading: DsIcon(sleepRunning ? DsIcons.timer : DsIcons.moon),
        label: Text(sleepRunning ? '${t.room.sleep} · ${asmrSleepDurationLabel(sleepMinutes)}' : t.room.sleep),
        onPressed: () => unawaited(showRoomSleepTimer(context, ref)),
      ),
      DsMenuItem(
        leading: const DsIcon(DsIcons.activity),
        label: Text(t.room.statsToggle),
        onPressed: () => ref.read(playerStatsVisibleProvider.notifier).toggle(),
      ),
      // The danmaku's look lives on the chat column's own tab, and the column
      // is gone the moment the picture owns the window — which is again when a
      // viewer most wants the lines smaller or the area taller. Same door the
      // tab opens, same words it uses.
      DsMenuItem(
        leading: const DsIcon(DsIcons.slidersHorizontal),
        label: Text(t.settings.navDanmaku),
        onPressed: () => unawaited(context.push(SettingsSectionRoute(section: SettingsSection.danmaku.name).location)),
      ),
    ],
    [
      DsMenuItem(
        leading: const DsIcon(DsIcons.refreshCw),
        label: Text(t.room.refreshRoom),
        onPressed: () => unawaited(ref.read(roomProvider.notifier).refreshRoom()),
      ),
      DsMenuItem(
        leading: const DsIcon(DsIcons.undo),
        label: Text(t.common.retry),
        onPressed: () => unawaited(ref.read(roomProvider.notifier).retry()),
      ),
      if (detail != null)
        DsMenuItem(
          leading: const DsIcon(DsIcons.share),
          label: Text(t.room.share),
          onPressed: () => unawaited(shareRoom(context, detail)),
        ),
      if (detail != null && external)
        DsMenuItem(
          leading: const DsIcon(DsIcons.externalLink),
          label: Text(t.room.openExternal),
          onPressed: () => unawaited(openRoomExternally(context, detail)),
        ),
      if (detail != null && link.isNotEmpty)
        DsMenuItem(
          leading: const DsIcon(DsIcons.link),
          label: Text(t.room.copyLink),
          onPressed: () => unawaited(copyRoomLink(context, detail)),
        ),
    ],
    [
      // The same sheet `?` opens. The binding table decides whether this room
      // has keys to explain at all (a TV remote has none).
      if (shortcuts.any((binding) => binding.action == RoomShortcutAction.help))
        DsMenuItem(
          leading: const DsIcon(DsIcons.keyboard),
          label: Text(t.room.shortcutsHelp),
          onPressed: () => unawaited(showRoomShortcuts(context, shortcuts)),
        ),
      DsMenuItem(leading: const DsIcon(DsIcons.x), label: Text(t.common.close), destructive: true, onPressed: onClose),
    ],
  ];
  final items = <Widget>[];
  for (final section in sections) {
    if (section.isEmpty) continue;
    if (items.isNotEmpty) items.add(const DsMenuDivider());
    items.addAll(section);
  }
  return items;
}

/// The room's overflow menu: its details, a light refresh, passing the room
/// on (share, the platform's own page, its link), a playback retry and the
/// way out. The player's own bar keeps the picture and stream actions.
final class _RoomMenu extends ConsumerWidget {
  const _RoomMenu({required this.onClose, required this.shortcuts});

  final VoidCallback onClose;
  final List<RoomShortcutBinding> shortcuts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final room = ref.watch(roomProvider);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: DsSpace.s8),
      child: DsMenuAnchor(
        semanticLabel: t.common.more,
        items: roomMenuItems(context, ref, room, onClose: onClose, shortcuts: shortcuts),
        builder: (context, controller, _) => DsButton.icon(
          variant: DsButtonVariant.ghost,
          size: DsSize.sm,
          semanticLabel: t.common.more,
          onPressed: controller.toggle,
          icon: const DsIcon(DsIcons.ellipsis),
        ),
      ),
    );
  }
}

/// Adds the room to the live check, or takes it out.
///
/// A waiting task is what the monitor polls; turning the check on here matches
/// the reference, where "Record when live" opens the live check as it adds the
/// room.
Future<void> _toggleAutoRecord(BuildContext context, WidgetRef ref, LiveRoom detail, RecordingTask? task) async {
  final t = context.t;
  final tasks = ref.read(recordingTasksProvider.notifier);
  if (task?.state == RecordingTaskState.waiting) {
    await tasks.remove(task!.id);
    if (!context.mounted) return;
    showDsToast(context: context, title: t.room.autoRecordRemoved, status: DsStatus.success);
    return;
  }
  if (!ref.read(recordingTasksProvider).ready) {
    showDsToast(context: context, title: t.room.autoRecordFailed, status: DsStatus.danger);
    return;
  }
  final settings = ref.read(recordingSettingsProvider);
  if (!settings.schedule.pollingEnabled) {
    ref.read(recordingSettingsProvider.notifier).pollingEnabled = true;
  }
  final now = DateTime.now().toUtc();
  final waiting = task == null
      ? RecordingTask(
          id: '${detail.ref.platform}:${detail.ref.roomId}',
          platform: detail.ref.platform,
          roomId: detail.ref.roomId,
          roomTitle: detail.content.title,
          quality: settings.defaultQuality,
          state: RecordingTaskState.waiting,
          startedAt: now,
        )
      : task.copyWith(
          roomTitle: detail.content.title,
          quality: settings.defaultQuality,
          state: RecordingTaskState.waiting,
          startedAt: now,
        );
  await tasks.add(waiting);
  if (!context.mounted) return;
  showDsToast(
    context: context,
    title: t.room.autoRecordArmed(seconds: settings.schedule.liveCheckSeconds),
    status: DsStatus.success,
  );
}

/// The room's own card, the reference's `RoomInfoBar` grown up: the
/// anchor's identity over a wash of the room's own cover — the avatar in a
/// live ring, the platform and the area, the live state, the audience and
/// the start time, the title — one press away from the details sheet.
///
/// It sits under the picture on a phone and at the head of the chat column
/// on a wide window, never over the picture itself.
final class _RoomHero extends ConsumerWidget {
  const _RoomHero({required this.room});

  final RoomState room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final detail = room.room;
    if (detail == null) {
      return Container(
        padding: const EdgeInsets.all(DsSpace.s12),
        decoration: DsBoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(theme.radii.card)),
        child: const Row(
          spacing: DsSpace.s12,
          children: [
            DsSkeleton(width: DsSpace.s32, height: DsSpace.s32),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: DsSpace.s3,
                children: [DsSkeleton(width: 96, height: 12), DsSkeleton(width: 160, height: 9)],
              ),
            ),
          ],
        ),
      );
    }
    final area = (detail.area?.areaName ?? '').trim();
    final anchor = (detail.anchor?.name ?? '').trim();
    final name = anchor.isEmpty ? detail.content.title : anchor;
    final avatar = (detail.anchor?.avatarUrl ?? detail.content.coverUrl).trim();
    final online = detail.audience.onlineViewers ?? detail.audience.totalViewers;
    final popularity = detail.audience.popularity;
    final started = detail.broadcast.startedAt;
    final live = detail.broadcast.isLiveNow;
    final caption = theme.typography.caption.copyWith(color: colors.textMuted);
    final numeric = theme.typography.numeric(caption);
    Widget metric(DsIconData icon, int value) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: DsSpace.s4,
      children: [
        DsIcon(icon, size: theme.sizes.iconXs, color: colors.textSubtle),
        Text(AudienceFormat.format(value), style: numeric),
      ],
    );
    // Three rows, the reference's own card: who is streaming (the avatar in
    // its live ring, the name, the live pill, the counts under it), a hair
    // line, then what is streaming (the title and the area) with how long
    // it has been on the air at the row's end. The whole card opens the
    // room's details.
    return DsPressable(
      semanticLabel: t.room.detailsHint,
      onPressed: () => unawaited(showRoomDetails(context)),
      builder: (context, states, child) => ColoredBox(
        color: states.contains(WidgetState.hovered) ? colors.hover : const Color(0x00000000),
        child: child,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(DsSpace.s16, DsSpace.s16, DsSpace.s12, DsSpace.s12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s12,
          children: [
            Row(
              spacing: DsSpace.s12,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: live ? colors.accent : colors.border),
                  child: DsAvatar(
                    initials: avatarInitials(name),
                    image: avatar.isEmpty ? null : cachedImage(avatar),
                    size: DsSize.lg,
                    semanticLabel: name,
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: DsSpace.s4,
                    children: [
                      Row(
                        spacing: DsSpace.s8,
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.title.copyWith(color: colors.text),
                            ),
                          ),
                          if (live) const _LiveBadge(),
                        ],
                      ),
                      // A platform that sends neither figure gets no row at
                      // all: an empty one still costs its spacing and reads as
                      // a hole under the name.
                      if (online != null || (popularity != null && popularity != online))
                        Row(
                          spacing: DsSpace.s12,
                          children: [
                            if (online != null) metric(DsIcons.eye, online),
                            if (popularity != null && popularity != online) metric(DsIcons.flame, popularity),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const DsDivider(),
            Row(
              spacing: DsSpace.s8,
              children: [
                DsIcon(DsIcons.messageSquare, size: theme.sizes.iconXs, color: colors.textSubtle),
                Expanded(
                  child: Text(
                    area.isEmpty ? detail.content.title : '${detail.content.title} · $area',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: caption,
                  ),
                ),
                if (live && started != null) _Elapsed(since: started, style: numeric),
                const _SleepChip(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// How long the room has been on the air, ticking once a second: the
/// reference's 「已直播 01:24:17」.
final class _Elapsed extends StatefulWidget {
  const _Elapsed({required this.since, required this.style});

  final DateTime since;
  final TextStyle style;

  @override
  State<_Elapsed> createState() => _ElapsedState();
}

final class _ElapsedState extends State<_Elapsed> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.since);
    if (elapsed.isNegative) return const SizedBox.shrink();
    String two(int value) => value.toString().padLeft(2, '0');
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60);
    final seconds = elapsed.inSeconds.remainder(60);
    return Text(context.t.room.onAirFor(time: '${two(hours)}:${two(minutes)}:${two(seconds)}'), style: widget.style);
  }
}

/// The live pill: the red dot and the word, over the hero's wash.
final class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final t = context.t;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.s6, vertical: 1),
      decoration: BoxDecoration(
        color: playerSignal.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(DsRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: DsSpace.s3,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: playerInk),
          ),
          Text(
            t.favorites.statusLiveNow,
            style: theme.typography.caption.copyWith(color: playerInk, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// The sleep timer's chip: off shows a moon that opens the picker; running
/// shows the countdown and the picker's first item stops it.
final class _SleepChip extends ConsumerWidget {
  const _SleepChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(sleepTimerProvider);
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final t = context.t;
    final running = timer.minutes != null;
    final label = running ? asmrSleepDurationLabel(timer.minutes!) : t.room.sleep;
    return DsMenuAnchor(
      semanticLabel: t.room.sleep,
      builder: (context, controller, child) => DsPressable(
        semanticLabel: t.room.sleep,
        onPressed: controller.toggle,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          return Container(
            height: theme.sizes.sm,
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8),
            decoration: DsBoxDecoration(
              color: running
                  ? theme.selectedFill
                  : hovered
                  ? colors.hover
                  : null,
              borderRadius: theme.radii.controlCorners(null, theme.sizes.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: DsSpace.s4,
              children: [
                DsIcon(
                  DsIcons.moon,
                  size: theme.sizes.iconSm,
                  color: running ? theme.onSelectedFill : colors.textMuted,
                ),
                Text(
                  label,
                  style: theme.typography.caption.copyWith(color: running ? theme.onSelectedFill : colors.textMuted),
                ),
              ],
            ),
          );
        },
      ),
      // The shared list, so the room's own menu and this chip can never offer
      // two different sets of minutes.
      items: roomSleepTimerChoices(context, ref),
    );
  }
}
