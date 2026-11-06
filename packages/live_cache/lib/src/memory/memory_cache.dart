import 'dart:collection';

import 'package:live_cache/src/models/cache_statistics.dart';
import 'package:live_cache/src/models/memory_cache_config.dart';

final class _MemoryEntry<V> {
  const new(this.value, this.expiresAt, this.size);

  final V value;
  final DateTime expiresAt;
  final int size;
}

/// A bounded, TTL-aware LRU cache for short-lived API values.
///
/// Nothing is persisted; a restart starts empty. This complements the disk
/// image cache rather than replacing any repository's own state.
final class MemoryCache<K, V> {
  /// Creates a cache with [config].
  ///
  /// [estimateSize] supplies the byte estimate of an entry; the default
  /// guesses strings and byte lists and charges 512 bytes for anything else.
  new({required this.config, this.estimateSize});

  /// The entry and byte limits.
  final MemoryCacheConfig config;

  /// How many bytes an entry is charged.
  final int Function(K key, V value)? estimateSize;

  final LinkedHashMap<K, _MemoryEntry<V>> _entries = LinkedHashMap();

  int _estimatedBytes = 0;
  int _hits = 0;
  int _misses = 0;

  /// The number of live entries.
  int get length => _entries.length;

  /// The estimated bytes held.
  int get estimatedBytes => _estimatedBytes;

  /// The value under [key], marking it recently used; null on a miss or an
  /// expired entry.
  V? get(K key) {
    final entry = _entries.remove(key);
    if (entry == null) {
      _misses++;
      return null;
    }
    if (!entry.expiresAt.isAfter(DateTime.now().toUtc())) {
      _estimatedBytes -= entry.size;
      _misses++;
      return null;
    }
    _entries[key] = entry;
    _hits++;
    return entry.value;
  }

  /// Stores [value] under [key] for [ttl] (or the config's default).
  ///
  /// An entry larger than the whole byte budget is refused rather than
  /// evicting every other value for it.
  void set(K key, V value, {Duration? ttl}) {
    final size = estimateSize?.call(key, value) ?? _defaultSize(value);
    if (size > config.maxBytes) {
      return;
    }
    final previous = _entries.remove(key);
    if (previous != null) {
      _estimatedBytes -= previous.size;
    }
    final life = ttl ?? config.defaultTtl;
    _entries[key] = _MemoryEntry(value, DateTime.now().toUtc().add(life), size);
    _estimatedBytes += size;
    _trim();
  }

  /// Whether a live, unexpired entry exists.
  bool containsKey(K key) {
    final entry = _entries[key];
    if (entry == null) {
      return false;
    }
    if (!entry.expiresAt.isAfter(DateTime.now().toUtc())) {
      _entries.remove(key);
      _estimatedBytes -= entry.size;
      return false;
    }
    return true;
  }

  /// Removes [key] and answers its value, if any.
  V? remove(K key) {
    final entry = _entries.remove(key);
    if (entry == null) {
      return null;
    }
    _estimatedBytes -= entry.size;
    return entry.value;
  }

  /// Drops every entry.
  void clear() {
    _entries.clear();
    _estimatedBytes = 0;
  }

  /// Drops expired entries and answers how many went.
  int clearExpired() {
    final now = DateTime.now().toUtc();
    var removed = 0;
    for (final key in _entries.keys.toList()) {
      final entry = _entries[key]!;
      if (!entry.expiresAt.isAfter(now)) {
        _entries.remove(key);
        _estimatedBytes -= entry.size;
        removed++;
      }
    }
    return removed;
  }

  /// The counters the settings surface prints.
  MemoryCacheStatistics get statistics => MemoryCacheStatistics(
    entryCount: _entries.length,
    estimatedSize: _estimatedBytes,
    hitCount: _hits,
    missCount: _misses,
  );

  void _trim() {
    while (_entries.length > config.maxEntries || _estimatedBytes > config.maxBytes) {
      final oldest = _entries.keys.first;
      final entry = _entries.remove(oldest);
      if (entry != null) {
        _estimatedBytes -= entry.size;
      }
    }
  }

  int _defaultSize(V value) {
    if (value is String) {
      return value.length * 2;
    }
    if (value is List<int>) {
      return value.length;
    }
    return 512;
  }
}
