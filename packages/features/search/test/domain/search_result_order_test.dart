// Module: test/domain/search_result_order_test.dart
// Purpose: Pins that the rendered order is a rule about content, not a race between sources.
// Author: liuchuancong
// Created: 2026-10-10

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_search/pure_live_search.dart';
import 'package:pure_live_search_feature/pure_live_search_feature.dart';
import 'package:test/test.dart';

ContentSummary _item(String sourceId, String contentId, String title, {String? subtitle}) => ContentSummary(
  ref: ContentRef(sourceId: sourceId, contentId: contentId, kind: ContentKind.vod),
  title: title,
  subtitle: subtitle,
);

SearchAggregate _aggregate(SearchTerm term, List<ContentSummary> slowThenFast) => SearchAggregate(
  query: SearchQuery(keyword: term.display),
  outcomes: <SearchProviderOutcome>[
    SearchProviderOutcome(
      sourceId: slowThenFast.first.ref.sourceId,
      kind: SearchOutcomeKind.answered,
      items: slowThenFast,
    ),
  ],
);

void main() {
  test('test_rankSearchResults_exactTitleBeatsPrefixBeatsSubstring', () {
    final term = SearchTerm.tryParse('abc')!;
    final ranked = rankSearchResults(
      term,
      _aggregate(term, <ContentSummary>[
        _item('s1', 'loose', 'zzz abc zzz'),
        _item('s1', 'prefix', 'abcdef'),
        _item('s1', 'exact', 'ABC'),
      ]),
    );

    expect(ranked.map((result) => result.item.title), <String>['ABC', 'abcdef', 'zzz abc zzz']);
    expect(ranked.map((result) => result.relevance), <SearchRelevance>[
      SearchRelevance.exactTitle,
      SearchRelevance.titlePrefix,
      SearchRelevance.partialMatch,
    ]);
  });

  test('test_rankSearchResults_isIndependentOfArrivalOrder', () {
    final term = SearchTerm.tryParse('abc')!;
    final first = rankSearchResults(
      term,
      _aggregate(term, <ContentSummary>[_item('s1', 'b', 'abc show'), _item('s1', 'a', 'abc')]),
    );
    final second = rankSearchResults(
      term,
      _aggregate(term, <ContentSummary>[_item('s1', 'a', 'abc'), _item('s1', 'b', 'abc show')]),
    );

    expect(first.map((result) => result.item.ref.contentId), second.map((result) => result.item.ref.contentId));
    expect(first.first.item.ref.contentId, 'a', reason: 'a tier tie is broken by the title, not by who answered');
  });

  test('test_rankSearchResults_marksDuplicateReferenceInsteadOfHidingIt', () {
    final term = SearchTerm.tryParse('abc')!;
    final ranked = rankSearchResults(
      term,
      _aggregate(term, <ContentSummary>[_item('s1', 'same', 'abc'), _item('s1', 'same', 'abc')]),
    );

    expect(ranked, hasLength(2));
    expect(ranked.first.isShowing, isTrue);
    expect(ranked.last.isDuplicateOf, isTrue);

    // The UI-facing list keeps one copy and leaves the other out, while both stay visible to diagnostics.
    final visible = SearchAnswer(
      term: term,
      aggregate: SearchAggregate(
        query: SearchQuery(keyword: term.display),
        outcomes: const <SearchProviderOutcome>[],
      ),
      ranked: ranked,
    ).visibleItems;
    expect(visible, hasLength(1));
  });

  test('test_relevanceOf_subtitleMatchCountsAsPartial', () {
    final term = SearchTerm.tryParse('live')!;
    expect(relevanceOf(term, _item('s1', 'x', 'Show', subtitle: 'a live special')), SearchRelevance.partialMatch);
    expect(relevanceOf(term, _item('s1', 'x', 'Unrelated')), SearchRelevance.unrelated);
  });
}
