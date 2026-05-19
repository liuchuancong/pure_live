class LineFallbackManager {
  int _currentIndex = 0;
  int _tryCount = 0;

  String next(List<String> lines) {
    if (lines.isEmpty) {
      throw Exception('No playable line');
    }

    if (_tryCount >= lines.length) {
      throw Exception('All lines failed to play');
    }

    if (_currentIndex >= lines.length) {
      _currentIndex = 0;
    }

    final line = lines[_currentIndex];

    _currentIndex = (_currentIndex + 1) % lines.length;
    _tryCount++;

    return line;
  }

  void resetTryCount() {
    _tryCount = 0;
  }

  void reset() {
    _currentIndex = 0;
    _tryCount = 0;
  }
}
