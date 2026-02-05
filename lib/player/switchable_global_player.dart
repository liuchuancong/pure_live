import 'dart:io';
import 'dart:async';
import 'dart:developer';
import 'fijk_adapter.dart';
import 'package:get/get.dart';
import 'media_kit_adapter.dart';
import 'package:rxdart/rxdart.dart';
import 'unified_player_interface.dart';
import 'package:floating/floating.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/player/fullscreen.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:flutter_floating/flutter_floating.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/modules/live_play/player_state.dart';
import 'package:pure_live/common/global/platform/background_server.dart';

enum PlayerEngine { mediaKit, fijk }

class SwitchableGlobalPlayer {
  static final SwitchableGlobalPlayer _instance = SwitchableGlobalPlayer._internal();
  factory SwitchableGlobalPlayer() => _instance;
  SwitchableGlobalPlayer._internal();

  // 状态管理
  final isInitialized = false.obs;
  final isVerticalVideo = false.obs;
  final isPlaying = false.obs;
  final isComplete = false.obs;
  final hasError = false.obs;
  final currentVolume = 1.0.obs;
  final isInPipMode = false.obs;
  late Floating floating;
  bool playerHasInit = false;
  bool hasSetVolume = false;
  static const String _floatTag = "global_video_player";
  // overlay相关
  final isFloating = false.obs;
  // pip
  final isInPip = false.obs;
  // 依赖
  final SettingsService settings = Get.find<SettingsService>();

  // 播放器相关
  UnifiedPlayer? _currentPlayer;
  PlayerEngine _currentEngine = PlayerEngine.mediaKit;
  ValueKey<String> videoKey = const ValueKey('video_0');

  // 订阅
  StreamSubscription<bool>? _orientationSubscription;
  StreamSubscription<bool>? _isPlayingSubscription;
  StreamSubscription<String?>? _errorSubscription;
  StreamSubscription<double?>? _volumeSubscription;
  StreamSubscription<bool>? _isCompleteSubscription;
  StreamSubscription<PiPStatus>? _pipSubscription;
  double _realWidth = 0;
  double _realHeight = 0;
  // Getter（安全访问）
  UnifiedPlayer? get currentPlayer => _currentPlayer;

  Stream<bool> get onLoading => _currentPlayer?.onLoading ?? Stream.value(false);
  Stream<bool> get onPlaying => _currentPlayer?.onPlaying ?? Stream.value(false);
  Stream<bool> get onComplete => _currentPlayer?.onComplete ?? Stream.value(false);
  Stream<String?> get onError => _currentPlayer?.onError ?? Stream.value(null);
  Stream<int?> get width => _currentPlayer?.width ?? Stream.value(null);
  Stream<int?> get height => _currentPlayer?.height ?? Stream.value(null);

  // 全局floating
  late LiveRoom currentFloatRoom;
  Future<void> init(PlayerEngine engine) async {
    if (_currentPlayer != null) return;
    _currentPlayer = _createPlayer(engine);
    _currentEngine = engine;
    _currentPlayer!.init();
    playerHasInit = true;
    hasSetVolume = false;
  }

  UnifiedPlayer _createPlayer(PlayerEngine engine) {
    switch (engine) {
      case PlayerEngine.mediaKit:
        return MediaKitPlayerAdapter();
      case PlayerEngine.fijk:
        return FijkPlayerAdapter();
    }
  }

  Future<void> switchEngine(PlayerEngine newEngine) async {
    if (newEngine == _currentEngine) return;
    _cleanup(); // 清理旧播放器和订阅
    _currentPlayer = _createPlayer(newEngine);
    _currentEngine = newEngine;
    videoKey = ValueKey('video_${DateTime.now().millisecondsSinceEpoch}');
    _currentPlayer!.init();
    playerHasInit = true;
  }

  Future<void> setDataSource(String url, List<String> playUrls, Map<String, String> headers, LiveRoom room) async {
    if (_currentPlayer != null || playerHasInit) {
      _currentPlayer!.stop();
      _cleanup();
    }
    await Future.delayed(const Duration(milliseconds: 100));
    _currentPlayer = _createPlayer(_currentEngine);
    playerHasInit = false;

    _cleanupSubscriptions();
    videoKey = ValueKey('video_${DateTime.now().millisecondsSinceEpoch}');

    unawaited(
      Future.microtask(() {
        isInitialized.value = false;
        isPlaying.value = true;
        hasError.value = false;
        hasSetVolume = false;
        isVerticalVideo.value = false;
      }),
    );

    try {
      await _currentPlayer!.init();
      await Future.delayed(const Duration(milliseconds: 100));
      await _currentPlayer!.setDataSource(url, playUrls, headers);
      if (PlatformUtils.isAndroid) {
        BackgroundService.startService(room.nick!, room.title!);
      }
      unawaited(
        Future.microtask(() {
          isInitialized.value = true;
          if (Platform.isAndroid) {
            floating = Floating();
          }
          _subscribeToPlayerEvents();
          playerHasInit = true;
          hasSetVolume = false;
        }),
      );
    } catch (e, st) {
      log('setDataSource failed: $e', error: e, stackTrace: st, name: 'SwitchableGlobalPlayer');
      hasError.value = true;
      hasSetVolume = false;
      isInitialized.value = false;
      _cleanup(); // 确保异常时也清理
    }
  }

  double get currentVideoRatio {
    // 使用缓存的真实宽高进行判断
    if (_realWidth > 0 && _realHeight > 0) {
      return _realWidth / _realHeight;
    }
    // 如果视频尚未解析出宽高，使用保底比例
    return isVerticalVideo.value ? (9 / 16) : (16 / 9);
  }

  final RxBool isHovered = false.obs;
  Widget buildPiPOverlay() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MouseRegion(
        onEnter: (_) => isHovered.value = true,
        onExit: (_) => isHovered.value = false,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(0), color: Colors.black),
          child: Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => windowManager.startDragging(),
                onDoubleTap: () {
                  isInPip.value = false;
                  GlobalPlayerState.to.isPipMode.value = false;
                  WindowService().exitWinPiP();
                },
                child: getVideoWidget(null),
              ),

              Center(
                child: Obx(
                  () => AnimatedOpacity(
                    opacity: isHovered.value ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: IconButton(
                      iconSize: 32,
                      style: IconButton.styleFrom(backgroundColor: Colors.black26),
                      icon: Icon(
                        isPlaying.value ? Icons.pause_circle_filled : Icons.play_circle_filled,
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
                right: 8, // 这里的定位现在会生效
                top: 8,
                child: Obx(
                  () => AnimatedOpacity(
                    opacity: isHovered.value ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    // 这里的 child 不能再是 Positioned
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () async {
                        isInPip.value = false;
                        GlobalPlayerState.to.isPipMode.value = false;
                        await WindowService().exitWinPiP();
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

  Timer? _hideTimer;

  void showAppFloating(LiveRoom room) {
    // 1. 每次清理旧的悬浮窗和计时器
    floatingManager.disposeFloating(_floatTag);
    _hideTimer?.cancel();

    // 2. 尺寸计算
    double maxSide = Platform.isWindows ? 350.0 : 220.0;
    double ratio = currentVideoRatio; // 确保这是一个数值
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
          // 桌面端鼠标进入显示
          onEnter: (_) {
            if (Platform.isWindows || Platform.isMacOS) isHovered.value = true;
          },
          // 桌面端鼠标离开隐藏
          onExit: (_) {
            if (Platform.isWindows || Platform.isMacOS) isHovered.value = false;
          },
          child: Container(
            width: floatWidth,
            height: floatHeight,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(100),
                  blurRadius: 15,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(child: getVideoWidget(null)),

                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (Platform.isAndroid || Platform.isIOS) {
                        if (!isHovered.value) {
                          isHovered.value = true;
                          resetHideTimer();
                        } else {
                          closeAppFloating();
                          AppNavigator.toLiveRoomDetail(liveRoom: currentFloatRoom);
                        }
                      } else {
                        closeAppFloating();
                        AppNavigator.toLiveRoomDetail(liveRoom: currentFloatRoom);
                      }
                    },
                    child: const SizedBox.expand(),
                  ),
                ),

                // 层级 3: 播放/暂停控制按钮
                Center(
                  child: Obx(
                    () => AnimatedOpacity(
                      opacity: isHovered.value ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: !isHovered.value,
                        child: IconButton(
                          iconSize: 42,
                          style: IconButton.styleFrom(backgroundColor: Colors.black45, foregroundColor: Colors.white),
                          icon: Icon(isPlaying.value ? Icons.pause_circle_filled : Icons.play_circle_filled),
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
                      opacity: isHovered.value ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: !isHovered.value,
                        child: IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          style: IconButton.styleFrom(backgroundColor: Colors.black45),
                          icon: const Icon(Icons.close, color: Colors.white, size: 20),
                          onPressed: () async {
                            _hideTimer?.cancel();
                            stop();
                            closeAppFloating();
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

    // 打开悬浮窗并更新状态
    floatingManager.getFloating(_floatTag).open(Get.context!);
    currentFloatRoom = room;
    isFloating.value = true;

    // 移动端初始显示 3 秒后自动隐藏按钮
    if (Platform.isAndroid || Platform.isIOS) {
      isHovered.value = true;
      resetHideTimer();
    }
  }

  /// 关闭并销毁悬浮播放器
  void closeAppFloating() {
    if (!isFloating.value) return;
    floatingManager.disposeFloating(_floatTag);
    isFloating.value = false;
  }

  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    currentVolume.value = clamped;
    await _currentPlayer?.setVolume(clamped);
  }

  Future<void> play() => _currentPlayer?.play() ?? Future.value();
  Future<void> pause() => _currentPlayer?.pause() ?? Future.value();

  Future<void> togglePlayPause() async {
    if (_currentPlayer?.isPlayingNow == true) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> stop() async {
    _currentPlayer?.stop();
    if (PlatformUtils.isAndroid) {
      BackgroundService.stopService();
    }
    dispose();
  }

  void enablePip() async {
    if (PlatformUtils.isAndroid) {
      final status = await floating.pipStatus;
      if (status == PiPStatus.disabled) {
        final rational = isVerticalVideo.value ? Rational.vertical() : Rational.landscape();
        final arguments = ImmediatePiP(aspectRatio: rational);
        await floating.enable(arguments);
      }
    } else {
      await WindowService().enterWinPiP(currentVideoRatio);
      isInPip.value = true;
      GlobalPlayerState.to.isPipMode.value = true;
    }
  }

  void exitPip() async {
    if (PlatformUtils.isWindows) {
      await WindowService().exitWinPiP();
      isInPip.value = false;
      GlobalPlayerState.to.isPipMode.value = false;
    }
  }

  void changeVideoFit(int index) {
    settings.videoFitIndex.value = index;
    videoKey = ValueKey('video_${DateTime.now().millisecondsSinceEpoch}');
  }

  Widget getVideoWidget(Widget? child) {
    return Obx(() {
      final bool isFloatContent = isFloating.value && child == null;
      if (!isInitialized.value) {
        return Material(
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              Container(color: Colors.black),
              Container(
                color: Colors.black,
                child: const Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 4, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      }
      if (!Platform.isAndroid) {
        return KeyedSubtree(
          key: videoKey,
          child: Material(
            key: ValueKey(settings.videoFitIndex.value),
            child: Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                fit: StackFit.passthrough,
                children: [
                  Container(color: Colors.black),
                  _currentPlayer?.getVideoWidget(settings.videoFitIndex.value, child) ?? const SizedBox(),
                  if (!isFloatContent && !isInPip.value) child ?? const SizedBox(),
                ],
              ),
              resizeToAvoidBottomInset: true,
            ),
          ),
        );
      }
      return PiPSwitcher(
        floating: floating,
        childWhenEnabled: KeyedSubtree(
          key: videoKey,
          child: Material(
            key: ValueKey(settings.videoFitIndex.value),
            child: Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                fit: StackFit.passthrough,
                children: [
                  Container(color: Colors.black),
                  _currentPlayer?.getVideoWidget(settings.videoFitIndex.value, child) ?? const SizedBox(),
                ],
              ),
              resizeToAvoidBottomInset: true,
            ),
          ),
        ),
        childWhenDisabled: KeyedSubtree(
          key: videoKey,
          child: Material(
            key: ValueKey(settings.videoFitIndex.value),
            child: Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                fit: StackFit.passthrough,
                children: [
                  Container(color: Colors.black),
                  _currentPlayer?.getVideoWidget(settings.videoFitIndex.value, child) ?? const SizedBox(),
                  if (!isFloatContent) child ?? const SizedBox(),
                ],
              ),
              resizeToAvoidBottomInset: true,
            ),
          ),
        ),
      );
    });
  }

  void _subscribeToPlayerEvents() {
    _cleanupSubscriptions();

    final orientationStream = CombineLatestStream.combine2<int?, int?, bool>(
      width.where((w) => w != null && w > 0),
      height.where((h) => h != null && h > 0),
      (w, h) {
        _realWidth = w!.toDouble();
        _realHeight = h!.toDouble();

        return _realHeight >= _realWidth;
      },
    );

    _orientationSubscription = orientationStream.listen((isVertical) {
      isVerticalVideo.value = isVertical;
    });

    _isPlayingSubscription = onPlaying.listen((playing) {
      isPlaying.value = playing;
      if (!hasSetVolume && playing) {
        setVolume(PlatformUtils.isMobile ? 1.0 : settings.volume.value);
        hasSetVolume = true;
      }
    });
    _errorSubscription = onError.listen((error) {
      hasError.value = error != null;
      log('onError: $error', error: error, name: 'SwitchableGlobalPlayer');
    });

    _isCompleteSubscription = onComplete.listen((complete) {
      log('complete: $complete', name: 'SwitchableGlobalPlayer');
      isComplete.value = complete;
    });

    if (Platform.isAndroid) {
      _pipSubscription = floating.pipStatusStream.listen((status) {
        isInPipMode.value = status == PiPStatus.enabled;
      });
    }
  }

  void _cleanupSubscriptions() {
    _orientationSubscription?.cancel();
    _isPlayingSubscription?.cancel();
    _errorSubscription?.cancel();
    _volumeSubscription?.cancel();
    _pipSubscription?.cancel();
    _isCompleteSubscription?.cancel();
  }

  void _cleanup() {
    _cleanupSubscriptions();
    _currentPlayer?.stop();
    _currentPlayer?.dispose();
    _currentPlayer = null;
    isInitialized.value = false;
    playerHasInit = false;
  }

  void dispose() {
    _cleanup();
  }

  PlayerEngine get currentEngine => _currentEngine;
}
