import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flame_barrage/flame_barrage.dart' show BarrageController, EmojiAtlas, FlameBarrageWidget;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/services.dart' show Clipboard, ClipboardData, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:live_device/live_device.dart'
    show
        PlatformScreenAwakeService,
        PlatformScreenBrightnessService,
        PlatformScreenOrientationService,
        ScreenAwakeService,
        ScreenBrightnessScope,
        ScreenBrightnessService,
        ScreenOrientationService;
import 'package:live_log/live_log.dart' show LiveLog;
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:live_vod/live_vod.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_danmaku/media_core_danmaku.dart' show BarrageItemMapper, DanmakuPlayerBinding;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/account/account.dart' show showBilibiliWebLoginPage;
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/room/page/chat_splitter.dart' show ChatSplitter;
import 'package:pure_live/modules/live/room/player/sleep_timer.dart' show SleepTimerController, sleepTimerProvider;
import 'package:pure_live/modules/vod/controller/vod_app_login.dart' show vodAppClientProvider;
import 'package:pure_live/modules/vod/controller/vod_controller.dart' show vodClientProvider, vodUploaderCardProvider;
import 'package:pure_live/modules/vod/controller/vod_downloads.dart';
import 'package:pure_live/modules/vod/controller/vod_library.dart';
import 'package:pure_live/modules/vod/controller/vod_playback_settings.dart';
import 'package:pure_live/modules/vod/controller/vod_settings.dart' show vodQualityProvider;
import 'package:pure_live/modules/vod/controller/vod_social.dart'
    show VodCommentsController, vodCommentsProvider, vodFollowUpProvider, vodLikeProvider, vodWriteReadyProvider;
import 'package:pure_live/modules/vod/widgets/vod_jump_dialog.dart' show showVodJumpDialog;
import 'package:pure_live/modules/vod/widgets/vod_media_source.dart'
    show isVodExternalAudioFailure, vodDashAudioUrls, vodDashSourceOf, vodDashVideoOf, vodQualityLabel;
import 'package:pure_live/modules/vod/widgets/vod_picture_gestures.dart' show VodPictureGestures, VodTapSide;
import 'package:pure_live/modules/vod/widgets/vod_player_chrome.dart'
    show VodGestureKind, VodGestureTip, VodPictureNotice, VodSeekBar, VodSubtitleLayer;
import 'package:pure_live/modules/vod/widgets/vod_widgets.dart'
    show VodFoldedText, VodRailDoor, VodStatPill, VodVideoRow, vodDateText, vodDurationText;
import 'package:pure_live/shared/player/player_danmaku_list_panel.dart';
import 'package:pure_live/shared/player/player_danmaku_quick_controls.dart';
import 'package:pure_live/shared/shared.dart';

/// One Bilibili archive's page: the player over media_core, the archive's
/// metadata, its parts, and related archives — Bilibili's own video page,
/// reduced to what the station's sources provide.
///
/// Playback is one shared media_core handle: progressive mp4 when the source
/// serves it (picture and sound together), or the source's first DASH video
/// rendition with an honest "picture only" notice when it does not. Progress
/// is saved per bvid (part + seconds) so a return resumes where it stopped.

/// The exact archive part that has successfully opened.
typedef _VideoMediaIdentity = ({String bvid, int aid, int cid, int page});

/// The newest part request; a newer pick replaces an older pending one.
typedef _VideoOpenIntent = ({VodPart part, int? qn, double? resume});

final class VodVideoPage extends ConsumerStatefulWidget {
  /// The archive behind [bvid].
  const VodVideoPage({required this.bvid, super.key});

  /// The archive's bvid.
  final String bvid;

  @override
  ConsumerState<VodVideoPage> createState() => _VodVideoPageState();
}

final LiveLog vodLog = appLog.forCategory('vod.play');

final class _VodVideoPageState extends ConsumerState<VodVideoPage> with RouteAware, WidgetsBindingObserver {
  /// The tier a part opens with before the station's own preference is read
  /// in `initState`. This is a choice about what plays; the number the source
  /// is asked with is the whole ladder, and lives with it.
  static const int _defaultQn = 64;

  VodDetail? _detail;

  /// The related archives read so far and the window of twenty the rail
  /// shows; 换一换 walks the rest and folds in what a fresh read adds.
  List<VodVideo> _relatedPool = const [];
  int _relatedStart = 0;
  bool _relatedBusy = false;
  VodPlayInfo? _play;
  VodPart? _part;
  _VideoMediaIdentity? _openedIdentity;
  _VideoOpenIntent? _pendingPart;
  PlayerHandle? _attemptHandle;
  int _openGeneration = 0;
  int _openedGeneration = 0;

  /// The flying danmaku engine this page owns, the bridge that keeps its
  /// clock on the part's own, and the cid the loaded timeline belongs to.
  final BarrageController _barrage = BarrageController();
  DanmakuPlayerBinding? _danmakuBinding;
  int _danmakuCid = 0;

  /// The part's danmaku track, kept whole: the list panel reads the
  /// recording's full timeline, not just what has flown past the clock.
  List<DanmakuEntry> _danmakuEntries = const [];
  int _qn = _defaultQn;

  /// The definition actually opened, which the source may answer below what
  /// was asked: the ladder the account is entitled to is the ceiling, and a
  /// bar that named the request rather than the answer would be selling a
  /// picture nobody is watching.
  int _openedQn = _defaultQn;
  String? _openedLabel;
  PlayerHandle? _handle;
  final FocusNode _playFocus = FocusNode(debugLabel: 'vod-play');
  StreamSubscription<PlayerTransportState>? _transportSub;
  StreamSubscription<PlayerAdapterEvent>? _eventSub;
  StreamSubscription<GeometryState>? _geometrySub;
  PlayerTransportState? _transport;
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);
  bool _gaveInitialFocus = false;
  bool _loading = true;
  bool _opening = false;
  bool _dashAudioFallbackTried = false;
  int _dashAudioUrlIndex = 0;
  bool _dashAudioFallbackPending = false;
  int _adapterAttempt = 0;
  bool _dashAudioActive = false;
  bool _silent = false;
  bool _disposed = false;
  String? _error;
  double? _dragSeconds;
  double? _resumeSeconds;
  double? _retryResume;
  bool _muted = false;
  bool _globalMute = false;
  bool _sleepStopped = false;
  double _volume = 1;
  double _speed = 1;

  /// The volume a drag on the picture started from, so the gesture moves from
  /// where the sound stands rather than from the frame before it.
  double _dragVolume = 1;

  /// The line the subtitle track is on right now; null leaves the picture
  /// alone. It is read with the transport rather than in the build, so the
  /// words never arrive a frame late.
  String? _subtitleText;

  /// The figure the picture's gesture is answering with, and where it stands;
  /// a seek says a time, a drag says a percentage, a hold says a rate.
  VodGestureKind? _gestureKind;
  String? _gestureValue;
  String? _gestureNote;
  Timer? _gestureTimer;

  /// The screen's brightness, which the left half of the picture adjusts where
  /// the display will take the write and the right half alone is the volume
  /// where it will not — the room's rule, so one gesture reads the same on
  /// both players.
  final ScreenBrightnessService _screenBrightness = const PlatformScreenBrightnessService();
  bool? _brightnessWritable;
  ScreenBrightnessScope _brightnessScope = ScreenBrightnessScope.application;
  double _brightness = 100;
  double _dragBrightness = 100;
  bool _dragIsBrightness = false;

  /// Whether a hold has the picture running faster right now, and the rate it
  /// goes back to when the finger lifts.
  bool _speedHeld = false;
  double _speedBeforeHold = 1;

  /// The keyboard's seek step, which grows while the key keeps being held:
  /// five seconds once, then ten, then twenty, so a long skip is one key.
  double _seekStep = 5;
  DateTime? _lastSeekKey;

  /// The horizontal drag on the picture: where it started from, how far it
  /// has walked, and where that stands, so the release seeks once rather than
  /// on every frame of the drag.
  Duration? _scrubFrom;
  double _scrubWalked = 0;
  double? _scrubSeconds;

  /// How far the subtitle line stands off the picture's bottom edge while the
  /// bar is up: the bar's own height, so the two never sit on each other.
  static const double _subtitleInset = 72;

  /// What a double tap on either side of the picture steps over.
  static const double _doubleTapStep = 10;

  /// The archive's own opening and ending, in seconds: where the opening stops
  /// and where the ending starts. They belong to the archive and to this
  /// device, and the station does not supply them for a posted video.
  double? _headSeconds;
  double? _tailSeconds;

  /// The player's extras for the part: its marked moments, its subtitle tracks
  /// and, where the station sends one, its scrub filmstrip.
  VodPlayerExtra _extra = const VodPlayerExtra();

  /// The subtitle track the viewer chose and the lines it came with; the index
  /// walks forward while the picture plays rather than searching every frame.
  VodSubtitleTrack? _subtitleTrack;
  List<VodSubtitleLine> _subtitleLines = const [];
  int _subtitleCursor = 0;

  /// The countdown a finished part runs before the next one opens, so the step
  /// forward can be stopped; zero means nothing is counting.
  int _countdown = 0;
  Timer? _countdownTimer;

  /// The position the page jumped back to on opening, offered a way to undo it
  /// for as long as the notice stands.
  double? _resumedAt;
  Timer? _resumedTimer;

  /// Sound only: the part keeps playing and the picture is put away — the way
  /// to keep listening to a 广播剧-style episode at a desk.
  bool _audioOnly = false;

  /// Whether the overlay bars are up; a playing stream lets them settle away.
  bool _controlsVisible = true;

  /// The watching lock, the room's own rule: locked, the strip, the bar and
  /// the picture's gestures all stand down, and the unlock pill on the
  /// picture's right edge is the only thing left to press.
  bool _locked = false;

  /// The wide window's rail (the parts shelf and the related videos): open
  /// or folded to its door, and the width the seam's drag left it at.
  bool _railOpen = true;
  double _railWidth = _railDefault;
  static const double _railMin = 280;
  static const double _railMax = 520;
  static const double _railDefault = 340;

  /// The least width the stage keeps beside the rail.
  static const double _stageFloor = 420;

  /// The display's wake lock: held while a part plays and the app's own
  /// 屏幕常亮 allows it, the same rule the live room and the IPTV page keep.
  final ScreenAwakeService _screenAwake = const PlatformScreenAwakeService();
  bool _screenHeld = false;

  /// Whether the blurb shows in full rather than its first six lines.
  Timer? _hideTimer;

  /// The picker whose catalogue hangs over the picture, if any.
  _VodPanel? _openPanel;
  Timer? _hoverTimer;
  Timer? _leaveTimer;

  /// The bar and each picker's box: the open catalogue hangs over the button
  /// that raised it rather than at the picture's end edge.
  final GlobalKey _barAnchor = GlobalKey(debugLabel: 'vod-bar');
  final Map<_VodPanel, GlobalKey> _panelAnchors = {
    for (final panel in _VodPanel.values) panel: GlobalKey(debugLabel: 'vod-picker-${panel.name}'),
  };

  /// The playing part's row in the parts catalogue, so opening the catalogue
  /// brings it into view instead of starting at the first.
  final GlobalKey _currentPartKey = GlobalKey();

  /// Whether the end of the current part has already been acted on, so the
  /// station's finish action runs once per part.
  bool _finished = false;
  bool _archiveCompleted = false;
  bool _nextPartCheckpointPending = false;

  /// The Android background-playback gate and the handle it paused.
  BackgroundPlaybackGate? _backgroundGate;
  PlayerId? _backgroundPausedHandle;

  /// The picture's aspect as the engine last reported it: the fullscreen
  /// orientation policy reads it to decide which way a phone turns.
  double _aspectRatio = 0;

  /// The phone's orientation lock (inert on a desktop).
  final ScreenOrientationService _screenOrientation = const PlatformScreenOrientationService();

  /// The window's observer, kept for `dispose` where the provider scope may
  /// already be gone.
  RouteObserver<ModalRoute<void>>? _routeObserver;
  ModalRoute<void>? _route;
  bool _routeCovered = false;
  int _routeCoverDepth = 0;
  bool _routeResumeWhenReady = false;
  bool _routeAutoplayRequested = false;

  /// The replay a covered route paused, kept apart from the background gate.
  PlayerId? _routePausedHandleId;
  Future<void>? _routePause;
  int _routePauseGeneration = 0;

  // Captured while the page is alive; `ref` is refused by the time dispose
  // runs, and the leaving page must still exit its presentation mode and
  // release its handle.
  late final RoomPresentationController _presentationNotifier;

  /// The sleep timer this page owns while it stands: its fire stops this
  /// video, and leaving disarms it.
  late final SleepTimerController _sleepTimerNotifier;
  late final PlayerKernel _kernel;

  /// The continue checkpoint's writer, captured for the same reason: the
  /// leaving page's last position and the mini window's close both land
  /// after `ref` has stopped answering.
  late final VodHistoryController _historyNotifier;

  /// The presentation mode, followed through a manual listener for the same
  /// reason: the leaving page reads its own field, not `ref`.
  PresentationMode _presentationMode = PresentationMode.normal;

  ({int aid, bool liked})? _likeBaseline;

  bool get _effectivelyMuted => _muted || _globalMute;

  _VideoMediaIdentity _identityOf(VodPart part) =>
      (bvid: widget.bvid, aid: _detail?.aid ?? 0, cid: part.cid, page: part.page);

  VodPart? _partOf(_VideoMediaIdentity? identity) {
    if (identity == null) return null;
    for (final part in _detail?.parts ?? const <VodPart>[]) {
      if (_identityOf(part) == identity) return part;
    }
    return null;
  }

  /// Only a successfully opened source may answer transport controls.
  PlayerHandle? get _playableHandle {
    final handle = _handle;
    if (!mounted || _disposed || _opening || _openedIdentity == null || _openedGeneration != _openGeneration) {
      return null;
    }
    return handle;
  }

  bool _isCurrentGeneration(int generation) => mounted && !_disposed && generation == _openGeneration;

  void _clearTransportSubscriptions() {
    unawaited(_transportSub?.cancel() ?? Future<void>.value());
    unawaited(_eventSub?.cancel() ?? Future<void>.value());
    unawaited(_geometrySub?.cancel() ?? Future<void>.value());
    unawaited(_danmakuBinding?.detach() ?? Future<void>.value());
    _transportSub = null;
    _eventSub = null;
    _geometrySub = null;
    _danmakuBinding = null;
  }

  void _releaseHandle(PlayerHandle handle) {
    silencePlayer(handle);
    unawaited(_kernel.release(handle.id));
  }

  @override
  void initState() {
    super.initState();
    _presentationNotifier = ref.read(roomPresentationProvider.notifier);
    // The sleep timer must stop this video, not some global notion of one.
    _sleepTimerNotifier = ref.read(sleepTimerProvider.notifier);
    // A timer armed with no player alive (the settings' ASMR dialog) dies
    // here: this page owns the fire now and inherits no leftover.
    Timer.run(() => _sleepTimerNotifier.start(null));
    _sleepTimerNotifier.onFire_ = _onSleepFire;
    _kernel = ref.read(playerKernelProvider);
    _historyNotifier = ref.read(vodHistoryProvider.notifier);
    ref.listenManual(roomPresentationProvider, (_, next) => _presentationMode = next, fireImmediately: true);
    WidgetsBinding.instance.addObserver(this);
    _globalMute = ref.read(playbackSettingsProvider).globalMute;
    _volume = ref.read(modulePlaybackSettingsProvider(PlayerModule.vod)).volume;
    _backgroundGate = BackgroundPlaybackGate(
      backgroundEnabled: () => ref.read(playbackSettingsProvider).backgroundPlay,
      shouldPause: () {
        final presentation = ref.read(roomPresentationProvider);
        return (_transport?.isPlaying ?? false) &&
            presentation != PresentationMode.pip &&
            presentation != PresentationMode.floating;
      },
      pause: () async {
        _backgroundPausedHandle = _playableHandle?.id;
        await _playableHandle?.pause();
      },
      canResume: () =>
          _backgroundPausedHandle != null &&
          _playableHandle?.id == _backgroundPausedHandle &&
          !_sleepStopped &&
          !(_transport?.isPlaying ?? false),
      resume: () async {
        _backgroundPausedHandle = null;
        await _playableHandle?.play();
      },
    );
    // The station's setting names the rendition the first part asks for;
    // the source may still answer lower, and the menu follows what it
    // actually served.
    _qn = ref.read(vodQualityProvider).qn;
    // The station's playback choices: the rate a video opens with and what
    // a finished part leads to.
    _speed = ref.read(vodPlaybackSettingsProvider).speed.value;
    unawaited(_syncBrightness());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is! ModalRoute<void> || identical(route, _route)) return;
    if (_route != null) _routeObserver?.unsubscribe(this);
    _route = route;
    final observer = ref.read(routeObserverProvider);
    _routeObserver = observer;
    observer.subscribe(this, route);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _backgroundGate?.handleLifecycle(state);
  }

  /// Another page covers this one (a related archive, a menu route): the
  /// picture pauses rather than playing under it.
  @override
  void didPushNext() {
    _routeCoverDepth++;
    _routeCovered = true;
    if (_routeCoverDepth != 1) return;
    final generation = ++_routePauseGeneration;
    final handle = _handle;
    if (handle == null || _routePausedHandleId != null || !(_transport?.isPlaying ?? false)) return;
    _routePausedHandleId = handle.id;
    _routePause = handle.pause().catchError((Object _) {
      if (_routePauseGeneration == generation) _routePausedHandleId = null;
    });
  }

  @override
  void didPopNext() {
    if (_routeCoverDepth > 0) _routeCoverDepth--;
    if (_routeCoverDepth > 0) return;
    final generation = ++_routePauseGeneration;
    final pausedHandleId = _routePausedHandleId;
    final pause = _routePause;
    final handle = _playableHandle;
    final opening = (_opening || handle == null) && pausedHandleId == null;
    _routeCovered = false;
    _routePausedHandleId = null;
    _routePause = null;
    if (opening) {
      _routeResumeWhenReady = _routeAutoplayRequested && !_sleepStopped;
      return;
    }
    _routeResumeWhenReady = false;
    if (pausedHandleId == null || handle == null || handle.id != pausedHandleId) return;
    unawaited(_resumeAfterRoute(handle, pause, generation));
  }

  Future<void> _pauseForRoute(PlayerHandle handle) async {
    if (!_routeCovered) return;
    final pending = _routePause;
    if (pending != null) {
      await pending;
      return;
    }
    final generation = _routePauseGeneration;
    _routePausedHandleId = handle.id;
    _routePause = handle.pause().catchError((Object _) {
      if (_routePauseGeneration == generation) _routePausedHandleId = null;
    });
    await _routePause;
  }

  Future<void> _settleRouteAutoplay(PlayerHandle handle) async {
    if (_sleepStopped || !_routeAutoplayRequested) {
      _routeResumeWhenReady = false;
      return;
    }
    if (_routeCovered) {
      _routeResumeWhenReady = true;
      await _pauseForRoute(handle);
      if (_routeCovered) {
        if (_routePausedHandleId == null) {
          _routePausedHandleId = handle.id;
          _routePause = Future<void>.value();
        }
        return;
      }
      _routePausedHandleId = null;
      _routePause = null;
    }
    if (!_routeResumeWhenReady) return;
    _routeResumeWhenReady = false;
    try {
      if (!handle.state.hasError && handle.state.canPlay && !(handle.playIntent ?? false)) await handle.play();
    } on Object {
      // Returning to the page does not turn a refused play into a page failure.
    }
  }

  Future<void> _resumeAfterRoute(PlayerHandle handle, Future<void>? pause, int generation) async {
    try {
      await pause;
    } on Object {
      return;
    }
    if (!mounted ||
        _disposed ||
        generation != _routePauseGeneration ||
        _playableHandle?.id != handle.id ||
        _sleepStopped) {
      return;
    }
    if (handle.state.hasError || !handle.state.canPlay || (_transport?.isPlaying ?? false)) return;
    try {
      final coverDepth = _routeCoverDepth;
      await handle.play();
      if (generation != _routePauseGeneration && _routeCoverDepth > coverDepth) await handle.pause();
    } on Object {
      // Returning to the page does not turn a refused play into a page failure.
    }
  }

  /// Holds the display awake exactly while the part plays and the preference
  /// allows it.
  void _syncScreenWake(bool hold) {
    if (hold == _screenHeld) return;
    _screenHeld = hold;
    unawaited((hold ? _screenAwake.enable() : _screenAwake.disable()).catchError((Object _) {}));
  }

  /// The page's hold on the app's sound: playing a video hushes a live
  /// window or the music the viewer left running.
  void _holdSound() {
    unawaited(
      ref
          .read(audioArbiterProvider.notifier)
          .claim(
            AudioOwner(AudioOwnerKind.vod, 'vod-video:${widget.bvid}'),
            () => Future<void>.value(_playableHandle?.pause()),
          ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _routePauseGeneration++;
    _routeCovered = false;
    _routeCoverDepth = 0;
    _routeResumeWhenReady = false;
    _routeAutoplayRequested = false;
    if (_route != null) _routeObserver?.unsubscribe(this);
    _route = null;
    ref.read(audioArbiterProvider.notifier).release(AudioOwner(AudioOwnerKind.vod, 'vod-video:${widget.bvid}'));
    unawaited(_screenAwake.disable().catchError((Object _) {}));
    _saveProgress(force: true);
    // The player goes quiet before anything else: the route's leave animation
    // runs while the release's queue drains, and the video must not be heard
    // over the page the viewer returned to.
    final handle = _handle ?? _attemptHandle;
    _handle = null;
    _attemptHandle = null;
    if (handle != null) {
      if (_presentationMode != PresentationMode.normal) {
        unawaited(_presentationNotifier.exit(handle.id));
      }
      _releaseHandle(handle);
    }
    _hideTimer?.cancel();
    _hoverTimer?.cancel();
    _leaveTimer?.cancel();
    _gestureTimer?.cancel();
    _countdownTimer?.cancel();
    _resumedTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _backgroundGate?.dispose();
    _backgroundGate = null;
    _sleepTimerNotifier.onFire_ = null;
    Timer.run(() => _sleepTimerNotifier.start(null));
    _routeObserver?.unsubscribe(this);
    _clearTransportSubscriptions();
    unawaited(_danmakuBinding?.dispose() ?? Future<void>.value());
    _danmakuBinding = null;
    _barrage.dispose();
    _playFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _play = null;
      _silent = false;
      _transport = null;
      _resumeSeconds = null;
      _retryResume = null;
    });
    final client = ref.read(vodClientProvider);
    final appClient = ref.read(vodAppClientProvider);
    try {
      // The chosen interface's detail: the app's view service when it is in
      // force, the web record otherwise; an app refusal falls back.
      VodDetail detail;
      if (ref.read(vodPlaybackSettingsProvider).apiType == VodApiType.app && appClient != null) {
        try {
          detail = await appClient.detail(bvid: widget.bvid);
        } on Object catch (error) {
          // The app service refusing a detail is routine (an unlogged session,
          // a gRPC tier the web still serves): say which door answered.
          vodLog.info('detail fell back to the web api', fields: {'bvid': widget.bvid, 'error': '$error'});
          detail = await client.detail(widget.bvid);
        }
      } else {
        detail = await client.detail(widget.bvid);
      }
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
      unawaited(_loadRelated(client));
      if (detail.parts.isEmpty) {
        vodLog.warning('the archive carries no part', fields: {'bvid': widget.bvid});
        setState(() => _error = context.t.vod.openFailed);
        return;
      }
      final saved = _readProgress();
      final part = saved == null
          ? detail.parts.first
          : detail.parts.where((candidate) => candidate.cid == saved.cid).firstOrNull ?? detail.parts.first;
      _resumeSeconds = saved != null && saved.cid == part.cid ? saved.seconds : null;
      await _openPart(part, resume: _resumeSeconds);
      _resumeSeconds = null;
    } on Object catch (error) {
      vodLog.warning(
        'detail load failed',
        fields: {'bvid': widget.bvid, 'error': error is VodFailure ? error.message : '$error'},
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is VodFailure ? error.message : '$error';
      });
    }
  }

  Future<void> _loadRelated(BilibiliVodClient client) async {
    try {
      final related = await client.related(widget.bvid);
      if (!mounted) return;
      // Bilibili offers up to forty; the rail shows twenty at a time and
      // 换一换 walks the rest.
      setState(() {
        _relatedPool = related;
        _relatedStart = 0;
      });
    } on Object {
      // Related videos are a bonus; the page stands without them.
    }
  }

  /// The rail's current twenty, wrapping through the pool it holds.
  List<VodVideo> get _relatedWindow {
    final pool = _relatedPool;
    if (pool.isEmpty) return const [];
    final count = pool.length < 20 ? pool.length : 20;
    final start = _relatedStart % pool.length;
    return [for (var index = 0; index < count; index++) pool[(start + index) % pool.length]];
  }

  /// Swaps the rail's twenty for the next ones: a fresh read folds in what
  /// the source newly offers, then the window moves on. A refused read still
  /// turns the page it already has.
  Future<void> _changeRelated() async {
    if (_relatedBusy || _relatedPool.length <= 20) return;
    setState(() => _relatedBusy = true);
    var pool = _relatedPool;
    try {
      final fresh = await ref.read(vodClientProvider).related(widget.bvid);
      final seen = {for (final video in pool) video.bvid ?? video.id};
      pool = [...pool, ...fresh.where((video) => seen.add(video.bvid ?? video.id))];
    } on Object {
      // Keep the pool as it was.
    }
    if (!mounted) return;
    setState(() {
      _relatedPool = pool;
      _relatedStart = (_relatedStart + 20) % pool.length;
      _relatedBusy = false;
    });
  }

  /// Opens [part] on the shared kernel, keeping only the newest request made
  /// while a source is still opening.
  Future<void> _openPart(VodPart part, {int? qn, double? resume}) async {
    if (!mounted || _disposed) return;
    _pendingPart = (part: part, qn: qn, resume: resume);
    if (_opening) return;
    await _drainPartOpens();
  }

  Future<void> _drainPartOpens() async {
    while (mounted && !_disposed && _pendingPart != null) {
      final intent = _pendingPart!;
      _pendingPart = null;
      final part = intent.part;
      final generation = ++_openGeneration;
      final fallback = _partOf(_openedIdentity) ?? _part;
      // The source that actually reported this transport owns the checkpoint.
      _saveProgress(force: true);
      _nextPartCheckpointPending = false;
      _archiveCompleted = false;
      _readSkipPoints(part.cid);
      final previous = _handle;
      _handle = null;
      _attemptHandle = null;
      _openedIdentity = null;
      _openedGeneration = 0;
      _dashAudioFallbackTried = false;
      _dashAudioUrlIndex = 0;
      _dashAudioFallbackPending = false;
      _adapterAttempt = 0;
      _dashAudioActive = false;
      _backgroundPausedHandle = null;
      _routeAutoplayRequested = !_sleepStopped;
      _routePauseGeneration++;
      _routePausedHandleId = null;
      _routePause = null;
      _routeResumeWhenReady = false;
      _clearTransportSubscriptions();
      // A failed part switch must not leave the previous source playing.
      if (previous != null) _releaseHandle(previous);
      // The part being left loses its timeline and all part-scoped extras.
      _barrage.clear();
      _danmakuCid = 0;
      _danmakuEntries = const [];
      _subtitleTrack = null;
      _subtitleLines = const [];
      _subtitleText = null;
      _subtitleCursor = 0;
      _extra = const VodPlayerExtra();
      _resetScrub();
      _cancelCountdown();
      _resumedTimer?.cancel();
      _resumedAt = null;
      _gestureTimer?.cancel();
      _syncScreenWake(false);
      setState(() {
        _opening = true;
        _error = null;
        _part = part;
        _play = null;
        _silent = false;
        _transport = null;
        _dragSeconds = null;
        _finished = false;
        _aspectRatio = 0;
        _openPanel = null;
        _gestureKind = null;
        _gestureValue = null;
        _gestureNote = null;
        _speedHeld = false;
        _speedBeforeHold = _speed;
      });
      if (!_isCurrentGeneration(generation)) return;
      final client = ref.read(vodClientProvider);
      final kernel = _kernel;
      try {
        // The interface the station asks: the app's gRPC channel when the
        // viewer chose it and signed in, the web REST answer otherwise. An app
        // refusal falls back to the web request rather than failing the part.
        final appClient = ref.read(vodAppClientProvider);
        final aid = _detail?.aid ?? 0;
        VodPlayInfo info;
        // The tier the viewer asked for this part: the ladder ask is the
        // source's business, and this number chooses its opened rendition.
        final want = intent.qn ?? _qn;
        _qn = want;
        if (ref.read(vodPlaybackSettingsProvider).apiType == VodApiType.app && appClient != null && aid > 0) {
          try {
            info = await appClient.playUgc(aid: aid, cid: part.cid);
          } on Object {
            if (!_isCurrentGeneration(generation)) return;
            info = await client.playPart(bvid: widget.bvid, cid: part.cid);
          }
        } else {
          info = await client.playPart(bvid: widget.bvid, cid: part.cid);
        }
        if (!_isCurrentGeneration(generation)) return;
        final handle = await kernel.create(
          config: PlayerConfig(name: 'vod', volume: _volume, muted: _effectivelyMuted),
          preferredBackend: ref.read(playerKernelBackendProvider).id,
        );
        if (!_isCurrentGeneration(generation)) {
          _releaseHandle(handle);
          return;
        }
        _attemptHandle = handle;
        _handle = handle;
        _bind(handle, generation);
        _holdSound();
        // A playing mini window belongs to the video the viewer just left; a
        // new one here supersedes it (its close path checkpoints the old one).
        FloatingVideoWindow.dismiss();
        // Apply the effective global/local mute before autoPlay can sound.
        await handle.setMute(muted: _effectivelyMuted);
        if (!_isCurrentGeneration(generation)) return;
        await _applyEngineOptions(handle);
        if (!_isCurrentGeneration(generation)) return;
        // What plays, and what the bar therefore says plays: the rendition at or
        // below the viewer's tier that this engine can be handed, named by the
        // answer's own list rather than by a table of ours.
        final picture = vodDashVideoOf(info, maxQuality: want);
        _openedQn = picture?.quality ?? info.servedQuality ?? want;
        _openedLabel = vodQualityLabel(info, _openedQn) ?? info.quality;
        final dash = vodDashSourceOf(info, maxQuality: want);
        _holdSound();
        await handle.setVolume(_volume);
        await handle.setMute(muted: _effectivelyMuted);
        if (!_isCurrentGeneration(generation)) return;
        if (dash != null) {
          _dashAudioActive = true;
          _beginAdapterAttempt(handle, generation);
          try {
            await handle.openMedia(dash, autoPlay: !_sleepStopped && !_routeCovered);
          } on Object catch (error) {
            if (error is! UnsupportedError && !isVodExternalAudioFailure('$error')) rethrow;
            final muxed = await _openMuxedPart(handle, part, generation, autoPlay: !_sleepStopped && !_routeCovered);
            if (muxed == null || !_isCurrentGeneration(generation)) return;
            info = muxed;
          }
        } else {
          await handle.open(_partSource(info, part), autoPlay: !_sleepStopped && !_routeCovered);
        }
        if (!_isCurrentGeneration(generation)) return;
        await handle.setVolume(_volume);
        await handle.setMute(muted: _effectivelyMuted);
        await handle.setRate(_speed);
        if (_audioOnly) await _applyAudioOnly(handle);
        final saved = intent.resume;
        // A saved position outranks the opening; a part watched for the first
        // time starts after it, when the viewer asked the player to step over.
        final opening = ref.read(vodPlaybackSettingsProvider).skipHeadTail ? _headSeconds : null;
        final seekTo = saved != null && saved > 5 ? saved : opening;
        if (seekTo != null && seekTo > 5) {
          await handle.seek(Duration(milliseconds: (seekTo * 1000).round()));
          if (saved != null && saved > 5) _noteResumed(saved);
        }
        if (!_isCurrentGeneration(generation)) return;
        await _settleRouteAutoplay(handle);
        // Publish the exact opened identity only after every opening option
        // succeeded; controls and history both read this identity.
        _openedIdentity = _identityOf(part);
        _openedGeneration = generation;
        _attemptHandle = null;
        _retryResume = null;
        setState(() {
          _play = info;
          _silent = info.silent;
          _opening = false;
        });
        if (_dashAudioFallbackPending) unawaited(_fallbackDashAudio(handle, generation));
        unawaited(_loadDanmaku(part.cid));
        unawaited(_loadExtra(part.cid));
        _giveInitialFocus();
      } on Object catch (error) {
        final stale = _attemptHandle ?? _handle;
        _handle = null;
        _attemptHandle = null;
        _openedIdentity = null;
        _openedGeneration = 0;
        _clearTransportSubscriptions();
        if (stale != null) _releaseHandle(stale);
        if (!mounted || _disposed) return;
        final retryPart = fallback ?? part;
        _retryResume = retryPart.cid == part.cid ? intent.resume : null;
        setState(() {
          _part = retryPart;
          _opening = false;
          _play = null;
          _silent = false;
          _transport = null;
          _dragSeconds = null;
          _openedLabel = null;
          _error = error is VodFailure ? error.message : '$error';
        });
      }
    }
  }

  /// Opens the muxed answer on the same handle after a DASH compatibility
  /// failure. The caller keeps ownership of the generation and publishes the
  /// returned answer only after every restored option has succeeded.
  Future<VodPlayInfo?> _openMuxedPart(
    PlayerHandle handle,
    VodPart part,
    int generation, {
    required bool autoPlay,
    Duration? resume,
  }) async {
    if (!_isCurrentGeneration(generation) || !identical(_handle, handle)) return null;
    _beginAdapterAttempt(handle, generation);
    _dashAudioActive = false;
    _dashAudioFallbackTried = true;
    _dashAudioFallbackPending = false;
    final info = await ref.read(vodClientProvider).playPart(bvid: widget.bvid, cid: part.cid, dash: false);
    if (!_isCurrentGeneration(generation) || !identical(_handle, handle)) return null;
    _openedQn = info.servedQuality ?? _openedQn;
    _openedLabel = info.quality;
    _holdSound();
    await handle.setVolume(_volume);
    await handle.setMute(muted: _effectivelyMuted);
    await handle.setRate(_speed);
    if (!_isCurrentGeneration(generation) || !identical(_handle, handle)) return null;
    await handle.open(_partSource(info, part), autoPlay: autoPlay);
    if (!_isCurrentGeneration(generation) || !identical(_handle, handle)) return null;
    await handle.setVolume(_volume);
    await handle.setMute(muted: _effectivelyMuted);
    await handle.setRate(_speed);
    if (_audioOnly) await _applyAudioOnly(handle);
    if (resume != null && resume > Duration.zero) {
      await handle.seek(resume);
    }
    return _isCurrentGeneration(generation) && identical(_handle, handle) ? info : null;
  }

  /// Tries alternate audio addresses without lowering the DASH picture, then
  /// falls back to a muxed source. Errors during the first open wait for its
  /// identity; stale sessions never touch the new handle.
  Future<void> _fallbackDashAudio(PlayerHandle handle, int generation) async {
    final part = _partOf(_openedIdentity) ?? _part;
    if (!_isCurrentGeneration(generation) ||
        !identical(_handle, handle) ||
        !_dashAudioActive ||
        _dashAudioFallbackTried ||
        part == null) {
      return;
    }
    final position = _transport?.position ?? Duration.zero;
    final autoPlay = !_sleepStopped && !_routeCovered && (handle.playIntent ?? _transport?.isPlaying ?? true);
    _dashAudioFallbackPending = false;
    setState(() {
      _error = null;
      _opening = true;
    });
    try {
      final dash = _play;
      if (dash != null) {
        final audioUrls = vodDashAudioUrls(dash);
        while (_dashAudioUrlIndex + 1 < audioUrls.length && _isCurrentGeneration(generation)) {
          final source = vodDashSourceOf(dash, maxQuality: _openedQn, audioUrl: audioUrls[++_dashAudioUrlIndex]);
          if (source == null) break;
          _holdSound();
          await handle.setVolume(_volume);
          await handle.setMute(muted: _effectivelyMuted);
          await handle.setRate(_speed);
          if (!_isCurrentGeneration(generation) || !identical(_handle, handle)) return;
          _beginAdapterAttempt(handle, generation);
          try {
            await handle.openMedia(source, autoPlay: autoPlay);
          } on Object catch (error) {
            if (error is UnsupportedError) break;
            if (isVodExternalAudioFailure('$error')) continue;
            rethrow;
          }
          if (!_isCurrentGeneration(generation) || !identical(_handle, handle)) return;
          await handle.setVolume(_volume);
          await handle.setMute(muted: _effectivelyMuted);
          await handle.setRate(_speed);
          if (_audioOnly) await _applyAudioOnly(handle);
          if (position > Duration.zero) await handle.seek(position);
          await _settleRouteAutoplay(handle);
          if (!_dashAudioFallbackPending) {
            if (!mounted || !_isCurrentGeneration(generation)) return;
            setState(() => _opening = false);
            if (_pendingPart != null) unawaited(_drainPartOpens());
            return;
          }
          _dashAudioFallbackPending = false;
        }
      }
      final info = await _openMuxedPart(handle, part, generation, autoPlay: autoPlay, resume: position);
      if (info == null || !_isCurrentGeneration(generation)) return;
      await _settleRouteAutoplay(handle);
      if (!mounted) return;
      setState(() {
        _play = info;
        _silent = info.silent;
        _opening = false;
      });
      if (_pendingPart != null) unawaited(_drainPartOpens());
    } on Object catch (error) {
      if (!_isCurrentGeneration(generation) || !identical(_handle, handle) || !mounted) return;
      setState(() {
        _opening = false;
        _error = error is VodFailure ? error.message : '$error';
      });
      if (_pendingPart != null) unawaited(_drainPartOpens());
    }
  }

  /// The flat source of a muxed answer: the shape a single-URL engine opens,
  /// and the fallback when the DASH pair is unsupported.
  PlayerSource _partSource(VodPlayInfo info, VodPart part) {
    final uri = Uri.parse(info.url);
    return PlayerSource.of(
      id: SourceId('vod:${widget.bvid}:${part.cid}:${DateTime.now().microsecondsSinceEpoch}'),
      uri: uri,
      type: SourceType.remote,
      protocol: SourceProtocol.fromScheme(uri.scheme),
      format: SourceFormat.fromUri(uri),
      headers: info.headers.isEmpty ? null : SourceHeaders(info.headers),
      title: _detail?.title ?? part.title,
    );
  }

  void _bind(PlayerHandle handle, int generation) {
    _clearTransportSubscriptions();
    _geometrySub = handle.geometryController.state.listen((state) {
      if (!_isCurrentGeneration(generation)) return;
      final size = state.geometry.videoSize;
      if (size.width <= 0 || size.height <= 0) return;
      _aspectRatio = size.width / size.height;
      // The fullscreen and compact-window drivers shape their surfaces from
      // the picture's size. VOD used to feed them nothing, so the compact
      // window kept the config's 16:9 and never locked to the video.
      ref.read(fullscreenDriverProvider).onVideoSize(size.width, size.height);
      ref.read(pipDriverProvider).onVideoSize(size.width, size.height);
    });
    _transportSub = handle.playbackStream.listen((state) {
      if (!_isCurrentGeneration(generation)) return;
      setState(() {
        _transport = state;
        // A recovered engine keeps playing; the notice belongs to the
        // failure that stopped it, not to a session that healed.
        if (state.isPlaying) _error = null;
      });
      _syncSubtitle(state.position);
      _watchTail();
      if (state.isPlaying) {
        _scheduleHide();
        if (_routeCovered) unawaited(_pauseForRoute(handle));
      }
      if (_openedGeneration == generation && _openedIdentity != null) _saveProgress();
    });
    _listenAdapterEvents(handle, generation, 0);
    // The engine's clock follows the new handle: play, pause, seek and rate
    // all reach the timeline through this one binding.
    _danmakuBinding = DanmakuPlayerBinding.forHandle(controller: _barrage, handle: handle)..attach();
  }

  void _beginAdapterAttempt(PlayerHandle handle, int generation) {
    unawaited(_eventSub?.cancel() ?? Future<void>.value());
    _dashAudioFallbackPending = false;
    _listenAdapterEvents(handle, generation, ++_adapterAttempt);
  }

  void _listenAdapterEvents(PlayerHandle handle, int generation, int attempt) {
    _eventSub = handle.adapterEvents.listen((event) {
      if (!_isCurrentGeneration(generation) || attempt != _adapterAttempt) return;
      switch (event) {
        case final PlayerAdapterErrorEvent error:
          if (isVodExternalAudioFailure(error.message) && _dashAudioActive && !_dashAudioFallbackTried) {
            _dashAudioFallbackPending = true;
            if (!_opening) unawaited(_fallbackDashAudio(handle, generation));
          } else {
            setState(() => _error = error.message);
          }
        case PlayerAdapterCompleted():
          if (_openedGeneration == generation && _openedIdentity != null) unawaited(_handleFinished());
        default:
          break;
      }
    });
  }

  /// Reads [cid]'s danmaku track and puts it on the engine's timeline; a part
  /// with no readable track plays without one.
  Future<void> _loadDanmaku(int cid) async {
    if (cid <= 0) return;
    try {
      // Danmaku reads the web protobuf/XML track in both interfaces — the
      // reference's own App path does the same; only the detail and the
      // playback ladder switch.
      final xml = await ref.read(vodClientProvider).danmakuXml(cid);
      if (!mounted || _disposed || _partOf(_openedIdentity)?.cid != cid) return;
      final entries = BilibiliDanmakuXml.decode(xml);
      final items = [for (final entry in entries) BarrageItemMapper.toItem(entry.toMessage(), at: entry.time)];
      _barrage
        ..clear()
        ..loadTimeline(items)
        ..seekTo(_transport?.position ?? Duration.zero);
      _danmakuEntries = entries;
      _danmakuCid = cid;
    } on Object {
      // The picture never depends on a comment track.
    }
  }

  /// What a part's end leads to — the reference's 播放结束动作. The engine
  /// already sits on the last frame, so leaving it alone is the "pause"
  /// choice; the others move the page.
  Future<void> _handleFinished() async {
    if (_finished || _playableHandle == null) return;
    _finished = true;
    final parts = _detail?.parts ?? const <VodPart>[];
    final index = parts.indexWhere((part) => _identityOf(part) == _openedIdentity);
    final next = index >= 0 && index + 1 < parts.length ? parts[index + 1] : null;
    _archiveCompleted = next == null;
    _saveProgress(force: true, markDone: _archiveCompleted);
    if (next != null) {
      final detail = _detail;
      final duration = _transport?.duration ?? next.duration ?? Duration.zero;
      unawaited(
        _historyNotifier.save(
          bvid: widget.bvid,
          cid: next.cid,
          seconds: 0,
          title: detail?.title ?? next.title,
          cover: detail?.coverUrl,
          uploader: detail?.uploader,
          durationSeconds: duration.inMilliseconds / 1000,
        ),
      );
      _nextPartCheckpointPending = true;
    }
    switch (ref.read(vodPlaybackSettingsProvider).finish) {
      case VodFinishAction.pause:
        break;
      case VodFinishAction.nextPart:
        final parts = _detail?.parts ?? const <VodPart>[];
        final index = parts.indexWhere((part) => _identityOf(part) == _openedIdentity);
        // The step forward is announced and counted, so a viewer who wants
        // this part again — or is not done with the last frame — can stop it.
        if (index >= 0 && index + 1 < parts.length) _startCountdown(parts[index + 1]);
      case VodFinishAction.exit:
        if (mounted) context.pop();
      case VodFinishAction.playRelated:
        final next = _relatedPool.isEmpty ? null : _relatedPool.first;
        if (next == null) return;
        final bvid = next.bvid ?? next.id;
        if (bvid.isEmpty) return;
        unawaited(context.push('/vod/$bvid'));
    }
  }

  /// The part [direction] steps from the one playing, or null at either end of
  /// the list. A serial is watched in both directions — back to the part whose
  /// point was quoted, forward to the next — so the bar's two step buttons
  /// are one question asked twice.
  VodPart? _partStepped(int direction) {
    if (_playableHandle == null) return null;
    final parts = _detail?.parts ?? const <VodPart>[];
    final index = parts.indexWhere((part) => _identityOf(part) == _openedIdentity) + direction;
    if (index < 0 || index >= parts.length) return null;
    return parts[index];
  }

  /// Whether the step exists: the bar draws a step button only where there is
  /// a part to step to.
  bool get _hasNextPart => _partStepped(1) != null;

  bool get _hasPreviousPart => _partStepped(-1) != null;

  /// Opens the part one step away — the bar's step, the sequential twin of
  /// the shelf's jump and of the finish action's own next part.
  void _openSteppedPart(int direction) {
    final target = _partStepped(direction);
    if (target == null) return;
    unawaited(_openPart(target, resume: _resumeFor(target)));
  }

  void _retryOpen() {
    final part = _part ?? _detail?.parts.firstOrNull;
    if (part == null) return;
    final resume = _retryResume ?? _resumeFor(part);
    unawaited(_openPart(part, resume: resume));
  }

  Future<void> _togglePlay() async {
    final handle = _playableHandle;
    if (handle == null) return;
    final playing = _transport?.isPlaying ?? false;
    if (!playing && _sleepStopped) {
      _sleepStopped = false;
      if (mounted) setState(() {});
    }
    try {
      if (playing) {
        await handle.pause();
      } else {
        _holdSound();
        await handle.play();
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _seekTo(double seconds) async {
    final handle = _playableHandle;
    if (handle == null) return;
    try {
      await handle.seek(Duration(milliseconds: (seconds * 1000).round()));
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _setMuted({required bool muted}) async {
    final handle = _playableHandle;
    if (!muted && _globalMute) {
      // The global mute overrides this page's own choice; using the unmute
      // button clears it rather than silently doing nothing.
      _globalMute = false;
      unawaited(ref.read(playbackSettingsProvider.notifier).setGlobalMute(value: false));
    }
    if (mounted) setState(() => _muted = muted);
    if (handle == null) return;
    try {
      await handle.setMute(muted: _effectivelyMuted);
    } on Object catch (_) {
      // A refused mute is not a playback failure.
    }
  }

  Future<void> _applyGlobalMute() async {
    if (!mounted || _disposed) return;
    final handle = _handle ?? _attemptHandle;
    if (handle == null) return;
    try {
      await handle.setMute(muted: _effectivelyMuted);
    } on Object {
      // A refused mute is not a playback failure.
    }
  }

  /// The engine options this page keeps for every part and handle:
  /// hardware decoding and the player proxy.
  List<EngineOption> _storedEngineOptions() => playerStoredEngineOptions(
    hardwareDecoding: ref.read(playbackSettingsProvider).hardwareDecoding,
    tuning: ref.read(playerTuningProvider),
    proxy: ref.read(playerProxyProvider),
  );

  Future<void> _applyEngineOptions(PlayerHandle handle, {List<EngineOption> extra = const []}) async {
    try {
      await handle.applyEngineOptions(<EngineOption>[..._storedEngineOptions(), ...extra]);
    } on Object {
      // A refused engine option is not a playback failure.
    }
  }

  /// A custom-output or driver change reaches the running part: the stored
  /// options feed the next part, the handle gets them now, and a changed
  /// video/audio output rebuilds the render context in place (the open part
  /// and position are preserved by the handle). [playerPresetTransitionOptions]
  /// clears the previous recipe's keys when only the preset changed.
  Future<void> _applyTuning(PlayerTuning? previous, PlayerTuning next) async {
    final handle = _playableHandle;
    if (handle == null) return;
    await _applyEngineOptions(
      handle,
      extra: previous == null ? const <EngineOption>[] : playerPresetTransitionOptions(previous, next),
    );
    if (previous == null || !playerOutputChanged(previous, next)) return;
    try {
      await handle.rebuildEngine(reason: 'video output settings changed');
    } on Object {
      // A rebuild the engine refused must not fail the page.
    }
  }

  Future<void> _setVolume(double volume) async {
    final handle = _playableHandle;
    if (handle == null) return;
    setState(() => _volume = volume);
    // The module remembers it: the next part opens here.
    unawaited(ref.read(modulePlaybackSettingsProvider(PlayerModule.vod).notifier).setVolume(volume));
    try {
      await handle.setVolume(volume);
    } on Object catch (_) {
      // Same as mute.
    }
  }

  /// Answers a gesture on the picture with the figure it moved, and lets the
  /// answer settle away a moment after the last move — the room's rule, so a
  /// viewer learns one gesture and finds the same feedback on both players.
  void _showGesture(VodGestureKind kind, String value, {String? note}) {
    _gestureTimer?.cancel();
    setState(() {
      _gestureKind = kind;
      _gestureValue = value;
      _gestureNote = note;
    });
    _gestureTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _gestureKind = null);
    });
  }

  /// Asks the display what it will take. A display that will not write has no
  /// brightness half, so that half stays the volume rather than a gesture that
  /// answers nothing.
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
        if (value != null) _brightness = value.toDouble().clamp(0.0, 100.0);
      });
    } on Object {
      // A display that will not answer simply has no brightness half.
      if (mounted) setState(() => _brightnessWritable = false);
    }
  }

  /// A vertical drag on the picture: the right half is the volume, the left
  /// half the screen's brightness — where the display takes the write.
  void _beginPictureDrag(double xFraction) {
    if (_brightnessWritable == true && xFraction < 0.5) {
      _dragIsBrightness = true;
      _dragBrightness = _brightness;
      _showGesture(VodGestureKind.brightness, '${_brightness.round()}%');
      return;
    }
    _dragIsBrightness = false;
    _dragVolume = _volume;
    _showGesture(VodGestureKind.volume, '${(_volume * 100).round()}%');
  }

  void _dragPictureBy(double delta) {
    if (_dragIsBrightness) {
      // The same travel as the volume: a full-height drag crosses the range.
      final next = (_dragBrightness - delta / 2.2).clamp(0.0, 100.0);
      _dragBrightness = next;
      _showGesture(VodGestureKind.brightness, '${next.round()}%');
      // A native write only when the whole percent moved: a drag reports a
      // delta per frame, and the display takes one value per percent.
      if (next.round() != _brightness.round()) {
        _brightness = next.round().toDouble();
        unawaited(
          _screenBrightness
              .setBrightness(_brightness.round(), scope: _brightnessScope)
              .catchError((Object _) => _brightness.round()),
        );
      }
      return;
    }
    final next = (_dragVolume - delta / 220).clamp(0.0, 1.0);
    _dragVolume = next;
    _showGesture(VodGestureKind.volume, '${(next * 100).round()}%');
    unawaited(_setVolume(next));
  }

  /// A wheel step takes the viewer's own share of the range (the 画质与音频
  /// setting) and answers with the same chip a drag uses. The seek line
  /// answers the wheel too, so the step only moves over the picture.
  void _wheelVolume(double delta) {
    if (_playableHandle == null) return;
    final step = ref.read(playbackSettingsProvider).volumeWheelStepPercent / 100;
    final next = (_volume + (delta > 0 ? -step : step)).clamp(0.0, 1.0);
    _showGesture(VodGestureKind.volume, '${(next * 100).round()}%');
    unawaited(_setVolume(next));
  }

  /// Steps the picture by [seconds] and says where it landed.
  Future<void> _stepSeek(double seconds) async {
    final transport = _transport;
    if (transport == null || _playableHandle == null) return;
    final total = transport.duration.inMilliseconds / 1000;
    var target = transport.position.inMilliseconds / 1000 + seconds;
    if (target < 0) target = 0;
    if (total > 0 && target > total) target = total;
    _showGesture(
      seconds < 0 ? VodGestureKind.seekBack : VodGestureKind.seekForward,
      vodDurationText(Duration(seconds: target.round())),
      note: '${seconds < 0 ? '-' : '+'}${seconds.abs().round()}',
    );
    await _seekTo(target);
  }

  /// The keyboard's step, which grows while the key keeps coming: five
  /// seconds once, then ten, then twenty, so a long skip is one key press.
  void _keySeek(double sign) {
    final now = DateTime.now();
    final chained = _lastSeekKey != null && now.difference(_lastSeekKey!) < const Duration(milliseconds: 900);
    final step = chained ? (_seekStep * 2).clamp(5.0, 30.0) : 5.0;
    _seekStep = step;
    _lastSeekKey = now;
    unawaited(_stepSeek(step * sign));
  }

  /// A double tap on the picture: either side steps ten seconds, the middle
  /// plays or pauses. The sides answer rather than the whole picture because a
  /// viewer who wants the part back taps where the line already went.
  void _doubleTapAt(VodTapSide side) {
    _wake();
    switch (side) {
      case VodTapSide.left:
        unawaited(_stepSeek(-_doubleTapStep));
      case VodTapSide.right:
        unawaited(_stepSeek(_doubleTapStep));
      case VodTapSide.middle:
        unawaited(_togglePlay());
    }
  }

  /// A horizontal drag on the picture walks the part: a full sweep of its
  /// width is the whole length, so the drag says the same thing on a phone's
  /// picture and on a desktop's. The seek itself waits for the finger, and the
  /// chip carries the time it would land on.
  void _scrubBy(double delta, double width) {
    if (_playableHandle == null) return;
    final transport = _transport;
    if (transport == null || width <= 0) return;
    final total = transport.duration.inMilliseconds / 1000;
    if (total <= 0) return;
    _scrubFrom ??= transport.position;
    _scrubWalked += delta / width * total;
    var target = _scrubFrom!.inMilliseconds / 1000 + _scrubWalked;
    if (target < 0) target = 0;
    if (target > total) target = total;
    _scrubSeconds = target;
    _showGesture(
      VodGestureKind.seek,
      vodDurationText(Duration(seconds: target.round())),
      note: '${_scrubWalked < 0 ? '-' : '+'}${_scrubWalked.abs().round()}',
    );
  }

  /// Seeks once, where the drag left the picture — or nowhere, when the drag
  /// was taken away by something else rather than let go.
  Future<void> _endScrub(bool committed) async {
    final target = committed ? _scrubSeconds : null;
    _resetScrub();
    if (target == null) return;
    await _seekTo(target);
  }

  /// Lets go of the drag's bookkeeping, so a cancelled gesture cannot leave a
  /// start point for the next one to read.
  void _resetScrub() {
    _scrubFrom = null;
    _scrubWalked = 0;
    _scrubSeconds = null;
  }

  /// A held picture runs faster until the finger lifts, at the rate the
  /// station's setting names; the part's own rate comes back with the hold.
  Future<void> _beginSpeedHold() async {
    final handle = _playableHandle;
    if (handle == null || _speedHeld) return;
    _speedHeld = true;
    _speedBeforeHold = _speed;
    final boosted = ref.read(vodPlaybackSettingsProvider).longPressSpeed;
    // The words are read before the engine is asked: the chip answers on the
    // frame the hold started on, not on whatever is under the pointer after.
    final note = context.t.vod.gestureSpeedHold;
    setState(() => _speed = boosted.value);
    try {
      await handle.setRate(boosted.value);
    } on Object {
      // A rate the engine refused is not a reason to fail the hold.
    }
    _showGesture(VodGestureKind.speed, boosted.label, note: note);
  }

  /// The hold's two halves, in the shape the gesture surface reports them.
  void _speedHold(bool held) => unawaited(held ? _beginSpeedHold() : _endSpeedHold());

  Future<void> _endSpeedHold() async {
    if (!_speedHeld) return;
    _speedHeld = false;
    _gestureTimer?.cancel();
    setState(() {
      _speed = _speedBeforeHold;
      _gestureKind = null;
    });
    final handle = _playableHandle;
    if (handle == null) return;
    try {
      await handle.setRate(_speedBeforeHold);
    } on Object {
      // Same as the hold itself.
    }
  }

  /// The current part's live download row, projected to the fields the
  /// over-the-bar pill reads: a record compares structurally, so a tick
  /// from some other task in the queue does not rebuild this page.
  ({VodDownloadPhase phase, double? progress, String id})? _partDownload() {
    final bvid = widget.bvid;
    final cid = _part?.cid ?? 0;
    return ref.watch(
      vodDownloadsProvider.select((items) {
        final item = vodDownloadOf(items, bvid, cid);
        if (item == null) return null;
        return (phase: item.phase, progress: item.progress, id: item.id);
      }),
    );
  }

  /// Reads the part's own extras: its marked moments, its subtitle tracks and
  /// its scrub filmstrip. The station keeps the last two for a signed-in
  /// viewer, so an empty answer is the ordinary one and the surface simply
  /// shows less rather than failing.
  Future<void> _loadExtra(int cid) async {
    if (cid <= 0) return;
    try {
      final extra = await ref.read(vodClientProvider).playerExtra(bvid: widget.bvid, cid: cid);
      if (!mounted || _disposed || _partOf(_openedIdentity)?.cid != cid) return;
      setState(() => _extra = extra);
    } on Object {
      // The extras are garnish: a failed answer leaves the surface without
      // them, the way an empty one would.
    }
  }

  /// The archive's opening and ending, kept on this device: Bilibili marks
  /// them for its own cinema titles and nothing at all for a posted archive,
  /// so the points a viewer sets here are the only ones there are. The store
  /// seam lives on the history controller; the page keeps only the marks.
  void _readSkipPoints(int cid) {
    final points = ref.read(vodHistoryProvider.notifier).skipPoints(widget.bvid, cid: cid);
    _headSeconds = points?.headSeconds;
    _tailSeconds = points?.tailSeconds;
  }

  Future<void> _writeSkipPoints() {
    final cid = _partOf(_openedIdentity)?.cid ?? _part?.cid;
    if (cid == null) return Future<void>.value();
    return ref
        .read(vodHistoryProvider.notifier)
        .saveSkipPoints(widget.bvid, cid: cid, headSeconds: _headSeconds, tailSeconds: _tailSeconds);
  }

  /// Marks the moment the picture stands on as the end of its opening, or the
  /// start of its ending.
  Future<void> _setHeadHere() async {
    final position = _transport?.position;
    if (position == null) return;
    setState(() => _headSeconds = position.inMilliseconds / 1000);
    await _writeSkipPoints();
  }

  Future<void> _setTailHere() async {
    final transport = _transport;
    if (transport == null || transport.duration.inMilliseconds <= 0) return;
    setState(() => _tailSeconds = transport.position.inMilliseconds / 1000);
    await _writeSkipPoints();
  }

  Future<void> _clearSkipPoints() async {
    setState(() {
      _headSeconds = null;
      _tailSeconds = null;
    });
    await _writeSkipPoints();
  }

  /// The ending is where the part stops for the viewer: the finish action runs
  /// there rather than at the last frame, so a long outro is not watched twice.
  void _watchTail() {
    if (!ref.read(vodPlaybackSettingsProvider).skipHeadTail || _finished || _opening) return;
    final tail = _tailSeconds;
    final transport = _transport;
    if (tail == null || tail <= 0 || transport == null) return;
    if (transport.position.inMilliseconds / 1000 >= tail) unawaited(_handleFinished());
  }

  /// Says where a saved position put the picture, and offers the way back to
  /// its start while the words stand.
  void _noteResumed(double seconds) {
    if (!mounted) return;
    _resumedTimer?.cancel();
    setState(() => _resumedAt = seconds);
    _resumedTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _resumedAt = null);
    });
  }

  /// Puts the part back at its first frame, and stops stepping over the
  /// opening for the rest of this one.
  Future<void> _playFromStart() async {
    _resumedTimer?.cancel();
    setState(() => _resumedAt = null);
    await _seekTo(0);
  }

  /// Runs the station's own countdown before the next part opens, so the step
  /// forward can be stopped while it is still a plan.
  void _startCountdown(VodPart next) {
    _countdownTimer?.cancel();
    setState(() => _countdown = 5);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final left = _countdown - 1;
      if (left <= 0) {
        timer.cancel();
        setState(() => _countdown = 0);
        unawaited(_openPart(next, resume: _resumeFor(next)));
        return;
      }
      setState(() => _countdown = left);
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    if (!mounted) return;
    setState(() => _countdown = 0);
  }

  /// Chooses the subtitle track, or none. A track's words are asked when it is
  /// picked rather than with the list, because a part may offer several.
  Future<void> _selectSubtitle(VodSubtitleTrack? track) async {
    if (track == null) {
      setState(() {
        _subtitleTrack = null;
        _subtitleLines = const [];
        _subtitleText = null;
      });
      return;
    }
    setState(() {
      _subtitleTrack = track;
      _subtitleLines = const [];
      _subtitleText = null;
    });
    try {
      final lines = await ref.read(vodClientProvider).subtitleLines(track.url);
      if (!mounted || _subtitleTrack?.id != track.id) return;
      setState(() => _subtitleLines = lines);
    } on Object {
      // A track that will not answer leaves the picture without words rather
      // than failing the part.
      if (mounted) {
        setState(() {
          _subtitleTrack = null;
          _subtitleLines = const [];
        });
      }
    }
  }

  /// The line the picture is on. The cursor walks forward with the position, so
  /// only a seek backwards reads the list from its top.
  void _syncSubtitle(Duration position) {
    final lines = _subtitleLines;
    if (lines.isEmpty) {
      if (_subtitleText != null) setState(() => _subtitleText = null);
      return;
    }
    var index = _subtitleCursor.clamp(0, lines.length - 1);
    if (lines[index].start > position) index = 0;
    while (index < lines.length && lines[index].end < position) {
      index++;
    }
    _subtitleCursor = index;
    final line = index < lines.length ? lines[index] : null;
    final shown = line != null && line.start <= position ? line.text : null;
    if (shown != _subtitleText && mounted) setState(() => _subtitleText = shown);
  }

  /// 音频模式: keep the sound, put the picture away.
  Future<void> _toggleAudioOnly() async {
    setState(() => _audioOnly = !_audioOnly);
    final handle = _playableHandle;
    if (handle == null) return;
    await _applyAudioOnly(handle);
  }

  /// Writes the mode to [handle]; a kernel that has none leaves the picture up
  /// rather than failing the part switch it is applied on.
  Future<void> _applyAudioOnly(PlayerHandle handle) async {
    try {
      await handle.setAudioOnly(audioOnly: _audioOnly);
    } on Object {
      // The switch says what was asked; the next handle gets the same try.
    }
  }

  /// The sleep timer's end: the part pauses where it stands, said with the
  /// room's own toast.
  void _onSleepFire() {
    _sleepStopped = true;
    _backgroundPausedHandle = null;
    _routePauseGeneration++;
    _routePausedHandleId = null;
    _routePause = null;
    _routeResumeWhenReady = false;
    _routeAutoplayRequested = false;
    unawaited(_playableHandle?.pause() ?? Future<void>.value());
    if (mounted) showDsToast(context: context, title: context.t.player.sleepDone);
  }

  /// Keeps the frame the part is showing in the viewer's screenshot folder, and
  /// says how it went — a capture that fails silently reads as a dead button.
  Future<void> _screenshot() async {
    final handle = _playableHandle;
    if (handle == null) return;
    final file = await capturePlayerFrame(handle, ref.read(appPathsProvider).screenshots, prefix: 'pure_live_vod');
    if (!mounted) return;
    final t = context.t;
    showDsToast(
      context: context,
      title: file == null ? t.player.screenshotFailed : t.player.screenshotSaved(name: file.uri.pathSegments.last),
      status: file == null ? DsStatus.danger : DsStatus.success,
    );
  }

  /// Sends the part's own address to a DLNA receiver. Bilibili's CDN answers
  /// only a request that carries the referer, so the headers travel with it —
  /// a TV that cannot send them surfaces a cast failure, which is the truth.
  Future<void> _cast() async {
    final info = _play;
    if (info == null) return;
    await showCastUriDialog(
      context,
      url: info.url,
      title: _detail?.title ?? _partOf(_openedIdentity)?.title,
      headers: info.headers,
    );
  }

  Future<void> _setSpeed(double speed) async {
    final handle = _playableHandle;
    if (handle == null) return;
    setState(() => _speed = speed);
    try {
      await handle.setRate(speed);
    } on Object catch (_) {
      // Same as mute.
    }
  }

  /// One step along the station's own rate ladder, the keyboard's way through
  /// it: the choices the panel lists, walked in [direction] from where the
  /// picture stands now.
  Future<void> _stepSpeed(int direction) async {
    const choices = VodSpeedChoice.values;
    final current = choices.indexOf(VodSpeedChoice.nearest(_speed));
    final next = (current + (direction > 0 ? 1 : -1)).clamp(0, choices.length - 1);
    if (choices[next] == choices[current]) return;
    final rate = choices[next].value;
    _showGesture(VodGestureKind.speed, choices[next].label);
    await _setSpeed(rate);
  }

  Future<void> _toggleFullscreen() async {
    final handle = _playableHandle;
    if (handle == null) return;
    await ref.read(roomPresentationProvider.notifier).toggleFullscreen(handle.id);
  }

  /// The window variant of the same verb, the desktop's own: the picture
  /// fills the app window and the window stays a window. It answers to its
  /// own button only — neither fullscreen exits the other as a side effect.
  Future<void> _toggleWindowFullscreen() async {
    final handle = _playableHandle;
    if (handle == null) return;
    await ref.read(roomPresentationProvider.notifier).toggleWindowFullscreen(handle.id);
  }

  Future<void> _togglePip() async {
    final handle = _playableHandle;
    if (handle == null) return;
    final accepted = await ref.read(roomPresentationProvider.notifier).togglePip(handle.id);
    if (accepted || !mounted) return;
    showDsToast(context: context, title: context.t.common.pipUnavailable);
  }

  /// Whether the 小窗 verb may show: the handle has a source to hand over
  /// (a still-opening picture has nothing to float) and no window-owning
  /// mode stands — the picture-in-picture small window already is a small
  /// window.
  bool get _miniWindowReady {
    // The 小窗 overlay belongs to the primary window: its root navigator
    // is the only one registered as the app's, so a secondary's handoff
    // would land its picture on the primary's overlay. Secondary windows
    // keep their own picture instead.
    if (!ref.read(isPrimaryWindowProvider)) return false;
    final handle = _playableHandle;
    return handle != null &&
        handle.source != null &&
        _presentationMode == PresentationMode.normal &&
        !FloatingVideoWindow.isShowing;
  }

  /// Hands the picture to the floating mini window and leaves: the window
  /// opens its own handle on the app-level kernel from this one's source,
  /// seeking where this one stopped, while the page pops back to whatever
  /// the viewer came from.
  Future<void> _enterMiniWindow() async {
    final handle = _playableHandle;
    final source = handle?.source;
    if (handle == null || source == null) return;
    _wake();
    final t = context.t;
    final backend = ref.read(playerKernelBackendProvider).id;
    final detail = _detail;
    final identity = _openedIdentity;
    final part = _partOf(identity);
    final duration = _transport?.duration ?? Duration.zero;
    final ok = await FloatingVideoWindow.show(
      FloatingVideoHandoff(
        title: detail?.title ?? part?.title ?? t.vod.opening,
        resume: handle.position,
        rate: handle.rate,
        muted: handle.muted,
        open: (kernel) => kernel.create(
          source: source,
          config: PlayerConfig(name: 'floating-video', playbackRate: handle.rate, muted: handle.muted),
          preferredBackend: backend,
        ),
        onClose: (position, {required reopen}) {
          // The page is gone by then; write the exact part handed over, not
          // whatever selection a later page state might name.
          if (identity != null && part != null && duration.inMilliseconds > 0 && position.inMilliseconds > 0) {
            unawaited(
              _historyNotifier.save(
                bvid: identity.bvid,
                cid: identity.cid,
                seconds: position.inMilliseconds / 1000,
                title: detail?.title ?? part.title,
                cover: detail?.coverUrl,
                uploader: detail?.uploader,
                durationSeconds: duration.inMilliseconds / 1000,
                completed: position.inMilliseconds >= duration.inMilliseconds - 5000,
              ),
            );
          }
          if (reopen) {
            final root = rootNavigatorKey.currentContext;
            if (root != null && root.mounted) {
              unawaited(root.push('/vod/${Uri.encodeComponent(widget.bvid)}'));
            }
          }
        },
      ),
    );
    if (!ok || !mounted || _disposed) return;
    // The window now carries the sound: this page goes quiet before it
    // pops, so the two never speak over each other.
    silencePlayer(handle);
    if (mounted && context.mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  void _leave() {
    final handle = _handle;
    // A phone's picture-in-picture window floats over the page; leaving the
    // page is the way out of it (the system owns its own close).
    if (handle != null &&
        ref.read(roomPresentationProvider.notifier).modeOwnsWindow(ref.read(roomPresentationProvider))) {
      unawaited(ref.read(roomPresentationProvider.notifier).exit(handle.id));
      return;
    }
    context.pop();
  }

  /// Passes the archive on: the share panel's shape here is the clipboard,
  /// the way the hongguo page passes a series on — a link and a word that it
  /// is on the clipboard.
  Future<void> _share() async {
    final detail = _detail;
    if (detail == null) return;
    await Clipboard.setData(ClipboardData(text: 'https://www.bilibili.com/video/${detail.bvid}'));
    if (!mounted) return;
    showDsToast(context: context, title: context.t.common.copied, status: DsStatus.success);
  }

  /// Collects the archive, or drops it; the station's 个人 page lists what
  /// this writes.
  Future<void> _toggleFavourite() async {
    final detail = _detail;
    if (detail == null) return;
    try {
      final added = await ref.read(vodFavouritesProvider.notifier).toggle(VodSavedVideo.ofDetail(detail));
      if (!mounted) return;
      showDsToast(
        context: context,
        title: added ? context.t.vod.saveAdded : context.t.vod.saveRemoved,
        status: DsStatus.success,
      );
    } on Object {
      if (!mounted) return;
      showDsToast(context: context, title: context.t.vod.saveFailed, status: DsStatus.danger);
    }
  }

  /// Flips the viewer's like on the archive on the picture; a refusal puts
  /// the pill back and says so.
  Future<void> _toggleLike() async {
    final detail = _detail;
    final aid = detail?.aid ?? 0;
    if (aid <= 0) return;
    try {
      await ref.read(vodLikeProvider(aid).notifier).toggle();
    } on Object {
      if (!mounted) return;
      showDsToast(context: context, title: context.t.vod.likeFailed, status: DsStatus.danger);
    }
  }

  /// Flips the viewer's follow of the uploader; a refusal puts the chip
  /// back and says so.
  Future<void> _toggleFollowUp() async {
    final mid = _detail?.uploaderMid ?? 0;
    if (mid <= 0) return;
    try {
      await ref.read(vodFollowUpProvider(mid).notifier).toggle();
    } on Object {
      if (!mounted) return;
      showDsToast(context: context, title: context.t.vod.followFailed, status: DsStatus.danger);
    }
  }

  ({int cid, double seconds})? _readProgress() => _historyNotifier.resumePoint(widget.bvid);

  /// Saves the part and position at most once every few seconds. The entry is
  /// also the history record the station's 个人 page reads, so it carries the
  /// archive's metadata; the end of an archive marks it finished instead of
  /// clearing it.
  void _saveProgress({bool force = false, bool markDone = false}) {
    // The next part's zero-second checkpoint owns the archive until it opens.
    if (_nextPartCheckpointPending) return;
    final part = _partOf(_openedIdentity);
    final transport = _transport;
    if (part == null || transport == null || _openedGeneration != _openGeneration) return;
    final total = transport.duration.inMilliseconds;
    final position = transport.position.inMilliseconds;
    if (total <= 0 || position <= 0) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastSave) < const Duration(seconds: 5)) return;
    _lastSave = now;
    final detail = _detail;
    unawaited(
      _historyNotifier.save(
        bvid: widget.bvid,
        cid: part.cid,
        seconds: position / 1000,
        title: detail?.title ?? part.title,
        cover: detail?.coverUrl,
        uploader: detail?.uploader,
        durationSeconds: total / 1000,
        completed: markDone || _archiveCompleted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(playbackSettingsProvider.select((settings) => settings.globalMute), (previous, next) {
      if (previous == next) return;
      if (mounted) setState(() => _globalMute = next);
      unawaited(_applyGlobalMute());
    });
    ref.listen(playerProxyProvider, (previous, next) {
      if (previous == next) return;
      final handle = _playableHandle;
      if (handle != null) unawaited(_applyEngineOptions(handle));
    });
    ref.listen(playbackSettingsProvider.select((settings) => settings.hardwareDecoding), (previous, next) {
      if (previous == next) return;
      final handle = _playableHandle;
      if (handle != null) unawaited(_applyEngineOptions(handle));
    });
    ref.listen(playerTuningProvider, (previous, next) {
      if (previous == next) return;
      unawaited(_applyTuning(previous, next));
    });
    // This archive's queue rows announce themselves: a finished part says
    // where it landed, a failed one says so — however the page was left.
    ref.listen(vodDownloadsProvider, (previous, next) {
      final before = {for (final item in previous ?? const <VodDownloadItem>[]) item.id: item.phase};
      for (final item in next) {
        if (item.bvid != widget.bvid || before[item.id] == item.phase) continue;
        if (!mounted) return;
        final t = context.t;
        if (item.phase == VodDownloadPhase.done) {
          showDsToast(
            context: context,
            title: t.player.downloadDone(name: item.fileName),
            status: DsStatus.success,
          );
        } else if (item.phase == VodDownloadPhase.failed) {
          // The reason belongs on the toast: "下载失败" with no cause reads as
          // the app's own confusion, and the row keeps it too.
          showDsToast(
            context: context,
            title: t.settings.downloadStatusFailed,
            description: item.error,
            status: DsStatus.danger,
          );
        }
      }
    });
    // Leaving fullscreen or PiP — by any hand, including the system's —
    // puts the keyboard back on the play button, whose node outlives both
    // surfaces.
    ref.listen(roomPresentationProvider, (previous, next) {
      if (previous == null || previous == PresentationMode.normal || next != PresentationMode.normal) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
          _playFocus.requestFocus();
        }
      });
    });
    // The room page's own rule, here too: a phone entering system fullscreen
    // asks the viewer's portrait policy which way it turns. The driver's exit
    // path puts the lock back.
    ref.listen(roomPresentationProvider, (previous, next) {
      if (next != PresentationMode.fullscreen || previous == PresentationMode.fullscreen) return;
      applyFullscreenOrientation(_screenOrientation, aspectRatio: _aspectRatio);
    });
    // The desktop's small window wears the shared chrome alone: it has no bar
    // for a catalogue to hang from and draws none. One left open on the way
    // in is put away there, rather than kept open where nothing shows it and
    // nothing closes it — and where, being open, it would hold the chrome up
    // for good.
    ref.listen(roomPresentationProvider, (previous, next) {
      if (next == PresentationMode.pip && _presentationNotifier.pipOwnsWindow) _closePanel();
    });
    final presentation = ref.watch(roomPresentationProvider);
    final presentationController = ref.read(roomPresentationProvider.notifier);
    final t = context.t;
    final detail = _detail;
    final colors = DsTheme.colorsOf(context);
    // Only a mode that owns the app's window replaces this page's layout; a
    // phone's picture-in-picture window floats over it.
    final immersive = presentationController.modeOwnsWindow(presentation);
    // The arrows mirror the room page: up and down take the wheel's step (the
    // 画质与音频 setting) toward the volume, left and right skip five seconds.
    // A TV keeps its arrows for focus; the remote drives the volume itself.
    final tv = ref.watch(platformRuntimeProvider).environment.runtime.formFactor == FormFactor.tv;
    if (immersive) {
      // The owned window keeps the keyboard its page had: Escape backs out of
      // the mode it sits in (the small window back to the page, fullscreen
      // back to the layout), I raises the stream's figures. The chrome's own
      // autofocus keeps the bindings live while the strip is up.
      return Scaffold(
        backgroundColor: colors.canvas,
        body: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): _leave,
            if (!tv)
              const SingleActivator(LogicalKeyboardKey.keyI): () =>
                  ref.read(playerStatsVisibleProvider.notifier).toggle(),
          },
          child: Focus(autofocus: true, child: _playerSurface(context, immersive: true)),
        ),
      );
    }
    final volumeStep = ref.watch(playbackSettingsProvider.select((settings) => settings.volumeWheelStepPercent)) / 100;
    void nudgeVolume(double delta) {
      _wake();
      _showGesture(VodGestureKind.volume, '${((_volume + delta).clamp(0.0, 1.0) * 100).round()}%');
      unawaited(_setVolume((_volume + delta).clamp(0.0, 1.0)));
    }

    return PlayerBarTier(
      tv: tv,
      child: CallbackShortcuts(
        bindings: {
          // A remote cannot tap the picture to raise the bar, so its transport
          // keys wake the chrome they drive.
          const SingleActivator(LogicalKeyboardKey.space): () {
            _wake();
            unawaited(_togglePlay());
          },
          const SingleActivator(LogicalKeyboardKey.keyF): () {
            _wake();
            unawaited(_toggleFullscreen());
          },
          // The window variant of the same verb, on the desktop's own chord.
          const SingleActivator(LogicalKeyboardKey.f11): () {
            _wake();
            unawaited(_toggleWindowFullscreen());
          },
          // The stream's own figures: the key every player answers to, over
          // the same panel the bar's menu item opens.
          if (!tv)
            const SingleActivator(LogicalKeyboardKey.keyI): () =>
                ref.read(playerStatsVisibleProvider.notifier).toggle(),
          const SingleActivator(LogicalKeyboardKey.escape): _leave,
          // While the bar is down a TV's arrows and OK have nothing to move
          // through, so they raise it; while it is up they stay with focus.
          if (tv && !_controlsVisible) ...{
            const SingleActivator(LogicalKeyboardKey.arrowUp): _wake,
            const SingleActivator(LogicalKeyboardKey.arrowDown): _wake,
            const SingleActivator(LogicalKeyboardKey.arrowLeft): _wake,
            const SingleActivator(LogicalKeyboardKey.arrowRight): _wake,
            const SingleActivator(LogicalKeyboardKey.select): _wake,
          },
          if (!tv) const SingleActivator(LogicalKeyboardKey.arrowUp): () => nudgeVolume(volumeStep),
          if (!tv) const SingleActivator(LogicalKeyboardKey.arrowDown): () => nudgeVolume(-volumeStep),
          // A held arrow keeps stepping, and each step in a row is bigger:
          // five seconds, then ten, then twenty, so reaching the middle of an
          // hour is one key rather than a hundred taps.
          if (!tv)
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
              _wake();
              _keySeek(-1);
            },
          if (!tv)
            const SingleActivator(LogicalKeyboardKey.arrowRight): () {
              _wake();
              _keySeek(1);
            },
          if (!tv)
            const SingleActivator(LogicalKeyboardKey.comma): () {
              _wake();
              unawaited(_stepSpeed(-1));
            },
          if (!tv)
            const SingleActivator(LogicalKeyboardKey.period): () {
              _wake();
              unawaited(_stepSpeed(1));
            },
          if (!tv)
            const SingleActivator(LogicalKeyboardKey.keyM): () {
              _wake();
              unawaited(_setMuted(muted: !_effectivelyMuted));
            },
        },
        child: Scaffold(
          backgroundColor: colors.canvas,
          // The page header is gone: the strip over the picture carries the
          // way back and the name, the room's own shape — the picture reads
          // from the page's first pixel.
          body: SafeArea(
            bottom: false,
            child: _loading && detail == null
                ? const _VideoSkeleton()
                : _error != null && detail == null
                ? Center(
                    child: DsEmptyState(
                      icon: const DsIcon(DsIcons.cloudOff),
                      title: Text(t.common.loadFailed),
                      description: Text(_error!),
                      actions: [DsButton(onPressed: () => unawaited(_load()), child: Text(t.vod.retry))],
                    ),
                  )
                : _body(context, detail, t),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, VodDetail? detail, Translations t) {
    if (detail == null) return const SizedBox.shrink();
    // 排版与直播间同一台机器，按窗口的形状判定（与平台无关）：矮窗（高
    // <480）横屏沉浸——满铺画面加覆盖条，页面内容退场，分P与画质都在
    // 条上；窄窗（宽 <600）竖屏沉浸——画面满宽贴顶；宽窗（≥840）舞台
    // 加可拖拽、可收起的侧栏。
    final windowSize = MediaQuery.sizeOf(context);
    final playbackLayout = PlaybackLayout.resolve(width: windowSize.width, height: windowSize.height);
    if (playbackLayout.landscapeImmersive) {
      return _playerSurface(context, immersive: false, fills: true);
    }
    final compact = playbackLayout.windowClass == PlaybackWindowClass.compact;
    final player = _playerSurface(context, immersive: false, flush: compact);
    final window = _relatedWindow;
    // The rail's cut of the same list reads in a 280–380px column, where the
    // page-width cover of 148 would leave the words sixty points of room.
    Widget relatedList({required bool compact}) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        for (final video in window)
          VodVideoRow(
            video: video,
            compact: compact,
            onOpen: () => unawaited(context.push('/vod/${video.bvid ?? video.id}')),
          ),
      ],
    );

    Widget related({required bool compact}) => window.isEmpty
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s12,
            children: [
              SectionHeader(
                title: t.vod.related,
                trailing: [
                  // The reference's rail turns the page of twenty.
                  if (_relatedPool.length > 20)
                    DsButton(
                      variant: DsButtonVariant.secondary,
                      size: DsSize.sm,
                      leading: const DsIcon(DsIcons.refreshCw, size: 14),
                      onPressed: _relatedBusy ? null : () => unawaited(_changeRelated()),
                      child: Text(t.vod.changeRelated),
                    ),
                ],
              ),
              relatedList(compact: compact),
            ],
          );
    // The parts shelf sits in the rail beside the picture on a wide window —
    // the episode strip the reference's own video page draws — and back under
    // the picture on a narrow one, where no rail exists. Related reads under
    // it there, one column: choose the next part first, then wander off.
    final parts = detail.parts.length > 1
        ? _PartsSection(
            parts: detail.parts,
            current: _part,
            onOpen: (part) => unawaited(_openPart(part, resume: _resumeFor(part))),
          )
        : null;
    final railRelated = related(compact: true);
    final rail = parts == null && window.isEmpty
        ? null
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: DsSpace.s16, children: [?parts, railRelated]);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kPlaybackWideBreakpoint;
        final info = _info(context, detail, t, showParts: parts == null || !wide);
        if (!wide) {
          if (compact) {
            // 竖屏沉浸（宽 <600）：画面满宽贴顶、直角贴边，文字内容留边距
            // ——参考机型的竖屏视频页。
            const gutter = EdgeInsets.symmetric(horizontal: DsSpace.s12);
            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: DsSpace.s24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: DsSpace.s20,
                children: [
                  player,
                  Padding(padding: gutter, child: info),
                  Padding(padding: gutter, child: related(compact: false)),
                ],
              ),
            );
          }
          final inset = LiveWindow.pageInset(constraints.maxWidth);
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s20,
              children: [player, info, related(compact: false)],
            ),
          );
        }
        // 宽窗（≥840）：舞台加可拖拽、可收起的侧栏——直播间聊天列同款的缝，
        // 收起后舞台的右缘留一扇门。
        final railMax = (constraints.maxWidth - _stageFloor).clamp(_railMin, _railMax);
        final railWidth = _railWidth.clamp(_railMin, railMax);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(DsSpace.s24, DsSpace.s12, DsSpace.s24, DsSpace.s24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: DsSpace.s16,
                      children: [player, info],
                    ),
                  ),
                  if (rail != null && !_railOpen)
                    VodRailDoor(label: t.vod.related, onOpen: () => setState(() => _railOpen = true)),
                ],
              ),
            ),
            if (rail != null && _railOpen) ...[
              ChatSplitter(
                width: railWidth,
                minWidth: _railMin,
                maxWidth: railMax,
                onResize: (value) => setState(() => _railWidth = value),
                onResizeEnd: (value) => setState(() => _railWidth = value),
                onReset: () => setState(() => _railWidth = _railDefault),
                label: t.vod.related,
              ),
              SizedBox(
                width: railWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s8, DsSpace.s8, DsSpace.s8, 0),
                      child: Row(
                        children: [
                          const Spacer(),
                          DsButton.icon(
                            variant: DsButtonVariant.ghost,
                            size: DsSize.sm,
                            onPressed: () => setState(() => _railOpen = false),
                            icon: const DsIcon(DsIcons.panelRightClose),
                            semanticLabel: t.common.previewCollapseList,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(DsSpace.s12, 0, DsSpace.s12, DsSpace.s24),
                        child: rail,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// The picture and its controls — read as a video, not as a stream.
  ///
  /// The bars follow the pointer: moving it over the picture brings them back,
  /// and a tap on a touch screen toggles them, while a playing part lets them
  /// settle away again. The gestures are the ones a video is watched with, the
  /// room's arrangement carried over where it already agrees with them: a
  /// horizontal drag anywhere on the picture scrubs, a vertical drag takes the
  /// volume on the right half and the screen's brightness on the left (where
  /// the display will take it), a double tap on either side steps ten seconds
  /// and on the middle plays or pauses, and a hold runs the part faster until
  /// the finger lifts. Each one answers with a chip naming the figure it moved.
  /// Under the picture the seek line says what has been watched, what the
  /// engine already holds and where the station marked a moment, and the
  /// pointer's bubble says where the picture would go. The rendition, the part
  /// list, the speed and the subtitles hang their catalogues from the bar as
  /// glass panels, the way the live room's strip does. [immersive] adds the way
  /// out and the title over the picture, since the page's own headline is gone
  /// there. The desktop's small window is the one owned mode that wears none
  /// of the strip and the bar: the shared small window's chrome stands over
  /// the same picture, under the same gestures.
  Widget _playerSurface(BuildContext context, {required bool immersive, bool fills = false, bool flush = false}) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final handle = _handle;
    final transport = _transport;
    final playing = transport?.isPlaying ?? false;
    _syncScreenWake(playing && ref.watch(keepScreenOnProvider));
    final detail = _detail;
    final playback = ref.watch(playbackSettingsProvider);
    final danmakuStyle = ref.watch(danmakuStyleProvider);
    final danmakuFps = ref.watch(danmakuEffectiveFpsProvider);
    // Locked, nothing rides the picture: the unlock pill on the right edge
    // is the whole chrome, the room's own rule.
    final showBar = !_locked && (_controlsVisible || !playing);
    // The desktop's small window wears the shared chrome alone: no strip, no
    // bar, no action column and no catalogue — the way back, the close, the
    // transport, the danmaku, the sound and the pin — the picture keeping its
    // gestures. A phone's picture-in-picture window is the system's and
    // floats over the page, which keeps every bit of its own chrome.
    final smallWindow =
        immersive && ref.watch(roomPresentationProvider) == PresentationMode.pip && _presentationNotifier.pipOwnsWindow;
    // The page's own chrome over the picture: the strip, the bar, the
    // picture's action column and the catalogues that hang from the bar.
    final barUp = showBar && !smallWindow;
    // The small window's foot is built here, in the page's own build, and
    // handed to the chrome below: the chrome is sized by the window and so is
    // built in the layout pass, where no provider is read. It is what the
    // page's bar says around its seek line — the download under way, the
    // part's one-time offers — over that line, the season page's own rule.
    final smallWindowFoot = smallWindow
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s4,
            children: [
              ?_downloadPill(t, theme),
              _vodSeekLayer(),
              for (final notice in _vodNotices(t)) Align(alignment: AlignmentDirectional.centerEnd, child: notice),
            ],
          )
        : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(immersive || fills || flush ? 0 : theme.radii.overlay),
      child: ColoredBox(
        color: colors.overlay,
        child: _PictureBox(
          immersive: immersive || fills,
          child: MouseRegion(
            onHover: (_) => _wake(),
            onExit: (_) => _scheduleHide(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (handle != null)
                  MediaPlayerView(handle: handle, fit: playback.fit.boxFit, backgroundColor: colors.overlay)
                else
                  const ColoredBox(color: Color(0xFF000000)),
                // The part's danmaku, on a clock the player's binding keeps
                // equal to the picture's; hidden while the layer is switched
                // off or no track loaded yet.
                if (handle != null && _danmakuCid > 0 && playback.danmakuVisible)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: FlameBarrageWidget(
                        config: playerBarrageConfig(
                          danmakuStyle,
                          danmakuFps,
                          family: resolvedFontFamily(danmakuStyle.fontFamily),
                        ),
                        emojiAtlas: EmojiAtlas.instance,
                        controller: _barrage,
                      ),
                    ),
                  ),
                // 音频模式 covers the frame rather than replacing the surface:
                // the part keeps playing, and the episode's name says what is
                // still running behind the card.
                if (_audioOnly && handle != null)
                  Positioned.fill(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        spacing: DsSpace.s8,
                        children: [
                          const DsIcon(DsIcons.headphones, size: 32, color: OnVideoColors.inkSubtle),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Text(
                              _partOf(_openedIdentity)?.title ?? _detail?.title ?? '',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.title.copyWith(color: OnVideoColors.foreground),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // The stream's own numbers, on the same session switch the room
                // and the preview use.
                if (handle case final player? when ref.watch(playerStatsVisibleProvider))
                  Positioned.fill(
                    child: IgnorePointer(child: PlayerStatsOverlay(handle: player)),
                  ),
                // What the last gesture on the picture did, in the corner it
                // happened in.
                if (_gestureKind case final kind?)
                  Positioned.fill(
                    child: VodGestureTip(kind: kind, value: _gestureValue ?? '', note: _gestureNote),
                  ),
                // The subtitle the part is on, above the bar and under the
                // flying danmaku: the words the station sent, not the ones the
                // viewers typed. It is content rather than chrome, so it keeps
                // standing while the bar settles away and on a TV too.
                if (_subtitleText case final words?)
                  Positioned.fill(
                    child: VodSubtitleLayer(text: words, bottomInset: showBar ? _subtitleInset : 0),
                  ),
                // The picture's own vocabulary, measured against this surface
                // and answered by the methods below.
                VodPictureGestures(
                  enabled: _playableHandle != null && !_locked,
                  onTap: _toggleControls,
                  onDoubleTap: _doubleTapAt,
                  onScrub: _scrubBy,
                  onScrubEnd: _endScrub,
                  onAdjustStart: _beginPictureDrag,
                  onAdjust: _dragPictureBy,
                  onHold: _speedHold,
                  onWheel: _wheelVolume,
                  child: const SizedBox.expand(),
                ),
                if (_opening || (transport?.isBuffering ?? false))
                  const Center(child: DsSpinner(style: DsSpinnerStyle(size: 40))),
                if (barUp)
                  PositionedDirectional(top: 0, start: 0, end: 0, child: _vodTopStrip(t, detail, immersive: immersive)),
                // The picture's right edge keeps the lock alone, the room
                // column's shape: the frame's copy moved into the strip's
                // cluster with the rest of the picture's verbs. Locked, the
                // unlock pill is the only thing drawn, whatever the page does
                // next; the download lives in the more container now. The
                // small window draws none of the column, the room's own rule
                // for its compact window — but a locked picture is never left
                // without its unlock.
                if (barUp || _locked)
                  PositionedDirectional(
                    end: DsSpace.s12,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        spacing: DsSpace.s8,
                        children: [
                          PlayerGlassPill(
                            child: PlayerBarButton(
                              icon: _locked ? DsIcons.unlock : DsIcons.lock,
                              label: _locked ? t.room.unlockControls : t.room.lockControls,
                              onPressed: _toggleLock,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (showBar && !smallWindow)
                  PositionedDirectional(
                    bottom: 0,
                    start: 0,
                    end: 0,
                    // Resting on the bar keeps it; leaving it settles the bar
                    // the way an idle pointer does. The small window draws none
                    // of this column: its chrome carries the download's pill and
                    // the part's offers over its own seek line.
                    child: MouseRegion(
                      onEnter: (_) => _hideTimer?.cancel(),
                      onExit: (_) => _scheduleHide(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // The part's download under way, over the bar's
                          // foot: it says its own percent, and the press
                          // pauses it.
                          if (_downloadPill(t, theme) case final pill?)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: DsSpace.s12, bottom: DsSpace.s4),
                              child: pill,
                            ),
                          // The part's own one-time offers, over its foot:
                          // the position the player jumped back to, the
                          // countdown before the next part, the opening and
                          // the ending the viewer can step over. They are not
                          // watching verbs, so they stand outside the bar.
                          for (final notice in _vodNotices(t))
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: DsSpace.s12, bottom: DsSpace.s4),
                              child: Align(alignment: AlignmentDirectional.centerEnd, child: notice),
                            ),
                          _vodControlBar(context, partsOnBar: immersive || fills),
                        ],
                      ),
                    ),
                  )
                // The bar away, the picture keeps one line at its bottom
                // edge: how far it played, and the strip that brings the bar
                // back under the pointer. Locked, the line stands down too —
                // nothing reads as chrome but the unlock pill — and the small
                // window draws none: the pointer over its picture, or a tap
                // on it, is what brings its chrome back.
                else if (!smallWindow && playing && handle != null && !_locked)
                  PositionedDirectional(
                    bottom: 0,
                    start: 0,
                    end: 0,
                    child: PlayerIdleProgress(
                      position: transport?.position,
                      duration: transport?.duration,
                      onWake: _wake,
                    ),
                  ),
                // The small window's chrome, in two layers: the band that
                // moves the window along its top edge, and — over it, and the
                // whole picture — the shared chrome itself.
                if (smallWindow) ...[
                  PositionedDirectional(
                    start: 0,
                    end: 0,
                    top: 0,
                    height: 44,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanStart: (_) {
                        final window = ref.read(windowsPipWindowProvider);
                        if (window != null) unawaited(window.startDragging());
                      },
                      onDoubleTap: () {
                        _wake();
                        unawaited(_togglePip());
                      },
                    ),
                  ),
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) => _smallWindowChrome(
                        context,
                        constraints.maxWidth,
                        danmakuVisible: playback.danmakuVisible,
                        pinned: playback.windowsPipAlwaysOnTop,
                        progress: smallWindowFoot,
                      ),
                    ),
                  ),
                ],
                // The catalogue floats over the bar and its pill, so a menu
                // never hides behind the download status — each one over the
                // picker that raised it, the parts among them now that their
                // chip stands on the bar. The small window has no bar to hang
                // from and draws none.
                if (barUp)
                  if (_openPanel case final panel?)
                    Positioned.fill(
                      child: PlayerPanelHost(
                        anchorKey: _panelAnchors[panel]!,
                        barKey: _barAnchor,
                        width: _panelWidth(panel),
                        child: MouseRegion(
                          onEnter: (_) => _leaveTimer?.cancel(),
                          onExit: (_) => _leavePanelSoon(),
                          child: _vodPanel(t, panel),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The part's download under way, as a pill standing at the end of the line
  /// it rides: over the page bar's foot, and over the seek line in the small
  /// window. A task running or queued says its own percent, and the press
  /// pauses it; nothing else draws a pill.
  Widget? _downloadPill(Translations t, DsThemeData theme) {
    if (_partDownload() case final download?
        when download.phase == VodDownloadPhase.running || download.phase == VodDownloadPhase.queued) {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: PlayerGlassPill(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s12, DsSpace.s4, DsSpace.s4, DsSpace.s4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: DsSpace.s8,
              children: [
                const DsSpinner(style: DsSpinnerStyle(size: 14)),
                Text(switch (download.progress) {
                  final progress? => t.settings.downloadPercent(percent: '${(progress * 100).round()}'),
                  null => t.settings.downloadPercentUnknown,
                }, style: theme.typography.caption.copyWith(color: OnVideoColors.foreground)),
                PlayerBarButton(
                  iconAsset: 'assets/icons/pause.svg',
                  label: t.player.downloadPause,
                  size: 28,
                  iconSize: 16,
                  onPressed: () => unawaited(ref.read(vodDownloadsProvider.notifier).pause(download.id)),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return null;
  }

  /// The desktop's small window: the shared chrome over the part's picture.
  /// The part's name beside the way back, the transport leading the bar, the
  /// danmaku's switch after it and the sound — the part's seek line running
  /// along the bottom edge above them — and the pin at the bar's end. The
  /// picture underneath keeps every gesture it has on the page; the strip,
  /// the bar and their catalogues stay with the page the way back leads to.
  ///
  /// The chrome is sized by the window, so it is built in a layout pass. What
  /// it reads from the providers — [danmakuVisible], [pinned] and the
  /// [progress] line — is read by the surface's own build and handed in: a
  /// widget that reads a provider belongs to the build that reads for it.
  Widget _smallWindowChrome(
    BuildContext context,
    double width, {
    required bool danmakuVisible,
    required bool pinned,
    required Widget? progress,
  }) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final handle = _playableHandle;
    final playing = _transport?.isPlaying ?? false;
    final control = PlayerBarTier.controlFootprint(context);
    // The name's room: what the two corner pills and the window's insets
    // leave of the window.
    final nameMax = (width - 2 * control - 56).clamp(0, double.infinity).toDouble();
    // Play and pause: the bar's first control on a desktop's window, the
    // middle of the picture on a phone's.
    Widget transportButton({double? size, double? glyph}) => PlayerBarButton(
      icon: playing ? DsIcons.pause : DsIcons.play,
      label: playing ? t.player.pause : t.player.play,
      size: size,
      iconSize: glyph,
      onPressed: handle == null
          ? null
          : () {
              _wake();
              unawaited(_togglePlay());
            },
    );
    return PlayerPipChrome(
      visible: !_locked && (_controlsVisible || !playing),
      width: width,
      control: control,
      onRestore: () {
        _wake();
        unawaited(_togglePip());
      },
      onClose: () {
        _wake();
        unawaited(_playableHandle?.pause());
        final close = ref.read(roomLeaveProvider);
        if (close != null) {
          unawaited(close());
          return;
        }
        // The page's own window cannot close itself: the part stops and the
        // small window hands the page back.
        _leave();
      },
      onWake: _wake,
      identity: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: nameMax),
        child: Text(
          _partOf(_openedIdentity)?.title ?? _detail?.title ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.typography.labelStrong.copyWith(color: OnVideoColors.foreground),
        ),
      ),
      leading: transportButton(),
      playPause: PlayerGlassPill(
        child: Padding(
          padding: const EdgeInsets.all(DsSpace.s8),
          child: transportButton(size: theme.sizes.lg, glyph: DsSpace.s24),
        ),
      ),
      verbs: [
        PlayerPipVerb(
          child: PlayerBarButton(
            iconAsset: danmakuVisible ? 'assets/icons/danmaku-on.svg' : 'assets/icons/danmaku-off.svg',
            label: danmakuVisible ? t.common.danmakuOff : t.common.danmakuOn,
            onPressed: handle == null
                ? null
                : () {
                    _wake();
                    unawaited(ref.read(playbackSettingsProvider.notifier).setDanmakuVisible(value: !danmakuVisible));
                  },
          ),
        ),
        PlayerPipVerb(
          child: PlayerBarButton(
            icon: _effectivelyMuted ? DsIcons.volumeX : DsIcons.volume2,
            label: _effectivelyMuted ? t.player.unmute : t.player.mute,
            onPressed: handle == null
                ? null
                : () {
                    _wake();
                    unawaited(_setMuted(muted: !_effectivelyMuted));
                  },
          ),
        ),
        // The level where the window is wide enough to trim it; the mute
        // pill alone names the sound where it is not.
        if (width >= 480)
          PlayerPipVerb(
            extent: 88,
            child: SizedBox(
              width: 88,
              child: DsSlider(
                value: _effectivelyMuted ? 0 : _volume,
                // The live bar's white: the track and the fill the room
                // slider wears, so the sound reads as one app's control on
                // every surface.
                style: const DsSliderStyle(
                  height: 24,
                  trackHeight: 4,
                  trackColor: OnVideoColors.track,
                  fillColor: OnVideoColors.foreground,
                  thumbColor: OnVideoColors.foreground,
                  thumbSize: 12,
                ),
                onChanged: handle == null
                    ? null
                    : (value) {
                        _wake();
                        unawaited(_setVolume(value));
                      },
                semanticLabel: t.player.volume,
              ),
            ),
          ),
      ],
      // The part's own line: how far it has run, with the drag seeking.
      progress: progress,
      // The window's pin: live on the host, remembered for the next entry.
      onTogglePin: () {
        final next = !ref.read(playbackSettingsProvider).windowsPipAlwaysOnTop;
        unawaited(ref.read(playbackSettingsProvider.notifier).setWindowsPipAlwaysOnTop(value: next));
        unawaited(ref.read(desktopWindowHostProvider).setAlwaysOnTop(value: next));
      },
      pinned: pinned,
    );
  }

  /// Whether this archive is on the viewer's shelf. The action row under the
  /// player and the immersive strip's button both read it here, so the two can
  /// never disagree about what is bookmarked.
  bool savedOf(String bvid) => ref.watch(vodFavouritesProvider).any((video) => video.bvid == bvid);

  /// The part's own one-time offers, in the order the viewer meets them: the
  /// position the page jumped back to, the opening it is still inside, the
  /// ending it has reached, and the countdown to the next part. Each names the
  /// verb it takes; none of them stays once taken.
  List<Widget> _vodNotices(Translations t) {
    final transport = _transport;
    final position = transport == null ? 0.0 : transport.position.inMilliseconds / 1000;
    final total = transport == null ? 0.0 : transport.duration.inMilliseconds / 1000;
    final head = _headSeconds;
    final tail = _tailSeconds;
    return [
      if (_resumedAt case final seconds?)
        VodPictureNotice(
          icon: DsIcons.history,
          text: t.vod.resumedAt(time: vodDurationText(Duration(seconds: seconds.round()))),
          actionLabel: t.player.playFromStart,
          onAction: () => unawaited(_playFromStart()),
        ),
      if (head != null && head > 0 && position < head)
        VodPictureNotice(
          icon: DsIcons.skipForward,
          text: t.vod.headRemaining(time: vodDurationText(Duration(seconds: (head - position).round()))),
          actionLabel: t.vod.skipHead,
          onAction: () => unawaited(_seekTo(head)),
        ),
      if (tail != null && tail > 0 && total > 0 && position >= tail)
        VodPictureNotice(
          icon: DsIcons.skipForward,
          text: t.vod.inTail,
          actionLabel: t.vod.skipTail,
          onAction: () => unawaited(_handleFinished()),
        ),
      if (_countdown > 0)
        VodPictureNotice(
          icon: DsIcons.listVideo,
          text: t.vod.nextPartIn(seconds: _countdown),
          actionLabel: t.common.cancel,
          onAction: _cancelCountdown,
        ),
    ];
  }

  /// The strip over the picture's top edge: what acts on the picture — fold
  /// it into a window, send it to a TV — in one glass pill led by the small
  /// window, the rest under a ⋮ menu beside it, and, when the picture owns
  /// the whole window, the way out and the archive's name at the left.
  ///
  /// In-page the identity half is skipped on purpose — the page header above
  /// already names the archive — so what sits over the picture's top-right is
  /// only the verbs. Same rule as the live room's strip. The desktop's small
  /// window is the one owned mode that wears none of this: the shared chrome
  /// is its way back, its name and its close.
  Widget _vodTopStrip(Translations t, VodDetail? detail, {required bool immersive}) {
    final theme = DsTheme.of(context);
    final presentation = ref.watch(roomPresentationProvider);
    final pipAvailable = _playableHandle != null && ref.read(roomPresentationProvider.notifier).pipAvailable;
    // The cluster holds every verb that acts on the picture, in one order on
    // every video page: the frame's copy first, then where the picture goes —
    // the cast, the small window, the app's own corner — and the more door
    // last. The lock keeps the picture's right edge, the room's own place.
    final actions = <Widget>[
      if (_playableHandle?.canCaptureScreenshot ?? false)
        PlayerBarButton(
          icon: DsIcons.camera,
          label: t.player.screenshot,
          onPressed: () {
            _wake();
            unawaited(_screenshot());
          },
        ),
      if (_play != null)
        PlayerBarButton(
          icon: DsIcons.cast,
          label: t.player.cast,
          onPressed: () {
            _wake();
            unawaited(_cast());
          },
        ),
      // The small window follows: where the picture goes comes before what
      // is done to it. A picture already in its small window carries no
      // second way into it.
      if (pipAvailable && presentation != PresentationMode.pip)
        PlayerBarButton(
          icon: DsIcons.pictureInPicture,
          label: t.player.pipOn,
          onPressed: () {
            _wake();
            unawaited(_togglePip());
          },
        ),
      // The mini window rides the cluster as the third destination — keep
      // the picture, send it to a TV, shrink it to a corner of the app.
      // Settings-governed: off, the cluster carries no chip at all.
      if (_miniWindowReady && ref.watch(playbackSettingsProvider.select((settings) => settings.floatWindow)))
        PlayerBarButton(
          icon: DsIcons.appWindow,
          label: t.common.miniWindow,
          onPressed: () {
            _wake();
            unawaited(_enterMiniWindow());
          },
        ),
    ];
    // The session verbs and the more door share one pill — the room
    // cluster's single form, never two pills drifting apart. No handle, no
    // verbs: pills would only promise what cannot run yet.
    final clusterPill = PlayerGlassPill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: PlayerBarTier.tvOf(context) ? DsSpace.s8 : DsSpace.s4,
        children: [
          ...actions,
          PlayerBarButton(
            icon: DsIcons.ellipsisVertical,
            label: t.common.more,
            onPressed: () {
              _wake();
              unawaited(showPlayerMoreContainer(context, content: (context, {required labeled}) => _vodMoreContent(t)));
            },
          ),
        ],
      ),
    );
    // No title on the strip: the info block right under the picture is the
    // title's home, and two copies of one line on the same screen is one too
    // many. The strip carries the errands only.
    final backPill = PlayerGlassPill(
      child: PlayerBarButton(
        icon: DsIcons.arrowLeft,
        label: t.common.back,
        onPressed: () {
          _wake();
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        },
      ),
    );
    if (!immersive) {
      // The strip is the page's head now: the way back always, the verbs
      // once a player exists to act on. No handle, no verbs — the pills
      // would only promise what cannot run yet.
      final ground = Container(
        padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s8, DsSpace.s8, DsSpace.s12, DsSpace.s20),
        decoration: BoxDecoration(gradient: OnVideoColors.shade(edge: VerticalDirection.up)),
        child: Row(spacing: DsSpace.s8, children: [backPill, const Spacer(), if (_playableHandle != null) clusterPill]),
      );
      return ground;
    }
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s8, DsSpace.s8, DsSpace.s12, DsSpace.s20),
      decoration: BoxDecoration(gradient: OnVideoColors.shade(edge: VerticalDirection.up)),
      child: Row(
        spacing: DsSpace.s8,
        children: [
          // The leading pill is the shape's own way out: it names the shape
          // it sits in and leaves that one — the window fullscreen hands the
          // window back, the system fullscreen the screen — and never falls
          // into the other on the way, the way the bar's pair never does. The
          // small window has no strip: its way back, the drag on its name and
          // its close are the shared chrome's.
          PlayerGlassPill(
            child: PlayerBarButton(
              icon: switch (presentation) {
                PresentationMode.windowFullscreen => DsIcons.squareShrinkUpLeftDownRight,
                _ => DsIcons.minimize,
              },
              label: switch (presentation) {
                PresentationMode.windowFullscreen => t.player.windowFullscreenOff,
                _ => t.player.fullscreenOff,
              },
              autofocus: true,
              onPressed: () {
                _wake();
                _leave();
              },
            ),
          ),
          Expanded(
            child: Text(
              detail?.title ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.title.copyWith(color: OnVideoColors.foreground),
            ),
          ),
          // The page's own bookmark, reachable from the fullscreen picture: the
          // action row under the player is page chrome, and an immersive
          // surface has none of it — an action that vanished with the chrome is
          // one the viewer has to leave fullscreen to reach. One verb, so it is
          // a button rather than a menu of one row.
          if (detail != null)
            PlayerGlassPill(
              child: PlayerBarButton(
                icon: DsIcons.heart,
                label: savedOf(detail.bvid) ? t.vod.savedVideo : t.vod.saveVideo,
                selected: savedOf(detail.bvid),
                onPressed: () => unawaited(_toggleFavourite()),
              ),
            ),
          clusterPill,
        ],
      ),
    );
  }

  /// The more container's content, the room's own shape: what the panel
  /// does as round tiles over lists of settings. The bar keeps the verbs that
  /// live on it — the danmaku pair, the renditions, the pace, the words, the
  /// parts — so the container carries what has no bar: the part's download,
  /// the sound without the picture, the stream's numbers, the picture's
  /// shape, the timer that ends a long video, and the viewer's own skip
  /// points. The StatefulBuilder is the panel's own redraw, so a switch never
  /// waits for the page's rebuild to look flipped.
  Widget _vodMoreContent(Translations t) {
    final handle = _playableHandle;
    return StatefulBuilder(
      builder: (context, setPanel) {
        final download = _partDownload();
        final fit = ref.read(playbackSettingsProvider).fit;
        final stats = ref.read(playerStatsVisibleProvider);
        final skip = ref.read(vodPlaybackSettingsProvider).skipHeadTail;
        final sleepMinutes = ref.read(sleepTimerProvider).minutes;
        // The picks run on a panel of their own, once this container is gone,
        // so they hold the notifiers.
        final playback = ref.read(playbackSettingsProvider.notifier);
        final sleep = ref.read(sleepTimerProvider.notifier);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s12,
          children: [
            PlayerMoreTiles(
              tiles: [
                if (_detail != null)
                  PlayerMoreTile(
                    color: PlayerMoreHues.download,
                    icon: DsIcons.download,
                    // A download under way says its own percent under the
                    // circle, and stands still — the pill over the bar
                    // pauses it.
                    label: switch (download) {
                      final task?
                          when task.phase == VodDownloadPhase.running || task.phase == VodDownloadPhase.queued =>
                        task.progress == null
                            ? t.settings.downloadPercentUnknown
                            : t.settings.downloadPercent(percent: '${(task.progress! * 100).round()}'),
                      _ => t.player.download,
                    },
                    onTap: download == null
                        ? () {
                            Navigator.of(context).pop();
                            unawaited(_startDownload());
                          }
                        : null,
                  ),
                PlayerMoreTile(
                  color: PlayerMoreHues.audio,
                  icon: DsIcons.headphones,
                  label: _audioOnly ? t.player.restoreVideo : t.player.audioOnlyMode,
                  lit: _audioOnly,
                  onTap: handle == null
                      ? null
                      : () {
                          unawaited(_toggleAudioOnly());
                          setPanel(() {});
                        },
                ),
              ],
            ),
            DsListSection(
              children: [
                // Read fresh on the panel's own redraw: the pick flips the
                // provider under the row, and this switch is the first thing
                // the redraw reads.
                PlayerMoreRow(
                  label: t.player.statsToggle,
                  leading: DsIcons.activity,
                  value: null,
                  onTap: handle == null
                      ? null
                      : () {
                          ref.read(playerStatsVisibleProvider.notifier).toggle();
                          setPanel(() {});
                        },
                  trailing: DsSwitch(
                    value: stats,
                    onChanged: (_) {
                      ref.read(playerStatsVisibleProvider.notifier).toggle();
                      setPanel(() {});
                    },
                  ),
                ),
                PlayerMoreRow(
                  label: t.settings.fit,
                  leading: DsIcons.scaling,
                  value: fitLabels(t)[fit.index],
                  onTap: () => unawaited(
                    showPlayerChoicePanel(
                      context,
                      title: t.settings.fit,
                      options: [
                        for (final option in PlaybackFit.values)
                          PlayerChoiceOption(
                            label: fitLabels(t)[option.index],
                            selected: option == fit,
                            onPick: () => unawaited(playback.setFit(option)),
                          ),
                      ],
                    ),
                  ),
                ),
                // A long video ends itself; the choices stand on a panel of
                // their own — the room's ASMR panel stays with the room.
                PlayerMoreRow(
                  label: t.player.sleep,
                  leading: DsIcons.timer,
                  value: sleepMinutes == null ? t.player.sleepOff : asmrSleepDurationLabel(sleepMinutes),
                  onTap: () => unawaited(
                    showPlayerChoicePanel(
                      context,
                      title: t.player.sleep,
                      options: [
                        for (final minutes in const [0, 15, 30, 60, 90])
                          PlayerChoiceOption(
                            label: minutes == 0 ? t.player.sleepOff : asmrSleepDurationLabel(minutes),
                            selected: (sleepMinutes ?? 0) == minutes,
                            onPick: () => sleep.start(minutes == 0 ? null : minutes),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Bilibili marks an opening and an ending for its own cinema titles
            // and says nothing at all for a posted archive, so the points here
            // are the viewer's: set them where the part stands now, and the
            // player steps over them from then on.
            playerMoreSectionLabel(context, t.vod.skipHeadTail),
            DsListSection(
              children: [
                PlayerMoreRow(
                  label: t.vod.autoSkipHeadTail,
                  leading: DsIcons.skipForward,
                  value: null,
                  onTap: () {
                    unawaited(ref.read(vodPlaybackSettingsProvider.notifier).setSkipHeadTail(value: !skip));
                    setPanel(() {});
                  },
                  trailing: DsSwitch(
                    value: skip,
                    onChanged: (value) {
                      unawaited(ref.read(vodPlaybackSettingsProvider.notifier).setSkipHeadTail(value: value));
                      setPanel(() {});
                    },
                  ),
                ),
                PlayerMoreRow(
                  label: t.vod.setHeadHere,
                  leading: DsIcons.skipBack,
                  value: null,
                  onTap: handle == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          unawaited(_setHeadHere());
                        },
                ),
                PlayerMoreRow(
                  label: t.vod.setTailHere,
                  leading: DsIcons.skipForward,
                  value: null,
                  onTap: handle == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          unawaited(_setTailHere());
                        },
                ),
                PlayerMoreRow(
                  label: t.vod.clearSkipPoints,
                  leading: DsIcons.x,
                  value: null,
                  onTap: _headSeconds == null && _tailSeconds == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          unawaited(_clearSkipPoints());
                        },
                ),
              ],
            ),
            const SizedBox(height: DsSpace.s12),
          ],
        );
      },
    );
  }

  /// Hands the current part to the app-wide download queue.
  ///
  /// The queue resolves its own muxed address when the task's turn comes —
  /// a signed one would be stale by then — and the 下载管理 page (the
  /// station's sidebar, or Settings → 视频) takes over from there.
  Future<void> _startDownload() async {
    final t = context.t;
    final part = _part;
    final detail = _detail;
    if (part == null || detail == null) return;
    final result = await ref
        .read(vodDownloadsProvider.notifier)
        .download(
          bvid: widget.bvid,
          cid: part.cid,
          title: detail.title,
          part: part.title,
          index: part.page,
          parts: detail.parts.length,
          qn: ref.read(vodDownloadQualityProvider).qn,
          cover: detail.coverUrl?.toString() ?? '',
        );
    if (!mounted) return;
    switch (result.outcome) {
      case VodDownloadEnqueue.queued:
        showDsToast(context: context, title: t.settings.downloadQueuedNotice, status: DsStatus.success);
      case VodDownloadEnqueue.duplicate:
        showDsToast(context: context, title: t.player.downloadDuplicate);
      case VodDownloadEnqueue.failed:
        showDsToast(
          context: context,
          title: t.settings.downloadStatusFailed,
          description: result.error,
          status: DsStatus.danger,
        );
    }
  }

  /// The bar under the picture, in the two layers every player's bar wears:
  /// the seek line, then the control line. The line reads left to right — the
  /// part's steps around play (a serial is walked both ways: the part before,
  /// play, the part after), the sound, the catalogues, and at the end the two
  /// ways out of the box, the picture's bottom-right corner at every width.
  /// The catalogues are the danmaku's trio first — the switch, the comments
  /// as a list, the gear — then the rendition, the speed, the station's
  /// words and, where the page runs nothing under the picture, the parts; a
  /// line that cannot carry them gives them the line above, so play stays
  /// the first control of the bottom line. Where the page does run under the
  /// picture, the shelf that jumps to any part lives there, or in the rail
  /// beside it. What acts on the picture (capture, cast, the small window)
  /// and the errands live on the strip above and its ⋮ menu.
  Widget _vodControlBar(BuildContext context, {required bool partsOnBar}) {
    final t = context.t;
    final handle = _playableHandle;
    final playing = _transport?.isPlaying ?? false;
    final qualities = _play?.qualities ?? const <VodQuality>[];
    final presentation = ref.watch(roomPresentationProvider);
    final danmakuVisible = ref.watch(playbackSettingsProvider).danmakuVisible;
    final previous = _hasPreviousPart;
    final next = _hasNextPart;
    final hasList = _danmakuEntries.isNotEmpty;
    final hasSubtitles = _extra.subtitles.isNotEmpty;
    // The parts catalogue stands on the bar only where the picture has no
    // page under it to keep the shelf.
    final hasParts = partsOnBar && ((_detail?.parts.length ?? 0) > 1);
    final qualityLabel = _openedLabel ?? t.player.quality;
    final speedLabel = VodSpeedChoice.nearest(_speed).label;
    final subtitleLabel = _subtitleTrack?.languageName.isEmpty ?? true ? t.vod.subtitles : _subtitleTrack!.languageName;
    // Built here, in the page's own build, and only placed by the layout
    // below: it is the one piece of the bar that reads a provider.
    final seekLayer = _vodSeekLayer();
    return PlayerControlBar(
      key: _barAnchor,
      padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s12, DsSpace.s8, DsSpace.s12, DsSpace.s8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = constraints.maxWidth;
          final tvBar = PlayerBarTier.tvOf(context);
          final gap = tvBar ? DsSpace.s8 : DsSpace.s4;
          final control = PlayerBarTier.controlFootprint(context);
          final pip = presentation == PresentationMode.pip;
          // The bar's own width is the ladder's ruler, the one every surface
          // reads: the volume slider 96 px when the bar is roomy, 72 when it
          // bends, and gone under 480, where the mute and the wheel still
          // carry the sound.
          final volumeWidth = barWidth >= 720 ? 96.0 : (barWidth >= 480 ? 72.0 : null);
          // The catalogues' extents, with their words and with the glyph
          // alone. The line is read off the bar's own width: the words go
          // first, then the line gives way to the one above.
          double picker(String label, {required bool words}) =>
              playerBarPickerExtent(context, label, compact: !words, maxWord: 110);
          final line = playerBarLine(
            barWidth: barWidth,
            gap: gap,
            fixed: [
              if (previous) control,
              control,
              if (next) control,
              control,
              ?volumeWidth,
              if (_desktop && !pip) control,
              if (!pip) control,
            ],
            worded: [
              control,
              if (hasList) control,
              control,
              if (qualities.isNotEmpty) picker(qualityLabel, words: true),
              picker(speedLabel, words: true),
              if (hasSubtitles) picker(subtitleLabel, words: true),
              if (hasParts) picker(t.vod.parts, words: true),
            ],
            glyphs: [
              control,
              if (hasList) control,
              control,
              if (qualities.isNotEmpty) picker(qualityLabel, words: false),
              picker(speedLabel, words: false),
              if (hasSubtitles) picker(subtitleLabel, words: false),
              if (hasParts) picker(t.vod.parts, words: false),
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s4,
            children: [
              // The bar's first layer: the clocks at the line's ends at every
              // width, the archive's own seek line between them.
              seekLayer,
              PlayerBarRows(
                foldWidth: line.inline ? 0 : double.infinity,
                foldAbove: true,
                gap: gap,
                start: Row(
                  spacing: gap,
                  children: [
                    // The steps between parts lead, the way every serial's bar
                    // carries them: the part before, play, the part after —
                    // where the thumb starts, at every width. The shelf under
                    // the picture (or the rail beside it) keeps the jump to
                    // any part.
                    if (previous)
                      PlayerBarButton(
                        icon: DsIcons.skipBack,
                        label: t.vod.previousPart,
                        onPressed: () {
                          _wake();
                          _openSteppedPart(-1);
                        },
                      ),
                    PlayerBarButton(
                      icon: playing ? DsIcons.pause : DsIcons.play,
                      label: playing ? t.player.pause : t.player.play,
                      focusNode: _playFocus,
                      onPressed: handle == null
                          ? null
                          : () {
                              _wake();
                              unawaited(_togglePlay());
                            },
                    ),
                    if (next)
                      PlayerBarButton(
                        icon: DsIcons.skipForward,
                        label: t.vod.nextPart,
                        onPressed: () {
                          _wake();
                          _openSteppedPart(1);
                        },
                      ),
                    // Mute stays one thumb away at every width; the slider
                    // beside it waits for a bar that can pay for it.
                    PlayerBarButton(
                      icon: _effectivelyMuted ? DsIcons.volumeX : DsIcons.volume2,
                      label: _effectivelyMuted ? t.player.unmute : t.player.mute,
                      onPressed: handle == null
                          ? null
                          : () {
                              _wake();
                              unawaited(_setMuted(muted: !_effectivelyMuted));
                            },
                    ),
                    if (volumeWidth case final width?)
                      SizedBox(
                        width: width,
                        child: DsSlider(
                          value: _effectivelyMuted ? 0 : _volume,
                          // The live bar's white: the track and the fill the
                          // room slider wears, so the sound reads as one
                          // app's control on every surface.
                          style: const DsSliderStyle(
                            height: 24,
                            trackHeight: 4,
                            trackColor: OnVideoColors.track,
                            fillColor: OnVideoColors.foreground,
                            thumbColor: OnVideoColors.foreground,
                            thumbSize: 12,
                          ),
                          onChanged: handle == null
                              ? null
                              : (value) {
                                  _wake();
                                  unawaited(_setVolume(value));
                                },
                          semanticLabel: t.player.volume,
                        ),
                      ),
                  ],
                ),
                // The catalogues on the line the width can give them: beside
                // the transport, or the line above it; a line narrower than
                // the row itself scrolls rather than clips.
                middle: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    spacing: gap,
                    children: [
                      // The danmaku's trio leads the catalogues, the room
                      // bar's order: the switch, the comments as a list
                      // against the clock, and the gear whose quick sliders
                      // stay beside the picture — the full settings wait
                      // behind the advanced row, never a jump out of the
                      // player.
                      PlayerBarButton(
                        iconAsset: danmakuVisible ? 'assets/icons/danmaku-on.svg' : 'assets/icons/danmaku-off.svg',
                        label: danmakuVisible ? t.common.danmakuOff : t.common.danmakuOn,
                        onPressed: handle == null
                            ? null
                            : () {
                                _wake();
                                unawaited(
                                  ref.read(playbackSettingsProvider.notifier).setDanmakuVisible(value: !danmakuVisible),
                                );
                              },
                      ),
                      if (hasList)
                        PlayerBarButton(
                          key: _panelAnchors[_VodPanel.danmakuList],
                          iconAsset: 'assets/icons/danmaku.svg',
                          label: t.room.danmakuListTitle,
                          selected: _openPanel == _VodPanel.danmakuList,
                          onPressed: handle == null
                              ? null
                              : () {
                                  _wake();
                                  setState(
                                    () =>
                                        _openPanel = _openPanel == _VodPanel.danmakuList ? null : _VodPanel.danmakuList,
                                  );
                                },
                        ),
                      PlayerBarButton(
                        key: _panelAnchors[_VodPanel.danmaku],
                        iconAsset: 'assets/icons/danmaku-settings.svg',
                        label: t.settings.navDanmaku,
                        selected: _openPanel == _VodPanel.danmaku,
                        onPressed: handle == null
                            ? null
                            : () {
                                _wake();
                                setState(() => _openPanel = _openPanel == _VodPanel.danmaku ? null : _VodPanel.danmaku);
                              },
                      ),
                      // The bar's three other catalogues: the rendition, the
                      // pace and the station's words — the high-frequency
                      // reads a viewer tunes without opening a menu. The
                      // parts live under the picture in the page's own
                      // layout, and in the immersive shell, where no page
                      // runs beneath, the more menu keeps the one entry (the
                      // card hangs off the bar).
                      if (qualities.isNotEmpty)
                        _vodPickerButton(
                          panel: _VodPanel.quality,
                          icon: DsIcons.gauge,
                          label: qualityLabel,
                          semanticLabel: t.player.quality,
                          compact: !line.words,
                        ),
                      _vodPickerButton(
                        panel: _VodPanel.speed,
                        icon: DsIcons.timer,
                        label: speedLabel,
                        semanticLabel: t.player.speed,
                        compact: !line.words,
                      ),
                      // The words the station wrote for this part. The door
                      // opens only where there is something behind it: a
                      // guest gets no list, and a CC button that has nothing
                      // to list is a button that answers nothing.
                      if (hasSubtitles)
                        _vodPickerButton(
                          panel: _VodPanel.subtitle,
                          icon: DsIcons.captions,
                          label: subtitleLabel,
                          semanticLabel: t.vod.subtitles,
                          compact: !line.words,
                        ),
                      // The parts catalogue, the bar's own: where the page
                      // runs nothing under the picture it is the only way to
                      // a part that is not a step away.
                      if (hasParts)
                        _vodPickerButton(
                          panel: _VodPanel.parts,
                          icon: DsIcons.listVideo,
                          label: t.vod.parts,
                          semanticLabel: t.vod.parts,
                          compact: !line.words,
                        ),
                    ],
                  ),
                ),
                end: Row(
                  spacing: gap,
                  children: [
                    // The window verbs, then the way out of the picture's box —
                    // the room bar's pair: the desktop's window-fullscreen first,
                    // then the system fullscreen the phone turns for. The
                    // window's own shape with the arrows that say which way it
                    // goes.
                    if (_desktop && !pip)
                      PlayerBarButton(
                        icon: presentation == PresentationMode.windowFullscreen
                            ? DsIcons.squareShrinkUpLeftDownRight
                            : DsIcons.squareExpandUpRightDownLeft,
                        label: presentation == PresentationMode.windowFullscreen
                            ? t.player.windowFullscreenOff
                            : t.player.windowFullscreenOn,
                        selected: presentation == PresentationMode.windowFullscreen,
                        onPressed: handle == null
                            ? null
                            : () {
                                _wake();
                                unawaited(_toggleWindowFullscreen());
                              },
                      ),
                    if (!pip)
                      PlayerBarButton(
                        icon: presentation == PresentationMode.fullscreen ? DsIcons.minimize : DsIcons.maximize,
                        label: presentation == PresentationMode.fullscreen
                            ? t.player.fullscreenOff
                            : t.player.fullscreen,
                        selected: presentation == PresentationMode.fullscreen,
                        onPressed: handle == null
                            ? null
                            : () {
                                _wake();
                                unawaited(_toggleFullscreen());
                              },
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The seek line: the bar's first layer, and the small window's. The shared
  /// layer's clocks stand at the line's two ends at every width, and between
  /// them rides the archive's own line — the one that says three things a
  /// slider cannot: what has been watched, what the engine already holds and
  /// where the station marked a moment, and under the pointer where the
  /// picture would go. Both surfaces draw it from here, so a drag speaks the
  /// same two callbacks wherever it starts.
  Widget _vodSeekLayer() {
    final t = context.t;
    final transport = _transport;
    final duration = transport?.duration ?? _detail?.duration ?? _partOf(_openedIdentity)?.duration ?? Duration.zero;
    final position = _dragSeconds != null
        ? Duration(milliseconds: (_dragSeconds! * 1000).round())
        : transport?.position ?? Duration.zero;
    return PlayerSeekLayer.replay(
      position: position,
      duration: duration,
      buffered: transport?.buffer.ranges ?? const [],
      seekBar: VodSeekBar(
        position: position,
        duration: duration,
        semanticLabel: t.player.progress,
        buffered: transport?.buffer.ranges ?? const [],
        chapters: _extra.chapters,
        preview: _extra.preview,
        coverUrl: _detail?.coverUrl,
        showPreview: ref.watch(vodPlaybackSettingsProvider).seekPreview,
        onScrub: (seconds) => setState(() => _dragSeconds = seconds),
        onSeek: (seconds) {
          setState(() => _dragSeconds = null);
          unawaited(_seekTo(seconds));
        },
      ),
    );
  }

  /// One picker on the bar: the glyph, the current choice's words when the
  /// bar has room, and the chevron that says a panel hangs above it.
  Widget _vodPickerButton({
    required _VodPanel panel,
    required DsIconData icon,
    required String label,
    required String semanticLabel,
    required bool compact,
  }) {
    final theme = DsTheme.of(context);
    final open = _openPanel == panel;
    return KeyedSubtree(
      key: _panelAnchors[panel],
      child: MouseRegion(
        onEnter: (_) => _hoverPanel(panel),
        onExit: (_) => _leavePanelSoon(),
        child: DsPressable(
          semanticLabel: semanticLabel,
          onPressed: () {
            _wake();
            if (_openPanel == panel) {
              _closePanel();
            } else {
              _showPanel(panel);
            }
          },
          builder: (context, states, _) {
            final lit = open || states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
            return Container(
              height: theme.sizes.md,
              padding: EdgeInsets.symmetric(horizontal: compact ? DsSpace.s6 : DsSpace.s8),
              decoration: DsBoxDecoration(
                color: lit ? OnVideoColors.inkHover : null,
                borderRadius: theme.radii.controlCorners(null, theme.sizes.md),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: DsSpace.s4,
                children: [
                  DsIcon(icon, size: theme.sizes.iconLg, color: OnVideoColors.inkMuted),
                  if (!compact)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: OnVideoColors.foreground),
                      ),
                    ),
                  DsIcon(open ? DsIcons.chevronDown : DsIcons.chevronUp, size: 12, color: OnVideoColors.inkMuted),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// The width each catalogue asks for; the anchored host centres the card
  /// on its picker with this measure.
  static double _panelWidth(_VodPanel panel) => switch (panel) {
    _VodPanel.quality => 200,
    _VodPanel.parts => 260,
    _VodPanel.speed => 180,
    _VodPanel.subtitle => 240,
    _VodPanel.danmaku => 280,
    _VodPanel.danmakuList => 300,
  };

  /// The open picker's catalogue.
  Widget _vodPanel(Translations t, _VodPanel panel) {
    switch (panel) {
      case _VodPanel.quality:
        final qualities = _play?.qualities ?? const <VodQuality>[];
        return PlayerOverlayPanel(
          title: t.player.quality,
          width: _panelWidth(panel),
          children: [
            for (final quality in qualities)
              PlayerPanelOption(
                label: quality.label,
                selected: quality.qn == _openedQn,
                onPressed: () {
                  _closePanel();
                  final current = _partOf(_openedIdentity);
                  if (current == null) return;
                  final resume = _transport?.position.inMilliseconds;
                  unawaited(_openPart(current, qn: quality.qn, resume: resume == null ? null : resume / 1000));
                },
              ),
          ],
        );
      case _VodPanel.parts:
        final parts = _detail?.parts ?? const <VodPart>[];
        return PlayerOverlayPanel(
          title: t.vod.parts,
          width: _panelWidth(panel),
          children: [
            for (final candidate in parts)
              KeyedSubtree(
                key: candidate.cid == _part?.cid ? _currentPartKey : null,
                child: PlayerPanelOption(
                  label: 'P${candidate.page} ${candidate.title}',
                  selected: candidate.cid == _part?.cid,
                  onPressed: () {
                    _closePanel();
                    unawaited(_openPart(candidate, resume: _resumeFor(candidate)));
                  },
                ),
              ),
          ],
        );
      case _VodPanel.speed:
        return PlayerOverlayPanel(
          title: t.player.speed,
          width: _panelWidth(panel),
          children: [
            for (final choice in VodSpeedChoice.values)
              PlayerPanelOption(
                label: choice.label,
                selected: choice.value == _speed,
                onPressed: () {
                  _closePanel();
                  unawaited(_setSpeed(choice.value));
                },
              ),
          ],
        );
      // The words the station wrote for this part, as opposed to the ones the
      // viewers fly over it. It sends the list only to a signed-in viewer, so
      // an empty one says which door is shut rather than pretending the
      // archive has nothing to say.
      case _VodPanel.subtitle:
        final tracks = _extra.subtitles;
        return PlayerOverlayPanel(
          title: t.vod.subtitles,
          width: _panelWidth(panel),
          children: [
            PlayerPanelOption(
              label: t.vod.subtitleOff,
              selected: _subtitleTrack == null,
              onPressed: () {
                _closePanel();
                unawaited(_selectSubtitle(null));
              },
            ),
            for (final track in tracks)
              PlayerPanelOption(
                label: track.languageName.isEmpty ? track.language : track.languageName,
                detail: track.auto ? t.vod.subtitleAuto : null,
                selected: _subtitleTrack?.id == track.id,
                onPressed: () {
                  _closePanel();
                  unawaited(_selectSubtitle(track));
                },
              ),
            if (tracks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12, vertical: DsSpace.s6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s6,
                  children: [
                    Text(
                      _extra.needsLoginForSubtitles ? t.vod.subtitleNeedsLogin : t.vod.subtitleNone,
                      style: DsTheme.of(context).typography.caption.copyWith(color: OnVideoColors.inkSubtle),
                    ),
                    // The caption alone was a dead end: the sign-in the
                    // notice asks for sits beside it.
                    if (_extra.needsLoginForSubtitles)
                      DsButton(
                        variant: DsButtonVariant.secondary,
                        size: DsSize.sm,
                        onPressed: () => unawaited(showBilibiliWebLoginPage(context)),
                        child: Text(t.vod.signIn),
                      ),
                  ],
                ),
              ),
          ],
        );
      case _VodPanel.danmaku:
        // The room bar's gear card: the four quick sliders and the way to
        // the full settings — the tuning never leaves the player.
        return PlayerOverlayPanel(
          title: t.settings.navDanmaku,
          width: _panelWidth(panel),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s12, 0, DsSpace.s12, DsSpace.s6),
              child: PlayerDanmakuQuickControls(
                onWake: _wake,
                onAdvanced: () {
                  _closePanel();
                  unawaited(context.push(SettingsSectionRoute(section: SettingsSection.danmaku.name).location));
                },
              ),
            ),
          ],
        );
      case _VodPanel.danmakuList:
        // The track's whole timeline: the decoded file already carries every
        // comment at its own position, so the list reads from the start — a
        // row's tap seeks the picture there.
        return PlayerDanmakuListPanel(
          lines: [
            for (final entry in _danmakuEntries)
              (
                at: entry.time,
                text: entry.text,
                color: 0xFF000000 | (entry.color.r << 16) | (entry.color.g << 8) | entry.color.b,
              ),
          ],
          onSeek: (at) {
            _closePanel();
            unawaited(_seekTo(at.inMilliseconds / 1000));
          },
          title: t.room.danmakuListTitle,
          empty: t.room.danmakuListEmpty,
        );
    }
  }

  /// Shows the bars and, while the stream plays, lets them settle away again.
  void _wake() {
    if (mounted && !_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  /// A tap on the picture: up when they are down, down when they are up.
  void _toggleControls() {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _wake();
    }
  }

  /// The watching lock: taking it puts the panels away first, and locked the
  /// strip, the bar and the gestures stand down until the unlock pill says
  /// otherwise — the room's and the channel's own rule.
  void _toggleLock() {
    if (!_locked && _openPanel != null) setState(() => _openPanel = null);
    setState(() => _locked = !_locked);
    if (_locked) {
      _hideTimer?.cancel();
      return;
    }
    _wake();
  }

  /// Whether this display is the TV form factor: its chrome never hides on
  /// idle, the room's keepControls rule — the remote's focus walk is the
  /// only way through the bar, and a bar that folds under a focused button
  /// strands the walk.
  bool get _isTv => ref.read(platformRuntimeProvider).environment.runtime.formFactor == FormFactor.tv;

  void _scheduleHide() {
    // The tracker still walks the regions a leaving page owned: its exit
    // lands here after dispose, and a dead state reads no store.
    if (!mounted) return;
    _hideTimer?.cancel();
    // The TV's chrome never hides on idle (see _isTv).
    if (_isTv) return;
    // An open catalogue holds the bar up; a paused stream keeps it too.
    if (_openPanel != null || !(_transport?.isPlaying ?? false)) return;
    final seconds = ref.read(modulePlaybackSettingsProvider(PlayerModule.vod)).controlsAutoHideSeconds;
    // The setting's zero is 常显: the bar never hides on idle while the
    // video plays.
    if (seconds <= 0) return;
    _hideTimer = Timer(Duration(seconds: seconds), () {
      if (mounted && (_transport?.isPlaying ?? false) && _openPanel == null) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _showPanel(_VodPanel panel) {
    _hoverTimer?.cancel();
    _leaveTimer?.cancel();
    if (_openPanel == panel) return;
    setState(() => _openPanel = panel);
    _hideTimer?.cancel();
    // The parts catalogue opens on the part being played, not on the first:
    // a multi-part upload hundreds deep would otherwise always start over.
    if (panel == _VodPanel.parts) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final keyContext = _currentPartKey.currentContext;
        if (keyContext != null && mounted) {
          Scrollable.ensureVisible(keyContext, alignment: 0.1, duration: const Duration(milliseconds: 120));
        }
      });
    }
  }

  void _closePanel() {
    _hoverTimer?.cancel();
    _leaveTimer?.cancel();
    if (_openPanel == null) return;
    setState(() => _openPanel = null);
    _scheduleHide();
  }

  /// Resting the pointer on a picker opens it after a breath, so crossing the
  /// bar on the way somewhere else does not flash every catalogue.
  void _hoverPanel(_VodPanel panel) {
    _leaveTimer?.cancel();
    _hoverTimer?.cancel();
    _hoverTimer = Timer(const Duration(milliseconds: 160), () {
      if (mounted) _showPanel(panel);
    });
  }

  /// The pointer leaving a picker gets a moment to reach the panel above it.
  void _leavePanelSoon() {
    _hoverTimer?.cancel();
    _leaveTimer?.cancel();
    _leaveTimer = Timer(const Duration(milliseconds: 260), () {
      if (mounted) _closePanel();
    });
  }

  /// Hands the first focus to the play button once there is a source: a
  /// remote or keyboard starts on the control that matters, as the room
  /// page's control bar does.
  void _giveInitialFocus() {
    if (_gaveInitialFocus) return;
    _gaveInitialFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _playFocus.context == null) return;
      if (ModalRoute.of(context)?.isCurrent ?? false) {
        _playFocus.requestFocus();
      }
    });
  }

  /// The saved position for [part], when the store's entry names it.
  double? _resumeFor(VodPart part) {
    final saved = _readProgress();
    return saved != null && saved.cid == part.cid ? saved.seconds : null;
  }

  /// The archive's blurb: the shared fold at its six-line default, so the
  /// season's 简介 answers with the same shape.
  Widget _description(BuildContext context, VodDetail detail, Translations t) {
    final text = detail.description.isEmpty ? t.vod.noDescription : detail.description;
    return VodFoldedText(text: text);
  }

  /// The archive's details under the picture. [showParts] leaves the parts
  /// shelf out where the rail beside the picture draws it instead (the wide
  /// layout), so the page never names the same list twice.
  Widget _info(BuildContext context, VodDetail detail, Translations t, {required bool showParts}) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final silent = _play?.silent ?? _silent;
    // The station's own switch: the archive's details under the picture are
    // what a viewer hides to keep the page on the parts and the rail.
    final showDetails = ref.watch(vodPlaybackSettingsProvider).showDetails;
    final saved = savedOf(detail.bvid);
    // The write verbs the cookie can speak: the like's verdict, the
    // uploader's. A guest reads null and keeps the read-only shapes.
    final writable = ref.watch(vodWriteReadyProvider);
    final liked = writable && detail.aid > 0 ? ref.watch(vodLikeProvider(detail.aid)) : null;
    if (liked == null || _likeBaseline?.aid != detail.aid) {
      _likeBaseline = liked == null ? null : (aid: detail.aid, liked: liked);
    }
    final followed = writable && (detail.uploaderMid ?? 0) > 0
        ? ref.watch(vodFollowUpProvider(detail.uploaderMid!))
        : null;
    final uploaded = detail.publishedAt;
    final plays = detail.playCount;
    final danmaku = detail.danmakuCount;
    // What happened to the archive, each figure under its own mark and in
    // the row's own ink — apart from what the viewer does further down.
    Widget stat(Widget icon, String value) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: DsSpace.s4,
      children: [
        icon,
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.numeric(
              theme.typography.caption.copyWith(color: colors.text, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
    final stats = <Widget>[
      if (plays != null)
        stat(DsIcon(DsIcons.eye, size: 14, color: colors.textSubtle), '${AudienceFormat.format(plays)} ${t.vod.views}'),
      if (danmaku != null)
        stat(
          DsIcon(DsIcons.messageCircle, size: 14, color: colors.textSubtle),
          '${AudienceFormat.format(danmaku)} ${t.vod.danmaku}',
        ),
      if (uploaded != null) stat(DsIcon(DsIcons.history, size: 14, color: colors.textSubtle), vodDateText(uploaded)),
    ];
    // What the source serves this part at its best — its tallest frame and,
    // from fifty up, its pace — and the lossless tracks where the station
    // has them. A page with no rendition yet names none of it.
    final videos = _play?.videos ?? const <VodDashVideo>[];
    final best = videos.isEmpty
        ? null
        : videos.reduce((tallest, video) => (video.height ?? 0) > (tallest.height ?? 0) ? video : tallest);
    final specs = <String>[
      if (_play case final play? when best != null) ?vodQualityLabel(play, best.quality),
      if (best?.frameRate case final rate? when rate >= 50) '${rate.round()}fps',
      if (_play?.dolby != null) t.vod.specDolby,
      if (_play?.flac != null) t.vod.specHiRes,
    ];
    final uploader = detail.uploader ?? '';
    final avatar = detail.uploaderAvatar;
    // The uploader's card — the followers, the archive count, the signature —
    // read once per uploader. Null until it answers, and for a source that
    // answers nothing.
    final uploaderCard = showDetails && (detail.uploaderMid ?? 0) > 0
        ? ref.watch(vodUploaderCardProvider(detail.uploaderMid!)).value
        : null;
    final uploaderFigures = [
      if (uploaderCard?.fans case final fans?) '${AudienceFormat.format(fans)} ${t.vod.fans}',
      if (uploaderCard?.videoCount case final count?) t.vod.uploaderVideos(count: count),
    ].join(' · ');
    final uploaderSign = uploaderCard?.sign ?? '';
    // The archive's own cover frosted behind its details: the page's
    // words sit on the picture they belong to, the season head's way.
    final cover = detail.coverUrl;
    return DetailHeroBackdrop(
      coverImage: cover == null || cover.isEmpty ? null : cachedImage(cover, policy: ImageCachePolicies.videoCover),
      child: Padding(
        padding: const EdgeInsets.all(DsSpace.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s20,
          children: [
            if (_error != null)
              DsAlert(
                status: DsStatus.danger,
                title: Text(t.vod.openFailed),
                description: Text(_error!),
                action: _part == null
                    ? null
                    : DsButton(
                        variant: DsButtonVariant.secondary,
                        size: DsSize.sm,
                        onPressed: _retryOpen,
                        child: Text(t.vod.retry),
                      ),
              ),
            if (silent) DsAlert(status: DsStatus.warning, title: Text(t.vod.silentNotice)),
            if (showDetails && uploader.isNotEmpty)
              // The uploader's row leads the block: who made the archive
              // comes before what it is called. The row is their own door —
              // the space page keeps their archive list, and the detail's mid
              // is its address; a source that names no mid leaves the row a
              // name only. The follow chip rides at the row's end when the
              // cookie can speak it — the app's one follow button's shape.
              Row(
                spacing: DsSpace.s8,
                children: [
                  Expanded(
                    child: DsPressable(
                      semanticLabel: uploader,
                      onPressed: (detail.uploaderMid ?? 0) <= 0
                          ? null
                          : () => unawaited(context.push('/vod/u/${detail.uploaderMid}')),
                      builder: (context, states, _) {
                        final lit = states.contains(WidgetState.hovered);
                        return Row(
                          spacing: DsSpace.s8,
                          children: [
                            DsAvatar(
                              initials: avatarInitials(uploader),
                              image: avatar == null || avatar.isEmpty
                                  ? null
                                  : cachedImage(avatar, policy: ImageCachePolicies.avatar),
                              size: DsSize.md,
                              toneIndex: DsAvatar.toneFor(uploader),
                              semanticLabel: uploader,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: DsSpace.s3,
                                children: [
                                  Text(
                                    uploader,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.typography.bodyStrong.copyWith(
                                      color: lit ? colors.accentText : colors.text,
                                    ),
                                  ),
                                  // The card's figures where the station gave one — the followers
                                  // and the archive count — and the signature under them; the two
                                  // lines the detail itself carries stand in until it answers.
                                  Text(
                                    uploaderFigures.isEmpty ? t.vod.up : uploaderFigures,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.typography.caption.copyWith(color: colors.textMuted),
                                  ),
                                  if (uploaderSign.isNotEmpty)
                                    Text(
                                      uploaderSign,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.typography.caption.copyWith(color: colors.textSubtle),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (writable && (detail.uploaderMid ?? 0) > 0 && followed == true)
                    DsButton(
                      variant: DsButtonVariant.secondary,
                      size: DsSize.sm,
                      onPressed: () => unawaited(_toggleFollowUp()),
                      child: Text(t.vod.followedUp),
                    )
                  else if (writable && (detail.uploaderMid ?? 0) > 0)
                    DsButton(
                      variant: DsButtonVariant.primary,
                      size: DsSize.sm,
                      onPressed: () => unawaited(_toggleFollowUp()),
                      child: Text(t.vod.followUp),
                    ),
                ],
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s8,
              children: [
                Text(detail.title, style: theme.typography.title.copyWith(color: colors.text)),
                Wrap(
                  spacing: DsSpace.s16,
                  runSpacing: DsSpace.s4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: stats,
                ),
                if (specs.isNotEmpty)
                  Wrap(
                    spacing: DsSpace.s6,
                    runSpacing: DsSpace.s4,
                    children: [for (final spec in specs) DsBadge(label: Text(spec), dot: false)],
                  ),
              ],
            ),
            // Actions on one line, the crowd's numbers on the next: the buttons
            // are things the viewer does, the stats are things that happened,
            // and one Wrap mixed them into a single unordered strip.
            // The season page's three voices: the thing a viewer keeps, the
            // thing a viewer takes, the thing a viewer passes on.
            // One row of capsules where there used to be two rows of
            // dialects: the counts wear the capsule shape, the verbs are
            // the presses, and the saved video's answer is the accent's
            // tint. 点赞 answers when the cookie can speak it, and reads
            // as a fact the rest of the time; the coin costs its spender,
            // so it stays a fact; 收藏 remains the local shelf's verb;
            // 分享 and the download keep theirs — the download at the
            // row's far end, where a viewer's eye lands last.
            LayoutBuilder(
              builder: (context, constraints) {
                int displayedLikeCount(int count) {
                  final baseline = _likeBaseline;
                  if (liked == null || baseline?.aid != detail.aid) return count;
                  final total = count + (liked ? 1 : 0) - (baseline!.liked ? 1 : 0);
                  return total < 0 ? 0 : total;
                }

                final actionPills = <Widget>[
                  if (detail.likeCount case final count?)
                    VodStatPill(
                      icon: DsIcons.thumbsUp,
                      label: t.vod.likes,
                      value: AudienceFormat.format(displayedLikeCount(count)),
                      active: writable && liked == true,
                      onPressed: writable && detail.aid > 0 && liked != null ? () => unawaited(_toggleLike()) : null,
                    ),
                  if (detail.coinCount case final count?)
                    VodStatPill(icon: DsIcons.coins, label: t.vod.coins, value: AudienceFormat.format(count)),
                  if (detail.favoriteCount case final count?)
                    VodStatPill(icon: DsIcons.star, label: t.vod.favorites, value: AudienceFormat.format(count)),
                  VodStatPill(
                    icon: DsIcons.heart,
                    label: saved ? t.vod.savedVideo : t.vod.saveVideo,
                    value: saved ? t.vod.savedVideo : t.vod.saveVideo,
                    active: saved,
                    onPressed: () => unawaited(_toggleFavourite()),
                  ),
                  VodStatPill(
                    icon: DsIcons.share,
                    label: t.vod.share,
                    value: t.vod.share,
                    onPressed: () => unawaited(_share()),
                  ),
                ];
                final downloadButton = DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: _part == null ? null : () => unawaited(_startDownload()),
                  leading: const DsIcon(DsIcons.download, size: 14),
                  child: Text(t.player.download),
                );
                if (constraints.maxWidth >= 720) {
                  return Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: DsSpace.s8,
                          runSpacing: DsSpace.s8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: actionPills,
                        ),
                      ),
                      const SizedBox(width: DsSpace.s8),
                      downloadButton,
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: DsSpace.s8,
                      runSpacing: DsSpace.s8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: actionPills,
                    ),
                    const SizedBox(height: DsSpace.s8),
                    Align(alignment: AlignmentDirectional.centerEnd, child: downloadButton),
                  ],
                );
              },
            ),
            const DsDivider(),
            if (showParts && detail.parts.length > 1)
              _PartsSection(
                parts: detail.parts,
                current: _part,
                onOpen: (part) => unawaited(_openPart(part, resume: _resumeFor(part))),
              ),
            if (showDetails) ...[
              _description(context, detail, t),
              if (detail.aid > 0) _CommentsSection(aid: detail.aid),
            ],
          ],
        ),
      ),
    );
  }
}

/// Whether this host offers the desktop-only window-fullscreen button — the
/// room bar's own rule: the picture filling the app window while the window
/// stays a window is a desktop shell's verb.
bool get _desktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux);

/// The catalogues the video bar hangs over the picture. The picture's fit is
/// not one of them any more: it reads from the strip's ⋮ menu, where a choice
/// made once belongs.
enum _VodPanel { quality, parts, speed, subtitle, danmaku, danmakuList }

/// The picture's box: a fixed 16:9 card inline, the container's own shape in
/// the immersive modes.
///
/// The compact window is already shaped to the video, and a phone turned
/// landscape has no room for bars around a card; a fixed 16:9 box there would
/// letterbox the picture a second time inside it.
final class _PictureBox extends StatelessWidget {
  const _PictureBox({required this.immersive, required this.child});

  /// Whether the surface takes the container's shape (the immersive modes).
  final bool immersive;

  /// The picture and its controls.
  final Widget child;

  @override
  Widget build(BuildContext context) => immersive ? child : AspectRatio(aspectRatio: 16 / 9, child: child);
}

/// One count in the archive's action row: the station's own reading — a
/// glyph and its number in flat ink, no capsule behind them.
final class _PartsSection extends StatefulWidget {
  const _PartsSection({required this.parts, required this.current, required this.onOpen});

  final List<VodPart> parts;

  /// The part the page is playing, when one is.
  final VodPart? current;

  /// Runs when the viewer picks another part.
  final void Function(VodPart part) onOpen;

  @override
  State<_PartsSection> createState() => _PartsSectionState();
}

final class _PartsSectionState extends State<_PartsSection> {
  /// One row's height, and the list's ceiling: a course running to hundreds
  /// of parts scrolls inside the panel rather than stretching the rail.
  static const double _rowHeight = 44;
  static const double _listMaxHeight = 420;

  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _keepCurrentVisible();
  }

  @override
  void didUpdateWidget(_PartsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Switching the playing part — from here or from the bar's catalogue —
    // scrolls the playing row back into view.
    if (oldWidget.current?.cid != widget.current?.cid) _keepCurrentVisible();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls the playing part's row into view: a list this long opens with
  /// the thing being played on screen, not buried past the fold.
  void _keepCurrentVisible() {
    final index = _indexOf(widget.current);
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final target = (index * _rowHeight).clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.jumpTo(target);
    });
  }

  int _indexOf(VodPart? part) {
    if (part == null) return -1;
    return widget.parts.indexWhere((candidate) => candidate.cid == part.cid);
  }

  /// Asks for a part number and opens it; an empty or unknown answer leaves
  /// the list where it was.
  Future<void> _jump() async {
    final parts = widget.parts;
    if (parts.isEmpty) return;
    int? parse(String typed) {
      final number = int.tryParse(typed.trim());
      if (number == null) return null;
      final byPage = parts.where((part) => part.page == number);
      if (byPage.isNotEmpty) return parts.indexOf(byPage.first);
      return number >= 1 && number <= parts.length ? number - 1 : null;
    }

    final position = await showVodJumpDialog(
      context,
      title: context.t.vod.partsJump,
      count: parts.length,
      parse: parse,
    );
    if (position == null || position < 0 || position >= parts.length) return;
    widget.onOpen(parts[position]);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final parts = widget.parts;
    final current = _indexOf(widget.current);
    final muted = theme.typography.caption.copyWith(color: colors.textMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        SectionHeader(
          title: t.vod.partsPlaylist,
          count: parts.length,
          trailing: [
            DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              leading: const DsIcon(DsIcons.listOrdered, size: 16),
              onPressed: () => unawaited(_jump()),
              child: Text(t.vod.partsJump),
            ),
          ],
        ),
        DsCard(
          style: const DsCardStyle(padding: EdgeInsets.zero),
          child: SizedBox(
            height: math.min(parts.length * _rowHeight + DsSpace.s8 * 2, _listMaxHeight),
            child: ListView.builder(
              controller: _scroll,
              itemExtent: _rowHeight,
              padding: const EdgeInsets.symmetric(vertical: DsSpace.s4),
              itemCount: parts.length,
              itemBuilder: (context, index) {
                final part = parts[index];
                final playing = index == current;
                return DsPressable(
                  semanticLabel: 'P${part.page} ${part.title}',
                  onPressed: () => widget.onOpen(part),
                  builder: (context, states, child) => ColoredBox(
                    color: playing
                        ? colors.accent.withValues(alpha: 0.14)
                        : states.contains(WidgetState.hovered)
                        ? colors.hover
                        : OnVideoColors.clear,
                    child: child,
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(horizontal: DsSpace.s12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          child: Text(
                            'P${part.page}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.numeric(
                              theme.typography.caption.copyWith(
                                color: playing ? colors.accent : colors.textSubtle,
                                fontWeight: playing ? FontWeight.w600 : null,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            part.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.caption.copyWith(
                              color: playing ? colors.accent : colors.text,
                              fontWeight: playing ? FontWeight.w600 : null,
                            ),
                          ),
                        ),
                        if (part.duration != null)
                          Text(vodDurationText(part.duration!), style: theme.typography.numeric(muted)),
                        if (playing) ...[
                          const SizedBox(width: DsSpace.s6),
                          DsIcon(DsIcons.play, size: 12, color: colors.accent),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

final class _CommentsSection extends ConsumerStatefulWidget {
  const _CommentsSection({required this.aid});

  final int aid;

  @override
  ConsumerState<_CommentsSection> createState() => _CommentsSectionState();
}

final class _CommentsSectionState extends ConsumerState<_CommentsSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(vodCommentsProvider.notifier).open(widget.aid));
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final state = ref.watch(vodCommentsProvider.select((comments) => comments[widget.aid]));
    final comments = state?.comments ?? const <VodComment>[];
    final controller = ref.read(vodCommentsProvider.notifier);
    // The header counts what the comments endpoint reported, not the danmaku
    // figure the detail carries — until the first page lands it says nothing.
    final count = state?.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        SectionHeader(
          title: t.vod.comments,
          count: count,
          trailing: [
            // The reference's two orders; a pick restarts from the first page.
            DsSegmentedControl<int>(
              value: state?.sort ?? VodCommentsController.sortHot,
              onChanged: (state?.loading ?? false) ? null : (sort) => unawaited(controller.setSort(widget.aid, sort)),
              semanticLabel: t.vod.comments,
              segments: [
                DsSegment(value: VodCommentsController.sortHot, label: Text(t.vod.commentsHot)),
                DsSegment(value: VodCommentsController.sortNewest, label: Text(t.vod.commentsNew)),
              ],
            ),
          ],
        ),
        if (state?.error case final failure?)
          DsAlert(
            status: DsStatus.danger,
            title: Text(t.vod.commentsFailed),
            description: Text(failure.message),
            action: DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              onPressed: () => unawaited(controller.retry(widget.aid)),
              child: Text(t.vod.retry),
            ),
          ),
        if (state != null && state.loading && comments.isEmpty)
          const Center(child: DsSpinner(style: DsSpinnerStyle(size: 24)))
        else if (state != null && state.error == null && comments.isEmpty)
          Text(t.vod.commentsEmpty, style: theme.typography.body.copyWith(color: colors.textMuted)),
        for (final (index, comment) in comments.indexed) ...[
          if (index > 0) const DsDivider(),
          _CommentRow(comment: comment),
        ],
        if ((state?.hasMore ?? false) && comments.isNotEmpty)
          Center(
            child: (state?.loading ?? false)
                ? const DsSpinner(style: DsSpinnerStyle(size: 24))
                : DsButton(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    onPressed: () => unawaited(controller.loadMore(widget.aid)),
                    child: Text(t.vod.loadMore),
                  ),
          ),
      ],
    );
  }
}

/// One comment, drawn the way the station lays its floor out: the author's
/// avatar and name, the words, then the floor's own line — when it was
/// posted, the likes it drew, the replies it gathered.
final class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment});

  final VodComment comment;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final avatar = comment.avatar;
    final posted = comment.createdAt;
    final likes = comment.likeCount ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.s6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s8,
        children: [
          DsAvatar(
            initials: avatarInitials(comment.author),
            image: avatar == null || avatar.isEmpty ? null : cachedImage(avatar, policy: ImageCachePolicies.userAvatar),
            size: DsSize.sm,
            toneIndex: DsAvatar.toneFor(comment.author),
            semanticLabel: comment.author,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s4,
              children: [
                Text(
                  comment.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(color: colors.text, fontWeight: FontWeight.w600),
                ),
                Text(comment.message, style: theme.typography.body.copyWith(color: colors.text)),
                Row(
                  spacing: DsSpace.s12,
                  children: [
                    if (posted != null)
                      Text(
                        vodDateText(posted),
                        style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textSubtle)),
                      ),
                    if (likes > 0) ...[
                      DsIcon(DsIcons.thumbsUp, size: theme.sizes.iconXs, color: colors.textSubtle),
                      Text(
                        AudienceFormat.format(likes),
                        style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textSubtle)),
                      ),
                    ],
                    if ((comment.replyCount ?? 0) > 0) ...[
                      DsIcon(DsIcons.messageCircle, size: theme.sizes.iconXs, color: colors.textSubtle),
                      Text(
                        AudienceFormat.format(comment.replyCount ?? 0),
                        style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textSubtle)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The archive's loading shape: bars where the title, its meta and the
/// verbs will stand, a block where the blurb goes, the stage's own box
/// first — the page opens already shaped like itself, not as a spinner on
/// an empty canvas.
final class _VideoSkeleton extends StatelessWidget {
  const _VideoSkeleton();

  @override
  Widget build(BuildContext context) {
    final windowSize = MediaQuery.sizeOf(context);
    final playbackLayout = PlaybackLayout.resolve(width: windowSize.width, height: windowSize.height);
    final compact = playbackLayout.windowClass == PlaybackWindowClass.compact;
    final gutter = compact ? DsSpace.s12 : LiveWindow.pageInset(windowSize.width);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          // The stage's own box: a 16:9 frame at the top, flush on the
          // phone the way the playing page stands.
          const AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(color: OnVideoColors.ground),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s12,
              children: [
                DsSkeleton(width: double.infinity, height: 20, strong: true),
                DsSkeleton(width: 220, height: 12),
                Row(
                  spacing: DsSpace.s8,
                  children: [DsSkeleton(width: 88, height: 14), DsSkeleton(width: 88, height: 14)],
                ),
                DsSkeleton.block(width: double.infinity, height: 64),
                DsSkeleton.block(width: double.infinity, height: 120),
                Row(
                  spacing: DsSpace.s8,
                  children: [DsSkeleton(width: 160, height: 14), DsSkeleton(width: 200, height: 14)],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: DsSpace.s12),
            child: Align(
              alignment: AlignmentDirectional.center,
              child: DsSpinner(style: DsSpinnerStyle(size: 24)),
            ),
          ),
        ],
      ),
    );
  }
}
