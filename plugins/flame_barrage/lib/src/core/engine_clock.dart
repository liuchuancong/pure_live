class EngineClock {
  double scale = 1.0;
  double _elapsedMs = 0.0;
  bool _isPaused = false;

  int now() => _elapsedMs.round();

  void tick(double dt) {
    if (!_isPaused) _elapsedMs += dt * 1000.0 * scale;
  }

  void pause() {
    if (_isPaused) return;
    _isPaused = true;
  }

  void resume() {
    if (!_isPaused) return;
    _isPaused = false;
  }

  void reset() {
    _elapsedMs = 0.0;
    _isPaused = false;
  }

  bool get isPaused => _isPaused;
}
