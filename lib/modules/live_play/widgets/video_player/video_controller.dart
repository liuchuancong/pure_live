import 'dart:async';
import 'dart:io';

import 'package:auto_orientation/auto_orientation.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/modules/live_play/live_play_controller.dart';
import 'package:pure_live/modules/live_play/load_type.dart';
import 'package:pure_live/modules/util/rx_util.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'model/video_play_impl.dart';
import 'model/video_player_factory.dart';
import 'video_controller_panel.dart';

class VideoController with ChangeNotifier {
  final GlobalKey playerKey;
  final LiveRoom room;
  final String datasourceType;
  String datasource;
  final bool allowBackgroundPlay;
  final bool allowScreenKeepOn;
  final bool allowFullScreen;
  final bool fullScreenByDefault;
  final bool autoPlay;
  final Map<String, String> headers;

  /// 是否为竖屏直播间
  final videoFitIndex = 0.obs;
  final videoFit = BoxFit.contain.obs;
  final mediaPlayerControllerInitialized = false.obs;

  /// 是否为竖屏直播间
  RxBool get isVertical {
    return videoPlayer.isVertical;
  }

  late ScreenBrightness brightnessController;

  String qualiteName;

  int currentLineIndex;

  int currentQuality;

  bool hasDestory = false;

  final refreshCompleted = true.obs;

  final playerRefresh = false.obs;

  GlobalKey<BrightnessVolumeDargAreaState> brightnessKey = GlobalKey<BrightnessVolumeDargAreaState>();

  // LivePlayController livePlayController = Get.find<LivePlayController>();

  final SettingsService settings = Get.find<SettingsService>();

  int videoPlayerIndex = 4;

  bool enableCodec = true;

  // 是否手动暂停
  var isActivePause = true.obs;

  Timer? hasActivePause;

  // Controller ui status
  ///State of navigator on widget created
  late NavigatorState navigatorState;

  ///Flag which determines if widget has initialized

  Timer? showControllerTimer;
  final showController = true.obs;
  final showSettting = false.obs;
  final showLocked = false.obs;
  final danmuKey = GlobalKey();
  double volume = 0.0;

  Timer? _debounceTimer;

  void enableController() {
    showControllerTimer?.cancel();
    showControllerTimer = Timer(const Duration(seconds: 2), () {
      showController.updateValueNotEquate(false);
    });
    showController.updateValueNotEquate(true);
  }

  // Danmaku player control
  // BarrageWallController danmakuController = BarrageWallController();
  // final hideDanmaku = false.obs;
  // final danmakuArea = 1.0.obs;
  // final danmakuSpeed = 8.0.obs;
  // final danmakuFontSize = 16.0.obs;
  // final danmakuFontBorder = 0.5.obs;
  // final danmakuOpacity = 1.0.obs;
  // final mergeDanmuRating = 0.0.obs;

  /// 存储 Stream 流监听
  /// 默认视频 MPV 视频监听流
  final defaultVideoStreamSubscriptionList = <StreamSubscription>[];

  // GSY 视频监听流
  final gsyStreamSubscriptionList = <StreamSubscription>[];

  // 其他类型 监听流
  final otherStreamSubscriptionList = <StreamSubscription>[];

  LivePlayController livePlayController;

  VideoController({
    required this.playerKey,
    required this.room,
    required this.datasourceType,
    required this.datasource,
    required this.headers,
    required this.livePlayController,
    this.allowBackgroundPlay = false,
    this.allowScreenKeepOn = false,
    this.allowFullScreen = true,
    this.fullScreenByDefault = false,
    this.autoPlay = true,
    BoxFit fitMode = BoxFit.contain,
    required this.qualiteName,
    required this.currentLineIndex,
    required this.currentQuality,
  }) {
    videoFitIndex.value = settings.videoFitIndex.value;
    videoFit.value = settings.videofitArrary[videoFitIndex.value];
    // hideDanmaku.value = settings.hideDanmaku.value;
    // danmakuArea.value = settings.danmakuArea.value;
    // danmakuSpeed.value = settings.danmakuSpeed.value;
    // danmakuFontSize.value = settings.danmakuFontSize.value;
    // danmakuFontBorder.value = settings.danmakuFontBorder.value;
    // danmakuOpacity.value = settings.danmakuOpacity.value;
    // mergeDanmuRating.value = settings.mergeDanmuRating.value;
    initPagesConfig();
  }

  void initPagesConfig() {
    if (allowScreenKeepOn) WakelockPlus.enable();
    initVideoController();
    initDanmaku();
    initBattery();
  }

  // Battery level control
  final Battery _battery = Battery();
  final batteryLevel = 100.obs;

  void initBattery() {
    if (Platform.isAndroid || Platform.isIOS) {
      _battery.batteryLevel.then((value) => batteryLevel.updateValueNotEquate(value));
      otherStreamSubscriptionList.add(_battery.onBatteryStateChanged.listen((BatteryState state) async {
        batteryLevel.updateValueNotEquate(await _battery.batteryLevel);
      }));
    }
  }

  late VideoPlayerInterFace videoPlayer;

  void initVideoController() async {
    try {
      brightnessController = ScreenBrightness();
    } catch (e) {
      CoreLog.w("e");
    }
    FlutterVolumeController.updateShowSystemUI(false);
    videoPlayerIndex = settings.videoPlayerIndex.value;
    enableCodec = settings.enableCodec.value;

    videoPlayer = VideoPlayerFactory.getSupportVideoPlayerList()[videoPlayerIndex];
    videoPlayer.init(controller: this);

    otherStreamSubscriptionList.add(videoPlayer.hasError.listen((p0) {
      try {
        if (videoPlayer.hasError.value && !livePlayController.isLastLine.value) {
          SmartDialog.showToast("视频播放失败,正在为您切换线路");
          changeLine();
        }
      } catch (e) {
        CoreLog.error(e);
      }
    }));
    /*debounce(hasError, (callback) {
      try {
        if (hasError.value && !livePlayController.isLastLine.value) {
          SmartDialog.showToast("视频播放失败,正在为您切换线路");
          changeLine();
        }
      } catch (e) {
        CoreLog.error(e);
      }
    }, time: const Duration(seconds: 2));*/

    otherStreamSubscriptionList.add(showController.listen((p0) {
      if (showController.value) {
        if (videoPlayer.isPlaying.value) {
          // 取消手动暂停

          isActivePause.updateValueNotEquate(false);
        }
      }
      if (videoPlayer.isPlaying.value) {
        hasActivePause?.cancel();
      }
    }));

    otherStreamSubscriptionList.add(videoPlayer.isPlaying.listen((p0) {
      // 代表手动暂停了
      if (!videoPlayer.isPlaying.value) {
        if (showController.value) {
          isActivePause.updateValueNotEquate(true);
          hasActivePause?.cancel();
        } else {
          if (isActivePause.value) {
            hasActivePause = Timer(const Duration(seconds: 20), () {
              // 暂停了
              SmartDialog.showToast("系统监测视频已停止播放,正在为您刷新视频");
              isActivePause.updateValueNotEquate(false);
              refresh();
            });
          }
        }
      } else {
        hasActivePause?.cancel();
        isActivePause.updateValueNotEquate(false);
      }
    }));

    otherStreamSubscriptionList.add(mediaPlayerControllerInitialized.listen((value) {
      // fix auto fullscreen
      if (fullScreenByDefault && datasource.isNotEmpty && value) {
        Timer(const Duration(milliseconds: 500), () => toggleFullScreen());
      }
    }));
  }

  void debounceListen(Function? func, [int delay = 1000]) {
    if (_debounceTimer != null) {
      _debounceTimer?.cancel();
    }
    _debounceTimer = Timer(Duration(milliseconds: delay), () {
      func?.call();
      _debounceTimer = null;
    });
  }

  void refreshView() {
    refreshCompleted.updateValueNotEquate(false);
    Timer(const Duration(microseconds: 200), () async {
      await resetScreenBrightness();
      brightnessKey = GlobalKey<BrightnessVolumeDargAreaState>();
      refreshCompleted.updateValueNotEquate(true);
    });
  }

  /// 重置屏幕亮度
  Future<void> resetScreenBrightness() async {
    try {
      await brightnessController.resetApplicationScreenBrightness();
    } catch (e) {
      // CoreLog.error(e);
    }
  }

  void initDanmaku() {
    /*hideDanmaku.value = PrefUtil.getBool('hideDanmaku') ?? false;
    otherStreamSubscriptionList.add(hideDanmaku.listen((data) {
      PrefUtil.setBool('hideDanmaku', data);
    }));
    danmakuArea.value = PrefUtil.getDouble('danmakuArea') ?? 1.0;
    otherStreamSubscriptionList.add(danmakuArea.listen((data) {
      PrefUtil.setDouble('danmakuArea', data);
    }));
    danmakuSpeed.value = PrefUtil.getDouble('danmakuSpeed') ?? 8;
    otherStreamSubscriptionList.add(danmakuSpeed.listen((data) {
      PrefUtil.setDouble('danmakuSpeed', data);
    }));
    danmakuFontSize.value = PrefUtil.getDouble('danmakuFontSize') ?? 16;
    otherStreamSubscriptionList.add(danmakuFontSize.listen((data) {
      PrefUtil.setDouble('danmakuFontSize', data);
    }));
    danmakuFontBorder.value = PrefUtil.getDouble('danmakuFontBorder') ?? 0.5;
    otherStreamSubscriptionList.add(danmakuFontBorder.listen((data) {
      PrefUtil.setDouble('danmakuFontBorder', data);
    }));
    danmakuOpacity.value = PrefUtil.getDouble('danmakuOpacity') ?? 1.0;
    otherStreamSubscriptionList.add(danmakuOpacity.listen((data) {
      PrefUtil.setDouble('danmakuOpacity', data);
    }));*/
  }

  // void sendDanmaku(LiveMessage msg) {
  //   if (settings.hideDanmaku.value) return;
  //
  //   danmakuController.send([
  //     Bullet(
  //       child: DanmakuText(
  //         msg.message,
  //         fontSize: settings.danmakuFontSize.value,
  //         strokeWidth: settings.danmakuFontBorder.value,
  //         color: msg.color,
  //       ),
  //     ),
  //   ]);
  // }

  @override
  void dispose() async {
    if (hasDestory == false) {
      hasDestory == true;
      await destory();
    }
    super.dispose();
  }

  void refresh() {
    destory();
    Timer(const Duration(seconds: 2), () {
      try {
        livePlayController.playUrls.value = [];
        livePlayController.qualites.value = [];
        livePlayController.onInitPlayerState(reloadDataType: ReloadDataType.refreash, firstLoad: true);
      } catch (e) {
        CoreLog.error(e);
      }
    });
  }

  void changeLine({bool active = false}) async {
    // 播放错误 不一定是线路问题 先切换路线解决 后面尝试通知用户切换播放器
    await destory();
    Timer(const Duration(seconds: 2), () {
      try {
        livePlayController.onInitPlayerState(
          reloadDataType: ReloadDataType.changeLine,
          line: currentLineIndex,
          active: active,
        );
      } catch (e) {
        CoreLog.error(e);
      }
    });
  }

  Future<void> destory() async {
    resetScreenBrightness();
    disposeAllStream();
    // danmakuController.disable();
    // await danmakuController.dispose();
    videoPlayer.isPlaying.updateValueNotEquate(false);
    videoPlayer.hasError.updateValueNotEquate(false);
    try {
      livePlayController.success.updateValueNotEquate(false);
    } catch (e) {
      CoreLog.error(e);
    }
    hasDestory = true;
    if (allowScreenKeepOn) WakelockPlus.disable();

    // 关闭时退出全屏
    if (videoPlayer.isFullscreen.value) {
      videoPlayer.exitFullScreen();
    }
    videoPlayer.dispose();
  }

  void setDataSource(String url, Map<String, String> headers) async {
    CoreLog.d("play url: $url");
    datasource = url;
    // fix datasource empty error
    if (datasource.isEmpty) {
      videoPlayer.hasError.updateValueNotEquate(true);
      return;
    } else {
      videoPlayer.hasError.updateValueNotEquate(false);
    }
    await videoPlayer.openVideo(url, headers);
    notifyListeners();
  }

  void clearStreamSubscription(List<StreamSubscription> list) {
    for (var s in list) {
      s.cancel();
    }
    list.clear();
  }

  /// 释放 默认 播放器 Stream 流监听
  void disposeDefaultVideoStream() {
    clearStreamSubscription(defaultVideoStreamSubscriptionList);
  }

  /// 释放 Gsy Stream 流监听
  void disposeGsyStream() {
    clearStreamSubscription(gsyStreamSubscriptionList);
  }

  /// 释放 所有 Stream 流监听
  void disposeAllStream() {
    disposeGsyStream();
    disposeDefaultVideoStream();
    clearStreamSubscription(otherStreamSubscriptionList);
    brightnessKey.currentState?.dispose();
  }

  void setVideoFit(BoxFit fit) {
    videoFit.value = fit;
    videoPlayer.setVideoFit(fit);
  }

  void togglePlayPause() {
    videoPlayer.togglePlayPause();
  }

  void play() {
    videoPlayer.play();
  }

  Future<void> pause() async {
    videoPlayer.pause();
  }

  Future<void> exitFullScreen() async {
    videoPlayer.exitFullScreen();
    showSettting.updateValueNotEquate(false);
  }

  /// 设置横屏
  Future setLandscapeOrientation() async {
    if (await beforeIOS16()) {
      AutoOrientation.landscapeAutoMode();
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  /// 设置竖屏
  Future setPortraitOrientation() async {
    if (await beforeIOS16()) {
      AutoOrientation.portraitAutoMode();
    } else {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
  }

  /// 是否是IOS16以下
  Future<bool> beforeIOS16() async {
    if (Platform.isIOS) {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      var info = await deviceInfo.iosInfo;
      var version = info.systemVersion;
      var versionInt = int.tryParse(version.split('.').first) ?? 0;
      return versionInt < 16;
    } else {
      return false;
    }
  }

  void toggleFullScreen() async {
    CoreLog.d("toggleFullScreen");
    // disable locked
    showLocked.updateValueNotEquate(false);
    // fix danmaku overlap bug
    if (!settings.hideDanmaku.value) {
      settings.hideDanmaku.updateValueNotEquate(true);
      Timer(const Duration(milliseconds: 500), () {
        settings.hideDanmaku.updateValueNotEquate(false);
      });
    }
    // fix obx setstate when build
    showControllerTimer?.cancel();
    Timer(const Duration(milliseconds: 500), () {
      enableController();
    });

    videoPlayer.isFullscreen.toggle();
    if (videoPlayer.isFullscreen.value) {
      enterFullScreen();
    } else {
      exitFull();
    }
    refreshView();
  }

  /// 进入全屏
  void enterFullScreen() {
    videoPlayer.isFullscreen.updateValueNotEquate(true);
    if (Platform.isAndroid || Platform.isIOS) {
      //全屏
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
      if (!videoPlayer.isVertical.value) {
        //横屏
        setLandscapeOrientation();
      }
    } else {
      windowManager.setFullScreen(true);
    }
    //danmakuController?.clear();
  }

  /// 退出全屏
  void exitFull() {
    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge, overlays: SystemUiOverlay.values);
      setPortraitOrientation();
    } else {
      windowManager.setFullScreen(false);
    }
    showSettting.updateValueNotEquate(false);
    videoPlayer.isFullscreen.updateValueNotEquate(false);

    //danmakuController?.clear();
  }

  void toggleWindowFullScreen() {
    windowManager.setAlwaysOnTop(!videoPlayer.isWindowFullscreen.value);
    // disable locked
    showLocked.updateValueNotEquate(false);
    // fix danmaku overlap bug
    if (!settings.hideDanmaku.value) {
      settings.hideDanmaku.updateValueNotEquate(true);
      Timer(const Duration(milliseconds: 500), () {
        settings.hideDanmaku.updateValueNotEquate(false);
      });
    }
    // fix obx setstate when build
    showControllerTimer?.cancel();
    Timer(const Duration(milliseconds: 500), () {
      enableController();
    });

    /// 是否 窗口全屏
    videoPlayer.toggleWindowFullScreen();
    enableController();
    refreshView();
  }

  void enterPipMode(BuildContext context) async {
    if (Platform.isAndroid) {
      try {
        livePlayController.enablePIP();
      } catch (e) {
        CoreLog.error(e);
      }
      return;
    }
    videoPlayer.enterPipMode();
  }

  /////////// 音量 & 亮度
  /// 获取音量
  Future<double?> getVolume() async {
    return await FlutterVolumeController.getVolume();
  }

  /// 设置音量
  void setVolume(double value) async {
    await FlutterVolumeController.setVolume(value);
  }

  /// 获取亮度
  Future<double> brightness() async {
    try {
      return await brightnessController.application;
    } catch (e) {
      CoreLog.d("$e");
      return 100;
    }
  }

  /// 设置亮度
  void setBrightness(double value) async {
    await brightnessController.setApplicationScreenBrightness(value);
  }
}

// use fullscreen with controller provider
// use fullscreen with controller provider
