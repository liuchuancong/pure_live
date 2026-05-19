import 'dart:developer';
import '../models/player_engine.dart';
import '../models/player_exception.dart';
import '../models/player_error_type.dart';

class EngineFallbackManager {
  EngineFallbackManager({required this.defaultEngine, this.maxRetryCount = 2, required this.supportedEngines});
  final List<PlayerEngine> supportedEngines;

  final PlayerEngine defaultEngine;
  final int maxRetryCount;

  final Map<PlayerEngine, int> _retryMap = {};
  final Set<PlayerEngine> _permanentlyFailed = {};

  late final List<PlayerEngine> _priority = [
    defaultEngine,
    ...PlayerEngine.values,
  ].where((e) => supportedEngines.contains(e)).toList();

  bool shouldFallback(PlayerException error) {
    switch (error.type) {
      case PlayerErrorType.codec:
      case PlayerErrorType.native:
      case PlayerErrorType.texture:
      case PlayerErrorType.initialization:
      case PlayerErrorType.source:
        return true;
      default:
        return false;
    }
  }

  Future<PlayerEngine> fallback(PlayerEngine current, PlayerException error) async {
    if (supportedEngines.length <= 1) {
      return defaultEngine;
    }
    final currentRetry = _retryMap[current] ?? 0;
    final nextRetry = currentRetry + 1;
    _retryMap[current] = nextRetry;

    if (nextRetry < maxRetryCount) {
      return current;
    }

    _permanentlyFailed.add(current);
    for (final engine in _priority) {
      if (!_permanentlyFailed.contains(engine)) {
        log("🔄 引擎降级成功: $current -> $engine");
        _retryMap[engine] = 0;
        return engine;
      }
    }

    resetAll();
    throw error;
  }

  void reset(PlayerEngine engine) {
    _retryMap[engine] = 0;
    _permanentlyFailed.remove(engine);
  }

  void resetAll() {
    _retryMap.clear();
    _permanentlyFailed.clear();
  }
}
