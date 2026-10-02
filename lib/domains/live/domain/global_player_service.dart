import 'dart:developer';

import 'package:pure_live/core/player/kernel/floating_playback.dart';
import 'package:pure_live/domains/live/domain/live_player_facade.dart';
import 'package:pure_live/core/player/models/player_engine.dart';

class GlobalPlayerService {
  GlobalPlayerService._();

  static final GlobalPlayerService instance = GlobalPlayerService._();

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
    playerManager = LivePlayerFacade(defaultEngine: defaultEngine);
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
