import 'package:pure_live/player/core/playback_source.dart';

import 'dart:io';
import 'dart:async';
import 'dart:developer';

import 'video_controller_panel.dart';
import 'iptv_programme_policy.dart';

import 'package:flutter/scheduler.dart';
import 'package:pure_live/common/index.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flame_barrage/flame_barrage.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/player/utils/fullscreen.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:pure_live/player/core/player_manager.dart';
import 'package:pure_live/player/core/portrait_stream_support.dart';
import 'package:pure_live/modules/live_play/widgets/layout/portrait_fullscreen_interaction.dart';
import 'package:pure_live/player/models/player_exception.dart';
import 'package:pure_live/player/models/player_error_type.dart';
import 'package:pure_live/modules/live_play/states/load_type.dart';
import 'package:pure_live/modules/live_play/states/ui_state.dart';
import 'package:pure_live/core/iptv/local/database.dart' as database;
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku/danmaku_message_actions.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku/danmaku_settings_binding.dart';

typedef AudioOnlyCallback = Future<void> Function(bool value);

typedef EpgProgrammeLoader = Future<List<database.EpgProgramme>> Function({
  required String sourceId,
  required String epgId,
  required DateTime start,
  required DateTime end,
});

enum PlayerStatus { idle, loading, playing, error, disposed }

// 平台工具类
class PlatformHelper {
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;
  static bool get isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  static bool get supportsBrightness => Platform.isAndroid || Platform.isIOS;
  static bool get supportsVolumeController => Platform.isAndroid || Platform.isIOS;
  static bool get supportsBatteryMonitoring => Platform.isAndroid || Platform.isIOS;
}

// 弹幕管理器
class DanmakuManager {
  final BarrageController controller;
  final BarrageController pipController;
  final List<Worker> workers = [];
  final SettingsService settingsService;
  final VideoController videoController;
  final RxInt _visualSettingsRevision = 0.obs;
  bool _configUpdateScheduled = false;
  bool _settingsDirty = false;
  bool _disposed = false;
  DateTime? _lastLongPressAction;

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
    videoController.noEmojiMode.value = dm.noEmojiMode.v;
    videoController.danmakuArea.value = dm.danmakuArea.v;
    videoController.danmakuTopArea.value = dm.danmakuTopArea.v;
    videoController.danmakuBottomArea.value = dm.danmakuBottomArea.v;
    final migratedSpeed = dm.danmakuSpeed.v.clamp(20.0, 400.0).toDouble();
    videoController.danmakuSpeed.value = migratedSpeed;
    if (migratedSpeed != dm.danmakuSpeed.v) {
      dm.danmakuSpeed.v = migratedSpeed;
    }
    videoController.danmakuFontSize.value = dm.danmakuFontSize.v;
    videoController.danmakuFontWeight.value = dm.danmakuFontWeight.v;
    videoController.danmakuFontBorder.value = dm.danmakuFontBorder.v;
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
      videoController.danmakuFontWeight,
      videoController.danmakuFontBorder,
      videoController.danmakuOpacity,
      videoController.enableDanmakuStroke,
      videoController.danmakuFps,
      videoController.danmakuFontFamilyName,
      videoController.noEmojiMode,
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
    var resolvedAutoFps = dm.resolvedDanmakuFps(refreshRateMode: SettingsService.to.app.refreshRateMode);
    workers.add(
      everAll([dm.danmakuAutoFps, DisplayModeService.info, SettingsService.to.app.refreshRateModeName], (_) {
        final nextFps = dm.resolvedDanmakuFps(refreshRateMode: SettingsService.to.app.refreshRateMode);
        if (nextFps == resolvedAutoFps) return;
        resolvedAutoFps = nextFps;
        _scheduleConfigUpdate();
      }),
    );
  }

  void _openMessageActions(LiveMessage message, {required bool fromLongPress}) {
    final now = DateTime.now();
    if (fromLongPress) {
      _lastLongPressAction = now;
    } else if (_lastLongPressAction != null && now.difference(_lastLongPressAction!) < const Duration(seconds: 1)) {
      return;
    }
    final context = Get.context;
    if (context == null) return;
    controller.pause();
    unawaited(
      DanmakuMessageActions.show(
        context,
        message,
        controller: videoController.livePlayController,
      ).whenComplete(controller.resume),
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
    dm.danmakuFontWeight.v = videoController.danmakuFontWeight.value;
    dm.danmakuFontBorder.v = videoController.danmakuFontBorder.value.toDouble();
    dm.danmakuOpacity.v = videoController.danmakuOpacity.value;
    dm.enableDanmakuStroke.v = videoController.enableDanmakuStroke.value;
    dm.danmakuFps.v = videoController.danmakuFps.value;
    dm.danmakuFontFamilyName.v = videoController.danmakuFontFamilyName.value;
    dm.noEmojiMode.v = videoController.noEmojiMode.value;
    _settingsDirty = false;
  }

  void sendDanmaku(LiveMessage msg, bool isPlaying, bool isCompactMode) {
    // A locally composed message is a UI interaction rather than a packet from
    // the live transport. Do not silently discard it while playback is still
    // starting or briefly buffering.
    if (!isPlaying && !msg.isLocal) return;

    final originalColor = Color.fromARGB(255, msg.color.r, msg.color.g, msg.color.b);
    final localStyle = msg.isLocal ? msg.style : null;
    final settings = settingsService.danmaku;
    if (settings.enableDanmakuDisplay.v && !videoController.hideDanmaku.value) {
      controller.send(
        BarrageItem(
          content: msg.message,
          type: switch (localStyle?.placement) {
            LiveMessagePlacement.top => BarrageType.topFixed,
            LiveMessagePlacement.bottom => BarrageType.bottomFixed,
            _ => BarrageType.scroll,
          },
          userId: msg.userId,
          userName: msg.userName,
          textColor: originalColor,
          fontSize: localStyle?.fontSize,
          fontWeight: localStyle == null ? null : FontWeight(localStyle.fontWeight),
          fontStyle: localStyle?.italic == true ? FontStyle.italic : null,
          fontFamily: localStyle?.fontFamily,
          letterSpacing: localStyle?.letterSpacing,
          opacity: localStyle?.opacity,
          showStroke: localStyle?.showStroke,
          strokeColor: localStyle == null ? null : Color(localStyle.strokeColor),
          strokeWidth: localStyle?.strokeWidth,
          showShadow: localStyle?.showShadow,
          shadowColor: localStyle == null ? null : Color(localStyle.shadowColor),
          shadowBlur: localStyle?.shadowBlur,
          shadowOffset: localStyle == null ? null : Offset(localStyle.shadowOffset, localStyle.shadowOffset),
          fixedDuration: localStyle == null ? null : Duration(milliseconds: localStyle.fixedDurationMs),
          // A single px/s value keeps portrait, landscape and desktop motion
          // consistent. Lane collision avoidance is handled by the engine.
          baseSpeed: localStyle?.baseSpeed ?? videoController.danmakuSpeed.value,
          onTapUp: settings.enableDanmakuTapInteraction.v ? () => _openMessageActions(msg, fromLongPress: false) : null,
          onLongTapDown: settings.enableDanmakuLongPressInteraction.v
              ? () => _openMessageActions(msg, fromLongPress: true)
              : null,
        ),
      );
    }

    if (settings.enablePipDanmaku.v && isCompactMode) {
      final compactColor = msg.isLocal || settings.pipDanmakuUseOriginalColor.v
          ? originalColor
          : Color(settings.pipDanmakuColor.v);
      pipController.send(
        BarrageItem(
          content: msg.message,
          type: switch (localStyle?.placement) {
            LiveMessagePlacement.top => BarrageType.topFixed,
            LiveMessagePlacement.bottom => BarrageType.bottomFixed,
            _ => BarrageType.scroll,
          },
          textColor: compactColor,
          fontSize: localStyle?.fontSize,
          fontWeight: localStyle == null ? null : FontWeight(localStyle.fontWeight),
          fontStyle: localStyle?.italic == true ? FontStyle.italic : null,
          fontFamily: localStyle?.fontFamily,
          letterSpacing: localStyle?.letterSpacing,
          opacity: localStyle?.opacity,
          showStroke: localStyle?.showStroke,
          strokeColor: localStyle == null ? null : Color(localStyle.strokeColor),
          strokeWidth: localStyle?.strokeWidth,
          showShadow: localStyle?.showShadow,
          shadowColor: localStyle == null ? null : Color(localStyle.shadowColor),
          shadowBlur: localStyle?.shadowBlur,
          shadowOffset: localStyle == null ? null : Offset(localStyle.shadowOffset, localStyle.shadowOffset),
          fixedDuration: localStyle == null ? null : Duration(milliseconds: localStyle.fixedDurationMs),
          baseSpeed: localStyle?.baseSpeed,
        ),
      );
    }
  }

  bool handlePointer(Offset position, {required bool longPress}) {
    final settings = settingsService.danmaku;
    final enabled = longPress ? settings.enableDanmakuLongPressInteraction.v : settings.enableDanmakuTapInteraction.v;
    if (!enabled) return false;
    return controller.triggerItemAt(position.dx, position.dy, longPress: longPress);
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

/// One-shot orientation ownership for a fullscreen presentation.
///
/// An explicit landscape action entered from a portrait room must restore the
/// portrait normal room when fullscreen closes. Ordinary fullscreen entries
/// replace any unfinished request so an earlier presentation cannot affect a
/// later one.
class FullscreenOrientationRestoreState {
  bool _restorePortrait = false;

  void begin({required bool restorePortraitOnExit}) {
    _restorePortrait = restorePortraitOnExit;
  }

  bool takePortraitRestore() {
    final restore = _restorePortrait;
    _restorePortrait = false;
    return restore;
  }
}

Future<void> exitFullscreenWithOrientationRestore({
  required FullscreenOrientationRestoreState state,
  required Future<void> Function() exitFullscreen,
  required Future<void> Function() restorePortrait,
  required Future<void> Function() releaseOrientation,
  Duration portraitSettleDelay = const Duration(milliseconds: 350),
}) async {
  final shouldRestorePortrait = state.takePortraitRestore();
  await exitFullscreen();
  if (!shouldRestorePortrait) return;
  await restorePortrait();
  if (portraitSettleDelay > Duration.zero) {
    await Future<void>.delayed(portraitSettleDelay);
  }
  await releaseOrientation();
}

class VideoController with ChangeNotifier implements DanmakuSettingsBinding {
  // 常量定义
  // Two seconds was shorter than the orientation animation plus an
  // accessibility scan on phones, so controls could disappear before a user
  // reached Fullscreen or the local composer. Four seconds matches common
  // media-control behavior while any focused editor/menu still pins the bar.
  static const _controllerHideDelay = Duration(seconds: 4);
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
  final RxBool audioOnlyState;
  bool get isAudioOnly => audioOnlyState.value;
  bool get hasPlaybackError => _playerManager.hasError.value;
  final AudioOnlyCallback? onAudioOnlyChanged;
  final bool reuseCurrentSession;
  final PlaybackSourceResolver? sourceResolver;
  final DateTime? sourceRefreshAt;
  final PlaybackSourceQualitySelection? sourceSelection;
  final OwnedPlaybackSource? ownedSource;
  final ValueChanged<PlaybackSourceCommitSnapshot>? onSourceCommitted;
  int _lastSourceCommitRevision = 0;
  bool _acceptSourceCommits = false;

  final Battery _battery;
  final SettingsService _settingsService;
  final DbService _dbService;
  final PlayerManager _playerManager;
  final LivePlayController _livePlayController;
  final EpgProgrammeLoader? _loadEpgProgrammes;

  // 资源管理
  final List<StreamSubscription> _subscriptions = [];

  // 状态
  PlayerStatus _status = PlayerStatus.idle;
  PlayerStatus get status => _status;
  bool _playerListenerBound = false;
  String? _lastPlayerErrorSignature;
  DateTime? _lastPlayerErrorAt;
  final isVertical = false.obs;
  final showController = true.obs;
  final showLocked = false.obs;
  final isMenuOpen = false.obs;
  final showVolume = false.obs;
  final audioModeSwitching = false.obs;
  final catchUpSwitching = false.obs;
  final batteryLevel = 100.obs;
  final currentVolume = 1.0.obs;
  final FullscreenOrientationRestoreState _fullscreenOrientationRestore = FullscreenOrientationRestoreState();

  // 弹幕相关
  final hideDanmaku = false.obs;
  @override
  final noEmojiMode = false.obs;
  @override
  final danmakuArea = 1.0.obs;
  @override
  final danmakuTopArea = 0.0.obs;
  @override
  final danmakuBottomArea = 0.0.obs;
  @override
  final danmakuSpeed = 120.0.obs;
  @override
  final danmakuFontSize = 16.0.obs;
  @override
  final danmakuFontWeight = FontWeight.w500.value.obs;
  @override
  final danmakuFontBorder = 1.5.obs;
  @override
  final danmakuOpacity = 1.0.obs;
  @override
  final enableDanmakuStroke = true.obs;
  @override
  final danmakuFps = 60.obs;
  final danmakuFontFamilyName = ''.obs;

  // EPG相关
  final RxList<database.EpgProgramme> currentChannelSchedule = <database.EpgProgramme>[].obs;
  final scheduleLoading = false.obs;
  final scheduleLoadFailed = false.obs;
  final ScrollController scheduleScrollController = createPureLiveScrollController();
  bool hasScrolledToLive = false;
  int _epgLoadEpoch = 0;

  // 控制器
  late final VolumeController _volumeController;
  final VolumeController? _injectedVolumeController;
  static const _volumeOperationTimeout = Duration(seconds: 2);
  int _volumeRevision = 0;
  bool get _usesSystemVolume => PlatformHelper.supportsVolumeController || _injectedVolumeController != null;
  bool get _ownsVolume => !_isDisposed && _playerManager.ownsVideoController(this);
  late final BarrageController danmakuController;
  late final BarrageController pipDanmakuController;
  late final DanmakuManager _danmakuManager;

  // Keys
  final danmuKey = GlobalKey();
  GlobalKey playerKey = GlobalKey();

  // 屏幕亮度
  ScreenBrightnessPlatform? _brightnessController;
  ScreenBrightnessPlatform? get brightnessController {
    if (!PlatformHelper.supportsBrightness) return null;
    _brightnessController ??= ScreenBrightnessPlatform.instance;
    return _brightnessController;
  }

  bool get supportWindowFull => Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  late final Future<void> initialization;

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
    required bool isAudioOnly,
    this.sourceResolver,
    this.sourceRefreshAt,
    this.sourceSelection,
    this.ownedSource,
    this.onSourceCommitted,
    this.reuseCurrentSession = false,
    this.allowScreenKeepOn = false,
    this.allowFullScreen = true,
    this.onAudioOnlyChanged,
    BoxFit fitMode = BoxFit.contain,
    Battery? battery,
    VolumeController? systemVolumeController,
    PlayerManager? playerManager,
    SettingsService? settingsService,
    DbService? dbService,
    LivePlayController? livePlayController,
    EpgProgrammeLoader? epgProgrammeLoader,
  }) : audioOnlyState = isAudioOnly.obs,
       _battery = battery ?? Battery(),
       _injectedVolumeController = systemVolumeController,
       _playerManager = playerManager ?? GlobalPlayerService.instance.player,
       _settingsService = settingsService ?? SettingsService.to,
       _dbService = dbService ?? Get.find<DbService>(),
       _livePlayController = livePlayController ?? Get.find<LivePlayController>(),
       _loadEpgProgrammes = epgProgrammeLoader {
    currentVolume.value = room.getSavedVolume();
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
    _danmakuManager.setupWorkers();

    if (allowScreenKeepOn) WakelockPlus.enable();

    _playerManager.attachVideoController(this);

    initialization = initVideoController();
    unawaited(initialization);
    initBattery();
  }

  // 播放器初始化
  Future<void> initVideoController() async {
    _setStatus(PlayerStatus.loading);
    // Bind before opening the source. Native open/decode failures can arrive
    // synchronously while PlayerManager.play is still awaiting the adapter;
    // binding afterwards silently lost that only terminal event and then
    // overwrote the page with a false `playing` state.
    initPlayerListener();

    await _initVolumeController();
    if (!_ownsVolume) return;

    if (reuseCurrentSession) {
      if (_playerManager.currentPlayer == null || _playerManager.currentFloatRoom != room) {
        throw PlayerException(message: 'Retained room session is no longer available', type: PlayerErrorType.lifecycle);
      }
      audioOnlyState.value = _playerManager.desiredAudioOnlyMode;
    } else {
      await _playVideo();
    }
    if (_isDisposed) return;

    _setupDefaultFullscreen();

    if (room.platform == Sites.iptvSite) {
      await loadFullChannelSchedule(room.epgId);
    }

    if (_playerManager.hasError.value) {
      _setStatus(PlayerStatus.error);
    } else if (_playerManager.isPlayingNow) {
      _setStatus(PlayerStatus.playing);
    } else {
      _setStatus(PlayerStatus.loading);
    }
  }

  Future<void> _initVolumeController() async {
    if (!_usesSystemVolume || !_ownsVolume) return;
    _volumeController = _injectedVolumeController ?? VolumeController.instance;
    _volumeController.showSystemUI = false;
    try {
      registerVolumeListener();
      final revision = _volumeRevision;
      final observed = await _volumeController.getVolume().timeout(_volumeOperationTimeout);
      if (!_ownsVolume || revision != _volumeRevision || !observed.isFinite) return;
      if (_settingsService.vol.globalVolumeMute.v) {
        // Global mute is an explicit app-wide request. It remains the only
        // preference allowed to change the shared device stream on entry.
        await setVolume(0.0);
        return;
      }
      // Android/iOS media volume belongs to the device, not to an individual
      // room. A room-level snapshot can outlive this route while the user
      // changes media volume elsewhere; replaying it here would unexpectedly
      // overwrite that newer device choice (most visibly when the stale value
      // is zero). Adopt the current native level without writing it back or
      // erasing the desktop/multiview room preference.
      currentVolume.value = observed.clamp(0.0, 1.0).toDouble();
    } catch (error, stack) {
      // An optional volume plugin must not prevent the room from opening.
      log('Initialize system volume failed', name: 'VideoController.Volume', error: error, stackTrace: stack);
    }
  }

  Future<void> _playVideo() async {
    // play() invalidates the previous intent synchronously before it queues
    // native work. Only from this point may a newly constructed route consume
    // events; its volume initialization must not replay the old same-room URL.
    _acceptSourceCommits = true;
    final owned = ownedSource;
    if (owned != null) {
      await _playerManager.playSource(
        owned,
        room: room,
        audioOnly: isAudioOnly,
        sourceResolver: sourceResolver,
        sourceRefreshAt: sourceRefreshAt,
        sourceSelection: sourceSelection,
      );
      return;
    }
    await _playerManager.play(
      datasource,
      playUrs,
      headers,
      room: room,
      audioOnly: isAudioOnly,
      sourceResolver: sourceResolver,
      sourceRefreshAt: sourceRefreshAt,
      sourceSelection: sourceSelection,
    );
  }

  /// Rebinds the existing room controller to a freshly-created native player.
  ///
  /// The UI controller deliberately survives this operation. Recreating it on
  /// every headphone tap used to give the replacement button a separate
  /// transition lock while the previous native player was still shutting down,
  /// so repeated audio/video taps could overlap and replace the video area with
  /// Flutter's release-mode error widget.
  Future<void> changeAudioOnlyMode(bool value) async {
    if (_isDisposed || isAudioOnly == value) return;
    final previous = isAudioOnly;
    final enteringAudioMode = value && !previous;
    if (enteringAudioMode) {
      // Present the stable room-level audio UI before the Android native track
      // command completes. mpv reports buffering while it drops the video
      // decoder; leaving the old video presentation visible during that window
      // looked like an endless spinner even though audio kept playing.
      audioOnlyState.value = true;
    }
    try {
      await _playerManager.setAudioOnlyMode(value);
      // A newer request may have superseded this one while the native command
      // was pending (for example, returning through the floating window).
      if (!_isDisposed) audioOnlyState.value = _playerManager.isAudioOnlyMode;
    } catch (_) {
      if (!_isDisposed) audioOnlyState.value = previous;
      rethrow;
    }
  }

  void _setupDefaultFullscreen() {
    _defaultFullscreenTimer?.cancel();
    _defaultFullscreenTimer = Timer(_fullscreenDelay, () {
      _defaultFullscreenTimer = null;
      if (_isDisposed) return;
      if (_settingsService.app.enableFullScreenDefault.v) {
        _enterFullscreenMode();
      }
    });
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

  Future<void> _cancelAllSubscriptions() async {
    _acceptSourceCommits = false;
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    _playerListenerBound = false;
  }

  void _cancelAllTimers() {
    _defaultFullscreenTimer?.cancel();
    _controllerTransitionTimer?.cancel();
    _hideVolumeTimer?.cancel();
    _debounceTimer?.cancel();
    showControllerTimer?.cancel();
    _controllerHideDeadlineMs = null;
    _defaultFullscreenTimer = null;
    _controllerTransitionTimer = null;
    _hideVolumeTimer = null;
    _debounceTimer = null;
    showControllerTimer = null;
  }

  bool get _isDisposed => _status == PlayerStatus.disposed;

  void _setStatus(PlayerStatus newStatus) {
    if (_status == newStatus) return;
    _status = newStatus;
    notifyListeners();
  }

  // 播放器监听
  void initPlayerListener() {
    if (_playerListenerBound || _isDisposed) return;
    _playerListenerBound = true;
    _acceptSourceCommits = reuseCurrentSession;
    // Subscribe before replaying the canonical snapshot: a retained native
    // session may commit a new source while the old room route is gone.
    _addSubscription(_playerManager.onSourceCommitted.listen(_handleSourceCommit));
    final sourceCommit = _playerManager.currentSourceCommit;
    if (reuseCurrentSession && sourceCommit != null) _handleSourceCommit(sourceCommit);
    final errorSub = _playerManager.onError.listen((error) {
      log('error: ${error.toString()}', name: 'initPlayerListener');
      _handlePlayerError(error);
    });
    _addSubscription(errorSub);
    _addSubscription(
      _playerManager.onPlaying.distinct().listen((playing) {
        if (_isDisposed) return;
        if (playing) {
          _setStatus(PlayerStatus.playing);
        } else if (_playerManager.hasError.value) {
          _setStatus(PlayerStatus.error);
        }
      }),
    );
    _addSubscription(
      _playerManager.onLoading.distinct().listen((loading) {
        if (_isDisposed || _playerManager.hasError.value) return;
        if (loading) _setStatus(PlayerStatus.loading);
      }),
    );
  }

  void _handleSourceCommit(PlaybackSourceCommitSnapshot commit) {
    if (_isDisposed ||
        !_acceptSourceCommits ||
        commit.revision <= _lastSourceCommitRevision ||
        commit.room.roomId != room.roomId ||
        commit.room.platform != room.platform ||
        !_playerManager.isSourceCommitCurrent(commit)) {
      return;
    }
    _lastSourceCommitRevision = commit.revision;
    try {
      onSourceCommitted?.call(commit);
    } catch (error, stackTrace) {
      // Presentation callbacks must not roll a successfully opened native
      // source back or leave a broadcast subscription with an unhandled error.
      log('Source commit presentation failed', name: 'VideoController', error: error, stackTrace: stackTrace);
    }
  }

  void _handlePlayerError(PlayerException error) {
    if (_isDisposed) return;
    _setStatus(PlayerStatus.error);

    final now = DateTime.now();
    final signature = error.toString();
    if (_lastPlayerErrorSignature == signature &&
        _lastPlayerErrorAt != null &&
        now.difference(_lastPlayerErrorAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastPlayerErrorSignature = signature;
    _lastPlayerErrorAt = now;

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
    if (!_ownsVolume) return;
    final volumeSub = _volumeController.addListener((volume) {
      if (!_ownsVolume || !volume.isFinite) return;
      _volumeRevision++;
      final resolved = volume.clamp(0.0, 1.0).toDouble();
      currentVolume.value = resolved;
      unawaited(room.saveCurrentVolume(resolved));
    }, fetchInitialVolume: false);
    volumeSub.onError((Object error, StackTrace stack) {
      log('Observe system volume failed', name: 'VideoController.Volume', error: error, stackTrace: stack);
    });
    _addSubscription(volumeSub);
  }

  void updateVolumn(double volume) {
    if (!_ownsVolume) return;
    _hideVolumeTimer?.cancel();
    showVolume.value = true;
    _hideVolumeTimer = Timer(_volumeHideDelay, () {
      _hideVolumeTimer = null;
      if (!_isDisposed) showVolume.value = false;
    });
  }

  Future<double?> volume() async {
    if (!_ownsVolume) return null;
    if (!_usesSystemVolume) return room.getSavedVolume();
    final revision = _volumeRevision;
    try {
      final observed = await _volumeController.getVolume().timeout(_volumeOperationTimeout);
      if (!_ownsVolume) return null;
      if (revision != _volumeRevision || !observed.isFinite) return currentVolume.value;
      return observed.clamp(0.0, 1.0).toDouble();
    } catch (error, stack) {
      log('Read system volume failed', name: 'VideoController.Volume', error: error, stackTrace: stack);
      return _ownsVolume ? currentVolume.value : null;
    }
  }

  Future<void> setVolume(double value) async {
    await trySetVolume(value);
  }

  /// Applies a user-requested volume and reports whether the active room still
  /// owned the operation. Ordinary controls keep using [setVolume], while
  /// transactional UI can retain its draft when the platform write fails.
  Future<bool> trySetVolume(double value) async {
    if (!_ownsVolume || !value.isFinite) return false;
    final revision = ++_volumeRevision;
    final resolved = value.clamp(0.0, 1.0).toDouble();
    try {
      if (_usesSystemVolume) {
        await _volumeController.setVolume(resolved).timeout(_volumeOperationTimeout);
      } else {
        await _playerManager.setVolume(resolved).timeout(_volumeOperationTimeout);
      }
      // A system event can report the actual, quantized device level before
      // the setter completes. Never replace that event or a newer room's state.
      if (!_ownsVolume) return false;
      if (revision != _volumeRevision) return true;
      currentVolume.value = resolved;
      await room.saveCurrentVolume(resolved);
      return true;
    } catch (error, stack) {
      log('Set volume failed', name: 'VideoController.Volume', error: error, stackTrace: stack);
      return false;
    }
  }

  // 亮度管理
  Future<double> brightness() async {
    if (PlatformHelper.supportsBrightness) {
      return await brightnessController!.application;
    }
    throw Exception('Brightness not supported on this platform');
  }

  Future<void> setBrightness(double value) async {
    if (!PlatformHelper.supportsBrightness || !value.isFinite) return;
    try {
      await brightnessController!.setApplicationScreenBrightness(value.clamp(0.0, 1.0).toDouble());
    } catch (error, stackTrace) {
      log('Set brightness failed', name: 'VideoController.Brightness', error: error, stackTrace: stackTrace);
    }
  }

  // 控制器显示管理
  void enableController() {
    if (_isDisposed) return;
    showController.value = true;
    _armControllerHide();
  }

  void _armControllerHide() {
    if (_isDisposed) return;
    if (!_isMouseOverController && !_isMouseOverPlayer) {
      _controllerIdleClock.start();
      _controllerHideDeadlineMs = _controllerIdleClock.elapsedMilliseconds + _controllerHideDelay.inMilliseconds;
      showControllerTimer ??= Timer(_controllerHideDelay, _handleControllerHideDeadline);
    }
  }

  void _handleControllerHideDeadline() {
    showControllerTimer = null;
    if (_isDisposed || _isMouseOverController || _isMouseOverPlayer) return;
    final deadline = _controllerHideDeadlineMs;
    if (deadline == null) return;
    final remainingMs = deadline - _controllerIdleClock.elapsedMilliseconds;
    if (remainingMs > 0) {
      showControllerTimer = Timer(Duration(milliseconds: remainingMs), _handleControllerHideDeadline);
      return;
    }
    _controllerHideDeadlineMs = null;
    showController.value = false;
  }

  void stopHideController() {
    showControllerTimer?.cancel();
    showControllerTimer = null;
    _controllerHideDeadlineMs = null;
  }

  // 鼠标进入控制器区域
  void onMouseEnterController([Object? owner]) {
    if (_isDisposed || !_controlHoverOwners.add(owner ?? _legacyControlHoverOwner)) return;
    stopHideController();
    showController.value = true;
  }

  // 鼠标离开控制器区域
  void onMouseExitController([Object? owner]) {
    if (_isDisposed || !_controlHoverOwners.remove(owner ?? _legacyControlHoverOwner)) return;
    // Unmount can occur during build. Re-arm without publishing Rx changes,
    // and never release another mounted control bar's hover ownership.
    _armControllerHide();
  }

  // 鼠标进入播放器区域
  void onMouseEnterPlayer() {
    _isMouseOverPlayer = true;
    showController.value = true;
    stopHideController();
  }

  void onMouseHoverPlayer() {
    _isMouseOverPlayer = false;
    // Pointer hover can fire hundreds of times per second on high polling-rate
    // mice. Extend one monotonic deadline instead of cancelling and allocating
    // a Timer for every event.
    enableController();
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
    final settings = SettingsService.to.danmaku;
    final resolvedFps = settings.danmakuAutoFps.v
        ? settings.resolvedDanmakuFps(refreshRateMode: SettingsService.to.app.refreshRateMode)
        : danmakuFps.value.clamp(30, 240).toInt();
    danmakuController.updateConfig(
      BarrageConfig(
        // Dispatching at 16 ms allowed up to 60 new paragraphs per second on
        // busy rooms. A 50 ms admission interval plus the adaptive renderer
        // cap bounds paragraph layout, paint pressure and heat.
        emitInterval: 0.05,
        fontSize: danmakuFontSize.value,
        area: danmakuArea.value,
        topAreaDistance: danmakuTopArea.value,
        bottomAreaDistance: danmakuBottomArea.value,
        baseSpeed: danmakuSpeed.value,
        opacity: danmakuOpacity.value,
        fontWeight: FontWeight(danmakuFontWeight.value),
        strokeWidth: danmakuFontBorder.value,
        showStroke: enableDanmakuStroke.value,
        noEmojiMode: noEmojiMode.value,
        fps: resolvedFps,
        maxVisibleCount: 48,
        maxPendingCount: 120,
        maxPendingAge: const Duration(seconds: 5),
        barragePoolMaxSize: 72,
        pictureCacheMaxSize: 96,
        textCacheMaxSize: 320,
        trackHeight: (danmakuFontSize.value * 1.55).clamp(24.0, 64.0).toDouble(),
        emojiSize: (danmakuFontSize.value * 1.3).clamp(16.0, 48.0).toDouble(),
      ),
    );
  }

  void sendDanmaku(LiveMessage msg) {
    _danmakuManager.sendDanmaku(msg, _playerManager.isPlayingNow, _playerManager.isCompactModeActive);
  }

  bool handleDanmakuPointer(Offset globalPosition, {required bool longPress}) {
    final renderObject = danmuKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return false;
    final localPosition = renderObject.globalToLocal(globalPosition);
    if (localPosition.dx < 0 ||
        localPosition.dy < 0 ||
        localPosition.dx > renderObject.size.width ||
        localPosition.dy > renderObject.size.height) {
      return false;
    }
    return _danmakuManager.handlePointer(localPosition, longPress: longPress);
  }

  void clearPipDanmaku() => pipDanmakuController.clear();

  void clearDanmaku() {
    danmakuController.resume();
    pipDanmakuController.resume();
    danmakuController.clear();
    pipDanmakuController.clear();
  }

  // EPG管理
  Future<void> loadFullChannelSchedule(String? epgId) async {
    final loadEpoch = ++_epgLoadEpoch;
    if (_isDisposed) return;
    final normalizedEpgId = epgId?.trim() ?? '';
    final sourceId = _settingsService.iptv.selectedSourceId.v.trim();
    scheduleLoadFailed.value = false;
    if (normalizedEpgId.isEmpty || sourceId.isEmpty) {
      scheduleLoading.value = false;
      currentChannelSchedule.clear();
      hasScrolledToLive = false;
      return;
    }
    scheduleLoading.value = true;
    currentChannelSchedule.clear();
    hasScrolledToLive = false;

    final now = DateTime.now();
    final startTime = now.subtract(const Duration(days: _epgLookBackDays));
    final endTime = now.add(const Duration(days: _epgLookForwardDays));

    try {
      final loader = _loadEpgProgrammes;
      final programmes = loader == null
          ? await _fetchEpgProgrammes(sourceId: sourceId, epgId: normalizedEpgId, start: startTime, end: endTime)
          : await loader(sourceId: sourceId, epgId: normalizedEpgId, start: startTime, end: endTime);
      if (!_isEpgLoadCurrent(loadEpoch, sourceId)) return;
      currentChannelSchedule.value = programmes;
      _logEpgLoadSuccess(programmes.length);
    } catch (e, stackTrace) {
      if (!_isEpgLoadCurrent(loadEpoch, sourceId)) return;
      scheduleLoadFailed.value = true;
      _logEpgLoadError(e, stackTrace);
    } finally {
      if (!_isDisposed && loadEpoch == _epgLoadEpoch) {
        scheduleLoading.value = false;
      }
    }
  }

  bool claimInitialScheduleScroll(int liveIndex) {
    if (liveIndex < 0 || hasScrolledToLive) return false;
    hasScrolledToLive = true;
    return true;
  }

  bool _isEpgLoadCurrent(int loadEpoch, String sourceId) {
    return !_isDisposed && loadEpoch == _epgLoadEpoch && _settingsService.iptv.selectedSourceId.v.trim() == sourceId;
  }

  Future<List<database.EpgProgramme>> _fetchEpgProgrammes({
    required String sourceId,
    required String epgId,
    required DateTime start,
    required DateTime end,
  }) async {
    final db = _dbService.db;
    final resolved = await db.resolveEpgChannelId(sourceId, epgId);
    if (resolved == null) return [];
    return db.getProgrammes(epgChannelId: resolved, start: start, end: end);
  }

  void _logEpgLoadSuccess(int count) {
    debugPrint(
      "📅 [EPG Matrix] Loaded $count total program rows spanning the (-${_epgLookBackDays}d to +${_epgLookForwardDays}d) timeline.",
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
    DateTime? now,
  }) {
    return buildIptvCatchupUrl(
      originalUrl: originalUrl,
      start: programme.start,
      stop: programme.stop,
      type: type,
      now: now,
      mode: room.catchUpMode,
      source: room.catchUpSource,
      correctionHours: room.catchUpCorrectionHours,
      catchupId: programme.catchupId,
    );
  }

  Future<IptvProgrammeSelectionResult> onProgrammeTapped(
    database.EpgProgramme programme, {
    DateTime? now,
    VoidCallback? closeSchedule,
    ValueChanged<String>? showMessage,
  }) async {
    if (catchUpSwitching.value) return IptvProgrammeSelectionResult.busy;
    final actionTime = now ?? DateTime.now();
    final phase = classifyIptvProgramme(start: programme.start, stop: programme.stop, now: actionTime);
    final notify = showMessage ?? ToastUtil.show;

    if (phase == IptvProgrammePhase.scheduled) {
      notify(i18n('program_scheduled_hint'));
      return IptvProgrammeSelectionResult.scheduled;
    }

    if (phase == IptvProgrammePhase.live) {
      return returnToLive(closeSchedule: closeSchedule, showMessage: showMessage);
    }

    final availability = evaluateIptvCatchupAvailability(
      programmeStop: programme.stop,
      now: actionTime,
      mode: room.catchUpMode,
      source: room.catchUpSource,
      days: room.catchUpDays,
      catchupId: programme.catchupId,
    );
    if (availability != IptvCatchupAvailability.available) {
      notify(i18n('catchup_unavailable'));
      return IptvProgrammeSelectionResult.catchupUnavailable;
    }

    final originalUrl = room.link?.trim() ?? '';
    if (originalUrl.isEmpty) {
      notify(i18n('invalid_play_url'));
      return IptvProgrammeSelectionResult.invalidUrl;
    }

    late final String catchupUrl;
    try {
      catchupUrl = generateCatchupUrl(
        originalUrl: originalUrl,
        programme: programme,
        type: CatchupUrlType.playseek,
        now: actionTime,
      );
    } on FormatException {
      notify(i18n('invalid_play_url'));
      return IptvProgrammeSelectionResult.invalidUrl;
    } on ArgumentError {
      notify(i18n('invalid_play_url'));
      return IptvProgrammeSelectionResult.invalidUrl;
    } on UnsupportedError {
      notify(i18n('catchup_unavailable'));
      return IptvProgrammeSelectionResult.catchupUnavailable;
    }

    catchUpSwitching.value = true;
    _closeSchedule(closeSchedule);
    try {
      final switchResult = await _reloadWithCatchup(catchupUrl, programme);
      if (switchResult == IptvPlaybackSwitchResult.superseded) {
        return IptvProgrammeSelectionResult.superseded;
      }
      if (switchResult == IptvPlaybackSwitchResult.failed) {
        notify(i18n('play_video_failed'));
        return IptvProgrammeSelectionResult.failed;
      }
      notify('${i18n('playing_catchup')}: ${programme.title}');
      return IptvProgrammeSelectionResult.catchupStarted;
    } catch (error, stackTrace) {
      log('IPTV catch-up switch failed', name: 'VideoController', error: error, stackTrace: stackTrace);
      notify(i18n('play_video_failed'));
      return IptvProgrammeSelectionResult.failed;
    } finally {
      catchUpSwitching.value = false;
    }
  }

  Future<IptvProgrammeSelectionResult> returnToLive({
    VoidCallback? closeSchedule,
    ValueChanged<String>? showMessage,
  }) async {
    if (catchUpSwitching.value) return IptvProgrammeSelectionResult.busy;
    if (!room.isCatchUpActive) {
      _closeSchedule(closeSchedule);
      return IptvProgrammeSelectionResult.live;
    }
    if ((room.link?.trim() ?? '').isEmpty) {
      (showMessage ?? ToastUtil.show)(i18n('invalid_play_url'));
      return IptvProgrammeSelectionResult.invalidUrl;
    }

    catchUpSwitching.value = true;
    _closeSchedule(closeSchedule);
    final notify = showMessage ?? ToastUtil.show;
    try {
      final switchResult = await _reloadWithLive();
      if (switchResult == IptvPlaybackSwitchResult.superseded) {
        return IptvProgrammeSelectionResult.superseded;
      }
      if (switchResult == IptvPlaybackSwitchResult.failed) {
        notify(i18n('play_video_failed'));
        return IptvProgrammeSelectionResult.failed;
      }
      notify(i18n('returned_to_live'));
      return IptvProgrammeSelectionResult.live;
    } catch (error, stackTrace) {
      log('IPTV return-to-live switch failed', name: 'VideoController', error: error, stackTrace: stackTrace);
      notify(i18n('play_video_failed'));
      return IptvProgrammeSelectionResult.failed;
    } finally {
      catchUpSwitching.value = false;
    }
  }

  void _closeSchedule(VoidCallback? closeSchedule) {
    if (closeSchedule != null) {
      closeSchedule();
      return;
    }
    final context = Get.context;
    if (context != null && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<IptvPlaybackSwitchResult> _reloadWithCatchup(String catchupUrl, database.EpgProgramme programme) async {
    clearListener();
    await _playerManager.close();
    await destory();
    return _livePlayController.startCatchUp(
      catchUpUrl: catchupUrl,
      startTime: programme.start.millisecondsSinceEpoch,
      endTime: programme.stop.millisecondsSinceEpoch,
    );
  }

  Future<IptvPlaybackSwitchResult> _reloadWithLive() async {
    clearListener();
    await _playerManager.close();
    await destory();
    return _livePlayController.returnToLive();
  }

  // 播放控制
  Future<void> toggleAudioOnly() async {
    if (audioModeSwitching.value) return;
    audioModeSwitching.value = true;
    try {
      // The controls can become visible while the room's native open Future is
      // still finishing. Let that initial source/track selection settle first,
      // otherwise its stale `audioOnly` argument can overwrite this tap.
      final activeSession = _playerManager.hasActivePlaybackSession(room);
      if (!activeSession) {
        await initialization.timeout(_playerManager.audioModeSwitchTimeout);
      }
      if (_isDisposed) return;
      await onAudioOnlyChanged?.call(!isAudioOnly);
    } catch (error, stackTrace) {
      log('Audio mode action failed: $error', name: 'VideoController', error: error, stackTrace: stackTrace);
      if (!_isDisposed) {
        ToastUtil.show(i18n('error_lifecycle'));
      }
    } finally {
      audioModeSwitching.value = false;
    }
  }

  Future<void> refresh() async {
    _livePlayController.invalidateRoomLoad();
    clearListener();
    await _playerManager.close();
    await destory();
    await _livePlayController.onInitPlayerState(reloadDataType: ReloadDataType.refreash);
  }

  Future<void> changeLine() async {
    _livePlayController.invalidateRoomLoad();
    clearListener();
    await _playerManager.close();
    await destory();
    await _livePlayController.onInitPlayerState(reloadDataType: ReloadDataType.changeLine, line: currentLineIndex);
  }

  void clearListener() {
    _acceptSourceCommits = false;
    final listenersToRemove = _subscriptions
        .where(
          (s) =>
              s is StreamSubscription<PlayerException> ||
              s is StreamSubscription<bool> ||
              s is StreamSubscription<PlaybackSourceCommitSnapshot>,
        )
        .toList();

    for (final sub in listenersToRemove) {
      sub.cancel();
      _subscriptions.remove(sub);
    }
  }

  void debounceListen(Function? func, [int delay = 1000]) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: delay), () {
      _debounceTimer = null;
      func?.call();
    });
  }

  // 全屏管理
  Future<void> exitFullScreen() async {
    await exitFullscreenWithOrientationRestore(
      state: _fullscreenOrientationRestore,
      exitFullscreen: WindowService().doExitFullScreen,
      restorePortrait: WindowService().verticalScreen,
      releaseOrientation: WindowService().followSystemOrientation,
    );
    GlobalPlayerState.to.isFullscreen.value = false;
  }

  bool _fullscreenTransitioning = false;

  Future<void> toggleFullScreen() async {
    if (_fullscreenTransitioning) return;
    _fullscreenTransitioning = true;
    showLocked.value = false;
    stopHideController();

    _controllerTransitionTimer?.cancel();
    _controllerTransitionTimer = Timer(_controllerHideDelay, () {
      _controllerTransitionTimer = null;
      enableController();
    });

    GlobalPlayerState.to.isWindowFullscreen.value = false;

    try {
      if (GlobalPlayerState.to.isFullscreen.value) {
        _livePlayController.setNormalScreen();
        await exitFullScreen();
      } else {
        _livePlayController.setFullScreen();
        await enterFullScreen();
      }
      enableController();
    } finally {
      _fullscreenTransitioning = false;
    }
  }

  Future<void> enterFullScreen({bool forceLandscape = false}) async {
    final isMobile = Platform.isAndroid || Platform.isIOS;
    _fullscreenOrientationRestore.begin(restorePortraitOnExit: isMobile && forceLandscape);
    await WindowService().doEnterFullScreen();
    GlobalPlayerState.to.isFullscreen.value = true;

    // Desktop full screen is already handled by window_manager above. Calling
    // landScape there issued a second setFullScreen(true) while the first
    // native transition was still running, producing inconsistent work-area
    // bounds on Windows systems with a side taskbar.
    if (Platform.isAndroid || Platform.isIOS) {
      if (forceLandscape) {
        await WindowService().landScape();
      } else {
        await applyFullscreenOrientationPolicy();
      }
    }
  }

  /// Explicit landscape-fullscreen action for a portrait live room.
  ///
  /// This is intentionally a one-shot presentation action rather than a
  /// settings mutation: users keep their preferred automatic policy while the
  /// visible room control can always request a conventional landscape view.
  Future<void> enterLandscapeFullScreen() async {
    if (_fullscreenTransitioning) return;
    _fullscreenTransitioning = true;
    showLocked.value = false;
    stopHideController();
    GlobalPlayerState.to.isWindowFullscreen.value = false;
    try {
      _livePlayController.setFullScreen();
      await enterFullScreen(forceLandscape: true);
      enableController();
    } finally {
      _fullscreenTransitioning = false;
    }
  }

  /// Enters the panel-dismiss fullscreen used only by a trusted portrait live
  /// source on Android phones. It bypasses the user's ordinary fullscreen
  /// orientation preference because the downward gesture explicitly requests
  /// a portrait presentation rather than the conventional landscape action.
  Future<void> enterPortraitFullScreen() async {
    final settings = _settingsService.player;
    if (_fullscreenTransitioning ||
        _livePlayController.state.value.ui.screenMode != VideoMode.normal ||
        GlobalPlayerState.to.isFullscreen.value ||
        !canEnterPortraitPanelFullscreen(
          isPortraitSource: _playerManager.isVerticalVideo.value,
          adaptationEnabled: settings.enablePortraitStreamAdaptation.v,
          adaptiveHeightEnabled: settings.portraitAdaptiveHeight.v,
          compatibilityLayout: settings.portraitLayoutMode == PortraitLayoutMode.compatibility,
          mobilePlatform: Platform.isAndroid,
        )) {
      return;
    }
    _fullscreenTransitioning = true;
    showLocked.value = false;
    stopHideController();
    GlobalPlayerState.to.isWindowFullscreen.value = false;
    try {
      _livePlayController.setPortraitFullScreen();
      await WindowService().doEnterFullScreen();
      final stillEligible = canEnterPortraitPanelFullscreen(
        isPortraitSource: _playerManager.isVerticalVideo.value,
        adaptationEnabled: settings.enablePortraitStreamAdaptation.v,
        adaptiveHeightEnabled: settings.portraitAdaptiveHeight.v,
        compatibilityLayout: settings.portraitLayoutMode == PortraitLayoutMode.compatibility,
        mobilePlatform: Platform.isAndroid,
      );
      if (_livePlayController.state.value.ui.screenMode != VideoMode.portraitFullscreen || !stillEligible) {
        _livePlayController.setNormalScreen();
        await exitFullScreen();
        return;
      }
      GlobalPlayerState.to.isFullscreen.value = true;
      await WindowService().verticalScreen();
      enableController();
    } finally {
      _fullscreenTransitioning = false;
    }
  }

  Future<void> exitPortraitFullScreen() async {
    if (_fullscreenTransitioning || _livePlayController.state.value.ui.screenMode != VideoMode.portraitFullscreen) {
      return;
    }
    _fullscreenTransitioning = true;
    try {
      _livePlayController.setNormalScreen();
      await exitFullScreen();
      enableController();
    } finally {
      _fullscreenTransitioning = false;
    }
  }

  Future<void> applyFullscreenOrientationPolicy() async {
    if (_isDisposed || !GlobalPlayerState.to.isFullscreen.value || !(Platform.isAndroid || Platform.isIOS)) return;
    if (_livePlayController.state.value.ui.screenMode == VideoMode.portraitFullscreen) {
      if (!_playerManager.isVerticalVideo.value) {
        await exitPortraitFullScreen();
      } else {
        await WindowService().verticalScreen();
      }
      return;
    }
    switch (_settingsService.player.portraitFullscreenPolicy) {
      case PortraitFullscreenPolicy.followSource:
        if (_playerManager.isVerticalVideo.value) {
          await WindowService().verticalScreen();
        } else {
          await WindowService().landScape();
        }
      case PortraitFullscreenPolicy.followSystem:
        await WindowService().followSystemOrientation();
      case PortraitFullscreenPolicy.landscape:
        await WindowService().landScape();
    }
  }

  void toggleWindowFullScreen() {
    showLocked.value = false;
    stopHideController();

    _controllerTransitionTimer?.cancel();
    _controllerTransitionTimer = Timer(_controllerHideDelay, () {
      _controllerTransitionTimer = null;
      enableController();
    });

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

    if (allowScreenKeepOn) await WakelockPlus.disable();
  }

  bool _resourcesDestroyed = false;

  @override
  void dispose() {
    if (_isDisposed) return;
    _epgLoadEpoch++;
    _setStatus(PlayerStatus.disposed);

    // 清理资源
    _playerManager.detachVideoController(this);
    _danmakuManager.dispose();
    _cancelAllTimers();
    scheduleScrollController.dispose();
    _controlHoverOwners.clear();
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
  final Stopwatch _controllerIdleClock = Stopwatch();
  int? _controllerHideDeadlineMs;
  // 添加鼠标状态跟踪
  final _controlHoverOwners = <Object>{};
  final _legacyControlHoverOwner = Object();
  bool get _isMouseOverController => _controlHoverOwners.isNotEmpty;
  bool _isMouseOverPlayer = false;
  Timer? _defaultFullscreenTimer;
  Timer? _controllerTransitionTimer;
  Timer? _debounceTimer;
  Timer? _hideVolumeTimer;
}
