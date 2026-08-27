import 'dart:io';
import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'line_fallback_manager.dart';
import 'live_stream_geometry_hint.dart';
import 'portrait_stream_support.dart';
import '../models/player_state.dart';
import '../models/player_engine.dart';
import 'engine_fallback_manager.dart';
import 'playback_lifecycle_coordinator.dart';

import 'package:floating/floating.dart';
import 'package:flutter/scheduler.dart';

import '../models/player_exception.dart';

import 'package:remixicon/remixicon.dart';

import '../models/player_error_type.dart';

import 'package:rxdart/rxdart.dart' hide Rx;
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/settings/player_settings_controller.dart';

import '../interface/unified_player_interface.dart';

import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/player/utils/fullscreen.dart';
import 'package:flutter_floating/flutter_floating.dart';
import 'package:pure_live/player/utils/player_consts.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/player/utils/pip_window_widget.dart';
import 'package:pure_live/player/core/live_audio_service.dart';
import 'package:pure_live/common/utils/latest_async_value_queue.dart';
import 'package:pure_live/player/adapters/player_adapter_factory.dart';
import 'package:pure_live/player/interface/media_kit_player_accessor.dart';
import 'package:pure_live/player/utils/media_kit_content_probe.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku/compact_danmaku_overlay.dart';

typedef UnifiedPlayerCreator = FutureOr<UnifiedPlayer> Function(PlayerEngine engine);

class PlayerManager {
  final EngineFallbackManager fallbackManager;
  final LineFallbackManager lineManager;
  final Duration audioModeSwitchTimeout;
  final Duration sourceOpenTimeout;
  final Duration sourceReadyTimeout;

  /// How long a manual foreground audio session keeps video decode warm.
  /// `null` retains it until the app backgrounds; [Duration.zero] selects the
  /// immediate low-power behaviour used by automatic ASMR and focused tests.
  final Duration? audioModeVideoWarmRetention;
  final UnifiedPlayerCreator _playerCreator;
  final bool Function() _useHardStopOnExit;
  final Future<void> Function(UnifiedPlayer player, bool audioOnly) _audioModeServiceSync;
  final Future<void> Function(LiveRoom room) _audioSessionStart;
  Future<void> _playerLifecycleQueue = Future.value();
  int _sessionId = 0;
  int _playbackIntentRevision = 0;
  bool _isClosing = false;

  PlayerManager({
    required this.fallbackManager,
    required this.lineManager,
    this.audioModeSwitchTimeout = const Duration(seconds: 5),
    this.sourceOpenTimeout = const Duration(seconds: 18),
    this.sourceReadyTimeout = Duration.zero,
    this.audioModeVideoWarmRetention,
    UnifiedPlayerCreator? playerCreator,
    bool Function()? useHardStopOnExit,
    Future<void> Function(UnifiedPlayer player, bool audioOnly)? audioModeServiceSync,
    Future<void> Function(LiveRoom room)? audioSessionStart,
  }) : _playerCreator = playerCreator ?? PlayerAdapterFactory.create,
       _useHardStopOnExit = useHardStopOnExit ?? (() => SettingsService.to.player.useHardStopOnExit.v),
       _audioModeServiceSync =
           audioModeServiceSync ?? ((player, audioOnly) => LiveAudioService.setPlayer(player, audioOnly: audioOnly)),
       _audioSessionStart =
           audioSessionStart ??
           ((room) => LiveAudioService.start(room.roomId!, room.title ?? "", room.nick ?? "", room.avatar)) {
    _audioModeTransitions = LatestAsyncValueQueue<bool>(_applyAudioOnlyMode);
    _audioServiceTransitions = LatestAsyncValueQueue<_AudioServiceRequest>(_applyAudioServiceRequest);
    _pipStateSubscription = isInPip.listen((value) {
      GlobalPlayerState.to.isPipMode.value = value;
      if (!value) _lastAppliedPipAspectRatio = null;
      if (!value && !isFloating.value && !_appFloatingPrepared) {
        _videoController?.clearPipDanmaku();
      }
    });
  }

  bool _isSessionValid(int id) => !_disposed && !_isClosing && _sessionId == id;

  UnifiedPlayer? _currentPlayer;
  PlayerEngine? _runtimeEngine;
  PlayerEngine? _defaultEngine;
  bool _runtimeAudioOnly = false;
  bool _requestedAudioOnly = false;
  bool _nativeAudioOnly = false;
  Timer? _audioModeVideoWarmTimer;
  late final LatestAsyncValueQueue<bool> _audioModeTransitions;
  late final LatestAsyncValueQueue<_AudioServiceRequest> _audioServiceTransitions;
  LiveRoom? _pendingRoomReentry;
  RoomSessionSnapshot? _appFloatingSession;

  String? _currentUrl;
  List<String> _currentPlayUrls = [];
  Map<String, String> _currentHeaders = {};

  final RxBool isInitialized = false.obs;
  final RxBool hasError = false.obs;
  final RxBool isVerticalVideo = false.obs;
  final Rx<VideoGeometrySnapshot> videoGeometry = const VideoGeometrySnapshot.unknown().obs;
  final RxBool isInPip = false.obs;
  final RxBool isPipPreparing = false.obs;
  final RxBool isFloating = false.obs;
  final RxBool isHovered = false.obs;
  final RxBool isFloatingVideoVisible = true.obs;

  /// True only while a deep power-saving audio session is reacquiring video.
  /// The audio presentation remains interactive during this interval, avoiding
  /// a black texture or full-page loading state while the next keyframe arrives.
  final RxBool isVideoRestorePending = false.obs;
  final RxInt videoFitIndex = 0.obs;
  Rx<ValueKey> videoKey = Rx<ValueKey>(const ValueKey("video_0"));
  final RxInt videoPresentationRevision = 0.obs;

  final _stateSubject = BehaviorSubject<PlayerState>.seeded(PlayerState.idle);
  final _playingSubject = BehaviorSubject<bool>.seeded(false);
  final _loadingSubject = BehaviorSubject<bool>.seeded(false);
  final _completeSubject = BehaviorSubject<bool>.seeded(false);
  final _errorSubject = PublishSubject<PlayerException>();
  final _widthSubject = BehaviorSubject<int?>.seeded(null);
  final _heightSubject = BehaviorSubject<int?>.seeded(null);
  final PortraitStreamDetector _portraitDetector = PortraitStreamDetector();

  final List<StreamSubscription> _subscriptions = [];
  StreamSubscription<PiPStatus>? _pipSubscription;
  StreamSubscription<bool>? _pipStateSubscription;

  bool _disposed = false;
  bool _isSwitchingDueToFallback = false;
  bool _isHandlingError = false;
  _PendingPlayerError? _pendingPlayerError;
  int? _errorDedupeSession;
  final Set<String> _errorDedupeSignatures = <String>{};
  static const String _floatTag = "global_video_player";
  Timer? _hideTimer;
  Timer? _sourceReadyTimer;
  Timer? _geometryObservationTimer;
  Timer? _geometryStabilityTimer;
  Timer? _contentProbeTimer;
  int _geometrySessionGeneration = 0;
  int? _freshDecoderGeometryGeneration;
  int _contentProbeAttempts = 0;
  int? _contentProbeInFlightGeneration;
  static const List<Duration> _contentProbeDelays = <Duration>[
    Duration(milliseconds: 500),
    Duration(milliseconds: 900),
    Duration(milliseconds: 1500),
    Duration(milliseconds: 2500),
    Duration(milliseconds: 4000),
    Duration(milliseconds: 6500),
  ];
  late Floating floating;
  LiveRoom? currentFloatRoom;
  VideoController? _videoController;
  final List<Future<void> Function()> _floatingResourceDisposers = <Future<void> Function()>[];
  Future<void>? _floatingCleanup;
  bool _appFloatingPrepared = false;
  bool _pipTransitionInFlight = false;
  int _pipGeometryUpdateGeneration = 0;
  double? _lastAppliedPipAspectRatio;
  final GlobalKey _pipSourceKey = GlobalKey(debugLabel: 'pip-video-source');

  UnifiedPlayer? get currentPlayer => _currentPlayer;
  PlayerEngine get currentEngine => _runtimeEngine ?? _defaultEngine ?? PlayerEngine.mediaKit;
  Stream<PlayerState> get onStateChanged => _stateSubject.stream;
  Stream<bool> get onPlaying => _playingSubject.stream;
  Stream<bool> get onLoading => _loadingSubject.stream;
  Stream<bool> get onComplete => _completeSubject.stream;
  Stream<PlayerException> get onError => _errorSubject.stream;
  Stream<int?> get width => _widthSubject.stream;
  Stream<int?> get height => _heightSubject.stream;
  bool get isPlayingNow => _playingSubject.value;
  bool get isAudioOnlyMode => _runtimeAudioOnly;
  bool get desiredAudioOnlyMode => _requestedAudioOnly;

  /// A lifecycle pause is an implementation detail, not a user playback
  /// intent. The token lets a later resume prove that neither the source nor
  /// the user's intent changed while the application was hidden.
  Future<PlaybackLifecyclePauseToken?> pauseForLifecycle() async {
    final player = _currentPlayer;
    if (player == null || _disposed || _isClosing || (!isPlayingNow && !player.isPlayingNow)) return null;
    final token = (sessionId: _sessionId, intentRevision: _playbackIntentRevision);
    await player.pause();
    if (_disposed || _isClosing || _sessionId != token.sessionId) return null;
    return token;
  }

  Future<bool> resumeFromLifecycle(PlaybackLifecyclePauseToken token) async {
    final player = _currentPlayer;
    if (player == null ||
        _disposed ||
        _isClosing ||
        _sessionId != token.sessionId ||
        _playbackIntentRevision != token.intentRevision ||
        isPlayingNow ||
        player.isPlayingNow) {
      return false;
    }
    await player.play();
    return !_disposed && !_isClosing && _sessionId == token.sessionId;
  }

  /// Selects the first engine without allocating a native player yet.
  /// Browsing the home/settings pages does not need a decoder, demuxer,
  /// texture or their worker threads; [play] performs the one-time warm-up on
  /// the first real room request.
  void configureDefaultEngine(PlayerEngine engine) {
    if (_disposed || _currentPlayer != null) return;
    _defaultEngine = engine;
  }

  /// Whether the room already owns a live native source that can accept an
  /// in-place audio/video track change.
  ///
  /// A live stream can paint and report `playing` before `Player.open`'s Future
  /// settles. Waiting for the whole route initialization in that state made the
  /// first headphone tap wait forever even though the current source was ready
  /// to accept commands.
  bool hasActivePlaybackSession(LiveRoom room) {
    return !_disposed &&
        !_isClosing &&
        _currentPlayer != null &&
        _currentUrl?.isNotEmpty == true &&
        currentFloatRoom == room &&
        isPlayingNow;
  }

  void prepareRoomSessionReentry(LiveRoom room) {
    _pendingRoomReentry = isAppFloatingActive && currentFloatRoom == room ? room : null;
  }

  RoomSessionSnapshot? consumeRoomSessionReentry(LiveRoom room) {
    final resumes =
        _pendingRoomReentry == room && _currentPlayer != null && currentFloatRoom == room && !_isClosing && !_disposed;
    _pendingRoomReentry = null;
    if (!resumes) {
      _appFloatingSession = null;
      return null;
    }

    final cached = _appFloatingSession;
    _appFloatingSession = null;
    if (cached != null && cached.room == room) return cached;

    // Compatibility fallback for a floating session created before the route
    // supplied its complete presentation state. It is still preferable to
    // reopening the same native live source during route construction.
    final urls = List<String>.unmodifiable(_currentPlayUrls);
    final currentUrl = _currentUrl ?? (urls.isEmpty ? '' : urls.first);
    return RoomSessionSnapshot(
      room: currentFloatRoom!,
      qualities: <LivePlayQuality>[LivePlayQuality(quality: '原画')],
      currentQuality: 0,
      playUrls: urls.isEmpty && currentUrl.isNotEmpty ? <String>[currentUrl] : urls,
      currentLineIndex: urls.isEmpty ? 0 : urls.indexOf(currentUrl).clamp(0, urls.length - 1),
      headers: Map<String, String>.unmodifiable(_currentHeaders),
      isAudioOnly: _requestedAudioOnly,
      isLiving: true,
      dataSource: currentUrl,
    );
  }

  void cancelRoomSessionReentry() {
    _pendingRoomReentry = null;
    _appFloatingSession = null;
  }

  bool get shouldKeepDanmakuForAppFloating => _appFloatingPrepared || isFloating.value;
  bool get isAppFloatingActive =>
      _appFloatingPrepared || isFloating.value || _floatingCleanup != null || _floatingResourceDisposers.isNotEmpty;
  bool get isCompactModeActive => isInPip.value || isPipPreparing.value || isFloating.value || _appFloatingPrepared;

  void attachVideoController(VideoController controller) {
    _videoController = controller;
  }

  void detachVideoController(VideoController controller) {
    if (identical(_videoController, controller)) {
      _videoController = null;
    }
  }

  void prepareAppFloating({required Future<void> Function() onClose, RoomSessionSnapshot? session}) {
    // Keep every pending owner until the overlay and popped route have fully
    // unmounted. Releasing a previous owner here recreated the same late-Obx
    // unsubscribe race when navigation happened unusually quickly.
    _floatingResourceDisposers.add(onClose);
    if (session != null && session.room == currentFloatRoom && _currentPlayer != null) {
      final currentUrl = _currentUrl ?? session.dataSource;
      final urls = _currentPlayUrls.isEmpty ? session.playUrls : _currentPlayUrls;
      _appFloatingSession = session.copyWith(
        dataSource: currentUrl,
        playUrls: List<String>.unmodifiable(urls),
        headers: Map<String, String>.unmodifiable(_currentHeaders.isEmpty ? session.headers : _currentHeaders),
        isAudioOnly: _requestedAudioOnly,
      );
    } else {
      _appFloatingSession = null;
    }
    _appFloatingPrepared = true;
  }

  Widget _buildCompactDanmaku() {
    final controller = _videoController;
    return controller == null ? const SizedBox.shrink() : CompactDanmakuOverlay(controller: controller);
  }

  Future<void> _releaseAppFloatingResources() async {
    _appFloatingPrepared = false;
    final disposers = List<Future<void> Function()>.from(_floatingResourceDisposers);
    _floatingResourceDisposers.clear();
    for (final disposer in disposers) {
      await disposer();
    }
    if (!isInPip.value && !isFloating.value) {
      _videoController?.clearPipDanmaku();
    }
  }

  Future<void> _awaitBoundedWidgetUnmount() async {
    // Route and overlay teardown normally completes on the next frame. During
    // backgrounding, shutdown and headless tests there may be no vsync, so an
    // unbounded endOfFrame wait would retain controllers, subscriptions and a
    // native player indefinitely.
    final completer = Completer<void>();
    late final Timer fallbackTimer;
    fallbackTimer = Timer(const Duration(milliseconds: 50), () {
      if (!completer.isCompleted) completer.complete();
    });
    SchedulerBinding.instance.scheduleFrame();
    SchedulerBinding.instance.endOfFrame.whenComplete(() {
      fallbackTimer.cancel();
      if (!completer.isCompleted) completer.complete();
    });
    await completer.future;
    fallbackTimer.cancel();
  }

  double get currentVideoRatio {
    final settings = _portraitSettings;
    return PortraitPresentationPolicy.resolveCompactWindowAspectRatio(
      snapshot: videoGeometry.value,
      effectiveOrientation: effectiveVideoOrientation,
      followStablePortraitSource: settings?.portraitPipFollowSource.v ?? true,
    );
  }

  /// The single immutable geometry shared by the normal room, fullscreen,
  /// system PiP and the application floating window.
  VideoPresentationGeometry get currentPresentationGeometry => PortraitPresentationPolicy.resolvePresentationGeometry(
    snapshot: videoGeometry.value,
    effectiveOrientation: effectiveVideoOrientation,
  );

  double get currentPresentationAspectRatio => currentPresentationGeometry.contentAspectRatio;

  void _beginVideoGeometrySession(LiveRoom? nextRoom, {String? selectedUrl}) {
    _geometrySessionGeneration++;
    _geometryObservationTimer?.cancel();
    _geometryStabilityTimer?.cancel();
    _contentProbeTimer?.cancel();
    _geometryObservationTimer = null;
    _geometryStabilityTimer = null;
    _contentProbeTimer = null;
    _contentProbeAttempts = 0;
    _freshDecoderGeometryGeneration = null;
    if (_widthSubject.value != null) _widthSubject.add(null);
    if (_heightSubject.value != null) _heightSubject.add(null);
    // A room ID is not a media identity. A restarted room, a refreshed signed
    // URL, another quality or another CDN may expose a different encoded
    // canvas. Reusing a room cache made the old orientation control the normal
    // page, fullscreen and PiP before the current decoder spoke. Start every
    // source from unknown; metadata below stays provisional until this source's
    // decoder publishes a valid dimension pair.
    VideoGeometrySnapshot next = _portraitDetector.reset();

    final hint = LiveStreamGeometryHintResolver.resolve(nextRoom, selectedUrl: selectedUrl);
    if (hint != null) {
      next = _portraitDetector.observeSourceMetadata(
        hint.width,
        hint.height,
        confidence: hint.confidence,
        source: hint.source,
      );
      log(
        'Source geometry hint ${hint.width}x${hint.height} (${hint.source}, ${hint.confidence.toStringAsFixed(2)})',
        name: 'PlayerManager.VideoGeometry',
      );
    }
    _publishVideoGeometry(next, notifyController: false);
  }

  void _scheduleVideoGeometryObservation() {
    _geometryObservationTimer?.cancel();
    final generation = _geometrySessionGeneration;
    _geometryObservationTimer = Timer(const Duration(milliseconds: 120), () {
      _geometryObservationTimer = null;
      final width = _widthSubject.value;
      final height = _heightSubject.value;
      if (generation != _geometrySessionGeneration ||
          width == null ||
          height == null ||
          width <= 0 ||
          height <= 0 ||
          _disposed ||
          _isClosing) {
        return;
      }
      final snapshot = _portraitDetector.observe(width, height);
      _freshDecoderGeometryGeneration = generation;
      _publishVideoGeometry(snapshot);
      _scheduleGeometryStabilityCommit();
      if (snapshot.isStable) _scheduleActiveContentProbe();
    });
  }

  void _scheduleGeometryStabilityCommit() {
    _geometryStabilityTimer?.cancel();
    _geometryStabilityTimer = null;
    final since = _portraitDetector.pendingSince;
    if (since == null) return;
    final elapsed = DateTime.now().difference(since);
    final remaining = _portraitDetector.stabilityDelay - elapsed;
    final generation = _geometrySessionGeneration;
    _geometryStabilityTimer = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      _geometryStabilityTimer = null;
      if (generation != _geometrySessionGeneration || _disposed || _isClosing) return;
      final snapshot = _portraitDetector.commitPending();
      _publishVideoGeometry(snapshot);
      if (snapshot.isStable) _scheduleActiveContentProbe();
    });
  }

  void _scheduleActiveContentProbe() {
    final snapshot = videoGeometry.value;
    final needsCanvasInspection = shouldInspectActiveVideoContent(snapshot);
    if (!PlatformUtils.isMobile ||
        _disposed ||
        _isClosing ||
        _runtimeAudioOnly ||
        !isPlayingNow ||
        _contentProbeAttempts >= _contentProbeDelays.length ||
        _contentProbeInFlightGeneration == _geometrySessionGeneration ||
        _contentProbeTimer != null ||
        _freshDecoderGeometryGeneration != _geometrySessionGeneration ||
        !snapshot.isStable ||
        snapshot.isProvisional ||
        !needsCanvasInspection ||
        _portraitDetector.contentEvidenceSettled ||
        !(_portraitSettings?.enablePortraitStreamAdaptation.v ?? true) ||
        _currentPlayer is! MediaKitPlayerAccessor) {
      return;
    }
    final generation = _geometrySessionGeneration;
    final delay = _contentProbeDelays[_contentProbeAttempts];
    _contentProbeTimer = Timer(delay, () {
      _contentProbeTimer = null;
      if (generation != _geometrySessionGeneration || _disposed || _isClosing) return;
      unawaited(_runActiveContentProbe(generation));
    });
  }

  Future<void> _runActiveContentProbe(int generation) async {
    final player = _currentPlayer;
    if (player is! MediaKitPlayerAccessor ||
        _contentProbeInFlightGeneration == generation ||
        _contentProbeAttempts >= _contentProbeDelays.length) {
      return;
    }
    final accessor = player as MediaKitPlayerAccessor;
    _contentProbeInFlightGeneration = generation;
    _contentProbeAttempts++;
    try {
      final observation = await MediaKitContentProbe.capture(accessor);
      if (observation == null ||
          generation != _geometrySessionGeneration ||
          _disposed ||
          _isClosing ||
          !identical(player, _currentPlayer)) {
        return;
      }
      _publishVideoGeometry(_portraitDetector.observeActiveContent(observation));
    } catch (error, stackTrace) {
      log(
        'Active content probe skipped: $error',
        name: 'PlayerManager.VideoGeometry',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (_contentProbeInFlightGeneration == generation) {
        _contentProbeInFlightGeneration = null;
      }
      if (generation == _geometrySessionGeneration &&
          _contentProbeAttempts < _contentProbeDelays.length &&
          !_portraitDetector.contentEvidenceSettled) {
        _scheduleActiveContentProbe();
      }
    }
  }

  VideoSourceOrientation get effectiveVideoOrientation {
    final settings = _portraitSettings;
    return PortraitPresentationPolicy.resolveOrientation(
      snapshot: videoGeometry.value,
      override: settings?.portraitOverrideForRoom(currentFloatRoom) ?? PortraitOrientationOverride.automatic,
      smartDetectionEnabled: settings?.enablePortraitStreamAdaptation.v ?? true,
    );
  }

  PlayerSettingsController? get _portraitSettings {
    try {
      return SettingsService.to.player;
    } catch (_) {
      return null;
    }
  }

  void refreshPortraitPresentationPolicy({bool notifyController = true}) {
    _publishVideoGeometry(videoGeometry.value, notifyController: false);
    if (notifyController) {
      final controller = _videoController;
      if (controller != null) unawaited(controller.applyFullscreenOrientationPolicy());
    }
  }

  void _publishVideoGeometry(VideoGeometrySnapshot snapshot, {bool notifyController = true}) {
    final previous = videoGeometry.value;
    final previousOrientation = effectiveVideoOrientation;
    final previousRatio = PortraitPresentationPolicy.resolveVideoDisplayAspectRatio(
      snapshot: previous,
      effectiveOrientation: previousOrientation,
    );
    videoGeometry.value = snapshot;
    final wasVertical = isVerticalVideo.value;
    final nextVertical = effectiveVideoOrientation == VideoSourceOrientation.portrait;
    final nextRatio = currentPresentationAspectRatio;
    final presentationChanged = wasVertical != nextVertical || (previousRatio - nextRatio).abs() > 0.004;
    final evidenceChanged = previous.evidence != snapshot.evidence;
    final encodedRatioChanged = (previous.aspectRatio - snapshot.aspectRatio).abs() > 0.01;
    if (presentationChanged || evidenceChanged || encodedRatioChanged) {
      log(
        'Geometry encoded=${snapshot.aspectRatio.toStringAsFixed(4)} '
        'effective=${snapshot.effectiveAspectRatio.toStringAsFixed(4)} '
        'presented=${nextRatio.toStringAsFixed(4)} '
        'orientation=${snapshot.orientation.name} evidence=${snapshot.evidence.name} '
        'hint=${snapshot.sourceHintSource.isEmpty ? '-' : snapshot.sourceHintSource}',
        name: 'PlayerManager.VideoGeometry',
      );
    }
    if (presentationChanged) {
      isVerticalVideo.value = nextVertical;
      videoPresentationRevision.value++;
      if (notifyController) {
        final controller = _videoController;
        if (controller != null) unawaited(controller.applyFullscreenOrientationPolicy());
      }
      if (isInPip.value) unawaited(_updateActiveAndroidPip());
    }
  }

  Future<void> _updateActiveAndroidPip() async {
    if (!Platform.isAndroid || !isInPip.value || _pipTransitionInFlight) return;
    final generation = ++_pipGeometryUpdateGeneration;
    // Mirror Android's layout-listener guidance: publish geometry only after
    // the compact video view has adopted the new presentation ratio.
    SchedulerBinding.instance.scheduleFrame();
    await SchedulerBinding.instance.endOfFrame;
    if (generation != _pipGeometryUpdateGeneration || !isInPip.value || _disposed || _isClosing) return;
    final compactRatio = currentVideoRatio;
    final pipRatio = PortraitPresentationPolicy.resolveAndroidPipAspectRatio(
      width: (compactRatio * 10000).round(),
      height: 10000,
      portraitFallback: effectiveVideoOrientation == VideoSourceOrientation.portrait,
    );
    if (_lastAppliedPipAspectRatio != null && (_lastAppliedPipAspectRatio! - pipRatio.value).abs() < 0.004) return;
    try {
      await floating.update(
        aspectRatio: Rational(pipRatio.width, pipRatio.height),
        sourceRectHint: _currentPipSourceRect(contentAspectRatio: pipRatio.value),
      );
      _lastAppliedPipAspectRatio = pipRatio.value;
    } catch (error, stackTrace) {
      log(
        'Update active PiP geometry failed: $error',
        name: 'PlayerManager.VideoGeometry',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<UnifiedPlayer> _createPlayer(PlayerEngine engine, {bool audioOnly = false}) async {
    final player = await _playerCreator(engine);
    try {
      await player.init(audioOnly: audioOnly);
      return player;
    } catch (_) {
      // Native allocation may succeed before controller/surface setup fails.
      // Always release that partial player before trying another engine.
      await _safeDestroyPlayer(player);
      rethrow;
    }
  }

  Future<T> _enqueuePlayerLifecycle<T>(Future<T> Function() operation) {
    final previous = _playerLifecycleQueue;

    final current = previous.then((_) => operation());

    _playerLifecycleQueue = current.then<void>((_) {}, onError: (_, _) {});

    return current;
  }

  Future<void> initialize({PlayerEngine engine = PlayerEngine.mediaKit, bool audioOnly = false}) {
    return _enqueuePlayerLifecycle(
      () => _initializeInternal(engine: engine, audioOnly: audioOnly, sessionId: _sessionId, publishError: true),
    );
  }

  Future<void> _initializeInternal({
    required PlayerEngine engine,
    required bool audioOnly,
    required int sessionId,
    required bool publishError,
  }) async {
    if (_disposed || _isClosing) return;

    _stateSubject.add(PlayerState.initializing);

    try {
      _defaultEngine = engine;
      _runtimeEngine = engine;

      final player = await _createPlayer(engine, audioOnly: audioOnly);

      if (!_isSessionValid(sessionId)) {
        await _safeDestroyPlayer(player);
        return;
      }

      _currentPlayer = player;
      _runtimeAudioOnly = audioOnly;
      _requestedAudioOnly = audioOnly;
      _nativeAudioOnly = audioOnly;

      await _bindPlayerStreams(player, sessionId: sessionId);

      if (!_isSessionValid(sessionId)) {
        await _safeDestroyPlayer(player);

        if (identical(_currentPlayer, player)) {
          _currentPlayer = null;
        }

        return;
      }
      if (Platform.isAndroid) {
        floating = Floating();
        _pipSubscription?.cancel();
        _pipSubscription = floating.pipStatusStream.listen((status) {
          isInPip.value = status == PiPStatus.enabled;
        });
      }

      isInitialized.value = true;
      videoPresentationRevision.value++;
      _stateSubject.add(PlayerState.initialized);

      _scheduleAudioServiceSync(player, audioOnly, sessionId: sessionId);
    } catch (e, s) {
      if (!_isSessionValid(sessionId)) return;

      final exception = PlayerException(
        message: 'Initialize player failed',
        type: PlayerErrorType.initialization,
        error: e,
        stackTrace: s,
      );

      // Explicit pre-warm calls own their terminal error. A player allocated as
      // part of [play] is different: its initialization failure must remain
      // private until the orchestrator has tried the remaining engines.
      if (publishError) _publishTerminalPlayerError(exception);

      throw exception;
    }
  }

  Future<void> play(
    String url,
    List<String> playUrls,
    Map<String, String> headers, {
    LiveRoom? room,
    bool audioOnly = false,
  }) {
    return _enqueuePlayerLifecycle(() => _playInternal(url, playUrls, headers, room: room, audioOnly: audioOnly));
  }

  Future<void> _playInternal(
    String url,
    List<String> playUrls,
    Map<String, String> headers, {
    LiveRoom? room,
    bool audioOnly = false,
  }) async {
    if (_disposed) return;
    _sourceReadyTimer?.cancel();
    _sourceReadyTimer = null;
    _audioModeVideoWarmTimer?.cancel();
    _audioModeVideoWarmTimer = null;
    isVideoRestorePending.value = false;
    if (_disposed || _isClosing) return;
    final mySessionId = ++_sessionId;

    final roomChanged = room != currentFloatRoom;
    if (roomChanged) {
      lineManager.reset();
      fallbackManager.resetAll();
    }
    // Start a geometry generation for every new source, including quality and
    // CDN switches in the same room. Same-room presentation remains visible;
    // another room receives only its own bounded cache entry.
    _beginVideoGeometrySession(room, selectedUrl: url);

    // Recovery needs the complete request even when the preferred native
    // engine fails before a player exists. Previously these fields were set
    // only after initialization, so an initialization exception escaped the
    // line/engine recovery state machine and immediately surfaced as a decoder
    // error.
    _currentUrl = url;
    _currentPlayUrls = List<String>.from(playUrls);
    _currentHeaders = Map<String, String>.from(headers);
    currentFloatRoom = room;
    refreshPortraitPresentationPolicy(notifyController: false);
    hasError.value = false;

    if (_currentPlayer == null || _runtimeEngine == null) {
      if (_defaultEngine == null) {
        final String savedKey = SettingsService.to.player.videoPlayerKey.v;

        final String validKey = PlayerConsts.engines.containsKey(savedKey) ? savedKey : PlayerConsts.defaultKey;

        _defaultEngine = PlayerConsts.engines[validKey]!;
      }

      final engine = _defaultEngine!;

      log('No current player, initializing with default engine: $engine', name: 'PlayerManager');

      try {
        await _initializeInternal(engine: engine, audioOnly: audioOnly, sessionId: mySessionId, publishError: false);
      } on PlayerException catch (error) {
        if (_isSessionValid(mySessionId)) {
          await _handleError(error, sessionId: mySessionId);
        }
        return;
      }
    } else if (_runtimeEngine != _defaultEngine && !_isSwitchingDueToFallback) {
      await _switchEngineInternal(_defaultEngine!, isManual: false, audioOnly: audioOnly, openCurrentSource: false);
    } else if (_runtimeAudioOnly != audioOnly || _requestedAudioOnly != audioOnly) {
      await setAudioOnlyMode(audioOnly);
    }

    if (!_isSessionValid(mySessionId)) return;

    final player = _currentPlayer;

    if (player == null) {
      if (!_isSessionValid(mySessionId)) {
        return;
      }

      throw PlayerException(message: 'Current player is null', type: PlayerErrorType.lifecycle);
    }

    // Every bundled player has a native audio-only path.  Opening the original
    // live URL directly avoids a second FFmpeg decode pipeline and removes the
    // previous fixed two-second wait / 30-second pipe timeout.
    final String targetUrl = url;
    final List<String> targetPlayUrls = List.from(playUrls);

    // Reset retained-adapter subjects before rebinding this source generation.
    // Without this handshake BehaviorSubjects replayed the previous URL's
    // dimensions and delayed errors into the new room/quality session.
    if (player is SourceTransitionAwarePlayer) {
      (player as SourceTransitionAwarePlayer).beginSourceTransition();
    }
    await _bindPlayerStreams(player, sessionId: mySessionId);
    if (!_isSessionValid(mySessionId)) return;

    _currentUrl = targetUrl;
    _currentPlayUrls = targetPlayUrls;

    try {
      _stateSubject.add(PlayerState.preparing);
      await _openPlayerSource(player, targetUrl, targetPlayUrls, headers, room: room, audioOnly: audioOnly);
      if (!_isSessionValid(mySessionId)) return;
      _nativeAudioOnly = audioOnly;
      _armSourceReadyDeadline(player, mySessionId);

      // Desktop player adapters do not all restore the per-room volume in
      // setDataSource. Apply it centrally so every engine starts consistently.
      if (PlatformUtils.isDesktop && room != null) {
        try {
          await player.setVolume(room.getSavedVolume().clamp(0.0, 1.0));
        } catch (error, stackTrace) {
          // A damaged/migrating volume preference is not a playback failure.
          // Keep the already-open live stream usable and fall back to the
          // adapter's current volume.
          log('Restore room volume failed: $error', name: 'PlayerManager', error: error, stackTrace: stackTrace);
        }
      }
      if (!_isSessionValid(mySessionId)) return;
      _stateSubject.add(PlayerState.ready);
      _scheduleAudioServiceSync(player, audioOnly, room: room, sessionId: mySessionId);
    } on PlayerException catch (e) {
      if (_isSessionValid(mySessionId)) await _handleError(e, sessionId: mySessionId);
    } catch (e, s) {
      log(e.toString());
      if (_isSessionValid(mySessionId)) {
        final exception = PlayerException(
          message: 'Play failed',
          type: PlayerErrorType.unknown,
          error: e,
          stackTrace: s,
        );
        await _handleError(exception, sessionId: mySessionId);
      }
    } finally {
      _isSwitchingDueToFallback = false;
    }
  }

  Future<void> replay() {
    return _enqueuePlayerLifecycle(() async {
      if (_currentUrl == null) return;

      await _playInternal(
        _currentUrl!,
        _currentPlayUrls,
        _currentHeaders,
        room: currentFloatRoom,
        audioOnly: _runtimeAudioOnly,
      );
    });
  }

  /// Changes the current room between video and audio-only in place.
  ///
  /// Reopening the whole stream made the UI wait for native stop/dispose,
  /// player initialization, AudioService binding and CDN setup. A stalled
  /// native future therefore left the room on an endless loading indicator.
  Future<void> setAudioOnlyMode(bool audioOnly) async {
    if (_disposed || _isClosing) return;
    if (!audioOnly) {
      _audioModeVideoWarmTimer?.cancel();
      _audioModeVideoWarmTimer = null;
    }
    _requestedAudioOnly = audioOnly;
    await _audioModeTransitions.submit(audioOnly);
  }

  Future<void> _applyAudioOnlyMode(bool audioOnly) async {
    if (_disposed || _isClosing) return;
    final player = _currentPlayer;
    if (player == null) {
      throw PlayerException(message: 'Current player is null', type: PlayerErrorType.lifecycle);
    }

    final previous = _runtimeAudioOnly;
    final transitionSessionId = _sessionId;
    final enteringAudioMode = audioOnly && !previous;
    final restoringDeepVideo = !audioOnly && previous && _nativeAudioOnly;

    // Cover the native video immediately when entering audio mode. Disabling
    // mpv's video track can make its buffering stream briefly report loading;
    // publishing the audio presentation first prevents that native transition
    // from replacing the room with an endless loading indicator. Restoring
    // video uses the opposite order and keeps the audio UI visible until the
    // Surface has really been re-enabled.
    if (enteringAudioMode && _requestedAudioOnly == audioOnly) {
      isVideoRestorePending.value = false;
      _runtimeAudioOnly = true;
      videoPresentationRevision.value++;
    }
    if (restoringDeepVideo && _requestedAudioOnly == audioOnly) {
      isVideoRestorePending.value = true;
    }
    try {
      final warmRetention = audioModeVideoWarmRetention;
      final keepVideoWarm =
          enteringAudioMode && !_nativeAudioOnly && (warmRetention == null || warmRetention > Duration.zero);
      if (keepVideoWarm) {
        _scheduleNativeAudioOnlyCommit(player, transitionSessionId);
      } else {
        // Restoring always submits `false`, even while the warm timer's
        // `true` command is in flight. The adapter's latest-value queue then
        // guarantees that a late power-saving commit cannot turn video off
        // again after the user has requested it.
        await player.setAudioOnly(audioOnly).timeout(audioModeSwitchTimeout);
        if (_requestedAudioOnly == audioOnly) {
          _nativeAudioOnly = audioOnly;
        }
      }
      if (!identical(_currentPlayer, player) || _disposed || _isClosing || transitionSessionId != _sessionId) {
        if (restoringDeepVideo) isVideoRestorePending.value = false;
        return;
      }

      _runtimeAudioOnly = audioOnly;
      // The request may have been superseded by a floating-window re-entry or
      // another room while the native command was pending. Let the queue apply
      // the latest value without publishing this stale intermediate state.
      if (_requestedAudioOnly != audioOnly) {
        if (restoringDeepVideo) isVideoRestorePending.value = false;
        return;
      }
      // Publish presentation state before synchronizing the notification/
      // foreground service. The headphone action must never leave the native
      // video surface as the only visible feedback while Android initializes
      // its media session.
      if (!enteringAudioMode) {
        isVideoRestorePending.value = false;
        videoPresentationRevision.value++;
        _scheduleActiveContentProbe();
      }
    } catch (error, stackTrace) {
      if (!identical(_currentPlayer, player) || _disposed || _isClosing || transitionSessionId != _sessionId) {
        if (restoringDeepVideo) isVideoRestorePending.value = false;
        return;
      }
      // Future.timeout does not stop the native command. Do not launch an
      // opposite command concurrently here. Record the desired rollback; the
      // adapter's serialized latest-value queue will apply it after the timed
      // out command returns.
      if (_requestedAudioOnly == audioOnly) {
        _requestedAudioOnly = previous;
      }
      unawaited(player.setAudioOnly(_requestedAudioOnly).catchError((_) {}));
      if (_runtimeAudioOnly != previous) {
        _runtimeAudioOnly = previous;
        videoPresentationRevision.value++;
      }
      isVideoRestorePending.value = false;
      throw PlayerException(
        message: error is TimeoutException ? 'Audio mode switch timed out' : 'Audio mode switch failed',
        type: PlayerErrorType.lifecycle,
        error: error,
        stackTrace: stackTrace,
      );
    }

    // The native player transition above is authoritative. Android's media
    // notification/foreground-service initialization is a separate serialized
    // lane and may be delayed by the OS. It never blocks or rolls back the
    // headphone action.
    _scheduleAudioServiceSync(player, audioOnly, room: currentFloatRoom, sessionId: transitionSessionId);
  }

  void _scheduleNativeAudioOnlyCommit(UnifiedPlayer player, int sessionId) {
    _audioModeVideoWarmTimer?.cancel();
    final retention = audioModeVideoWarmRetention;
    // The normal foreground headphone action stays warm for its complete
    // lifetime. Android lifecycle will explicitly commit the low-power state
    // when the app backgrounds.
    if (retention == null) return;
    _audioModeVideoWarmTimer = Timer(retention, () {
      _audioModeVideoWarmTimer = null;
      unawaited(_commitNativeAudioOnly(player, sessionId));
    });
  }

  Future<void> _commitNativeAudioOnly(UnifiedPlayer player, int sessionId) async {
    if (_disposed ||
        _isClosing ||
        !_requestedAudioOnly ||
        !_runtimeAudioOnly ||
        !identical(_currentPlayer, player) ||
        sessionId != _sessionId) {
      return;
    }
    if (_nativeAudioOnly) return;
    try {
      await player.setAudioOnly(true).timeout(audioModeSwitchTimeout);
      if (!_disposed &&
          !_isClosing &&
          _requestedAudioOnly &&
          _runtimeAudioOnly &&
          identical(_currentPlayer, player) &&
          sessionId == _sessionId) {
        _nativeAudioOnly = true;
      }
    } catch (error, stackTrace) {
      // The room is already presenting and playing audio. Failure to enter the
      // delayed low-power state must not interrupt that usable session.
      log(
        'Delayed audio-only power-saving commit failed: $error',
        name: 'PlayerManager',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Ends the short manual-switch warm window immediately, e.g. when Android
  /// backgrounds the room. Long ASMR/background sessions still stop video
  /// decode, while a quick foreground toggle can restore without waiting for
  /// the next stream keyframe.
  Future<void> commitAudioOnlyPowerSaving() async {
    final player = _currentPlayer;
    if (player == null || !_requestedAudioOnly || !_runtimeAudioOnly) return;
    _audioModeVideoWarmTimer?.cancel();
    _audioModeVideoWarmTimer = null;
    await _commitNativeAudioOnly(player, _sessionId);
  }

  /// Prepares a manually selected audio room after returning to the foreground.
  /// The audio card remains visible while mpv catches the next keyframe, so a
  /// later headphone tap reveals an already-current video instead of starting
  /// the 1-3 second keyframe wait at tap time.
  Future<void> prepareAudioOnlyVideoRestore() async {
    final player = _currentPlayer;
    final sessionId = _sessionId;
    if (player == null || !_requestedAudioOnly || !_runtimeAudioOnly || !_nativeAudioOnly) return;
    try {
      // Prewarm silently behind the existing audio card. This deliberately
      // does not publish [isVideoRestorePending]: no user action is waiting and
      // showing a restore badge on every app resume would create visual noise.
      await player.setAudioOnly(false).timeout(audioModeSwitchTimeout);
      if (!_disposed &&
          !_isClosing &&
          _requestedAudioOnly &&
          _runtimeAudioOnly &&
          identical(_currentPlayer, player) &&
          sessionId == _sessionId) {
        _nativeAudioOnly = false;
      }
    } catch (error, stackTrace) {
      log('Foreground video warm-up failed: $error', name: 'PlayerManager', error: error, stackTrace: stackTrace);
    }
  }

  void _scheduleAudioServiceSync(UnifiedPlayer player, bool audioOnly, {LiveRoom? room, required int sessionId}) {
    unawaited(
      _audioServiceTransitions
          .submit(_AudioServiceRequest(player: player, audioOnly: audioOnly, room: room, sessionId: sessionId))
          .catchError((Object error, StackTrace stackTrace) {
            log(
              'Audio service synchronization failed: $error',
              name: 'PlayerManager',
              error: error,
              stackTrace: stackTrace,
            );
          }),
    );
  }

  Future<void> _applyAudioServiceRequest(_AudioServiceRequest request) async {
    if (_disposed || _isClosing || !identical(_currentPlayer, request.player) || request.sessionId != _sessionId) {
      return;
    }

    try {
      await _audioModeServiceSync(request.player, request.audioOnly);
      if (_disposed || _isClosing || !identical(_currentPlayer, request.player) || request.sessionId != _sessionId) {
        return;
      }
      if (_requestedAudioOnly != request.audioOnly) return;
      final room = request.room;
      if (room != null && room.roomId != null && currentFloatRoom == room) {
        await _audioSessionStart(room);
      }
    } catch (error, stackTrace) {
      if (!identical(_currentPlayer, request.player) || _disposed || _isClosing || request.sessionId != _sessionId) {
        return;
      }
      log(
        'Audio service sync failed after mode change: $error',
        name: 'PlayerManager',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> switchEngine(PlayerEngine engine, {bool isManual = false, bool? audioOnly}) {
    return _enqueuePlayerLifecycle(() => _switchEngineInternal(engine, isManual: isManual, audioOnly: audioOnly));
  }

  Future<void> _switchEngineInternal(
    PlayerEngine engine, {
    bool isManual = false,
    bool? audioOnly,
    bool openCurrentSource = true,
  }) async {
    if (_disposed || _isClosing) return;

    if (_runtimeEngine == engine && _currentPlayer != null) {
      return;
    }

    final sessionId = _sessionId;
    final oldPlayer = _currentPlayer;
    final oldEngine = _runtimeEngine;
    final oldDefaultEngine = _defaultEngine;
    final oldRuntimeAudioOnly = _runtimeAudioOnly;
    final oldRequestedAudioOnly = _requestedAudioOnly;
    final oldNativeAudioOnly = _nativeAudioOnly;
    final targetAudioOnly = audioOnly ?? _runtimeAudioOnly;
    UnifiedPlayer? candidate;
    var candidateInstalled = false;

    try {
      candidate = await _createPlayer(engine, audioOnly: targetAudioOnly);
      if (!_isSessionValid(sessionId)) {
        await _safeDestroyPlayer(candidate);
        return;
      }

      final sourceUrl = _currentUrl;
      if (openCurrentSource && sourceUrl != null && sourceUrl.isNotEmpty) {
        if (candidate is SourceTransitionAwarePlayer) {
          (candidate as SourceTransitionAwarePlayer).beginSourceTransition();
        }
        await _openPlayerSource(
          candidate,
          sourceUrl,
          List<String>.from(_currentPlayUrls),
          Map<String, String>.from(_currentHeaders),
          room: currentFloatRoom,
          audioOnly: targetAudioOnly,
        );
        if (!_isSessionValid(sessionId)) {
          await _safeDestroyPlayer(candidate);
          return;
        }
      }

      // Commit only after the candidate has initialized and, for a live
      // switch, opened the active source. The previous decoder remains the
      // visible/playing owner until this point, so a failed engine no longer
      // turns a recoverable switch into a black screen.
      _currentPlayer = candidate;
      _runtimeEngine = engine;
      _runtimeAudioOnly = targetAudioOnly;
      _requestedAudioOnly = targetAudioOnly;
      _nativeAudioOnly = targetAudioOnly;

      if (isManual) {
        _defaultEngine = engine;
      }
      try {
        await _bindPlayerStreams(candidate, sessionId: sessionId);
        candidateInstalled = true;
      } catch (_) {
        // Stream binding is part of installing the replacement engine. Roll
        // the transaction back instead of leaking a half-installed native
        // player and abandoning the still-usable previous decoder.
        _currentPlayer = oldPlayer;
        _runtimeEngine = oldEngine;
        _defaultEngine = oldDefaultEngine;
        _runtimeAudioOnly = oldRuntimeAudioOnly;
        _requestedAudioOnly = oldRequestedAudioOnly;
        _nativeAudioOnly = oldNativeAudioOnly;
        if (oldPlayer != null) {
          try {
            await _bindPlayerStreams(oldPlayer, sessionId: sessionId);
          } catch (restoreError, restoreStackTrace) {
            log(
              'Restore previous player subscriptions failed: $restoreError',
              name: 'PlayerManager',
              error: restoreError,
              stackTrace: restoreStackTrace,
            );
          }
        }
        rethrow;
      }
      if (openCurrentSource && sourceUrl != null && sourceUrl.isNotEmpty) {
        _armSourceReadyDeadline(candidate, sessionId);
      }
      if (oldPlayer != null && !identical(oldPlayer, candidate)) {
        await _safeDestroyPlayer(oldPlayer);
      }
      videoKey.value = ValueKey("video_${DateTime.now().millisecondsSinceEpoch}");
      _scheduleAudioServiceSync(candidate, targetAudioOnly, room: currentFloatRoom, sessionId: sessionId);
    } catch (e, s) {
      if (!candidateInstalled && candidate != null && !identical(candidate, oldPlayer)) {
        await _safeDestroyPlayer(candidate);
      }
      if (!candidateInstalled && identical(_currentPlayer, candidate)) {
        _currentPlayer = oldPlayer;
        _runtimeEngine = oldEngine;
        _defaultEngine = oldDefaultEngine;
        _runtimeAudioOnly = oldRuntimeAudioOnly;
        _requestedAudioOnly = oldRequestedAudioOnly;
        _nativeAudioOnly = oldNativeAudioOnly;
      }
      final exception = PlayerException(
        message: 'Switch engine failed: $e',
        type: PlayerErrorType.lifecycle,
        error: e,
        stackTrace: s,
      );
      if (isManual) _publishTerminalPlayerError(exception);
      throw exception;
    }
  }

  Future<void> _openPlayerSource(
    UnifiedPlayer player,
    String url,
    List<String> playUrls,
    Map<String, String> headers, {
    required LiveRoom? room,
    required bool audioOnly,
  }) async {
    final sourceOpen = player.setDataSource(url, playUrls, headers, room: room, audioOnly: audioOnly);
    if (sourceOpenTimeout <= Duration.zero) {
      await sourceOpen;
      return;
    }
    await sourceOpen.timeout(
      sourceOpenTimeout,
      onTimeout: () {
        throw PlayerException(
          message: 'Native player did not finish opening the source before the deadline',
          type: PlayerErrorType.initialization,
          code: 'source_open_timeout',
        );
      },
    );
  }

  Future<void> _safeDestroyPlayer(UnifiedPlayer player) async {
    try {
      await player.hardDispose();
    } catch (e, s) {
      log("destroy player error: $e", stackTrace: s);
    }
  }

  void _armSourceReadyDeadline(UnifiedPlayer player, int sessionId) {
    _sourceReadyTimer?.cancel();
    _sourceReadyTimer = null;
    if (sourceReadyTimeout <= Duration.zero || player.isPlayingNow || !_isPlayerEventCurrent(player, sessionId)) {
      return;
    }
    _sourceReadyTimer = Timer(sourceReadyTimeout, () {
      _sourceReadyTimer = null;
      if (!_isPlayerEventCurrent(player, sessionId) || player.isPlayingNow || _playingSubject.value) return;
      _schedulePlayerError(
        PlayerException(
          message: 'Source opened but produced no playable frame before the readiness deadline',
          type: PlayerErrorType.source,
        ),
        sessionId,
      );
    });
  }

  void _schedulePlayerError(PlayerException error, int sessionId) {
    unawaited(
      _enqueuePlayerLifecycle(() => _handleError(error, sessionId: sessionId))
          .catchError((Object failure, StackTrace stackTrace) {
            log(
              'Scheduled player recovery failed: $failure',
              name: 'PlayerManager',
              error: failure,
              stackTrace: stackTrace,
            );
          }),
    );
  }

  Future<void> togglePlayPause() async {
    if (_currentPlayer == null) return;
    if (isPlayingNow) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> pause() async {
    final player = _currentPlayer;
    if (player == null) return;
    _playbackIntentRevision++;
    await player.pause();
  }

  Future<void> resume() async {
    final player = _currentPlayer;
    if (player == null) return;
    _playbackIntentRevision++;
    await player.play();
  }

  Future<void> stop() async {
    await close();
    await closeAppFloating();
  }

  Future<void> setVolume(double volume) async {
    await _currentPlayer?.setVolume(volume.clamp(0.0, 1.0));
  }

  void changeVideoFit(int index) {
    final fitList = SettingsService.to.player.videoFitArray;
    if (fitList.isEmpty || index < 0 || index >= fitList.length) return;
    videoFitIndex.value = index;
    _applyVideoFit(_currentPlayer, fitList[index]);
  }

  void _applyVideoFit(UnifiedPlayer? player, BoxFit fit) {
    if (player is! VideoFitAwarePlayer) return;
    (player as VideoFitAwarePlayer).setVideoFit(fit);
  }

  Future<void> enablePip() async {
    if (PlatformUtils.isAndroid) {
      if (_pipTransitionInFlight) return;
      _pipTransitionInFlight = true;
      try {
        final status = await floating.pipStatus;
        if (status != PiPStatus.disabled) return;

        // Android captures the Activity at the start of the PiP animation.
        // Build the compact video-only surface first, then enter PiP after a
        // rendered frame so Texture/PlatformView players do not show an app
        // icon or a black placeholder while being reattached.
        isPipPreparing.value = true;
        await SchedulerBinding.instance.endOfFrame;

        final compactRatio = currentVideoRatio;
        final sourceRectHint = _currentPipSourceRect(contentAspectRatio: compactRatio);
        final pipRatio = PortraitPresentationPolicy.resolveAndroidPipAspectRatio(
          width: (compactRatio * 10000).round(),
          height: 10000,
          portraitFallback: isVerticalVideo.value,
        );
        final rational = Rational(pipRatio.width, pipRatio.height);
        final result = await floating.enable(ImmediatePiP(aspectRatio: rational, sourceRectHint: sourceRectHint));
        if (result == PiPStatus.enabled) {
          _lastAppliedPipAspectRatio = pipRatio.value;
          isInPip.value = true;
        }
      } finally {
        isPipPreparing.value = false;
        _pipTransitionInFlight = false;
      }
    } else if (Platform.isWindows) {
      await WindowService().enterWinPiP(currentVideoRatio);
      isInPip.value = true;
    }
  }

  math.Rectangle<int>? _currentPipSourceRect({required double contentAspectRatio}) {
    final context = _pipSourceKey.currentContext;
    final renderObject = context?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    final view = View.maybeOf(context!);
    if (view == null) return null;
    final origin = renderObject.localToGlobal(Offset.zero);
    final visibleRect = resolveContainedVideoRect(
      container: origin & renderObject.size,
      contentAspectRatio: contentAspectRatio,
    );
    final ratio = view.devicePixelRatio;
    final left = (visibleRect.left * ratio).round();
    final top = (visibleRect.top * ratio).round();
    final width = (visibleRect.width * ratio).round();
    final height = (visibleRect.height * ratio).round();
    if (width <= 0 || height <= 0) return null;
    return math.Rectangle<int>(left, top, width, height);
  }

  Future<void> exitPip() async {
    if (Platform.isWindows) {
      await WindowService().exitWinPiP();
      isInPip.value = false;
    }
  }

  void showAppFloating() {
    // A delayed show is scheduled after the room route pops. Re-entering a
    // room during that delay closes the prepared session and must prevent the
    // stale callback from mounting the old player on top of the new route.
    if (!_appFloatingPrepared || _floatingCleanup != null) return;
    isFloatingVideoVisible.value = true;
    floatingManager.disposeFloating(_floatTag);
    _hideTimer?.cancel();
    final maxSide = Platform.isWindows ? 350.0 : 220.0;

    void resetHideTimer() {
      if (Platform.isAndroid || Platform.isIOS) {
        _hideTimer?.cancel();
        _hideTimer = Timer(const Duration(seconds: 3), () {
          isHovered.value = false;
        });
      }
    }

    isFloatingVideoVisible.value = true;
    floatingManager.createFloating(
      _floatTag,
      FloatingOverlay(
        MouseRegion(
          onEnter: (_) {
            if (Platform.isWindows || Platform.isMacOS) isHovered.value = true;
          },
          onExit: (_) {
            if (Platform.isWindows || Platform.isMacOS) isHovered.value = false;
          },
          child: Obx(() {
            // The overlay is created before late decoder/frame evidence may
            // settle. Keep its outer bounds on the same reactive geometry as
            // the texture instead of freezing the entry-time 16:9 size.
            videoPresentationRevision.value;
            final floatingSize = resolveAppFloatingSize(aspectRatio: currentVideoRatio, maxSide: maxSide);
            return Container(
              width: floatingSize.width,
              height: floatingSize.height,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.black),
              child: Stack(
                children: [
                  Obx(
                    () => Positioned.fill(
                      child: isFloatingVideoVisible.value
                          ? getVideoWidget(
                              SettingsService.to.player.videoFitIndex.v,
                              fitList: SettingsService.to.player.videoFitArray,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  Positioned.fill(child: _buildCompactDanmaku()),
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        final room = currentFloatRoom;
                        if (room != null) {
                          await AppNavigator.toLiveRoomDetail(liveRoom: room);
                        }
                      },
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Center(
                    child: Obx(
                      () => AnimatedOpacity(
                        opacity: isHovered.value ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: IgnorePointer(
                          ignoring: !isHovered.value,
                          child: StreamBuilder<bool>(
                            stream: onPlaying,
                            initialData: isPlayingNow,
                            builder: (context, snapshot) {
                              var isPlay = snapshot.data ?? true;
                              return IconButton(
                                iconSize: 42,
                                style: IconButton.styleFrom(backgroundColor: Colors.black45),
                                icon: Icon(
                                  isPlay ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  togglePlayPause();
                                  resetHideTimer();
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Obx(
                      () => AnimatedOpacity(
                        opacity: isHovered.value ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: IgnorePointer(
                          ignoring: !isHovered.value,
                          child: IconButton(
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                            style: IconButton.styleFrom(backgroundColor: Colors.black45),
                            icon: const Icon(Icons.close, color: Colors.white, size: 20),
                            onPressed: () async {
                              await stop();
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
        right: 50,
        top: 100,
        slideType: FloatingEdgeType.onRightAndTop,
        params: FloatingParams(isSnapToEdge: false, snapToEdgeSpace: 10, dragOpacity: 0.8),
      ),
    );
    final overlay = floatingManager.getFloating(_floatTag);
    final overlayContext = Get.overlayContext ?? Get.context;
    if (overlayContext != null) {
      overlay.open(overlayContext);
    }
    if (overlayContext == null || !overlay.isShowing) {
      // Never keep decoding an invisible floating session. This also releases
      // the popped route's controllers when the target Overlay disappeared
      // during navigation.
      isFloating.value = false;
      unawaited(closeAppFloating().then((_) => close()));
      return;
    }
    isFloating.value = true;
    if (Platform.isAndroid || Platform.isIOS) {
      isHovered.value = true;
      resetHideTimer();
    }
  }

  Future<void> closeAppFloating() async {
    final cleanupInFlight = _floatingCleanup;
    if (cleanupInFlight != null) {
      await cleanupInFlight;
      return;
    }
    if (!_appFloatingPrepared &&
        !isFloating.value &&
        _floatingResourceDisposers.isEmpty &&
        !floatingManager.containsFloating(_floatTag)) {
      return;
    }

    late final Future<void> cleanup;
    cleanup = () async {
      final hadOverlay = floatingManager.containsFloating(_floatTag);
      if (hadOverlay) {
        isFloatingVideoVisible.value = false;
        // Hiding the native view normally takes one frame, but Android can
        // stop producing vsync while the app backgrounds. Use the same bounded
        // fence as the later unmount step so cleanup cannot retain a decoder,
        // Surface and route subscriptions forever before it removes the
        // overlay.
        await _awaitBoundedWidgetUnmount();
        // OverlayEntry.remove() schedules unmount for the next frame. Calling
        // disposeFloating here would also dispose its controllers while the
        // FloatingView is still subscribed to them.
        floatingManager.getFloating(_floatTag).close();
      }
      isFloating.value = false;
      // Cancel a delayed showAppFloating callback immediately.
      _appFloatingPrepared = false;

      // The popped live route and its overlay can both still be in Flutter's
      // inactive element list. Let their Obx/StreamBuilder widgets unsubscribe
      // before closing the old room's Rx values and player controllers.
      await _awaitBoundedWidgetUnmount();

      if (hadOverlay && floatingManager.containsFloating(_floatTag)) {
        floatingManager.disposeFloating(_floatTag);
      }
      await _releaseAppFloatingResources();
      if (_pendingRoomReentry == null) {
        _appFloatingSession = null;
      }
      if (!isInPip.value) {
        _videoController?.clearPipDanmaku();
      }
    }();
    _floatingCleanup = cleanup;
    try {
      await cleanup;
    } finally {
      if (identical(_floatingCleanup, cleanup)) _floatingCleanup = null;
    }
  }

  Widget buildPiPOverlay() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MouseRegion(
        onEnter: (_) => isHovered.value = true,
        onExit: (_) => isHovered.value = false,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(color: Colors.black),
          child: Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => windowManager.startDragging(),
                onDoubleTap: () async {
                  await exitPip();
                },
                child: Obx(
                  () => getVideoWidget(
                    SettingsService.to.player.videoFitIndex.v,
                    fitList: SettingsService.to.player.videoFitArray,
                    trackPipSource: true,
                  ),
                ),
              ),
              Positioned.fill(child: _buildCompactDanmaku()),
              Center(
                child: Obx(
                  () => AnimatedOpacity(
                    opacity: isHovered.value ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: StreamBuilder<bool>(
                      stream: onPlaying,
                      initialData: isPlayingNow,
                      builder: (context, snapshot) {
                        var isPlay = snapshot.data ?? true;
                        return IconButton(
                          iconSize: 42,
                          style: IconButton.styleFrom(backgroundColor: Colors.black45),
                          icon: Icon(
                            isPlay ? Icons.pause_circle_filled : Icons.play_circle_filled,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            togglePlayPause();
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Obx(
                  () => AnimatedOpacity(
                    opacity: isHovered.value ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () async {
                        await exitPip();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildAudioOnlyUI(BuildContext context, LiveRoom? detail) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        final compact = maxHeight < 500;
        final avatarSize = compact ? (maxHeight * 0.22).clamp(50.0, 76.0) : 100.0;
        final titleSize = compact ? 14.0 : 22.0;
        final nickSize = compact ? 11.0 : 13.0;
        final badgeTextSize = compact ? 11.0 : 13.0;
        final gapLarge = compact ? 10.0 : 24.0;
        final gapMedium = compact ? 8.0 : 16.0;
        final gapSmall = compact ? 4.0 : 8.0;

        final avatar = detail?.avatar ?? '';
        final title = detail?.title ?? '';
        final nick = detail?.nick ?? '';

        final background = avatar.isEmpty
            ? const SizedBox.expand()
            : Positioned.fill(
                child: Opacity(
                  opacity: 0.22,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(Color(0xFF273047), BlendMode.modulate),
                    child: Image.network(avatar, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.expand()),
                  ),
                ),
              );

        return Stack(
          fit: StackFit.expand,
          children: [
            background,
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xE8121827), Color(0xF20B0E16), Color(0xF0151020)],
                ),
              ),
            ),
            Container(
              width: maxWidth,
              height: maxHeight,
              alignment: Alignment.center,
              child: SingleChildScrollView(
                physics: compact ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 24, vertical: compact ? 4 : 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: compact ? maxWidth : 460),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.95, end: 1.05),
                        duration: const Duration(milliseconds: 1500),
                        curve: Curves.easeInOut,
                        builder: (context, scale, child) {
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.04),
                                blurRadius: compact ? 10 : 20,
                                spreadRadius: compact ? 4 : 8,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: avatar.isNotEmpty
                                ? Image.network(
                                    avatar,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Remix.user_3_line, color: Colors.white24),
                                  )
                                : const Icon(Remix.user_3_line, color: Colors.white24),
                          ),
                        ),
                      ),
                      SizedBox(height: gapLarge),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 24),
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: compact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: titleSize,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      SizedBox(height: gapSmall),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 14, vertical: compact ? 2 : 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Text(
                          nick,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: nickSize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(height: gapMedium),
                      Obx(() {
                        final restoring = isVideoRestorePending.value;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16, vertical: compact ? 5 : 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            color: restoring
                                ? const Color(0xFF5B67F1).withValues(alpha: 0.28)
                                : Colors.white.withValues(alpha: 0.08),
                            border: Border.all(
                              color: restoring
                                  ? const Color(0xFF8B94FF).withValues(alpha: 0.62)
                                  : Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: Row(
                              key: ValueKey<bool>(restoring),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (restoring)
                                  SizedBox.square(
                                    dimension: compact ? 12 : 15,
                                    child: const CircularProgressIndicator(strokeWidth: 1.8, color: Colors.white),
                                  )
                                else
                                  Icon(
                                    Remix.headphone_line,
                                    color: Colors.white.withValues(alpha: 0.85),
                                    size: compact ? 12 : 16,
                                  ),
                                SizedBox(width: compact ? 4 : 8),
                                Text(
                                  i18n(restoring ? "restoring_live_video" : "audio_only_mode"),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: badgeTextSize,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget getVideoWidget(
    int fitIndex, {
    Widget? controls,
    required List<BoxFit> fitList,
    bool trackPipSource = false,
    bool? audioOnlyOverride,
    Color surfaceColor = Colors.black,
    double? videoViewportAspectRatio,
  }) {
    // Floating/PiP callers already wrap this factory in Obx; keep their
    // dependency registered while the inner observer covers direct callers.
    videoPresentationRevision.value;
    return Obx(() {
      // Runtime audio-only state is intentionally non-reactive because native
      // mode changes are serialized. The revision publishes only the final
      // presentation state while preserving the same texture/surface element.
      videoPresentationRevision.value;
      final initialized = isInitialized.value;
      final showAudioOnly = audioOnlyOverride ?? _runtimeAudioOnly;
      final player = _currentPlayer;

      if (!initialized || _disposed || _isClosing || player == null) {
        return _buildPlaceholder(surfaceColor: surfaceColor);
      }
      final safeFitIndex = fitList.isEmpty ? 0 : fitIndex.clamp(0, fitList.length - 1);
      final boxFit = fitList.isEmpty ? BoxFit.contain : fitList[safeFitIndex];
      return RepaintBoundary(
        key: trackPipSource ? _pipSourceKey : null,
        child: PureLivePipWidget(
          child: Container(
            color: surfaceColor,
            padding: EdgeInsets.zero,
            child: KeyedSubtree(
              key: videoKey.value,
              child: Container(
                color: surfaceColor,
                width: double.infinity,
                height: double.infinity,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Offstage(
                        offstage: showAudioOnly,
                        child: Container(
                          color: surfaceColor,
                          child: buildPresentationVideoViewport(
                            aspectRatio: videoViewportAspectRatio,
                            child: _buildVideoWidget(player, boxFit),
                          ),
                        ),
                      ),
                    ),
                    if (showAudioOnly)
                      Positioned.fill(
                        child: Builder(builder: (context) => buildAudioOnlyUI(context, currentFloatRoom)),
                      ),
                    if (controls != null) Positioned.fill(child: controls),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildVideoWidget(UnifiedPlayer player, BoxFit boxFit) {
    if (!PlatformUtils.isMobile) {
      // Desktop adapters retain their native aspect and visible-viewport
      // policies, including the bounded Windows texture implementation.
      return player.getVideoWidget(fit: boxFit);
    }

    // The native player is the only fit owner for ordinary frames. media_kit,
    // FijkPlayer and BetterPlayer already size their texture/surface from the
    // decoded frame. Wrapping that view in another aspect-ratio FittedBox made
    // a transient 16:9 manager snapshot multiply with the native 9:16 fit and
    // produced the persistent narrow-strip portrait regression.
    final geometry = currentPresentationGeometry;
    return buildUnifiedMobileVideoPresentation(
      aspectRatio: geometry.contentAspectRatio,
      encodedAspectRatio: geometry.canvasAspectRatio,
      contentInsets: geometry.contentInsets,
      fit: boxFit,
      nativeVideoBuilder: (nativeFit) => player.getVideoWidget(fit: nativeFit),
    );
  }

  Widget _buildPlaceholder({Color surfaceColor = Colors.black}) {
    return Container(
      color: surfaceColor,
      child: AppStatusView(type: AppStatusType.loading, title: "", subtitle: "", iconColor: Colors.white, isMini: true),
    );
  }

  Future<void> close() {
    return _enqueuePlayerLifecycle(_closeInternal);
  }

  Future<void> _closeInternal() async {
    _sourceReadyTimer?.cancel();
    _sourceReadyTimer = null;
    _audioModeVideoWarmTimer?.cancel();
    _audioModeVideoWarmTimer = null;
    _pendingRoomReentry = null;
    _appFloatingSession = null;
    _sessionId++;
    _isClosing = true;
    isVideoRestorePending.value = false;
    // Let route/overlay widgets release their listeners before native teardown,
    // but keep the fence bounded. endOfFrame stays pending when close is called
    // while no frame is scheduled (background, tests, shutdown), which would
    // otherwise leave close/play serialized behind a Future that never ends.
    await _awaitBoundedWidgetUnmount();
    try {
      await LiveAudioService.stop();
      _useHardStopOnExit() ? await _hardDisposeInternal() : await softStop();
    } finally {
      _isClosing = false;
    }
  }

  Future<void> softStop() async {
    lineManager.reset();
    try {
      if (_stateSubject.value == PlayerState.error) {
        await _hardDisposeInternal();
        return;
      }
      await _currentPlayer?.softStop();
      _stateSubject.add(PlayerState.idle);
      _playingSubject.add(false);
    } catch (e) {
      await _hardDisposeInternal();
    }
  }

  Future<void> _hardDisposeInternal() async {
    _sourceReadyTimer?.cancel();
    _sourceReadyTimer = null;
    _sessionId++;
    lineManager.reset();
    await _clearSubscriptions();
    final player = _currentPlayer;

    if (player != null) {
      await player.hardDispose();
    }
    _currentPlayer = null;
    _runtimeEngine = null;
    _runtimeAudioOnly = false;
    _requestedAudioOnly = false;
    _nativeAudioOnly = false;
    isVideoRestorePending.value = false;
    _pendingRoomReentry = null;
    _appFloatingSession = null;
    isInitialized.value = false;
  }

  Future<void> retry() {
    return _enqueuePlayerLifecycle(() async {
      final url = _currentUrl;
      if (url == null) return;
      await _playInternal(url, _currentPlayUrls, _currentHeaders, room: currentFloatRoom, audioOnly: _runtimeAudioOnly);
    });
  }

  Future<void> _handleError(PlayerException error, {int? sessionId}) async {
    if (_disposed || _isClosing) return;
    final mySessionId = sessionId ?? _sessionId;
    if (!_isSessionValid(mySessionId)) return;
    _sourceReadyTimer?.cancel();
    _sourceReadyTimer = null;

    final request = _PendingPlayerError(error: error, sessionId: mySessionId);
    if (!_registerPlayerError(request)) {
      log('skip duplicated source-generation error: ${error.message}', name: 'PlayerManager');
      return;
    }
    if (_isHandlingError) {
      // A replacement line/engine can fail synchronously while the previous
      // recovery is still on the stack. Dropping that event left the second
      // source loading forever. Keep the newest source-generation failure and
      // drain it as soon as the current recovery step returns.
      _pendingPlayerError = request;
      return;
    }

    _isHandlingError = true;
    try {
      _PendingPlayerError? current = request;
      while (current != null && !_disposed && !_isClosing) {
        _pendingPlayerError = null;
        await _recoverOrPublishPlayerError(current);
        current = _pendingPlayerError;
      }
    } finally {
      _isHandlingError = false;
      final pending = _pendingPlayerError;
      _pendingPlayerError = null;
      if (pending != null && _isSessionValid(pending.sessionId)) {
        unawaited(_handleError(pending.error, sessionId: pending.sessionId));
      }
    }
  }

  bool _registerPlayerError(_PendingPlayerError request) {
    if (_errorDedupeSession != request.sessionId) {
      _errorDedupeSession = request.sessionId;
      _errorDedupeSignatures.clear();
    }
    return _errorDedupeSignatures.add(
      '${request.error.type.name}:${request.error.code ?? '-'}:${request.error.message}',
    );
  }

  Future<void> _recoverOrPublishPlayerError(_PendingPlayerError request) async {
    if (!_isSessionValid(request.sessionId)) return;
    final error = request.error;
    _loadingSubject.add(true);
    _stateSubject.add(PlayerState.buffering);

    try {
      final currentUrl = _currentUrl;
      if ((error.type == PlayerErrorType.network || error.type == PlayerErrorType.source) &&
          currentUrl != null &&
          _currentPlayUrls.length > 1) {
        lineManager.markFailed(currentUrl);
        if (lineManager.hasAvailable(_currentPlayUrls)) {
          final nextLine = lineManager.next(_currentPlayUrls);
          if (nextLine != currentUrl) {
            log('recover playback with next line', name: 'PlayerManager');
            await _playInternal(
              nextLine,
              _currentPlayUrls,
              _currentHeaders,
              room: currentFloatRoom,
              audioOnly: _runtimeAudioOnly,
            );
            return;
          }
        }
      }

      final activePlayer = _currentPlayer;
      final currentDecoderUrl = _currentUrl;
      if (error.type == PlayerErrorType.codec &&
          error.code?.startsWith('audio_') != true &&
          activePlayer is DecoderRecoveryAwarePlayer &&
          currentDecoderUrl != null &&
          await (activePlayer as DecoderRecoveryAwarePlayer).prepareSoftwareDecoderFallback(error)) {
        log('recover playback with software decoder on the current engine', name: 'PlayerManager');
        await _playInternal(
          currentDecoderUrl,
          _currentPlayUrls,
          _currentHeaders,
          room: currentFloatRoom,
          audioOnly: _runtimeAudioOnly,
        );
        return;
      }

      if (fallbackManager.shouldFallback(error)) {
        final activeEngine = _runtimeEngine;
        if (activeEngine != null) {
          var engineCursor = activeEngine;
          var engineError = error;
          while (true) {
            final nextEngine = await fallbackManager.fallback(engineCursor, engineError);
            if (nextEngine == engineCursor) break;
            log('recover playback with engine: ${engineCursor.name} -> ${nextEngine.name}', name: 'PlayerManager');
            _isSwitchingDueToFallback = true;
            try {
              await _switchEngineInternal(nextEngine, isManual: false, audioOnly: _runtimeAudioOnly);
            } catch (switchError, stackTrace) {
              // Initialization can fail before the replacement engine owns a
              // source. Continue through the remaining engines instead of
              // leaving the old engine marked as switching forever.
              _isSwitchingDueToFallback = false;
              engineCursor = nextEngine;
              engineError = switchError is PlayerException
                  ? switchError
                  : PlayerException(
                      message: 'Switch engine failed: $switchError',
                      type: PlayerErrorType.initialization,
                      error: switchError,
                      stackTrace: stackTrace,
                    );
              continue;
            }
            return;
          }
        }
      }
      _isSwitchingDueToFallback = false;
      _publishTerminalPlayerError(error);
    } catch (fallbackError, stackTrace) {
      _isSwitchingDueToFallback = false;
      log('player recovery exhausted: $fallbackError', name: 'PlayerManager', stackTrace: stackTrace);
      _publishTerminalPlayerError(fallbackError is PlayerException ? fallbackError : error);
    }
  }

  void _publishTerminalPlayerError(PlayerException error) {
    _sourceReadyTimer?.cancel();
    _sourceReadyTimer = null;
    hasError.value = true;
    _loadingSubject.add(false);
    _errorSubject.add(error);
    _stateSubject.add(PlayerState.error);
  }

  bool _isPlayerEventCurrent(UnifiedPlayer player, int sessionId) {
    return _isSessionValid(sessionId) && identical(player, _currentPlayer);
  }

  Future<void> _bindPlayerStreams(UnifiedPlayer player, {required int sessionId}) async {
    await _clearSubscriptions();
    _subscriptions.add(
      player.onPlaying.listen((event) {
        if (!_isPlayerEventCurrent(player, sessionId)) return;
        _playingSubject.add(event);
        if (event) {
          _sourceReadyTimer?.cancel();
          _sourceReadyTimer = null;
          hasError.value = false;
          _stateSubject.add(PlayerState.playing);
          final currentUrl = _currentUrl;
          if (currentUrl != null) lineManager.markSuccess(currentUrl);
          final runtimeEngine = _runtimeEngine;
          if (runtimeEngine != null) fallbackManager.reset(runtimeEngine);
          if (_isSwitchingDueToFallback) {
            _isSwitchingDueToFallback = false;
          }
          _scheduleActiveContentProbe();
        } else if (_stateSubject.value != PlayerState.preparing && _stateSubject.value != PlayerState.buffering) {
          _stateSubject.add(PlayerState.paused);
        }
      }),
    );
    _subscriptions.add(
      player.onLoading.listen((event) {
        if (!_isPlayerEventCurrent(player, sessionId)) return;
        _loadingSubject.add(event);
        if (event && _stateSubject.value != PlayerState.buffering) {
          _stateSubject.add(PlayerState.buffering);
        }
      }),
    );
    _subscriptions.add(
      player.onComplete.listen((event) {
        if (!_isPlayerEventCurrent(player, sessionId)) return;
        _completeSubject.add(event);
      }),
    );
    _subscriptions.add(
      player.onStateChanged.listen((event) {
        if (!_isPlayerEventCurrent(player, sessionId)) return;
        _stateSubject.add(event);
      }),
    );
    _subscriptions.add(
      player.onError.listen((error) {
        if (!_isPlayerEventCurrent(player, sessionId)) return;
        _schedulePlayerError(error, sessionId);
      }),
    );
    _subscriptions.add(
      player.width.listen((event) {
        if (!_isPlayerEventCurrent(player, sessionId)) return;
        _widthSubject.add(event);
        _scheduleVideoGeometryObservation();
      }),
    );
    _subscriptions.add(
      player.height.listen((event) {
        if (!_isPlayerEventCurrent(player, sessionId)) return;
        _heightSubject.add(event);
        _scheduleVideoGeometryObservation();
      }),
    );
  }

  Future<void> _clearSubscriptions() async {
    if (_subscriptions.isEmpty) return;
    final subscriptions = List<StreamSubscription>.of(_subscriptions);
    // Detach ownership before awaiting cancellation so a synchronous source
    // callback cannot append into the list being drained. Cancel independent
    // streams concurrently; the previous serial loop added one event-loop turn
    // per subject during every quality, line and engine transition.
    _subscriptions.clear();
    await Future.wait<void>(subscriptions.map((item) => item.cancel()));
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _sessionId++;
    _pendingPlayerError = null;
    _errorDedupeSignatures.clear();
    _isClosing = true;
    _hideTimer?.cancel();
    _sourceReadyTimer?.cancel();
    _sourceReadyTimer = null;
    _geometryObservationTimer?.cancel();
    _geometryStabilityTimer?.cancel();
    _contentProbeTimer?.cancel();
    _audioModeVideoWarmTimer?.cancel();
    await closeAppFloating();
    await _pipSubscription?.cancel();
    await _pipStateSubscription?.cancel();
    await _clearSubscriptions();
    await _hardDisposeInternal();
    await Future.wait([
      _stateSubject.close(),
      _playingSubject.close(),
      _loadingSubject.close(),
      _completeSubject.close(),
      _errorSubject.close(),
      _widthSubject.close(),
      _heightSubject.close(),
    ]);
  }
}

/// Resolves application-floating bounds from the same aspect used by the
/// normal player and Android PiP. Keeping this pure makes late portrait
/// detection and size clamping deterministic in widget-free tests.
@visibleForTesting
Size resolveAppFloatingSize({
  required double aspectRatio,
  required double maxSide,
  double minimumWidth = 120,
  double portraitHeightFactor = 1.2,
}) {
  final safeMaxSide = maxSide.isFinite && maxSide > 0 ? maxSide : 220.0;
  final safeMinimumWidth = minimumWidth.isFinite && minimumWidth > 0 ? minimumWidth : 120.0;
  final ratio = aspectRatio.isFinite && aspectRatio > 0
      ? aspectRatio.clamp(PortraitPresentationPolicy.androidPipMinimumAspectRatio, 4.0).toDouble()
      : 16 / 9;
  if (ratio >= 1) return Size(safeMaxSide, safeMaxSide / ratio);

  var height = safeMaxSide * (portraitHeightFactor.isFinite && portraitHeightFactor > 0 ? portraitHeightFactor : 1.2);
  var width = height * ratio;
  if (width < safeMinimumWidth) {
    width = safeMinimumWidth;
    height = width / ratio;
  }
  return Size(width, height);
}

/// Returns the visible contain-fitted video bounds used as Android's PiP
/// transition hint. The system expects this rectangle and the requested PiP
/// aspect to describe the same pixels.
@visibleForTesting
Rect resolveContainedVideoRect({required Rect container, required double contentAspectRatio}) {
  if (container.isEmpty || !contentAspectRatio.isFinite || contentAspectRatio <= 0) return container;
  final containerRatio = container.width / container.height;
  if ((containerRatio - contentAspectRatio).abs() <= 0.001) return container;
  if (containerRatio > contentAspectRatio) {
    final width = container.height * contentAspectRatio;
    return Rect.fromLTWH(container.left + (container.width - width) / 2, container.top, width, container.height);
  }
  final height = container.width / contentAspectRatio;
  return Rect.fromLTWH(container.left, container.top + (container.height - height) / 2, container.width, height);
}

/// Selects exactly one owner for mobile scaling.
///
/// Ordinary decoded frames are returned directly and the native player owns
/// [fit]. A confirmed active-content crop is the only case that adds a Flutter
/// viewport: the native surface fills its measured raw canvas, then one outer
/// transform applies the crop and requested fit. Keeping the builder here also
/// lets widget tests reproduce media_kit's internal FittedBox contract.
@visibleForTesting
Widget buildUnifiedMobileVideoPresentation({
  required double aspectRatio,
  required BoxFit fit,
  required Widget Function(BoxFit fit) nativeVideoBuilder,
  double? encodedAspectRatio,
  NormalizedVideoInsets contentInsets = NormalizedVideoInsets.none,
}) {
  final safeAspectRatio = aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 16 / 9;
  final safeEncodedRatio = encodedAspectRatio != null && encodedAspectRatio.isFinite && encodedAspectRatio > 0
      ? encodedAspectRatio
      : safeAspectRatio;
  final safeContentInsets = resolveConsistentVideoContentInsets(
    encodedAspectRatio: safeEncodedRatio,
    presentationAspectRatio: safeAspectRatio,
    contentInsets: contentInsets,
  );
  if (!safeContentInsets.hasCrop) return nativeVideoBuilder(fit);
  return buildUnifiedMobileVideoFrame(
    aspectRatio: safeAspectRatio,
    encodedAspectRatio: safeEncodedRatio,
    contentInsets: safeContentInsets,
    fit: fit,
    child: nativeVideoBuilder(BoxFit.fill),
  );
}

/// Builds the exceptional measured-crop viewport used by
/// [buildUnifiedMobileVideoPresentation].
@visibleForTesting
Widget buildUnifiedMobileVideoFrame({
  required double aspectRatio,
  required BoxFit fit,
  required Widget child,
  double? encodedAspectRatio,
  NormalizedVideoInsets contentInsets = NormalizedVideoInsets.none,
}) {
  final safeAspectRatio = aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 16 / 9;
  final safeEncodedRatio = encodedAspectRatio != null && encodedAspectRatio.isFinite && encodedAspectRatio > 0
      ? encodedAspectRatio
      : safeAspectRatio;
  const basis = 1000.0;
  final safeContentInsets = resolveConsistentVideoContentInsets(
    encodedAspectRatio: safeEncodedRatio,
    presentationAspectRatio: safeAspectRatio,
    contentInsets: contentInsets,
  );
  final useActiveCrop = safeContentInsets.hasCrop;
  // Always size the native texture from its actual canvas. Presentation ratio
  // may come from platform metadata, a room override or visual content, none of
  // which is permission to stretch the decoded pixels. A measured crop changes
  // only the viewport below.
  final rawWidth = basis * safeEncodedRatio;
  final rawHeight = basis;
  final viewportWidth = useActiveCrop ? rawWidth * safeContentInsets.widthFraction : rawWidth;
  final viewportHeight = useActiveCrop ? rawHeight * safeContentInsets.heightFraction : rawHeight;
  final videoFrame = useActiveCrop
      ? SizedBox(
          key: const ValueKey('active-video-content-viewport'),
          width: viewportWidth,
          height: viewportHeight,
          child: ClipRect(
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: -rawWidth * safeContentInsets.left,
                  top: -rawHeight * safeContentInsets.top,
                  width: rawWidth,
                  height: rawHeight,
                  child: child,
                ),
              ],
            ),
          ),
        )
      : SizedBox(width: rawWidth, height: rawHeight, child: child);
  return ClipRect(
    child: FittedBox(fit: fit, clipBehavior: Clip.hardEdge, child: videoFrame),
  );
}

/// Constrains only the decoded-video layer while leaving sibling controls on
/// the complete presentation surface.
///
/// This is intentionally outside [UnifiedPlayer]. Fullscreen portrait layout
/// is a route-local concern; writing a special fit into the shared native
/// player/controller lets inactive normal, fullscreen and floating trees race
/// over one adapter state during transitions.
@visibleForTesting
Widget buildPresentationVideoViewport({required Widget child, double? aspectRatio}) {
  if (aspectRatio == null || !aspectRatio.isFinite || aspectRatio <= 0) return child;
  return Center(
    child: AspectRatio(key: const ValueKey('presentation-video-viewport'), aspectRatio: aspectRatio, child: child),
  );
}

class _AudioServiceRequest {
  const _AudioServiceRequest({
    required this.player,
    required this.audioOnly,
    required this.room,
    required this.sessionId,
  });

  final UnifiedPlayer player;
  final bool audioOnly;
  final LiveRoom? room;
  final int sessionId;
}

class _PendingPlayerError {
  const _PendingPlayerError({required this.error, required this.sessionId});

  final PlayerException error;
  final int sessionId;
}

/// Immutable presentation state transferred from the popped live-room route to
/// the route opened from the in-app floating player.
///
/// The native player remains owned by [PlayerManager]. This object deliberately
/// contains only room/UI metadata, so a new page can attach new controllers and
/// listeners without reopening the stream or retaining the old page owner.
class RoomSessionSnapshot {
  const RoomSessionSnapshot({
    required this.room,
    required this.qualities,
    required this.currentQuality,
    required this.playUrls,
    required this.currentLineIndex,
    required this.headers,
    required this.isAudioOnly,
    required this.isLiving,
    this.dataSource = '',
    this.hasUseDefaultResolution = true,
  });

  final LiveRoom room;
  final List<LivePlayQuality> qualities;
  final int currentQuality;
  final List<String> playUrls;
  final int currentLineIndex;
  final Map<String, String> headers;
  final bool isAudioOnly;
  final bool isLiving;
  final String dataSource;
  final bool hasUseDefaultResolution;

  RoomSessionSnapshot copyWith({
    LiveRoom? room,
    List<LivePlayQuality>? qualities,
    int? currentQuality,
    List<String>? playUrls,
    int? currentLineIndex,
    Map<String, String>? headers,
    bool? isAudioOnly,
    bool? isLiving,
    String? dataSource,
    bool? hasUseDefaultResolution,
  }) {
    return RoomSessionSnapshot(
      room: room ?? this.room,
      qualities: qualities ?? this.qualities,
      currentQuality: currentQuality ?? this.currentQuality,
      playUrls: playUrls ?? this.playUrls,
      currentLineIndex: currentLineIndex ?? this.currentLineIndex,
      headers: headers ?? this.headers,
      isAudioOnly: isAudioOnly ?? this.isAudioOnly,
      isLiving: isLiving ?? this.isLiving,
      dataSource: dataSource ?? this.dataSource,
      hasUseDefaultResolution: hasUseDefaultResolution ?? this.hasUseDefaultResolution,
    );
  }
}
