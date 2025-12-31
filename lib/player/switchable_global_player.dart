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
import 'package:pure_live/routes/app_navigation.dart';
import 'package:flutter_floating/flutter_floating.dart';
import 'package:pure_live/common/global/platform_utils.dart';

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
  final isFloating = false.obs;
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

  Future<void> setDataSource(String url, Map<String, String> headers) async {
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
      await _currentPlayer!.setDataSource(url, headers);

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

  /// 构建悬浮窗关闭按钮
  Widget _buildCloseButton() {
    return GestureDetector(
      onTap: () {
        stop();
        closeAppFloating();
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(128),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 0.5),
        ),
        child: const Icon(Icons.close, color: Colors.white, size: 16),
      ),
    );
  }

  double get _currentVideoRatio {
    // 使用缓存的真实宽高进行判断
    if (_realWidth > 0 && _realHeight > 0) {
      return _realWidth / _realHeight;
    }
    // 如果视频尚未解析出宽高，使用保底比例
    return isVerticalVideo.value ? (9 / 16) : (16 / 9);
  }

  void showAppFloating(LiveRoom room) {
    floatingManager.disposeFloating(_floatTag);
    double maxSide = Platform.isWindows ? 350.0 : 220.0;

    double ratio = _currentVideoRatio;
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
    floatingManager.createFloating(
      _floatTag,
      FloatingOverlay(
        Container(
          width: floatWidth,
          height: floatHeight,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.black,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(100), // 加深一点阴影
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              getVideoWidget(null),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    // 点击悬浮窗回到页面的逻辑
                    closeAppFloating();
                    AppNavigator.toLiveRoomDetail(liveRoom: currentFloatRoom);
                  },
                  child: const SizedBox.expand(),
                ),
              ),

              // 3. 顶层：关闭按钮
              Positioned(right: 8, top: 8, child: _buildCloseButton()),
            ],
          ),
        ),
        right: 50,
        top: 100,
        slideType: FloatingEdgeType.onRightAndTop,
        params: FloatingParams(isSnapToEdge: false, snapToEdgeSpace: 10, dragOpacity: 0.8),
      ),
    );

    floatingManager.getFloating(_floatTag).open(Get.context!);
    currentFloatRoom = room;
    isFloating.value = true;
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
    dispose();
  }

  void enablePip() async {
    final status = await floating.pipStatus;
    if (status == PiPStatus.disabled) {
      final rational = isVerticalVideo.value ? Rational.vertical() : Rational.landscape();
      final arguments = ImmediatePiP(aspectRatio: rational);
      await floating.enable(arguments);
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
                  if (!isFloatContent) child ?? const SizedBox(),
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
