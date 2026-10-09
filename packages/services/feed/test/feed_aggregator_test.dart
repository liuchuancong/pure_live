// Module: test/feed_aggregator_test.dart
// Purpose: Verify the home feed keeps its shape when a source is slow, broken, empty or dishonest.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/services/feed.md - Home only consumes FeedSection, a source without the capability does not
// appear, and the cursor runs through to the provider.
import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_feed/pure_live_feed.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:test/test.dart';

ContentRef _ref(String sourceId, String contentId) =>
    ContentRef(sourceId: sourceId, contentId: contentId, kind: ContentKind.vod);

ContentSummary _item(String sourceId, String id, {String? title}) =>
    ContentSummary(ref: _ref(sourceId, id), title: title ?? '$sourceId/$id');

final class _FakeFeed implements FeedCapability {
  _FakeFeed(this.sourceId, {this.items = const <ContentSummary>[], this.delay, this.error, this.hasMore = false});

  final String sourceId;
  final List<ContentSummary> items;
  final Duration? delay;
  final Object? error;
  final bool hasMore;

  final List<PageRequest> askedPages = <PageRequest>[];

  @override
  Future<PageResult<ContentSummary>> feed(PageRequest page) async {
    askedPages.add(page);
    if (delay != null) {
      await Future<void>.delayed(delay!);
    }
    if (error != null) {
      throw error!;
    }
    return PageResult<ContentSummary>(items: items, page: page.page, pageSize: page.pageSize, hasMore: hasMore);
  }
}

final class _NotFeed {}

ProviderRegistration _entry(
  String sourceId,
  Object provider, {
  Set<CapabilityKind> kinds = const <CapabilityKind>{CapabilityKind.feed},
}) {
  return ProviderRegistration(
    sourceId: sourceId,
    extensionId: 'purelive.$sourceId',
    provider: provider,
    capabilities: CapabilitySet(kinds),
  );
}

CapabilityRegistry _registry(List<ProviderRegistration> entries) => CapabilityRegistry(entries);

const PageRequest _firstPage = PageRequest(page: 1, pageSize: 20);

void main() {
  group('test_feed_whichSourcesAreAsked', () {
    test('test_feed_asksOnlySourcesThatDeclaredFeed', () async {
      final feeder = _FakeFeed('a', items: <ContentSummary>[_item('a', '1')]);
      final registry = _registry(<ProviderRegistration>[
        _entry('a', feeder),
        _entry('b', _NotFeed(), kinds: const <CapabilityKind>{CapabilityKind.vod}),
      ]);

      final result = await CapabilityFeedAggregator(providers: registry).feed(_firstPage);

      expect(result.sections.map((section) => section.sourceId), <String>['a']);
      expect(result.skips, isEmpty);
      expect(feeder.askedPages, <PageRequest>[_firstPage]);
    });

    test('test_feed_declaredButCannotAnswer_isSkippedAndNeverCalled', () async {
      final liar = _NotFeed();
      final registry = _registry(<ProviderRegistration>[_entry('a', liar)]);

      final result = await CapabilityFeedAggregator(providers: registry).feed(_firstPage);

      expect(result.isEmpty, isTrue);
      expect(result.skips.single.reason, FeedSkipReason.notCapable);
      expect(result.skips.single.detail, contains('not a FeedCapability'));
    });

    test('test_feed_noFeedSourcesAtAll_isAnEmptyFeedNotAnError', () async {
      final registry = _registry(<ProviderRegistration>[_entry('a', _NotFeed(), kinds: const <CapabilityKind>{})]);

      final result = await CapabilityFeedAggregator(providers: registry).feed(_firstPage);

      expect(result.isEmpty, isTrue);
      expect(result.skips, isEmpty);
    });
  });

  group('test_feed_isolatesSources', () {
    test('test_feed_keepsRegistryOrderWhenAnswersArriveOutOfOrder', () async {
      final registry = _registry(<ProviderRegistration>[
        _entry(
          'slow',
          _FakeFeed('slow', items: <ContentSummary>[_item('slow', '1')], delay: const Duration(milliseconds: 40)),
        ),
        _entry('quick', _FakeFeed('quick', items: <ContentSummary>[_item('quick', '1')])),
      ]);

      final result = await CapabilityFeedAggregator(providers: registry).feed(_firstPage);

      // A front page that reshuffles itself because one source was slower today cannot be the layout the
      // user arranged.
      expect(result.sections.map((section) => section.sourceId), <String>['slow', 'quick']);
    });

    test('test_feed_oneSourceTimesOut_othersStillRender', () async {
      final registry = _registry(<ProviderRegistration>[
        _entry(
          'hung',
          _FakeFeed('hung', items: <ContentSummary>[_item('hung', '1')], delay: const Duration(seconds: 5)),
        ),
        _entry('fine', _FakeFeed('fine', items: <ContentSummary>[_item('fine', '1')])),
      ]);

      final result = await CapabilityFeedAggregator(
        providers: registry,
        perSourceTimeout: const Duration(milliseconds: 20),
      ).feed(_firstPage);

      expect(result.sections.single.sourceId, 'fine');
      expect(result.skips.single.reason, FeedSkipReason.timedOut);
      expect(result.skips.single.detail, contains('20ms'));
    });

    test('test_feed_sourceThrows_isSkippedWithItsReason', () async {
      final registry = _registry(<ProviderRegistration>[
        _entry('broken', _FakeFeed('broken', error: StateError('repository not loaded'))),
      ]);

      final result = await CapabilityFeedAggregator(providers: registry).feed(_firstPage);

      expect(result.skips.single.reason, FeedSkipReason.failed);
      expect(result.skips.single.detail, contains('repository not loaded'));
      expect(result.sections, isEmpty);
    });

    test('test_feed_sourceAnsweredWithNothing_isMarkedEmpty', () async {
      final registry = _registry(<ProviderRegistration>[_entry('quiet', _FakeFeed('quiet'))]);

      final result = await CapabilityFeedAggregator(providers: registry).feed(_firstPage);

      expect(result.skips.single.reason, FeedSkipReason.empty);
      expect(result.skips.single.detail, contains('nothing'));
    });
  });

  group('test_feed_dataRules', () {
    test('test_feed_dropsRowsBelongingToAnotherSource', () async {
      final registry = _registry(<ProviderRegistration>[
        _entry('a', _FakeFeed('a', items: <ContentSummary>[_item('a', 'mine'), _item('b', 'stolen')])),
      ]);

      final section = (await CapabilityFeedAggregator(providers: registry).feed(_firstPage)).sections.single;

      expect(section.items.map((item) => item.ref.contentId), <String>['mine']);
      expect(section.foreignItems, 1);
    });

    test('test_feed_onlyForeignRows_isReportedAsSuch', () async {
      final registry = _registry(<ProviderRegistration>[
        _entry('a', _FakeFeed('a', items: <ContentSummary>[_item('b', 'x'), _item('c', 'y')])),
      ]);

      final result = await CapabilityFeedAggregator(providers: registry).feed(_firstPage);

      expect(result.sections, isEmpty);
      expect(result.skips.single.detail, contains('2 rows named other sources'));
    });

    test('test_feed_dropsADuplicateWithinOneSectionAndCountsIt', () async {
      final registry = _registry(<ProviderRegistration>[
        _entry('a', _FakeFeed('a', items: <ContentSummary>[_item('a', '1'), _item('a', '1'), _item('a', '2')])),
      ]);

      final section = (await CapabilityFeedAggregator(providers: registry).feed(_firstPage)).sections.single;

      // contract.feed.duplicate_ref says a front page may not list one row twice; keeping the first copy is
      // what still renders, and the count is the evidence the provider is double-listing.
      expect(section.items.map((item) => item.ref.contentId), <String>['1', '2']);
      expect(section.duplicateItems, 1);
    });

    test('test_feed_sameTitleFromTwoSources_staysTwoSections', () async {
      // A ref carries its source, so one title arriving from two sources is two different rows; deduping by
      // title would silently delete one source's recommendation.
      final registry = _registry(<ProviderRegistration>[
        _entry('a', _FakeFeed('a', items: <ContentSummary>[_item('a', '1', title: 'Same')])),
        _entry('b', _FakeFeed('b', items: <ContentSummary>[_item('b', '2', title: 'Same')])),
      ]);

      final result = await CapabilityFeedAggregator(providers: registry).feed(_firstPage);

      expect(result.sections, hasLength(2));
      expect(result.allItems, hasLength(2));
      expect(result.droppedRows, 0);
    });
  });

  group('test_feed_paging', () {
    test('test_feed_cursorGoesThroughToTheProviderAndComesBack', () async {
      const second = PageRequest(page: 2, pageSize: 10);
      final feeder = _FakeFeed('a', items: <ContentSummary>[_item('a', '11')], hasMore: true);
      final registry = _registry(<ProviderRegistration>[_entry('a', feeder)]);

      final result = await CapabilityFeedAggregator(providers: registry).feed(second);

      expect(feeder.askedPages.single, second);
      expect(result.page, 2);
      expect(result.sections.single.page, 2);
      expect(result.sections.single.hasMore, isTrue);
    });

    test('test_feed_droppedRowsAreCountedAcrossTheWholeFeed', () async {
      final registry = _registry(<ProviderRegistration>[
        _entry('a', _FakeFeed('a', items: <ContentSummary>[_item('a', '1'), _item('a', '1'), _item('b', 'x')])),
        _entry('c', _FakeFeed('c', items: <ContentSummary>[_item('c', '1'), _item('c', '2')])),
      ]);

      final result = await CapabilityFeedAggregator(providers: registry).feed(_firstPage);

      expect(result.allItems, hasLength(3));
      expect(result.droppedRows, 2);
    });
  });
}
