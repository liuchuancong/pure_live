import 'dart:ui' as ui;
import 'dart:collection';

class PictureCache {
  PictureCache({required this.maxSize});

  int maxSize;
  int get size => _cache.length;

  final LinkedHashMap<String, ui.Picture> _cache = LinkedHashMap<String, ui.Picture>();

  ui.Picture? get(String key) {
    final picture = _cache.remove(key);
    if (picture != null) {
      _cache[key] = picture;
      return picture;
    }
    return null;
  }

  void put(String key, ui.Picture picture) {
    _cache.remove(key);
    if (_cache.length >= maxSize && _cache.isNotEmpty) {
      final firstKey = _cache.keys.first;
      final oldest = _cache.remove(firstKey);
      oldest?.dispose();
    }
    _cache[key] = picture;
  }

  void updateMaxSize(int newMaxSize) {
    if (newMaxSize <= 0) return;
    maxSize = newMaxSize;
    while (_cache.length > maxSize && _cache.isNotEmpty) {
      final firstKey = _cache.keys.first;
      final oldest = _cache.remove(firstKey);
      oldest?.dispose();
    }
  }

  void clear() {
    for (final picture in _cache.values) {
      picture.dispose();
    }
    _cache.clear();
  }
}
