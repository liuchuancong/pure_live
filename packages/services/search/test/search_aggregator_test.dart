// Module: test/search_aggregator_test.dart
// Purpose: Verify that one source's timeout, refusal or bad data cannot take an aggregated search down.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/services/search.md (并发查询 / 超时 / 失败隔离 / 部分结果可用 / 无结果源静默标记).
import 'dart:async';

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_search/pure_live_search.dart';
import 'package:test/test.dart';

ContentRef _ref(String sourceId, String contentId) =>
    ContentRef(sourceId: sourceId, contentId: contentId, kind: ContentKind.vod);

ContentSummary _item(String sourceId, String id) => ContentSummary(ref: _ref(sourceId, id), title: '$sourceId/$id');

/// The provider side of the boundary, with the three behaviours an aggregator has to survive.
final class _FakeSearch implements SearchCapability {
  _FakeSearch(this.sourceId, {this.items = const <ContentSummary>[], this.error, this.hasMore = false});

  final String sourceId;
  final List<ContentSummary> items;
  final Object? error;
  final bool hasMore;

  int calls = 0;

  @override
  Future<PageResult<ContentSummary>> search(SearchQuery query) async {
    calls++;
    if (error != null) {
      throw error!;
    }
    return PageResult<ContentSummary>(
      items: items,
      page: query.page.page,
      pageSize: query.page.pageSize,
      hasMore: hasMore,
    );
  }
}

/// A source that declares search but is not one.
final class _NotSearchable {}

ProviderRegistration _entry(
  String sourceId,
  Object provider, {
  Set<CapabilityKind> kinds = const <CapabilityKind>{CapabilityKind.search},
}) => ProviderRegistration(
  sourceId: sourceId,
  extensionId: 'purelive.$sourceId',
  provider: provider,
  capabilities: CapabilitySet(kinds),
);

CapabilityRegistry _registry(List<ProviderRegistration> entries) => CapabilityRegistry(entries);

const SearchQuery _query = SearchQuery(keyword: 'test');

void main() {
  group('test_aggregator_fanOut', () {
    test('test_search_asksOnlySourcesThatDeclaredSearch', () async {
      final searchable = _FakeSearch('a', items: <ContentSummary>[_item('a', '1')]);
      final voder = _NotSearchable();
      final registry = _registry(<ProviderRegistration>[
        _entry('a', searchable),
        _entry('b', voder, kinds: const <CapabilityKind>{CapabilityKind.vod}),
      ]);

      final result = await CapabilitySearchAggregator(providers: registry).search(_query);

      expect(result.outcomes.map((outcome) => outcome.sourceId), <String>['a']);
      expect(searchable.calls, 1);
    });

    test('test_search_keepsProviderOrderAndItems', () async {
      final registry = _registry(<ProviderRegistration>[
        _entry('first', _FakeSearch('first', items: <ContentSummary>[_item('first', '1'), _item('first', '2')])),
        _entry('second', _FakeSearch('second', items: <ContentSummary>[_item('second', '1')])),
      ]);

      final result = await CapabilitySearchAggregator(providers: registry).search(_query);

      expect(result.outcomes.map((outcome) => outcome.sourceId), <String>['first', 'second']);
      expect(result.allItems.map((item) => item.title), <String>['first/1', 'first/2', 'second/1']);
    });

    test('test_search_blankKeyword_sendsNoRequestAtAll', () async {
      final slow = _FakeSearch('a', items: <ContentSummary>[_item('a', '1')]);
      final registry = _registry(<ProviderRegistration>[_entry('a', slow)]);

      final result = await CapabilitySearchAggregator(providers: registry).search(const SearchQuery(keyword: '   '));

      expect(slow.calls, 0, reason: 'N pointless requests are still N requests');
      expect(result.refused, contains('blank'));
      expect(result.outcomes, isEmpty);
      expect(result.isEmpty, isTrue);
    });

    test('test_search_onlySources_narrowsTheRun', () async {
      final a = _FakeSearch('a', items: <ContentSummary>[_item('a', '1')]);
      final b = _FakeSearch('b', items: <ContentSummary>[_item('b', '1')]);
      final registry = _registry(<ProviderRegistration>[_entry('a', a), _entry('b', b)]);

      final result = await CapabilitySearchAggregator(providers: registry).search(_query, onlySources: <String>['b']);

      expect(result.outcomes.map((outcome) => outcome.sourceId), <String>['b']);
      expect(a.calls, 0);
      expect(b.calls, 1);
    });

    test('test_search_unknownOnlySource_runsNothingWithoutBlamingAnyone', () async {
      final registry = _registry(<ProviderRegistration>[_entry('a', _FakeSearch('a'))]);

      final result = await CapabilitySearchAggregator(providers: registry)
          .search(_query, onlySources: <String>['gone']);

      expect(result.outcomes, isEmpty);
      expect(result.refused, isNull);
    });
  });

  group('test_aggregator_isolatesFailures', () {
    test('test_search_oneSourceTimesOut_othersStillAnswer', () async {
      final hung = Completer<PageResult<ContentSummary>>();
      final hungSource = _HungSource(hung);
      final quick = _FakeSearch('quick', items: <ContentSummary>[_item('quick', '1')]);
      final registry = _registry(<ProviderRegistration>[_entry('slow', hungSource), _entry('quick', quick)]);

      final result = await CapabilitySearchAggregator(
        providers: registry,
        perProviderTimeout: const Duration(milliseconds: 20),
      ).search(_query);

      final slowOutcome = result.outcomes.firstWhere((outcome) => outcome.sourceId == 'slow');
      expect(slowOutcome.kind, SearchOutcomeKind.timedOut);
      expect(slowOutcome.detail, contains('20ms'));
      // The partial answer is the point: a hung source must not turn into no results.
      expect(result.answered.single.sourceId, 'quick');
      expect(result.problems.map((outcome) => outcome.sourceId), <String>['slow']);
    });

    test('test_search_sourceThrows_isRecordedNotRethrown', () async {
      final boom = StateError('js bridge died');
      final registry = _registry(<ProviderRegistration>[
        _entry('broken', _FakeSearch('broken', error: boom)),
        _entry('fine', _FakeSearch('fine', items: <ContentSummary>[_item('fine', '1')])),
      ]);

      final result = await CapabilitySearchAggregator(providers: registry).search(_query);

      final broken = result.outcomes.firstWhere((outcome) => outcome.sourceId == 'broken');
      expect(broken.kind, SearchOutcomeKind.failed);
      expect(broken.detail, contains('js bridge died'));
      expect(result.answered.single.sourceId, 'fine');
    });

    test('test_search_declaredSearchWithoutImplementingIt_isReportedAndNotCalled', () async {
      final registry = _registry(<ProviderRegistration>[_entry('liar', _NotSearchable())]);

      final result = await CapabilitySearchAggregator(providers: registry).search(_query);

      // A tile that is simply missing would be unexplainable; this says why.
      expect(result.outcomes.single.kind, SearchOutcomeKind.failed);
      expect(result.outcomes.single.detail, contains('not a SearchCapability'));
    });

    test('test_search_everySourceFails_isStillAnAnswer', () async {
      final registry = _registry(<ProviderRegistration>[
        _entry('a', _FakeSearch('a', error: Exception('403'))),
        _entry('b', _FakeSearch('b', error: Exception('403'))),
      ]);

      final result = await CapabilitySearchAggregator(providers: registry).search(_query);

      expect(result.isEmpty, isTrue);
      expect(result.problems, hasLength(2));
      expect(result.refused, isNull);
    });
  });

  group('test_aggregator_dataRules', () {
    test('test_search_dropsItemsBelongingToAnotherSource', () async {
      final registry = _registry(<ProviderRegistration>[
        _entry('a', _FakeSearch('a', items: <ContentSummary>[_item('a', 'mine'), _item('b', 'stolen')])),
      ]);

      final result = await CapabilitySearchAggregator(providers: registry).search(_query);
      final outcome = result.outcomes.single;

      // The contract test asserts the same rule; this copy is what holds when a third-party source shipped
      // without passing it, and a result naming the wrong source cannot be opened.
      expect(outcome.items.map((item) => item.ref.contentId), <String>['mine']);
      expect(outcome.droppedForeignItems, 1);
      expect(result.droppedForeignItems, 1);
    });

    test('test_search_onlyForeignItems_countsAsEmpty', () async {
      final registry = _registry(<ProviderRegistration>[
        _entry('a', _FakeSearch('a', items: <ContentSummary>[_item('b', 'x')])),
      ]);

      final outcome = (await CapabilitySearchAggregator(providers: registry).search(_query)).outcomes.single;

      expect(outcome.kind, SearchOutcomeKind.empty);
      expect(outcome.isUsable, isFalse);
    });

    test('test_search_answersWithNothing_isMarkedEmptyNotFailed', () async {
      final registry = _registry(<ProviderRegistration>[_entry('a', _FakeSearch('a'))]);

      final outcome = (await CapabilitySearchAggregator(providers: registry).search(_query)).outcomes.single;

      // "静默标记": a source that had no match is not a failure, and the UI must be able to tell them apart.
      expect(outcome.kind, SearchOutcomeKind.empty);
      expect(outcome.detail, isNull);
      expect(outcome.page, isNotNull);
    });

    test('test_search_carriesTheProvidersOwnPaging', () async {
      final registry = _registry(<ProviderRegistration>[
        _entry('a', _FakeSearch('a', items: <ContentSummary>[_item('a', '1')], hasMore: true)),
      ]);

      final outcome = (await CapabilitySearchAggregator(providers: registry).search(_query)).outcomes.single;

      expect(outcome.page!.hasMore, isTrue);
      expect(outcome.page!.page, 1);
    });
  });
}

/// A source whose answer never arrives.
final class _HungSource implements SearchCapability {
  _HungSource(this.completer);

  final Completer<PageResult<ContentSummary>> completer;

  @override
  Future<PageResult<ContentSummary>> search(SearchQuery query) => completer.future;
}
