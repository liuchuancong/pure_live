// Module: lib/src/domain/search_result_order.dart
// Purpose: Put aggregated search results in an order that does not depend on which source answered first.
// Author: liuchuancong
// Created: 2026-10-10
//
// The aggregator fans out and returns per-source buckets, so the naive concatenation is ordered by response
// latency. On a phone that is stable enough to look intentional and on a TV box with six sources it is not:
// the same query in the same app shows the same tile in a different row after a cold start, and the user
// reads it as the results being wrong. Ranking is therefore a rule about content, applied here, and a source
// that answers quickly gets no advantage.
//
// The tiers are what a person scanning a list actually keys on - an exact title match, then something that
// starts with the query, then something containing it - and the tail of the comparator is a total order over
// fields that are stable per item, so equal relevance never resolves by arrival.

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_search/pure_live_search.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

import 'search_term.dart';

/// How strongly an item matches the query.
enum SearchRelevance {
  /// The folded title equals the folded query.
  exactTitle,

  /// The folded title starts with the folded query.
  titlePrefix,

  /// The folded title or subtitle contains the folded query.
  partialMatch,

  /// Nothing in the item's own text matches; it is shown because a source returned it.
  unrelated,
}

/// The item plus the tier it fell in, for a ui that wants to label why it is first.
final class RankedResult {
  const RankedResult({required this.item, required this.relevance, required this.isDuplicateOf});

  final ContentSummary item;
  final SearchRelevance relevance;

  /// True when an identical reference already appears earlier in the list, so the ui can hide this one
  /// instead of showing the same tile twice from two sources that mirror each other.
  final bool isDuplicateOf;

  bool get isShowing => !isDuplicateOf;
}

/// Classifies [item] against [term].
SearchRelevance relevanceOf(SearchTerm term, ContentSummary item) {
  final title = normalizeToken(item.title);
  if (title == term.matchKey) {
    return SearchRelevance.exactTitle;
  }
  if (title.startsWith(term.matchKey)) {
    return SearchRelevance.titlePrefix;
  }
  final subtitle = item.subtitle;
  if (title.contains(term.matchKey) || (subtitle != null && normalizeToken(subtitle).contains(term.matchKey))) {
    return SearchRelevance.partialMatch;
  }
  return SearchRelevance.unrelated;
}

/// The ranked list: relevance first, then a stable total order, duplicates marked rather than dropped.
///
/// Dropping a duplicate silently would hide the fact that two sources serve the same content, which is
/// information the diagnostics view needs, so the flag says "not yours to render" and the caller decides.
List<RankedResult> rankSearchResults(SearchTerm term, SearchAggregate aggregate) {
  final ranked = <RankedResult>[];
  final seen = <String>{};
  for (final outcome in aggregate.outcomes) {
    for (final item in outcome.items) {
      final key = identityKey(<Object?>[item.ref.sourceId, item.ref.contentId]);
      ranked.add(RankedResult(item: item, relevance: relevanceOf(term, item), isDuplicateOf: !seen.add(key)));
    }
  }

  ranked.sort((left, right) {
    final byRelevance = left.relevance.index.compareTo(right.relevance.index);
    if (byRelevance != 0) {
      return byRelevance;
    }
    final byTitle = compareForOrder(left.item.title, right.item.title);
    if (byTitle != 0) {
      return byTitle;
    }
    final bySource = compareForOrder(left.item.ref.sourceId, right.item.ref.sourceId);
    if (bySource != 0) {
      return bySource;
    }
    return compareForOrder(left.item.ref.contentId, right.item.ref.contentId);
  });
  return ranked;
}

/// A total order that ignores the difference between "abc" and "ABC" and never falls back to identity.
int compareForOrder(String left, String right) {
  final folded = normalizeToken(left).compareTo(normalizeToken(right));
  // Folding makes two spellings equal; the raw comparison then breaks the tie deterministically instead of
  // leaving it to sort's notion of arrival order.
  return folded != 0 ? folded : left.compareTo(right);
}
