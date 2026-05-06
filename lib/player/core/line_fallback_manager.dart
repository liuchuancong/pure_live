class LineFallbackManager {
  int _currentIndex = 0;

  String next(List<String> lines) {
    if (lines.isEmpty) throw Exception('No playable line');

    final line = lines[_currentIndex]; // 先取当前
    _currentIndex = (_currentIndex + 1) % lines.length; // 再推进
    return line;
  }

  void reset() {
    _currentIndex = 0;
  }
}
