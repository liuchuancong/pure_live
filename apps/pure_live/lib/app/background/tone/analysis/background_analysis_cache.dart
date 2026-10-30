import 'dart:collection' show LinkedHashMap;

import 'package:pure_live/app/background/tone/analysis/background_models.dart';

/// The key a result is cached under.
///
/// It names the media, its on-disk modification time when there is one, and
/// the algorithm version. It deliberately does not name the scrim, the blur,
/// the theme or the layout: changing those must not decode the wallpaper
/// again. A network address has no mtime and is keyed by its URL alone.
String backgroundAnalysisKey({required String identity, int? modifiedMs}) =>
    'v$kBackgroundAnalysisVersion|w$kBackgroundAnalysisSampleWidth|${modifiedMs ?? 'remote'}|$identity';

/// A bounded, in-memory store of analysis results.
///
/// Nothing is persisted: the app re-measures once per run, which keeps the
/// first sample honest after an algorithm change and costs one 64px decode per
/// wallpaper.
final class BackgroundAnalysisCache {
  /// Creates a cache holding at most [capacity] results.
  BackgroundAnalysisCache({this.capacity = 12}) : assert(capacity > 0, 'A cache needs at least one slot.');

  /// How many results are kept before the least recently used one is dropped.
  final int capacity;

  final LinkedHashMap<String, BackgroundAnalysisResult> _entries = LinkedHashMap();

  /// How many results are currently held.
  int get length => _entries.length;

  /// The result for [key], marking it as recently used; null when absent.
  BackgroundAnalysisResult? get(String key) {
    final value = _entries.remove(key);
    if (value != null) _entries[key] = value;
    return value;
  }

  /// Stores [value] under [key], evicting the least recently used result when
  /// the cache is full or the key was already present.
  void put(String key, BackgroundAnalysisResult value) {
    _entries.remove(key);
    _entries[key] = value;
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }

  /// Drops every result.
  void clear() => _entries.clear();
}
