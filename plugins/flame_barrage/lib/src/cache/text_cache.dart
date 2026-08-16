import 'dart:ui' as ui;

class TextCache {
  TextCache({this.maxSize = 1000});

  final int maxSize;
  final Map<String, ui.Paragraph> _cache = {};

  int get size => _cache.length;

  bool contains(String key) => _cache.containsKey(key);

  ui.Paragraph? get(String key) {
    final value = _cache.remove(key);
    if (value != null) {
      _cache[key] = value;
    }
    return value;
  }

  void put(String key, ui.Paragraph paragraph) {
    if (_cache.containsKey(key)) return;

    if (_cache.length >= maxSize) {
      final firstKey = _cache.keys.first;
      _cache.remove(firstKey);
    }

    _cache[key] = paragraph;
  }

  void remove(String key) {
    _cache.remove(key);
  }

  void clear() {
    _cache.clear();
  }
}
