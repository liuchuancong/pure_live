/// Hot words and search suggestions a platform can answer beside the source
/// contract — lx-music's `hotSearch.js` and `tipSearch.js` per platform.
abstract interface class MusicHotWords {
  /// The viewer-shown top searches, shown while the query box is empty.
  Future<List<String>> hotSearches();

  /// The completion candidates for a partially typed query.
  Future<List<String>> suggestions(String query);
}

/// Pulls plain string words out of a raw answer list, skipping damaged rows.
List<String> hotWordsOf(Iterable<Object?> rows) => [
  for (final row in rows)
    if (row case final String word when word.trim().isNotEmpty) word.trim(),
];
