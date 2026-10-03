import 'dart:developer';

import 'package:pure_live/core/player/kernel/floating_playback.dart';
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
    _initialized = true;
    log("GlobalPlayerService: kernel facade ready.", name: "GlobalPlayerService");
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    await floating.closeAppFloating();
    await playerManager.dispose();
    _initialized = false;
    log("GlobalPlayerService: Disposed.", name: "GlobalPlayerService");
  }
}
