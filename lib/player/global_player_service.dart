import 'dart:developer';

import 'core/player_pool.dart';
import 'core/player_manager.dart';
import 'models/player_engine.dart';
import 'adapters/fijk_adapter.dart';
import 'adapters/media_kit_adapter.dart';
import 'core/line_fallback_manager.dart';

import 'core/preload_player_manager.dart';
import 'core/engine_fallback_manager.dart';
import 'adapters/video_player_adapter.dart';

import 'package:pure_live/common/global/platform_utils.dart';

class GlobalPlayerService {
  GlobalPlayerService._();

  static final GlobalPlayerService instance = GlobalPlayerService._();

  late final PlayerManager playerManager;
  PlayerManager get player => playerManager;
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
    // 1. Setup the Pool with a factory that knows how to create each Adapter
    final playerPool = PlayerPool(
      factory: (engine) async {
        switch (engine) {
          case PlayerEngine.mediaKit:
            return MediaKitAdapter();
          case PlayerEngine.fijk:
            return FijkAdapter();
          case PlayerEngine.exo:
            return BetterPlayerAdapter();
        }
      },
    );

    // 2. Instantiate the Orchestrator with all its specialized managers
    playerManager = PlayerManager(
      playerPool: playerPool,
      fallbackManager: EngineFallbackManager(
        defaultEngine: PlayerEngine.mediaKit,
        supportedEngines: PlatformUtils.isMobile ? PlayerEngine.values : [PlayerEngine.mediaKit],
      ),
      preloadManager: PreloadPlayerManager(),
      lineManager: LineFallbackManager(),
    );

    // 3. Keep native decoders, network workers and textures cold until the
    // first room is opened. This avoids paying hundreds of MiB and background
    // CPU merely for browsing the home/settings UI.
    playerManager.configureDefaultEngine(defaultEngine);
    _initialized = true;
    log("GlobalPlayerService: Ready for lazy player initialization.", name: "GlobalPlayerService");
  }

  /// Global dispose - Call this only when the app is being destroyed
  Future<void> dispose() async {
    if (!_initialized) return;
    await playerManager.dispose();
    _initialized = false;
    log("GlobalPlayerService: Disposed.", name: "GlobalPlayerService");
  }
}
