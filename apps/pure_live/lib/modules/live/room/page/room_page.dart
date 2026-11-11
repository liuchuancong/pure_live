import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show AppBar, Scaffold;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
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
import 'package:pure_live/modules/live/room/chat/room_chat.dart' show RoomChatPanel;
import 'package:pure_live/modules/live/room/controller/room_controller.dart';
import 'package:pure_live/modules/live/room/page/player_surface.dart'
    show PlayerSurface, kPlayerStageColor, toggleRoomPip;
import 'package:pure_live/modules/live/room/page/room_bottom_panel.dart';
import 'package:pure_live/modules/live/room/page/room_follow.dart' show toggleRoomFollow;
import 'package:pure_live/modules/live/room/page/room_frame.dart' show kRoomFrameRatioMax, kRoomFrameRatioMin;
import 'package:pure_live/modules/live/room/page/room_glass_card.dart';
import 'package:pure_live/modules/live/room/page/room_refresh_rate.dart' show roomRefreshRateProvider;
import 'package:pure_live/modules/live/room/page/room_screenshot.dart' show takeRoomScreenshot;
import 'package:pure_live/modules/live/room/page/room_shortcuts.dart'
    show RoomShortcutAction, RoomShortcutBinding, roomShortcutBindings, showRoomShortcuts;
import 'package:pure_live/modules/live/room/page/room_status.dart' show roomSlowProvider, slowAfter;
import 'package:pure_live/modules/live/room/panels/room_panel.dart'
    show
        RoomPanelController,
        RoomPanelKind,
        RoomPanelScope,
        isRoomPanelRoute,
        roomPanelRouteName,
        roomPanelSheet,
        showRoomDetails,
        showRoomSleepTimer;
import 'package:pure_live/modules/live/room/player/floating_room_player.dart' show FloatingRoomPlayer;
import 'package:pure_live/modules/live/room/player/room_playlist.dart'
    show RoomPlaylistController, roomPlaylistProvider;
import 'package:pure_live/modules/live/room/player/room_switcher.dart' show roomSwipeList, showRoomSwitcher;
import 'package:pure_live/modules/live/room/player/sleep_timer.dart';
import 'package:pure_live/shared/navigation/room_seed.dart' show takeRoomSeed;
import 'package:pure_live/shared/shared.dart';

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

/// The width the room's wide arrangements start at; the chat column's
/// toggle and the `T` key answer to the same measure.
const double kRoomWideBreakpoint = 840;

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
  static const double _wideBreakpoint = kRoomWideBreakpoint;

  /// Windows shorter than this are a phone held sideways, whatever their width
  /// (the reference's compact height, which wins over its wide breakpoint):
  /// stacked, the chat would get a strip under a letterbox; split as on a
  /// desktop, the column's card would leave it one line.
  static const double _phoneLandscapeMaxHeight = 480;

  /// The chat's column beside the picture on a phone held sideways (the
  /// reference's `phoneLandscapeChatWidth`): the list alone, at the width a
  /// line of talk still reads at without taking the picture's share.
  static const double _phoneLandscapeChatWidth = 280;

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
            _enterFullscreen();
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
    _panels.removeListener(_onRoomPanelChanged);
    _panels.dispose();
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

  /// Runs a provider write this leaving page may not make in place.
  ///
  /// The route unmounts while the tree is being torn down, and Riverpod
  /// rejects a notification in that phase — it left the page half unmounted
  /// with the route transition reading a dead element. The write therefore
  /// rides the end of the frame, and it goes through a notifier captured
  /// while this page still existed, never through its own `ref`.
  void _writeAfterFrame(void Function() write) => unawaited(Future<void>.delayed(Duration.zero, write));

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
      color: OnVideoColors.ground,
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

  /// A phone held sideways, outside fullscreen (the reference's `landscape`
  /// layout, its choice A): the picture takes the whole height under the app
  /// bar and the chat's list alone a 280 px column beside it.
  ///
  /// The room's card has no column to sit in here — at the head of the list it
  /// left one line of talk on a phone's short side — so its name folds into the
  /// picture's strip, which opens the details the card would ([player] is built
  /// with that press). The quality and the line stay on the bar under the
  /// picture, where every layout keeps them. The list is the chat panel's own,
  /// drawn without its tabs and composer, so it reads the room's one feed; the
  /// picture is the one surface every layout reparents, so turning the phone
  /// moves it rather than rebuilding it.
  Widget _buildPhoneLandscape(Widget player) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ColoredBox(color: kPlayerStageColor, child: player),
        ),
        const DsDivider.vertical(),
        const SizedBox(width: _phoneLandscapeChatWidth, child: RoomChatPanel(feedOnly: true)),
      ],
    );
  }

  /// The picture's frame, from the engine's own geometry: the stream reports
  /// its shape, so the room no longer keeps a per-room manual orientation to
  /// fight it. The clamp keeps an absurd report from taking the whole stage.
  double _pictureRatio(RoomState room) {
    final detected = room.handle?.combinedSnapshot.geometry.aspectRatio ?? 0;
    final ratio = detected <= 0 || !detected.isFinite ? 16 / 9 : detected;
    return ratio.clamp(kRoomFrameRatioMin, kRoomFrameRatioMax);
  }

  /// The portrait fullscreen's vertical swipe: +1 for the next room in the
  /// list the room was opened from, -1 for the previous. A room opened from
  /// no list swipes through the switcher's followed-on-air/history rooms.
  /// The new room opens on this page's controller, so the portrait surface
  /// and the player stay.
  void _switchRoomByStep(int step) {
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
    // The switch names itself: a remote's Up or Down leaves no trail on the
    // picture, and the viewer needs to know whose room just came up — the
    // anchor when the list carried one, the title always.
    final nick = target.anchor?.name ?? '';
    final title = target.content.title;
    final named = [nick, title].where((part) => part.isNotEmpty).join(' · ');
    if (named.isNotEmpty) ref.read(roomHintProvider.notifier).show(named);
    unawaited(
      ref
          .read(roomProvider.notifier)
          .open(platform: target.ref.platform, roomId: target.ref.roomId, known: target)
          .whenComplete(() {
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

  /// The panel state moved: sweep whatever panel route is up, then show
  /// the wanted one (or nothing). A close routes through here too, so the
  /// page's bookkeeping and the stack agree.
  void _onRoomPanelChanged() {
    final kind = _panels.value;
    if (kind == _openPanelKind) return;
    _rootNav?.popUntil((route) => !isRoomPanelRoute(route));
    _openPanelKind = kind;
    if (kind == null) return;
    unawaited(_showRoomPanel(kind));
  }

  Future<void> _showRoomPanel(RoomPanelKind kind) async {
    await showDsPanel<void>(
      context: context,
      routeSettings: RouteSettings(name: roomPanelRouteName(kind)),
      builder: (sheetContext) => roomPanelSheet(sheetContext, kind),
    );
    if (!mounted) return;
    // The sheet went away for good (its own close, the scrim, back): the
    // controller follows, quietly — a replaced panel has already been
    // swept by the open that displaced it.
    if (_panels.value == kind) {
      _openPanelKind = null;
      _panels.close();
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
    // A phone or tablet held sideways in a short window takes the landscape
    // arrangement before any width is asked: the reference's compact height
    // wins over its wide breakpoint, so a sideways phone never gets the
    // desktop split or the stacked column. A desktop window
    // as short keeps the layout its width gives it. The window's shape decides,
    // not the stream's: a portrait source sideways is still a short window.
    final landscapePhone =
        mobile &&
        windowSize.height < _phoneLandscapeMaxHeight &&
        windowSize.width > windowSize.height &&
        windowSize.width >= LiveWindow.compact;
    final wideWindow = !landscapePhone && windowSize.width >= _wideBreakpoint;

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
      RoomShortcutAction.fullscreen => () {
        final player = room.handle?.id;
        if (player != null) unawaited(presentationController.toggleFullscreen(player));
      },
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
    Widget playerWith({
      Widget? overlay,
      double bottomInset = 0,
      double controlBarEndInset = 0,
      VoidCallback? onTitle,
      double topBarEndInset = DsSpace.s12,
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
      portraitFullscreen: _portraitFullscreen,
      canEnterPortraitFullscreen: pictureRatio < 1,
      onPortraitFullscreen: () => _setPortraitFullscreen(true),
      onPortraitSwipe: _portraitFullscreen && swipeSwitch && mobile ? _switchRoomByStep : null,
      // The swipe up from the portrait full screen's bottom band, back to the
      // panel: a touch screen's gesture, where the surface is the whole of it.
      onPortraitRestore: _portraitFullscreen && mobile ? () => _setPortraitFullscreen(false) : null,
      onTitle: onTitle,
      // The room's own framing, not only the source's: a portrait frame the
      // viewer chose sits over the room's art too, a landscape one keeps the
      // stage's black — except on the portrait full screen, where a landscape
      // room swiped to sits over the art as the reference draws it.
      ambient: pictureRatio < 1 || _portraitFullscreen,
      overlay: overlay,
      bottomInset: bottomInset,
      controlBarEndInset: controlBarEndInset,
      // A presentation mode that owns the window has no chat to float, and a
      // narrow page stacks it under the picture.
      roomMenu: roomMenuItems(context, ref, room, shortcuts: shortcuts),
      topBarEndInset: topBarEndInset,
    );

    final body = _portraitFullscreen
        ? _buildPortraitFullscreen(
            context,
            // The portrait full screen has no column of its own: the stream
            // is the chat there, unless the stats panel owns the corner.
            playerWith(),
            canSwipeRooms: swipeSwitch && mobile,
          )
        : LayoutBuilder(
            builder: (context, constraints) {
              if (landscapePhone) {
                return _buildPhoneLandscape(playerWith(onTitle: () => unawaited(showRoomDetails(context))));
              }
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
                    // Pulling the sheet past its lowest stop is the handle's own
                    // way into the portrait full screen, by hand: a phone's,
                    // where that full screen exists.
                    onPortraitFullscreen: mobile ? () => _setPortraitFullscreen(true) : null,
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
                    const _ChatRoomHeader(hoverStats: false),
                    const Expanded(child: RoomChatPanel()),
                  ],
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
                final columnWidth = kChatPanelWidthFixed.clamp(kChatPanelWidthMin, columnMaxWidth);
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
                      Container(width: 1, color: colors.border),
                      SizedBox(
                        width: columnWidth,
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ChatRoomHeader(),
                            Expanded(child: RoomChatPanel()),
                          ],
                        ),
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
    return withShortcuts(
      RoomPanelScope(
        notifier: _panels,
        child: ColoredBox(
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
  // The bar is a single line now (the anchor's identity), so it stays short;
  // the caption controls ride at a modest height instead of the old two-line
  // 64, which made the close button read as a slab.
  final height = wide ? 40.0 : WindowClassScope.toolbarHeightOf(context);
  final leading = DsTooltip(
    message: t.common.back,
    side: DsSide.bottom,
    child: WindowCaptionButton(semanticLabel: t.common.back, icon: DsIcons.arrowLeft, size: 36, onPressed: leave),
  );
  return AppBar(
    backgroundColor: colors.surface,
    surfaceTintColor: const Color(0x00000000),
    elevation: 0,
    automaticallyImplyLeading: false,
    toolbarHeight: height,
    leadingWidth: 36,
    leading: leading,
    titleSpacing: DsSpace.s4,
    // The whole middle band is the window's handle: the title is plain text,
    // not a menu and not a details door — the header card below carries those.
    title: ownChrome
        ? const SizedBox(
            width: double.infinity,
            child: WindowDragArea(child: _RoomTitleBar()),
          )
        : const _RoomTitleBar(),
    actions: [
      const ThemeModeToggle(size: 36),
      const _ChatColumnToggle(),
      _RoomMenu(shortcuts: shortcuts),
      if (ownChrome) ...[
        const SizedBox(width: DsSpace.s4),
        const SizedBox(height: 16, child: DsDivider.vertical()),
        const WindowCaptionControls(height: 36),
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
              style: DsTheme.of(context).typography.caption.copyWith(color: OnVideoColors.foreground),
            ),
          ),
        ),
      ),
    );
  }
}

/// The window's document title: the room's name, plain text. The anchor and
/// the facts live elsewhere; the title is not a menu and not a details door.
final class _RoomTitleBar extends ConsumerWidget {
  const _RoomTitleBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final detail = ref.watch(roomProvider.select((room) => room.room));
    if (detail == null) return const DsSkeleton(width: 220, height: 15);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: DsSpace.s8, end: DsSpace.s8),
      child: Text(
        detail.content.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.typography.bodyStrong.copyWith(color: colors.text),
      ),
    );
  }
}

/// The room's identity header: the anchor's card — avatar in its live ring,
/// the name, the platform and area, and the follow pill. It sits at the head of
/// the wide chat column and, on a phone, under the picture.
///
/// The three figures (viewers, on air, watched) are not a permanent row: the
/// header keeps one line so the talk gets the height. A pointer hovering the
/// header gets them in a tooltip; a phone reads them in the room details.
final class _ChatRoomHeader extends ConsumerWidget {
  const _ChatRoomHeader({this.hoverStats = true});

  /// Whether the pointer may reveal the three figures. False where the header
  /// is the phone's compact card and the numbers live in the details panel.
  final bool hoverStats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final detail = ref.watch(roomProvider.select((room) => room.room));
    if (detail == null) {
      // The detail hasn't landed: the header keeps its footprint with the
      // quiet blocks the identity strip rests on — a blank strip would jump
      // when the facts arrive.
      return ColoredBox(
        color: colors.surface,
        child: const Padding(
          padding: EdgeInsetsDirectional.fromSTEB(DsSpace.s12, DsSpace.s8, DsSpace.s12, DsSpace.s8),
          child: Row(
            spacing: DsSpace.s12,
            children: [
              DsSkeleton.circle(size: 40),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: DsSpace.s4,
                children: [DsSkeleton(width: 160, height: 15), DsSkeleton(width: 90, height: 12)],
              ),
              Spacer(),
              DsSkeleton.block(width: 64, height: 28),
            ],
          ),
        ),
      );
    }
    final anchor = (detail.anchor?.name ?? '').trim();
    final name = anchor.isEmpty ? detail.content.title : anchor;
    final avatar = (detail.anchor?.avatarUrl ?? detail.content.coverUrl).trim();
    final live = detail.broadcast.isLiveNow;
    final site = ref.watch(sitesProvider).all.where((site) => site.manifest.id == detail.ref.platform).firstOrNull;
    final platform = site == null ? detail.ref.platform : localizedSiteName(site);
    final area = (detail.area?.areaName ?? '').trim();
    final where = [platform, if (area.isNotEmpty) area].join(' · ');
    final caption = theme.typography.caption.copyWith(color: colors.textMuted);
    final header = DsPressable(
      semanticLabel: t.room.detailsHint,
      onPressed: () => unawaited(showRoomDetails(context)),
      builder: (context, states, child) =>
          ColoredBox(color: states.contains(WidgetState.hovered) ? colors.hover : colors.surface, child: child),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s12, DsSpace.s8, DsSpace.s12, DsSpace.s8),
        child: Row(
          spacing: DsSpace.s12,
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(shape: BoxShape.circle, color: live ? colors.accent : colors.border),
              child: DsAvatar(
                initials: avatarInitials(name),
                image: avatar.isEmpty ? null : cachedImage(avatar, policy: ImageCachePolicies.avatar),
                size: DsSize.md,
                semanticLabel: name,
              ),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.bodyStrong.copyWith(color: colors.text),
                  ),
                  if (where.isNotEmpty) Text(where, maxLines: 1, overflow: TextOverflow.ellipsis, style: caption),
                ],
              ),
            ),
            const _FollowPill(),
          ],
        ),
      ),
    );
    if (!hoverStats) return header;
    final online = detail.audience.onlineViewers ?? detail.audience.totalViewers;
    final started = detail.broadcast.startedAt;
    final watchStarted = ref.watch(roomProvider.select((room) => room.watchStartedAt));
    final figures = <String>[
      if (online != null) '${t.room.statViewers} ${AudienceFormat.format(online)}',
      if (started != null) '${t.room.statOnAir} ${_roomClock(started)}',
      '${t.room.statWatched} ${_roomClock(watchStarted)}',
    ].join('\n');
    return DsTooltip(message: figures, side: DsSide.bottom, child: header);
  }
}

/// A running clock for the header's hover figures, without a ticking widget:
/// the header rebuilds on the room's own updates, and a hover snapshot is
/// enough for a number that is not the thing being watched.
String _roomClock(DateTime since) {
  final elapsed = DateTime.now().difference(since);
  String two(int value) => value.toString().padLeft(2, '0');
  if (elapsed.isNegative) return '00:00:00';
  return '${two(elapsed.inHours)}:${two(elapsed.inMinutes.remainder(60))}:${two(elapsed.inSeconds.remainder(60))}';
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
      padding: const EdgeInsetsDirectional.symmetric(vertical: DsSpace.s4),
      child: DsButton(
        variant: followed ? DsButtonVariant.secondary : DsButtonVariant.primary,
        size: DsSize.sm,
        onPressed: () => unawaited(toggleRoomFollow(context, ref)),
        leading: DsIcon(followed ? DsIcons.heart : DsIcons.heartCrack, size: theme.sizes.iconSm),
        child: Text(followed ? t.room.unfollow : t.room.follow),
      ),
    );
  }
}

/// Shows or folds the chat column from the room bar — the live sites' panel
/// verb, beside share and more. Only the wide room has a column to fold.
final class _ChatColumnToggle extends ConsumerWidget {
  const _ChatColumnToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The column exists wherever the wide layout does (840 and up), not only
    // past the sidebar breakpoint: a viewer who folded the chat at 900 must
    // still be able to unfold it at 900.
    if (MediaQuery.sizeOf(context).width < kRoomWideBreakpoint) return const SizedBox.shrink();
    final open = !ref.watch(chatCollapsedProvider);
    return ChromeIconButton(
      icon: open ? DsIcons.panelRightClose : DsIcons.panelRightOpen,
      semanticLabel: open ? context.t.room.collapseChat : context.t.room.expandChat,
      tooltip: open ? context.t.room.collapseChat : context.t.room.expandChat,
      size: 36,
      onPressed: () {
        if (open) {
          unawaited(ref.read(chatCollapsedProvider.notifier).set(value: true));
        } else {
          unawaited(ref.read(chatCollapsedProvider.notifier).set(value: false));
        }
      },
    );
  }
}

/// The room's own actions, in one small list.
///
/// The page header's ⋮ and the fullscreen strip's ⋮ open the same rows —
/// switch, refresh, the picture's own verbs (PiP, cast) where the strip is too
/// narrow to carry them, sleep, a window of its own, the keyboard help — so a
/// room action never disappears with the page chrome. Everything else lives
/// where its object lives: details on the header, playback in the player
/// settings, picture verbs on the picture.
List<Widget> roomMenuItems(
  BuildContext context,
  WidgetRef ref,
  RoomState room, {
  required List<RoomShortcutBinding> shortcuts,
}) {
  final t = context.t;
  final detail = room.room;
  final presentation = ref.watch(roomPresentationProvider);
  final sleepMinutes = ref.watch(sleepTimerProvider).minutes;
  final sleepRunning = sleepMinutes != null;
  // A desktop shell that runs secondary windows and has the viewer's
  // rooms-in-windows habit on: the room can move into a window of its own.
  // Raising the window the room already lives in would be a verb that does
  // nothing, so a room window itself does not offer it.
  final offersRoomWindow =
      ref.read(roomLeaveProvider) == null &&
      ref.watch(secondaryWindowsProvider) != null &&
      ref.watch(roomWindowsProvider) &&
      ref.read(platformRuntimeProvider).environment.runtime.formFactor == FormFactor.desktop;
  final items = <Widget>[
    if (detail != null)
      DsMenuItem(
        leading: const DsIcon(DsIcons.arrowLeftRight),
        label: Text(t.room.switchRoom),
        onPressed: () => unawaited(showRoomSwitcher(context, current: detail)),
      ),
    DsMenuItem(
      leading: const DsIcon(DsIcons.refreshCw),
      label: Text(t.room.refreshRoom),
      onPressed: () => unawaited(ref.read(roomProvider.notifier).refreshRoom()),
    ),
    // The strip folds these away on a narrow picture; the menu keeps them
    // reachable there, and everywhere else they ride along for free.
    if (room.handle != null && ref.read(roomPresentationProvider.notifier).pipAvailable)
      DsMenuItem(
        leading: const DsIcon(DsIcons.pictureInPicture2),
        label: Text(presentation == PresentationMode.pip ? t.room.pipOff : t.room.pipOn),
        onPressed: () => unawaited(toggleRoomPip(context, ref)),
      ),
    if (room.lines.isNotEmpty)
      DsMenuItem(
        leading: const DsIcon(DsIcons.cast),
        label: Text(t.room.cast),
        onPressed: () => unawaited(
          showCastDialog(
            context,
            line: room.lines[room.lineIndex.clamp(0, room.lines.length - 1)],
            title: detail?.content.title,
          ),
        ),
      ),
    const DsMenuDivider(),
    DsMenuItem(
      leading: DsIcon(sleepRunning ? DsIcons.timer : DsIcons.moon),
      label: Text(sleepRunning ? '${t.room.sleep} · ${asmrSleepDurationLabel(sleepMinutes)}' : t.room.sleep),
      onPressed: () => unawaited(showRoomSleepTimer(context)),
    ),
    if (detail != null && offersRoomWindow)
      DsMenuItem(
        leading: const DsIcon(DsIcons.appWindow),
        label: Text(t.room.openInNewWindow),
        onPressed: () => unawaited(
          openRoom(
            context,
            platform: detail.ref.platform,
            roomId: detail.ref.roomId,
            room: detail,
            playlist: ref.read(roomPlaylistProvider)?.rooms,
          ),
        ),
      ),
    if (shortcuts.any((binding) => binding.action == RoomShortcutAction.help)) ...[
      const DsMenuDivider(),
      DsMenuItem(
        leading: const DsIcon(DsIcons.keyboard),
        label: Text(t.room.shortcutsHelp),
        onPressed: () => unawaited(showRoomShortcuts(context, shortcuts)),
      ),
    ],
  ];
  return items;
}

/// The room's overflow menu: switch, refresh, the picture's PiP and cast
/// where they apply, sleep, a window of its own and the keyboard help.
/// Everything else lives where its object lives — details on the header,
/// playback in the player settings, picture verbs on the picture — so the
/// menu stays a short list and never grows with the window.
final class _RoomMenu extends ConsumerWidget {
  const _RoomMenu({required this.shortcuts});

  final List<RoomShortcutBinding> shortcuts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final room = ref.watch(roomProvider);
    return DsMenuAnchor(
      semanticLabel: t.common.more,
      items: roomMenuItems(context, ref, room, shortcuts: shortcuts),
      builder: (context, controller, _) => ChromeIconButton(
        icon: DsIcons.ellipsisVertical,
        semanticLabel: t.common.more,
        tooltip: t.common.more,
        size: 36,
        onPressed: controller.toggle,
      ),
    );
  }
}

/// The room's own card, the reference's `RoomInfoBar` grown up: the
/// anchor's identity over a wash of the room's own cover — the avatar in a
/// live ring, the platform and the area, the live state, the audience and
/// the start time, the title — one press away from the details sheet.
///
/// It sits under the picture on a phone and at the head of the chat column
/// on a wide window, never over the picture itself. A phone held sideways has
/// no column with room for it, so there its name folds into the picture's
/// strip instead, and that name takes the card's press.
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
    final replay = detail.broadcast.isRecord;
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
      builder: (context, states, child) =>
          ColoredBox(color: states.contains(WidgetState.hovered) ? colors.hover : OnVideoColors.clear, child: child),
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
                    image: avatar.isEmpty ? null : cachedImage(avatar, policy: ImageCachePolicies.avatar),
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
                          if (replay)
                            // The same word the details panel says for the
                            // same fact: this room plays a recording.
                            DsBadge(dot: false, label: Text(t.favorites.statusReplay), status: DsStatus.info),
                        ],
                      ),
                      // A platform that sends neither figure gets no row at
                      // all: an empty one still costs its spacing and reads as
                      // a hole under the name. The figures are a broadcast's
                      // numbers — a replay says what it is above instead.
                      if (live && (online != null || (popularity != null && popularity != online)))
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
                // The card's press opens the details; the chevron at its end
                // edge says so where a pointer looks for a way in — and it
                // points the way the sheet will come: in from the end edge on
                // a wide window, up from the bottom on a narrow one.
                DsIcon(
                  MediaQuery.sizeOf(context).width >= kDsPanelBreakpoint ? DsIcons.chevronRight : DsIcons.chevronDown,
                  size: theme.sizes.iconSm,
                  color: colors.textSubtle,
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
    final time = '${two(hours)}:${two(minutes)}:${two(seconds)}';
    return Text(context.t.room.onAirFor(time: time), style: widget.style);
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
    // The same sheet the room's menu opens (the shared minute list inside),
    // not a menu of its own: the chip is a second door to one panel, and two
    // sets of minutes could never agree for long.
    return DsPressable(
      semanticLabel: t.room.sleep,
      onPressed: () => unawaited(showRoomSleepTimer(context)),
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        return Container(
          height: theme.sizes.sm,
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8),
          decoration: DsBoxDecoration(
            color: running
                ? theme.selectedFill
                : hovered || states.contains(WidgetState.focused)
                ? colors.hover
                : null,
            borderRadius: theme.radii.controlCorners(null, theme.sizes.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: DsSpace.s4,
            children: [
              DsIcon(DsIcons.moon, size: theme.sizes.iconSm, color: running ? theme.onSelectedFill : colors.textMuted),
              Text(
                label,
                style: theme.typography.caption.copyWith(color: running ? theme.onSelectedFill : colors.textMuted),
              ),
            ],
          ),
        );
      },
    );
  }
}
