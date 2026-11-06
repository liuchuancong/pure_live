import 'package:flutter/painting.dart';

/// The bridge between the disk cache and Flutter's decoded-image cache.
///
/// Decoded bytes stay in `PaintingBinding.instance.imageCache`; this class
/// only remembers which provider keys belong to which category so a
/// category clear can evict exactly those, and reads the framework's own
/// counters for the statistics surface.
final class LiveCacheMemory {
  /// Creates an empty registry.
  new();

  /// The cap on remembered keys per category; the framework cache is much
  /// smaller than this, so only a long session reaches it.
  static const int _maxKeysPerCategory = 4096;

  final Map<String, Set<Object>> _keysByCategory = {};

  /// The decoded bytes Flutter holds.
  int get decodedBytes => PaintingBinding.instance.imageCache.currentSizeBytes;

  /// The decoded images Flutter holds.
  int get decodedCount => PaintingBinding.instance.imageCache.currentSize;

  /// The live images Flutter keeps for in-flight requests.
  int get liveCount => PaintingBinding.instance.imageCache.liveImageCount;

  /// Remembers that [key] decodes an image of [category].
  void register(String category, Object key) {
    final keys = _keysByCategory.putIfAbsent(category, () => <Object>{});
    if (keys.length >= _maxKeysPerCategory) {
      keys.clear();
    }
    keys.add(key);
  }

  /// Evicts every remembered decoded image of [category].
  void evictCategory(String category) {
    final keys = _keysByCategory.remove(category);
    if (keys == null) {
      return;
    }
    keys.forEach(PaintingBinding.instance.imageCache.evict);
  }

  /// Evicts every decoded image this cache issued.
  void clear() {
    final imageCache = PaintingBinding.instance.imageCache;
    for (final keys in _keysByCategory.values) {
      keys.forEach(imageCache.evict);
    }
    _keysByCategory.clear();
  }
}
