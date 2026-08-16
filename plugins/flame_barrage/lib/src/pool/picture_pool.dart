import 'dart:ui';

class PicturePool {
  PicturePool({this.maxSize = 50});

  final int maxSize;
  final Map<String, Picture> _cache = {};
  final List<String> _keys = [];

  Picture? get(String key) {
    return _cache[key];
  }

  void put(String key, Picture picture) {
    if (_cache.containsKey(key)) {
      return;
    }
    if (_cache.length >= maxSize) {
      final oldKey = _keys.removeAt(0);
      _cache.remove(oldKey)?.dispose();
    }
    _cache[key] = picture;
    _keys.add(key);
  }

  void clear() {
    for (final pic in _cache.values) {
      pic.dispose();
    }
    _cache.clear();
    _keys.clear();
  }
}
