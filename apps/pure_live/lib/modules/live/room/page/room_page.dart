import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:math' as math;
import 'dart:ui' show ImageFilter, TileMode;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show AppBar, IconButton, Scaffold, kToolbarHeight;
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_device/live_device.dart'
    show PlatformScreenAwakeService, PlatformScreenOrientationService, ScreenAwakeService, ScreenOrientationService;
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:live_sites/live_sites.dart';
import 'package:media_core/media_core.dart' show PlayerId, PresentationMode;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/favorites/favorites.dart';
import 'package:pure_live/modules/live/history/history.dart';
import 'package:pure_live/modules/live/recorder/recorder.dart';
import 'package:pure_live/modules/live/room/chat/room_chat.dart' show RoomChatPanel;
import 'package:pure_live/modules/live/room/controller/room_controller.dart';
import 'package:pure_live/modules/live/room/page/player_surface.dart' show PlayerSurface, kPlayerStageColor;
import 'package:pure_live/modules/live/room/page/room_details.dart'
    show copyRoomLink, openRoomExternally, roomLinkOf, shareRoom, showRoomDetails;
import 'package:pure_live/modules/live/room/page/room_orientation.dart'
    show RoomOrientation, roomFrameRatio, roomOrientationProvider, showRoomOrientationDialog;
import 'package:pure_live/modules/live/room/page/room_refresh_rate.dart' show roomRefreshRateProvider;
import 'package:pure_live/modules/live/room/page/room_status.dart' show roomSlowProvider, slowAfter;
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
/// picture and its facts take the left and the chat a 300–400 px column on
/// the right; narrower windows stack the chat under the picture. Fullscreen,
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
      policy: ref.read(portraitSettingsProvider).fullscreenPolicy,
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
    return detected > 0 && detected.isFinite ? detected.clamp(0.5, 2.4) : 16 / 9;
  }

  /// The frame's ratio: the room's own orientation choice when it made
  /// one, else the picture's width over height once the engine reports it,
  /// else the usual 16:9. A portrait stream keeps its tall shape instead of
  /// sitting letterboxed in a landscape box.
  /// The portrait full-screen surface: the same player filling the page,
  /// with compact controls for the picture mode, the danmaku area and the
  /// optional diagnostics line.
  Widget _buildPortraitFullscreen(
    BuildContext context,
    RoomState room,
    PortraitFullscreenState state,
    Widget player,
    String roomKey,
  ) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final controller = ref.read(portraitFullscreenProvider.notifier);
    final choice = state.modeFor(roomKey);
    final geometry = room.handle?.combinedSnapshot.geometry;
    final displayLabel = switch (choice.display) {
      PortraitFullscreenMode.complete => t.room.portraitDisplayComplete,
      PortraitFullscreenMode.ambient => t.room.portraitDisplayAmbient,
      PortraitFullscreenMode.balanced => t.room.portraitDisplayBalanced,
      PortraitFullscreenMode.cover => t.room.portraitDisplayCover,
    };
    final danmakuLabel = switch (choice.danmaku) {
      PortraitDanmakuMode.followGlobal => t.room.portraitDanmakuFollow,
      PortraitDanmakuMode.upperQuarter => t.room.portraitDanmakuUpper,
      PortraitDanmakuMode.reduced => t.room.portraitDanmakuReduced,
      PortraitDanmakuMode.hidden => t.room.portraitDanmakuHidden,
    };
    void choose({PortraitFullscreenMode? display, PortraitDanmakuMode? danmaku}) {
      unawaited(controller.remember(roomKey, (display: display ?? choice.display, danmaku: danmaku ?? choice.danmaku)));
    }

    return ColoredBox(
      color: const Color(0xFF000000),
      child: Stack(
        children: [
          Positioned.fill(child: player),
          PositionedDirectional(
            start: 8,
            end: 8,
            top: 8,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      spacing: DsSpace.s8,
                      children: [
                        _PortraitChoiceBar<PortraitFullscreenMode>(
                          label: t.room.portraitFullscreenDisplay,
                          value: choice.display,
                          options: [
                            DsChipOption(
                              value: PortraitFullscreenMode.complete,
                              label: Text(t.room.portraitDisplayComplete),
                            ),
                            DsChipOption(
                              value: PortraitFullscreenMode.ambient,
                              label: Text(t.room.portraitDisplayAmbient),
                            ),
                            DsChipOption(
                              value: PortraitFullscreenMode.balanced,
                              label: Text(t.room.portraitDisplayBalanced),
                            ),
                            DsChipOption(value: PortraitFullscreenMode.cover, label: Text(t.room.portraitDisplayCover)),
                          ],
                          onChanged: (value) => choose(display: value),
                        ),
                        _PortraitChoiceBar<PortraitDanmakuMode>(
                          label: t.room.portraitDanmakuTitle,
                          value: choice.danmaku,
                          options: [
                            DsChipOption(
                              value: PortraitDanmakuMode.followGlobal,
                              label: Text(t.room.portraitDanmakuFollow),
                            ),
                            DsChipOption(
                              value: PortraitDanmakuMode.upperQuarter,
                              label: Text(t.room.portraitDanmakuUpper),
                            ),
                            DsChipOption(
                              value: PortraitDanmakuMode.reduced,
                              label: Text(t.room.portraitDanmakuReduced),
                            ),
                            DsChipOption(value: PortraitDanmakuMode.hidden, label: Text(t.room.portraitDanmakuHidden)),
                          ],
                          onChanged: (value) => choose(danmaku: value),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: DsSpace.s8),
                if (room.room case final detail?)
                  DsButton.icon(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    onPressed: () => unawaited(showRoomSwitcher(context, current: detail)),
                    icon: const DsIcon(DsIcons.arrowLeftRight),
                    semanticLabel: t.room.switchRoom,
                  ),
                if (room.room != null) const SizedBox(width: DsSpace.s8),
                DsButton.icon(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: () => _setPortraitFullscreen(false),
                  icon: const DsIcon(DsIcons.x),
                  semanticLabel: t.room.portraitFullscreenExit,
                ),
              ],
            ),
          ),
          if (state.diagnostics)
            PositionedDirectional(
              start: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s4),
                decoration: BoxDecoration(
                  color: const Color(0xB3000000),
                  borderRadius: BorderRadius.circular(theme.radii.card),
                ),
                child: Text(
                  '${geometry?.videoSize?.width ?? 0}×${geometry?.videoSize?.height ?? 0}'
                  ' · ${(geometry?.aspectRatio ?? 0).toStringAsFixed(2)}'
                  ' · $displayLabel / $danmakuLabel',
                  style: theme.typography.caption.copyWith(color: const Color(0xFFFFFFFF)),
                ),
              ),
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
    return roomFrameRatio(orientation, detected: ratio).clamp(0.5, 2.4);
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

    final keys = <SingleActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyF): () {
        final player = room.handle?.id;
        if (player != null) unawaited(presentationController.toggleFullscreen(player));
      },
      const SingleActivator(LogicalKeyboardKey.escape): leave,
      const SingleActivator(LogicalKeyboardKey.space): () =>
          unawaited(ref.read(roomProvider.notifier).togglePlayPause()),
      if (!tv) const SingleActivator(LogicalKeyboardKey.arrowUp): () => nudgeVolume(volumeStep),
      if (!tv) const SingleActivator(LogicalKeyboardKey.arrowDown): () => nudgeVolume(-volumeStep),
      const SingleActivator(LogicalKeyboardKey.keyR): () => unawaited(ref.read(roomProvider.notifier).retry()),
    };

    final pictureRatio = _pictureRatio(room);
    final portraitSettings = ref.watch(portraitSettingsProvider);
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
    final portraitState = ref.watch(portraitFullscreenProvider);
    final chatCollapsed = ref.watch(playbackSettingsProvider.select((settings) => settings.chatCollapsed));
    final portraitChoice = portraitState.modeFor(roomKey);
    final player = PlayerSurface(
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
      portraitFullscreen: _portraitFullscreen,
      portraitDisplay: portraitChoice.display,
      portraitDanmaku: portraitChoice.danmaku,
      canEnterPortraitFullscreen: pictureRatio < 1,
      onPortraitFullscreen: () => _setPortraitFullscreen(true),
      onPortraitSwipe: _portraitFullscreen && swipeSwitch && mobile ? _switchPortraitRoom : null,
    );

    final body = _portraitFullscreen
        ? _buildPortraitFullscreen(context, room, portraitState, player, roomKey)
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
                // The reference's portrait panel needs detection, the adaptive
                // height and a layout other than "compatibility 16:9"; without
                // them a portrait source uses the regular 16:9 room page.
                final tallPortrait =
                    portraitStream &&
                    portraitSettings.adaptation &&
                    portraitSettings.adaptiveHeight &&
                    portraitSettings.layoutMode != PortraitLayoutMode.compatibility;
                final ratio = tallPortrait
                    ? pictureRatio.clamp(0.5, 0.8)
                    : portraitStream
                    ? 16 / 9
                    : pictureRatio.clamp(1.0, 2.4);
                final desired = tallPortrait
                    ? constraints.maxHeight *
                          (portraitSettings.layoutMode == PortraitLayoutMode.immersive ? 0.72 : 0.58)
                    : constraints.maxWidth / ratio;
                final picture = SizedBox(
                  height: math.min(desired, maxPicture),
                  child: ColoredBox(
                    color: kPlayerStageColor,
                    child: Center(
                      child: AspectRatio(aspectRatio: ratio, child: player),
                    ),
                  ),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    picture,
                    Padding(
                      padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s12, DsSpace.s12, 0),
                      child: _RoomHero(room: room),
                    ),
                    const Expanded(child: RoomChatPanel()),
                  ],
                );
              }
              // The reference's wide room: the picture centred in the stage at its
              // own shape, and the chat column with the strip above it. The
              // column can fold away; the choice is remembered for the next room.
              // Its width is the viewer's own (the 弹幕 setting).
              final chatWidth = ref.watch(chatPanelWidthProvider);
              void toggleChat() {
                unawaited(ref.read(playbackSettingsProvider.notifier).setChatCollapsed(value: !chatCollapsed));
              }

              final stage = Expanded(
                child: ColoredBox(
                  color: kPlayerStageColor,
                  child: Center(
                    child: AspectRatio(aspectRatio: pictureRatio, child: player),
                  ),
                ),
              );
              if (chatCollapsed) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(
                        color: kPlayerStageColor,
                        child: Center(
                          child: AspectRatio(aspectRatio: pictureRatio, child: player),
                        ),
                      ),
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
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  stage,
                  const DsDivider.vertical(),
                  SizedBox(
                    width: chatWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s12, DsSpace.s12, 0, DsSpace.s4),
                                child: _RoomHero(room: room),
                              ),
                            ),
                            DsButton.icon(
                              variant: DsButtonVariant.ghost,
                              size: DsSize.sm,
                              onPressed: toggleChat,
                              icon: const DsIcon(DsIcons.panelRightClose),
                              semanticLabel: t.room.collapseChat,
                            ),
                          ],
                        ),
                        const Expanded(child: RoomChatPanel()),
                      ],
                    ),
                  ),
                ],
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
            ? Scaffold(backgroundColor: kPlayerStageColor, body: player)
            : Scaffold(
                // The portrait full-screen surface is the page's own way of
                // filling the window: it keeps its black stage and drops the
                // app bar with it, so no header survives into the mode.
                backgroundColor: _portraitFullscreen ? kPlayerStageColor : colors.surface,
                appBar: _portraitFullscreen
                    ? null
                    : AppBar(
                        backgroundColor: colors.surface,
                        surfaceTintColor: const Color(0x00000000),
                        elevation: 0,
                        automaticallyImplyLeading: false,
                        leadingWidth: 52,
                        leading: IconButton(
                          tooltip: t.common.back,
                          onPressed: leave,
                          icon: DsIcon(DsIcons.chevronLeft, size: 20, color: colors.text),
                        ),
                        titleSpacing: 0,
                        // On a desktop where the app draws the window's own caption
                        // this bar is the caption: the header doubles as the drag
                        // band and the three buttons close the window here, so the
                        // page never stacks two title bars.
                        title: ownChrome ? WindowDragArea(child: _RoomHeader(room: room)) : _RoomHeader(room: room),
                        actions: [
                          _FollowPill(room: room),
                          _RoomMenu(room: room, onClose: leave),
                          if (ownChrome) ...[
                            const SizedBox(width: DsSpace.s8),
                            const SizedBox(height: 20, child: DsDivider.vertical()),
                            const WindowCaptionControls(height: kToolbarHeight),
                          ],
                          const SizedBox(width: DsSpace.s4),
                        ],
                      ),
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
final class _RoomHeader extends ConsumerWidget {
  const _RoomHeader({required this.room});

  final RoomState room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final detail = room.room;
    if (detail == null) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: DsSpace.s3,
        children: [DsSkeleton(width: 132, height: 12), DsSkeleton(width: 96, height: 9)],
      );
    }
    final site = ref.watch(sitesProvider).all.where((site) => site.manifest.id == detail.ref.platform).firstOrNull;
    final platform = site == null ? detail.ref.platform : localizedSiteName(site);
    final area = (detail.area?.areaName ?? '').trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 1,
      children: [
        Text(
          detail.content.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
        ),
        Text(
          area.isEmpty ? platform : '$platform · $area',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.typography.caption.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }
}

/// The follow action in the app bar: a labelled pill on a wide window, the
/// same pill on a phone (it gives way only if the header needs the room).
final class _FollowPill extends ConsumerWidget {
  const _FollowPill({required this.room});

  final RoomState room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final detail = room.room;
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

/// The room's overflow menu: its details, a light refresh, passing the room
/// on (share, the platform's own page, its link), a playback retry and the
/// way out. The player's own bar keeps the picture and stream actions.
final class _RoomMenu extends ConsumerWidget {
  const _RoomMenu({required this.room, required this.onClose});

  final RoomState room;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final external =
        detail != null &&
        ((detail.links.webUrl?.trim().isNotEmpty ?? false) || (detail.links.appUrl?.trim().isNotEmpty ?? false));
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: DsSpace.s8),
      child: DsMenuAnchor(
        semanticLabel: t.common.more,
        items: [
          if (detail != null)
            DsMenuItem(
              leading: const DsIcon(DsIcons.arrowLeftRight),
              label: Text(t.room.switchRoom),
              onPressed: () => unawaited(showRoomSwitcher(context, current: detail)),
            ),
          DsMenuItem(
            leading: const DsIcon(DsIcons.info),
            label: Text(t.room.details),
            onPressed: () => unawaited(showRoomDetails(context)),
          ),
          if (detail != null)
            DsMenuItem(
              leading: const DsIcon(DsIcons.rectangleVertical),
              label: Text(t.room.orientation),
              onPressed: () => unawaited(showRoomOrientationDialog(context, detail)),
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
          DsMenuItem(
            leading: const DsIcon(DsIcons.refreshCw),
            label: Text(t.room.refreshRoom),
            onPressed: () => unawaited(ref.read(roomProvider.notifier).refreshRoom()),
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
          const DsMenuDivider(),
          DsMenuItem(
            leading: const DsIcon(DsIcons.undo),
            label: Text(t.common.retry),
            onPressed: () => unawaited(ref.read(roomProvider.notifier).retry()),
          ),
          DsMenuItem(
            leading: const DsIcon(DsIcons.x),
            label: Text(t.common.close),
            destructive: true,
            onPressed: onClose,
          ),
        ],
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

  /// Adds the room to the live check, or takes it out. A waiting task is
  /// what the monitor polls; turning the check on here matches the
  /// reference, where "Record when live" opens the live check as it adds
  /// the room.
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
    if (!settings.pollingEnabled) {
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
      title: t.room.autoRecordArmed(seconds: settings.liveCheckSeconds),
      status: DsStatus.success,
    );
  }
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
    final site = ref.watch(sitesProvider).all.where((site) => site.manifest.id == detail.ref.platform).firstOrNull;
    final platform = site == null ? detail.ref.platform : localizedSiteName(site);
    final area = (detail.area?.areaName ?? '').trim();
    final anchor = (detail.anchor?.name ?? '').trim();
    final name = anchor.isEmpty ? detail.content.title : anchor;
    final avatar = (detail.anchor?.avatarUrl ?? detail.content.coverUrl).trim();
    final cover = detail.content.coverUrl.trim();
    final audience = detail.audience.onlineViewers ?? detail.audience.popularity ?? detail.audience.totalViewers;
    final started = detail.broadcast.startedAt;
    final live = detail.broadcast.isLiveNow;
    return DsPressable(
      semanticLabel: t.room.detailsHint,
      onPressed: () => unawaited(showRoomDetails(context)),
      builder: (context, states, child) => ColoredBox(
        color: states.contains(WidgetState.hovered) ? colors.overlay : const Color(0x00000000),
        child: child,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(theme.radii.card),
        child: Stack(
          children: [
            Positioned.fill(child: _HeroWash(cover: cover)),
            Padding(
              padding: const EdgeInsets.all(DsSpace.s12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: DsSpace.s8,
                children: [
                  Row(
                    spacing: DsSpace.s12,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: live ? colors.accent : colors.border),
                        child: DsAvatar(
                          initials: name,
                          image: avatar.isEmpty ? null : cachedImage(avatar),
                          size: DsSize.md,
                          semanticLabel: name,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: DsSpace.s3,
                          children: [
                            Row(
                              spacing: DsSpace.s8,
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.typography.bodyStrong.copyWith(color: colors.text),
                                  ),
                                ),
                                if (live) const _LiveBadge(),
                              ],
                            ),
                            Row(
                              spacing: DsSpace.s8,
                              children: [
                                Flexible(
                                  child: Text(
                                    area.isEmpty ? platform : '$platform · $area',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.typography.caption.copyWith(color: colors.textMuted),
                                  ),
                                ),
                                const Spacer(),
                                if (audience != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    spacing: DsSpace.s3,
                                    children: [
                                      DsIcon(DsIcons.eye, size: theme.sizes.iconXs, color: colors.textSubtle),
                                      Text(
                                        AudienceFormat.format(audience),
                                        style: theme.typography.numeric(
                                          theme.typography.caption.copyWith(color: colors.textMuted),
                                        ),
                                      ),
                                    ],
                                  ),
                                if (started != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    spacing: DsSpace.s3,
                                    children: [
                                      DsIcon(DsIcons.clock, size: theme.sizes.iconXs, color: colors.textSubtle),
                                      Text(
                                        _clock(started),
                                        style: theme.typography.numeric(
                                          theme.typography.caption.copyWith(color: colors.textMuted),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    spacing: DsSpace.s4,
                    children: [
                      Expanded(
                        child: Text(
                          detail.content.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.body.copyWith(color: colors.text),
                        ),
                      ),
                      DsIcon(DsIcons.chevronDown, size: theme.sizes.iconXs, color: colors.textSubtle),
                      const _SleepChip(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _clock(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }
}

/// The card's backdrop: the room's own cover, blurred flat and quieted under
/// the surface's ink, so the card carries the room's colour without fighting
/// the words over it. A room without a cover gets the plain surface.
final class _HeroWash extends StatelessWidget {
  const _HeroWash({required this.cover});

  final String cover;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    if (cover.isEmpty) return ColoredBox(color: colors.surface);
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28, tileMode: TileMode.decal),
          child: Image(image: cachedImage(cover), fit: BoxFit.cover),
        ),
        ColoredBox(color: colors.surface.withValues(alpha: 0.82)),
      ],
    );
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
      decoration: BoxDecoration(color: const Color(0xE6FF3B5C), borderRadius: BorderRadius.circular(DsRadii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: DsSpace.s3,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFFFFF)),
          ),
          Text(
            t.favorites.statusLiveNow,
            style: theme.typography.caption.copyWith(color: const Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
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
      items: [
        if (running)
          DsMenuItem(label: Text(t.room.sleepOff), onPressed: () => ref.read(sleepTimerProvider.notifier).start(null)),
        // The settings page's own duration presets, read through the shared
        // list: one set of choices, one wording.
        for (final minutes in kAsmrSleepMinuteChoices)
          DsMenuItem(
            label: Text(asmrSleepDurationLabel(minutes)),
            onPressed: () => ref.read(sleepTimerProvider.notifier).start(minutes),
          ),
      ],
    );
  }
}

/// A labelled, horizontally scrollable chip group used by the portrait
/// full-screen chrome.
final class _PortraitChoiceBar<T> extends StatelessWidget {
  const _PortraitChoiceBar({required this.label, required this.value, required this.options, required this.onChanged});

  final String label;
  final T value;
  final List<DsChipOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s4),
      decoration: BoxDecoration(color: const Color(0xB3000000), borderRadius: BorderRadius.circular(theme.radii.card)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: DsSpace.s8,
        children: [
          Text(label, style: theme.typography.caption.copyWith(color: colors.textSubtle)),
          DsChoiceChips<T>(value: value, onChanged: onChanged, semanticLabel: label, options: options),
        ],
      ),
    );
  }
}
