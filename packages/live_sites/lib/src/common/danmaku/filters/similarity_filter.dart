// Constructors spell their class name by convention here; the `.new`
// shorthand hurts readability more than the lint helps.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'dart:collection';

import 'package:live_sites/src/common/danmaku/filters/partial_ratio.dart';

/// Hides a text that is too similar to one shown in the last few seconds
/// (3.x `DanmakuSimilarityFilter`; off by default, see
/// `DanmakuFilterSettings`).
///
/// - Texts are trimmed and otherwise compared as they are: case, emoji and
///   punctuation count.
/// - An empty text is never shown.
/// - A text equal to a cached one, or whose [partialRatio] with one of the
///   newest [maxComparisons] cached texts reaches [similarityThreshold], is
///   hidden and refreshes that entry (moves it to the newest and restarts
///   its time).
/// - Entries older than [cacheDuration] are dropped; at most [maxCacheSize]
///   are kept.
final class DanmakuSimilarityFilter {
  /// Creates the filter: the threshold is clamped to 0–100, the cache size to
  /// 1–1000 and the comparisons per text to 1–256, as in 3.x.
  DanmakuSimilarityFilter({
    int similarityThreshold = 85,
    this._cacheDuration = const Duration(seconds: 3),
    int maxCacheSize = 100,
    int maxComparisons = 96,
    DateTime Function()? clock,
  }) : _similarityThreshold = similarityThreshold.clamp(0, 100),
       _maxCacheSize = maxCacheSize.clamp(1, 1000),
       maxComparisons = maxComparisons.clamp(1, 256),
       _clock = clock ?? DateTime.now;

  int _similarityThreshold;
  Duration _cacheDuration;
  int _maxCacheSize;
  final DateTime Function() _clock;
  final LinkedHashMap<String, _Cached> _cache = LinkedHashMap();

  /// Lowest score that counts as similar.
  int get similarityThreshold => _similarityThreshold;

  /// How long a shown text stays a reference.
  Duration get cacheDuration => _cacheDuration;

  /// Most texts kept.
  int get maxCacheSize => _maxCacheSize;

  /// Most cached texts one incoming text is compared with (the newest ones):
  /// bounds the work per message while the cache keeps its full history.
  final int maxComparisons;

  /// Texts compared by the last [shouldDisplay] (for tests).
  int get lastComparisonCount => _lastComparisonCount;
  int _lastComparisonCount = 0;

  /// Texts cached now.
  int get cacheSize => _cache.length;

  /// Changes the settings; omitted ones stay. A smaller [maxCacheSize] drops
  /// the oldest entries at once.
  void updateConfig({int? similarityThreshold, Duration? cacheDuration, int? maxCacheSize}) {
    if (similarityThreshold != null) _similarityThreshold = similarityThreshold.clamp(0, 100);
    if (cacheDuration != null) _cacheDuration = cacheDuration;
    if (maxCacheSize != null) {
      _maxCacheSize = maxCacheSize.clamp(1, 1000);
      _trim();
    }
  }

  /// Whether [text] should be shown; a shown text becomes a reference.
  bool shouldDisplay(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) return false;
    final now = _clock();
    _lastComparisonCount = 0;
    _cache.removeWhere((_, cached) => now.difference(cached.lastSeenAt) > _cacheDuration);

    final exact = _cache[normalized];
    if (exact != null) {
      _refresh(normalized, exact, now);
      return false;
    }
    var skipped = (_cache.length - maxComparisons).clamp(0, _cache.length);
    for (final MapEntry(:key, :value) in _cache.entries) {
      if (skipped > 0) {
        skipped--;
        continue;
      }
      _lastComparisonCount++;
      if (partialRatio(value.text, normalized) >= _similarityThreshold) {
        _refresh(key, value, now);
        return false;
      }
    }
    _cache[normalized] = _Cached(normalized, now);
    _trim();
    return true;
  }

  /// Forgets every reference.
  void clear() => _cache.clear();

  void _refresh(String key, _Cached cached, DateTime now) {
    cached.lastSeenAt = now;
    _cache
      ..remove(key)
      ..[key] = cached;
  }

  void _trim() {
    while (_cache.length > _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
  }
}

final class _Cached {
  _Cached(this.text, this.lastSeenAt);

  final String text;
  DateTime lastSeenAt;
}
