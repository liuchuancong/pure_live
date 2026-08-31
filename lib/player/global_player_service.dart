import 'dart:developer';

import 'core/player_manager.dart';
import 'models/player_engine.dart';
import 'core/line_fallback_manager.dart';
import 'core/engine_fallback_manager.dart';

import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/player/shaders/shader_asset_service.dart';

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
    await ShaderAssetService.instance.initialize();
    // 1. Instantiate the Orchestrator with all its specialized managers
    playerManager = PlayerManager(
      fallbackManager: EngineFallbackManager(
        defaultEngine: defaultEngine,
        supportedEngines: PlatformUtils.isMobile ? PlayerEngine.values : [PlayerEngine.mediaKit],
      ),
      lineManager: LineFallbackManager(),
    );

    // 2. Keep native decoders, network workers and textures cold until the
    // first room is opened. This avoids paying hundreds of MiB and background
    // CPU merely for browsing the home/settings UI.
    await playerManager.initialize(engine: defaultEngine, audioOnly: false);
    _initialized = true;
    log("GlobalPlayerService: Player initialized.", name: "GlobalPlayerService");
  }

  /// Global dispose - Call this only when the app is being destroyed
  Future<void> dispose() async {
    if (!_initialized) return;
    await playerManager.dispose();
    _initialized = false;
    log("GlobalPlayerService: Disposed.", name: "GlobalPlayerService");
  }
}
