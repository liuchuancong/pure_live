import 'dart:io';
import 'dart:async';
import 'dart:developer';
import 'player_pool.dart';
import 'package:get/get.dart';
import 'line_fallback_manager.dart';
import '../models/player_state.dart';
import 'preload_player_manager.dart';
import '../models/player_engine.dart';
import 'engine_fallback_manager.dart';
import 'player_error_dispatcher.dart';
import 'package:floating/floating.dart';
import '../models/player_exception.dart';
import '../models/player_error_type.dart';
import 'package:rxdart/rxdart.dart' hide Rx;
import 'package:audio_service/audio_service.dart';
import '../interface/unified_player_interface.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/player/utils/fullscreen.dart';
import 'package:flutter_floating/flutter_floating.dart';
import 'package:pure_live/player/core/audio_service.dart';
import 'package:pure_live/player/utils/player_consts.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/common/index.dart' hide PlayerState;
import 'package:pure_live/modules/live_play/player_state.dart';
import 'package:pure_live/common/global/platform/background_server.dart';

class PlayerManager {
  final PlayerPool playerPool;

  final EngineFallbackManager fallbackManager;

  final PreloadPlayerManager preloadManager;

  final LineFallbackManager lineManager;
  late MyAudioHandler audioHandler;
  PlayerManager({
    required this.playerPool,
    required this.fallbackManager,
    required this.preloadManager,
    required this.lineManager,
  }) {
    isInPip.listen((value) {
      GlobalPlayerState.to.isPipMode.value = value;
    });
  }

  // =========================
  // player
  // =========================

  UnifiedPlayer? _currentPlayer;

  PlayerEngine? _runtimeEngine;

  PlayerEngine? _defaultEngine;

  // =========================
  // play info
  // =========================

  String? _currentUrl;

  List<String> _currentPlayUrls = [];

  Map<String, String> _currentHeaders = {};

  // =========================
  // rx state
  // =========================

  final RxBool isInitialized = false.obs;

  final RxBool hasError = false.obs;

  final RxBool isVerticalVideo = false.obs;

  final RxBool isInPip = false.obs;

  final RxBool isFloating = false.obs;

  final RxBool isHovered = false.obs;

  final RxInt videoFitIndex = 0.obs;

  Rx<ValueKey> videoKey = Rx<ValueKey>(const ValueKey("video_0"));

  // =========================
  // stream state
  // =========================

  final _stateSubject = BehaviorSubject<PlayerState>.seeded(PlayerState.idle);

  final _playingSubject = BehaviorSubject<bool>.seeded(false);

  final _loadingSubject = BehaviorSubject<bool>.seeded(false);

  final _completeSubject = BehaviorSubject<bool>.seeded(false);

  final _errorSubject = PublishSubject<PlayerException>();

  final _widthSubject = BehaviorSubject<int?>.seeded(null);

  final _heightSubject = BehaviorSubject<int?>.seeded(null);

  // =========================
  // subscriptions
  // =========================

  final List<StreamSubscription> _subscriptions = [];

  StreamSubscription<PiPStatus>? _pipSubscription;

  // =========================
  // misc
  // =========================

  bool _disposed = false;

  bool _isSwitchingDueToFallback = false;

  int _errorCount = 0;

  DateTime? _lastErrorTime;

  static const int _maxErrorCount = 5;

  static const Duration _errorResetDuration = Duration(seconds: 10);

  static const String _floatTag = "global_video_player";

  Timer? _hideTimer;

  late Floating floating;

  LiveRoom? currentFloatRoom;

  // =========================
  // getter
  // =========================

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

  double get currentVideoRatio {
    final w = _widthSubject.value?.toDouble() ?? 1920;

    final h = _heightSubject.value?.toDouble() ?? 1080;

    if (w <= 0 || h <= 0) {
      return 16 / 9;
    }

    return w / h;
  }

  // =========================
  // initialize
  // =========================

  Future<void> initialize({PlayerEngine engine = PlayerEngine.mediaKit}) async {
    if (_disposed) return;

    _stateSubject.add(PlayerState.initializing);

    try {
      _defaultEngine = engine;

      _runtimeEngine = engine;

      _currentPlayer = await playerPool.getPlayer(engine);

      _bindPlayerStreams(_currentPlayer!);

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

  // =========================
  // play
  // =========================

  Future<void> play(String url, List<String> playUrls, Map<String, String> headers, {LiveRoom? room}) async {
    if (_disposed) return;

    if (_currentPlayer == null || _runtimeEngine == null) {
      final settings = Get.find<SettingsService>();

      _defaultEngine = PlayerEngine.values[settings.videoPlayerIndex.value];

      _runtimeEngine = _defaultEngine;

      await initialize(engine: _defaultEngine!);
    } else if (_runtimeEngine != _defaultEngine && !_isSwitchingDueToFallback) {
      await switchEngine(_defaultEngine!, isManual: false);
    }

    final player = _currentPlayer;

    if (player == null) {
      throw PlayerException(message: 'Current player is null', type: PlayerErrorType.lifecycle);
    }

    _currentUrl = url;

    _currentPlayUrls = playUrls;

    _currentHeaders = headers;

    currentFloatRoom = room;

    hasError.value = false;

    try {
      _stateSubject.add(PlayerState.preparing);

      await player.setDataSource(url, playUrls, headers);

      if (PlatformUtils.isAndroid) {
        if (_runtimeEngine == PlayerEngine.exo) {
          if (room != null) {
            final mediaItem = MediaItem(
              id: room.roomId ?? "",
              title: room.title ?? "",
              artist: room.nick ?? "",
              album: room.platform,
              isLive: true,
              artUri: Uri.tryParse(room.cover ?? ""),
            );

            audioHandler.mediaItem.add(mediaItem);
          }
        } else {
          if (room != null) {
            BackgroundService.startService(room.nick ?? "", room.title ?? "");
          }
        }
      }

      videoKey.value = ValueKey("video_${DateTime.now().millisecondsSinceEpoch}");

      _stateSubject.add(PlayerState.ready);
    } on PlayerException catch (e) {
      await _handleError(e);
    } catch (e, s) {
      final exception = PlayerException(message: 'Play failed', type: PlayerErrorType.unknown, error: e, stackTrace: s);

      await _handleError(exception);
    } finally {
      _isSwitchingDueToFallback = false;
    }
  }

  // =========================
  // replay
  // =========================

  Future<void> replay() async {
    if (_currentUrl == null) return;

    await play(_currentUrl!, _currentPlayUrls, _currentHeaders, room: currentFloatRoom);
  }

  // =========================
  // switch engine
  // =========================

  Future<void> switchEngine(PlayerEngine engine, {bool isManual = false}) async {
    if (_disposed) return;

    if (_runtimeEngine == engine && _currentPlayer != null) {
      return;
    }

    try {
      final oldPlayer = _currentPlayer;

      final oldEngine = _runtimeEngine;

      await _clearSubscriptions();

      final newPlayer = await playerPool.getPlayer(engine);

      _currentPlayer = newPlayer;

      _runtimeEngine = engine;

      if (isManual) {
        _defaultEngine = engine;
      }

      _bindPlayerStreams(newPlayer);

      if (oldPlayer != null && oldEngine != null) {
        unawaited(_safeDestroyPlayer(oldPlayer, oldEngine));
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

  // =========================
  // preload
  // =========================

  Future<void> preload(String url, List<String> playUrls, Map<String, String> headers) async {
    if (_disposed) return;

    final standby = await playerPool.getPlayer(_runtimeEngine!);

    await preloadManager.preload(standby, url, playUrls, headers);
  }

  // =========================
  // seamless switch
  // =========================

  Future<void> seamlessSwitch() async {
    if (_disposed) return;

    await preloadManager.switchToStandby();

    final player = preloadManager.current;

    if (player == null) return;

    await _clearSubscriptions();

    _currentPlayer = player;

    _bindPlayerStreams(player);
  }

  // =========================
  // play control
  // =========================

  Future<void> togglePlayPause() async {
    if (_currentPlayer == null) return;

    if (isPlayingNow) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> pause() async {
    await _currentPlayer?.pause();
  }

  Future<void> resume() async {
    await _currentPlayer?.play();
  }

  Future<void> stop() async {
    await _currentPlayer?.stop();

    if (PlatformUtils.isAndroid) {
      if (_runtimeEngine == PlayerEngine.exo) {
        await audioHandler.stop();
      } else {
        await BackgroundService.stopService();
      }
    }

    closeAppFloating();

    if (Platform.isWindows) {
      await exitPip();
    }
  }

  // =========================
  // volume
  // =========================

  Future<void> setVolume(double volume) async {
    await _currentPlayer?.setVolume(volume.clamp(0.0, 1.0));
  }

  // =========================
  // fit
  // =========================

  void changeVideoFit(int index) {
    videoFitIndex.value = index;
  }

  // =========================
  // pip
  // =========================

  Future<void> enablePip() async {
    if (PlatformUtils.isAndroid) {
      final status = await floating.pipStatus;
      if (status == PiPStatus.disabled) {
        final rational = isVerticalVideo.value ? Rational.vertical() : Rational.landscape();
        await floating.enable(ImmediatePiP(aspectRatio: rational));
      }
    } else if (Platform.isWindows) {
      await WindowService().enterWinPiP(currentVideoRatio);
      isInPip.value = true;
    }
  }

  Future<void> exitPip() async {
    if (Platform.isWindows) {
      await WindowService().exitWinPiP();
      isInPip.value = false;
    }
  }

  // =========================
  // floating
  // =========================

  void showAppFloating() {
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
            if (Platform.isWindows || Platform.isMacOS) {
              isHovered.value = true;
            }
          },
          onExit: (_) {
            if (Platform.isWindows || Platform.isMacOS) {
              isHovered.value = false;
            }
          },
          child: Container(
            width: floatWidth,
            height: floatHeight,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.black),
            child: Stack(
              children: [
                Positioned.fill(child: getVideoWidget(videoFitIndex.value, fitList: PlayerConsts.videofitList)),

                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      closeAppFloating();

                      if (currentFloatRoom != null) {
                        AppNavigator.toLiveRoomDetail(liveRoom: currentFloatRoom!);
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
                        child: IconButton(
                          iconSize: 42,
                          style: IconButton.styleFrom(backgroundColor: Colors.black45),
                          icon: Icon(
                            isPlayingNow ? Icons.pause_circle_filled : Icons.play_circle_filled,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            togglePlayPause();

                            resetHideTimer();
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

  void closeAppFloating() {
    if (!isFloating.value) return;

    floatingManager.disposeFloating(_floatTag);

    isFloating.value = false;
  }

  // =========================
  // pip overlay
  // =========================

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
                child: getVideoWidget(videoFitIndex.value, fitList: PlayerConsts.videofitList),
              ),

              Center(
                child: Obx(
                  () => AnimatedOpacity(
                    opacity: isHovered.value ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: IconButton(
                      iconSize: 32,
                      style: IconButton.styleFrom(backgroundColor: Colors.black26),
                      icon: Icon(
                        isPlayingNow ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        togglePlayPause();
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

  // =========================
  // widget
  // =========================

  Widget getVideoWidget(int fitIndex, {Widget? controls, required List<BoxFit> fitList}) {
    return StreamBuilder<bool>(
      stream: onPlaying,
      initialData: isPlayingNow,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data ?? false;
        if (_currentPlayer == null || !isPlaying) {
          return _buildPlaceholder();
        }
        final boxFit = fitList[fitIndex];
        final content = KeyedSubtree(
          key: videoKey.value,
          child: Container(
            color: Colors.black,
            width: double.infinity,
            height: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(
                  child: FittedBox(
                    fit: boxFit,
                    clipBehavior: Clip.hardEdge,
                    child: StreamBuilder<List<int?>>(
                      stream: CombineLatestStream.list([width, height]),
                      builder: (context, snapshot) {
                        final w = snapshot.data?[0]?.toDouble() ?? 1920;
                        final h = snapshot.data?[1]?.toDouble() ?? 1080;
                        return SizedBox(width: w, height: h, child: _currentPlayer!.getVideoWidget());
                      },
                    ),
                  ),
                ),
                if (controls != null) Positioned.fill(child: controls),
              ],
            ),
          ),
        );
        if (!Platform.isAndroid) {
          return content;
        }
        return PiPSwitcher(floating: floating, childWhenEnabled: content, childWhenDisabled: content);
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.black,
      child: const Center(child: CircularProgressIndicator(strokeWidth: 4, color: Colors.white70)),
    );
  }

  // =========================
  // close
  // =========================

  Future<void> close() async {
    final settings = Get.find<SettingsService>();

    settings.useHardStopOnExit.value ? await hardDispose() : await softStop();
  }

  Future<void> softStop() async {
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
    final player = _currentPlayer;

    if (player != null) {
      await player.hardDispose();
    }

    if (_runtimeEngine != null) {
      await playerPool.removeFromCache(_runtimeEngine!);
    }

    _currentPlayer = null;

    _runtimeEngine = null;

    isInitialized.value = false;
  }

  // =========================
  // retry
  // =========================

  Future<void> retry() async {
    await replay();
  }

  // =========================
  // error
  // =========================

  Future<void> _handleError(PlayerException error) async {
    hasError.value = true;

    _errorSubject.add(error);

    PlayerErrorDispatcher.instance.dispatch(error);

    _stateSubject.add(PlayerState.error);

    DateTime now = DateTime.now();

    if (_lastErrorTime != null && now.difference(_lastErrorTime!) > _errorResetDuration) {
      _errorCount = 0;
    }

    _errorCount++;

    _lastErrorTime = now;

    if (_errorCount >= _maxErrorCount) {
      return;
    }

    if (error.type == PlayerErrorType.network || error.type == PlayerErrorType.source) {
      if (_currentPlayUrls.isEmpty) {
        return;
      }

      final nextLine = lineManager.next(_currentPlayUrls);

      await play(nextLine, _currentPlayUrls, _currentHeaders, room: currentFloatRoom);

      return;
    }

    if (fallbackManager.shouldFallback(error)) {
      final nextEngine = await fallbackManager.fallback(_runtimeEngine!, error);

      if (nextEngine == _runtimeEngine) {
        return;
      }

      _isSwitchingDueToFallback = true;

      await switchEngine(nextEngine, isManual: false);

      await replay();

      return;
    }
  }

  // =========================
  // bind
  // =========================

  void _bindPlayerStreams(UnifiedPlayer player) {
    _subscriptions.add(
      player.onPlaying.listen((event) async {
        _playingSubject.add(event);

        if (event) {
          hasError.value = false;

          _stateSubject.add(PlayerState.playing);

          if (_isSwitchingDueToFallback) {
            _errorCount = 0;

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

        if (event) {
          _stateSubject.add(PlayerState.buffering);
        }
      }),
    );

    _subscriptions.add(player.onComplete.listen(_completeSubject.add));

    _subscriptions.add(player.onStateChanged.listen(_stateSubject.add));

    _subscriptions.add(
      player.onError.listen((error) {
        unawaited(_handleError(error));
      }),
    );

    _subscriptions.add(player.width.listen(_widthSubject.add));

    _subscriptions.add(player.height.listen(_heightSubject.add));

    _subscriptions.add(
      CombineLatestStream.combine2<int?, int?, bool>(
        width.where((w) => w != null && w > 0),
        height.where((h) => h != null && h > 0),
        (w, h) => h! >= w!,
      ).listen((event) {
        isVerticalVideo.value = event;
      }),
    );
  }

  // =========================
  // clear subscriptions
  // =========================

  Future<void> _clearSubscriptions() async {
    for (final item in _subscriptions) {
      await item.cancel();
    }

    _subscriptions.clear();
  }

  // =========================
  // dispose
  // =========================

  Future<void> dispose() async {
    if (_disposed) return;

    _disposed = true;

    _hideTimer?.cancel();

    closeAppFloating();

    _pipSubscription?.cancel();

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
