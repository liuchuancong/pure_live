import 'dart:io';
import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'player_pool.dart';
import 'line_fallback_manager.dart';
import '../models/player_state.dart';
import 'preload_player_manager.dart';
import '../models/player_engine.dart';
import 'engine_fallback_manager.dart';

import 'package:floating/floating.dart';
import 'package:flutter/scheduler.dart';

import '../models/player_exception.dart';

import 'package:remixicon/remixicon.dart';

import '../models/player_error_type.dart';

import 'package:rxdart/rxdart.dart' hide Rx;
import 'package:pure_live/common/index.dart';

import '../interface/unified_player_interface.dart';

import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/player/utils/fullscreen.dart';
import 'package:flutter_floating/flutter_floating.dart';
import 'package:pure_live/player/utils/player_consts.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/player/utils/pip_window_widget.dart';
import 'package:pure_live/player/core/live_audio_service.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/compact_danmaku_overlay.dart';

class PlayerManager {
  final PlayerPool playerPool;
  final EngineFallbackManager fallbackManager;
  final PreloadPlayerManager preloadManager;
  final LineFallbackManager lineManager;
  final Duration audioModeSwitchTimeout;

  int _sessionId = 0;
  bool _isClosing = false;

  PlayerManager({
    required this.playerPool,
    required this.fallbackManager,
    required this.preloadManager,
    required this.lineManager,
    this.audioModeSwitchTimeout = const Duration(seconds: 5),
  }) {
    _pipStateSubscription = isInPip.listen((value) {
      GlobalPlayerState.to.isPipMode.value = value;
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

  String? _currentUrl;
  List<String> _currentPlayUrls = [];
  Map<String, String> _currentHeaders = {};

  final RxBool isInitialized = false.obs;
  final RxBool hasError = false.obs;
  final RxBool isVerticalVideo = false.obs;
  final RxBool isInPip = false.obs;
  final RxBool isPipPreparing = false.obs;
  final RxBool isFloating = false.obs;
  final RxBool isHovered = false.obs;
  final RxInt videoFitIndex = 0.obs;
  Rx<ValueKey> videoKey = Rx<ValueKey>(const ValueKey("video_0"));

  final _stateSubject = BehaviorSubject<PlayerState>.seeded(PlayerState.idle);
  final _playingSubject = BehaviorSubject<bool>.seeded(false);
  final _loadingSubject = BehaviorSubject<bool>.seeded(false);
  final _completeSubject = BehaviorSubject<bool>.seeded(false);
  final _errorSubject = PublishSubject<PlayerException>();
  final _widthSubject = BehaviorSubject<int?>.seeded(null);
  final _heightSubject = BehaviorSubject<int?>.seeded(null);

  final List<StreamSubscription> _subscriptions = [];
  StreamSubscription<PiPStatus>? _pipSubscription;
  StreamSubscription<bool>? _pipStateSubscription;

  bool _disposed = false;
  bool _isSwitchingDueToFallback = false;
  bool _isHandlingError = false;
  static const String _floatTag = "global_video_player";
  Timer? _hideTimer;
  late Floating floating;
  LiveRoom? currentFloatRoom;
  VideoController? _videoController;
  final List<Future<void> Function()> _floatingResourceDisposers = <Future<void> Function()>[];
  Future<void>? _floatingCleanup;
  bool _appFloatingPrepared = false;
  bool _pipTransitionInFlight = false;
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

  void prepareAppFloating({required Future<void> Function() onClose}) {
    // Keep every pending owner until the overlay and popped route have fully
    // unmounted. Releasing a previous owner here recreated the same late-Obx
    // unsubscribe race when navigation happened unusually quickly.
    _floatingResourceDisposers.add(onClose);
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

  double get currentVideoRatio {
    final w = _widthSubject.value?.toDouble() ?? 1920;
    final h = _heightSubject.value?.toDouble() ?? 1080;
    if (w <= 0 || h <= 0) return 16 / 9;
    return w / h;
  }

  Future<void> initialize({PlayerEngine engine = PlayerEngine.mediaKit, bool audioOnly = false}) async {
    if (_disposed) return;
    _stateSubject.add(PlayerState.initializing);
    try {
      _defaultEngine = engine;
      _runtimeEngine = engine;
      _currentPlayer = await playerPool.getPlayer(engine, audioOnly: audioOnly);
      _runtimeAudioOnly = audioOnly;
      await _bindPlayerStreams(_currentPlayer!);
      await LiveAudioService.setPlayer(_currentPlayer!, audioOnly: audioOnly);
      if (Platform.isAndroid) {
        floating = Floating();
        _pipSubscription?.cancel();
        _pipSubscription = floating.pipStatusStream.listen((status) {
          isInPip.value = status == PiPStatus.enabled;
        });
      }
      isInitialized.value = true;
      _stateSubject.add(PlayerState.initialized);
    } catch (e, s) {
      hasError.value = true;
      final exception = PlayerException(
        message: 'Initialize player failed',
        type: PlayerErrorType.initialization,
        error: e,
        stackTrace: s,
      );
      _errorSubject.add(exception);
      _stateSubject.add(PlayerState.error);
      throw exception;
    }
  }

  Future<void> play(
    String url,
    List<String> playUrls,
    Map<String, String> headers, {
    LiveRoom? room,
    bool audioOnly = false,
  }) async {
    if (_disposed || _isClosing) return;
    final mySessionId = ++_sessionId;

    if (room?.roomId != currentFloatRoom?.roomId) {
      lineManager.reset();
    }
    if (_currentPlayer == null || _runtimeEngine == null) {
      final String savedKey = SettingsService.to.player.videoPlayerKey.v;
      final String validKey = PlayerConsts.engines.containsKey(savedKey) ? savedKey : PlayerConsts.defaultKey;
      _defaultEngine = PlayerConsts.engines[validKey]!;
      _runtimeEngine = _defaultEngine;
      log('No current player, initializing with default engine: $_defaultEngine', name: 'PlayerManager');
      await initialize(engine: _defaultEngine!, audioOnly: audioOnly);
    } else if (_runtimeEngine != _defaultEngine && !_isSwitchingDueToFallback) {
      await switchEngine(_defaultEngine!, isManual: false, audioOnly: audioOnly);
    } else if (_runtimeAudioOnly != audioOnly) {
      await setAudioOnlyMode(audioOnly);
    }

    if (!_isSessionValid(mySessionId)) return;

    final player = _currentPlayer;
    if (player == null) {
      throw PlayerException(message: 'Current player is null', type: PlayerErrorType.lifecycle);
    }

    // Every bundled player has a native audio-only path.  Opening the original
    // live URL directly avoids a second FFmpeg decode pipeline and removes the
    // previous fixed two-second wait / 30-second pipe timeout.
    final String targetUrl = url;
    final List<String> targetPlayUrls = List.from(playUrls);

    _currentUrl = targetUrl;
    _currentPlayUrls = targetPlayUrls;
    _currentHeaders = headers;
    currentFloatRoom = room;
    hasError.value = false;

    try {
      _stateSubject.add(PlayerState.preparing);
      await player.setDataSource(targetUrl, targetPlayUrls, headers, room: room, audioOnly: audioOnly);
      if (!_isSessionValid(mySessionId)) return;

      // Desktop player adapters do not all restore the per-room volume in
      // setDataSource. Apply it centrally so every engine starts consistently.
      if (PlatformUtils.isDesktop && room != null) {
        await player.setVolume(room.getSavedVolume().clamp(0.0, 1.0));
      }
      if (!_isSessionValid(mySessionId)) return;

      await LiveAudioService.setPlayer(player, audioOnly: audioOnly);
      await LiveAudioService.start(room!.roomId!, room.nick ?? "", room.title ?? "", room.avatar);
      videoKey.value = ValueKey("video_${DateTime.now().millisecondsSinceEpoch}");
      _stateSubject.add(PlayerState.ready);
    } on PlayerException catch (e) {
      if (!_isHandlingError && _isSessionValid(mySessionId)) {
        await _handleError(e, sessionId: mySessionId);
      }
    } catch (e, s) {
      log(e.toString());
      if (!_isHandlingError && _isSessionValid(mySessionId)) {
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

  Future<void> replay() async {
    if (_currentUrl == null) return;
    await play(_currentUrl!, _currentPlayUrls, _currentHeaders, room: currentFloatRoom, audioOnly: _runtimeAudioOnly);
  }

  /// Changes the current room between video and audio-only in place.
  ///
  /// Reopening the whole stream made the UI wait for native stop/dispose,
  /// player initialization, AudioService binding and CDN setup. A stalled
  /// native future therefore left the room on an endless loading indicator.
  Future<void> setAudioOnlyMode(bool audioOnly) async {
    if (_disposed || _isClosing || _runtimeAudioOnly == audioOnly) return;
    final player = _currentPlayer;
    if (player == null) {
      throw PlayerException(message: 'Current player is null', type: PlayerErrorType.lifecycle);
    }

    final previous = _runtimeAudioOnly;
    try {
      await player.setAudioOnly(audioOnly).timeout(audioModeSwitchTimeout);
      if (!identical(_currentPlayer, player) || _disposed || _isClosing) return;

      _runtimeAudioOnly = audioOnly;
      await LiveAudioService.setPlayer(player, audioOnly: audioOnly).timeout(audioModeSwitchTimeout);
      videoKey.value = ValueKey("video_${DateTime.now().millisecondsSinceEpoch}");
    } catch (error, stackTrace) {
      // Restore both the native track and the UI state. The rollback is also
      // bounded so a broken platform call never locks the headphone button.
      try {
        await player.setAudioOnly(previous).timeout(audioModeSwitchTimeout);
      } catch (_) {}
      try {
        await LiveAudioService.setPlayer(player, audioOnly: previous).timeout(audioModeSwitchTimeout);
      } catch (_) {}
      _runtimeAudioOnly = previous;
      videoKey.value = ValueKey("video_${DateTime.now().millisecondsSinceEpoch}");
      throw PlayerException(
        message: error is TimeoutException ? 'Audio mode switch timed out' : 'Audio mode switch failed',
        type: PlayerErrorType.lifecycle,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> switchEngine(PlayerEngine engine, {bool isManual = false, bool? audioOnly}) async {
    if (_disposed || _isClosing) return;
    if (_runtimeEngine == engine && _currentPlayer != null) return;
    try {
      final oldPlayer = _currentPlayer;
      final oldEngine = _runtimeEngine;
      await _clearSubscriptions();
      final targetAudioOnly = audioOnly ?? _runtimeAudioOnly;
      final newPlayer = await playerPool.getPlayer(engine, audioOnly: targetAudioOnly);
      _currentPlayer = newPlayer;
      _runtimeEngine = engine;
      _runtimeAudioOnly = targetAudioOnly;
      if (isManual) _defaultEngine = engine;
      log('Switch engine to $engine', name: 'PlayerManager');
      await _bindPlayerStreams(newPlayer);
      await LiveAudioService.setPlayer(_currentPlayer!, audioOnly: targetAudioOnly);
      if (oldPlayer != null && oldEngine != null) {
        await _safeDestroyPlayer(oldPlayer, oldEngine);
      }
      videoKey.value = ValueKey("video_${DateTime.now().millisecondsSinceEpoch}");
    } catch (e, s) {
      final exception = PlayerException(
        message: 'Switch engine failed',
        type: PlayerErrorType.lifecycle,
        error: e,
        stackTrace: s,
      );
      _errorSubject.add(exception);
      rethrow;
    }
  }

  Future<void> _safeDestroyPlayer(UnifiedPlayer player, PlayerEngine engine) async {
    try {
      await player.hardDispose();
      await playerPool.removeFromCache(engine);
    } catch (e, s) {
      log("destroy player error: $e", stackTrace: s);
    }
  }

  Future<void> preload(String url, List<String> playUrls, Map<String, String> headers) async {
    if (_disposed || _isClosing) return;
    final standby = await playerPool.getPlayer(_runtimeEngine!);
    await preloadManager.preload(standby, url, playUrls, headers);
  }

  Future<void> seamlessSwitch() async {
    if (_disposed || _isClosing) return;
    await preloadManager.switchToStandby();
    final player = preloadManager.current;
    if (player == null) return;
    await _clearSubscriptions();
    _currentPlayer = player;
    await _bindPlayerStreams(player);
  }

  Future<void> togglePlayPause() async {
    if (_currentPlayer == null) return;
    if (isPlayingNow) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> pause() async => await _currentPlayer?.pause();
  Future<void> resume() async => await _currentPlayer?.play();

  Future<void> stop() async {
    await close();
    await closeAppFloating();
  }

  Future<void> setVolume(double volume) async {
    await _currentPlayer?.setVolume(volume.clamp(0.0, 1.0));
  }

  void changeVideoFit(int index) => videoFitIndex.value = index;

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
        final sourceRectHint = _currentPipSourceRect();
        isPipPreparing.value = true;
        await SchedulerBinding.instance.endOfFrame;

        final rational = isVerticalVideo.value ? const Rational.vertical() : const Rational.landscape();
        final result = await floating.enable(ImmediatePiP(aspectRatio: rational, sourceRectHint: sourceRectHint));
        if (result == PiPStatus.enabled) isInPip.value = true;
      } finally {
        isPipPreparing.value = false;
        _pipTransitionInFlight = false;
      }
    } else if (Platform.isWindows) {
      await WindowService().enterWinPiP(currentVideoRatio);
      isInPip.value = true;
    }
  }

  math.Rectangle<int>? _currentPipSourceRect() {
    final context = _pipSourceKey.currentContext;
    final renderObject = context?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    final origin = renderObject.localToGlobal(Offset.zero);
    final ratio = View.of(context!).devicePixelRatio;
    final left = (origin.dx * ratio).round();
    final top = (origin.dy * ratio).round();
    final width = (renderObject.size.width * ratio).round();
    final height = (renderObject.size.height * ratio).round();
    if (width <= 0 || height <= 0) return null;
    return math.Rectangle<int>(left, top, width, height);
  }

  Future<void> exitPip() async {
    if (Platform.isWindows) {
      await WindowService().exitWinPiP();
      GlobalPlayerState.to.reset();
      isInPip.value = false;
    }
  }

  void showAppFloating() {
    // A delayed show is scheduled after the room route pops. Re-entering a
    // room during that delay closes the prepared session and must prevent the
    // stale callback from mounting the old player on top of the new route.
    if (!_appFloatingPrepared || _floatingCleanup != null) return;
    floatingManager.disposeFloating(_floatTag);
    _hideTimer?.cancel();
    double maxSide = Platform.isWindows ? 350 : 220;
    double ratio = currentVideoRatio;
    double floatWidth;
    double floatHeight;
    if (ratio >= 1) {
      floatWidth = maxSide;
      floatHeight = maxSide / ratio;
    } else {
      floatHeight = maxSide * 1.2;
      floatWidth = floatHeight * ratio;
      if (floatWidth < 120) {
        floatWidth = 120;
        floatHeight = floatWidth / ratio;
      }
    }

    void resetHideTimer() {
      if (Platform.isAndroid || Platform.isIOS) {
        _hideTimer?.cancel();
        _hideTimer = Timer(const Duration(seconds: 3), () {
          isHovered.value = false;
        });
      }
    }

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
          child: Container(
            width: floatWidth,
            height: floatHeight,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.black),
            child: Stack(
              children: [
                Positioned.fill(
                  child: getVideoWidget(videoFitIndex.value, fitList: SettingsService.to.player.videoFitArray),
                ),
                Positioned.fill(child: _buildCompactDanmaku()),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      final room = currentFloatRoom;
                      await closeAppFloating();
                      if (room != null) {
                        await AppNavigator.toLiveRoomDetail(liveRoom: room);
                      }
                    },
                    child: const SizedBox.expand(),
                  ),
                ),
                Center(
                  child: AnimatedOpacity(
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
          ),
        ),
        right: 50,
        top: 100,
        slideType: FloatingEdgeType.onRightAndTop,
        params: FloatingParams(isSnapToEdge: false, snapToEdgeSpace: 10, dragOpacity: 0.8),
      ),
    );
    floatingManager.getFloating(_floatTag).open(Get.context!);
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
      await SchedulerBinding.instance.endOfFrame;

      if (hadOverlay && floatingManager.containsFloating(_floatTag)) {
        floatingManager.disposeFloating(_floatTag);
      }
      await _releaseAppFloatingResources();
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
                child: getVideoWidget(videoFitIndex.value, fitList: SettingsService.to.player.videoFitArray),
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

        return Container(
          width: maxWidth,
          height: maxHeight,
          alignment: Alignment.center,
          color: Colors.transparent,
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
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16, vertical: compact ? 5 : 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: Colors.white.withValues(alpha: 0.08),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Remix.headphone_line,
                          color: Colors.white.withValues(alpha: 0.85),
                          size: compact ? 12 : 16,
                        ),
                        SizedBox(width: compact ? 4 : 8),
                        Text(
                          i18n("audio_only_mode"),
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget getVideoWidget(int fitIndex, {Widget? controls, required List<BoxFit> fitList, bool trackPipSource = false}) {
    return RepaintBoundary(
      key: trackPipSource ? _pipSourceKey : null,
      child: PureLivePipWidget(
        child: Container(
          color: Colors.black,
          padding: const EdgeInsets.all(0),
          child: StreamBuilder<bool>(
            stream: onPlaying,
            initialData: isPlayingNow,
            builder: (context, snapshot) {
              // Capture one player reference for the whole build. An async
              // teardown may clear _currentPlayer between the outer check and
              // the nested width/height builder; reading the mutable field
              // again used to throw a null-check exception and replace the
              // complete player area (including controls) with ErrorWidget.
              final activePlayer = _currentPlayer;
              if (activePlayer == null) {
                return _buildPlaceholder();
              }
              final safeFitIndex = fitList.isEmpty ? 0 : fitIndex.clamp(0, fitList.length - 1);
              final boxFit = fitList.isEmpty ? BoxFit.contain : fitList[safeFitIndex];
              final content = KeyedSubtree(
                key: videoKey.value,
                child: Container(
                  color: Colors.black,
                  width: double.infinity,
                  height: double.infinity,
                  child: Stack(
                    children: [
                      if (_runtimeAudioOnly)
                        buildAudioOnlyUI(context, currentFloatRoom)
                      else
                        Positioned.fill(
                          child: Container(
                            color: Colors.black,
                            child: FittedBox(
                              fit: boxFit,
                              clipBehavior: Clip.hardEdge,
                              child: StreamBuilder<List<int?>>(
                                stream: CombineLatestStream.list([width, height]),
                                builder: (context, snapshot) {
                                  final vW = snapshot.data?[0]?.toDouble() ?? 1920.0;
                                  final vH = snapshot.data?[1]?.toDouble() ?? 1080.0;
                                  return SizedBox(width: vW, height: vH, child: activePlayer.getVideoWidget());
                                },
                              ),
                            ),
                          ),
                        ),
                      if (controls != null) Positioned.fill(child: controls),
                    ],
                  ),
                ),
              );
              // The same player surface is used in and out of PiP. Wrapping
              // identical children in PiPSwitcher rebuilt an AnimatedSwitcher
              // exactly when Android started its resize animation, adding a
              // needless transition on the hottest frame.
              return content;
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.black,
      child: AppStatusView(type: AppStatusType.loading, title: "", subtitle: "", iconColor: Colors.white),
    );
  }

  Future<void> close() async {
    _sessionId++;
    _isClosing = true;
    await LiveAudioService.stop();
    SettingsService.to.player.useHardStopOnExit.v ? await hardDispose() : await softStop();
    _isClosing = false;
  }

  Future<void> softStop() async {
    lineManager.reset();
    try {
      if (_stateSubject.value == PlayerState.error) {
        await hardDispose();
        return;
      }
      await _currentPlayer?.softStop();
      _stateSubject.add(PlayerState.idle);
      _playingSubject.add(false);
    } catch (e) {
      await hardDispose();
    }
  }

  Future<void> hardDispose() async {
    _sessionId++;
    lineManager.reset();
    await _clearSubscriptions();
    if (_runtimeEngine != null) {
      await playerPool.removeFromCache(_runtimeEngine!);
    }
    _currentPlayer = null;
    _runtimeEngine = null;
    _runtimeAudioOnly = false;
    isInitialized.value = false;
  }

  Future<void> retry() async {
    await replay();
  }

  Future<void> _handleError(PlayerException error, {int? sessionId}) async {
    if (_disposed || _isClosing) return;
    if (_isHandlingError) {
      log("skip duplicated error handling: ${error.message}");
      return;
    }
    final mySessionId = sessionId ?? _sessionId;
    if (!_isSessionValid(mySessionId)) return;

    _isHandlingError = true;
    try {
      hasError.value = true;
      _errorSubject.add(error);
      _stateSubject.add(PlayerState.error);

      bool lineSwitched = false;
      if ((error.type == PlayerErrorType.network || error.type == PlayerErrorType.source) &&
          _currentPlayUrls.length > 1) {
        lineManager.markFailed(_currentUrl!);
        if (!lineManager.hasAvailable(_currentPlayUrls)) {
          log("no available lines, fallback engine");
        } else {
          final nextLine = lineManager.next(_currentPlayUrls);
          if (nextLine != _currentUrl) {
            lineSwitched = true;
            log("switch line => $nextLine");
            await Future.delayed(const Duration(seconds: 2));
            if (!_isSessionValid(mySessionId)) return;
            await play(nextLine, _currentPlayUrls, _currentHeaders, room: currentFloatRoom);
            return;
          }
        }
      }

      log(error.type.toString());
      if (!lineSwitched && fallbackManager.shouldFallback(error)) {
        final nextEngine = await fallbackManager.fallback(_runtimeEngine!, error);
        if (nextEngine == _runtimeEngine) {
          log("skip fallback: nextEngine(${nextEngine.name}) == currentEngine(${_runtimeEngine?.name})");
          return;
        }
        log(
          "fallback engine: "
          "${_runtimeEngine?.name} -> ${nextEngine.name}",
        );
        _isSwitchingDueToFallback = true;
        await Future.delayed(const Duration(milliseconds: 1200));
        if (!_isSessionValid(mySessionId)) return;
        await switchEngine(nextEngine, isManual: false);
        await Future.delayed(const Duration(milliseconds: 500));
        if (!_isSessionValid(mySessionId)) return;
        await replay();
        return;
      }
    } catch (e, s) {
      log("_handleError failed: $e", stackTrace: s);
    } finally {
      _isHandlingError = false;
    }
  }

  Future<void> _bindPlayerStreams(UnifiedPlayer player) async {
    await _clearSubscriptions();
    _subscriptions.add(
      player.onPlaying.listen((event) async {
        _playingSubject.add(event);
        if (event) {
          hasError.value = false;
          _stateSubject.add(PlayerState.playing);
          if (_isSwitchingDueToFallback) {
            _isSwitchingDueToFallback = false;
          }
        } else {
          _stateSubject.add(PlayerState.paused);
        }
      }),
    );
    _subscriptions.add(
      player.onLoading.listen((event) {
        _loadingSubject.add(event);
        if (event && _stateSubject.value != PlayerState.buffering) {
          _stateSubject.add(PlayerState.buffering);
        }
      }),
    );
    _subscriptions.add(
      player.onComplete.listen((event) {
        _completeSubject.add(event);
      }),
    );
    _subscriptions.add(
      player.onStateChanged.listen((event) {
        _stateSubject.add(event);
      }),
    );
    _subscriptions.add(
      player.onError.listen((error) {
        if (!_isHandlingError) {
          unawaited(_handleError(error));
        }
      }),
    );
    _subscriptions.add(
      player.width.listen((event) {
        _widthSubject.add(event);
      }),
    );
    _subscriptions.add(
      player.height.listen((event) {
        _heightSubject.add(event);
      }),
    );
    _subscriptions.add(
      CombineLatestStream.combine2<int?, int?, bool>(
        width.where((w) => w != null && w > 0),
        height.where((h) => h != null && h > 0),
        (w, h) => h! >= w!,
      ).distinct().listen((event) {
        isVerticalVideo.value = event;
      }),
    );
  }

  Future<void> _clearSubscriptions() async {
    if (_subscriptions.isEmpty) return;
    for (final item in _subscriptions.toList()) {
      await item.cancel();
    }
    _subscriptions.clear();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _sessionId++;
    _isClosing = true;
    _hideTimer?.cancel();
    await closeAppFloating();
    await _pipSubscription?.cancel();
    await _pipStateSubscription?.cancel();
    await _clearSubscriptions();
    await playerPool.disposeAll();
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
