import 'dart:io';
import 'dart:async';
import 'dart:developer';
import 'player_pool.dart';
import 'line_fallback_manager.dart';
import '../models/player_state.dart';
import 'preload_player_manager.dart';
import '../models/player_engine.dart';
import 'engine_fallback_manager.dart';
import 'package:floating/floating.dart';
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
import 'package:pure_live/recorder/ffmpeg/ffmpeg_types.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/player/utils/pip_window_widget.dart';
import 'package:pure_live/modules/live_play/player_state.dart';
import 'package:pure_live/player/core/live_audio_service.dart';
import 'package:pure_live/player/core/audio_stream_loader.dart';
import 'package:pure_live/modules/live_play/live_play_controller.dart';

class PlayerManager {
  final PlayerPool playerPool;

  final EngineFallbackManager fallbackManager;

  final PreloadPlayerManager preloadManager;
  final AudioStreamLoader audioLoader = AudioStreamLoader();
  final LineFallbackManager lineManager;
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
  bool _isHandlingError = false;

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

      await _bindPlayerStreams(_currentPlayer!);
      LiveAudioService.setPlayer(_currentPlayer!);
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

  Future<void> play(
    String url,
    List<String> playUrls,
    Map<String, String> headers, {
    LiveRoom? room,
    bool audioOnly = false,
  }) async {
    if (_disposed) return;
    if (room?.roomId != currentFloatRoom?.roomId) {
      lineManager.reset();
    }
    if (_currentPlayer == null || _runtimeEngine == null) {
      final String savedKey = SettingsService.to.player.videoPlayerKey.v;
      final String validKey = PlayerConsts.engines.containsKey(savedKey) ? savedKey : PlayerConsts.defaultKey;
      _defaultEngine = PlayerConsts.engines[validKey]!;

      _runtimeEngine = _defaultEngine;
      await initialize(engine: _defaultEngine!);
    } else if (_runtimeEngine != _defaultEngine && !_isSwitchingDueToFallback) {
      await switchEngine(_defaultEngine!, isManual: false);
    }

    final player = _currentPlayer;

    if (player == null) {
      throw PlayerException(message: 'Current player is null', type: PlayerErrorType.lifecycle);
    }

    String targetUrl = url;
    List<String> targetPlayUrls = List.from(playUrls);

    if (audioOnly && room?.roomId != null) {
      audioLoader.stop();
      final completer = Completer<String>();

      audioLoader.startAudioStream(
        remoteStreamUrl: url,
        uniqueId: room!.roomId!,
        platform: room.platform ?? "",
        onAudioReady: (audioPipePath) {
          if (!completer.isCompleted) completer.complete(audioPipePath);
        },
        onFFmpegEvent: (event) {
          if (event.type == FFmpegEventType.error) {
            final msg = event.data['message'] ?? 'FFmpeg stream extract failed';
            log(msg);
          }
        },
      );

      try {
        final pipePath = await completer.future.timeout(const Duration(seconds: 30));
        await Future.delayed(const Duration(seconds: 2));

        targetUrl = pipePath;
        targetPlayUrls = [pipePath];
      } catch (e) {
        audioLoader.stop();
        throw PlayerException(message: 'Audio pipe init timeout', type: PlayerErrorType.unknown);
      }
    } else if (!audioOnly) {
      audioLoader.stop();
    }

    _currentUrl = targetUrl;
    _currentPlayUrls = targetPlayUrls;
    _currentHeaders = headers;
    currentFloatRoom = room;
    hasError.value = false;

    try {
      _stateSubject.add(PlayerState.preparing);
      await player.setDataSource(targetUrl, targetPlayUrls, headers, room: room);
      LiveAudioService.setPlayer(player);
      LiveAudioService.start(room!.roomId!, room.nick ?? "", room.title ?? "", room.avatar);

      videoKey.value = ValueKey("video_${DateTime.now().millisecondsSinceEpoch}");
      _stateSubject.add(PlayerState.ready);
    } on PlayerException catch (e) {
      if (!_isHandlingError) {
        await _handleError(e);
      }
    } catch (e, s) {
      log(e.toString());
      final exception = PlayerException(message: 'Play failed', type: PlayerErrorType.unknown, error: e, stackTrace: s);

      if (!_isHandlingError) {
        await _handleError(exception);
      }
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
      log('Switch engine to $engine', name: 'PlayerManager');
      await _bindPlayerStreams(newPlayer);
      LiveAudioService.setPlayer(_currentPlayer!);
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

    await _bindPlayerStreams(player);
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
    await close();
    closeAppFloating();
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
      GlobalPlayerState.to.reset();
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
                Positioned.fill(
                  child: getVideoWidget(videoFitIndex.value, fitList: SettingsService.to.player.videoFitArray),
                ),

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
                child: getVideoWidget(videoFitIndex.value, fitList: SettingsService.to.player.videoFitArray),
              ),

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

  // =========================
  // widget
  // =========================
  Widget buildAudioOnlyUI(BuildContext context, LivePlayController livePlayController) {
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
                        child: Image.network(
                          livePlayController.detail.value?.avatar ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Remix.user_3_line, color: Colors.white24),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: gapLarge),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 24),
                    child: Text(
                      livePlayController.detail.value?.title ?? '',
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
                      livePlayController.detail.value?.nick ?? '',
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

  Widget getVideoWidget(int fitIndex, {Widget? controls, required List<BoxFit> fitList}) {
    final LivePlayController livePlayController = Get.find<LivePlayController>();
    return PureLivePipWidget(
      child: Container(
        color: Colors.black,
        padding: const EdgeInsets.all(0),
        child: StreamBuilder<bool>(
          stream: onPlaying,
          initialData: isPlayingNow,
          builder: (context, snapshot) {
            if (_currentPlayer == null) {
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
                    if (livePlayController.isCurrentRoomAudioOnly.value)
                      buildAudioOnlyUI(context, livePlayController)
                    else
                      // 修改后的逻辑
                      Positioned.fill(
                        child: Container(
                          color: Colors.black,
                          child: FittedBox(
                            fit: boxFit,
                            clipBehavior: Clip.hardEdge,
                            child: StreamBuilder<List<int?>>(
                              stream: CombineLatestStream.list([width, height]),
                              builder: (context, snapshot) {
                                final data = snapshot.data;

                                final double vW = (data != null && data.isNotEmpty)
                                    ? (data[0]?.toDouble() ?? 1920.0)
                                    : 1920.0;

                                final double vH = (data != null && data.length > 1)
                                    ? (data[1]?.toDouble() ?? 1080.0)
                                    : 1080.0;

                                return SizedBox(width: vW, height: vH, child: _currentPlayer!.getVideoWidget());
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
            if (!Platform.isAndroid) {
              return content;
            }
            return PiPSwitcher(floating: floating, childWhenEnabled: content, childWhenDisabled: content);
          },
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

  // =========================
  // close
  // =========================

  Future<void> close() async {
    await LiveAudioService.stop();
    audioLoader.stop();
    SettingsService.to.player.useHardStopOnExit.v ? await hardDispose() : await softStop();
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
    lineManager.reset();
    await _clearSubscriptions();
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
    if (_disposed) return;
    if (_isHandlingError) {
      log("skip duplicated error handling: ${error.message}");
      return;
    }
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

            await play(nextLine, _currentPlayUrls, _currentHeaders, room: currentFloatRoom);

            return;
          }
        }
      }
      log(error.type.toString());
      // =========================
      // 2. 再尝试切播放器
      // =========================

      if (!lineSwitched && fallbackManager.shouldFallback(error)) {
        final nextEngine = await fallbackManager.fallback(_runtimeEngine!, error);

        // 防止重复切换
        if (nextEngine == _runtimeEngine) {
          log("skip fallback: nextEngine(${nextEngine.name}) == currentEngine(${_runtimeEngine?.name})");
          return;
        }

        log(
          "fallback engine: "
          "${_runtimeEngine?.name} -> ${nextEngine.name}",
        );
        _isSwitchingDueToFallback = true;

        // 给底层播放器一点释放时间
        await Future.delayed(const Duration(milliseconds: 1200));

        await switchEngine(nextEngine, isManual: false);

        await Future.delayed(const Duration(milliseconds: 500));

        await replay();

        return;
      }
    } catch (e, s) {
      log("_handleError failed: $e", stackTrace: s);
    } finally {
      _isHandlingError = false;
    }
  }
  // =========================
  // bind
  // =========================

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
          _handleError(error);
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

  // =========================
  // clear subscriptions
  // =========================

  Future<void> _clearSubscriptions() async {
    if (_subscriptions.isEmpty) return;
    for (final item in _subscriptions.toList()) {
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
