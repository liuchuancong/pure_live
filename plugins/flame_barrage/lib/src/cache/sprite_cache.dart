import 'package:flame/components.dart';

class SpriteCache {
  final Map<String, Sprite> _cache = {};

  int get size => _cache.length;

  bool contains(String key) => _cache.containsKey(key);

  Sprite? get(String key) => _cache[key];

  void put(String key, Sprite sprite) {
    if (_cache.containsKey(key)) return;
    _cache[key] = sprite;
  }

  void remove(String key) {
    _cache.remove(key);
  }

  void clear() {
    _cache.clear();
  }
}
