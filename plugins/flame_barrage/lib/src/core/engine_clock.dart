class EngineClock {
  double scale = 1.0;
  final int _startMs = DateTime.now().millisecondsSinceEpoch;
  bool _isPaused = false;
  int _pausedAt = 0;
  int _pauseAccumulatedMs = 0;

  int now() {
    final real = DateTime.now().millisecondsSinceEpoch;
    final double logicalRaw = (real - _startMs - _pauseAccumulatedMs) * scale;
    return logicalRaw.round();
  }

  void tick(double dt) {}

  void pause() {
    if (_isPaused) return;
    _isPaused = true;
    _pausedAt = DateTime.now().millisecondsSinceEpoch;
  }

  void resume() {
    if (!_isPaused) return;
    final realNow = DateTime.now().millisecondsSinceEpoch;
    _pauseAccumulatedMs += realNow - _pausedAt;
    _isPaused = false;
  }

  void reset() {
    _pauseAccumulatedMs = 0;
    _isPaused = false;
    _pausedAt = 0;
  }

  bool get isPaused => _isPaused;
}
