import 'dart:collection';

import 'package:fuzzywuzzy/fuzzywuzzy.dart';

/// Filters similar danmaku messages within a configurable time window.
///
/// A message is considered a duplicate when its similarity score with
/// a recently cached message reaches [similarityThreshold].
class DanmakuSimilarityFilter {
  DanmakuSimilarityFilter({
    int similarityThreshold = 85,
    this._cacheDuration = const Duration(seconds: 3),
    int maxCacheSize = 100,
    int maxComparisons = 96,
    DateTime Function()? clock,
  }) : _similarityThreshold = similarityThreshold.clamp(0, 100),
       _maxCacheSize = maxCacheSize.clamp(1, 1000),
       _maxComparisons = maxComparisons.clamp(1, 256),
       _clock = clock ?? DateTime.now;

  /// Minimum similarity score required to treat a message as a duplicate.
  int _similarityThreshold;

  /// How long a message remains in the similarity cache.
  Duration _cacheDuration;

  /// Maximum number of messages kept in the similarity cache.
  int _maxCacheSize;

  /// Bounds fuzzy work per incoming packet. Keeping the retained cache and the
  /// comparison budget separate avoids a burst of up to 1000 edit-distance
  /// calculations on the UI isolate while retaining the configured history.
  final int _maxComparisons;

  final DateTime Function() _clock;

  final LinkedHashMap<String, _CachedDanmaku> _cache = LinkedHashMap();

  int _lastComparisonCount = 0;

  int get similarityThreshold => _similarityThreshold;

  Duration get cacheDuration => _cacheDuration;

  int get maxCacheSize => _maxCacheSize;

  int get maxComparisons => _maxComparisons;

  /// Exposed for deterministic performance regression tests.
  int get lastComparisonCount => _lastComparisonCount;

  /// Updates the filter configuration at runtime.
  void updateConfig({int? similarityThreshold, Duration? cacheDuration, int? maxCacheSize}) {
    if (similarityThreshold != null) {
      _similarityThreshold = similarityThreshold.clamp(0, 100);
    }

    if (cacheDuration != null) {
      _cacheDuration = cacheDuration;
    }

    if (maxCacheSize != null) {
      _maxCacheSize = maxCacheSize.clamp(1, 1000);
      _trimCache();
    }
  }

  /// Returns whether the specified message should be displayed.
  ///
  /// Returns `true` when the message is considered new.
  /// Returns `false` when it is too similar to a recently displayed message.
  bool shouldDisplay(String text) {
    final normalizedText = _normalizeText(text);

    if (normalizedText.isEmpty) {
      return false;
    }

    final now = _clock();
    _lastComparisonCount = 0;

    _removeExpiredEntries(now);

    // Exact match can be handled without running the similarity algorithm.
    final cachedMessage = _cache[normalizedText];

    if (cachedMessage != null) {
      cachedMessage.count++;
      cachedMessage.lastSeenAt = now;
      _markAsNewest(normalizedText, cachedMessage);
      return false;
    }

    // Compare only the newest bounded window. Iteration still stays allocation
    // free; old retained entries are skipped before fuzzy matching begins.
    var skipped = (_cache.length - _maxComparisons).clamp(0, _cache.length);
    for (final entry in _cache.entries) {
      if (skipped > 0) {
        skipped--;
        continue;
      }
      final cached = entry.value;
      _lastComparisonCount++;
      final similarity = partialRatio(cached.text, normalizedText);

      if (similarity >= _similarityThreshold) {
        cached.count++;
        cached.lastSeenAt = now;
        _markAsNewest(entry.key, cached);
        return false;
      }
    }

    // Store the new message as a similarity reference.
    _cache[normalizedText] = _CachedDanmaku(text: normalizedText, lastSeenAt: now);

    _trimCache();

    return true;
  }

  /// Clears all cached danmaku messages.
  void clear() {
    _cache.clear();
  }

  /// Returns the current number of cached messages.
  int get cacheSize => _cache.length;

  void _removeExpiredEntries(DateTime now) {
    _cache.removeWhere((_, cached) => now.difference(cached.lastSeenAt) > _cacheDuration);
  }

  void _trimCache() {
    while (_cache.length > _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
  }

  void _markAsNewest(String key, _CachedDanmaku value) {
    _cache.remove(key);
    _cache[key] = value;
  }

  /// Removes whitespace characters without modifying the actual message.
  ///
  /// Emoji, punctuation, Unicode characters and other special characters
  /// are intentionally preserved for similarity comparison.
  String _normalizeText(String text) {
    return text.trim();
  }
}

class _CachedDanmaku {
  _CachedDanmaku({required this.text, required this.lastSeenAt}) : count = 1;

  final String text;

  DateTime lastSeenAt;

  int count;
}
