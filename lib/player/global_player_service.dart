import 'dart:developer';

import 'core/player_manager.dart';
import 'models/player_engine.dart';
import 'core/line_fallback_manager.dart';
import 'core/engine_fallback_manager.dart';
import 'core/live_audio_service.dart';
import 'core/playback_lifecycle_coordinator.dart';

import 'package:pure_live/common/global/platform_utils.dart';

class GlobalPlayerService {
  GlobalPlayerService._();

  static final GlobalPlayerService instance = GlobalPlayerService._();

  late final PlayerManager playerManager;
  late final PlaybackLifecycleCoordinator playbackLifecycle;
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
    // 1. Instantiate the Orchestrator with all its specialized managers
    playerManager = PlayerManager(
      fallbackManager: EngineFallbackManager(
        defaultEngine: defaultEngine,
        supportedEngines: PlatformUtils.isMobile ? PlayerEngine.values : [PlayerEngine.mediaKit],
      ),
      lineManager: LineFallbackManager(),
    );
    LiveAudioService.configurePlaybackCommands(
      play: playerManager.resume,
      pause: playerManager.pause,
      stop: playerManager.stop,
      pauseForInterruption: playerManager.pauseForAudioInterruption,
      resumeFromInterruption: playerManager.resumeFromAudioInterruption,
    );

    // 2. Keep native decoders, network workers and textures cold until the
    // first room is opened. This avoids paying hundreds of MiB and background
    // CPU merely for browsing the home/settings UI.
    playerManager.configureDefaultEngine(defaultEngine);
    playbackLifecycle = PlaybackLifecycleCoordinator(
      pauseForLifecycle: playerManager.pauseForLifecycle,
      resumeFromLifecycle: playerManager.resumeFromLifecycle,
      // PiP/app-floating is still a visible playback presentation even though
      // Android may report the hosting Activity as hidden during transition.
      shouldContinueInBackground: () =>
          LiveAudioService.shouldContinueInBackground || playerManager.isCompactModeActive,
      isAudioOnly: () => playerManager.isAudioOnlyMode,
      isSleepSessionActive: () => LiveAudioService.isSleepSessionActive,
      commitAudioOnlyPowerSaving: playerManager.commitAudioOnlyPowerSaving,
      prepareAudioOnlyVideoRestore: playerManager.prepareAudioOnlyVideoRestore,
    )..start();
    _initialized = true;
    log("GlobalPlayerService: Ready for lazy player initialization.", name: "GlobalPlayerService");
  }

  /// Global dispose - Call this only when the app is being destroyed
  Future<void> dispose() async {
    if (!_initialized) return;
    await playbackLifecycle.dispose();
    await playerManager.dispose();
    _initialized = false;
    log("GlobalPlayerService: Disposed.", name: "GlobalPlayerService");
  }
}
