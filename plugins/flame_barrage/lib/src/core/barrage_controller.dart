class BarrageController {
  dynamic _engine;
  void Function(dynamic)? _onAddDanmaku;
  void Function(dynamic)? _onUpdateOption;
  void Function()? _onPause;
  void Function()? _onResume;
  void Function()? _onClear;

  bool running = true;
  int _totalEmittedCount = 0;

  dynamic get engine => _engine;

  set onAddDanmaku(void Function(dynamic) callback) => _onAddDanmaku = callback;
  set onUpdateOption(void Function(dynamic) callback) => _onUpdateOption = callback;
  set onPause(void Function() callback) => _onPause = callback;
  set onResume(void Function() callback) => _onResume = callback;
  set onClear(void Function() callback) => _onClear = callback;
  void togglePause() {
    if (running) {
      pause();
    } else {
      resume();
    }
  }

  void attach(dynamic engine) {
    _engine = engine;
  }

  void detach([dynamic engine]) {
    if (engine != null && !identical(_engine, engine)) return;
    _engine = null;
    _onAddDanmaku = null;
    _onUpdateOption = null;
    _onPause = null;
    _onResume = null;
    _onClear = null;
  }

  void send(dynamic item) {
    if (!running) return;
    _totalEmittedCount++;
    _onAddDanmaku?.call(item);
  }

  void updateConfig(dynamic newConfig) {
    _onUpdateOption?.call(newConfig);
  }

  void pause() {
    running = false;
    _onPause?.call();
  }

  void resume() {
    running = true;
    _onResume?.call();
  }

  void clear() {
    _onClear?.call();
  }

  bool triggerItemAt(double x, double y, {required bool longPress}) {
    final currentEngine = _engine;
    if (currentEngine == null) return false;
    try {
      return currentEngine.triggerItemAt(x, y, longPress: longPress) as bool;
    } catch (_) {
      return false;
    }
  }

  int get totalEmitted => _totalEmittedCount;

  int get pictureCacheCount {
    final currentEngine = _engine;
    if (currentEngine != null) {
      try {
        return currentEngine.activeCacheSize as int;
      } catch (_) {}
    }
    return 0;
  }

  int get poolObjectCount {
    final currentEngine = _engine;
    if (currentEngine != null) {
      try {
        return currentEngine.activePoolSize as int;
      } catch (_) {}
    }
    return 0;
  }

  int get pendingMessageCount {
    final currentEngine = _engine;
    if (currentEngine != null) {
      try {
        return currentEngine.pendingMessageCount as int;
      } catch (_) {}
    }
    return 0;
  }
}
