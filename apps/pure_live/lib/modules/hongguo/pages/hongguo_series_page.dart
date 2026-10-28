import 'dart:async' show StreamSubscription, Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart' show AppBar, Scaffold;
import 'package:flutter/services.dart' show FilteringTextInputFormatter, LogicalKeyboardKey, TextInputType;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_device/live_device.dart' show PlatformScreenOrientationService, ScreenOrientationService;
import 'package:media_core/media_core.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_account_state.dart'
    show
        hongguoAccountClientProvider,
        hongguoAccountFavoritesProvider,
        hongguoAccountProvider,
        hongguoReservationsProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_client.dart'
    show
        hongguoClientProvider,
        hongguoFailureText,
        hongguoLowerRendition,
        hongguoPickRendition,
        hongguoStreamProxyProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_comfort.dart'
    show HongguoRecoveryBudget, HongguoSleepTimer;
import 'package:pure_live/modules/hongguo/controller/hongguo_danmaku.dart' show hongguoDanmakuSettingsProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_decoder.dart' show hongguoDecoderLessonsProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_library.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_settings.dart'
    show HongguoQualityChoice, hongguoSettingsProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_social.dart'
    show
        hongguoCommentsProvider,
        hongguoDanmakuProvider,
        hongguoPublicReviewsProvider,
        hongguoRelatedClientProvider,
        hongguoRelatedProvider;
import 'package:pure_live/modules/hongguo/official/hongguo_account.dart' show HongguoAccountClient, HongguoCredentials;
import 'package:pure_live/modules/hongguo/official/hongguo_official.dart' show HongguoRendition;
import 'package:pure_live/modules/hongguo/official/hongguo_public_reviews.dart' show HongguoPublicReview;
import 'package:pure_live/modules/hongguo/official/hongguo_related.dart' show HongguoRelatedWork;
import 'package:pure_live/modules/hongguo/widgets/hongguo_danmaku_layer.dart' show HongguoDanmakuLayer;
import 'package:pure_live/modules/hongguo/widgets/hongguo_widgets.dart' show HongguoSeriesRow, hongguoDurationText;
import 'package:pure_live/shared/shared.dart';

/// The episodes one group of the shelf lists before the pager takes over —
/// the reference's twenty.
const int _kEpisodeGroup = 20;

/// One series' page: the player over media_core, the episodes as numbered
/// tiles, and the series' own metadata — the station's series page, reduced
/// to what the companion service provides.
///
/// Playback is one shared media_core handle fed the service's decrypted,
/// rangeable mp4. Progress is saved per series (episode + seconds) so a
/// return resumes where it stopped, and a finished episode leads to the
/// next one on its own.
final class HongguoSeriesPage extends ConsumerStatefulWidget {
  /// The series behind [seriesId].
  const HongguoSeriesPage({required this.seriesId, super.key});

  /// The series' id.
  final String seriesId;

  @override
  ConsumerState<HongguoSeriesPage> createState() => _HongguoSeriesPageState();
}

final class _HongguoSeriesPageState extends ConsumerState<HongguoSeriesPage> with RouteAware, WidgetsBindingObserver {
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
  bool _loading = true;
  bool _opening = false;
  bool _disposed = false;
  bool _finished = false;
  bool _introExpanded = false;
  String? _error;
  double? _dragSeconds;
  double? _resumeSeconds;
  bool _muted = false;
  bool _globalMute = false;
  double _volume = 1;
  double _speed = 1;

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

  /// Which group of [_kEpisodeGroup] episodes the shelf lists.
  int _episodeGroup = 0;

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
    ref.listenManual(roomPresentationProvider, (_, next) => _presentationMode = next, fireImmediately: true);
    WidgetsBinding.instance.addObserver(this);
    _globalMute = ref.read(playbackSettingsProvider).globalMute;
    _volume = ref.read(playbackSettingsProvider.notifier).volume;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
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
      unawaited(handle.pause());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _routeObserver?.unsubscribe(this);
    _saveProgress(force: true);
    _disposed = true;
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
    ref.read(hongguoDanmakuProvider.notifier).stop();
    final handle = _handle;
    if (handle != null) {
      if (_presentationMode != PresentationMode.normal) {
        unawaited(_presentationNotifier.exit(handle.id));
      }
      unawaited(_kernel.release(handle.id));
    }
    _playFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _stopWaiting();
    setState(() {
      _loading = true;
      _error = null;
      _transport = null;
      _resumeSeconds = null;
    });
    try {
      final detail = await ref.read(hongguoClientProvider).detail(widget.seriesId);
      if (!mounted || _disposed) return;
      // Opening the series is the shelf's acknowledgement: the `新增 N 集`
      // line on the card stops at what was read.
      _library.acknowledgeUpdates(widget.seriesId);
      setState(() {
        _detail = detail;
        _loading = false;
      });
      final episodes = detail.episodes;
      if (episodes.isEmpty) return;
      final resume = _readProgress();
      final start = episodes.firstWhere((episode) => episode.index == resume?.index, orElse: () => episodes.first);
      await _openEpisode(start, resume: resume?.seconds);
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
      _episodeGroup = _groupOf(episode);
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
        if (existing == null) unawaited(_kernel.release(handle.id));
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

  Future<void> _setSpeed(double speed) async {
    final handle = _handle;
    if (handle == null) return;
    setState(() => _speed = speed);
    try {
      await handle.setRate(speed);
    } on Object catch (_) {
      // Same as mute.
    }
  }

  /// The engine options this page keeps for every episode and handle:
  /// hardware decoding and the stored outputs. The player proxy is left out —
  /// the stream is always the companion service on this machine, and a proxy
  /// client asked for a loopback address usually refuses the connection.
  List<EngineOption> _storedEngineOptions() => playerStoredEngineOptions(
    hardwareDecoding: ref.read(playbackSettingsProvider).hardwareDecoding,
    tuning: ref.read(playerTuningProvider),
    proxy: (mode: PlayerProxyMode.off, host: '', port: kDefaultPlayerProxyPort),
  );

  Future<void> _applyEngineOptions(PlayerHandle handle, {List<EngineOption> extra = const []}) async {
    try {
      final options = <EngineOption>[
        ...await withSuperResolution(_storedEngineOptions(), ref.read(superResolutionModeProvider)),
        ...extra,
      ];
      await handle.applyEngineOptions(options);
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
    ref.listen(effectivePlayerProxyProvider, (previous, next) {
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
    ref.listen(superResolutionModeProvider, (previous, next) {
      if (previous == next) return;
      final handle = _handle;
      if (handle != null) unawaited(applySuperResolution(handle, next));
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
      applyFullscreenOrientation(
        _screenOrientation,
        policy: ref.read(portraitSettingsProvider).fullscreenPolicy,
        aspectRatio: _aspectRatio,
      );
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
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): _togglePlay,
        const SingleActivator(LogicalKeyboardKey.keyF): _toggleFullscreen,
        const SingleActivator(LogicalKeyboardKey.escape): _leave,
      },
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          backgroundColor: colors.surface,
          surfaceTintColor: const Color(0x00000000),
          elevation: 0,
          title: Text(detail?.meta.title ?? t.hongguo.opening, maxLines: 1, overflow: TextOverflow.ellipsis),
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
            : _body(context, detail, t),
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

  Widget _body(BuildContext context, HongguoSeriesDetail? detail, Translations t) {
    if (detail == null) return const SizedBox.shrink();
    final player = _playerSurface(context, immersive: false);
    final info = _info(context, detail, t);
    final reviews = _SeriesReviewsSection(seriesId: widget.seriesId, episodeVid: _episode?.vid ?? '');
    final episodes = _episodes(context, detail, t);
    final related = _RelatedSection(seriesId: widget.seriesId);
    final comments = _CommentsSection(seriesId: widget.seriesId, episodeVid: _episode?.vid ?? '');
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1000;
        if (!wide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s16,
              children: [player, episodes, info, reviews, related, comments],
            ),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(DsSpace.s24, DsSpace.s12, DsSpace.s24, DsSpace.s24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: DsSpace.s16,
                  children: [player, info, reviews, related, comments],
                ),
              ),
            ),
            SizedBox(
              width: 320,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(0, DsSpace.s12, DsSpace.s24, DsSpace.s24),
                child: episodes,
              ),
            ),
          ],
        );
      },
    );
  }

  /// The picture and its controls; [immersive] adds the way out and the
  /// title over the picture, since the page's app bar is gone there.
  Widget _playerSurface(BuildContext context, {required bool immersive}) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final handle = _handle;
    final transport = _transport;
    final detail = _detail;
    final settings = ref.watch(hongguoSettingsProvider);
    // The picture mode is the app's own player setting — one entry for every
    // player — and the bar's menu writes it rather than a module copy.
    final fit = ref.watch(playbackSettingsProvider).fit;
    final lessons = ref.watch(hongguoDecoderLessonsProvider);
    final danmaku = ref.watch(hongguoDanmakuSettingsProvider);
    final danmakuItems = ref.watch(hongguoDanmakuProvider).items;
    final duration = transport?.duration ?? Duration.zero;
    final position = _dragSeconds != null
        ? Duration(milliseconds: (_dragSeconds! * 1000).round())
        : transport?.position ?? Duration.zero;
    final playing = transport?.isPlaying ?? false;
    final next = _nextEpisode();
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
          aspectRatio: _aspectRatio > 0 ? _aspectRatio : 16 / 9,
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
              if (immersive)
                PositionedDirectional(
                  top: 0,
                  start: 0,
                  end: 0,
                  child: Container(
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
                        _PlayerIconButton(
                          icon: DsIcons.minimize2,
                          label: t.hongguo.exitFullscreen,
                          onPressed: () => unawaited(_toggleFullscreen()),
                          onDark: true,
                          autofocus: true,
                        ),
                        Expanded(
                          child: Text(
                            detail?.meta.title ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.title.copyWith(color: const Color(0xFFFFFFFF)),
                          ),
                        ),
                      ],
                    ),
                  ),
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
              PositionedDirectional(
                bottom: 0,
                start: 0,
                end: 0,
                child: Container(
                  padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s8, DsSpace.s24, DsSpace.s8, DsSpace.s4),
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
                      // The reference's HUD line: the rendition in play, the
                      // speed, and the sleep timer when one runs.
                      Row(
                        children: [
                          const Spacer(),
                          Text(
                            [
                              if ((_attempted?.quality ?? 0) > 0) '${_attempted!.quality}P',
                              '${_speed == _speed.roundToDouble() ? _speed.toInt() : _speed}x',
                              if (_sleep.active) _sleep.label(t),
                            ].join(' · '),
                            style: theme.typography.numeric(
                              theme.typography.caption.copyWith(color: const Color(0xB3FFFFFF)),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        spacing: DsSpace.s8,
                        children: [
                          SizedBox(
                            width: 54,
                            child: Text(
                              hongguoDurationText(position),
                              textAlign: TextAlign.center,
                              style: theme.typography.numeric(
                                theme.typography.caption.copyWith(color: const Color(0xFFFFFFFF)),
                              ),
                            ),
                          ),
                          Expanded(
                            child: DsSlider(
                              value: duration.inMilliseconds <= 0
                                  ? 0
                                  : position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble(),
                              max: duration.inMilliseconds <= 0 ? 1 : duration.inMilliseconds.toDouble(),
                              onChanged: duration.inMilliseconds <= 0
                                  ? null
                                  : (value) => setState(() => _dragSeconds = value / 1000),
                              onChangeEnd: duration.inMilliseconds <= 0
                                  ? null
                                  : (value) {
                                      final seconds = value / 1000;
                                      setState(() => _dragSeconds = null);
                                      unawaited(_seekTo(seconds));
                                    },
                              semanticLabel: t.hongguo.progress,
                            ),
                          ),
                          SizedBox(
                            width: 54,
                            child: Text(
                              hongguoDurationText(duration),
                              textAlign: TextAlign.center,
                              style: theme.typography.numeric(
                                theme.typography.caption.copyWith(color: const Color(0xFFFFFFFF)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 560;
                          return Row(
                            spacing: DsSpace.s4,
                            children: [
                              _PlayerIconButton(
                                icon: playing ? DsIcons.pause : DsIcons.play,
                                label: playing ? t.hongguo.pause : t.hongguo.play,
                                onPressed: handle == null ? null : () => unawaited(_togglePlay()),
                                focusNode: _playFocus,
                                onDark: true,
                              ),
                              _PlayerIconButton(
                                icon: _effectivelyMuted ? DsIcons.volumeOff : DsIcons.volume,
                                label: _effectivelyMuted ? t.hongguo.unmute : t.hongguo.mute,
                                onPressed: handle == null
                                    ? null
                                    : () => unawaited(_setMuted(muted: !_effectivelyMuted)),
                                onDark: true,
                              ),
                              if (!compact)
                                SizedBox(
                                  width: 100,
                                  child: DsSlider(
                                    value: _effectivelyMuted ? 0 : _volume,
                                    onChanged: handle == null ? null : (value) => unawaited(_setVolume(value)),
                                    semanticLabel: t.hongguo.volume,
                                  ),
                                ),
                              _PlayerIconButton(
                                icon: danmaku.enabled ? DsIcons.captions : DsIcons.captionsOff,
                                label: danmaku.enabled ? t.hongguo.danmakuOn : t.hongguo.danmakuOff,
                                onPressed: () => unawaited(
                                  ref.read(hongguoDanmakuSettingsProvider.notifier).setEnabled(value: !danmaku.enabled),
                                ),
                                onDark: true,
                              ),
                              const Spacer(),
                              if (next != null)
                                _PlayerIconButton(
                                  icon: DsIcons.skipForward,
                                  label: t.hongguo.nextEpisode,
                                  onPressed: () => unawaited(_openEpisode(next)),
                                  onDark: true,
                                ),
                              _PlayerMenu(
                                label: fitLabels(t)[fit.index],
                                icon: DsIcons.aspectRatio,
                                semanticLabel: t.settings.fit,
                                compact: compact,
                                items: [
                                  for (final mode in const [PlaybackFit.contain, PlaybackFit.cover, PlaybackFit.fill])
                                    DsMenuItem(
                                      label: Text(fitLabels(t)[mode.index]),
                                      checked: mode == fit,
                                      onPressed: () =>
                                          unawaited(ref.read(playbackSettingsProvider.notifier).setFit(mode)),
                                    ),
                                ],
                              ),
                              _PlayerMenu(
                                label: _sleep.label(t),
                                icon: DsIcons.moon,
                                semanticLabel: t.hongguo.sleep,
                                compact: compact,
                                items: [
                                  DsMenuItem(
                                    label: Text(t.hongguo.sleepOff),
                                    checked: !_sleep.active,
                                    onPressed: _setSleep,
                                  ),
                                  for (final minutes in const [15, 30, 60, 90])
                                    DsMenuItem(
                                      label: Text(t.hongguo.sleepAfter(minutes: minutes)),
                                      checked:
                                          _sleep.remaining != null &&
                                          (_sleep.remaining!.inMinutes - minutes).abs() <= 1,
                                      onPressed: () => _setSleep(minutes: minutes),
                                    ),
                                  DsMenuItem(
                                    label: Text(t.hongguo.sleepThisEpisode),
                                    checked: _sleep.episodesLeft == 1,
                                    onPressed: () => _setSleep(episodes: 1),
                                  ),
                                  for (final count in const [3, 5])
                                    DsMenuItem(
                                      label: Text(t.hongguo.sleepAfterEpisodes(count: count)),
                                      checked: _sleep.episodesLeft == count,
                                      onPressed: () => _setSleep(episodes: count),
                                    ),
                                ],
                              ),
                              _PlayerMenu(
                                label: '${_speed == _speed.roundToDouble() ? _speed.toInt() : _speed}x',
                                icon: DsIcons.gauge,
                                semanticLabel: t.hongguo.speed,
                                compact: compact,
                                items: [
                                  for (final speed in const <double>[0.5, 0.75, 1, 1.25, 1.5, 2])
                                    DsMenuItem(
                                      label: Text('${speed == speed.roundToDouble() ? speed.toInt() : speed}x'),
                                      checked: speed == _speed,
                                      onPressed: () => unawaited(_setSpeed(speed)),
                                    ),
                                ],
                              ),
                              _PlayerIconButton(
                                icon: DsIcons.maximize2,
                                label: t.hongguo.fullscreen,
                                onPressed: handle == null ? null : () => unawaited(_toggleFullscreen()),
                                onDark: true,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

  /// The episodes as numbered tiles, twenty at a time — the reference's
  /// groups — with the one playing lit, the last one watched marked and the
  /// ones behind it checked. A group with more than twenty offers the
  /// pager and the jump box.
  Widget _episodes(BuildContext context, HongguoSeriesDetail detail, Translations t) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final current = _episode;
    final episodes = detail.episodes;
    final groups = (episodes.length + _kEpisodeGroup - 1) ~/ _kEpisodeGroup;
    final group = _episodeGroup.clamp(0, groups <= 0 ? 0 : groups - 1);
    final first = group * _kEpisodeGroup;
    final shown = episodes.skip(first).take(_kEpisodeGroup).toList();
    final last = first + shown.length;
    final progress = ref.watch(hongguoLibraryProvider).progressOf(detail.meta.seriesId);
    final watchedThrough = progress == null
        ? 0
        : progress.completed
        ? progress.episodeIndex
        : progress.episodeIndex - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Row(
          spacing: DsSpace.s8,
          children: [
            Expanded(
              child: Text(t.hongguo.episodes, style: theme.typography.title.copyWith(color: colors.text)),
            ),
            if (groups > 1) ...[
              Text(
                '$first–$last / ${episodes.length}',
                style: theme.typography.caption.copyWith(color: colors.textMuted),
              ),
              DsButton.icon(
                icon: const DsIcon(DsIcons.chevronLeft),
                semanticLabel: t.hongguo.episodesPrevious,
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                onPressed: group > 0 ? () => setState(() => _episodeGroup = group - 1) : null,
              ),
              DsButton.icon(
                icon: const DsIcon(DsIcons.chevronRight),
                semanticLabel: t.hongguo.episodesNext,
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                onPressed: group < groups - 1 ? () => setState(() => _episodeGroup = group + 1) : null,
              ),
              DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                leading: const DsIcon(DsIcons.listOrdered, size: 16),
                onPressed: () => unawaited(_jumpToEpisode(detail)),
                child: Text(t.hongguo.episodesJump),
              ),
            ],
          ],
        ),
        Wrap(
          spacing: DsSpace.s8,
          runSpacing: DsSpace.s8,
          children: [
            for (final episode in shown)
              DsChip(
                leading: episode.vid == current?.vid && episode.index == current?.index
                    ? null
                    : episode.index == progress?.episodeIndex && !(progress?.completed ?? false)
                    ? const DsIcon(DsIcons.play, size: 12)
                    : episode.index <= watchedThrough
                    ? const DsIcon(DsIcons.check, size: 12)
                    : null,
                label: Text('${episode.index}'),
                selected: episode.vid == current?.vid && episode.index == current?.index,
                onChanged: episode.vid == current?.vid && episode.index == current?.index
                    ? null
                    : (_) => unawaited(_openEpisode(episode)),
                semanticLabel: t.hongguo.episodeLabel(index: episode.index),
              ),
          ],
        ),
      ],
    );
  }

  /// The group [episode] sits in, by its place in the loaded list.
  int _groupOf(HongguoEpisode episode) {
    final episodes = _detail?.episodes ?? const <HongguoEpisode>[];
    final position = episodes.indexWhere((row) => row.vid == episode.vid);
    return position < 0 ? 0 : position ~/ _kEpisodeGroup;
  }

  /// Asks for an episode number and opens it; an empty or unknown answer
  /// leaves the page where it was.
  Future<void> _jumpToEpisode(HongguoSeriesDetail detail) async {
    final episodes = detail.episodes;
    if (episodes.isEmpty) return;
    final controller = TextEditingController();
    int? parse() {
      final typed = int.tryParse(controller.text.trim());
      if (typed == null) return null;
      final byIndex = episodes.where((episode) => episode.index == typed);
      if (byIndex.isNotEmpty) return episodes.indexOf(byIndex.first);
      return typed >= 1 && typed <= episodes.length ? typed - 1 : null;
    }

    final position = await showDsDialog<int>(
      context: context,
      builder: (dialogContext) {
        final t = dialogContext.t;
        return DsDialog(
          title: Text(t.hongguo.episodesJump),
          description: DsTextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            placeholder: '1–${episodes.length}',
            onSubmitted: (_) => Navigator.of(dialogContext).pop(parse()),
          ),
          actions: [
            DsButton(
              variant: DsButtonVariant.ghost,
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(t.common.cancel),
            ),
            DsButton(onPressed: () => Navigator.of(dialogContext).pop(parse()), child: Text(t.common.confirm)),
          ],
        );
      },
    );
    controller.dispose();
    if (position == null || !mounted || _disposed) return;
    await _openEpisode(episodes[position]);
  }

  /// The series' own metadata: the status and figures, the shelf
  /// categories, and the story blurb with its way to read all of it.
  Widget _info(BuildContext context, HongguoSeriesDetail detail, Translations t) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final meta = detail.meta;
    final figures = <String>[
      if (meta.statusText.isNotEmpty) meta.statusText,
      if (meta.playCount > 0) '${t.hongguo.plays} ${AudienceFormat.format(meta.playCount)}',
      if (meta.followedCount > 0) '${t.hongguo.followers} ${AudienceFormat.format(meta.followedCount)}',
      if (meta.episodeCount > 0) t.hongguo.episodesCount(count: meta.episodeCount),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Text(meta.title, style: theme.typography.title.copyWith(color: colors.text)),
        if (figures.isNotEmpty)
          Text(figures.join(' · '), style: theme.typography.caption.copyWith(color: colors.textMuted)),
        if (meta.categories.isNotEmpty)
          Wrap(
            spacing: DsSpace.s8,
            runSpacing: DsSpace.s8,
            children: [for (final category in meta.categories) DsBadge(label: Text(category), dot: false)],
          ),
        Consumer(
          builder: (context, ref, _) {
            final t = context.t;
            final library = ref.watch(hongguoLibraryProvider);
            final account = ref.watch(hongguoAccountProvider);
            final snapshot = HongguoSeries(
              seriesId: meta.seriesId,
              title: meta.title,
              cover: meta.cover,
              intro: meta.intro,
              episodeCount: meta.episodeCount,
            );
            final favored = library.isFavorite(meta.seriesId);
            return Wrap(
              spacing: DsSpace.s8,
              runSpacing: DsSpace.s8,
              children: [
                DsButton(
                  variant: favored ? DsButtonVariant.primary : DsButtonVariant.secondary,
                  leading: DsIcon(favored ? DsIcons.heart : DsIcons.heartOff, size: 16),
                  onPressed: () {
                    final added = ref.read(hongguoLibraryProvider.notifier).toggleFavorite(snapshot);
                    showDsToast(
                      context: context,
                      title: added ? t.hongguo.favoriteToggleOn : t.hongguo.favoriteToggleOff,
                    );
                  },
                  child: Text(favored ? t.hongguo.favoriteToggleOff : t.hongguo.favoriteToggleOn),
                ),
                if (account.signedIn)
                  DsButton(
                    variant: DsButtonVariant.secondary,
                    leading: const DsIcon(DsIcons.cloudUpload, size: 16),
                    onPressed: () =>
                        unawaited(ref.read(hongguoAccountFavoritesProvider.notifier).setFavorite(snapshot, add: true)),
                    child: Text(t.hongguo.cloudFavoriteOn),
                  ),
              ],
            );
          },
        ),
        if (meta.intro.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: DsSpace.s4,
            children: [
              GestureDetector(
                onTap: () => setState(() => _introExpanded = !_introExpanded),
                child: Text(
                  meta.intro,
                  maxLines: _introExpanded ? null : 3,
                  overflow: _introExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: theme.typography.body.copyWith(color: colors.textMuted),
                ),
              ),
              DsLink(
                label: _introExpanded ? t.hongguo.collapse : t.hongguo.expand,
                onPressed: () => setState(() => _introExpanded = !_introExpanded),
              ),
            ],
          ),
      ],
    );
  }
}

/// An icon button on the dark control bar.
final class _PlayerIconButton extends StatelessWidget {
  /// The button for [icon].
  const _PlayerIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.autofocus = false,
    this.onDark = false,
    this.focusNode,
  });

  /// The glyph.
  final DsIconData icon;

  /// The control's name, shown on hover and to semantics.
  final String label;

  /// Null disables the control.
  final VoidCallback? onPressed;

  /// Whether the keyboard lands here first.
  final bool autofocus;

  /// Whether the button sits on the picture's dark gradient.
  final bool onDark;

  /// The node the keyboard returns to after a presentation change.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final ink = onDark ? const Color(0xFFFFFFFF) : DsTheme.colorsOf(context).text;
    return DsTooltip(
      message: label,
      child: DsPressable(
        semanticLabel: label,
        onPressed: onPressed,
        autofocus: autofocus,
        focusNode: focusNode,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          return Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: DsBoxDecoration(
              color: hovered ? const Color(0x33FFFFFF) : null,
              borderRadius: BorderRadius.circular(theme.radii.control(36)),
            ),
            child: DsIcon(icon, size: 18, color: onPressed == null ? const Color(0x66FFFFFF) : ink),
          );
        },
      ),
    );
  }
}

/// A labelled menu over the picture: the current choice and a chevron, or
/// just the icon where the bar is too narrow for labels.
final class _PlayerMenu extends StatelessWidget {
  /// The menu for [items].
  const _PlayerMenu({
    required this.label,
    required this.icon,
    required this.semanticLabel,
    required this.items,
    this.compact = false,
  });

  /// The menu's own label.
  final String label;

  /// The glyph beside it.
  final DsIconData icon;

  /// The menu's name, for semantics.
  final String semanticLabel;

  /// The menu's entries.
  final List<Widget> items;

  /// Whether the bar is too narrow for the label.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return DsMenuAnchor(
      semanticLabel: semanticLabel,
      items: items,
      builder: (context, controller, _) => DsTooltip(
        message: semanticLabel,
        child: DsPressable(
          semanticLabel: semanticLabel,
          onPressed: controller.toggle,
          builder: (context, states, _) {
            final hovered = states.contains(WidgetState.hovered);
            return Container(
              height: 36,
              width: compact ? 36 : null,
              padding: EdgeInsetsDirectional.symmetric(horizontal: compact ? 0 : DsSpace.s8),
              alignment: Alignment.center,
              decoration: DsBoxDecoration(
                color: hovered ? const Color(0x33FFFFFF) : null,
                borderRadius: BorderRadius.circular(theme.radii.control(36)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: DsSpace.s4,
                children: [
                  DsIcon(icon, size: 16, color: const Color(0xFFFFFFFF)),
                  if (!compact) ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: const Color(0xFFFFFFFF)),
                      ),
                    ),
                    const DsIcon(DsIcons.chevronDown, size: 12, color: Color(0xCCFFFFFF)),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The series' related works: a row per season, live ones open, waiting
/// ones reservable on the signed-in account.
final class _RelatedSection extends ConsumerStatefulWidget {
  const _RelatedSection({required this.seriesId});

  final String seriesId;

  @override
  ConsumerState<_RelatedSection> createState() => _RelatedSectionState();
}

final class _RelatedSectionState extends ConsumerState<_RelatedSection> {
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final state = ref.watch(hongguoRelatedProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(hongguoRelatedProvider.notifier).open(widget.seriesId));
    });
    final account = ref.watch(hongguoAccountProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Text(t.hongguo.related, style: theme.typography.title.copyWith(color: colors.text)),
        if (state.loading && state.items.isEmpty) const Center(child: DsSpinner()),
        if (state.error != null && state.items.isEmpty)
          Text(state.error!, style: theme.typography.caption.copyWith(color: colors.textMuted)),
        if (!state.loading && state.items.isEmpty && state.error == null)
          Text(t.hongguo.relatedNone, style: theme.typography.caption.copyWith(color: colors.textMuted)),
        for (final work in state.items)
          HongguoSeriesRow(
            series: work.series.copyWith(
              hot: [
                work.season,
                if (work.upcoming) t.hongguo.relatedReserve else t.hongguo.relatedLive,
              ].where((line) => line.isNotEmpty).join(' · '),
            ),
            onOpen: work.upcoming ? null : () => _openRelated(context, work.series),
            trailing: work.upcoming && account.signedIn
                ? DsButton(
                    size: DsSize.sm,
                    variant: DsButtonVariant.secondary,
                    onPressed: () {
                      final credentials = ref.read(hongguoAccountProvider).credentials;
                      if (credentials == null) return;
                      unawaited(_reserve(context, credentials, work));
                    },
                    child: Text(t.hongguo.relatedReserve),
                  )
                : null,
          ),
      ],
    );
  }
}

/// One episode's comments: paged by the server cursor, read-only.
final class _CommentsSection extends ConsumerStatefulWidget {
  const _CommentsSection({required this.seriesId, required this.episodeVid});

  final String seriesId;

  /// The episode whose comments the section reads; empty until one opens.
  final String episodeVid;

  @override
  ConsumerState<_CommentsSection> createState() => _CommentsSectionState();
}

final class _CommentsSectionState extends ConsumerState<_CommentsSection> {
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final state = ref.watch(hongguoCommentsProvider);
    final episode = widget.episodeVid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || episode.isEmpty || !RegExp(r'^[0-9]{6,30}$').hasMatch(episode)) return;
      unawaited(ref.read(hongguoCommentsProvider.notifier).open(widget.seriesId, episode));
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Text(
          state.total > 0 ? '${t.hongguo.comments} (${state.total})' : t.hongguo.comments,
          style: theme.typography.title.copyWith(color: colors.text),
        ),
        if (state.loading && state.items.isEmpty) const Center(child: DsSpinner()),
        if (state.error != null && state.items.isEmpty)
          Text(state.error!, style: theme.typography.caption.copyWith(color: colors.textMuted)),
        if (!state.loading && state.items.isEmpty && state.error == null && episode.isNotEmpty)
          Text(t.hongguo.commentsEmpty, style: theme.typography.caption.copyWith(color: colors.textMuted)),
        for (final comment in state.items)
          DsCard(
            style: const DsCardStyle(padding: EdgeInsets.all(DsSpace.s12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s12,
              children: [
                DsAvatar(
                  initials: comment.author.isEmpty ? 'HG' : comment.author,
                  size: DsSize.sm,
                  toneIndex: DsAvatar.toneFor(comment.id),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: DsSpace.s4,
                    children: [
                      Row(
                        spacing: DsSpace.s8,
                        children: [
                          Expanded(
                            child: Text(
                              comment.author.isEmpty ? '红果用户' : comment.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.caption.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                            ),
                          ),
                          DsIcon(DsIcons.heart, size: theme.sizes.iconXs, color: colors.textSubtle),
                          Text(
                            '${comment.likes}',
                            style: theme.typography.numeric(
                              theme.typography.caption.copyWith(color: colors.textSubtle),
                            ),
                          ),
                        ],
                      ),
                      Text(comment.content, style: theme.typography.body.copyWith(color: colors.text)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (state.hasMore)
          DsButton(
            variant: DsButtonVariant.secondary,
            onPressed: state.loading ? null : () => unawaited(ref.read(hongguoCommentsProvider.notifier).loadMore()),
            child: Text(t.hongguo.commentsLoadMore),
          ),
      ],
    );
  }
}

/// The series' public reviews and its rating, read off the website's own
/// pages — no account credential goes with the ask.
final class _SeriesReviewsSection extends ConsumerStatefulWidget {
  const _SeriesReviewsSection({required this.seriesId, required this.episodeVid});

  final String seriesId;

  /// The episode the player holds; its comments come from the same pages.
  final String episodeVid;

  @override
  ConsumerState<_SeriesReviewsSection> createState() => _SeriesReviewsSectionState();
}

final class _SeriesReviewsSectionState extends ConsumerState<_SeriesReviewsSection> {
  /// Whether the list shows this episode's comments; the other tab is the
  /// series' own reviews, the reference's two tabs.
  bool _episodeTab = true;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final state = ref.watch(hongguoPublicReviewsProvider);
    final episode = widget.episodeVid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || episode.isEmpty || !RegExp(r'^[0-9]{6,30}$').hasMatch(episode)) return;
      unawaited(ref.read(hongguoPublicReviewsProvider.notifier).open(widget.seriesId, episode));
    });
    final data = state.data;
    final page = data == null ? null : (_episodeTab ? data.episode : data.series);
    final reviews = page?.items ?? const <HongguoPublicReview>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Row(
          spacing: DsSpace.s8,
          children: [
            Expanded(
              child: Text(t.hongguo.reviews, style: theme.typography.title.copyWith(color: colors.text)),
            ),
            if (data != null && data.rating > 0)
              DsBadge(
                label: Text(
                  data.ratingCount > 0
                      ? '${t.hongguo.rating(score: data.rating.toStringAsFixed(1))} · ${t.hongguo.ratingCount(count: data.ratingCount)}'
                      : t.hongguo.rating(score: data.rating.toStringAsFixed(1)),
                ),
                dot: false,
              ),
          ],
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: DsSegmentedControl<bool>(
            value: _episodeTab,
            onChanged: (value) => setState(() => _episodeTab = value),
            segments: [
              DsSegment(value: true, label: Text(t.hongguo.reviewsEpisode)),
              DsSegment(value: false, label: Text(t.hongguo.reviewsSeries)),
            ],
          ),
        ),
        if (state.loading && data == null) const Center(child: DsSpinner()),
        if (state.error != null && data == null)
          Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(
                child: Text(state.error!, style: theme.typography.caption.copyWith(color: colors.textMuted)),
              ),
              DsButton(
                size: DsSize.sm,
                variant: DsButtonVariant.ghost,
                onPressed: () => unawaited(ref.read(hongguoPublicReviewsProvider.notifier).retry()),
                child: Text(t.common.retry),
              ),
            ],
          ),
        if (data != null && reviews.isEmpty)
          Text(t.hongguo.reviewsEmpty, style: theme.typography.caption.copyWith(color: colors.textMuted)),
        for (final review in reviews)
          DsCard(
            style: const DsCardStyle(padding: EdgeInsets.all(DsSpace.s12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s12,
              children: [
                DsAvatar(
                  initials: review.author.isEmpty ? 'HG' : review.author,
                  size: DsSize.sm,
                  toneIndex: DsAvatar.toneFor(review.id),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: DsSpace.s4,
                    children: [
                      Row(
                        spacing: DsSpace.s8,
                        children: [
                          Expanded(
                            child: Text(
                              review.author.isEmpty ? '红果用户' : review.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.caption.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                            ),
                          ),
                          if (review.rating > 0)
                            Text(
                              review.rating.toStringAsFixed(1),
                              style: theme.typography.numeric(
                                theme.typography.caption.copyWith(color: colors.textSubtle),
                              ),
                            ),
                          DsIcon(DsIcons.heart, size: theme.sizes.iconXs, color: colors.textSubtle),
                          Text(
                            '${review.likes}',
                            style: theme.typography.numeric(
                              theme.typography.caption.copyWith(color: colors.textSubtle),
                            ),
                          ),
                        ],
                      ),
                      Text(review.content, style: theme.typography.body.copyWith(color: colors.text)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Pushes another series' page.
void _openRelated(BuildContext context, HongguoSeries series) {
  unawaited(context.push(RouteNames.hongguoSeries.replaceFirst(':seriesId', series.seriesId)));
}

/// The related section's reserve action, on the state above it.
extension _ReserveAction on _RelatedSectionState {
  Future<void> _reserve(BuildContext context, HongguoCredentials credentials, HongguoRelatedWork work) async {
    final t = context.t;
    try {
      await ref.read(hongguoRelatedClientProvider).reserve(credentials, work);
      unawaited(ref.read(hongguoReservationsProvider.notifier).refresh());
      if (!mounted) return;
      showDsToast(context: this.context, title: t.hongguo.reserved);
    } on Object catch (error) {
      if (!mounted) return;
      showDsToast(context: this.context, title: '$error');
    }
  }
}
