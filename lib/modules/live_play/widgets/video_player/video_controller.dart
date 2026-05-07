import 'dart:io';
import 'dart:async';
import 'dart:developer';
import 'package:get/get.dart';
import 'video_controller_panel.dart';
import 'package:pure_live/common/index.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:pure_live/player/utils/fullscreen.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/modules/live_play/load_type.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/player/models/player_exception.dart';
import 'package:pure_live/modules/live_play/player_state.dart';
import 'package:pure_live/player/models/player_error_type.dart';
import 'package:pure_live/pkg/canvas_danmaku/danmaku_controller.dart';
import 'package:pure_live/modules/live_play/live_play_controller.dart';
import 'package:pure_live/pkg/canvas_danmaku/models/danmaku_option.dart';
import 'package:pure_live/pkg/canvas_danmaku/models/danmaku_content_item.dart';

class VideoController with ChangeNotifier {
  final LiveRoom room;
  String datasource;
  List<String> playUrs;
  final bool allowScreenKeepOn;
  final bool allowFullScreen;
  final Map<String, String> headers;
  final isVertical = false.obs;

  ScreenBrightness brightnessController = ScreenBrightness();

  double initBrightness = 0.0;

  final String qualiteName;

  final int currentLineIndex;

  final int currentQuality;

  bool get supportWindowFull => Platform.isWindows || Platform.isLinux;

  late final VolumeController _volumeController;

  late final StreamSubscription<double> _subscription;

  GlobalKey<BrightnessVolumnDargAreaState> brightnessKey = GlobalKey<BrightnessVolumnDargAreaState>();

  LivePlayController livePlayController = Get.find<LivePlayController>();

  final SettingsService settings = Get.find<SettingsService>();
  late StreamSubscription<PlayerException> _errorSub;
  Timer? showControllerTimer;
  final showController = true.obs;
  final showSettting = false.obs;
  final showLocked = false.obs;
  final danmuKey = GlobalKey();
  final isMenuOpen = false.obs;
  GlobalKey playerKey = GlobalKey();

  Timer? _debounceTimer;
  Timer? _hideVolumeTimer;
  var showVolume = false.obs;

  void updateVolumn(double volume) {
    _hideVolumeTimer?.cancel();
    showVolume = true.obs;
    _hideVolumeTimer = Timer(const Duration(seconds: 1), () {
      showVolume.value = false;
    });
  }

  void enableController() {
    showControllerTimer?.cancel();
    showControllerTimer = Timer(const Duration(seconds: 2), () {
      showController.value = false;
    });
    showController.value = true;
  }

  void stopHideController() {
    showControllerTimer?.cancel();
  }

  final hideDanmaku = false.obs;
  final danmakuArea = 1.0.obs;
  final danmakuTopArea = 0.0.obs;
  final danmakuBottomArea = 0.0.obs;
  final danmakuSpeed = 8.0.obs;
  final danmakuFontSize = 16.0.obs;
  final danmakuFontBorder = 4.0.obs;
  final danmakuOpacity = 1.0.obs;
  VideoController({
    required this.room,
    required this.datasource,
    required this.headers,
    required this.playUrs,
    this.allowScreenKeepOn = false,
    this.allowFullScreen = true,
    BoxFit fitMode = BoxFit.contain,
    required this.qualiteName,
    required this.currentLineIndex,
    required this.currentQuality,
  }) {
    danmakuController = DanmakuController(
      onAddDanmaku: (item) {},
      onUpdateOption: (option) {},
      onPause: () {},
      onResume: () {},
      onClear: () {},
    );

    hideDanmaku.value = settings.hideDanmaku.value;
    danmakuTopArea.value = settings.danmakuTopArea.value;
    danmakuBottomArea.value = settings.danmakuBottomArea.value;
    danmakuSpeed.value = settings.danmakuSpeed.value;
    danmakuFontSize.value = settings.danmakuFontSize.value;
    danmakuFontBorder.value = settings.danmakuFontBorder.value;
    danmakuOpacity.value = settings.danmakuOpacity.value;
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

  late DanmakuController danmakuController;
  void initBattery() {
    if (Platform.isAndroid || Platform.isIOS) {
      _battery.batteryLevel.then((value) => batteryLevel.value = value);
      _battery.onBatteryStateChanged.listen((BatteryState state) async {
        batteryLevel.value = await _battery.batteryLevel;
      });
    }
  }

  void initPlayerListener() {
    final manager = GlobalPlayerService.instance.playerManager;
    _errorSub = manager.onError.listen((error) {
      _handlePlayerError(error);
    });
  }

  void _handlePlayerError(PlayerException error) {
    log(error.toString(), name: 'PlayerError');
    switch (error.type) {
      // =====================
      // 网络错误
      // =====================
      case PlayerErrorType.network:
        ToastUtil.show('网络连接失败');
        break;
      // =====================
      // 播放源错误
      // =====================
      case PlayerErrorType.source:
        ToastUtil.show('播放源异常');
        break;
      // =====================
      // 解码错误
      // =====================
      case PlayerErrorType.codec:
        ToastUtil.show('当前播放器解码失败');
        break;
      // =====================
      // native 崩溃
      // =====================
      case PlayerErrorType.native:
        ToastUtil.show('播放器异常');
        break;
      // =====================
      // 初始化失败
      // =====================
      case PlayerErrorType.initialization:
        ToastUtil.show('播放器初始化失败');
        break;
      // =====================
      // texture 错误
      // =====================
      case PlayerErrorType.texture:
        ToastUtil.show('视频渲染失败');
        break;
      // =====================
      // 生命周期错误
      // =====================
      case PlayerErrorType.lifecycle:
        ToastUtil.show('播放器状态异常');
        break;
      // =====================
      // 未知错误
      // =====================
      case PlayerErrorType.unknown:
        ToastUtil.show('未知播放错误');

        break;
    }
  }

  void initVideoController() async {
    final playerManager = GlobalPlayerService.instance.playerManager;
    if (PlatformUtils.isMobile) {
      _volumeController = VolumeController.instance;
      _volumeController.showSystemUI = true;
      registerVolumeListener();
    }
    playerManager.play(datasource, playUrs, headers, room: room);
    initPlayerListener();
    // 处理默认全屏

    Future.delayed(Duration(milliseconds: 1000), () {
      if (settings.enableFullScreenDefault.value) {
        livePlayController.setFullScreen();
        enterFullScreen();
        GlobalPlayerState.to.isFullscreen.value = true;
        enableController();
      }
    });
  }

  void retryRoom() async {
    var liveRoom = await Sites.of(
      room.platform!,
    ).liveSite.getRoomDetail(roomId: room.roomId!, platform: room.platform!);
    if (liveRoom.liveStatus == LiveStatus.offline) {
      livePlayController.setNormalScreen();
      ToastUtil.show("该房间已下播");
    } else {
      changeLine();
    }
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

  void initDanmaku() {
    hideDanmaku.value = HivePrefUtil.getBool('hideDanmaku') ?? false;
    hideDanmaku.listen((data) {
      if (data) {
        danmakuController.clear();
      }
      HivePrefUtil.setBool('hideDanmaku', data);
      settings.hideDanmaku.value = data;
    });
    danmakuArea.value = HivePrefUtil.getDouble('danmakuArea') ?? 0.0;
    danmakuArea.listen((data) {
      HivePrefUtil.setDouble('danmakuArea', data);
      settings.danmakuArea.value = data;
      updateDanmaku();
    });
    danmakuTopArea.value = HivePrefUtil.getDouble('danmakuTopArea') ?? 0.0;
    danmakuTopArea.listen((data) {
      HivePrefUtil.setDouble('danmakuTopArea', data);
      settings.danmakuTopArea.value = data;
      updateDanmaku();
    });
    danmakuBottomArea.value = HivePrefUtil.getDouble('danmakuBottomArea') ?? 0.0;
    danmakuBottomArea.listen((data) {
      HivePrefUtil.setDouble('danmakuBottomArea', data);
      settings.danmakuBottomArea.value = data;
      updateDanmaku();
    });
    danmakuSpeed.value = HivePrefUtil.getDouble('danmakuSpeed') ?? 8;
    danmakuSpeed.listen((data) {
      HivePrefUtil.setDouble('danmakuSpeed', data);
      settings.danmakuSpeed.value = data;
      updateDanmaku();
    });
    danmakuFontSize.value = HivePrefUtil.getDouble('danmakuFontSize') ?? 16;
    danmakuFontSize.listen((data) {
      HivePrefUtil.setDouble('danmakuFontSize', data);
      settings.danmakuFontSize.value = data;
      updateDanmaku();
    });
    danmakuFontBorder.value = HivePrefUtil.getDouble('danmakuFontBorder') ?? 4.0;
    danmakuFontBorder.listen((data) {
      HivePrefUtil.setDouble('danmakuFontBorder', data);
      settings.danmakuFontBorder.value = data;
      updateDanmaku();
    });
    danmakuOpacity.value = HivePrefUtil.getDouble('danmakuOpacity') ?? 1.0;
    danmakuOpacity.listen((data) {
      HivePrefUtil.setDouble('danmakuOpacity', data);
      settings.danmakuOpacity.value = data;
      updateDanmaku();
    });

    GlobalPlayerService.instance.playerManager.isInPip.listen((isInPip) {
      if (isInPip) {
        livePlayController.setFullScreen();
      } else {
        livePlayController.setNormalScreen();
      }
    });
  }

  void updateDanmaku() {
    danmakuController.updateOption(
      DanmakuOption(
        fontSize: danmakuFontSize.value,
        area: danmakuArea.value,
        topAreaDistance: danmakuTopArea.value,
        bottomAreaDistance: danmakuBottomArea.value,
        duration: danmakuSpeed.value.toInt(),
        opacity: danmakuOpacity.value,
        fontWeight: danmakuFontBorder.value.toInt(),
      ),
    );
  }

  void sendDanmaku(LiveMessage msg) {
    if (hideDanmaku.value) return;
    if (GlobalPlayerService.instance.playerManager.isPlayingNow) {
      danmakuController.addDanmaku(
        DanmakuContentItem(msg.message, color: Color.fromARGB(255, msg.color.r, msg.color.g, msg.color.b)),
      );
    }
  }

  @override
  void dispose() async {
    _errorSub.cancel();
    await destory();
    super.dispose();
  }

  void refresh() async {
    _errorSub.cancel();
    GlobalPlayerService.instance.playerManager.close();
    await destory();
    livePlayController.onInitPlayerState(reloadDataType: ReloadDataType.refreash);
  }

  void changeLine() async {
    _errorSub.cancel();
    GlobalPlayerService.instance.playerManager.close();
    await destory();
    livePlayController.onInitPlayerState(reloadDataType: ReloadDataType.changeLine, line: currentLineIndex);
  }

  Future<void> destory() async {
    if (Platform.isAndroid || Platform.isIOS) {
      if (allowScreenKeepOn) WakelockPlus.disable();
      brightnessController.resetApplicationScreenBrightness();
      _subscription.cancel();
      _volumeController.removeListener();
    }
  }

  void setVideoFit(int index) {
    GlobalPlayerService.instance.playerManager.changeVideoFit(index);
  }

  void exitFullScreen() async {
    showSettting.value = false;
    WindowService().doExitFullScreen();
    GlobalPlayerState.to.isFullscreen.value = false;
  }

  void toggleFullScreen() async {
    log('toggleFullScreen called');
    showLocked.value = false;
    showControllerTimer?.cancel();

    GlobalPlayerState.to.isWindowFullscreen.value = false;
    Timer(const Duration(seconds: 2), () {
      enableController();
    });
    if (GlobalPlayerState.to.isFullscreen.value) {
      livePlayController.setNormalScreen();
      WindowService().doExitFullScreen();
      GlobalPlayerState.to.isFullscreen.value = false;
    } else {
      livePlayController.setFullScreen();
      enterFullScreen();
      GlobalPlayerState.to.isFullscreen.value = true;
    }
    enableController();
  }

  void enterFullScreen() {
    WindowService().doEnterFullScreen();
    GlobalPlayerState.to.isFullscreen.value = true;
    if (GlobalPlayerService.instance.playerManager.isVerticalVideo.value) {
      WindowService().verticalScreen();
    } else {
      WindowService().landScape();
    }
  }

  void toggleWindowFullScreen() {
    showLocked.value = false;
    showControllerTimer?.cancel();
    Timer(const Duration(seconds: 2), () {
      enableController();
    });
    if (GlobalPlayerState.to.isWindowFullscreen.value) {
      livePlayController.setNormalScreen();
      GlobalPlayerState.to.isWindowFullscreen.value = false;
    } else {
      livePlayController.setWidescreen();
      GlobalPlayerState.to.isWindowFullscreen.value = true;
    }
    GlobalPlayerState.to.isFullscreen.value = false;
    enableController();
  }

  // 注册音量变化监听器
  void registerVolumeListener() {
    _subscription = _volumeController.addListener((volume) {
      settings.volume.value = volume;
    }, fetchInitialVolume: true);
  }

  // volume & brightness
  Future<double?> volume() async {
    if (Platform.isWindows) {
      return settings.volume.value;
    }
    return await _volumeController.getVolume();
  }

  Future<double> brightness() async {
    return await brightnessController.application;
  }

  void setVolume(double value) async {
    if (Platform.isWindows) {
      GlobalPlayerService.instance.playerManager.setVolume(value);
    } else {
      await _volumeController.setVolume(value);
    }
    settings.volume.value = value;
  }

  void setBrightness(double value) async {
    if (Platform.isAndroid || Platform.isIOS) {
      await brightnessController.setApplicationScreenBrightness(value);
    }
  }
}
