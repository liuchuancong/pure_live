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

  static PlaybackSourceInterceptor Function()? sourceInterceptorFactory;

  late final LivePlayerFacade playerManager;
  late final FloatingPlayback floating;

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
      pauseForLifecycle: () async => null,
      resumeFromLifecycle: (_) async => false,
      shouldContinueInBackground: () => LiveAudioService.shouldContinueInBackground,
      isAudioOnly: () => playerManager.desiredAudioOnlyMode,
      isSleepSessionActive: () => LiveAudioService.isSleepSessionActive,
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
