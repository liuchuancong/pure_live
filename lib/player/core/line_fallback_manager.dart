class LineFallbackManager {
  int _currentIndex = 0;
  final Set<String> _failedLines = {};

  String next(List<String> lines) {
    if (lines.isEmpty) {
      throw Exception('No playable line');
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[_currentIndex];

      _currentIndex = (_currentIndex + 1) % lines.length;

      if (!_failedLines.contains(line)) {
        return line;
      }
    }
    throw Exception('All lines failed');
  }

  void markFailed(String line) {
    _failedLines.add(line);
  }

  void markSuccess(String line) {
    _failedLines.remove(line);
  }

  void reset() {
    _currentIndex = 0;
    _failedLines.clear();
  }

  bool hasAvailable(List<String> lines) {
    return lines.any((l) => !_failedLines.contains(l));
  }
}
