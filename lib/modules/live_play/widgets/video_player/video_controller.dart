import 'dart:io';
import 'dart:async';
import 'dart:developer';
import 'video_controller_panel.dart';
import 'package:pure_live/common/index.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/player/utils/fullscreen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:pure_live/modules/live_play/load_type.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:scrollview_observer/scrollview_observer.dart';
import 'package:pure_live/player/models/player_exception.dart';
import 'package:pure_live/modules/live_play/player_state.dart';
import 'package:pure_live/player/models/player_error_type.dart';
import 'package:pure_live/core/iptv/local/database.dart' as database;
import 'package:pure_live/pkg/canvas_danmaku/danmaku_controller.dart';
import 'package:pure_live/modules/live_play/live_play_controller.dart';
import 'package:pure_live/pkg/canvas_danmaku/models/danmaku_option.dart';
import 'package:pure_live/pkg/canvas_danmaku/models/danmaku_content_item.dart';

typedef AudioOnlyCallback = void Function(bool value);

class VideoController with ChangeNotifier {
  final LiveRoom room;
  String datasource;
  List<String> playUrs;
  final bool allowScreenKeepOn;
  final bool allowFullScreen;
  final Map<String, String> headers;
  final isVertical = false.obs;

  ScreenBrightness? _brightnessController;
  ScreenBrightness? get brightnessController {
    if (!Platform.isAndroid && !Platform.isIOS) return null;
    _brightnessController ??= ScreenBrightness();
    return _brightnessController;
  }

  double initBrightness = 0.0;

  final String qualiteName;

  final int currentLineIndex;

  final int currentQuality;

  final bool isAudioOnly;

  final AudioOnlyCallback? onAudioOnlyChanged;

  bool get supportWindowFull => Platform.isWindows || Platform.isLinux;

  late final VolumeController _volumeController;

  late final StreamSubscription<double> _subscription;

  GlobalKey<BrightnessVolumnDargAreaState> brightnessKey = GlobalKey<BrightnessVolumnDargAreaState>();

  LivePlayController livePlayController = Get.find<LivePlayController>();

  final RxList<database.EpgProgramme> currentChannelSchedule = <database.EpgProgramme>[].obs;
  StreamSubscription<PlayerException>? _errorSub;
  StreamSubscription<bool>? _pipSub;
  Timer? showControllerTimer;
  final showController = true.obs;
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
  final enableDanmakuStroke = true.obs;
  final danmakuFps = 60.obs;
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
    required this.isAudioOnly,
    this.onAudioOnlyChanged,
  }) {
    danmakuController = DanmakuController();

    hideDanmaku.value = SettingsService.to.danmaku.hideDanmaku.v;
    danmakuTopArea.value = SettingsService.to.danmaku.danmakuTopArea.v;
    danmakuBottomArea.value = SettingsService.to.danmaku.danmakuBottomArea.v;
    danmakuSpeed.value = SettingsService.to.danmaku.danmakuSpeed.v;
    danmakuFontSize.value = SettingsService.to.danmaku.danmakuFontSize.v;
    danmakuFontBorder.value = SettingsService.to.danmaku.danmakuFontBorder.v;
    danmakuOpacity.value = SettingsService.to.danmaku.danmakuOpacity.v;
    enableDanmakuStroke.value = SettingsService.to.danmaku.enableDanmakuStroke.v;
    initPagesConfig();
  }

  void initPagesConfig() {
    scheduleObserverController = ListObserverController(controller: scheduleScrollController);
    if (allowScreenKeepOn) WakelockPlus.enable();
    initVideoController();
    initDanmaku();
    initBattery();
  }

  void toggleAudioOnly() async {
    _errorSub?.cancel();
    _errorSub = null;
    _pipSub?.cancel();
    _pipSub = null;
    GlobalPlayerService.instance.playerManager.hardDispose();
    await destory();
    onAudioOnlyChanged?.call(!isAudioOnly);
  }

  // Battery level control
  final Battery _battery = Battery();
  final batteryLevel = 100.obs;

  late DanmakuController danmakuController;

  final ScrollController scheduleScrollController = ScrollController();
  late ListObserverController scheduleObserverController;
  bool hasScrolledToLive = false;
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
    _errorSub?.cancel();
    _errorSub = manager.onError.listen((error) {
      log('error: ${error.toString()}', name: 'initPlayerListener');
      _handlePlayerError(error);
    });
  }

  void _handlePlayerError(PlayerException error) {
    switch (error.type) {
      case PlayerErrorType.network:
        ToastUtil.show(i18n("error_network"));
        break;
      case PlayerErrorType.source:
        ToastUtil.show(i18n("error_source"));
        break;
      case PlayerErrorType.codec:
        ToastUtil.show(i18n("error_codec"));
        break;
      case PlayerErrorType.native:
        ToastUtil.show(i18n("error_native"));
        break;
      case PlayerErrorType.initialization:
        ToastUtil.show(i18n("error_initialization"));
        break;
      case PlayerErrorType.texture:
        ToastUtil.show(i18n("error_texture"));
        break;
      case PlayerErrorType.lifecycle:
        ToastUtil.show(i18n("error_lifecycle"));
        break;
      case PlayerErrorType.unknown:
        ToastUtil.show(i18n("error_unknown"));
        break;
    }
  }

  String generateCatchupUrl({
    required String originalUrl,
    required database.EpgProgramme programme,
    String type = 'default',
  }) {
    final Uri uri = Uri.parse(originalUrl);
    final formatter = DateFormat('yyyyMMddHHmmss');
    final String startStr = formatter.format(programme.start);
    final String stopStr = formatter.format(programme.stop);

    if (type == 'playseek') {
      final Map<String, String> newParams = Map<String, String>.from(uri.queryParameters);
      newParams['playseek'] = '$startStr-$stopStr';
      return uri.replace(queryParameters: newParams).toString();
    } else if (type == 'offset') {
      final int offsetSeconds = DateTime.now().difference(programme.start).inSeconds;
      final Map<String, String> newParams = Map<String, String>.from(uri.queryParameters);
      newParams['catchup'] = 'default';
      newParams['offset'] = offsetSeconds.toString();
      return uri.replace(queryParameters: newParams).toString();
    }

    return originalUrl.contains('?') ? '$originalUrl&timeshift=$startStr' : '$originalUrl?timeshift=$startStr';
  }

  void onProgrammeTapped(database.EpgProgramme programme) async {
    final now = DateTime.now();

    if (programme.start.isAfter(now)) {
      ToastUtil.show(i18n('program_scheduled_hint'));
      return;
    }

    if (programme.start.isBefore(now) && programme.stop.isAfter(now)) {
      Navigator.of(Get.context!).pop();
      return;
    }

    String catchupUrl = generateCatchupUrl(originalUrl: room.link!, programme: programme, type: 'playseek');
    Navigator.of(Get.context!).pop(); // 关闭节目单弹窗
    _errorSub?.cancel();
    _errorSub = null;
    _pipSub?.cancel();
    _pipSub = null;
    await GlobalPlayerService.instance.playerManager.close();
    await destory();
    livePlayController.startCatchUp(catchUpUrl: catchupUrl, startTime: programme.start.millisecondsSinceEpoch);
    ToastUtil.show('${i18n('playing_catchup')}: ${programme.title}');
  }

  void initVideoController() async {
    final playerManager = GlobalPlayerService.instance.playerManager;
    if (PlatformUtils.isMobile) {
      _volumeController = VolumeController.instance;
      _volumeController.showSystemUI = false;
      registerVolumeListener();
      final currentVolume = await _volumeController.getVolume();
      if (currentVolume > 0.001) {
        final targetVolume = room.getSavedVolume();
        _volumeController.setVolume(targetVolume);
      }
    }
    playerManager.play(datasource, playUrs, headers, room: room, audioOnly: isAudioOnly);
    initPlayerListener();
    // 处理默认全屏

    Future.delayed(Duration(milliseconds: 1000), () {
      if (SettingsService.to.app.enableFullScreenDefault.v) {
        livePlayController.setFullScreen();
        enterFullScreen();
        GlobalPlayerState.to.isFullscreen.value = true;
        enableController();
      }
    });

    if (room.platform == Sites.iptvSite) {
      loadFullChannelSchedule(room.epgId);
    }
  }

  void retryRoom() async {
    var liveRoom = await Sites.of(
      room.platform!,
    ).liveSite.getRoomDetail(roomId: room.roomId!, platform: room.platform!);
    if (liveRoom.liveStatus == LiveStatus.offline) {
      livePlayController.setNormalScreen();
      ToastUtil.show(i18n("room_offline"));
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
    final dm = SettingsService.to.danmaku;

    hideDanmaku.value = dm.hideDanmaku.v;
    ever<bool>(hideDanmaku, (data) {
      dm.hideDanmaku.v = data;
    });

    danmakuArea.value = dm.danmakuArea.v;
    danmakuTopArea.value = dm.danmakuTopArea.v;
    danmakuBottomArea.value = dm.danmakuBottomArea.v;
    danmakuSpeed.value = dm.danmakuSpeed.v;
    danmakuFontSize.value = dm.danmakuFontSize.v;
    danmakuFontBorder.value = dm.danmakuFontBorder.v;
    danmakuOpacity.value = dm.danmakuOpacity.v;
    enableDanmakuStroke.value = dm.enableDanmakuStroke.v;
    danmakuFps.value = dm.danmakuFps.v;
    final List<Rx> visualProperties = [
      danmakuArea,
      danmakuTopArea,
      danmakuBottomArea,
      danmakuSpeed,
      danmakuFontSize,
      danmakuFontBorder,
      danmakuOpacity,
      enableDanmakuStroke,
      danmakuFps,
    ];

    for (final rxProperty in visualProperties) {
      ever(rxProperty, (_) => updateDanmaku());
    }

    ever<double>(danmakuArea, (v) => dm.danmakuArea.v = v);
    ever<double>(danmakuTopArea, (v) => dm.danmakuTopArea.v = v);
    ever<double>(danmakuBottomArea, (v) => dm.danmakuBottomArea.v = v);
    ever<double>(danmakuSpeed, (v) => dm.danmakuSpeed.v = v);
    ever<double>(danmakuFontSize, (v) => dm.danmakuFontSize.v = v);
    ever<double>(danmakuFontBorder, (v) => dm.danmakuFontBorder.v = v);
    ever<double>(danmakuOpacity, (v) => dm.danmakuOpacity.v = v);
    ever<bool>(enableDanmakuStroke, (v) => dm.enableDanmakuStroke.v = v);
    ever<int>(danmakuFps, (v) => dm.danmakuFps.v = v);
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
        showStroke: enableDanmakuStroke.value,
        fps: danmakuFps.value,
      ),
    );
  }

  void sendDanmaku(LiveMessage msg) {
    if (hideDanmaku.value) return;
    if (GlobalPlayerService.instance.playerManager.isPlayingNow) {
      danmakuController.addDanmaku(
        DanmakuContentItem(
          msg.message,
          color: Color.fromARGB(255, msg.color.r, msg.color.g, msg.color.b),
          fontFamily: SettingsService.to.danmaku.danmakuFontFamilyName.v,
        ),
      );
    }
  }

  Future<void> loadFullChannelSchedule(String? epgId) async {
    currentChannelSchedule.clear();
    if (epgId == null || epgId.isEmpty) return;

    try {
      final db = Get.find<DbService>().db;
      final now = DateTime.now();

      final startTime = now.subtract(const Duration(days: 2));

      final endTime = now.add(const Duration(days: 1));

      List<database.EpgProgramme> dbProgrammes = await db.getProgrammes(
        epgChannelId: epgId,
        start: startTime,
        end: endTime,
      );

      currentChannelSchedule.value = dbProgrammes;

      debugPrint(
        "📅 [EPG Matrix] Loaded ${currentChannelSchedule.length} total program rows spanning the (-48h to +24h) timeline.",
      );
    } catch (e) {
      debugPrint("❌ EPG Schedule Loading Failure: $e");
    }
  }

  @override
  void dispose() async {
    _errorSub?.cancel();
    _errorSub = null;
    _pipSub?.cancel();
    _pipSub = null;
    showControllerTimer?.cancel();
    _debounceTimer?.cancel();
    _hideVolumeTimer?.cancel();
    await destory();
    super.dispose();
  }

  void refresh() async {
    _errorSub?.cancel();
    _errorSub = null;
    _pipSub?.cancel();
    _pipSub = null;
    GlobalPlayerService.instance.playerManager.close();
    await destory();
    livePlayController.onInitPlayerState(reloadDataType: ReloadDataType.refreash);
  }

  void clearListener() {
    _errorSub?.cancel();
    _errorSub = null;
    _pipSub?.cancel();
    _pipSub = null;
  }

  void changeLine() async {
    _errorSub?.cancel();
    _errorSub = null;
    _pipSub?.cancel();
    _pipSub = null;

    GlobalPlayerService.instance.playerManager.close();
    await destory();
    livePlayController.onInitPlayerState(reloadDataType: ReloadDataType.changeLine, line: currentLineIndex);
  }

  Future<void> destory() async {
    if (Platform.isAndroid || Platform.isIOS) {
      if (allowScreenKeepOn) WakelockPlus.disable();
      unawaited(_subscription.cancel());
      _volumeController.removeListener();
    }
  }

  void setVideoFit(int index) {
    GlobalPlayerService.instance.playerManager.changeVideoFit(index);
  }

  void exitFullScreen() async {
    WindowService().doExitFullScreen();
    GlobalPlayerState.to.isFullscreen.value = false;
  }

  void toggleFullScreen() async {
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

  // 半屏显示
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
      room.saveCurrentVolume(volume);
    }, fetchInitialVolume: true);
  }

  // volume & brightness
  Future<double?> volume() async {
    if (Platform.isWindows) {
      return room.getSavedVolume();
    }
    return await _volumeController.getVolume();
  }

  Future<double> brightness() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return await brightnessController!.application;
    }
    throw Exception('Brightness not supported on this platform');
  }

  void setVolume(double value) async {
    if (Platform.isWindows) {
      GlobalPlayerService.instance.playerManager.setVolume(value);
    } else {
      await _volumeController.setVolume(value);
    }
    room.saveCurrentVolume(value);
  }

  void setBrightness(double value) async {
    if (Platform.isAndroid || Platform.isIOS) {
      await brightnessController!.setApplicationScreenBrightness(value);
    }
  }
}
