// Module: lib/src/cache_stats.dart
// Purpose: The counters that make a cache's behaviour observable instead of assumed.
// Author: liuchuancong
// Created: 2026-10-11
//
// "The cache works" is not a claim anyone can make from a hit ratio they never measured. These counters are
// cheap (integer increments on paths that already do IO) and they are what a diagnostics screen shows when a
// user reports that a screen reloads every time.

/// One cache's running totals since construction or the last [reset].
final class CacheStats {
  CacheStats();

  int hits = 0;
  int misses = 0;

  /// Reads served by joining an already-running load instead of starting a second one.
  int coalesced = 0;

  int loads = 0;
  int loadFailures = 0;

  /// Entries dropped to stay inside a budget, and the bytes that went with them.
  int evictions = 0;
  int evictedBytes = 0;

  /// Stale entries served while a refresh ran, and stale entries served because the refresh failed.
  int staleServed = 0;
  int staleServedOnError = 0;

  int bytesWritten = 0;
  int bytesRead = 0;

  Duration totalLoadTime = Duration.zero;

  int get reads => hits + misses;

  /// Hits over reads, or null before the first read.
  ///
  /// Null rather than 0 because "no reads yet" and "every read missed" are different facts, and a settings
  /// screen that shows 0% for an unused cache invites the wrong fix.
  double? get hitRatio => reads == 0 ? null : hits / reads;

  Duration get averageLoadTime => loads == 0 ? Duration.zero : totalLoadTime ~/ loads;

  Map<String, Object?> toJson() => <String, Object?>{
    'hits': hits,
    'misses': misses,
    'coalesced': coalesced,
    'loads': loads,
    'loadFailures': loadFailures,
    'evictions': evictions,
    'evictedBytes': evictedBytes,
    'staleServed': staleServed,
    'staleServedOnError': staleServedOnError,
    'bytesWritten': bytesWritten,
    'bytesRead': bytesRead,
    'totalLoadMs': totalLoadTime.inMilliseconds,
    if (hitRatio != null) 'hitRatio': (hitRatio! * 100).round(),
  };

  void reset() {
    hits = 0;
    misses = 0;
    coalesced = 0;
    loads = 0;
    loadFailures = 0;
    evictions = 0;
    evictedBytes = 0;
    staleServed = 0;
    staleServedOnError = 0;
    bytesWritten = 0;
    bytesRead = 0;
    totalLoadTime = Duration.zero;
  }

  @override
  String toString() {
    final ratio = hitRatio;
    return 'CacheStats(${ratio == null ? 'no reads' : '${(ratio * 100).round()}% hit'}, '
        '$coalesced coalesced, $loads loads/$loadFailures failed, $evictions evictions)';
  }
}
