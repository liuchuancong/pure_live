class LineFallbackManager {
  int _currentIndex = 0;

  String next(List<String> lines) {
    if (lines.isEmpty) throw Exception('No playable line');
    if (_currentIndex >= lines.length) {
      _currentIndex = 0;
    }
    final line = lines[_currentIndex];
    _currentIndex = (_currentIndex + 1) % lines.length;

    return line;
  }

  void reset() {
    _currentIndex = 0;
  }
}
