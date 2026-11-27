import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:io' show InternetAddress;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/services.dart' show Clipboard, ClipboardData, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_device/live_device.dart'
    show PlatformScreenAwakeService, PlatformScreenOrientationService, ScreenAwakeService, ScreenOrientationService;
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:media_core/media_core.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_account_state.dart'
    show hongguoAccountClientProvider, hongguoAccountProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_client.dart'
    show
        hongguoClientProvider,
        hongguoFailureText,
        hongguoLowerRendition,
        hongguoPickRendition,
        hongguoStreamProxyProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_comfort.dart'
    show HongguoRecoveryBudget, HongguoSleepTimer;
import 'package:pure_live/modules/hongguo/controller/hongguo_danmaku.dart'
    show HongguoDanmakuDensity, hongguoDanmakuSettingsProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_decoder.dart' show hongguoDecoderLessonsProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_downloads.dart'
    show
        HongguoDownloadEnqueue,
        HongguoDownloadItem,
        HongguoDownloadPhase,
        hongguoDownloadOf,
        hongguoDownloadQualityProvider,
        hongguoDownloadsProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_library.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_settings.dart'
    show HongguoQualityChoice, hongguoSettingsProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_social.dart'
    show HongguoDanmakuController, hongguoDanmakuProvider;
import 'package:pure_live/modules/hongguo/official/hongguo_account.dart' show HongguoAccountClient, HongguoCredentials;
import 'package:pure_live/modules/hongguo/official/hongguo_official.dart' show HongguoRendition, kHongguoSite;
import 'package:pure_live/modules/hongguo/widgets/hongguo_comment_panel.dart' show HongguoCommentPanel;
import 'package:pure_live/modules/hongguo/widgets/hongguo_danmaku_layer.dart' show HongguoDanmakuLayer;
import 'package:pure_live/modules/hongguo/widgets/hongguo_episode_shelf.dart'
    show
        HongguoEpisodeFoldaway,
        HongguoEpisodeList,
        hongguoEpisodeGroupOf,
        hongguoEpisodeMarks,
        hongguoEpisodeRangeLabel,
        kHongguoEpisodeGroup;
import 'package:pure_live/modules/hongguo/widgets/hongguo_widgets.dart' show hongguoDurationText;
import 'package:pure_live/modules/live/room/page/chat_splitter.dart' show ChatSplitter;
import 'package:pure_live/modules/vod/widgets/vod_widgets.dart' show VodFoldedText, VodRailDoor;
import 'package:pure_live/shared/player/player_danmaku_list_panel.dart';
import 'package:pure_live/shared/shared.dart';

/// The catalogues the picture bar hangs over. The picture's fit is not among
/// them: it is picked on the shared choice panel, from the more container.
enum _HongguoPanel { sleep, speed, quality, episodes, danmaku, danmakuList }

typedef _HongguoOpenRequest = ({
  HongguoEpisode episode,
  double? resume,
  bool recovering,
  bool downgrade,
  bool autoplay,
});

/// One episode's player page: the stage, its corner cluster and control row,
/// the action column along its edge and the episode shelf beside or beneath,
/// pushed from the series page's play card.
///
/// Playback is one shared media_core handle fed the service's decrypted,
/// rangeable mp4. Progress is saved per series (episode + seconds) so a
/// return resumes where it stopped, and a finished episode leads to the next
/// one on its own; a failure learns the device's real decoding limits, spends
/// its recovery budget, or waits for the network rather than burn it.
final class HongguoPlayerPage extends ConsumerStatefulWidget {
  /// The player for [seriesId], opened at [episodeVid] and [resumeSeconds]
  /// when the caller names them — otherwise the shelf's own checkpoint is
  /// used, or the first episode.
  const HongguoPlayerPage({required this.seriesId, this.episodeVid, this.resumeSeconds, super.key});

  /// The series' id.
  final String seriesId;

  /// The episode to open, when the caller chose one.
  final String? episodeVid;

  /// Where inside it to start, in seconds.
  final double? resumeSeconds;

  @override
  ConsumerState<HongguoPlayerPage> createState() => _HongguoPlayerPageState();
}

final class _HongguoPlayerPageState extends ConsumerState<HongguoPlayerPage> with RouteAware, WidgetsBindingObserver {
  HongguoSeriesDetail? _detail;
  HongguoEpisode? _episode;
  PlayerHandle? _handle;

  /// The address the episode plays from — kept for the cast, which sends a
  /// TV what this player is reading.
  String? _playUrl;
  PlayerId? _boundPlayer;
  final FocusNode _playFocus = FocusNode(debugLabel: 'hongguo-play');
  StreamSubscription<PlayerTransportState>? _transportSub;
  StreamSubscription<PlayerAdapterEvent>? _eventSub;
  StreamSubscription<GeometryState>? _geometrySub;
  PlayerTransportState? _transport;
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);

  /// When the position was last handed to the cloud. The local row saves
  /// every few seconds; the platform needs to hear from it less often, and
  /// each upload is a request.
  DateTime _lastCloudSave = DateTime.fromMillisecondsSinceEpoch(0);

  /// Whether the overlay bar is up; a playing picture lets it settle away.
  bool _controlsVisible = true;

  /// The display's wake lock: held while an episode plays and the app's own
  /// 屏幕常亮 allows it, the same rule the live room and the IPTV page keep.
  final ScreenAwakeService _screenAwake = const PlatformScreenAwakeService();
  bool _screenHeld = false;

  /// The Android background gate behind the app's 后台播放 switch: the room,
  /// the IPTV page and the video station all keep one; this page played
  /// without asking the switch, so the setting did nothing here.
  BackgroundPlaybackGate? _backgroundGate;
  PlayerId? _backgroundPausedHandle;

  /// The overlay's timers: the bar's hide, and a picker's open and close.
  Timer? _hideTimer;
  Timer? _hoverTimer;
  Timer? _leaveTimer;

  /// The catalogue hanging over the bar, when one is open.
  _HongguoPanel? _openPanel;

  /// The watching lock, the room's own rule: locked, the strip, the bar and
  /// the picture's gestures all stand down, and the unlock pill on the
  /// picture's right edge is the only thing left to press.
  bool _locked = false;

  /// The bar and each picker's box: the open catalogue hangs over the button
  /// that raised it rather than at the picture's end edge.
  final GlobalKey _barAnchor = GlobalKey(debugLabel: 'hongguo-bar');
  final Map<_HongguoPanel, GlobalKey> _panelAnchors = {
    for (final panel in _HongguoPanel.values) panel: GlobalKey(debugLabel: 'hongguo-picker-${panel.name}'),
  };

  /// The page of the episodes catalogue hanging over the bar. Null follows the
  /// playing episode, so a series hundreds deep opens where the viewer stands
  /// rather than at its first; a range button takes the page over.
  int? _episodesGroup;
  bool _loading = true;
  bool _opening = false;
  bool _disposed = false;
  bool _finished = false;
  String? _error;
  double? _dragSeconds;
  double? _resumeSeconds;
  bool _muted = false;
  bool _globalMute = false;
  double _volume = 1;
  double _speed = 1;

  /// The arrow key's seek: the presses of one held key step bigger each
  /// time, and the count forgets itself once the key rests.
  int _keySeekSteps = 0;
  Timer? _keySeekTimer;

  /// The volume a wheel is setting right now; null while no gesture shows it.
  /// A vertical drag belongs to the episodes here, so this surface answers the
  /// wheel only — the chip and the fade are the room's.
  double? _volumeHud;
  Timer? _volumeHudTimer;

  /// Sound only: the episode keeps playing and the picture is put away.
  bool _audioOnly = false;

  /// The speed a press-and-hold fast-forward runs at, and the speed it
  /// restores on release — or the speed a locked hold unlocks to.
  static const double _holdSpeed = 2;
  double _speedBeforeHold = 1;
  double _lockedFromSpeed = 1;
  bool _holding = false;
  bool _speedLocked = false;

  /// How far the current vertical swipe has travelled, in logical pixels.
  double _swipeDy = 0;

  /// The session's sleep timer and the ticker that watches its deadline.
  final HongguoSleepTimer _sleep = HongguoSleepTimer();
  Timer? _sleepTicker;
  int _sleepShownMinutes = 0;

  /// Whether the sleep timer stopped this session; pressing play resumes.
  bool _sleepStopped = false;

  /// This episode's automatic-recovery budget and the pending retry.
  final HongguoRecoveryBudget _recovery = HongguoRecoveryBudget();
  Timer? _recoveryTimer;
  bool _autoRecovery = false;

  /// Whether the last failure is waiting for the network to come back: the
  /// device had no connection, so the retry budget is not spent on timers
  /// that can only fail — the first reading that is online again plays on.
  bool _waitingForNetwork = false;
  ProviderSubscription<bool>? _networkWait;

  /// Where a failed play was, so a retry resumes there rather than at the
  /// episode's head.
  Duration _retryPosition = Duration.zero;
  bool _retryAutoplay = true;

  /// The complete open request made while another open was running, so the
  /// final tap keeps its checkpoint and retry semantics instead of being
  /// reduced to an episode id.
  _HongguoOpenRequest? _pendingEpisode;

  /// What the last failure was, for the panel's line.
  String? _lastFailure;

  /// The rendition this episode opened with — the lesson's subject when the
  /// engine refuses to decode it.
  HongguoRendition? _attempted;

  /// The ladder the current episode opened from, so a downgrade need not ask
  /// again.
  List<HongguoRendition>? _lastLadder;

  /// How many automatic downgrades this episode already took.
  int _autoDowngrades = 0;

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

  /// The episode a covered route paused, kept apart from the background gate.
  PlayerId? _routePausedHandleId;
  Future<void>? _routePause;
  int _routePauseGeneration = 0;

  // Captured while the page is alive; `ref` is refused by the time dispose
  // runs, and the leaving page must still exit its presentation mode and
  // release its handle.
  late final RoomPresentationController _presentationNotifier;
  late final PlayerKernel _kernel;
  late final HongguoAccountClient _accountClient;
  late final HongguoLibraryController _library;

  /// The danmaku clock the leaving page stops; captured for the same reason as
  /// the rest of this block.
  late final HongguoDanmakuController _danmakuNotifier;

  /// The sign-in the last build saw; the leaving page uploads with it
  /// rather than asking a disposed scope.
  HongguoCredentials? _accountCredentials;

  /// The presentation mode, followed through a manual listener for the same
  /// reason: the leaving page reads its own field, not `ref`.
  PresentationMode _presentationMode = PresentationMode.normal;

  bool get _effectivelyMuted => _muted || _globalMute;

  bool get _playerReady {
    final handle = _handle;
    return handle != null &&
        !_opening &&
        handle.source != null &&
        handle.state.canControl &&
        ((_transport?.initialized ?? false) || _sleepStopped);
  }

  /// A TV cannot read this page's loopback proxy. Keep its tokenised address
  /// on this device; only a directly reachable source may leave through cast.
  String? get _castUrl {
    final raw = _playUrl;
    if (raw == null) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) return null;
    final host = uri.host.toLowerCase();
    final normalized = host.endsWith('.') ? host.substring(0, host.length - 1) : host;
    if (normalized.isEmpty || normalized == 'localhost' || normalized.endsWith('.localhost')) return null;
    if (InternetAddress.tryParse(normalized)?.isLoopback ?? false) return null;
    return raw;
  }

  /// A desktop owns the window-fullscreen verb; a phone has no window to
  /// widen.
  bool get _desktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// The rate ladder the speed panel lists; the keyboard walks it step by
  /// step.
  static const List<double> _speedChoices = [0.5, 0.75, 1, 1.25, 1.5, 2];

  @override
  void initState() {
    super.initState();
    _presentationNotifier = ref.read(roomPresentationProvider.notifier);
    _kernel = ref.read(playerKernelProvider);
    _accountClient = ref.read(hongguoAccountClientProvider);
    _library = ref.read(hongguoLibraryProvider.notifier);
    _danmakuNotifier = ref.read(hongguoDanmakuProvider.notifier);
    _resumeSeconds = widget.resumeSeconds;
    ref.listenManual(roomPresentationProvider, (_, next) => _presentationMode = next, fireImmediately: true);
    WidgetsBinding.instance.addObserver(this);
    _globalMute = ref.read(playbackSettingsProvider).globalMute;
    _volume = ref.read(modulePlaybackSettingsProvider(PlayerModule.hongguo)).volume;
    _backgroundGate = BackgroundPlaybackGate(
      backgroundEnabled: () => ref.read(playbackSettingsProvider).backgroundPlay,
      shouldPause: () =>
          (_transport?.isPlaying ?? false) &&
          _presentationMode != PresentationMode.pip &&
          _presentationMode != PresentationMode.floating,
      pause: () async {
        _backgroundPausedHandle = _handle?.id;
        try {
          await _handle?.pause();
        } on Object {
          // A player that will not answer still counts as paused here.
        }
      },
      canResume: () =>
          _backgroundPausedHandle != null &&
          _handle != null &&
          _handle?.id == _backgroundPausedHandle &&
          !_sleepStopped &&
          !(_transport?.isPlaying ?? false),
      resume: () async {
        _backgroundPausedHandle = null;
        try {
          await _handle?.play();
        } on Object {
          // The transport's own state decides what the bar shows next.
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _backgroundGate?.handleLifecycle(state);
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

  /// Another page covers this one: the picture pauses rather than playing
  /// under it.
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
    final covered = _routeCovered;
    final generation = ++_routePauseGeneration;
    final pausedHandleId = _routePausedHandleId;
    final pause = _routePause;
    final handle = _handle;
    final opening = pausedHandleId == null && (_opening || handle == null);
    _routeCovered = false;
    _routeResumeWhenReady = opening && covered && _routeAutoplayRequested && !_sleepStopped;
    _routePausedHandleId = null;
    _routePause = null;
    if (_routeResumeWhenReady) return;
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
    if (!mounted || _disposed || generation != _routePauseGeneration || _handle?.id != handle.id || _sleepStopped) {
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

  /// Holds the display awake exactly while the episode plays and the
  /// preference allows it.
  void _syncScreenWake(bool hold) {
    if (hold == _screenHeld) return;
    _screenHeld = hold;
    unawaited((hold ? _screenAwake.enable() : _screenAwake.disable()).catchError((Object _) {}));
  }

  /// The page's hold on the app's sound: playing an episode hushes a live
  /// window or the music the viewer left running.
  void _holdSound() {
    unawaited(
      ref
          .read(audioArbiterProvider.notifier)
          .claim(
            AudioOwner(AudioOwnerKind.audiobook, 'hongguo:${widget.seriesId}'),
            () => Future<void>.value(_handle?.pause()),
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
    _routePausedHandleId = null;
    _routePause = null;
    if (_route != null) _routeObserver?.unsubscribe(this);
    _route = null;
    ref.read(audioArbiterProvider.notifier).release(AudioOwner(AudioOwnerKind.audiobook, 'hongguo:${widget.seriesId}'));
    _backgroundGate?.dispose();
    _backgroundGate = null;
    unawaited(_screenAwake.disable().catchError((Object _) {}));
    // The player goes quiet before anything else: the route's leave animation
    // runs while the release's queue drains, and the episode must not be
    // heard over the page the viewer returned to.
    final handle = _handle;
    if (handle != null) {
      if (_presentationMode != PresentationMode.normal) {
        unawaited(_presentationNotifier.exit(handle.id));
      }
      silencePlayer(handle);
      unawaited(_kernel.release(handle.id));
    }
    WidgetsBinding.instance.removeObserver(this);
    _saveProgress(force: true);
    _hideTimer?.cancel();
    _hideTimer = null;
    _volumeHudTimer?.cancel();
    _volumeHudTimer = null;
    _hoverTimer?.cancel();
    _hoverTimer = null;
    _leaveTimer?.cancel();
    _leaveTimer = null;
    _sleepTicker?.cancel();
    _sleepTicker = null;
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
    _keySeekTimer?.cancel();
    _keySeekTimer = null;
    _networkWait?.close();
    _networkWait = null;
    unawaited(_transportSub?.cancel() ?? Future<void>.value());
    unawaited(_eventSub?.cancel() ?? Future<void>.value());
    unawaited(_geometrySub?.cancel() ?? Future<void>.value());
    _geometrySub = null;
    // The stop resets provider state, refused during teardown; it lands
    // after the frame instead.
    Timer.run(_danmakuNotifier.stop);
    _playFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _stopWaiting();
    setState(() {
      _loading = true;
      _error = null;
      _transport = null;
    });
    try {
      final detail = await ref.read(hongguoClientProvider).detail(widget.seriesId);
      if (!mounted || _disposed) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
      final episodes = detail.episodes;
      if (episodes.isEmpty) return;
      final resume = _readProgress();
      final chosen = widget.episodeVid == null
          ? episodes.firstWhere((episode) => episode.index == resume?.index, orElse: () => episodes.first)
          : episodes.firstWhere((episode) => episode.vid == widget.episodeVid, orElse: () => episodes.first);
      await _openEpisode(chosen, resume: _resumeSeconds ?? resume?.seconds);
    } on Object catch (error) {
      appLog.forCategory('hongguo.play').warning('playback step failed', fields: {'error': '$error'});
      if (!mounted || _disposed) return;
      setState(() {
        _loading = false;
        _error = hongguoFailureText(error);
      });
    }
  }

  /// Opens [episode] on the shared kernel, reusing the page's handle; a
  /// finished episode's last seconds are not replayed. [recovering] is an
  /// automatic retry — the sleep stop stands, and the episode's recovery
  /// budget carries over; [downgrade] asks the ladder for the next tier down.
  Future<void> _openEpisode(
    HongguoEpisode episode, {
    double? resume,
    bool recovering = false,
    bool downgrade = false,
    bool autoplay = true,
  }) async {
    if (_opening) {
      _pendingEpisode = (
        episode: episode,
        resume: resume,
        recovering: recovering,
        downgrade: downgrade,
        autoplay: autoplay,
      );
      return;
    }
    _stopWaiting();
    final sameEpisode = _episode?.vid == episode.vid;
    if (!recovering) _saveProgress(force: true);
    if (!sameEpisode) {
      _recovery.reset();
      _autoDowngrades = 0;
      _attempted = null;
      _lastFailure = null;
      // The failed episode's retry position belongs to that episode: a
      // switch that fails must not resume the new one where the old one
      // was left.
      _retryPosition = Duration.zero;
    }
    setState(() {
      _opening = true;
      _error = null;
      _episode = episode;
      _transport = null;
      _dragSeconds = null;
      _finished = false;
      if (!recovering) _sleepStopped = false;
    });
    _routeAutoplayRequested = autoplay && !_sleepStopped;
    _routePauseGeneration++;
    _routePausedHandleId = null;
    _routePause = null;
    _routeResumeWhenReady = false;
    final client = ref.read(hongguoClientProvider);
    // The episode being left stops before the next address is fetched, so a
    // failed switch cannot leave it sounding under the new episode's page.
    final previous = _handle;
    if (previous != null) {
      try {
        await previous.pause();
      } on Object {
        // The switch itself reports a player that will not answer.
      }
    }
    try {
      // The ladder answers the renditions the platform serves this episode,
      // and — in the same round trip — the next two episodes' models, so a
      // handoff needs no second ask. The pick rides through the local
      // decrypting proxy so the player reads plain mp4 off the loopback.
      final ladder = await client.playbackLadder(episode.vid, ahead: _aheadVids(episode));
      if (!mounted || _disposed) return;
      _lastLadder = ladder;
      final lessons = ref.read(hongguoDecoderLessonsProvider);
      final maxHeight = ref.read(hongguoSettingsProvider).quality.maxHeight;
      final attempted = _attempted;
      final rendition = downgrade && attempted != null
          ? hongguoLowerRendition(ladder, attempted, maxHeight, learnedFailures: lessons) ??
                hongguoPickRendition(ladder, maxHeight, learnedFailures: lessons)
          : hongguoPickRendition(ladder, maxHeight, learnedFailures: lessons);
      _attempted = rendition;
      final url = await ref.read(hongguoStreamProxyProvider).register(rendition);
      if (!mounted || _disposed) return;
      final existing = _handle;
      final handle =
          existing ??
          await _kernel.create(
            config: PlayerConfig(name: 'hongguo', volume: _volume, muted: _effectivelyMuted),
            preferredBackend: ref.read(playerKernelBackendProvider).id,
          );
      if (!mounted || _disposed) {
        if (existing == null) {
          silencePlayer(handle);
          unawaited(_kernel.release(handle.id));
        }
        return;
      }
      _handle = handle;
      _bind(handle);
      _holdSound();
      // A playing mini window belongs to the episode the viewer just left;
      // a new one here supersedes it (its close path checkpoints the old).
      FloatingVideoWindow.dismiss();
      await _applyEngineOptions(handle);
      final uri = Uri.parse(url);
      // Kept only if it is directly reachable: the loopback proxy's token
      // address belongs to this device and must never be handed to a TV.
      _playUrl = url;
      await handle.setVolume(_volume);
      await handle.setMute(muted: _effectivelyMuted);
      await handle.open(
        PlayerSource.of(
          id: SourceId('hongguo:${widget.seriesId}:${episode.vid}:${DateTime.now().microsecondsSinceEpoch}'),
          uri: uri,
          type: SourceType.remote,
          protocol: SourceProtocol.fromScheme(uri.scheme),
          format: SourceFormat.fromUri(uri),
          title: _detail?.meta.title ?? episode.title,
        ),
        autoPlay: autoplay && !_sleepStopped && !_routeCovered,
      );
      await handle.setVolume(_volume);
      await handle.setMute(muted: _effectivelyMuted);
      await handle.setRate(_speed);
      if (_audioOnly) await _applyAudioOnly(handle);
      final seekTo = resume ?? _resumeSeconds;
      _resumeSeconds = null;
      if (seekTo != null && seekTo > 5) {
        await handle.seek(Duration(milliseconds: (seekTo * 1000).round()));
      }
      if (!mounted || _disposed) return;
      await _settleRouteAutoplay(handle);
      setState(() {
        _opening = false;
        _error = null;
      });
      _drainPending(episode);
    } on Object catch (error) {
      appLog.forCategory('hongguo.play').warning('playback step failed', fields: {'error': '$error'});
      if (!mounted || _disposed) return;
      // The handle may still hold the previous episode; it is not the
      // episode this page now names, so it goes rather than playing on
      // behind a failed switch.
      final stale = _handle;
      if (stale != null) {
        _handle = null;
        silencePlayer(stale);
        unawaited(_kernel.release(stale.id));
      }
      setState(() => _opening = false);
      if (_drainPending(episode)) return;
      _onPlaybackFailure(error);
    }
  }

  /// Opens the episode asked for while an open ran, when it differs from
  /// the one that just settled; answers whether it took over.
  bool _drainPending(HongguoEpisode settled) {
    final pending = _pendingEpisode;
    _pendingEpisode = null;
    if (pending == null || pending.episode.vid == settled.vid) return false;
    unawaited(
      _openEpisode(
        pending.episode,
        resume: pending.resume,
        recovering: pending.recovering,
        downgrade: pending.downgrade,
        autoplay: pending.autoplay,
      ),
    );
    return true;
  }

  /// The vids after [episode], at most two — the models fetched ahead.
  List<String> _aheadVids(HongguoEpisode episode) {
    final episodes = _detail?.episodes ?? const <HongguoEpisode>[];
    final index = episodes.indexWhere((row) => row.vid == episode.vid);
    if (index < 0) return const [];
    return [for (final row in episodes.skip(index + 1).take(2)) row.vid];
  }

  /// A playback failure, from whichever layer: the progress is kept, the
  /// engine's refusal of a rendition is learned and downgraded, and what is
  /// left is handed to the recovery budget — the reference's order.
  void _onPlaybackFailure(Object error) {
    if (!mounted || _disposed) return;
    final failure = hongguoFailureText(error);
    final position = _transport?.position ?? Duration.zero;
    if (position > Duration.zero) {
      _retryPosition = position;
    } else {
      // The stream never opened — a switch or a first open that failed: the
      // episode's own checkpoint is the resume, never the position the
      // episode before it was left at.
      final episode = _episode;
      final row = ref.read(hongguoLibraryProvider).progressOf(widget.seriesId);
      final index = episode == null || row == null
          ? -1
          : (_detail?.episodes.indexWhere((entry) => entry.vid == episode.vid) ?? -1);
      _retryPosition = row != null && index >= 0 && row.episodeIndex == index
          ? Duration(milliseconds: row.positionMs)
          : Duration.zero;
    }
    _retryAutoplay = !_sleepStopped;
    _saveProgress(force: true);
    _cancelRecovery();
    final attempted = _attempted;
    final episode = _episode;
    if (attempted != null && episode != null && _transport != null) {
      // The stream had opened, so the engine refused what it was given: the
      // device can do less than the probe claimed. Learn it and retry one
      // tier lower before the panel — at most twice, as the reference does.
      final learned = ref.read(hongguoDecoderLessonsProvider.notifier).learn(attempted);
      final ladder = _lastLadder;
      if (learned && _autoDowngrades < 2 && ladder != null) {
        final lessons = ref.read(hongguoDecoderLessonsProvider);
        final lower = hongguoLowerRendition(
          ladder,
          attempted,
          ref.read(hongguoSettingsProvider).quality.maxHeight,
          learnedFailures: lessons,
        );
        if (lower != null) {
          _autoDowngrades++;
          setState(() {
            _lastFailure = failure;
            _error = null;
          });
          unawaited(
            _openEpisode(
              episode,
              resume: _retryPosition.inMilliseconds / 1000,
              recovering: true,
              downgrade: true,
              autoplay: _retryAutoplay,
            ),
          );
          return;
        }
      }
    }
    final handle = _handle;
    if (handle != null) unawaited(handle.pause().catchError((Object _) {}));
    setState(() {
      _lastFailure = failure;
      _error = failure;
      _autoRecovery = _recovery.remaining && !_sleepStopped;
    });
    // No connection: the reference waits for it instead of burning retries
    // on timers that can only fail.
    if (!ref.read(isOnlineProvider)) {
      _waitForNetwork();
      return;
    }
    _scheduleRecovery();
  }

  /// Holds the failed episode until a reading says the device is online
  /// again, then continues where it stopped. The retry budget is untouched.
  void _waitForNetwork() {
    _cancelRecovery();
    _networkWait?.close();
    setState(() {
      _waitingForNetwork = true;
      _autoRecovery = false;
    });
    _networkWait = ref.listenManual<bool>(isOnlineProvider, (previous, next) {
      if (!next) return;
      _networkWait?.close();
      _networkWait = null;
      if (!mounted || _disposed || _error == null) return;
      final episode = _episode;
      if (episode == null) return;
      setState(() => _waitingForNetwork = false);
      unawaited(
        _openEpisode(episode, resume: _retryPosition.inMilliseconds / 1000, recovering: true, autoplay: _retryAutoplay),
      );
    });
  }

  /// Drops a pending wait: the viewer took over, or another episode opened.
  void _stopWaiting() {
    _networkWait?.close();
    _networkWait = null;
    if (!_waitingForNetwork) return;
    _waitingForNetwork = false;
    if (mounted && !_disposed) setState(() {});
  }

  /// Arms the next automatic retry, if the budget has one left.
  void _scheduleRecovery() {
    if (!mounted || _disposed || _error == null || !_autoRecovery || _sleepStopped) return;
    final delay = _recovery.delay;
    if (delay == null) {
      setState(() => _autoRecovery = false);
      return;
    }
    _recoveryTimer?.cancel();
    _recoveryTimer = Timer(delay, () {
      if (!mounted || _disposed || _error == null) return;
      final episode = _episode;
      if (episode == null || !_recovery.consume()) return;
      unawaited(
        _openEpisode(episode, resume: _retryPosition.inMilliseconds / 1000, recovering: true, autoplay: _retryAutoplay),
      );
    });
  }

  void _cancelRecovery() {
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
  }

  /// The viewer's explicit retry: the budget starts over.
  Future<void> _retryNow() async {
    final episode = _episode;
    if (episode == null) {
      await _load();
      return;
    }
    _cancelRecovery();
    _recovery.reset();
    setState(() => _error = null);
    await _openEpisode(episode, resume: _retryPosition.inMilliseconds / 1000, autoplay: _retryAutoplay);
  }

  /// A retry at [height], the panel's own downgrade: the preference moves
  /// down with it, so the next episode opens there too.
  Future<void> _retryLower(int height) async {
    final episode = _episode;
    if (episode == null) return;
    _cancelRecovery();
    _recovery.reset();
    _autoDowngrades = 0;
    for (final choice in HongguoQualityChoice.values) {
      if (choice.maxHeight == height) {
        unawaited(ref.read(hongguoSettingsProvider.notifier).setQuality(choice));
        break;
      }
    }
    setState(() => _error = null);
    await _openEpisode(episode, resume: _retryPosition.inMilliseconds / 1000, autoplay: _retryAutoplay);
  }

  /// Arms, replaces or clears the sleep timer; a running timer ticks its
  /// label once a minute and stops playback when its turn comes.
  void _setSleep({int? minutes, int? episodes}) {
    _cancelRecovery();
    if (minutes == null && episodes == null) {
      _sleep.cancel();
    } else if (minutes != null) {
      _sleep.afterMinutes(minutes);
    } else {
      _sleep.afterEpisodes(episodes!);
    }
    if (_sleep.active) {
      _sleepShownMinutes = _sleep.remaining?.inMinutes ?? 0;
      _sleepTicker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _disposed) return;
        if (_sleep.poll()) {
          unawaited(_stopForSleep());
          return;
        }
        // The button speaks in whole minutes; a tick that changed none of
        // them needs no rebuild of the picture.
        final minutes = _sleep.remaining?.inMinutes ?? 0;
        if (minutes == _sleepShownMinutes) return;
        _sleepShownMinutes = minutes;
        setState(() {});
      });
    } else {
      _sleepTicker?.cancel();
      _sleepTicker = null;
    }
    setState(() {});
  }

  /// The timer's turn: playback pauses, the position is kept, and the page
  /// says how to resume — the reference's `stopForSleep`.
  Future<void> _stopForSleep() async {
    _sleepStopped = true;
    _backgroundPausedHandle = null;
    _routePauseGeneration++;
    _routePausedHandleId = null;
    _routePause = null;
    _routeResumeWhenReady = false;
    _routeAutoplayRequested = false;
    _sleep.cancel();
    _sleepTicker?.cancel();
    _sleepTicker = null;
    _cancelRecovery();
    final handle = _handle;
    if (handle != null) {
      try {
        await handle.pause();
      } on Object {
        // The stop itself is what matters; a refused pause is reported by the
        // engine's own event.
      }
    }
    _saveProgress(force: true);
    if (!mounted || _disposed) return;
    setState(() {
      _autoRecovery = false;
    });
    showDsToast(context: context, title: context.t.hongguo.sleepStopped);
  }

  void _bind(PlayerHandle handle) {
    if (_boundPlayer == handle.id) return;
    _boundPlayer = handle.id;
    unawaited(_transportSub?.cancel() ?? Future<void>.value());
    unawaited(_eventSub?.cancel() ?? Future<void>.value());
    unawaited(_geometrySub?.cancel() ?? Future<void>.value());
    _geometrySub = handle.geometryController.state.listen((state) {
      if (!mounted) return;
      final size = state.geometry.videoSize;
      if (size.width <= 0 || size.height <= 0) return;
      _aspectRatio = size.width / size.height;
      // The fullscreen and compact-window drivers shape their surfaces from
      // the picture's own size; the small window locks to the video instead
      // of the config's 16:9.
      ref.read(fullscreenDriverProvider).onVideoSize(size.width, size.height);
      ref.read(pipDriverProvider).onVideoSize(size.width, size.height);
    });
    _transportSub = handle.playbackStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _transport = state;
        // A recovered engine keeps playing; the notice belongs to the
        // failure that stopped it, not to a session that healed.
        if (state.isPlaying) _error = null;
      });
      _saveProgress();
      if (state.isPlaying) {
        _scheduleHide();
        if (_routeCovered) unawaited(_pauseForRoute(handle));
      }
      final detail = _detail;
      final episode = _episode;
      if (state.initialized &&
          detail != null &&
          episode != null &&
          episode.vid.isNotEmpty &&
          RegExp(r'^[0-9]{6,30}$').hasMatch(episode.vid)) {
        ref
            .read(hongguoDanmakuProvider.notifier)
            .start(
              widget.seriesId,
              episode.vid,
              state.duration.inMilliseconds,
              () => _transport?.position.inMilliseconds ?? 0,
            );
      }
    });
    _eventSub = handle.adapterEvents.listen((event) {
      if (!mounted) return;
      switch (event) {
        case final PlayerAdapterErrorEvent error:
          setState(() => _opening = false);
          _onPlaybackFailure(error.message);
        case PlayerAdapterCompleted():
          unawaited(_handleFinished());
        default:
          break;
      }
    });
  }

  /// A finished episode leads to the next one; the last one stands on its
  /// final frame with its progress marked complete.
  Future<void> _handleFinished() async {
    if (_finished) return;
    _finished = true;
    _saveProgress(force: true, completed: true);
    // An episode's end is the sleep timer's turn to count: one that asks to
    // stop here leaves the next episode unopened.
    if (_sleep.episodeEnded()) {
      await _stopForSleep();
      return;
    }
    final episodes = _detail?.episodes ?? const <HongguoEpisode>[];
    final current = _episode;
    if (current == null) return;
    final index = episodes.indexWhere((episode) => episode.vid == current.vid);
    if (index >= 0 && index + 1 < episodes.length) {
      await _openEpisode(episodes[index + 1]);
    }
  }

  Future<void> _togglePlay() async {
    final handle = _handle;
    if (handle == null || !_playerReady) return;
    final playing = _transport?.isPlaying ?? false;
    if (!playing && _sleepStopped) {
      // Pressing play after a sleep stop resumes the session.
      _sleepStopped = false;
      if (mounted) setState(() {});
    }
    try {
      playing ? await handle.pause() : await handle.play();
    } on Object catch (error) {
      appLog.forCategory('hongguo.play').warning('playback step failed', fields: {'error': '$error'});
      if (mounted) setState(() => _error = '$error');
    }
  }

  /// The watching lock's flip: taking it closes any catalogue first and
  /// stops the hide clock, leaving it wakes the chrome again.
  void _toggleLock() {
    if (!_locked && _openPanel != null) setState(() => _openPanel = null);
    setState(() => _locked = !_locked);
    if (_locked) {
      _hideTimer?.cancel();
      return;
    }
    _wake();
  }

  Future<void> _seekTo(double seconds) async {
    final handle = _handle;
    if (handle == null || !_playerReady) return;
    try {
      await handle.seek(Duration(milliseconds: (seconds * 1000).round()));
    } on Object catch (error) {
      appLog.forCategory('hongguo.play').warning('playback step failed', fields: {'error': '$error'});
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _setMuted({required bool muted}) async {
    final handle = _handle;
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

  Future<void> _setVolume(double volume) async {
    final handle = _handle;
    if (handle == null) return;
    setState(() => _volume = volume);
    // The module remembers it: the next episode opens here.
    unawaited(ref.read(modulePlaybackSettingsProvider(PlayerModule.hongguo).notifier).setVolume(volume));
    try {
      await handle.setVolume(volume);
    } on Object catch (_) {
      // Same as mute.
    }
  }

  /// Shows [value] on the picture's own volume chip and lets it settle away a
  /// moment after the last step — the same chip and timing the room and the
  /// preview use, so one gesture is learned once.
  void _showVolumeHud(double value) {
    _volumeHudTimer?.cancel();
    setState(() => _volumeHud = value.clamp(0.0, 1.0));
    _volumeHudTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _volumeHud = null);
    });
  }

  /// A wheel step takes the viewer's own share of the range (the 画质与音频
  /// setting). The drag on this picture belongs to the episodes, so the wheel is
  /// the gesture offered here.
  void _wheelVolume(double delta) {
    if (_handle == null) return;
    final step = ref.read(playbackSettingsProvider).volumeWheelStepPercent / 100;
    final next = (_volume + (delta > 0 ? -step : step)).clamp(0.0, 1.0);
    _showVolumeHud(next);
    unawaited(_setVolume(next));
  }

  /// 音频模式: keep the episode's sound, put the picture away.
  Future<void> _toggleAudioOnly() async {
    setState(() => _audioOnly = !_audioOnly);
    final handle = _handle;
    if (handle == null) return;
    await _applyAudioOnly(handle);
  }

  /// Writes the mode to [handle]; a kernel that has none keeps the picture
  /// rather than failing the episode switch it was applied on.
  Future<void> _applyAudioOnly(PlayerHandle handle) async {
    try {
      await handle.setAudioOnly(audioOnly: _audioOnly);
    } on Object {
      // The switch says what was asked; the next episode gets the same try.
    }
  }

  /// Keeps the frame the episode is showing in the viewer's screenshot folder,
  /// and says how it went.
  Future<void> _screenshot() async {
    final handle = _handle;
    if (handle == null) return;
    final file = await capturePlayerFrame(handle, ref.read(appPathsProvider).screenshots, prefix: 'pure_live_hongguo');
    if (!mounted) return;
    final t = context.t;
    showDsToast(
      context: context,
      title: file == null ? t.player.screenshotFailed : t.player.screenshotSaved(name: file.uri.pathSegments.last),
      status: file == null ? DsStatus.danger : DsStatus.success,
    );
  }

  /// The episode playing now, sent to a TV on the local network — the same
  /// dialog the other video pages open, over the address the player reads.
  Future<void> _cast() async {
    final url = _castUrl;
    if (url == null) return;
    await showCastUriDialog(context, url: url, title: _detail?.meta.title);
  }

  /// The compact window the desktop offers (the phone's system picture-in-
  /// picture on iOS). This page had no way into it at all.
  Future<void> _togglePip() async {
    final handle = _handle;
    if (handle == null) return;
    final accepted = await _presentationNotifier.togglePip(handle.id);
    if (accepted || !mounted) return;
    showDsToast(context: context, title: context.t.common.pipUnavailable);
  }

  /// Whether the 小窗 verb may show: the handle carries a source to hand
  /// over, no window-owning mode stands (the picture-in-picture small window
  /// already is a small window), and no mini window is up yet.
  bool get _miniWindowReady {
    // The 小窗 overlay belongs to the primary window: its root navigator
    // is the only one registered as the app's, so a secondary's handoff
    // would land its picture on the primary's overlay. Secondary windows
    // keep their own picture instead.
    if (!ref.read(isPrimaryWindowProvider)) return false;
    final handle = _handle;
    return handle != null &&
        handle.source != null &&
        _presentationMode == PresentationMode.normal &&
        !FloatingVideoWindow.isShowing;
  }

  /// Hands the episode to the floating mini window and leaves: the window
  /// opens its own handle from this one's source, resuming where it stopped,
  /// while the page pops back; the expand button re-opens this route at the
  /// position the window closed at.
  Future<void> _enterMiniWindow() async {
    final handle = _handle;
    final source = handle?.source;
    final episode = _episode;
    if (handle == null || source == null || episode == null) return;
    _wake();
    final backend = ref.read(playerKernelBackendProvider).id;
    final title = _detail?.meta.title ?? episode.title;
    final ok = await FloatingVideoWindow.show(
      FloatingVideoHandoff(
        title: title,
        resume: handle.position,
        rate: handle.rate,
        muted: handle.muted,
        open: (kernel) => kernel.create(
          source: source,
          config: PlayerConfig(name: 'floating-video', playbackRate: handle.rate, muted: handle.muted),
          preferredBackend: backend,
        ),
        onClose: (position, {required reopen}) {
          // The page is gone by then, but its progress fields survive as
          // plain data: the write lands in the same local history row (and,
          // signed in, the same cloud copy) a return resumes from.
          _saveProgress(force: true, positionOverride: position);
          if (reopen) {
            final root = rootNavigatorKey.currentContext;
            if (root != null && root.mounted) {
              final resume = (position.inMilliseconds / 1000).toStringAsFixed(1);
              final vid = Uri.encodeComponent(episode.vid);
              final route = '/hongguo/${Uri.encodeComponent(widget.seriesId)}?vid=$vid&resume=$resume';
              unawaited(root.push(route));
            }
          }
        },
      ),
    );
    if (!ok || !mounted || _disposed) return;
    // The window now carries the sound: this page goes quiet before it pops.
    silencePlayer(handle);
    if (mounted && context.mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  Future<void> _setSpeed(double speed) async {
    final handle = _handle;
    if (handle == null) return;
    // Picking another speed by hand lets a locked fast-forward go.
    if (_speedLocked && speed != _holdSpeed) _speedLocked = false;
    setState(() => _speed = speed);
    try {
      await handle.setRate(speed);
    } on Object catch (_) {
      // Same as mute.
    }
  }

  /// A press held on the picture runs at [_holdSpeed]; releasing restores the
  /// speed the viewer had, unless the hold slid up far enough to lock it.
  void _beginHold() {
    final handle = _handle;
    if (handle == null || !_playerReady || _error != null) return;
    _hideTimer?.cancel();
    _speedBeforeHold = _speed;
    setState(() => _holding = true);
    if (!_speedLocked) unawaited(handle.setRate(_holdSpeed).catchError((Object _) {}));
  }

  /// While the press is held, sliding up locks the fast speed past the
  /// release; a locked hold slid back down unlocks it.
  void _holdMoved(double dy) {
    if (!_holding) return;
    if (!_speedLocked && dy <= -40) {
      setState(() {
        _speedLocked = true;
        _lockedFromSpeed = _speedBeforeHold == _holdSpeed ? 1 : _speedBeforeHold;
        _speed = _holdSpeed;
      });
      showDsToast(context: context, title: context.t.hongguo.speedLockedToast);
    } else if (_speedLocked && dy >= 40) {
      setState(() {
        _speedLocked = false;
        // Releasing after this unlock must not put the hold speed back.
        _speedBeforeHold = _lockedFromSpeed;
      });
      unawaited(_setSpeed(_lockedFromSpeed));
      showDsToast(context: context, title: context.t.hongguo.speedUnlockedToast);
    }
  }

  void _endHold() {
    if (!_holding) return;
    setState(() => _holding = false);
    _scheduleHide();
    if (_speedLocked) return;
    unawaited(_setSpeed(_speedBeforeHold));
  }

  /// A vertical swipe on the picture walks the episodes: up for the next,
  /// down for the previous.
  void _endSwipe(double velocity) {
    final travelled = _swipeDy;
    _swipeDy = 0;
    if (travelled.abs() < 48 && velocity.abs() < 320) return;
    final next = travelled != 0 ? travelled < 0 : velocity < 0;
    _switchEpisode(next: next);
  }

  void _switchEpisode({required bool next}) {
    final episodes = _detail?.episodes ?? const <HongguoEpisode>[];
    final current = _episode;
    if (current == null || episodes.isEmpty) return;
    final index = episodes.indexWhere((episode) => episode.vid == current.vid);
    if (index < 0) return;
    final target = next
        ? (index + 1 < episodes.length ? episodes[index + 1] : null)
        : (index > 0 ? episodes[index - 1] : null);
    if (target == null) {
      final t = context.t;
      showDsToast(context: context, title: next ? t.hongguo.lastEpisode : t.hongguo.firstEpisode);
      return;
    }
    _wake();
    unawaited(_openEpisode(target));
  }

  /// The engine options this page keeps for every episode and handle:
  /// hardware decoding and the stored outputs. The player proxy is left out —
  /// the stream is always the companion service on this machine, and a proxy
  /// client asked for a loopback address usually refuses the connection.
  List<EngineOption> _storedEngineOptions() => playerStoredEngineOptions(
    hardwareDecoding: ref.read(playbackSettingsProvider).hardwareDecoding,
    tuning: ref.read(playerTuningProvider),
    proxy: null,
  );

  Future<void> _applyEngineOptions(PlayerHandle handle, {List<EngineOption> extra = const []}) async {
    try {
      await handle.applyEngineOptions(<EngineOption>[..._storedEngineOptions(), ...extra]);
    } on Object {
      // A refused engine option is not a playback failure.
    }
  }

  /// The desktop's window-fullscreen: the app window goes full-bleed, the
  /// system chrome out of the way, the page the viewer's whole view.
  Future<void> _toggleWindowFullscreen() async {
    final handle = _handle;
    if (handle == null) return;
    await _presentationNotifier.toggleWindowFullscreen(handle.id);
  }

  Future<void> _toggleFullscreen() async {
    final handle = _handle;
    if (handle == null) return;
    await _presentationNotifier.toggleFullscreen(handle.id);
  }

  void _leave() {
    final handle = _handle;
    // A phone's picture-in-picture window floats over the page; leaving the
    // page is the way out of it (the system owns its own close).
    if (handle != null && _presentationNotifier.modeOwnsWindow(_presentationMode)) {
      unawaited(_presentationNotifier.exit(handle.id));
      return;
    }
    context.pop();
  }

  /// The stored checkpoint, when one exists and is worth resuming. A
  /// finished series keeps its history row but is not resumed.
  ({int index, double seconds})? _readProgress() {
    final row = ref.read(hongguoLibraryProvider).progressOf(widget.seriesId);
    if (row == null || row.completed || row.positionMs <= 0) return null;
    return (index: row.episodeIndex, seconds: row.positionMs / 1000);
  }

  /// Saves the episode and position at most once every few seconds — the
  /// local history row a return resumes from, and, signed in, the cloud's
  /// own copy (best effort; a refused upload never fails the page).
  void _saveProgress({bool force = false, bool completed = false, Duration? positionOverride}) {
    final episode = _episode;
    final transport = _transport;
    if (episode == null || transport == null) return;
    final total = transport.duration.inMilliseconds;
    // The floating mini window hands the page its last position on the way
    // out: the page's own transport stopped at the handoff, so the override
    // is the only record of what the window played since.
    final position = positionOverride?.inMilliseconds ?? transport.position.inMilliseconds;
    if (total <= 0 || position <= 0) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastSave) < const Duration(seconds: 5)) return;
    _lastSave = now;
    final done = completed || position >= total - 5000;
    final detail = _detail;
    _library.saveProgress(
      HongguoWatchProgress(
        seriesId: widget.seriesId,
        title: detail?.meta.title ?? episode.title,
        cover: detail?.meta.cover ?? '',
        episodeIndex: episode.index,
        episodeVid: episode.vid,
        positionMs: done ? total : position,
        durationMs: total,
        completed: done,
        updatedAt: now.millisecondsSinceEpoch,
        episodeCount: detail?.meta.episodeCount ?? detail?.episodes.length ?? 0,
      ),
    );
    final credentials = _accountCredentials;
    if (credentials == null || credentials.cookie.isEmpty) return;
    // The platform's copy lags the local one on purpose: a position upload
    // every five seconds would be a request every five seconds.
    if (!force && now.difference(_lastCloudSave) < const Duration(seconds: 30)) return;
    _lastCloudSave = now;
    unawaited(
      _accountClient
          .upload(
            credentials,
            seriesId: widget.seriesId,
            episodeVid: episode.vid,
            episodeIndex0: episode.index - 1,
            positionMs: position,
            durationMs: total,
            episodeCount: detail?.meta.episodeCount ?? detail?.episodes.length ?? 0,
          )
          .catchError((Object _) {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    _accountCredentials = ref.read(hongguoAccountProvider).credentials;
    ref.listen(playbackSettingsProvider.select((settings) => settings.globalMute), (previous, next) {
      if (previous == next) return;
      if (mounted) setState(() => _globalMute = next);
      final handle = _handle;
      if (handle != null) {
        unawaited(
          handle.setMute(muted: _muted || next).catchError((Object _) {
            // A refused mute is not a playback failure.
          }),
        );
      }
    });
    ref.listen(playerProxyProvider, (previous, next) {
      if (previous == next) return;
      final handle = _handle;
      if (handle != null) unawaited(_applyEngineOptions(handle));
    });
    ref.listen(playbackSettingsProvider.select((settings) => settings.hardwareDecoding), (previous, next) {
      if (previous == next) return;
      final handle = _handle;
      if (handle != null) unawaited(_applyEngineOptions(handle));
    });
    ref.listen(playerTuningProvider, (previous, next) {
      if (previous == next) return;
      unawaited(_applyTuning(previous, next));
    });
    // Leaving fullscreen — by any hand, including the system's — puts the
    // keyboard back on the play control.
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
    // A phone entering system fullscreen asks the viewer's portrait policy
    // which way it turns; the driver's exit path puts the lock back.
    ref.listen(roomPresentationProvider, (previous, next) {
      if (next != PresentationMode.fullscreen || previous == PresentationMode.fullscreen) return;
      applyFullscreenOrientation(_screenOrientation, aspectRatio: _aspectRatio);
    });
    // A download the queue finished or failed says so here too — a toast
    // names the file, however the page was left.
    ref.listen(hongguoDownloadsProvider, (previous, next) {
      final episode = _episode;
      if (episode == null) return;
      final before = {for (final item in previous ?? const <HongguoDownloadItem>[]) item.id: item.phase};
      for (final item in next) {
        if (item.id != episode.vid || before[item.id] == item.phase) continue;
        if (!mounted) return;
        final t = context.t;
        if (item.phase == HongguoDownloadPhase.done) {
          showDsToast(
            context: context,
            title: t.hongguo.downloadDone(name: item.fileName),
            status: DsStatus.success,
          );
        } else if (item.phase == HongguoDownloadPhase.failed) {
          // The reason belongs on the toast; the row keeps it too.
          showDsToast(
            context: context,
            title: t.settings.downloadStatusFailed,
            description: item.error,
            status: DsStatus.danger,
          );
        }
      }
    });
    final presentation = ref.watch(roomPresentationProvider);
    final t = context.t;
    final detail = _detail;
    final colors = DsTheme.colorsOf(context);
    final presentationController = ref.read(roomPresentationProvider.notifier);
    final immersive = presentationController.modeOwnsWindow(presentation);
    // 矮窗（高 <480）横屏沉浸：满铺画面加覆盖控件，页头退场——判定是
    // 窗口的形状，与平台无关（与直播间同一台排版机）。
    final windowSize = MediaQuery.sizeOf(context);
    final landscapeImmersive = PlaybackLayout.resolve(
      width: windowSize.width,
      height: windowSize.height,
    ).landscapeImmersive;
    // The arrows mirror the room page: up and down take the wheel's step (the
    // 画质与音频 setting) toward the volume, left and right skip five seconds.
    // A TV keeps its arrows for focus; the remote drives the volume itself.
    final tv = ref.watch(platformRuntimeProvider).environment.runtime.formFactor == FormFactor.tv;
    if (immersive) {
      // The owned window keeps the keyboard its page had: Escape backs out of
      // the mode it sits in, I raises the stream's figures. The chrome's own
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
    void nudgeVolume(double delta) => unawaited(_setVolume((_volume + delta).clamp(0.0, 1.0)));
    void nudgeSeek(double delta) {
      final position = _transport?.position;
      if (position == null) return;
      final target = position.inMilliseconds / 1000 + delta;
      unawaited(_seekTo(target < 0 ? 0 : target));
    }

    // A held arrow keeps stepping, and each step in a row is bigger: five
    // seconds, then ten, then twenty, so reaching the middle of an episode
    // is one key rather than a hundred taps.
    void nudgeKeySeek(int direction) {
      _wake();
      _keySeekSteps++;
      _keySeekTimer?.cancel();
      _keySeekTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted) _keySeekSteps = 0;
      });
      nudgeSeek((direction * 5 * _keySeekSteps).toDouble());
    }

    // One step along the speed panel's own ladder, the keyboard's way
    // through it.
    void stepSpeed(int direction) {
      const choices = _speedChoices;
      var nearest = 0;
      for (var i = 1; i < choices.length; i++) {
        if ((choices[i] - _speed).abs() < (choices[nearest] - _speed).abs()) nearest = i;
      }
      final next = (nearest + (direction > 0 ? 1 : -1)).clamp(0, choices.length - 1);
      if (choices[next] == _speed) return;
      _wake();
      unawaited(_setSpeed(choices[next]));
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
          if (!tv) const SingleActivator(LogicalKeyboardKey.arrowLeft): () => nudgeKeySeek(-1),
          if (!tv) const SingleActivator(LogicalKeyboardKey.arrowRight): () => nudgeKeySeek(1),
          // The speed ladder and the sound: comma and period walk the panel's
          // own choices, M flips the mute.
          if (!tv) const SingleActivator(LogicalKeyboardKey.comma): () => stepSpeed(-1),
          if (!tv) const SingleActivator(LogicalKeyboardKey.period): () => stepSpeed(1),
          if (!tv)
            const SingleActivator(LogicalKeyboardKey.keyM): () {
              _wake();
              unawaited(_setMuted(muted: !_effectivelyMuted));
            },
        },
        child: Scaffold(
          backgroundColor: colors.canvas,
          body: landscapeImmersive
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    _playerSurface(context, immersive: false, fills: true),
                    PositionedDirectional(
                      top: 0,
                      start: 0,
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s12, DsSpace.s8, DsSpace.s12, 0),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: PlayerGlassPill(
                              child: PlayerBarButton(icon: DsIcons.arrowLeft, label: t.common.back, onPressed: _leave),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PageHeader(
                      title: _episode == null
                          ? detail?.meta.title ?? t.hongguo.opening
                          : '${detail?.meta.title ?? ''} · ${t.hongguo.episodeLabel(index: _episode!.index)}',
                    ),
                    Expanded(
                      child: _loading && detail == null
                          ? const Center(child: DsSpinner(style: DsSpinnerStyle(size: 28)))
                          : _error != null && detail == null
                          ? Center(
                              child: DsEmptyState(
                                icon: const DsIcon(DsIcons.cloudOff),
                                title: Text(t.hongguo.loadFailed),
                                description: Text(_error!),
                                actions: [DsButton(onPressed: () => unawaited(_load()), child: Text(t.common.retry))],
                              ),
                            )
                          : _body(context, detail),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _applyTuning(PlayerTuning? previous, PlayerTuning next) async {
    final handle = _handle;
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

  /// The stage the episode plays in, with the episode list docked beside it
  /// from the regular window up — the reference's portrait stage and its
  /// side shelf, the rail's door letting a squeezed window take the width
  /// back. A compact window (a phone, or a window under it) stacks: the
  /// stage on top, then what is playing, the comments, and the episodes
  /// folded to the one on air.
  Widget _body(BuildContext context, HongguoSeriesDetail? detail) {
    final t = context.t;
    // The page's own margin, asked from the app's one rule rather than kept
    // here: on a phone a private 20 puts this page's left edge beside every
    // other page's 16.
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final head = detail == null ? const _HeadSkeleton() : _watchHead(context, detail, t);
    // The compact window's episodes fold to the one on air and open on
    // demand; the rail beside the regular-and-wider window lists the whole
    // series — a row an episode, opened on the one playing.
    final episodes = detail == null
        ? null
        : HongguoEpisodeFoldaway(
            detail: detail,
            current: _episode,
            onOpen: (episode) => unawaited(_openEpisode(episode)),
          );
    final list = detail == null
        ? null
        : HongguoEpisodeList(detail: detail, current: _episode, onOpen: (episode) => unawaited(_openEpisode(episode)));
    final comments = HongguoCommentPanel(seriesId: widget.seriesId, episodeVid: _episode?.vid ?? '');
    if (MediaQuery.sizeOf(context).width < kPlaybackCompactBreakpoint) {
      // A compact window's portrait stage is the phone's player: the action
      // rail rides the picture's own edge, drawn for the on-video ink.
      final player = Center(child: _stage(context));
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s20,
          children: [player, head, comments, ?episodes],
        ),
      );
    }
    // The wide window keeps the watch head and the comments with the stage —
    // the title and the verbs belong to what is playing — and hangs the
    // action rail beside the picture instead of over it, the station's own
    // web player: the picture keeps its shape, the verbs sit at its side on
    // the page's own ink.
    final player = Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: DsSpace.s16,
        children: [
          Flexible(child: _stage(context, overlayActions: false)),
          if (detail != null) _actionRail(t, detail),
        ],
      ),
    );
    final railMax = (MediaQuery.sizeOf(context).width - _railStageFloor).clamp(_railMin, _railMax);
    final railWidth = _railWidth.clamp(_railMin, railMax);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: EdgeInsetsDirectional.fromSTEB(inset, DsSpace.s16, DsSpace.s16, DsSpace.s24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: DsSpace.s20,
                  children: [player, head, comments],
                ),
              ),
              if (!_railOpen) VodRailDoor(label: t.hongguo.episodes, onOpen: () => setState(() => _railOpen = true)),
            ],
          ),
        ),
        if (_railOpen) ...[
          ChatSplitter(
            width: railWidth,
            minWidth: _railMin,
            maxWidth: railMax,
            onResize: (value) => setState(() => _railWidth = value),
            onResizeEnd: (value) => setState(() => _railWidth = value),
            onReset: () => setState(() => _railWidth = _railDefaultWidth),
            label: t.hongguo.episodes,
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
                // The list scrolls itself and opens on the episode on air;
                // only the skeleton, with no rows, rides a scroll view.
                Expanded(
                  child:
                      list ??
                      const SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(DsSpace.s12, 0, DsSpace.s20, DsSpace.s24),
                        child: _ShelfSkeleton(),
                      ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// The stage box a non-immersive picture plays in: an episode shot upright
  /// keeps its own shape but never draws narrower than 9:16, a landscape
  /// episode keeps its width-first shape — the picture is never forced into a
  /// shape it has not got — and the box tops out at 640 so the shelf's column
  /// beside it stays the taller one.
  Widget _stage(BuildContext context, {bool overlayActions = true}) {
    final aspect = _aspectRatio > 0 ? _aspectRatio : 9 / 16;
    final shaped = aspect < 1 ? math.max(aspect, 9 / 16) : aspect;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 640),
      child: _playerSurface(context, immersive: false, aspectRatio: shaped, overlayActions: overlayActions),
    );
  }

  /// The wide window's episode rail: open or folded to its door, and the
  /// width the seam's drag left it at — the season page's rail, pointed at
  /// the shelf.
  bool _railOpen = true;
  double _railWidth = _railDefaultWidth;
  static const double _railMin = 280;
  static const double _railMax = 520;
  static const double _railDefaultWidth = 340;

  /// The least width the stage keeps beside the rail.
  static const double _railStageFloor = 420;

  /// What is playing, under the stage on the stacked layout: the series'
  /// name, the episode and the figures it carries, and the verbs inline — the
  /// local favorite, the next episode, the download and the share — plus the
  /// first lines of the blurb. The video station's watch head; the stage's own
  /// corner cluster and action column repeat the same verbs over the picture.
  Widget _watchHead(BuildContext context, HongguoSeriesDetail detail, Translations t) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final meta = detail.meta;
    final episode = _episode;
    final total = detail.episodes.length;
    final duration =
        _transport?.duration ??
        (episode != null && episode.durationSeconds > 0 ? Duration(seconds: episode.durationSeconds) : null);
    final comments = episode?.commentCount ?? 0;
    final likes = episode?.diggedCount ?? 0;
    final figures = [
      if (episode != null) t.hongguo.episodeLabel(index: episode.index),
      if (total > 0) t.hongguo.allEpisodesCount(count: total),
      if (duration != null && duration > Duration.zero) hongguoDurationText(duration),
      if (meta.playCount > 0) '${AudienceFormat.format(meta.playCount)} ${t.hongguo.plays}',
      if (meta.followedCount > 0) '${AudienceFormat.format(meta.followedCount)} ${t.hongguo.followers}',
      if (comments > 0) '${AudienceFormat.format(comments)} ${t.hongguo.comments}',
      if (likes > 0) '${AudienceFormat.format(likes)} ${t.hongguo.likes}',
    ];
    // The series' own status leads the badges: the station's wording where
    // it gives one, the plain fact of an ended series otherwise.
    final status = meta.statusText.isNotEmpty
        ? meta.statusText
        : meta.finished
        ? t.hongguo.finished
        : '';
    final badges = [
      if (status.isNotEmpty) status,
      ...meta.categories,
      if (meta.rating > 0) t.hongguo.rating(score: meta.rating),
      if (meta.hot.isNotEmpty) t.hongguo.hot(value: meta.hot),
      if (meta.rankLabel.isNotEmpty) meta.rankLabel,
    ];
    final next = _nextEpisode();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Text(meta.title, style: theme.typography.title.copyWith(color: colors.text)),
        // What the station says of the series itself: whether it has ended,
        // its genres, its score, its heat and its place on the board — the
        // facts a viewer picks a drama by, which the page never drew.
        if (badges.isNotEmpty)
          Wrap(
            spacing: DsSpace.s6,
            runSpacing: DsSpace.s4,
            children: [
              for (final badge in badges)
                DsBadge(label: Text(badge), status: badge == status ? DsStatus.success : DsStatus.neutral, dot: false),
            ],
          ),
        if (figures.isNotEmpty)
          Text(figures.join(' · '), style: theme.typography.caption.copyWith(color: colors.textMuted)),
        Wrap(
          spacing: DsSpace.s8,
          runSpacing: DsSpace.s8,
          children: [
            Consumer(
              builder: (context, ref, _) {
                final favored = ref.watch(
                  hongguoLibraryProvider.select((library) => library.isFavorite(meta.seriesId)),
                );
                return DsButton(
                  variant: favored ? DsButtonVariant.primary : DsButtonVariant.secondary,
                  size: DsSize.sm,
                  leading: DsIcon(favored ? DsIcons.heart : DsIcons.heartOff, size: 16),
                  onPressed: () {
                    final added = ref
                        .read(hongguoLibraryProvider.notifier)
                        .toggleFavorite(
                          HongguoSeries(
                            seriesId: meta.seriesId,
                            title: meta.title,
                            cover: meta.cover,
                            intro: meta.intro,
                            episodeCount: meta.episodeCount > 0 ? meta.episodeCount : detail.episodes.length,
                          ),
                        );
                    showDsToast(
                      context: context,
                      title: added ? t.hongguo.favoriteToggleOn : t.hongguo.favoriteToggleOff,
                    );
                  },
                  child: Text(favored ? t.hongguo.favorited : t.hongguo.favorite),
                );
              },
            ),
            if (next != null)
              DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                leading: const DsIcon(DsIcons.skipForward, size: 16),
                onPressed: () => unawaited(_openEpisode(next)),
                child: Text(t.hongguo.nextEpisode),
              ),
            if (episode != null) _downloadButton(context, episode),
            DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              leading: const DsIcon(DsIcons.share, size: 16),
              onPressed: () => unawaited(_shareSeries()),
              child: Text(t.hongguo.share),
            ),
          ],
        ),
        if (meta.intro.isNotEmpty) VodFoldedText(text: meta.intro, maxLines: 2),
      ],
    );
  }

  /// The episode after the one held, in episode order.
  HongguoEpisode? _nextEpisode() {
    final episodes = _detail?.episodes ?? const <HongguoEpisode>[];
    final current = _episode;
    if (current == null) return null;
    final index = episodes.indexWhere((episode) => episode.vid == current.vid);
    if (index < 0 || index + 1 >= episodes.length) return null;
    return episodes[index + 1];
  }

  /// The episode before the one held, in episode order.
  HongguoEpisode? _previousEpisode() {
    final episodes = _detail?.episodes ?? const <HongguoEpisode>[];
    final current = _episode;
    if (current == null) return null;
    final index = episodes.indexWhere((episode) => episode.vid == current.vid);
    if (index <= 0) return null;
    return episodes[index - 1];
  }

  /// The current episode's download, projected to the fields both download
  /// controls read. Other tasks' progress ticks keep the same record and do
  /// not rebuild the player.
  ({HongguoDownloadPhase phase, int total, int received, String id})? _episodeDownload(HongguoEpisode? episode) {
    final vid = episode?.vid;
    return ref.watch(
      hongguoDownloadsProvider.select((items) {
        final item = vid == null ? null : hongguoDownloadOf(items, vid);
        if (item == null) return null;
        return (phase: item.phase, total: item.total, received: item.received, id: item.id);
      }),
    );
  }

  /// The watch head's download button: idle it asks the queue, moving it
  /// reports the percent, paused it resumes, done it stands down.
  Widget _downloadButton(BuildContext context, HongguoEpisode episode) {
    final t = context.t;
    final task = _episodeDownload(episode);
    final label = switch (task?.phase) {
      HongguoDownloadPhase.queued => t.settings.downloadStatusQueued,
      HongguoDownloadPhase.running => '${task!.total > 0 ? task.received * 100 ~/ task.total : 0}%',
      HongguoDownloadPhase.paused => t.settings.downloadResume,
      HongguoDownloadPhase.done => t.hongguo.downloaded,
      HongguoDownloadPhase.failed || null => t.hongguo.download,
    };
    final busy =
        task != null && (task.phase == HongguoDownloadPhase.running || task.phase == HongguoDownloadPhase.queued);
    final finished = task != null && task.phase == HongguoDownloadPhase.done;
    return DsButton(
      variant: DsButtonVariant.secondary,
      size: DsSize.sm,
      leading: busy ? const DsSpinner(style: DsSpinnerStyle(size: 12)) : const DsIcon(DsIcons.download, size: 16),
      onPressed: busy || finished || _detail == null ? null : () => unawaited(_startDownload()),
      child: Text(label),
    );
  }

  /// Hands the current episode to the app-wide download queue. The queue
  /// resolves its own ladder and decrypting proxy when the task's turn
  /// comes, and the 下载管理 page (the station's sidebar, or Settings →
  /// 红果短剧) takes over from there.
  Future<void> _startDownload() async {
    final t = context.t;
    final episode = _episode;
    final detail = _detail;
    if (episode == null || detail == null) return;
    final episodes = detail.episodes;
    final position = episodes.indexWhere((entry) => entry.vid == episode.vid);
    final result = await ref
        .read(hongguoDownloadsProvider.notifier)
        .download(
          vid: episode.vid,
          seriesId: widget.seriesId,
          title: detail.meta.title,
          part: episode.title.isEmpty ? t.hongguo.episodeLabel(index: episode.index) : episode.title,
          index: episode.index > 0 ? episode.index : position + 1,
          parts: episodes.isEmpty ? 1 : episodes.length,
          maxHeight: ref.read(hongguoDownloadQualityProvider).maxHeight,
          cover: detail.meta.cover,
        );
    if (!mounted) return;
    switch (result.outcome) {
      case HongguoDownloadEnqueue.queued:
        showDsToast(context: context, title: t.settings.downloadQueuedNotice, status: DsStatus.success);
      case HongguoDownloadEnqueue.duplicate:
        showDsToast(context: context, title: t.hongguo.downloadDuplicate);
      case HongguoDownloadEnqueue.failed:
        showDsToast(
          context: context,
          title: t.settings.downloadStatusFailed,
          description: result.error,
          status: DsStatus.danger,
        );
    }
  }

  /// The episode catalogue's name: the phone's own "选集 · 全50集".
  String _episodesLabel(Translations t) {
    final detail = _detail;
    final declared = detail?.meta.episodeCount ?? 0;
    final count = declared > 0 ? declared : (detail?.episodes.length ?? 0);
    return count > 0 ? '${t.hongguo.episodes} · ${t.hongguo.allEpisodesCount(count: count)}' : t.hongguo.episodes;
  }

  /// The series' bookmark on the local shelf — the rail's button and the
  /// immersive menu's row both run this one, so the figure, the series built
  /// from the detail and the toast can never disagree between the two.
  void _toggleSeriesFavorite(HongguoSeriesDetail detail) {
    final t = context.t;
    final meta = detail.meta;
    final added = ref
        .read(hongguoLibraryProvider.notifier)
        .toggleFavorite(
          HongguoSeries(
            seriesId: meta.seriesId,
            title: meta.title,
            cover: meta.cover,
            intro: meta.intro,
            episodeCount: meta.episodeCount > 0 ? meta.episodeCount : detail.episodes.length,
          ),
        );
    showDsToast(context: context, title: added ? t.hongguo.favoriteToggleOn : t.hongguo.favoriteToggleOff);
  }

  /// The stage's action column, as the phone player puts it along the
  /// picture's edge: the next episode on top in the accent colour, then the
  /// episode's likes as the platform counts them — read-only, the local
  /// session cannot post one — the local shelf's bookmark with the series' own
  /// follower figure, the episode's comments, and the way to hand the series
  /// out. Over the picture it draws in the on-video ink; beside it, on the
  /// page's own surface, in the theme's.
  Widget _actionRail(Translations t, HongguoSeriesDetail detail, {bool onVideo = false}) {
    final meta = detail.meta;
    final episode = _episode;
    final next = _nextEpisode();
    return Consumer(
      builder: (context, ref, _) {
        final favored = ref.watch(hongguoLibraryProvider.select((library) => library.isFavorite(meta.seriesId)));
        return Column(
          mainAxisSize: MainAxisSize.min,
          spacing: DsSpace.s12,
          children: [
            if (next != null)
              _RailAction(
                icon: DsIcons.skipForward,
                label: t.hongguo.nextEpisode,
                strong: true,
                onVideo: onVideo,
                onPressed: () => unawaited(_openEpisode(next)),
              ),
            if (episode != null)
              _RailAction(
                icon: DsIcons.thumbsUp,
                label: t.hongguo.likes,
                count: episode.diggedCount > 0 ? AudienceFormat.format(episode.diggedCount) : null,
                onVideo: onVideo,
                onPressed: () => showDsToast(context: context, title: t.hongguo.likesReadonly),
              ),
            _RailAction(
              icon: favored ? DsIcons.heart : DsIcons.heartOff,
              label: favored ? t.hongguo.favorited : t.hongguo.favorite,
              count: meta.followedCount > 0 ? AudienceFormat.format(meta.followedCount) : null,
              selected: favored,
              onVideo: onVideo,
              onPressed: () => _toggleSeriesFavorite(detail),
            ),
            if (episode != null)
              _RailAction(
                icon: DsIcons.messageCircle,
                label: t.hongguo.comments,
                count: episode.commentCount > 0 ? AudienceFormat.format(episode.commentCount) : null,
                onVideo: onVideo,
                onPressed: _openComments,
              ),
            _RailAction(
              icon: DsIcons.share,
              label: t.hongguo.share,
              onVideo: onVideo,
              onPressed: () => unawaited(_shareSeries()),
            ),
          ],
        );
      },
    );
  }

  /// This episode's comments, opened as the phone's own sheet — the rail's
  /// way in, on the stage whose window has no docked comments column and on
  /// the immersive picture alike.
  void _openComments() {
    final episode = _episode;
    if (episode == null) return;
    unawaited(
      showAppPanel<void>(
        context: context,
        builder: (context) => AppPanel(
          title: Text(context.t.hongguo.comments),
          child: HongguoCommentPanel(seriesId: widget.seriesId, episodeVid: episode.vid, showTitle: false),
        ),
      ),
    );
  }

  /// Hands out the series' public page; the phone shares through the system
  /// sheet, and here the link goes to the clipboard with a word of thanks.
  Future<void> _shareSeries() async {
    await Clipboard.setData(ClipboardData(text: '$kHongguoSite/detail?series_id=${widget.seriesId}'));
    if (!mounted) return;
    showDsToast(context: context, title: context.t.hongguo.shareCopied);
  }

  /// The picture and its controls. The bar wakes under the pointer and
  /// settles away while the stream plays — the live room's own overlay — and
  /// [immersive] adds the way out and the title over the picture, since the
  /// page's app bar is gone there. [aspectRatio] is the box the caller asked
  /// for — the page stage's shape, never narrower than 9:16 for an upright
  /// episode — and the engine's own reading is the fallback, which a
  /// fullscreen window's tight constraints hold in place regardless.
  /// [overlayActions] hangs the action rail over the picture's own edge; the
  /// wide page's stage hands that duty to the rail beside the picture.
  Widget _playerSurface(
    BuildContext context, {
    required bool immersive,
    bool fills = false,
    double? aspectRatio,
    bool overlayActions = true,
  }) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final handle = _handle;
    final transport = _transport;
    final detail = _detail;
    final settings = ref.watch(hongguoSettingsProvider);
    // The picture mode is the app's own player setting — one entry for every
    // player — and the bar's panel writes it rather than a module copy.
    final fit = ref.watch(playbackSettingsProvider).fit;
    final lessons = ref.watch(hongguoDecoderLessonsProvider);
    final danmaku = ref.watch(hongguoDanmakuSettingsProvider);
    final danmakuItems = ref.watch(hongguoDanmakuProvider).items;
    final playing = transport?.isPlaying ?? false;
    final ready = _playerReady;
    _syncScreenWake(playing && ref.watch(keepScreenOnProvider));
    // Locked, nothing rides the picture: the unlock pill on the right edge
    // is the whole chrome, the room's own rule.
    final showBar = !_locked && (_controlsVisible || !playing || _error != null);
    // The desktop's small window wears the shared chrome alone: no strip, no
    // rail and no bar of catalogues — the way back, the close, the transport,
    // the danmaku and the sound, the pin — the picture keeping its gestures.
    final smallWindow =
        immersive && ref.watch(roomPresentationProvider) == PresentationMode.pip && _presentationNotifier.pipOwnsWindow;
    final ladder = _lastLadder;
    final attempted = _attempted;
    final lower = ladder != null && attempted != null
        ? hongguoLowerRendition(ladder, attempted, settings.quality.maxHeight, learnedFailures: lessons)
        : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(immersive || fills ? 0 : theme.radii.overlay),
      child: ColoredBox(
        color: colors.overlay,
        child: _FramedPicture(
          fills: fills,
          aspectRatio: aspectRatio ?? (_aspectRatio > 0 ? _aspectRatio : 16 / 9),
          child: MouseRegion(
            onHover: (_) => _wake(),
            onExit: (_) => _scheduleHide(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (handle != null)
                  MediaPlayerView(handle: handle, fit: fit.boxFit, backgroundColor: colors.overlay)
                else
                  const ColoredBox(color: OnVideoColors.ground),
                if (handle != null && danmaku.enabled && danmakuItems.isNotEmpty)
                  Positioned.fill(
                    child: HongguoDanmakuLayer(
                      items: danmakuItems,
                      positionMs: () => _transport?.position.inMilliseconds ?? 0,
                      playing: () => _transport?.isPlaying ?? false,
                      settings: danmaku,
                    ),
                  ),
                // 音频模式 covers the frame rather than replacing the surface:
                // the episode keeps playing, and its name says what is running.
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
                              _episode?.title ?? _detail?.meta.title ?? '',
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
                // The stream's own numbers, on the same session switch the room,
                // the IPTV page and the preview use.
                if (handle case final player? when ref.watch(playerStatsVisibleProvider))
                  Positioned.fill(
                    child: IgnorePointer(child: PlayerStatsOverlay(handle: player)),
                  ),
                if (_volumeHud case final value?)
                  PositionedDirectional(
                    end: DsSpace.s20,
                    top: 0,
                    bottom: 0,
                    child: PlayerVolumeHud(value: value),
                  ),
                // The picture itself is the bar's switch: a press toggles it,
                // a double press plays or pauses, a held press fast-forwards,
                // and a vertical swipe walks the episodes. The wheel is the
                // volume — the drag is already spoken for.
                Listener(
                  onPointerSignal: (signal) {
                    if (!_locked && signal is PointerScrollEvent) _wheelVolume(signal.scrollDelta.dy);
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    // Locked, the picture's own vocabulary stands down with
                    // the bar: the unlock pill is the whole chrome.
                    onTap: _locked ? null : _toggleControls,
                    onDoubleTap: !ready || _locked
                        ? null
                        : () {
                            _wake();
                            unawaited(_togglePlay());
                          },
                    onLongPressStart: !ready || _locked ? null : (_) => _beginHold(),
                    onLongPressMoveUpdate: !ready || _locked
                        ? null
                        : (details) => _holdMoved(details.offsetFromOrigin.dy),
                    onLongPressEnd: !ready || _locked ? null : (_) => _endHold(),
                    onLongPressCancel: !ready || _locked ? null : _endHold,
                    onVerticalDragStart: !ready || _locked ? null : (_) => _swipeDy = 0,
                    onVerticalDragUpdate: !ready || _locked ? null : (details) => _swipeDy += details.delta.dy,
                    onVerticalDragEnd: !ready || _locked ? null : (details) => _endSwipe(details.primaryVelocity ?? 0),
                  ),
                ),
                if (immersive && showBar && !smallWindow)
                  PositionedDirectional(top: 0, start: 0, end: 0, child: _topStrip(t, detail)),
                // The stage's own corner cluster: the frame's capture, this
                // episode's download, and the rest of the picture's switches
                // gathered under one menu. Fullscreen rides the same cluster
                // on its top strip, where the way out already lives.
                if (!immersive && showBar && detail != null)
                  PositionedDirectional(
                    top: DsSpace.s12,
                    end: DsSpace.s12,
                    // The rail on the picture's edge carries the capture
                    // verbs; the wide page's stage, whose rail stands beside
                    // the picture, keeps them here.
                    child: _stageCornerActions(t, detail),
                  ),
                // A held press says what it is doing; the lock itself is
                // confirmed by a toast and the bar's speed reading.
                if (_holding)
                  PositionedDirectional(
                    // The strip is 8 of padding, one control and 20 below it;
                    // the stage's corner cluster is 12 of padding, one control
                    // and 12 more — both read from the tier, so a TV's taller
                    // controls do not cover this.
                    top: immersive && showBar && !smallWindow
                        ? DsSpace.s8 + PlayerBarTier.controlSize(context) + DsSpace.s20
                        : showBar && detail != null && !immersive
                        ? DsSpace.s12 + PlayerBarTier.controlSize(context) + DsSpace.s12
                        : DsSpace.s16,
                    end: DsSpace.s12,
                    child: PlayerGlassPill(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s12, DsSpace.s4, DsSpace.s12, DsSpace.s4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: DsSpace.s6,
                          children: [
                            DsIcon(
                              _speedLocked ? DsIcons.lock : DsIcons.timer,
                              size: theme.sizes.iconXs,
                              color: OnVideoColors.foreground,
                            ),
                            Text(
                              _speedLocked ? t.hongguo.speedLocked : t.hongguo.speedHolding,
                              style: theme.typography.caption.copyWith(color: OnVideoColors.foreground),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Locked, the unlock pill is the whole chrome — the room's
                // own rule: the clusters and the episode's own action column
                // stand down with the bar, and this is the only thing left
                // to press.
                if (_locked)
                  PositionedDirectional(
                    end: DsSpace.s12,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: PlayerGlassPill(
                        child: PlayerBarButton(
                          icon: DsIcons.unlock,
                          label: t.room.unlockControls,
                          onPressed: _toggleLock,
                        ),
                      ),
                    ),
                  ),
                // The picture's own action column, over the picture's edge:
                // the next episode, the episode's likes, the series'
                // bookmark, its comments and the way to hand it out. The wide
                // page's stage hands it to the rail beside the picture; like
                // the bar, the column stands down while a catalogue hangs
                // over the picture or a hold is running.
                if (overlayActions &&
                    showBar &&
                    !smallWindow &&
                    handle != null &&
                    detail != null &&
                    _openPanel == null &&
                    !_holding)
                  PositionedDirectional(
                    // Fullscreen hangs the column under the strip, clear of
                    // the way out's row; the stage centres it on the picture's
                    // own edge.
                    top: immersive ? DsSpace.s8 + PlayerBarTier.controlSize(context) + DsSpace.s20 : 0,
                    bottom: immersive ? null : 0,
                    end: immersive ? DsSpace.s8 : DsSpace.s12,
                    child: immersive
                        ? _actionRail(t, detail, onVideo: true)
                        : Center(child: _actionRail(t, detail, onVideo: true)),
                  ),
                if (_error == null && (!ready || (transport?.isBuffering ?? false)))
                  const Center(child: DsSpinner(style: DsSpinnerStyle(size: 24))),
                // A failure that outlived the automatic recovery: what went
                // wrong, what the budget is doing, and the four ways out the
                // reference offers.
                if (_error != null)
                  Positioned.fill(
                    child: ColoredBox(
                      color: OnVideoColors.paneGlass,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Container(
                            padding: const EdgeInsets.all(DsSpace.s16),
                            decoration: DsBoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(theme.radii.overlay),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              spacing: DsSpace.s8,
                              children: [
                                DsIcon(DsIcons.circleAlert, size: 24, color: colors.text),
                                Text(
                                  _lastFailure ?? _error!,
                                  textAlign: TextAlign.center,
                                  style: theme.typography.body.copyWith(color: colors.text),
                                ),
                                Text(
                                  _waitingForNetwork
                                      ? t.hongguo.waitingForNetwork
                                      : _autoRecovery
                                      ? t.hongguo.autoRetry(
                                          attempt: _recovery.attempts + 1,
                                          seconds: (_recovery.delay?.inMilliseconds ?? 0) ~/ 1000,
                                        )
                                      : t.hongguo.retryExhausted,
                                  textAlign: TextAlign.center,
                                  style: theme.typography.caption.copyWith(color: colors.textMuted),
                                ),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: DsSpace.s8,
                                  runSpacing: DsSpace.s8,
                                  children: [
                                    DsButton(onPressed: () => unawaited(_retryNow()), child: Text(t.hongguo.retryNow)),
                                    if (lower != null)
                                      DsButton(
                                        variant: DsButtonVariant.secondary,
                                        onPressed: () => unawaited(_retryLower(lower.quality)),
                                        child: Text(t.hongguo.retryLower(height: lower.quality)),
                                      ),
                                    if (immersive)
                                      DsButton(
                                        variant: DsButtonVariant.ghost,
                                        // The small window has no fullscreen to
                                        // fall into: back to the page is what
                                        // 「回选集」 means there.
                                        onPressed: () => unawaited(
                                          ref.read(roomPresentationProvider) == PresentationMode.pip
                                              ? _togglePip()
                                              : _toggleFullscreen(),
                                        ),
                                        child: Text(t.hongguo.backToEpisodes),
                                      ),
                                    if (_autoRecovery)
                                      DsButton(
                                        variant: DsButtonVariant.ghost,
                                        onPressed: () {
                                          _cancelRecovery();
                                          setState(() => _autoRecovery = false);
                                        },
                                        child: Text(t.hongguo.stopAutoRetry),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (smallWindow)
                // The band that moves the window: the top 44 px, under the
                // chrome. A double press on it hands the page back.
                ...[
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
                      builder: (context, constraints) =>
                          _smallWindowChrome(context, constraints.maxWidth, detail, episode: _episode),
                    ),
                  ),
                ],
                // The small window's chrome draws its own progress line.
                if (showBar && !smallWindow)
                  PositionedDirectional(
                    bottom: 0,
                    start: 0,
                    end: 0,
                    // Resting on the bar keeps it; leaving settles it away.
                    child: MouseRegion(
                      onEnter: (_) => _hideTimer?.cancel(),
                      onExit: (_) => _scheduleHide(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [_controlBar(context, immersive: immersive)],
                      ),
                    ),
                  )
                // The bar away, the episode keeps one line on its bottom edge.
                else if (!smallWindow && playing && handle != null)
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
                // The catalogue floats over the bar, above whatever status
                // pill it carries.
                if (showBar)
                  if (_openPanel case final panel?)
                    Positioned.fill(
                      child: PlayerPanelHost(
                        anchorKey: _panelAnchors[panel]!,
                        barKey: _barAnchor,
                        width: _panelWidth(panel),
                        child: MouseRegion(
                          onEnter: (_) => _leaveTimer?.cancel(),
                          onExit: (_) => _leavePanelSoon(),
                          child: _panel(t, panel),
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

  /// The desktop's small window: the shared chrome over the episode's
  /// picture. The title beside the way back, the transport leading the bar,
  /// the danmaku's switch after it and the sound — the episode's seek line
  /// running along the bottom edge above them — and the pin at the bar's end.
  /// The picture underneath keeps every gesture it has on the page.
  Widget _smallWindowChrome(
    BuildContext context,
    double width,
    HongguoSeriesDetail? detail, {
    required HongguoEpisode? episode,
  }) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final handle = _handle;
    final transport = _transport;
    final playing = transport?.isPlaying ?? false;
    final ready = _playerReady;
    final danmaku = ref.watch(hongguoDanmakuSettingsProvider);
    final pinTop = ref.watch(playbackSettingsProvider.select((settings) => settings.windowsPipAlwaysOnTop));
    final title = detail == null
        ? ''
        : episode == null
        ? detail.meta.title
        : '${detail.meta.title} · ${t.hongguo.episodeLabel(index: episode.index)}';
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
      onPressed: handle == null || !ready
          ? null
          : () {
              _wake();
              unawaited(_togglePlay());
            },
    );
    return PlayerPipChrome(
      visible: !_locked && (_controlsVisible || !playing || _error != null),
      width: width,
      control: control,
      onRestore: () {
        _wake();
        unawaited(_togglePip());
      },
      onClose: () {
        _wake();
        unawaited(_handle?.pause());
        final close = ref.read(roomLeaveProvider);
        if (close != null) {
          unawaited(close());
          return;
        }
        // The page's own window cannot close itself: the episode stops and
        // the small window hands the page back.
        _leave();
      },
      onWake: _wake,
      identity: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: nameMax),
        child: Text(
          title,
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
            iconAsset: danmaku.enabled ? 'assets/icons/danmaku-on.svg' : 'assets/icons/danmaku-off.svg',
            label: danmaku.enabled ? t.common.danmakuOff : t.common.danmakuOn,
            onPressed: handle == null
                ? null
                : () {
                    _wake();
                    unawaited(ref.read(hongguoDanmakuSettingsProvider.notifier).setEnabled(value: !danmaku.enabled));
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
        // The level where the window is wide enough to trim it.
        if (width >= 480)
          PlayerPipVerb(
            extent: 88,
            child: SizedBox(
              width: 88,
              child: DsSlider(
                value: _effectivelyMuted ? 0.0 : _volume,
                style: const DsSliderStyle(
                  height: 24,
                  trackHeight: 4,
                  trackColor: OnVideoColors.track,
                  fillColor: OnVideoColors.foreground,
                  thumbColor: OnVideoColors.foreground,
                  thumbSize: 12,
                ),
                onChanged: !ready ? null : (value) => unawaited(_setVolume(value)),
                semanticLabel: t.player.volume,
              ),
            ),
          ),
      ],
      // The episode's own line: how far it has run, with the drag seeking.
      progress: ready
          ? PlayerSeekLayer.replay(
              position: _dragSeconds != null
                  ? Duration(milliseconds: (_dragSeconds! * 1000).round())
                  : (transport?.position ?? Duration.zero),
              duration: transport?.duration ?? Duration.zero,
              buffered: transport?.buffer.ranges ?? const [],
              onSeek: (seconds) => unawaited(_seekTo(seconds)),
              onScrub: (seconds) => setState(() => _dragSeconds = seconds),
            )
          : null,
      onTogglePin: () {
        final next = !ref.read(playbackSettingsProvider).windowsPipAlwaysOnTop;
        unawaited(ref.read(playbackSettingsProvider.notifier).setWindowsPipAlwaysOnTop(value: next));
        unawaited(ref.read(desktopWindowHostProvider).setAlwaysOnTop(value: next));
      },
      pinned: pinTop,
    );
  }

  /// The strip over an immersive picture: the way out and what is playing.
  Widget _topStrip(Translations t, HongguoSeriesDetail? detail) {
    final theme = DsTheme.of(context);
    final episode = _episode;
    // The strip answers the mode it sits in. The small window draws none of
    // it — the shared chrome is its own — so what is left is the fullscreen
    // pair, and the leading pill is the shape's own way out: it names the
    // shape it sits in and leaves that one, never falling into the other on
    // the way, the way the bar's pair never does.
    final presentation = ref.watch(roomPresentationProvider);
    final inPip = presentation == PresentationMode.pip;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s8, DsSpace.s8, DsSpace.s12, DsSpace.s20),
      decoration: BoxDecoration(gradient: OnVideoColors.shade(edge: VerticalDirection.up)),
      child: Row(
        spacing: DsSpace.s8,
        children: [
          PlayerGlassPill(
            child: inPip
                ? PlayerBarButton(
                    icon: DsIcons.pictureInPicture2,
                    label: t.player.pipOff,
                    autofocus: true,
                    onPressed: () {
                      _wake();
                      unawaited(_togglePip());
                    },
                  )
                : PlayerBarButton(
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
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: inPip
                  ? (_) {
                      final window = ref.read(windowsPipWindowProvider);
                      if (window != null) unawaited(window.startDragging());
                    }
                  : null,
              onDoubleTap: inPip
                  ? () {
                      _wake();
                      unawaited(_togglePip());
                    }
                  : null,
              child: Text(
                detail == null
                    ? ''
                    : episode == null
                    ? detail.meta.title
                    : '${detail.meta.title} · ${t.hongguo.episodeLabel(index: episode.index)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.title.copyWith(color: OnVideoColors.foreground),
              ),
            ),
          ),
          // The stage's corner cluster rides the strip in fullscreen: the
          // capture, the download and the switches the bar no longer carries.
          if (detail != null) _stageCornerActions(t, detail),
          // The small window's own close: done watching here means the window
          // goes, and the page stays where its host left it. A window that
          // cannot close carries no verb.
          if (inPip)
            PlayerGlassPill(
              child: PlayerBarButton(
                icon: DsIcons.x,
                label: t.common.close,
                onPressed: () {
                  final close = ref.read(roomLeaveProvider);
                  if (close == null) return;
                  _wake();
                  unawaited(_handle?.pause());
                  unawaited(close());
                },
              ),
            ),
        ],
      ),
    );
  }

  /// The stage's corner cluster, the phone player's own: a pill with the
  /// frame's capture and this episode's download, and a pill with the more
  /// menu — statistics, the sleep timer, the audio mode, the compact window,
  /// the picture bar, the danmaku and the mute. The three choices that want a
  /// catalogue (sleep, fit, danmaku) hang their cards over the bar anchored
  /// here, which is why this cluster carries their anchors.
  Widget _stageCornerActions(Translations t, HongguoSeriesDetail detail) {
    final handle = _handle;
    final episode = _episode;
    final task = _episodeDownload(episode);
    final busy =
        task != null && (task.phase == HongguoDownloadPhase.running || task.phase == HongguoDownloadPhase.queued);
    final finished = task != null && task.phase == HongguoDownloadPhase.done;
    final downloadLabel = switch (task?.phase) {
      HongguoDownloadPhase.queued => t.settings.downloadStatusQueued,
      HongguoDownloadPhase.running => '${task!.total > 0 ? task.received * 100 ~/ task.total : 0}%',
      HongguoDownloadPhase.paused => t.settings.downloadResume,
      HongguoDownloadPhase.done => t.hongguo.downloaded,
      HongguoDownloadPhase.failed || null => t.hongguo.download,
    };
    final fit = ref.watch(playbackSettingsProvider).fit;
    final danmaku = ref.watch(hongguoDanmakuSettingsProvider);
    final pipIn = handle != null && _presentationNotifier.pipAvailable;
    final presentation = ref.watch(roomPresentationProvider);
    final pipInMode = presentation == PresentationMode.pip;
    return MouseRegion(
      // Resting on the cluster holds the bar, the way resting on the bar does.
      onEnter: (_) => _hideTimer?.cancel(),
      onExit: (_) => _scheduleHide(),
      child: KeyedSubtree(
        key: _panelAnchors[_HongguoPanel.sleep],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: DsSpace.s8,
          children: [
            // One pill, the room cluster's single form — never two pills
            // drifting apart — holding every verb that acts on the picture,
            // in one order on every video page: the frame's copy first, then
            // where the picture goes, the lock, and the more door last. The
            // capture shows on every stage: there is no edge column here
            // that could carry it instead. The download lives in the more
            // container.
            PlayerGlassPill(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (handle?.canCaptureScreenshot ?? false)
                    PlayerBarButton(
                      icon: DsIcons.camera,
                      label: t.player.screenshot,
                      onPressed: () {
                        _wake();
                        unawaited(_screenshot());
                      },
                    ),
                  // The episode playing now, sent to a TV on the local
                  // network — the same dialog the other video pages open.
                  if (_castUrl != null)
                    PlayerBarButton(
                      icon: DsIcons.cast,
                      label: t.player.cast,
                      onPressed: () {
                        _wake();
                        unawaited(_cast());
                      },
                    ),
                  // The small window follows, the room's own order: where
                  // the picture goes comes before what is done to it.
                  if (pipIn && !pipInMode)
                    PlayerBarButton(
                      icon: DsIcons.pictureInPicture,
                      label: t.player.pipOn,
                      onPressed: () {
                        _wake();
                        unawaited(_togglePip());
                      },
                    ),
                  if (_miniWindowReady &&
                      ref.watch(playbackSettingsProvider.select((settings) => settings.floatWindow)))
                    PlayerBarButton(
                      icon: DsIcons.appWindow,
                      label: t.common.miniWindow,
                      onPressed: () {
                        _wake();
                        unawaited(_enterMiniWindow());
                      },
                    ),
                  // The watching lock, the room's own rule. The picture's
                  // edge here belongs to the episode's own action column,
                  // so the lock rides the cluster beside the capture
                  // verb; taken, the unlock pill is the edge's whole
                  // chrome.
                  PlayerBarButton(
                    icon: _locked ? DsIcons.unlock : DsIcons.lock,
                    label: _locked ? t.room.unlockControls : t.room.lockControls,
                    onPressed: _toggleLock,
                  ),
                  PlayerBarButton(
                    icon: DsIcons.ellipsisVertical,
                    label: t.common.more,
                    onPressed: () {
                      _wake();
                      unawaited(
                        // The room's container — a side panel on a wide
                        // window, a bottom sheet on a narrow one, the
                        // room's own shape: the download and the audio
                        // as round tiles, the switches and the choices as
                        // one list. The timer gives way to its own
                        // anchored panel, so the container pops first.
                        showPlayerMoreContainer(
                          context,
                          content: (context, {required labeled}) => StatefulBuilder(
                            builder: (context, setPanel) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                spacing: DsSpace.s12,
                                children: [
                                  // What the panel does, over what it sets: the episode's copy
                                  // for the disk and the sound without the picture — the two
                                  // verbs whose home is no bar. The capture and the lock ride
                                  // the corner cluster, the like, the bookmark, the comments
                                  // and the share the episode's action column.
                                  PlayerMoreTiles(
                                    tiles: [
                                      if (episode != null)
                                        PlayerMoreTile(
                                          color: PlayerMoreHues.download,
                                          icon: DsIcons.download,
                                          // A task under way says its own state under the
                                          // circle.
                                          label: task == null ? t.hongguo.download : downloadLabel,
                                          // A task running or already finished has
                                          // nothing to press.
                                          onTap: busy || finished
                                              ? null
                                              : () {
                                                  Navigator.of(context).pop();
                                                  _wake();
                                                  unawaited(_startDownload());
                                                },
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
                                        // Read fresh on the panel's own redraw:
                                        // the pick flips the provider under the
                                        // row, and this switch is the first
                                        // thing the redraw reads.
                                        trailing: DsSwitch(
                                          value: ref.read(playerStatsVisibleProvider),
                                          onChanged: (_) {
                                            ref.read(playerStatsVisibleProvider.notifier).toggle();
                                            setPanel(() {});
                                          },
                                        ),
                                      ),
                                      // The timer's panel takes the menu's place: the menu puts
                                      // itself away first.
                                      PlayerMoreRow(
                                        label: t.hongguo.sleep,
                                        leading: DsIcons.timer,
                                        value: _sleep.active ? _sleep.label(t) : t.hongguo.sleepOff,
                                        onTap: () {
                                          Navigator.of(context).pop();
                                          _wake();
                                          _showPanel(_HongguoPanel.sleep);
                                        },
                                      ),
                                      // The picture's shape, picked on the shared choice panel —
                                      // the pick holds the notifier, since it runs once this
                                      // container is gone.
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
                                                  onPick: () => unawaited(
                                                    ref.read(playbackSettingsProvider.notifier).setFit(option),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // The flying layer's switch. Its tuning — the gear — is the
                                      // bar's own, where the viewer reaches for it.
                                      PlayerMoreRow(
                                        label: t.hongguo.danmaku,
                                        leading: DsIcons.captions,
                                        value: null,
                                        onTap: () {
                                          unawaited(
                                            ref
                                                .read(hongguoDanmakuSettingsProvider.notifier)
                                                .setEnabled(value: !danmaku.enabled),
                                          );
                                          setPanel(() {});
                                        },
                                        trailing: DsSwitch(
                                          value: danmaku.enabled,
                                          onChanged: (_) {
                                            unawaited(
                                              ref
                                                  .read(hongguoDanmakuSettingsProvider.notifier)
                                                  .setEnabled(value: !danmaku.enabled),
                                            );
                                            setPanel(() {});
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: DsSpace.s12),
                                ],
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The bar under the picture: the seek line, then one control line — the
  /// episode's steps and the transport leading it, the sound after, the
  /// catalogues beside them, and the fullscreen pair at the line's end, the
  /// picture's bottom-right corner. A line that cannot carry the catalogues
  /// gives them the line above, so play stays the first control of the bottom
  /// line and the way out its last, whatever the width. The switches that
  /// left the bar — the statistics, the sleep timer, the audio mode, the
  /// compact window, the picture bar — live in the corner cluster's more menu.
  Widget _controlBar(BuildContext context, {required bool immersive}) {
    final t = context.t;
    final handle = _handle;
    final ready = _playerReady;
    if (!ready) return const SizedBox(height: 72);
    final transport = _transport;
    final playing = transport?.isPlaying ?? false;
    final duration = transport?.duration ?? Duration.zero;
    final position = _dragSeconds != null
        ? Duration(milliseconds: (_dragSeconds! * 1000).round())
        : transport?.position ?? Duration.zero;
    final speedLabel = playerRateLabel(_speed);
    final next = _nextEpisode();
    final previous = _previousEpisode();
    final presentation = ref.watch(roomPresentationProvider);
    // The danmaku trio's state, watched here so the switch and the list chip
    // read fresh on every pick.
    final danmaku = ref.watch(hongguoDanmakuSettingsProvider);
    final danmakuItems = ref.watch(hongguoDanmakuProvider).items;
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
          // bends, and gone under 480, where the mute and the wheel still carry
          // the sound.
          final volumeWidth = barWidth >= 720 ? 96.0 : (barWidth >= 480 ? 72.0 : null);
          // The catalogues: the danmaku trio, then the episode's three
          // choices. The line is read off the bar's own width — the words go
          // first, then the line gives way to the one above.
          final qualityLabel = (_attempted?.quality ?? 0) > 0 ? '${_attempted!.quality}P' : t.player.quality;
          final hasList = danmakuItems.isNotEmpty;
          double picker(String label, {required bool words, double? maxWord}) =>
              playerBarPickerExtent(context, label, compact: !words, maxWord: maxWord);
          final line = playerBarLine(
            barWidth: barWidth,
            gap: gap,
            fixed: [
              if (previous != null) control,
              control,
              if (next != null) control,
              control,
              ?volumeWidth,
              if (_desktop && !pip) control,
              if (!pip) control,
            ],
            worded: [
              control,
              if (hasList) control,
              control,
              picker(qualityLabel, words: true),
              picker(speedLabel, words: true),
              picker(t.hongguo.episodes, words: true, maxWord: 168),
            ],
            glyphs: [
              control,
              if (hasList) control,
              control,
              picker(qualityLabel, words: false),
              picker(speedLabel, words: false),
              picker(t.hongguo.episodes, words: false),
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s4,
            children: [
              // The bar's first layer: the clocks at the line's ends at every
              // width — the archive bars' layer, this station's seek riding
              // it, the drag speaking the same two callbacks it always did.
              PlayerSeekLayer.replay(
                position: position,
                duration: duration,
                buffered: _transport?.buffer.ranges ?? const [],
                onSeek: (seconds) => unawaited(_seekTo(seconds)),
                onScrub: (seconds) => setState(() => _dragSeconds = seconds),
              ),
              PlayerBarRows(
                foldWidth: line.inline ? 0 : double.infinity,
                foldAbove: true,
                gap: gap,
                start: Row(
                  spacing: gap,
                  children: [
                    // The episode's steps lead, the way every serial's bar
                    // carries them: the episode before, play, the episode
                    // after — where the thumb starts, at every width.
                    if (previous != null)
                      PlayerBarButton(
                        icon: DsIcons.skipBack,
                        label: t.hongguo.previousEpisode,
                        onPressed: handle == null ? null : () => unawaited(_openEpisode(previous)),
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
                    if (next != null)
                      PlayerBarButton(
                        icon: DsIcons.skipForward,
                        label: t.hongguo.nextEpisode,
                        onPressed: handle == null ? null : () => unawaited(_openEpisode(next)),
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
                          value: _effectivelyMuted ? 0.0 : _volume,
                          style: const DsSliderStyle(
                            height: 24,
                            trackHeight: 4,
                            trackColor: OnVideoColors.track,
                            fillColor: OnVideoColors.foreground,
                            thumbColor: OnVideoColors.foreground,
                            thumbSize: 12,
                          ),
                          onChanged: !ready ? null : (value) => unawaited(_setVolume(value)),
                          semanticLabel: t.player.volume,
                        ),
                      ),
                  ],
                ),
                middle: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    spacing: gap,
                    children: [
                      // The danmaku trio leads the catalogue row, the room
                      // bar's order: the switch, the track as a list against
                      // the clock, and the gear whose panel keeps its tuning.
                      PlayerBarButton(
                        iconAsset: danmaku.enabled ? 'assets/icons/danmaku-on.svg' : 'assets/icons/danmaku-off.svg',
                        label: danmaku.enabled ? t.common.danmakuOff : t.common.danmakuOn,
                        onPressed: handle == null
                            ? null
                            : () {
                                _wake();
                                unawaited(
                                  ref.read(hongguoDanmakuSettingsProvider.notifier).setEnabled(value: !danmaku.enabled),
                                );
                              },
                      ),
                      if (danmakuItems.isNotEmpty)
                        PlayerBarButton(
                          key: _panelAnchors[_HongguoPanel.danmakuList],
                          iconAsset: 'assets/icons/danmaku.svg',
                          label: t.room.danmakuListTitle,
                          selected: _openPanel == _HongguoPanel.danmakuList,
                          onPressed: handle == null
                              ? null
                              : () {
                                  _wake();
                                  setState(
                                    () => _openPanel = _openPanel == _HongguoPanel.danmakuList
                                        ? null
                                        : _HongguoPanel.danmakuList,
                                  );
                                },
                        ),
                      PlayerBarButton(
                        key: _panelAnchors[_HongguoPanel.danmaku],
                        iconAsset: 'assets/icons/danmaku-settings.svg',
                        label: t.settings.navDanmaku,
                        selected: _openPanel == _HongguoPanel.danmaku,
                        onPressed: handle == null
                            ? null
                            : () {
                                _wake();
                                setState(
                                  () => _openPanel = _openPanel == _HongguoPanel.danmaku ? null : _HongguoPanel.danmaku,
                                );
                              },
                      ),
                      _pickerButton(
                        panel: _HongguoPanel.quality,
                        icon: DsIcons.gauge,
                        label: qualityLabel,
                        semanticLabel: t.player.quality,
                        compact: !line.words,
                      ),
                      _pickerButton(
                        panel: _HongguoPanel.speed,
                        icon: DsIcons.timer,
                        label: speedLabel,
                        semanticLabel: t.player.speed,
                        compact: !line.words,
                      ),
                      _pickerButton(
                        panel: _HongguoPanel.episodes,
                        icon: DsIcons.listVideo,
                        // The count reads on the panel this opens; the bar's chip
                        // stays the one word, so the row keeps its line.
                        label: t.hongguo.episodes,
                        semanticLabel: t.hongguo.episodes,
                        compact: !line.words,
                      ),
                    ],
                  ),
                ),
                end: Row(
                  spacing: gap,
                  children: [
                    // The window verbs, then the way out of the picture's box —
                    // the room bar's pair: the desktop's window-fullscreen
                    // first, then the system fullscreen the phone turns for.
                    // The window's own shape with the arrows that say which way
                    // it goes.
                    if (_desktop && presentation != PresentationMode.pip)
                      PlayerBarButton(
                        icon: presentation == PresentationMode.windowFullscreen
                            ? DsIcons.squareShrinkUpLeftDownRight
                            : DsIcons.squareExpandUpRightDownLeft,
                        label: presentation == PresentationMode.windowFullscreen
                            ? t.player.windowFullscreenOff
                            : t.player.windowFullscreenOn,
                        selected: presentation == PresentationMode.windowFullscreen,
                        onPressed: handle == null ? null : () => unawaited(_toggleWindowFullscreen()),
                      ),
                    // The small window has no fullscreen of its own to toggle —
                    // its way back rides the small window's chrome — so the verb
                    // stands down there.
                    if (presentation != PresentationMode.pip)
                      PlayerBarButton(
                        icon: immersive ? DsIcons.minimize : DsIcons.maximize,
                        label: immersive ? t.player.fullscreenOff : t.player.fullscreen,
                        selected: presentation == PresentationMode.fullscreen,
                        onPressed: handle == null ? null : () => unawaited(_toggleFullscreen()),
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

  /// One picker on the bar: the glyph, the current choice's words when the
  /// bar has room, and the chevron that says a panel hangs above it.
  Widget _pickerButton({
    required _HongguoPanel panel,
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
                      constraints: BoxConstraints(maxWidth: panel == _HongguoPanel.episodes ? 168 : 110),
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
  static double _panelWidth(_HongguoPanel panel) => switch (panel) {
    _HongguoPanel.sleep => 220,
    _HongguoPanel.speed => 180,
    _HongguoPanel.quality => 220,
    // Five numbered tiles to a row, as the reference's episode grid — a
    // series runs to a hundred and the tiles are what a viewer reads.
    _HongguoPanel.episodes => 300,
    // The comments' settings at the width every player's sliders are drawn:
    // a slider needs the room a 200 px card never had.
    _HongguoPanel.danmaku => 280,
    _HongguoPanel.danmakuList => 300,
  };

  /// The open picker's catalogue.
  Widget _panel(Translations t, _HongguoPanel panel) {
    switch (panel) {
      case _HongguoPanel.sleep:
        return PlayerOverlayPanel(
          title: t.hongguo.sleep,
          width: _panelWidth(panel),
          children: [
            PlayerPanelOption(
              label: t.hongguo.sleepOff,
              selected: !_sleep.active,
              onPressed: () {
                _closePanel();
                _setSleep();
              },
            ),
            for (final minutes in const [15, 30, 60, 90])
              PlayerPanelOption(
                label: t.hongguo.sleepAfter(minutes: minutes),
                selected: _sleep.remaining != null && (_sleep.remaining!.inMinutes - minutes).abs() <= 1,
                onPressed: () {
                  _closePanel();
                  _setSleep(minutes: minutes);
                },
              ),
            PlayerPanelOption(
              label: t.hongguo.sleepThisEpisode,
              selected: _sleep.episodesLeft == 1,
              onPressed: () {
                _closePanel();
                _setSleep(episodes: 1);
              },
            ),
            for (final count in const [3, 5])
              PlayerPanelOption(
                label: t.hongguo.sleepAfterEpisodes(count: count),
                selected: _sleep.episodesLeft == count,
                onPressed: () {
                  _closePanel();
                  _setSleep(episodes: count);
                },
              ),
          ],
        );
      case _HongguoPanel.speed:
        return PlayerOverlayPanel(
          title: t.player.speed,
          width: _panelWidth(panel),
          children: [
            for (final speed in _speedChoices)
              PlayerPanelOption(
                label: playerRateLabel(speed),
                selected: speed == _speed,
                onPressed: () {
                  _closePanel();
                  unawaited(_setSpeed(speed));
                },
              ),
          ],
        );
      case _HongguoPanel.quality:
        final choice = ref.watch(hongguoSettingsProvider).quality;
        return PlayerOverlayPanel(
          title: t.player.quality,
          width: _panelWidth(panel),
          children: [
            for (final value in HongguoQualityChoice.values)
              PlayerPanelOption(
                label: value.label(t),
                selected: value == choice,
                onPressed: () {
                  _closePanel();
                  final episode = _episode;
                  final position = _transport?.position.inMilliseconds;
                  unawaited(ref.read(hongguoSettingsProvider.notifier).setQuality(value));
                  if (episode != null) {
                    unawaited(_openEpisode(episode, resume: position == null ? null : position / 1000));
                  }
                },
              ),
          ],
        );
      case _HongguoPanel.episodes:
        return _episodesPanel(t);
      case _HongguoPanel.danmaku:
        final danmaku = ref.watch(hongguoDanmakuSettingsProvider);
        final controller = ref.read(hongguoDanmakuSettingsProvider.notifier);
        return PlayerOverlayPanel(
          title: t.hongguo.danmaku,
          width: _panelWidth(panel),
          children: [
            // How many rows the comments may fill: three steps, so they
            // stand as three chips and are read at a glance — a measure of
            // three is chosen, not slid to.
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s12, 0, DsSpace.s12, DsSpace.s12),
              child: Row(
                spacing: DsSpace.s6,
                children: [
                  for (final density in HongguoDanmakuDensity.values)
                    Expanded(
                      child: PlayerPanelChip(
                        label: density.label(t),
                        selected: density == danmaku.density,
                        onPressed: () => unawaited(controller.setDensity(density)),
                      ),
                    ),
                ],
              ),
            ),
            // The measures, slid the way every player's danmaku settings
            // slide them, so the picture stays visible while the look is
            // tuned. The switch is the bar's own glyph, not a row here.
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: DsSpace.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: DsSpace.s12,
                children: [
                  PlayerPanelSlider(
                    label: t.hongguo.danmakuFontSize,
                    value: '${danmaku.fontSize.round()}',
                    current: danmaku.fontSize,
                    min: 14,
                    max: 40,
                    onChanged: (value) => unawaited(controller.setFontSize(value)),
                  ),
                  PlayerPanelSlider(
                    label: t.hongguo.danmakuOpacity,
                    value: '${(danmaku.opacity * 100).round()}%',
                    current: danmaku.opacity,
                    min: 0.2,
                    max: 1,
                    onChanged: (value) => unawaited(controller.setOpacity(value)),
                  ),
                  PlayerPanelSlider(
                    label: t.hongguo.danmakuSpeed,
                    value: playerRateLabel(danmaku.speed),
                    current: danmaku.speed,
                    min: 0.5,
                    max: 2,
                    divisions: 3,
                    onChanged: (value) => unawaited(controller.setSpeed(value)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DsSpace.s12),
          ],
        );
      case _HongguoPanel.danmakuList:
        // The track's whole timeline, the (time, words) pairs the provider
        // keeps in the episode's own order: a row's tap seeks the episode
        // there.
        return PlayerDanmakuListPanel(
          lines: [
            for (final (ms, text) in ref.watch(hongguoDanmakuProvider).items)
              (at: Duration(milliseconds: ms), text: text, color: 0xFFFFFFFF),
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

  /// The immersive episodes catalogue: the same navigation the shelf under
  /// the picture already gives — this group's numbered tiles, the ranges that
  /// page through the series, the tick on what has been watched — drawn in the
  /// panel's own ink, because the card behind it is dark in every theme and
  /// the theme's text would go dark-on-dark over the picture.
  Widget _episodesPanel(Translations t) {
    final detail = _detail;
    final episodes = detail?.episodes ?? const <HongguoEpisode>[];
    final groups = (episodes.length + kHongguoEpisodeGroup - 1) ~/ kHongguoEpisodeGroup;
    final group = (_episodesGroup ?? hongguoEpisodeGroupOf(episodes, _episode)).clamp(0, groups <= 0 ? 0 : groups - 1);
    final shown = episodes.skip(group * kHongguoEpisodeGroup).take(kHongguoEpisodeGroup);
    final marks = hongguoEpisodeMarks(ref.read(hongguoLibraryProvider).progressOf(widget.seriesId));
    final current = _episode;
    return PlayerOverlayPanel(
      title: _episodesLabel(t),
      width: _panelWidth(_HongguoPanel.episodes),
      children: [
        PlayerPanelGrid(
          // The ranges page through a series too long for one page of tiles.
          ranges: [
            if (groups > 1)
              for (var index = 0; index < groups; index++)
                PlayerPanelChip(
                  label: hongguoEpisodeRangeLabel(episodes, index),
                  selected: index == group,
                  onPressed: () => setState(() => _episodesGroup = index),
                ),
          ],
          tiles: [
            for (final episode in shown)
              _episodeTile(
                t,
                episode,
                playing: episode.vid == current?.vid && episode.index == current?.index,
                marks: marks,
              ),
          ],
        ),
      ],
    );
  }

  /// One episode's tile in the grid: lit white while it plays, ticked once it
  /// is finished, and marked where the viewer stopped part-way.
  Widget _episodeTile(
    Translations t,
    HongguoEpisode episode, {
    required bool playing,
    required ({int watchedThrough, int? resumeAt}) marks,
  }) {
    // The number is what the grid shows, as the shelf under the picture shows
    // it; where the source names the episode, the name still reads out.
    final label = t.hongguo.episodeLabel(index: episode.index);
    final resume = !playing && episode.index == marks.resumeAt;
    final watched = !playing && !resume && episode.index <= marks.watchedThrough;
    return PlayerPanelTile(
      label: '${episode.index}',
      selected: playing,
      mark: resume
          ? PlayerPanelTileMark.resume
          : watched
          ? PlayerPanelTileMark.watched
          : PlayerPanelTileMark.none,
      semanticLabel: episode.title.isEmpty ? label : '$label ${episode.title}',
      onPressed: () {
        _closePanel();
        unawaited(_openEpisode(episode));
      },
    );
  }

  /// Shows the bars and, while the stream plays, lets them settle away again.
  void _wake() {
    if (mounted && !_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  /// A press on the picture: up when they are down, down when they are up.
  void _toggleControls() {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _wake();
    }
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
    final seconds = ref.read(modulePlaybackSettingsProvider(PlayerModule.hongguo)).controlsAutoHideSeconds;
    // The setting's zero is 常显: the bar never hides on idle while the
    // drama plays.
    if (seconds <= 0) return;
    _hideTimer = Timer(Duration(seconds: seconds), () {
      if (mounted && (_transport?.isPlaying ?? false) && _openPanel == null) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _showPanel(_HongguoPanel panel) {
    _hoverTimer?.cancel();
    _leaveTimer?.cancel();
    if (_openPanel == panel) return;
    // The episodes catalogue opens where the viewer stands, not at the first.
    if (panel == _HongguoPanel.episodes) _episodesGroup = null;
    setState(() => _openPanel = panel);
    _hideTimer?.cancel();
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
  void _hoverPanel(_HongguoPanel panel) {
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
}

/// One action on the picture's own column: a disc with the glyph and, under
/// it, the count the phone prints. Over the video the disc is the on-video
/// glass; beside it, the theme's own control.
final class _RailAction extends StatelessWidget {
  const _RailAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.count,
    this.selected = false,
    this.strong = false,
    this.onVideo = false,
  });

  /// The glyph in the disc.
  final DsIconData icon;

  /// The action's name, for the tooltip and screen readers.
  final String label;

  /// What the action does.
  final VoidCallback onPressed;

  /// The figure under the disc, when the platform has one.
  final String? count;

  /// Whether the action's state is on, as a favorite is: the disc tints to
  /// say so.
  final bool selected;

  /// The column's one strong verb — the next episode — in the accent
  /// outright.
  final bool strong;

  /// Whether the disc sits on the video's ink (white on glass) or on the
  /// page's own surface (theme colours).
  final bool onVideo;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsTooltip(
      message: label,
      child: DsPressable(
        semanticLabel: label,
        onPressed: onPressed,
        builder: (context, states, _) {
          final lit = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
          final Color disc;
          final Color glyph;
          if (onVideo) {
            disc = selected || strong
                ? colors.accent
                : lit
                ? OnVideoColors.inkHover
                : OnVideoColors.dimLight;
            glyph = selected || strong ? colors.onAccent : OnVideoColors.foreground;
          } else if (strong) {
            disc = colors.accent;
            glyph = colors.onAccent;
          } else if (selected) {
            disc = colors.accent.withValues(alpha: 0.14);
            glyph = colors.accentText;
          } else {
            disc = lit ? colors.hover : colors.control;
            glyph = colors.text;
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            spacing: DsSpace.s4,
            children: [
              AnimatedContainer(
                duration: theme.motion.toneDuration,
                curve: theme.motion.toneCurve,
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: DsBoxDecoration(color: disc, borderRadius: BorderRadius.circular(theme.radii.control(38))),
                child: DsIcon(icon, size: theme.sizes.iconLg, color: glyph),
              ),
              if (count case final figure?)
                Text(
                  figure,
                  style: theme.typography.numeric(
                    theme.typography.caption.copyWith(
                      color: onVideo ? OnVideoColors.foreground : colors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The picture's frame: an aspect box for the page's stage, the window's own
/// shape for a surface that fills it (the sideways-immersive window).
final class _FramedPicture extends StatelessWidget {
  const _FramedPicture({required this.fills, required this.aspectRatio, required this.child});

  /// Whether the picture takes the whole box instead of an aspect shape.
  final bool fills;

  /// The stage's own shape when it keeps one.
  final double aspectRatio;

  /// The picture and its controls.
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      fills ? SizedBox.expand(child: child) : AspectRatio(aspectRatio: aspectRatio, child: child);
}

/// The watch head's loading shape: the title, the figures and the verbs as
/// bars where their words will stand, the blurb as its block.
final class _HeadSkeleton extends StatelessWidget {
  const _HeadSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DsSpace.s12,
      children: [
        DsSkeleton(width: double.infinity, height: 20, strong: true),
        DsSkeleton(width: 260, height: 12),
        Row(
          spacing: DsSpace.s8,
          children: [
            DsSkeleton(width: 88, height: 30),
            DsSkeleton(width: 88, height: 30),
            DsSkeleton(width: 88, height: 30),
            DsSkeleton.circle(size: 30),
          ],
        ),
        DsSkeleton.block(width: double.infinity, height: 44),
      ],
    );
  }
}

/// The episode shelf's loading shape: the header bar and three of the rail
/// rows — cover block at the head, two lines beside.
final class _ShelfSkeleton extends StatelessWidget {
  const _ShelfSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DsSpace.s8,
      children: [
        const DsSkeleton(width: 160, height: 18, strong: true),
        for (final _ in const [1, 2, 3])
          const Row(
            spacing: DsSpace.s8,
            children: [
              DsSkeleton.block(width: 120, height: 68),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s6,
                  children: [DsSkeleton(width: 140, height: 14), DsSkeleton(width: 64, height: 12)],
                ),
              ),
            ],
          ),
      ],
    );
  }
}
