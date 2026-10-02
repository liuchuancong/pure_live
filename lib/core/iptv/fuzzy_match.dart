import 'package:string_similarity/string_similarity.dart';

/// Tokenize a query string by splitting on spaces, commas, and pipes.
List<String> tokenizeQuery(String query) {
  return query
      .toLowerCase()
      .split(RegExp(r'[\s,|]+'))
      .where((t) => t.isNotEmpty)
      .toList();
}

/// Build a single lowercase searchable blob from nullable fields.
String buildSearchBlob(List<String?> fields) {
  return fields.where((f) => f != null).join(' ').toLowerCase();
}

/// Return a relevance score (0.0+) for [query] matched against [fields].
///
/// Tokenizes the query and scores each token:
/// - 1.0 for an exact substring match in the blob
/// - 0.5 for a fuzzy match (best word similarity > 0.6)
/// - 0.0 if the token doesn't match at all
///
/// ALL tokens must match for the result to pass (AND logic).
double fuzzyMatch(String query, List<String?> fields) {
  final tokens = tokenizeQuery(query);
  if (tokens.isEmpty) return 0.0;

  final blob = buildSearchBlob(fields);
  final blobWords =
      blob.split(RegExp(r'[\s,|]+'))
          .where((w) => w.isNotEmpty)
          .toList();

  var score = 0.0;
  for (final token in tokens) {
    if (blob.contains(token)) {
      score += 1.0;
    } else {
      // Check fuzzy similarity against individual words
      var bestSim = 0.0;
      for (final word in blobWords) {
        final sim = StringSimilarity.compareTwoStrings(token, word);
        if (sim > bestSim) bestSim = sim;
      }
      if (bestSim > 0.6) {
        score += 0.5;
      } else {
        // Token didn't match at all — AND fails
        return 0.0;
      }
    }
  }
  return score;
}

/// Whether ALL tokens in the query match the fields (AND logic).
bool fuzzyMatchPasses(String query, List<String?> fields) {
  final tokens = tokenizeQuery(query);
  if (tokens.isEmpty) return true;
  return fuzzyMatch(query, fields) > 0.0;
}
