import 'dart:ui' as ui;

class AtlasCache {
  final Map<String, ui.Image> _cache = {};

  int get size => _cache.length;

  bool contains(String key) => _cache.containsKey(key);

  ui.Image? get(String key) => _cache[key];

  void put(String key, ui.Image image) {
    if (_cache.containsKey(key)) return;
    _cache[key] = image;
  }

  ui.Image? remove(String key) {
    final image = _cache.remove(key);
    image?.dispose();
    return image;
  }

  void clear() {
    for (final image in _cache.values) {
      image.dispose();
    }
    _cache.clear();
  }
}
