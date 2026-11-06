import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart' show AppBar, Scaffold;
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
    show HongguoEpisodeShelf, hongguoEpisodeGroupOf, hongguoEpisodeMarks, kHongguoEpisodeGroup;
import 'package:pure_live/modules/hongguo/widgets/hongguo_widgets.dart' show hongguoDurationText;
import 'package:pure_live/shared/shared.dart';

/// The catalogues the picture bar hangs over.
enum _HongguoPanel { fit, sleep, speed, quality, episodes, danmaku }

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

  /// The bar and each picker's box: the open catalogue hangs over the button
  /// that raised it rather than at the picture's end edge.
  final GlobalKey _barAnchor = GlobalKey(debugLabel: 'hongguo-bar');
  final Map<_HongguoPanel, GlobalKey> _panelAnchors = {
    for (final panel in _HongguoPanel.values) panel: GlobalKey(debugLabel: 'hongguo-picker-${panel.name}'),
  };

  /// The corner cluster's more menu. The page owns the controller so a menu
  /// floating over the picture holds the bar up for as long as it is open —
  /// the menu lives outside the stage's own stack, where the pointer no
  /// longer reaches the regions that keep the bar awake.
  final DsOverlayController _moreMenu = DsOverlayController();

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
    _moreMenu.addListener(_onMoreMenuChanged);
    WidgetsBinding.instance.addObserver(this);
    _globalMute = ref.read(playbackSettingsProvider).globalMute;
    _volume = ref.read(playbackSettingsProvider.notifier).volume;
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
    if (route is ModalRoute<void>) {
      // The field is not promoted by flow analysis, so name the type.
      // ignore: omit_local_variable_types
      final RouteObserver<ModalRoute<void>> observer = _routeObserver ?? ref.read(routeObserverProvider);
      _routeObserver = observer;
      observer.subscribe(this, route);
    }
  }

  /// Another page covers this one: the picture pauses rather than playing
  /// under it.
  @override
  void didPushNext() {
    final handle = _handle;
    if (handle != null && (_transport?.isPlaying ?? false)) {
      unawaited(handle.pause().catchError((Object _) {}));
    }
  }

  /// Holds the display awake exactly while the episode plays and the
  /// preference allows it.
  void _syncScreenWake(bool hold) {
    if (hold == _screenHeld) return;
    _screenHeld = hold;
    unawaited((hold ? _screenAwake.enable() : _screenAwake.disable()).catchError((Object _) {}));
  }

  @override
  void dispose() {
    _disposed = true;
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
      _silence(handle);
      unawaited(_kernel.release(handle.id));
    }
    WidgetsBinding.instance.removeObserver(this);
    _routeObserver?.unsubscribe(this);
    _saveProgress(force: true);
    _hideTimer?.cancel();
    _hideTimer = null;
    _moreMenu.removeListener(_onMoreMenuChanged);
    _moreMenu.dispose();
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
    _networkWait?.close();
    _networkWait = null;
    unawaited(_transportSub?.cancel() ?? Future<void>.value());
    unawaited(_eventSub?.cancel() ?? Future<void>.value());
    unawaited(_geometrySub?.cancel() ?? Future<void>.value());
    _geometrySub = null;
    _danmakuNotifier.stop();
    _playFocus.dispose();
    super.dispose();
  }

  /// Silences a handle the moment the page lets it go: mute first — it takes
  /// effect at once — then pause. The release below is queued behind whatever
  /// the playback is doing (an open still dialling a stuck proxy takes its
  /// whole budget), and the episode must not be heard over the page the
  /// viewer returned to while that queue drains. Both are fire-and-forget; a
  /// handle already being released is silent by definition, so a refusal
  /// needs no answer — the room controller's own teardown does the same.
  static void _silence(PlayerHandle handle) {
    unawaited(() async {
      try {
        await handle.setMute(muted: true);
      } on Object {
        // Already gone.
      }
      try {
        await handle.pause();
      } on Object {
        // Already gone.
      }
    }());
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
    if (_opening) return;
    _stopWaiting();
    final sameEpisode = _episode?.vid == episode.vid;
    if (!recovering) _saveProgress(force: true);
    if (!sameEpisode) {
      _recovery.reset();
      _autoDowngrades = 0;
      _attempted = null;
      _lastFailure = null;
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
            config: const PlayerConfig(name: 'hongguo'),
            preferredBackend: ref.read(playerKernelBackendProvider).id,
          );
      if (!mounted || _disposed) {
        if (existing == null) {
          _silence(handle);
          unawaited(_kernel.release(handle.id));
        }
        return;
      }
      _handle = handle;
      _bind(handle);
      await _applyEngineOptions(handle);
      final uri = Uri.parse(url);
      await handle.open(
        PlayerSource.of(
          id: SourceId('hongguo:${widget.seriesId}:${episode.vid}:${DateTime.now().microsecondsSinceEpoch}'),
          uri: uri,
          type: SourceType.remote,
          protocol: SourceProtocol.fromScheme(uri.scheme),
          format: SourceFormat.fromUri(uri),
          title: _detail?.meta.title ?? episode.title,
        ),
        autoPlay: autoplay && !_sleepStopped,
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
      setState(() {
        _opening = false;
        _error = null;
      });
    } on Object catch (error) {
      if (!mounted || _disposed) return;
      // The handle may still hold the previous episode; it is not the
      // episode this page now names, so it goes rather than playing on
      // behind a failed switch.
      final stale = _handle;
      if (stale != null) {
        _handle = null;
        _silence(stale);
        unawaited(_kernel.release(stale.id));
      }
      setState(() => _opening = false);
      _onPlaybackFailure(error);
    }
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
    if (position > Duration.zero) _retryPosition = position;
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
    if (episode == null) return;
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
      // the picture's own size.
      ref.read(fullscreenDriverProvider).onVideoSize(size.width, size.height);
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
      if (state.isPlaying) _scheduleHide();
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
    if (handle == null) return;
    final playing = _transport?.isPlaying ?? false;
    if (!playing && _sleepStopped) {
      // Pressing play after a sleep stop resumes the session.
      _sleepStopped = false;
      if (mounted) setState(() {});
    }
    try {
      playing ? await handle.pause() : await handle.play();
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _seekTo(double seconds) async {
    final handle = _handle;
    if (handle == null) return;
    try {
      await handle.seek(Duration(milliseconds: (seconds * 1000).round()));
    } on Object catch (error) {
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
      title: file == null ? t.room.screenshotFailed : t.room.screenshotSaved(name: file.uri.pathSegments.last),
      status: file == null ? DsStatus.danger : DsStatus.success,
    );
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
    if (handle == null || _opening || _error != null) return;
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
  void _saveProgress({bool force = false, bool completed = false}) {
    final episode = _episode;
    final transport = _transport;
    if (episode == null || transport == null) return;
    final total = transport.duration.inMilliseconds;
    final position = transport.position.inMilliseconds;
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
            title: t.hongguo.downloadFailed,
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
    if (immersive) {
      return Scaffold(backgroundColor: colors.canvas, body: _playerSurface(context, immersive: true));
    }
    // The arrows mirror the room page: up and down take the wheel's step (the
    // 画质与音频 setting) toward the volume, left and right skip five seconds.
    // A TV keeps its arrows for focus; the remote drives the volume itself.
    final tv = ref.watch(platformRuntimeProvider).environment.runtime.formFactor == FormFactor.tv;
    final volumeStep = ref.watch(playbackSettingsProvider.select((settings) => settings.volumeWheelStepPercent)) / 100;
    void nudgeVolume(double delta) => unawaited(_setVolume((_volume + delta).clamp(0.0, 1.0)));
    void nudgeSeek(double delta) {
      final position = _transport?.position;
      if (position == null) return;
      final target = position.inMilliseconds / 1000 + delta;
      unawaited(_seekTo(target < 0 ? 0 : target));
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
          if (!tv) const SingleActivator(LogicalKeyboardKey.arrowLeft): () => nudgeSeek(-5),
          if (!tv) const SingleActivator(LogicalKeyboardKey.arrowRight): () => nudgeSeek(5),
        },
        child: Scaffold(
          backgroundColor: colors.surface,
          appBar: AppBar(
            backgroundColor: colors.surface,
            surfaceTintColor: const Color(0x00000000),
            elevation: 0,
            title: Text(
              _episode == null
                  ? detail?.meta.title ?? t.hongguo.opening
                  : '${detail?.meta.title ?? ''} · ${t.hongguo.episodeLabel(index: _episode!.index)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: _loading && detail == null
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

  /// The stage the episode plays in, with the episode shelf docked beside it
  /// on a wide window — the reference's portrait stage and its side shelf. On
  /// a narrow window the page stacks the way it did: the stage on top, then
  /// what is playing, the shelf, and the episode's comments.
  Widget _body(BuildContext context, HongguoSeriesDetail? detail) {
    final t = context.t;
    // The page's own margin, asked from the app's one rule rather than kept
    // here: on a phone a private 20 puts this page's left edge beside every
    // other page's 16.
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final player = Center(child: _stage(context));
    final head = detail == null ? const SizedBox.shrink() : _watchHead(context, detail, t);
    final shelf = detail == null
        ? const SizedBox.shrink()
        : HongguoEpisodeShelf(detail: detail, current: _episode, onOpen: (episode) => unawaited(_openEpisode(episode)));
    final comments = HongguoCommentPanel(seriesId: widget.seriesId, episodeVid: _episode?.vid ?? '');
    if (MediaQuery.sizeOf(context).width < 1100) {
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s16,
          children: [player, head, shelf, comments],
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(inset, DsSpace.s16, DsSpace.s16, DsSpace.s16),
            child: player,
          ),
        ),
        SizedBox(
          width: 340,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, DsSpace.s16, DsSpace.s20, DsSpace.s24),
            child: shelf,
          ),
        ),
      ],
    );
  }

  /// The stage box a non-immersive picture plays in: an episode shot upright
  /// keeps its own shape but never draws narrower than 9:16, a landscape
  /// episode keeps its width-first shape — the picture is never forced into a
  /// shape it has not got — and the box tops out at 640 so the shelf's column
  /// beside it stays the taller one.
  Widget _stage(BuildContext context) {
    final aspect = _aspectRatio > 0 ? _aspectRatio : 9 / 16;
    final shaped = aspect < 1 ? math.max(aspect, 9 / 16) : aspect;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 640),
      child: _playerSurface(context, immersive: false, aspectRatio: shaped),
    );
  }

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
    final total = meta.episodeCount > 0 ? meta.episodeCount : detail.episodes.length;
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
    final next = _nextEpisode();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Text(meta.title, style: theme.typography.title.copyWith(color: colors.text)),
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
                            episodeCount: total,
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
              leading: const GlyphIcon(PlayerGlyph.share, size: 16),
              onPressed: () => unawaited(_shareSeries()),
              child: Text(t.hongguo.share),
            ),
          ],
        ),
        if (meta.intro.isNotEmpty)
          Text(
            meta.intro,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.body.copyWith(color: colors.textMuted),
          ),
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

  /// The watch head's download button: idle it asks the queue, moving it
  /// reports the percent, paused it resumes, done it stands down.
  Widget _downloadButton(BuildContext context, HongguoEpisode episode) {
    final t = context.t;
    final task = hongguoDownloadOf(ref.watch(hongguoDownloadsProvider), episode.vid);
    final label = switch (task?.phase) {
      HongguoDownloadPhase.queued => t.hongguo.downloadQueuedLabel,
      HongguoDownloadPhase.running => '${task!.total > 0 ? task.received * 100 ~/ task.total : 0}%',
      HongguoDownloadPhase.paused => t.hongguo.downloadResume,
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
        showDsToast(context: context, title: t.hongguo.downloadQueued, status: DsStatus.success);
      case HongguoDownloadEnqueue.duplicate:
        showDsToast(context: context, title: t.hongguo.downloadDuplicate);
      case HongguoDownloadEnqueue.failed:
        showDsToast(
          context: context,
          title: t.hongguo.downloadFailed,
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
  /// out. Drawn over the page's stage and over the immersive picture alike.
  Widget _actionRail(Translations t, HongguoSeriesDetail detail) {
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
                selected: true,
                onPressed: () => unawaited(_openEpisode(next)),
              ),
            if (episode != null)
              _RailAction(
                icon: DsIcons.thumbsUp,
                label: t.hongguo.likes,
                count: episode.diggedCount > 0 ? AudienceFormat.format(episode.diggedCount) : null,
                onPressed: () => showDsToast(context: context, title: t.hongguo.likesReadonly),
              ),
            _RailAction(
              icon: DsIcons.star,
              glyph: const GlyphIcon(PlayerGlyph.star, size: 20, color: playerInk),
              label: favored ? t.hongguo.favorited : t.hongguo.favorite,
              count: meta.followedCount > 0 ? AudienceFormat.format(meta.followedCount) : null,
              selected: favored,
              onPressed: () => _toggleSeriesFavorite(detail),
            ),
            if (episode != null)
              _RailAction(
                icon: DsIcons.messageCircle,
                label: t.hongguo.comments,
                count: episode.commentCount > 0 ? AudienceFormat.format(episode.commentCount) : null,
                onPressed: _openComments,
              ),
            _RailAction(icon: DsIcons.share, glyph: const GlyphIcon(PlayerGlyph.share, size: 20, color: playerInk), label: t.hongguo.share, onPressed: () => unawaited(_shareSeries())),
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
      showDsPanel<void>(
        context: context,
        builder: (context) => DsPanel(
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
  Widget _playerSurface(BuildContext context, {required bool immersive, double? aspectRatio}) {
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
    _syncScreenWake(playing && ref.watch(keepScreenOnProvider));
    final showBar = _controlsVisible || !playing || _error != null;
    final ladder = _lastLadder;
    final attempted = _attempted;
    final lower = ladder != null && attempted != null
        ? hongguoLowerRendition(ladder, attempted, settings.quality.maxHeight, learnedFailures: lessons)
        : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(immersive ? 0 : theme.radii.overlay),
      child: ColoredBox(
        color: colors.overlay,
        child: AspectRatio(
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
                  const ColoredBox(color: Color(0xFF000000)),
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
                          const DsIcon(DsIcons.headphones, size: 32, color: playerInkSubtle),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Text(
                              _episode?.title ?? _detail?.meta.title ?? '',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.title.copyWith(color: playerInk),
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
                    if (signal is PointerScrollEvent) _wheelVolume(signal.scrollDelta.dy);
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggleControls,
                    onDoubleTap: handle == null
                        ? null
                        : () {
                            _wake();
                            unawaited(_togglePlay());
                          },
                    onLongPressStart: handle == null ? null : (_) => _beginHold(),
                    onLongPressMoveUpdate: handle == null ? null : (details) => _holdMoved(details.offsetFromOrigin.dy),
                    onLongPressEnd: handle == null ? null : (_) => _endHold(),
                    onLongPressCancel: handle == null ? null : _endHold,
                    onVerticalDragStart: handle == null ? null : (_) => _swipeDy = 0,
                    onVerticalDragUpdate: handle == null ? null : (details) => _swipeDy += details.delta.dy,
                    onVerticalDragEnd: handle == null ? null : (details) => _endSwipe(details.primaryVelocity ?? 0),
                  ),
                ),
                if (immersive && showBar) PositionedDirectional(top: 0, start: 0, end: 0, child: _topStrip(t, detail)),
                // The stage's own corner cluster: the frame's capture, this
                // episode's download, and the rest of the picture's switches
                // gathered under one menu. Fullscreen rides the same cluster
                // on its top strip, where the way out already lives.
                if (!immersive && showBar && detail != null)
                  PositionedDirectional(top: DsSpace.s12, end: DsSpace.s12, child: _stageCornerActions(t, detail)),
                // A held press says what it is doing; the lock itself is
                // confirmed by a toast and the bar's speed reading.
                if (_holding)
                  PositionedDirectional(
                    // The strip is 8 of padding, one control and 20 below it;
                    // the stage's corner cluster is 12 of padding, one control
                    // and 12 more — both read from the tier, so a TV's taller
                    // controls do not cover this.
                    top: immersive && showBar
                        ? DsSpace.s8 + PlayerBarTier.controlSize(context) + DsSpace.s20
                        : showBar && detail != null
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
                              _speedLocked ? DsIcons.lock : DsIcons.fastForward,
                              size: theme.sizes.iconXs,
                              color: playerInk,
                            ),
                            Text(
                              _speedLocked ? t.hongguo.speedLocked : t.hongguo.speedHolding,
                              style: theme.typography.caption.copyWith(color: playerInk),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // The picture's own action column, over the page's stage and
                // the immersive picture alike: the next episode, the episode's
                // likes, the series' bookmark, its comments and the way to
                // hand it out. Like the bar, the column stands down while a
                // catalogue hangs over the picture or a hold is running.
                if (showBar && handle != null && detail != null && _openPanel == null && !_holding)
                  PositionedDirectional(
                    // Fullscreen hangs the column under the strip, clear of
                    // the way out's row; the stage centres it on the picture's
                    // own edge.
                    top: immersive ? DsSpace.s8 + PlayerBarTier.controlSize(context) + DsSpace.s20 : 0,
                    bottom: immersive ? null : 0,
                    end: immersive ? DsSpace.s8 : DsSpace.s12,
                    child: immersive ? _actionRail(t, detail) : Center(child: _actionRail(t, detail)),
                  ),
                if (_opening || (transport?.isBuffering ?? false))
                  const Center(child: DsSpinner(style: DsSpinnerStyle(size: 40))),
                // A failure that outlived the automatic recovery: what went
                // wrong, what the budget is doing, and the four ways out the
                // reference offers.
                if (_error != null)
                  Positioned.fill(
                    child: ColoredBox(
                      color: const Color(0x99000000),
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
                                        onPressed: () => unawaited(_toggleFullscreen()),
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
                if (showBar)
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
                else if (playing && handle != null)
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

  /// The strip over an immersive picture: the way out and what is playing.
  Widget _topStrip(Translations t, HongguoSeriesDetail? detail) {
    final theme = DsTheme.of(context);
    final episode = _episode;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s8, DsSpace.s8, DsSpace.s12, DsSpace.s20),
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
          PlayerGlassPill(
            child: PlayerBarButton(
              icon: DsIcons.minimize2,
              glyphBuilder: (_, color, size) => GlyphIcon(PlayerGlyph.fullscreenExit, size: size, color: color),
              label: t.hongguo.exitFullscreen,
              autofocus: true,
              onPressed: () => unawaited(_toggleFullscreen()),
            ),
          ),
          Expanded(
            child: Text(
              detail == null
                  ? ''
                  : episode == null
                  ? detail.meta.title
                  : '${detail.meta.title} · ${t.hongguo.episodeLabel(index: episode.index)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.title.copyWith(color: playerInk),
            ),
          ),
          // The stage's corner cluster rides the strip in fullscreen: the
          // capture, the download and the switches the bar no longer carries.
          if (detail != null) _stageCornerActions(t, detail),
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
    final task = episode == null ? null : hongguoDownloadOf(ref.watch(hongguoDownloadsProvider), episode.vid);
    final busy =
        task != null && (task.phase == HongguoDownloadPhase.running || task.phase == HongguoDownloadPhase.queued);
    final finished = task != null && task.phase == HongguoDownloadPhase.done;
    final downloadLabel = switch (task?.phase) {
      HongguoDownloadPhase.queued => t.hongguo.downloadQueuedLabel,
      HongguoDownloadPhase.running => '${task!.total > 0 ? task.received * 100 ~/ task.total : 0}%',
      HongguoDownloadPhase.paused => t.hongguo.downloadResume,
      HongguoDownloadPhase.done => t.hongguo.downloaded,
      HongguoDownloadPhase.failed || null => t.hongguo.download,
    };
    final fit = ref.watch(playbackSettingsProvider).fit;
    final danmaku = ref.watch(hongguoDanmakuSettingsProvider);
    final statsVisible = ref.watch(playerStatsVisibleProvider);
    final pipIn = handle != null && _presentationNotifier.pipAvailable;
    final presentation = ref.watch(roomPresentationProvider);
    final pipInMode = presentation == PresentationMode.pip;
    return MouseRegion(
      // Resting on the cluster holds the bar, the way resting on the bar does.
      onEnter: (_) => _hideTimer?.cancel(),
      onExit: (_) => _scheduleHide(),
      child: KeyedSubtree(
        key: _panelAnchors[_HongguoPanel.danmaku],
        child: KeyedSubtree(
          key: _panelAnchors[_HongguoPanel.sleep],
          child: KeyedSubtree(
            key: _panelAnchors[_HongguoPanel.fit],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: DsSpace.s8,
              children: [
                PlayerGlassPill(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (handle?.canCaptureScreenshot ?? false)
                        PlayerBarButton(
                          icon: DsIcons.camera,
                          label: t.room.screenshot,
                          onPressed: () {
                            _wake();
                            unawaited(_screenshot());
                          },
                        ),
                      if (episode != null)
                        PlayerBarButton(
                          icon: DsIcons.download,
                          label: downloadLabel,
                          onPressed: busy || finished
                              ? null
                              : () {
                                  _wake();
                                  unawaited(_startDownload());
                                },
                        ),
                    ],
                  ),
                ),
                PlayerGlassPill(
                  child: DsMenuAnchor(
                    controller: _moreMenu,
                    semanticLabel: t.common.more,
                    align: DsAlign.end,
                    items: [
                      DsMenuItem(
                        leading: const DsIcon(DsIcons.activity),
                        label: Text(t.room.statsToggle),
                        trailing: statsVisible ? const DsIcon(DsIcons.check, size: 16) : null,
                        onPressed: handle == null ? null : () => ref.read(playerStatsVisibleProvider.notifier).toggle(),
                      ),
                      DsMenuItem(
                        leading: const DsIcon(DsIcons.moon),
                        label: Text(_sleep.active ? '${t.hongguo.sleep} · ${_sleep.label(t)}' : t.hongguo.sleep),
                        onPressed: () => _showPanel(_HongguoPanel.sleep),
                      ),
                      DsMenuItem(
                        leading: const DsIcon(DsIcons.headphones),
                        label: Text(t.room.audioOnlyMode),
                        trailing: _audioOnly ? const DsIcon(DsIcons.check, size: 16) : null,
                        onPressed: handle == null
                            ? null
                            : () {
                                _wake();
                                unawaited(_toggleAudioOnly());
                              },
                      ),
                      if (pipIn)
                        DsMenuItem(
                          leading: DsIcon(pipInMode ? DsIcons.pictureInPictureExit : DsIcons.pictureInPicture),
                          label: Text(pipInMode ? t.room.pipOff : t.room.pipOn),
                          onPressed: () => unawaited(_togglePip()),
                        ),
                      DsMenuItem(
                        leading: const DsIcon(DsIcons.aspectRatio),
                        label: Text('${t.settings.fit} · ${fitLabels(t)[fit.index]}'),
                        onPressed: () => _showPanel(_HongguoPanel.fit),
                      ),
                      DsMenuItem(
                        leading: DsIcon(danmaku.enabled ? DsIcons.captions : DsIcons.captionsOff),
                        label: Text(danmaku.enabled ? t.hongguo.danmakuOn : t.hongguo.danmakuOff),
                        onPressed: () => _showPanel(_HongguoPanel.danmaku),
                      ),
                      DsMenuItem(
                        leading: DsIcon(_effectivelyMuted ? DsIcons.volumeOff : DsIcons.volume),
                        label: Text(_effectivelyMuted ? t.hongguo.unmute : t.hongguo.mute),
                        onPressed: handle == null
                            ? null
                            : () {
                                _wake();
                                unawaited(_setMuted(muted: !_effectivelyMuted));
                              },
                      ),
                    ],
                    builder: (context, anchor, _) => PlayerBarButton(
                      icon: DsIcons.ellipsisVertical,
                      glyphBuilder: (_, color, size) => GlyphIcon(PlayerGlyph.more, size: size, color: color),
                      label: t.common.more,
                      onPressed: () {
                        _wake();
                        anchor.toggle();
                      },
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

  /// The bar under the picture, the phone player's one row: the seek line,
  /// then transport and clock on the left, the episode's chips and the way
  /// into fullscreen on the right. The switches that left the bar — the
  /// statistics, the sleep timer, the audio mode, the compact window, the
  /// picture bar, the danmaku and the mute — live in the corner cluster's
  /// more menu instead.
  Widget _controlBar(BuildContext context, {required bool immersive}) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final handle = _handle;
    final transport = _transport;
    final playing = transport?.isPlaying ?? false;
    final duration = transport?.duration ?? Duration.zero;
    final position = _dragSeconds != null
        ? Duration(milliseconds: (_dragSeconds! * 1000).round())
        : transport?.position ?? Duration.zero;
    final timeStyle = theme.typography.numeric(theme.typography.caption.copyWith(color: playerInk));
    final speedLabel = _speed == _speed.roundToDouble() ? '${_speed.toInt()}x' : '${_speed}x';
    return Container(
      key: _barAnchor,
      padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s12, DsSpace.s8, DsSpace.s12, DsSpace.s8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.bottomCenter,
          end: AlignmentDirectional.topCenter,
          colors: [Color(0xD9000000), Color(0x00000000)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s4,
        children: [
          // The seek line, alone: the clock moved down into the row below.
          DsSlider(
            value: duration.inMilliseconds <= 0
                ? 0
                : position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble(),
            max: duration.inMilliseconds <= 0 ? 1 : duration.inMilliseconds.toDouble(),
            onChanged: duration.inMilliseconds <= 0 ? null : (value) => setState(() => _dragSeconds = value / 1000),
            onChangeEnd: duration.inMilliseconds <= 0
                ? null
                : (value) {
                    final seconds = value / 1000;
                    setState(() => _dragSeconds = null);
                    unawaited(_seekTo(seconds));
                  },
            semanticLabel: t.hongguo.progress,
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              // The row gives the chips' words up on a narrow stage — a
              // portrait picture leaves a phone's stage a few hundred wide —
              // and keeps one line, never wrapping.
              final compact = constraints.maxWidth < 480;
              return Row(
                spacing: PlayerBarTier.tvOf(context) ? DsSpace.s8 : DsSpace.s4,
                children: [
                  PlayerBarButton(
                    icon: playing ? DsIcons.pause : DsIcons.play,
                    label: playing ? t.hongguo.pause : t.hongguo.play,
                    focusNode: _playFocus,
                    onPressed: handle == null
                        ? null
                        : () {
                            _wake();
                            unawaited(_togglePlay());
                          },
                  ),
                  // The clock the row carries: where the episode is, and how
                  // long it runs — the bar's own reading of the seek line.
                  Text('${hongguoDurationText(position)} / ${hongguoDurationText(duration)}', style: timeStyle),
                  const Spacer(),
                  _pickerButton(
                    panel: _HongguoPanel.episodes,
                    icon: DsIcons.listVideo,
                    label: _episodesLabel(t),
                    semanticLabel: t.hongguo.episodes,
                    compact: compact,
                  ),
                  _pickerButton(
                    panel: _HongguoPanel.speed,
                    icon: DsIcons.timer,
                    label: speedLabel,
                    semanticLabel: t.hongguo.speed,
                    compact: compact,
                  ),
                  _pickerButton(
                    panel: _HongguoPanel.quality,
                    icon: DsIcons.gauge,
                    label: (_attempted?.quality ?? 0) > 0 ? '${_attempted!.quality}P' : t.hongguo.quality,
                    semanticLabel: t.hongguo.quality,
                    compact: compact,
                  ),
                  PlayerBarButton(
                    icon: immersive ? DsIcons.minimize2 : DsIcons.maximize2,
                    glyphBuilder: (_, color, size) =>
                        GlyphIcon(immersive ? PlayerGlyph.fullscreenExit : PlayerGlyph.fullscreenEnter, size: size, color: color),
                    label: immersive ? t.hongguo.exitFullscreen : t.hongguo.fullscreen,
                    onPressed: handle == null ? null : () => unawaited(_toggleFullscreen()),
                  ),
                ],
              );
            },
          ),
        ],
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
        child: TvFocusScale(
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
                height: theme.sizes.sm,
                padding: EdgeInsets.symmetric(horizontal: compact ? DsSpace.s6 : DsSpace.s8),
                decoration: DsBoxDecoration(
                  color: lit ? playerInkHover : null,
                  borderRadius: theme.radii.controlCorners(null, theme.sizes.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: DsSpace.s4,
                  children: [
                    DsIcon(icon, size: theme.sizes.iconSm, color: playerInkMuted),
                    if (!compact)
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: panel == _HongguoPanel.episodes ? 168 : 110),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.caption.copyWith(color: playerInk),
                        ),
                      ),
                    DsIcon(open ? DsIcons.chevronDown : DsIcons.chevronUp, size: 12, color: playerInkMuted),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// The width each catalogue asks for; the anchored host centres the card
  /// on its picker with this measure.
  static double _panelWidth(_HongguoPanel panel) => switch (panel) {
    _HongguoPanel.fit => 180,
    _HongguoPanel.sleep => 220,
    _HongguoPanel.speed => 180,
    _HongguoPanel.quality => 220,
    // Five numbered tiles to a row, as the reference's episode grid — a
    // series runs to a hundred and the tiles are what a viewer reads.
    _HongguoPanel.episodes => 300,
    _HongguoPanel.danmaku => 200,
  };

  /// The open picker's catalogue.
  Widget _panel(Translations t, _HongguoPanel panel) {
    switch (panel) {
      case _HongguoPanel.fit:
        final fit = ref.watch(playbackSettingsProvider).fit;
        return PlayerOverlayPanel(
          title: t.settings.fit,
          width: _panelWidth(panel),
          children: [
            // The same six the room and the video page list — a shortlist
            // here would make the app-wide ratio read as broken on this one
            // page.
            for (final mode in PlaybackFit.values)
              PlayerPanelOption(
                label: fitLabels(t)[mode.index],
                selected: mode == fit,
                onPressed: () {
                  _closePanel();
                  unawaited(ref.read(playbackSettingsProvider.notifier).setFit(mode));
                },
              ),
          ],
        );
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
          title: t.hongguo.speed,
          width: _panelWidth(panel),
          children: [
            for (final speed in const <double>[0.5, 0.75, 1, 1.25, 1.5, 2])
              PlayerPanelOption(
                label: '${speed == speed.roundToDouble() ? speed.toInt() : speed}x',
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
          title: t.hongguo.quality,
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
        const sizes = <double>[16, 20, 24, 28, 32];
        const speeds = <double>[0.5, 1, 1.5, 2];
        const densities = HongguoDanmakuDensity.values;
        String speedText(double speed) => '${speed == speed.roundToDouble() ? speed.toInt() : speed}x';
        return PlayerOverlayPanel(
          title: t.hongguo.danmaku,
          width: _panelWidth(panel),
          children: [
            // A tap walks the value on, as the reference's own panel does,
            // so the picture stays visible while the look is tuned.
            PlayerPanelOption(
              label: danmaku.enabled ? t.hongguo.danmakuOn : t.hongguo.danmakuOff,
              selected: danmaku.enabled,
              onPressed: () => unawaited(controller.setEnabled(value: !danmaku.enabled)),
            ),
            PlayerPanelOption(
              label: '${t.hongguo.danmakuFontSize} · ${danmaku.fontSize.round()}',
              selected: false,
              onPressed: () {
                final index = sizes.indexOf(danmaku.fontSize);
                unawaited(controller.setFontSize(sizes[(index < 0 ? 1 : index + 1) % sizes.length]));
              },
            ),
            PlayerPanelOption(
              label: '${t.hongguo.danmakuDensity} · ${danmaku.density.label(t)}',
              selected: false,
              onPressed: () => unawaited(
                controller.setDensity(densities[(densities.indexOf(danmaku.density) + 1) % densities.length]),
              ),
            ),
            PlayerPanelOption(
              label: '${t.hongguo.danmakuSpeed} · ${speedText(danmaku.speed)}',
              selected: false,
              onPressed: () {
                final index = speeds.indexOf(danmaku.speed);
                unawaited(controller.setSpeed(speeds[(index < 0 ? 1 : index + 1) % speeds.length]));
              },
            ),
          ],
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
        if (groups > 1)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s12, 0, DsSpace.s12, DsSpace.s8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: DsSpace.s6,
                children: [
                  for (var index = 0; index < groups; index++)
                    _panelPill(
                      label: _episodeRangeLabel(episodes, index),
                      selected: index == group,
                      onPressed: () => setState(() => _episodesGroup = index),
                    ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s12, 0, DsSpace.s12, DsSpace.s6),
          child: Wrap(
            spacing: DsSpace.s6,
            runSpacing: DsSpace.s6,
            children: [
              for (final episode in shown)
                _episodeTile(
                  t,
                  episode,
                  playing: episode.vid == current?.vid && episode.index == current?.index,
                  marks: marks,
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// One page of the series, named by the episode numbers it holds — `1–20`,
  /// and the short last one `81–102`.
  String _episodeRangeLabel(List<HongguoEpisode> episodes, int group) {
    final first = group * kHongguoEpisodeGroup;
    return '${first + 1}–${first + (episodes.length - first).clamp(0, kHongguoEpisodeGroup)}';
  }

  /// One numbered tile: lit white while it plays, ticked once it is finished,
  /// and marked where the viewer stopped part-way.
  Widget _episodeTile(
    Translations t,
    HongguoEpisode episode, {
    required bool playing,
    required ({int watchedThrough, int? resumeAt}) marks,
  }) {
    final theme = DsTheme.of(context);
    final height = theme.sizes.xs;
    // The number is what the grid shows, as the shelf under the picture shows
    // it; where the source names the episode, the name still reads out.
    final label = t.hongguo.episodeLabel(index: episode.index);
    return DsPressable(
      semanticLabel: episode.title.isEmpty ? label : '$label ${episode.title}',
      onPressed: () {
        _closePanel();
        unawaited(_openEpisode(episode));
      },
      builder: (context, states, _) {
        final lit = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
        final resume = !playing && episode.index == marks.resumeAt;
        final watched = !playing && !resume && episode.index <= marks.watchedThrough;
        // The dark the card itself is cut from, for the words on a lit tile.
        final ink = playing
            ? const Color(0xFF131519)
            : watched
            ? playerInkSubtle
            : playerInkMuted;
        return Container(
          height: height,
          width: height + 20,
          alignment: Alignment.center,
          decoration: DsBoxDecoration(
            color: playing
                ? playerInk
                : lit
                ? playerInkHover
                : const Color(0x1FFFFFFF),
            borderRadius: theme.radii.controlCorners(null, height),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 2,
            children: [
              if (resume)
                DsIcon(DsIcons.play, size: 10, color: ink)
              else if (watched)
                DsIcon(DsIcons.check, size: 10, color: ink),
              Text(
                '${episode.index}',
                style: theme.typography.numeric(
                  theme.typography.caption.copyWith(color: ink, fontWeight: playing ? FontWeight.w600 : null),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// One small ink control inside a picker panel. The panels' rows are
  /// [PlayerPanelOption]s and their tiles are numbered boxes; a range button
  /// is neither, but it carries the same white-on-dark the card is drawn in.
  Widget _panelPill({required String label, required bool selected, required VoidCallback onPressed}) {
    final theme = DsTheme.of(context);
    return DsPressable(
      semanticLabel: label,
      onPressed: onPressed,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
        return Container(
          height: theme.sizes.xs,
          padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s8, 0, DsSpace.s8, 0),
          alignment: Alignment.center,
          decoration: DsBoxDecoration(
            color: selected
                ? playerInkHover
                : hovered
                ? const Color(0x14FFFFFF)
                : null,
            borderRadius: theme.radii.controlCorners(null, theme.sizes.xs),
          ),
          child: Text(
            label,
            style: theme.typography.numeric(
              theme.typography.caption.copyWith(
                color: selected ? playerInk : playerInkSubtle,
                fontWeight: selected ? FontWeight.w600 : null,
              ),
            ),
          ),
        );
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

  void _scheduleHide() {
    _hideTimer?.cancel();
    // An open catalogue holds the bar up; a paused stream keeps it too.
    if (_openPanel != null || !(_transport?.isPlaying ?? false)) return;
    final seconds = ref.read(playbackSettingsProvider).controlsAutoHideSeconds;
    _hideTimer = Timer(Duration(seconds: seconds), () {
      if (mounted && (_transport?.isPlaying ?? false) && _openPanel == null) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  /// The more menu's own hold on the bar: open, it cancels the hide; closed,
  /// the bar settles as after any other gesture.
  void _onMoreMenuChanged() {
    if (!mounted) return;
    if (_moreMenu.isOpen) {
      _hideTimer?.cancel();
    } else {
      _scheduleHide();
    }
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

/// One action on the picture's own column: a glass disc over the video, and
/// the count the phone prints under it.
final class _RailAction extends StatelessWidget {
  const _RailAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.count,
    this.selected = false,
    this.glyph,
  });

  /// The glyph in the disc.
  final DsIconData icon;

  /// A picture glyph drawn instead of [icon] when set.
  final Widget? glyph;

  /// The action's name, for the tooltip and screen readers.
  final String label;

  /// What the action does.
  final VoidCallback onPressed;

  /// The figure under the disc, when the platform has one.
  final String? count;

  /// Whether the action draws in the accent colour: a state that is on, as a
  /// favorite is — or, for the column's one strong verb (the next episode),
  /// the accent outright.
  final bool selected;

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
                decoration: DsBoxDecoration(
                  color: selected
                      ? colors.accent
                      : lit
                      ? playerInkHover
                      : const Color(0x66000000),
                  borderRadius: BorderRadius.circular(theme.radii.control(38)),
                ),
                child: glyph ?? DsIcon(icon, size: theme.sizes.iconLg, color: selected ? colors.onAccent : playerInk),
              ),
              if (count case final figure?)
                Text(
                  figure,
                  style: theme.typography.numeric(theme.typography.caption.copyWith(color: playerInk, fontSize: 11)),
                ),
            ],
          );
        },
      ),
    );
  }
}
