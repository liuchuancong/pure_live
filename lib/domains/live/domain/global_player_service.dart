import 'dart:developer';

import 'package:pure_live/core/player/kernel/floating_playback.dart';
import 'package:pure_live/core/player/core/playback_lifecycle_coordinator.dart';
import 'package:pure_live/core/player/core/live_audio_service.dart';
import 'package:pure_live/domains/live/domain/live_player_facade.dart';
import 'package:pure_live/domains/live/domain/playback_source_interceptor.dart';
import 'package:pure_live/core/player/models/player_engine.dart';

class GlobalPlayerService {
  GlobalPlayerService._();

  static final GlobalPlayerService instance = GlobalPlayerService._();

  /// 取流接线的装配点：app 启动时注入 data 层的实现（FFmpeg 转封装 / manifest
  /// 重写），domain 只认 [PlaybackSourceInterceptor] 这个形状，不认识中继本身。
  /// 没有注入时按直连播放。
  static PlaybackSourceInterceptor Function()? sourceInterceptorFactory;

  late final LivePlayerFacade playerManager;
  late final FloatingPlayback floating;

  /// 应用生命周期策略。刻意挂在这里而不是某个视频组件上：全屏、转屏、浮窗都会
  /// 重建 presentation 层，配对放在组件里就会在组件被销毁时丢掉恢复的那一半。
  late final PlaybackLifecycleCoordinator lifecycle;

  LivePlayerFacade get player => playerManager;
  bool _initialized = false;
  Future<void>? _initializationFuture;

  bool get initialized => _initialized;

  Future<void> initialize({PlayerEngine defaultEngine = PlayerEngine.mediaKit}) async {
    if (_initialized) return;
    final inFlight = _initializationFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final operation = _initialize(defaultEngine);
    _initializationFuture = operation;
    try {
      await operation;
    } finally {
      if (identical(_initializationFuture, operation)) _initializationFuture = null;
    }
  }

  Future<void> _initialize(PlayerEngine defaultEngine) async {
    playerManager = LivePlayerFacade(defaultEngine: defaultEngine, sourceInterceptor: sourceInterceptorFactory?.call());
    floating = FloatingPlayback(facade: playerManager);
    playerManager.floating = floating;
    lifecycle = PlaybackLifecycleCoordinator(
      // **后台暂停那条腿没有装配**，两个端口是显式的空实现：`enableBackgroundPlay`
      // 默认关，一旦接上，桌面端最小化窗口就会在 1.5 秒后暂停播放——那是另一个
      // 产品决定，不该跟着省电这条腿悄悄生效。`_applyHiddenPause` 拿到 null 令牌
      // 因此什么也不做，而纯音频省电与恢复照常工作。要接后台暂停就把这两个端口
      // 换成真正的 pause/resume（带 sessionId 与 intentRevision 的令牌）。
      pauseForLifecycle: () async => null,
      resumeFromLifecycle: (_) async => false,
      shouldContinueInBackground: () => LiveAudioService.shouldContinueInBackground,
      isAudioOnly: () => playerManager.desiredAudioOnlyMode,
      isSleepSessionActive: () => LiveAudioService.isSleepSessionActive,
      // 前台手动切纯音频只是把画面盖住（解码继续，切回即时）；退到后台就真关掉
      // 视频解码，回前台再打开。助眠会话不在回前台时打开——它整夜都要省电，
      // 这个区别由 coordinator 的 `!isSleepSessionActive()` 判定。
      commitAudioOnlyPowerSaving: () => playerManager.setAudioOnly(true),
      prepareAudioOnlyVideoRestore: () => playerManager.setAudioOnly(false),
    )..start();
    _initialized = true;
    log("GlobalPlayerService: kernel facade ready.", name: "GlobalPlayerService");
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    await lifecycle.dispose();
    await floating.closeAppFloating();
    await playerManager.dispose();
    _initialized = false;
    log("GlobalPlayerService: Disposed.", name: "GlobalPlayerService");
  }
}
