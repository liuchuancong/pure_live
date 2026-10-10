// Module: test/domain/search_controller_test.dart
// Purpose: Pins the generation fence: only the newest run may answer, and only it reaches history.
// Author: liuchuancong
// Created: 2026-10-10

import 'dart:async';

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_search/pure_live_search.dart';
import 'package:pure_live_search_feature/pure_live_search_feature.dart';
import 'package:pure_live_storage/pure_live_storage.dart';
import 'package:pure_live_utils/pure_live_utils.dart';
import 'package:test/test.dart';

/// Answers when the test says so, which is the only way to make "the older query finished last" deterministic.
final class _GatedAggregator implements SearchAggregator {
  final List<SearchQuery> asked = <SearchQuery>[];
  final Map<String, Completer<SearchAggregate>> _gates = <String, Completer<SearchAggregate>>{};

  @override
  Future<SearchAggregate> search(SearchQuery query, {Iterable<SourceId>? onlySources}) {
    asked.add(query);
    final completer = Completer<SearchAggregate>();
    _gates[query.keyword] = completer;
    return completer.future;
  }

  void answer(String keyword) {
    _gates
        .remove(keyword)!
        .complete(
          SearchAggregate(
            query: SearchQuery(keyword: keyword),
            outcomes: <SearchProviderOutcome>[
              SearchProviderOutcome(
                sourceId: 's1',
                kind: SearchOutcomeKind.answered,
                items: <ContentSummary>[
                  ContentSummary(
                    ref: ContentRef(sourceId: 's1', contentId: keyword, kind: ContentKind.vod),
                    title: keyword,
                  ),
                ],
              ),
            ],
          ),
        );
  }
}

void main() {
  late _GatedAggregator aggregator;
  late StoredSearchHistory history;
  late SearchController controller;

  setUp(() {
    aggregator = _GatedAggregator();
    history = StoredSearchHistory(store: MemoryKeyValueStore(), clock: FixedClock(DateTime.utc(2026, 10, 10)));
    controller = SearchController(aggregator: aggregator, history: history);
  });

  test('test_searchController_blankKeyword_isRefusedBeforeAnyRequest', () async {
    final outcome = await controller.run('   ');

    expect(outcome, isA<SearchRejected>());
    expect(aggregator.asked, isEmpty, reason: 'a refused search must not reach the fan-out');
    expect(await history.recent(), isEmpty);
  });

  test('test_searchController_olderRunLosingTheRace_isSupersededAndNotRecorded', () async {
    final older = controller.run('abc');
    final newer = controller.run('abcdef');
    expect(controller.isRunning, isTrue);

    // Both answers arrive, the older one last: exactly what a source with a slow line produces.
    aggregator.answer('abcdef');
    aggregator.answer('abc');

    expect(await older, isA<SearchSuperseded>());
    final answer = await newer;
    expect(answer, isA<SearchAnswer>());
    expect((await history.recent()).map((entry) => entry.term.display), <String>['abcdef']);
    expect(controller.isRunning, isFalse);
  });

  test('test_searchController_cancelDropsTheInFlightAnswer', () async {
    final run = controller.run('abc');
    controller.cancel();
    aggregator.answer('abc');

    expect(await run, isA<SearchSuperseded>());
    expect(await history.recent(), isEmpty);
  });

  test('test_searchController_currentTokenFiresWhenAbandonedNotWhenAnswered', () async {
    final abandonedRun = controller.run('abc');
    var heard = 0;
    controller.currentToken.addListener(() => heard++);

    // A newer keystroke abandons the run whose token the listener is holding.
    final winningRun = controller.run('abcd');
    expect(heard, 1);

    aggregator.answer('abcd');
    aggregator.answer('abc');
    await abandonedRun;
    await winningRun;
    expect(heard, 1, reason: 'success is not the event a spinner waits for, and it must not fire twice');
    expect(controller.currentToken.isCancelled, isFalse);
  });

  test('test_searchController_withoutHistory_stillAnswers', () async {
    final controller = SearchController(aggregator: aggregator);
    final run = controller.run('abc');
    aggregator.answer('abc');

    final answer = await run as SearchAnswer;
    expect(answer.visibleItems.single.title, 'abc');
  });
}
