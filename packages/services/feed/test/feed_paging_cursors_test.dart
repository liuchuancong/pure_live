// Module: test/feed_paging_cursors_test.dart
// Purpose: Verify the feed's continuation actually reaches a caller, per source, and that a dishonest paging
// answer is recorded instead of smoothed over.
// Author: liuchuancong
// Created: 2026-10-10
//
// Spec: docs/services/feed.md line 9 and 17 - "FeedSection[](标题 + FeedItem[] + cursor)" and
// "分页 cursor 贯穿到 Provider". The first version echoed only the page number back, so a cursor-mode source
// could be asked once and never continued: the token it handed back had nowhere to go.

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_feed/pure_live_feed.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart';
import 'package:test/test.dart';

ContentRef _ref(String sourceId, String contentId) =>
    ContentRef(sourceId: sourceId, contentId: contentId, kind: ContentKind.vod);

ContentSummary _item(String sourceId, String id) => ContentSummary(ref: _ref(sourceId, id), title: '$sourceId/$id');

/// A feed source whose answer can carry a paging mode and a continuation token, unlike the plain fake in
/// feed_aggregator_test.dart.
final class _PagingFeed implements FeedCapability {
  _PagingFeed(
    this.sourceId, {
    this.mode = PageMode.fixedPage,
    this.nextCursor,
    this.hasMore = false,
    this.items,
    this.delay,
  });

  final String sourceId;
  final PageMode mode;
  final String? nextCursor;
  final bool hasMore;
  final Duration? delay;
  final List<ContentSummary>? items;

  final List<PageRequest> asked = <PageRequest>[];

  @override
  Future<PageResult<ContentSummary>> feed(PageRequest page) async {
    asked.add(page);
    if (delay != null) {
      await Future<void>.delayed(delay!);
    }
    return PageResult<ContentSummary>(
      items: items ?? <ContentSummary>[_item(sourceId, '${page.page}')],
      page: page.page,
      pageSize: page.pageSize,
      hasMore: hasMore,
      mode: mode,
      nextCursor: nextCursor,
    );
  }
}

ProviderRegistration _entry(String sourceId, Object provider) => ProviderRegistration(
  sourceId: sourceId,
  extensionId: 'purelive.$sourceId',
  provider: provider,
  capabilities: const CapabilitySet(<CapabilityKind>{CapabilityKind.feed}),
);

CapabilityRegistry _registry(List<ProviderRegistration> entries) => CapabilityRegistry(entries);

const PageRequest _first = PageRequest(page: 1, pageSize: 20);

void main() {
  group('test_feed_paging_cursors', () {
    test('test_feed_nextCursor_comesBackOnTheSectionItBelongsTo', () async {
      final feeder = _PagingFeed('a', mode: PageMode.cursor, nextCursor: 'tok-1', hasMore: true);
      final aggregator = CapabilityFeedAggregator(providers: _registry(<ProviderRegistration>[_entry('a', feeder)]));

      final result = await aggregator.feed(_first);
      final section = result.sections.single;

      expect(section.mode, PageMode.cursor);
      expect(section.nextCursor, 'tok-1', reason: 'feed.md puts the cursor in the section; nowhere else to read it');

      // And it has to be usable: asking again with it must hand the same token to the same source.
      await aggregator.feed(_first, cursors: <String, String>{'a': section.nextCursor!});
      expect(feeder.asked.last.cursor, 'tok-1');
    });

    test('test_feed_cursorsArePerSourceAndNeverShared', () async {
      final a = _PagingFeed('a', mode: PageMode.cursor);
      final b = _PagingFeed('b');
      final aggregator = CapabilityFeedAggregator(
        providers: _registry(<ProviderRegistration>[_entry('a', a), _entry('b', b)]),
      );

      await aggregator.feed(const PageRequest(page: 2, pageSize: 10), cursors: <String, String>{'a': 'tokA'});

      expect(a.asked.single.cursor, 'tokA');
      expect(b.asked.single.cursor, isNull, reason: "Bilibili's token means nothing to Huya");
      expect(b.asked.single.page, 2, reason: 'a source without a cursor keeps paging by number');
    });

    test('test_feed_aFixedPageSourceKeepsItsPageNumberEcho', () async {
      final a = _PagingFeed('a');
      final aggregator = CapabilityFeedAggregator(providers: _registry(<ProviderRegistration>[_entry('a', a)]));

      final result = await aggregator.feed(const PageRequest(page: 3, pageSize: 10));

      expect(result.sections.single.page, 3);
      expect(result.sections.single.mode, PageMode.fixedPage);
      expect(result.sections.single.hasMore, isFalse);
    });
  });

  group('test_feed_paging_contract_violations', () {
    test('test_feed_singleShotClaimingMoreRows_isRecordedNotNormalised', () async {
      final a = _PagingFeed('a', mode: PageMode.singleShot, hasMore: true);
      final aggregator = CapabilityFeedAggregator(providers: _registry(<ProviderRegistration>[_entry('a', a)]));

      final section = (await aggregator.feed(_first)).sections.single;

      expect(section.contractViolation, contains('single-shot'));
      expect(section.items, isNotEmpty, reason: 'the rows it did return are still shown');
    });

    test('test_feed_cursorSourceThatContinuesWithoutAToken_isRecorded', () async {
      final a = _PagingFeed('a', mode: PageMode.cursor, hasMore: true);
      final aggregator = CapabilityFeedAggregator(providers: _registry(<ProviderRegistration>[_entry('a', a)]));

      final section = (await aggregator.feed(_first)).sections.single;

      expect(section.contractViolation, contains('returned no cursor'));
    });

    test('test_feed_aTokenForAFixedPageFeed_isRecorded', () async {
      final a = _PagingFeed('a', nextCursor: 'unexpected');
      final aggregator = CapabilityFeedAggregator(providers: _registry(<ProviderRegistration>[_entry('a', a)]));

      final section = (await aggregator.feed(_first)).sections.single;

      expect(section.contractViolation, contains('fixed-page'));
    });

    test('test_feed_aCleanAnswerCarriesNoViolationNote', () async {
      final a = _PagingFeed('a', mode: PageMode.cursor, nextCursor: 'ok', hasMore: true);
      final aggregator = CapabilityFeedAggregator(providers: _registry(<ProviderRegistration>[_entry('a', a)]));

      expect((await aggregator.feed(_first)).sections.single.contractViolation, isNull);
    });
  });

  group('test_feed_cancellation', () {
    test('test_feed_cancelledBeforeTheRun_asksNoSourceAtAll', () async {
      final a = _PagingFeed('a');
      final aggregator = CapabilityFeedAggregator(providers: _registry(<ProviderRegistration>[_entry('a', a)]));
      final token = CancellationToken()..cancel();

      await expectLater(aggregator.feed(_first, cancellation: token), throwsA(isA<OperationCancelledException>()));
      expect(a.asked, isEmpty);
    });

    test('test_feed_cancelledWhileSourcesAreSlow_isCancelledNotTwelveFailures', () async {
      final slow = _PagingFeed('a', delay: const Duration(milliseconds: 60));
      final aggregator = CapabilityFeedAggregator(providers: _registry(<ProviderRegistration>[_entry('a', slow)]));
      final token = CancellationToken();

      final run = aggregator.feed(_first, cancellation: token);
      // The user left Home while the request was in the air.
      token.cancel();

      await expectLater(run, throwsA(isA<OperationCancelledException>()));
    });

    test('test_feed_nocancellation_behavesAsBefore', () async {
      final a = _PagingFeed('a', items: <ContentSummary>[_item('a', '1')]);
      final aggregator = CapabilityFeedAggregator(providers: _registry(<ProviderRegistration>[_entry('a', a)]));

      final result = await aggregator.feed(_first);
      expect(result.sections.single.items, hasLength(1));
      expect(result.skips, isEmpty);
    });
  });
}
