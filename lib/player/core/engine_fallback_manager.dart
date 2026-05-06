import 'dart:developer';
import '../models/player_engine.dart';
import '../models/player_exception.dart';
import '../models/player_error_type.dart';

class EngineFallbackManager {
  EngineFallbackManager({required this.defaultEngine, this.maxRetryCount = 2});

  final PlayerEngine defaultEngine;
  final int maxRetryCount;
  final Map<PlayerEngine, int> _retryMap = {};
  final Map<PlayerEngine, bool> _permanentlyFailed = {}; // 标记永久失败的引擎

  late final List<PlayerEngine> _priority = [defaultEngine, ...PlayerEngine.values.where((e) => e != defaultEngine)];

  bool shouldFallback(PlayerException error) {
    switch (error.type) {
      case PlayerErrorType.codec:
      case PlayerErrorType.native:
      case PlayerErrorType.texture:
      case PlayerErrorType.initialization:
        return true;
      default:
        return false;
    }
  }

  Future<PlayerEngine> fallback(PlayerEngine current, PlayerException error) async {
    // 标记当前引擎已失败一次
    final retry = _retryMap[current] ?? 0;
    _retryMap[current] = retry + 1;

    // 如果达到最大重试次数，标记此引擎为永久失败
    if (retry + 1 >= maxRetryCount) {
      _permanentlyFailed[current] = true;
      log("❌ 引擎 $current 已被标记为永久失败");
    }

    // 查找一个未失败的引擎
    for (final engine in _priority) {
      if (!_permanentlyFailed.containsKey(engine) || !_permanentlyFailed[engine]!) {
        if (engine != current) {
          // 不返回当前引擎
          log("🔄 引擎降级: $current -> $engine");
          return engine;
        }
      }
    }

    log("⚠️ 所有引擎都失败了，返回默认引擎并重置");
    _permanentlyFailed.clear();
    return defaultEngine;
  }

  void reset(PlayerEngine engine) {
    _retryMap[engine] = 0;
    _permanentlyFailed.remove(engine); // 移除永久失败标记
  }

  // 新增：重置所有状态
  void resetAll() {
    _retryMap.clear();
    _permanentlyFailed.clear();
  }
}
