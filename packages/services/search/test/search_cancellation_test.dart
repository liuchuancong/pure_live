// Module: test/search_cancellation_test.dart
// Purpose: Verify an abandoned search is reported as cancelled, not as a page of source failures.
// Author: liuchuancong
// Created: 2026-10-10
//
// Spec: docs/services/search.md promises concurrency with timeout and failure isolation; it says nothing
// about a caller walking away, which is the normal case for a search box. Without the seam, every superseded
// run's answer arrived as "twelve sources failed", the exact report that makes a healthy provider look sick.

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_search/pure_live_search.dart';
import 'package:pure_live_utils/pure_live_utils.dart';
import 'package:test/test.dart';

ContentRef _ref(String sourceId, String id) => ContentRef(sourceId: sourceId, contentId: id, kind: ContentKind.vod);

final class _SlowSearch implements SearchCapability {
  _SlowSearch({this.delay = const Duration(milliseconds: 40)});

  final Duration delay;
  int calls = 0;

  @override
  Future<PageResult<ContentSummary>> search(SearchQuery query) async {
    calls++;
    await Future<void>.delayed(delay);
    return PageResult<ContentSummary>(
      items: <ContentSummary>[ContentSummary(ref: _ref('a', '1'), title: 'hit')],
      page: query.page.page,
      pageSize: query.page.pageSize,
    );
  }
}

ProviderRegistration _entry(String sourceId, Object provider) => ProviderRegistration(
  sourceId: sourceId,
  extensionId: 'purelive.$sourceId',
  provider: provider,
  capabilities: const CapabilitySet(<CapabilityKind>{CapabilityKind.search}),
);

const SearchQuery _query = SearchQuery(keyword: 'abc');

void main() {
  test('test_search_cancelledBeforeTheRun_asksNobody', () async {
    final capability = _SlowSearch();
    final aggregator = CapabilitySearchAggregator(
      providers: CapabilityRegistry(<ProviderRegistration>[_entry('a', capability)]),
    );
    final token = CancellationToken()..cancel();

    await expectLater(aggregator.search(_query, cancellation: token), throwsA(isA<OperationCancelledException>()));
    expect(capability.calls, 0);
  });

  test('test_search_cancelledMidFlight_isACancellationNotAFailedSource', () async {
    final capability = _SlowSearch();
    final aggregator = CapabilitySearchAggregator(
      providers: CapabilityRegistry(<ProviderRegistration>[_entry('a', capability)]),
    );
    final token = CancellationToken();

    final run = aggregator.search(_query, cancellation: token);
    token.cancel();

    // The provider request was already dispatched and finishes anyway: this layer does not own it. What the
    // caller gets is the cancellation, not an outcome list blaming 'a'.
    await expectLater(run, throwsA(isA<OperationCancelledException>()));
    expect(capability.calls, 1);
  });

  test('test_search_withoutAToken_isUnchanged', () async {
    final capability = _SlowSearch(delay: Duration.zero);
    final aggregator = CapabilitySearchAggregator(
      providers: CapabilityRegistry(<ProviderRegistration>[_entry('a', capability)]),
    );

    final result = await aggregator.search(_query);

    expect(result.outcomes.single.isUsable, isTrue);
    expect(result.refused, isNull);
  });
}
