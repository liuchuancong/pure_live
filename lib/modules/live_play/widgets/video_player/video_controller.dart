import 'dart:io';
import 'dart:async';
import 'dart:developer';
import 'package:flutter/scheduler.dart';
import 'video_controller_panel.dart';
import 'package:pure_live/common/index.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flame_barrage/flame_barrage.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/player/utils/fullscreen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:pure_live/player/core/player_manager.dart';
import 'package:scrollview_observer/scrollview_observer.dart';
import 'package:pure_live/player/models/player_exception.dart';
import 'package:pure_live/player/models/player_error_type.dart';
import 'package:pure_live/modules/live_play/states/load_type.dart';
import 'package:pure_live/core/iptv/local/database.dart' as database;
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';

typedef AudioOnlyCallback = void Function(bool value);

enum PlayerStatus { idle, loading, playing, error, disposed }

// 平台工具类
class PlatformHelper {
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;
  static bool get isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  static bool get supportsBrightness => Platform.isAndroid || Platform.isIOS;
  static bool get supportsVolumeController => Platform.isAndroid || Platform.isIOS;
  static bool get supportsBatteryMonitoring => Platform.isAndroid || Platform.isIOS;
}

// 回放URL类型枚举
enum CatchupUrlType { default_, playseek, offset }

// 弹幕管理器
class DanmakuManager {
  static const List<double> _speedFactors = [0.90, 0.96, 1.02, 1.08, 1.14];

  final BarrageController controller;
  final BarrageController pipController;
  final List<Worker> workers = [];
  final SettingsService settingsService;
  final VideoController videoController;
  final RxInt _visualSettingsRevision = 0.obs;
  int _speedVariant = 0;
  bool _configUpdateScheduled = false;
  bool _settingsDirty = false;
  bool _disposed = false;

  DanmakuManager({
    required this.controller,
    required this.pipController,
    required this.settingsService,
    required this.videoController,
  });

  void setupWorkers() {
    final dm = settingsService.danmaku;

    // 设置初始值
    videoController.hideDanmaku.value = dm.hideDanmaku.v;
    videoController.danmakuArea.value = dm.danmakuArea.v;
    videoController.danmakuTopArea.value = dm.danmakuTopArea.v;
    videoController.danmakuBottomArea.value = dm.danmakuBottomArea.v;
    final migratedSpeed = dm.danmakuSpeed.v.clamp(20.0, 400.0).toDouble();
    videoController.danmakuSpeed.value = migratedSpeed;
    if (migratedSpeed != dm.danmakuSpeed.v) {
      dm.danmakuSpeed.v = migratedSpeed;
    }
    videoController.danmakuFontSize.value = dm.danmakuFontSize.v;
    videoController.danmakuFontBorder.value = dm.danmakuFontBorder.v.toInt();
    videoController.danmakuOpacity.value = dm.danmakuOpacity.v;
    videoController.enableDanmakuStroke.value = dm.enableDanmakuStroke.v;
    videoController.danmakuFps.value = dm.danmakuFps.v;
    videoController.danmakuFontFamilyName.value = dm.danmakuFontFamilyName.v;

    // 设置 workers
    workers.add(ever<bool>(videoController.hideDanmaku, (data) => dm.hideDanmaku.v = data));

    final List<Rx> visualProperties = [
      videoController.danmakuArea,
      videoController.danmakuTopArea,
      videoController.danmakuBottomArea,
      videoController.danmakuSpeed,
      videoController.danmakuFontSize,
      videoController.danmakuFontBorder,
      videoController.danmakuOpacity,
      videoController.enableDanmakuStroke,
      videoController.danmakuFps,
      videoController.danmakuFontFamilyName,
    ];

    workers.add(
      everAll(visualProperties, (_) {
        _settingsDirty = true;
        _visualSettingsRevision.value++;
        _scheduleConfigUpdate();
      }),
    );
    workers.add(
      debounce<int>(_visualSettingsRevision, (_) => _persistVisualSettings(), time: const Duration(milliseconds: 160)),
    );
  }

  void _scheduleConfigUpdate() {
    if (_disposed || _configUpdateScheduled) return;
    _configUpdateScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _configUpdateScheduled = false;
      if (!_disposed) videoController.updateDanmaku();
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  void _persistVisualSettings() {
    if (!_settingsDirty) return;
    final dm = settingsService.danmaku;
    dm.danmakuArea.v = videoController.danmakuArea.value;
    dm.danmakuTopArea.v = videoController.danmakuTopArea.value;
    dm.danmakuBottomArea.v = videoController.danmakuBottomArea.value;
    dm.danmakuSpeed.v = videoController.danmakuSpeed.value;
    dm.danmakuFontSize.v = videoController.danmakuFontSize.value;
    dm.danmakuFontBorder.v = videoController.danmakuFontBorder.value.toDouble();
    dm.danmakuOpacity.v = videoController.danmakuOpacity.value;
    dm.enableDanmakuStroke.v = videoController.enableDanmakuStroke.value;
    dm.danmakuFps.v = videoController.danmakuFps.value;
    dm.danmakuFontFamilyName.v = videoController.danmakuFontFamilyName.value;
    _settingsDirty = false;
  }

  void sendDanmaku(LiveMessage msg, bool isPlaying, bool isCompactMode) {
    if (!isPlaying) return;

    final originalColor = Color.fromARGB(255, msg.color.r, msg.color.g, msg.color.b);
    final settings = settingsService.danmaku;
    if (settings.enableDanmakuDisplay.v && !videoController.hideDanmaku.value) {
      final speed = videoController.danmakuSpeed.value * _speedFactors[_speedVariant++ % _speedFactors.length];
      controller.send(BarrageItem(content: msg.message, textColor: originalColor, baseSpeed: speed));
    }

    if (settings.enablePipDanmaku.v && isCompactMode) {
      final compactColor = settings.pipDanmakuUseOriginalColor.v ? originalColor : Color(settings.pipDanmakuColor.v);
      pipController.send(BarrageItem(content: msg.message, textColor: compactColor));
    }
  }

  void dispose() {
    _persistVisualSettings();
    _disposed = true;
    for (final worker in workers) {
      worker.dispose();
    }
    workers.clear();
    controller.clear();
    pipController.clear();
  }
}

class VideoController with ChangeNotifier {
  // 常量定义
  static const _controllerHideDelay = Duration(seconds: 2);
  static const _fullscreenDelay = Duration(milliseconds: 1000);
  static const _volumeHideDelay = Duration(seconds: 1);
  static const _epgLookBackDays = 2;
  static const _epgLookForwardDays = 1;

  // 依赖注入
  final LiveRoom room;
  final String datasource;
  final List<String> playUrs;
  final bool allowScreenKeepOn;
  final bool allowFullScreen;
  final Map<String, String> headers;
  final String qualiteName;
  final int currentLineIndex;
  final int currentQuality;
  final bool isAudioOnly;
  final AudioOnlyCallback? onAudioOnlyChanged;

  final Battery _battery;
  final SettingsService _settingsService;
  final DbService _dbService;
  final PlayerManager _playerManager;
  final LivePlayController _livePlayController;

  // 资源管理
  final List<StreamSubscription> _subscriptions = [];
  final List<Timer> _timers = [];

  // 状态
  PlayerStatus _status = PlayerStatus.idle;
  PlayerStatus get status => _status;
  final isVertical = false.obs;
  final showController = true.obs;
  final showLocked = false.obs;
  final isMenuOpen = false.obs;
  final showVolume = false.obs;
  final batteryLevel = 100.obs;

  // 弹幕相关
  final hideDanmaku = false.obs;
  final danmakuArea = 1.0.obs;
  final danmakuTopArea = 0.0.obs;
  final danmakuBottomArea = 0.0.obs;
  final danmakuSpeed = 120.0.obs;
  final danmakuFontSize = 16.0.obs;
  final danmakuFontBorder = 4.obs;
  final danmakuOpacity = 1.0.obs;
  final enableDanmakuStroke = true.obs;
  final danmakuFps = 60.obs;
  final danmakuFontFamilyName = ''.obs;

  // EPG相关
  final RxList<database.EpgProgramme> currentChannelSchedule = <database.EpgProgramme>[].obs;
  final ScrollController scheduleScrollController = ScrollController();
  late ListObserverController scheduleObserverController;
  bool hasScrolledToLive = false;

  // 控制器
  late final VolumeController _volumeController;
  late final BarrageController danmakuController;
  late final BarrageController pipDanmakuController;
  late final DanmakuManager _danmakuManager;

  // Keys
  GlobalKey<BrightnessVolumnDargAreaState> brightnessKey = GlobalKey<BrightnessVolumnDargAreaState>();
  final danmuKey = GlobalKey();
  GlobalKey playerKey = GlobalKey();

  // 屏幕亮度
  ScreenBrightness? _brightnessController;
  ScreenBrightness? get brightnessController {
    if (!PlatformHelper.supportsBrightness) return null;
    _brightnessController ??= ScreenBrightness();
    return _brightnessController;
  }

  bool get supportWindowFull => Platform.isWindows || Platform.isLinux;

  // 暴露 livePlayController 的 getter
  LivePlayController get livePlayController => _livePlayController;

  // 构造函数
  VideoController({
    required this.room,
    required this.datasource,
    required this.headers,
    required this.playUrs,
    required this.qualiteName,
    required this.currentLineIndex,
    required this.currentQuality,
    required this.isAudioOnly,
    this.allowScreenKeepOn = false,
    this.allowFullScreen = true,
    this.onAudioOnlyChanged,
    BoxFit fitMode = BoxFit.contain,
    Battery? battery,
    PlayerManager? playerManager,
    SettingsService? settingsService,
    DbService? dbService,
    LivePlayController? livePlayController,
  }) : _battery = battery ?? Battery(),
       _playerManager = playerManager ?? GlobalPlayerService.instance.playerManager,
       _settingsService = settingsService ?? SettingsService.to,
       _dbService = dbService ?? Get.find<DbService>(),
       _livePlayController = livePlayController ?? Get.find<LivePlayController>() {
    _initControllers();
    _initPagesConfig();
  }

  // 初始化方法
  void _initControllers() {
    danmakuController = BarrageController();
    pipDanmakuController = BarrageController();
    _danmakuManager = DanmakuManager(
      controller: danmakuController,
      pipController: pipDanmakuController,
      settingsService: _settingsService,
      videoController: this,
    );
  }

  void _initPagesConfig() {
    scheduleObserverController = ListObserverController(controller: scheduleScrollController);
    _danmakuManager.setupWorkers();

    if (allowScreenKeepOn) WakelockPlus.enable();

    _playerManager.attachVideoController(this);

    unawaited(initVideoController());
    initBattery();
  }

  // 播放器初始化
  Future<void> initVideoController() async {
    _setStatus(PlayerStatus.loading);

    await _initVolumeController();
    if (_isDisposed) return;

    await _playVideo();
    if (_isDisposed) return;

    initPlayerListener();
    _setupDefaultFullscreen();

    if (room.platform == Sites.iptvSite) {
      await loadFullChannelSchedule(room.epgId);
    }

    _setStatus(PlayerStatus.playing);
  }

  Future<void> _initVolumeController() async {
    if (!PlatformHelper.supportsVolumeController) return;

    _volumeController = VolumeController.instance;
    _volumeController.showSystemUI = false;
    registerVolumeListener();

    final currentVolume = await _volumeController.getVolume();
    if (currentVolume > 0.001) {
      final targetVolume = room.getSavedVolume();
      await _volumeController.setVolume(targetVolume);
    }
  }

  Future<void> _playVideo() async {
    await _playerManager.play(datasource, playUrs, headers, room: room, audioOnly: isAudioOnly);
  }

  void _setupDefaultFullscreen() {
    final timer = Timer(_fullscreenDelay, () {
      if (_isDisposed) return;
      if (_settingsService.app.enableFullScreenDefault.v) {
        _enterFullscreenMode();
      }
    });
    _addTimer(timer);
  }

  void _enterFullscreenMode() {
    _livePlayController.setFullScreen();
    enterFullScreen();
    GlobalPlayerState.to.isFullscreen.value = true;
    enableController();
  }

  // 资源管理方法
  void _addSubscription(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }

  void _addTimer(Timer timer) {
    _timers.add(timer);
  }

  Future<void> _cancelAllSubscriptions() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
  }

  void _cancelAllTimers() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  bool get _isDisposed => _status == PlayerStatus.disposed;

  void _setStatus(PlayerStatus newStatus) {
    _status = newStatus;
    notifyListeners();
  }

  // 播放器监听
  void initPlayerListener() {
    final errorSub = _playerManager.onError.listen((error) {
      log('error: ${error.toString()}', name: 'initPlayerListener');
      _handlePlayerError(error);
    });
    _addSubscription(errorSub);
  }

  void _handlePlayerError(PlayerException error) {
    _setStatus(PlayerStatus.error);

    final errorMessage = switch (error.type) {
      PlayerErrorType.network => i18n("error_network"),
      PlayerErrorType.source => i18n("error_source"),
      PlayerErrorType.codec => i18n("error_codec"),
      PlayerErrorType.native => i18n("error_native"),
      PlayerErrorType.initialization => i18n("error_initialization"),
      PlayerErrorType.texture => i18n("error_texture"),
      PlayerErrorType.lifecycle => i18n("error_lifecycle"),
      PlayerErrorType.unknown => i18n("error_unknown"),
    };

    ToastUtil.show(errorMessage);
  }

  // 电池管理
  void initBattery() {
    if (!PlatformHelper.supportsBatteryMonitoring) return;

    _battery.batteryLevel.then((value) {
      if (!_isDisposed) batteryLevel.value = value;
    });

    final batterySub = _battery.onBatteryStateChanged.listen((BatteryState state) async {
      final value = await _battery.batteryLevel;
      if (!_isDisposed) batteryLevel.value = value;
    });
    _addSubscription(batterySub);
  }

  // 音量管理
  void registerVolumeListener() {
    final volumeSub = _volumeController.addListener((volume) {
      room.saveCurrentVolume(volume);
    }, fetchInitialVolume: true);
    _addSubscription(volumeSub);
  }

  void updateVolumn(double volume) {
    _hideVolumeTimer?.cancel();
    showVolume.value = true;
    final timer = Timer(_volumeHideDelay, () {
      showVolume.value = false;
    });
    _addTimer(timer);
  }

  Future<double?> volume() async {
    if (PlatformHelper.isDesktop) {
      return room.getSavedVolume();
    }
    return await _volumeController.getVolume();
  }

  Future<void> setVolume(double value) async {
    if (PlatformHelper.isDesktop) {
      await _playerManager.setVolume(value);
    } else {
      await _volumeController.setVolume(value);
    }
    await room.saveCurrentVolume(value);
  }

  // 亮度管理
  Future<double> brightness() async {
    if (PlatformHelper.supportsBrightness) {
      return await brightnessController!.application;
    }
    throw Exception('Brightness not supported on this platform');
  }

  void setBrightness(double value) async {
    if (PlatformHelper.supportsBrightness) {
      await brightnessController!.setApplicationScreenBrightness(value);
    }
  }

  // 控制器显示管理
  void enableController() {
    showControllerTimer?.cancel();
    showController.value = true;

    if (!_isMouseOverController && !_isMouseOverPlayer) {
      showControllerTimer = Timer(const Duration(seconds: 2), () {
        if (!_isMouseOverController && !_isMouseOverPlayer) {
          showController.value = false;
        }
      });
    }
  }

  void stopHideController() {
    showControllerTimer?.cancel();
    showControllerTimer = null;
  }

  // 鼠标进入控制器区域
  void onMouseEnterController() {
    _isMouseOverController = true;
    stopHideController();
    showController.value = true;
  }

  // 鼠标离开控制器区域
  void onMouseExitController() {
    _isMouseOverController = false;
    enableController(); // 重新开始计时
  }

  // 鼠标进入播放器区域
  void onMouseEnterPlayer() {
    _isMouseOverPlayer = true;
    showController.value = true;
    stopHideController();
  }

  void onMouseHoverPlayer() {
    _isMouseOverPlayer = false;
    _isMouseOverPlayer = false;
    enableController(); // 重新开始计时
  }

  // 鼠标离开播放器区域
  void onMouseExitPlayer() {
    _isMouseOverPlayer = false;
    enableController(); // 重新开始计时
  }

  // 手动切换控制器显示
  void toggleController() {
    if (showController.value) {
      showController.value = false;
      stopHideController();
    } else {
      enableController();
    }
  }

  // 弹幕管理
  void updateDanmaku() {
    danmakuController.updateConfig(
      BarrageConfig(
        emitInterval: 0.016,
        fontSize: danmakuFontSize.value,
        area: danmakuArea.value,
        topAreaDistance: danmakuTopArea.value,
        bottomAreaDistance: danmakuBottomArea.value,
        baseSpeed: danmakuSpeed.value,
        opacity: danmakuOpacity.value,
        fontWeight: FontWeight.values[danmakuFontBorder.value],
        showStroke: enableDanmakuStroke.value,
        fps: danmakuFps.value,
      ),
    );
  }

  void sendDanmaku(LiveMessage msg) {
    _danmakuManager.sendDanmaku(msg, _playerManager.isPlayingNow, _playerManager.isCompactModeActive);
  }

  void clearPipDanmaku() => pipDanmakuController.clear();

  // EPG管理
  Future<void> loadFullChannelSchedule(String? epgId) async {
    currentChannelSchedule.clear();
    if (epgId == null || epgId.isEmpty) return;

    try {
      final programmes = await _fetchEpgProgrammes(epgId);
      currentChannelSchedule.value = programmes;
      _logEpgLoadSuccess(programmes.length);
    } catch (e, stackTrace) {
      _logEpgLoadError(e, stackTrace);
    }
  }

  Future<List<database.EpgProgramme>> _fetchEpgProgrammes(String epgId) async {
    final db = _dbService.db;
    final now = DateTime.now();
    final startTime = now.subtract(const Duration(days: _epgLookBackDays));
    final endTime = now.add(const Duration(days: _epgLookForwardDays));

    return db.getProgrammes(epgChannelId: epgId, start: startTime, end: endTime);
  }

  void _logEpgLoadSuccess(int count) {
    debugPrint(
      "📅 [EPG Matrix] Loaded $count total program rows spanning the (-${_epgLookBackDays}h to +${_epgLookForwardDays}h) timeline.",
    );
  }

  void _logEpgLoadError(Object error, StackTrace stackTrace) {
    debugPrint("❌ EPG Schedule Loading Failure: $error");
    log('EPG load error', error: error, stackTrace: stackTrace);
  }

  // 回放URL生成
  String generateCatchupUrl({
    required String originalUrl,
    required database.EpgProgramme programme,
    CatchupUrlType type = CatchupUrlType.default_,
  }) {
    final Uri uri = Uri.parse(originalUrl);
    final formatter = DateFormat('yyyyMMddHHmmss');
    final String startStr = formatter.format(programme.start);
    final String stopStr = formatter.format(programme.stop);

    switch (type) {
      case CatchupUrlType.playseek:
        final Map<String, String> newParams = Map<String, String>.from(uri.queryParameters);
        newParams['playseek'] = '$startStr-$stopStr';
        return uri.replace(queryParameters: newParams).toString();

      case CatchupUrlType.offset:
        final int offsetSeconds = DateTime.now().difference(programme.start).inSeconds;
        final Map<String, String> newParams = Map<String, String>.from(uri.queryParameters);
        newParams['catchup'] = 'default';
        newParams['offset'] = offsetSeconds.toString();
        return uri.replace(queryParameters: newParams).toString();

      case CatchupUrlType.default_:
        return originalUrl.contains('?') ? '$originalUrl&timeshift=$startStr' : '$originalUrl?timeshift=$startStr';
    }
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

    String catchupUrl = generateCatchupUrl(
      originalUrl: room.link!,
      programme: programme,
      type: CatchupUrlType.playseek,
    );

    Navigator.of(Get.context!).pop();
    await _reloadWithCatchup(catchupUrl, programme);

    ToastUtil.show('${i18n('playing_catchup')}: ${programme.title}');
  }

  Future<void> _reloadWithCatchup(String catchupUrl, database.EpgProgramme programme) async {
    clearListener();
    await _playerManager.close();
    await destory();
    _livePlayController.startCatchUp(catchUpUrl: catchupUrl, startTime: programme.start.millisecondsSinceEpoch);
  }

  // 播放控制
  Future<void> toggleAudioOnly() async {
    clearListener();
    await _playerManager.hardDispose();
    await destory();
    onAudioOnlyChanged?.call(!isAudioOnly);
  }

  void retryRoom() async {
    var liveRoom = await Sites.of(
      room.platform!,
    ).liveSite.getRoomDetail(roomId: room.roomId!, platform: room.platform!);

    if (liveRoom.liveStatus == LiveStatus.offline) {
      _livePlayController.setNormalScreen();
      ToastUtil.show(i18n("room_offline"));
    } else {
      changeLine();
    }
  }

  Future<void> refresh() async {
    clearListener();
    await _playerManager.close();
    await destory();
    await _livePlayController.onInitPlayerState(reloadDataType: ReloadDataType.refreash);
  }

  Future<void> changeLine() async {
    clearListener();
    await _playerManager.close();
    await destory();
    await _livePlayController.onInitPlayerState(reloadDataType: ReloadDataType.changeLine, line: currentLineIndex);
  }

  void clearListener() {
    final listenersToRemove = _subscriptions
        .where((s) => s is StreamSubscription<PlayerException> || s is StreamSubscription<bool>)
        .toList();

    for (final sub in listenersToRemove) {
      sub.cancel();
      _subscriptions.remove(sub);
    }
  }

  void debounceListen(Function? func, [int delay = 1000]) {
    _debounceTimer?.cancel();
    final timer = Timer(Duration(milliseconds: delay), () {
      func?.call();
    });
    _addTimer(timer);
  }

  // 全屏管理
  void exitFullScreen() async {
    WindowService().doExitFullScreen();
    GlobalPlayerState.to.isFullscreen.value = false;
  }

  void toggleFullScreen() async {
    showLocked.value = false;
    stopHideController();

    final timer = Timer(_controllerHideDelay, () {
      enableController();
    });
    _addTimer(timer);

    GlobalPlayerState.to.isWindowFullscreen.value = false;

    if (GlobalPlayerState.to.isFullscreen.value) {
      _livePlayController.setNormalScreen();
      WindowService().doExitFullScreen();
      GlobalPlayerState.to.isFullscreen.value = false;
    } else {
      _livePlayController.setFullScreen();
      enterFullScreen();
      GlobalPlayerState.to.isFullscreen.value = true;
    }
    enableController();
  }

  void enterFullScreen() {
    WindowService().doEnterFullScreen();
    GlobalPlayerState.to.isFullscreen.value = true;

    if (_playerManager.isVerticalVideo.value) {
      WindowService().verticalScreen();
    } else {
      WindowService().landScape();
    }
  }

  void toggleWindowFullScreen() {
    showLocked.value = false;
    stopHideController();

    final timer = Timer(_controllerHideDelay, () {
      enableController();
    });
    _addTimer(timer);

    if (GlobalPlayerState.to.isWindowFullscreen.value) {
      _livePlayController.setNormalScreen();
      GlobalPlayerState.to.isWindowFullscreen.value = false;
    } else {
      _livePlayController.setWidescreen();
      GlobalPlayerState.to.isWindowFullscreen.value = true;
    }
    GlobalPlayerState.to.isFullscreen.value = false;
    enableController();
  }

  // 视频适配
  void setVideoFit(int index) {
    _playerManager.changeVideoFit(index);
  }

  // 资源销毁
  Future<void> destory() async {
    if (_resourcesDestroyed) return;
    _resourcesDestroyed = true;

    if (PlatformHelper.supportsVolumeController) {
      if (allowScreenKeepOn) await WakelockPlus.disable();
    }
  }

  bool _resourcesDestroyed = false;

  @override
  void dispose() {
    if (_isDisposed) return;
    _setStatus(PlayerStatus.disposed);

    // 清理资源
    _playerManager.detachVideoController(this);
    _danmakuManager.dispose();
    _cancelAllTimers();
    scheduleScrollController.dispose();
    _isMouseOverController = false;
    _isMouseOverPlayer = false;
    // 异步清理
    unawaited(_disposeAsync());

    super.dispose();
  }

  Future<void> _disposeAsync() async {
    await _cancelAllSubscriptions();
    await destory();
  }

  // 兼容性属性
  Timer? showControllerTimer;
  // 添加鼠标状态跟踪
  bool _isMouseOverController = false;
  bool _isMouseOverPlayer = false;
  Timer? _debounceTimer;
  Timer? _hideVolumeTimer;
}
