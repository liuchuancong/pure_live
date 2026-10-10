// Module: test/history_test.dart
// Purpose: Verify one record per ContentRef, throttled progress that is delayed rather than lost, and series views.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/services/history.md - 键 = ContentRef、进度节流、parentId 剧集聚合、统一时间线按域过滤、
// ContinueWatching、清空需要确认。
import 'dart:io';

import 'package:pure_live_history/pure_live_history.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_storage/pure_live_storage.dart';
import 'package:test/test.dart';

ContentRef _ref(String sourceId, String contentId, {ContentKind kind = ContentKind.episode}) =>
    ContentRef(sourceId: sourceId, contentId: contentId, kind: kind, parentId: null);

ContentSummary _summary(String title) => ContentSummary(ref: _ref('a', 'x'), title: title);

void main() {
  late DateTime now;
  late MemoryKeyValueStore store;
  late HistoryService history;

  HistoryService service({Duration throttle = Duration.zero}) =>
      HistoryService(repository: KeyValueHistoryRepository(store), clock: () => now, minWriteInterval: throttle);

  setUp(() {
    now = DateTime.utc(2026, 10, 9, 12);
    store = MemoryKeyValueStore();
    history = service();
  });

  group('test_history_record', () {
    test('test_record_createsOneRowAndKeepsTheLatestPosition', () async {
      await history.record(_ref('a', '1'), const Duration(minutes: 3), duration: const Duration(minutes: 30));
      await history.record(_ref('a', '1'), const Duration(minutes: 9));

      final rows = await history.timeline();

      expect(rows, hasLength(1));
      expect(rows.single.position, const Duration(minutes: 9));
      // The length stays even though the second call did not report one.
      expect(rows.single.duration, const Duration(minutes: 30));
    });

    test('test_record_withoutRestatingTheParent_updatesTheSameRow', () async {
      // The trap this pins: ContentRef equality includes parentId, so matching rows by ref would split one
      // episode into two records the moment a caller stopped restating which series it belongs to.
      final parented = ContentRef(sourceId: 'a', contentId: 'ep1', kind: ContentKind.episode, parentId: 's1');
      await history.record(
        parented,
        const Duration(minutes: 10),
        duration: const Duration(minutes: 45),
        parentId: 's1',
      );

      await history.record(_ref('a', 'ep1'), const Duration(minutes: 20));

      final rows = await history.timeline();
      expect(rows, hasLength(1));
      expect(rows.single.position, const Duration(minutes: 20));
      expect(rows.single.parentId, 's1');
      expect((await history.series('s1'))!.latest.position, const Duration(minutes: 20));
    });

    test('test_record_kindIsPartOfTheKey', () async {
      // Same source and id under two kinds are two different things to have watched.
      await history.record(_ref('a', 'same', kind: ContentKind.vod), const Duration(minutes: 1));
      await history.record(_ref('a', 'same', kind: ContentKind.music), const Duration(minutes: 2));

      expect(await history.timeline(), hasLength(2));
    });

    test('test_record_unknownLength_staysOpenInContinueWatching', () async {
      await history.record(_ref('a', 'x'), const Duration(minutes: 12));

      final row = (await history.timeline()).single;

      expect(row.duration, isNull);
      expect(row.isCompleted, isFalse, reason: 'an unreported length is not a zero length');
      expect(await history.continueWatching(), hasLength(1));
    });

    test('test_record_toTheKnownLength_isFinished', () async {
      await history.record(_ref('a', 'x'), const Duration(minutes: 30), duration: const Duration(minutes: 30));

      expect((await history.timeline()).single.isCompleted, isTrue);
      expect(await history.continueWatching(), isEmpty);
    });

    test('test_finish_marksTheEndEvenWhenTheLastTickWasShort', () async {
      await history.record(_ref('a', 'x'), const Duration(minutes: 28), duration: const Duration(minutes: 30));

      final ended = await history.finish(_ref('a', 'x'));

      expect(ended.position, const Duration(minutes: 30));
      expect(ended.isCompleted, isTrue);
    });

    test('test_finish_withoutAnyRecord_isRefused', () async {
      await expectLater(
        history.finish(_ref('a', 'ghost')),
        throwsA(isA<HistoryException>().having((e) => e.kind, 'kind', HistoryFailure.notFound)),
      );
    });
  });

  group('test_history_throttle', () {
    test('test_record_withinTheInterval_isHeldAndFlushedAsTheLatestPosition', () async {
      history = service(throttle: const Duration(seconds: 30));
      await history.record(_ref('a', 'x'), const Duration(seconds: 10), duration: const Duration(minutes: 5));

      now = now.add(const Duration(seconds: 10));
      final held = await history.record(_ref('a', 'x'), const Duration(seconds: 40));

      // A coalesced tick is delayed, not dropped: the row still says 10s, and the 40s is what flush writes.
      expect(held, isNull);
      expect((await history.timeline()).single.position, const Duration(seconds: 10));

      await history.flush();

      expect((await history.timeline()).single.position, const Duration(seconds: 40));
    });

    test('test_record_firstRowIsAlwaysWritten', () async {
      history = service(throttle: const Duration(minutes: 1));

      final written = await history.record(_ref('a', 'new'), const Duration(seconds: 5));

      expect(written, isNotNull);
      expect(await history.timeline(), hasLength(1));
    });

    test('test_record_afterTheInterval_elapsed_isWritten', () async {
      history = service(throttle: const Duration(seconds: 30));
      await history.record(_ref('a', 'x'), const Duration(seconds: 10), duration: const Duration(minutes: 5));

      now = now.add(const Duration(seconds: 31));
      final written = await history.record(_ref('a', 'x'), const Duration(seconds: 90));

      expect(written, isNotNull);
      expect((await history.timeline()).single.position, const Duration(seconds: 90));
    });

    test('test_remove_dropsAHeldRowSoItCannotResurrect', () async {
      history = service(throttle: const Duration(seconds: 30));
      await history.record(_ref('a', 'x'), const Duration(seconds: 10));
      now = now.add(const Duration(seconds: 5));
      expect(await history.record(_ref('a', 'x'), const Duration(seconds: 20)), isNull);

      await history.remove(_ref('a', 'x'));
      await history.flush();

      expect(await history.timeline(), isEmpty);
    });

    test('test_clear_dropsHeldRowsToo', () async {
      history = service(throttle: const Duration(seconds: 30));
      await history.record(_ref('a', 'x'), const Duration(seconds: 10));
      now = now.add(const Duration(seconds: 5));
      await history.record(_ref('a', 'x'), const Duration(seconds: 20));

      await history.clear();
      await history.flush();

      expect(await history.timeline(), isEmpty);
    });
  });

  group('test_history_series', () {
    setUp(() async {
      for (final (index, minutes) in <int>[20, 30, 10].indexed) {
        now = now.add(Duration(minutes: index + 1));
        await history.record(
          _ref('a', 'ep$index', kind: ContentKind.episode),
          Duration(minutes: minutes),
          duration: const Duration(minutes: 30),
          parentId: 'series-1',
          snapshot: _summary('第 ${index + 1} 集'),
        );
      }
    });

    test('test_series_aggregatesTheChildrenAndPicksTheLatest', () async {
      final progress = await history.series('series-1');

      expect(progress!.recorded, 3);
      // ep1 sits at 20/30, ep2 at 30/30 (finished), ep3 at 10/30.
      expect(progress.completed, 1);
      expect(progress.isFullyWatched, isFalse);
      expect(progress.latest.ref.contentId, 'ep2');
    });

    test('test_seriesViews_collapseOnlyRowsThatHaveAParent', () async {
      await history.record(_ref('a', 'movie', kind: ContentKind.movie), const Duration(minutes: 5));

      final views = await history.seriesViews();

      expect(views.keys, <String>['series-1']);
      expect((await history.timeline()).length, 4);
    });

    test('test_removeSeries_dropsTheEpisodesAndTheirHeldRows', () async {
      // A row held by the throttle must not come back to life after its series was deleted.
      history = service(throttle: const Duration(minutes: 10));
      expect(await history.record(_ref('a', 'ep0'), const Duration(minutes: 25)), isNull);

      final removed = await history.removeSeries('series-1');
      await history.flush();

      expect(removed, 3);
      expect(await history.series('series-1'), isNull);
      expect(await history.timeline(), isEmpty);
    });
  });

  group('test_history_timeline', () {
    setUp(() async {
      now = now.subtract(const Duration(hours: 2));
      await history.record(
        _ref('bili', 'movie1', kind: ContentKind.movie),
        const Duration(minutes: 40),
        duration: const Duration(hours: 1),
        snapshot: _summary('老片子'),
      );
      now = now.add(const Duration(hours: 1));
      await history.record(
        _ref('douyu', 'room7', kind: ContentKind.liveRoom),
        const Duration(minutes: 5),
        snapshot: _summary('直播中'),
      );
      now = now.add(const Duration(hours: 1));
      await history.record(
        _ref('bili', 'song3', kind: ContentKind.music),
        const Duration(seconds: 90),
        duration: const Duration(seconds: 200),
        snapshot: _summary('一首歌'),
      );
    });

    test('test_timeline_isNewestFirstAcrossDomains', () async {
      expect((await history.timeline()).map((entry) => entry.ref.sourceId), <String>['bili', 'douyu', 'bili']);
    });

    test('test_timeline_filtersByDomain', () async {
      expect(await history.timeline(domain: HistoryDomain.live), hasLength(1));
      expect(await history.timeline(domain: HistoryDomain.vod), hasLength(1));
      expect(await history.timeline(domain: HistoryDomain.music), hasLength(1));
      expect(await history.timeline(domain: HistoryDomain.other), isEmpty);
    });

    test('test_timeline_filtersBySourceAndTitle', () async {
      expect(await history.timeline(sourceId: 'douyu'), hasLength(1));
      expect((await history.timeline(search: '一首')).single.ref.contentId, 'song3');
      await history.record(
        _ref('bili', 'track9', kind: ContentKind.music),
        const Duration(seconds: 5),
        snapshot: _summary('Live Version'),
      );
      expect((await history.timeline(search: 'live version')).map((e) => e.ref.contentId), <String>[
        'track9',
      ], reason: 'matching is case-insensitive on the stored title');
      expect(await history.timeline(search: '  '), hasLength(4), reason: 'blank search is no filter');
    });

    test('test_timeline_searchCannotFindARowWithoutASnapshot', () async {
      // Consequence of local title matching: a record captured without metadata is invisible to the history
      // page's own search box, even though it is still in the timeline.
      await history.record(_ref('a', 'bare'), const Duration(minutes: 3));

      expect(await history.timeline(search: 'bare'), isEmpty);
      expect((await history.timeline()).any((entry) => entry.ref.contentId == 'bare'), isTrue);
    });

    test('test_continueWatching_ordersByRecencyAndSkipsFinished', () async {
      await history.record(
        _ref('bili', 'movie1', kind: ContentKind.movie),
        const Duration(hours: 1),
        duration: const Duration(hours: 1),
      );

      final open = await history.continueWatching();

      expect(open.map((entry) => entry.ref.contentId), <String>['song3', 'room7']);
      expect(await history.continueWatching(limit: 1), hasLength(1));
    });
  });

  group('test_history_domains', () {
    test('test_domainOf_mapsEveryKindWithoutGuessingTheAmbiguousOnes', () {
      expect(domainOf(ContentKind.liveChannel), HistoryDomain.live);
      expect(domainOf(ContentKind.liveRoom), HistoryDomain.live);
      expect(domainOf(ContentKind.epgProgram), HistoryDomain.live);
      for (final kind in <ContentKind>[ContentKind.vod, ContentKind.movie, ContentKind.series, ContentKind.episode]) {
        expect(domainOf(kind), HistoryDomain.vod, reason: kind.name);
      }
      for (final kind in <ContentKind>[ContentKind.music, ContentKind.album, ContentKind.artist]) {
        expect(domainOf(kind), HistoryDomain.music, reason: kind.name);
      }
      // A bare stream or playlist does not say which family it belongs to; filing it under a domain the user
      // then cannot find it in would read as lost history.
      expect(domainOf(ContentKind.stream), HistoryDomain.other);
      expect(domainOf(ContentKind.playlist), HistoryDomain.other);
      expect(domainOf(ContentKind.localMedia), HistoryDomain.other);

      for (final kind in ContentKind.values) {
        expect(domainOf(kind), isNotNull, reason: '${kind.name} must land in a domain');
      }
    });
  });

  group('test_history_durability', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('history_store');
    });
    tearDown(() {
      dir.deleteSync(recursive: true);
    });

    test('test_records_surviveAStoreReopen', () async {
      final path = '${dir.path}${Platform.pathSeparator}history.json';
      final first = HistoryService(repository: KeyValueHistoryRepository(FileKeyValueStore(filePath: path)));
      await first.record(
        _ref('a', 'ep1'),
        const Duration(minutes: 12),
        duration: const Duration(minutes: 24),
        parentId: 's1',
        snapshot: _summary('第一集'),
      );

      final reopened = HistoryService(
        repository: KeyValueHistoryRepository(FileKeyValueStore(filePath: path)),
        clock: () => DateTime.utc(2026, 10, 20),
      );

      final row = (await reopened.timeline()).single;
      expect(row.position, const Duration(minutes: 12));
      expect(row.duration, const Duration(minutes: 24));
      expect(row.parentId, 's1');
      expect(row.snapshot!.title, '第一集');
      expect((await reopened.series('s1'))!.latest.ref.contentId, 'ep1');
    });

    test('test_aDocumentThatIsNotAList_isRefusedRatherThanReadAsEmpty', () async {
      await store.write('history', 'not a list');

      await expectLater(KeyValueHistoryRepository(store).entries(), throwsA(isA<FormatException>()));
    });
  });

  group('test_history_identity_and_bulk', () {
    test('test_remove_deletesTheRowWhoseKeyMatchesEvenWhenTheRefDiffers', () async {
      // The guard used to compare full ContentRefs while the repository deleted by key: a caller that restated
      // the series (or carried any metadata) was told "no such record" about a row that then did disappear -
      // or, worse, the two rules disagreed about which row that was.
      final parented = ContentRef(sourceId: 'a', contentId: 'ep1', kind: ContentKind.episode, parentId: 's1');
      await history.record(parented, const Duration(minutes: 5), parentId: 's1');

      await history.remove(_ref('a', 'ep1'));

      expect(await history.timeline(), isEmpty);
      await expectLater(
        history.remove(_ref('a', 'ep1')),
        throwsA(isA<HistoryException>().having((e) => e.kind, 'kind', HistoryFailure.notFound)),
      );
    });

    test('test_continueWatching_skipsARecordWithNoProgressAtAll', () async {
      await history.record(_ref('a', 'opened-then-left'), Duration.zero);
      await history.record(_ref('a', 'partway'), const Duration(minutes: 4), duration: const Duration(minutes: 40));

      expect((await history.continueWatching()).map((entry) => entry.ref.contentId), <String>['partway']);
      expect(await history.timeline(), hasLength(2), reason: 'it is still history, just not "continue"');
    });

    test('test_flush_writesEveryHeldRowAsOneRepositoryCall', () async {
      final counting = _CountingRepository(KeyValueHistoryRepository(store));
      final throttled = HistoryService(
        repository: counting,
        clock: () => now,
        minWriteInterval: const Duration(minutes: 1),
      );

      await throttled.record(_ref('a', 'one'), const Duration(minutes: 1));
      now = now.add(const Duration(seconds: 10));
      for (var tick = 2; tick <= 6; tick++) {
        await throttled.record(_ref('a', 'one'), Duration(minutes: tick));
      }
      await throttled.record(_ref('b', 'two'), const Duration(minutes: 2));

      final singlesBeforeFlush = counting.singleUpsertCalls;
      await throttled.flush();

      expect(counting.upsertAllCalls, 1, reason: 'the exit flush is one bulk statement, not N rewrites');
      expect(counting.singleUpsertCalls, singlesBeforeFlush, reason: 'and it does not trickle single writes either');
      expect(singlesBeforeFlush, 2, reason: 'the two first-seen rows were written as they happened');
      expect((await throttled.timeline()).map((entry) => entry.ref.contentId), containsAll(<String>['one', 'two']));
      expect((await throttled.timeline()).firstWhere((entry) => entry.ref.contentId == 'one').position,
          const Duration(minutes: 6));
    });

    test('test_upsertAll_replacesMatchingRowsAndKeepsTheRest', () async {
      await history.record(_ref('a', 'keep'), const Duration(minutes: 1));
      await history.record(_ref('a', 'swap'), const Duration(minutes: 1));

      await KeyValueHistoryRepository(store).upsertAll(<HistoryEntry>[
        HistoryEntry(ref: _ref('a', 'swap'), updatedAt: now, position: const Duration(minutes: 9)),
        HistoryEntry(ref: _ref('a', 'new'), updatedAt: now, position: const Duration(minutes: 3)),
      ]);

      final rows = await history.timeline();
      expect(rows, hasLength(3));
      expect(rows.firstWhere((entry) => entry.ref.contentId == 'swap').position, const Duration(minutes: 9));
      expect(rows.firstWhere((entry) => entry.ref.contentId == 'keep').position, const Duration(minutes: 1));
    });

    test('test_upsertAll_ofNothingLeavesTheDocumentAlone', () async {
      await history.record(_ref('a', 'keep'), const Duration(minutes: 1));
      final before = await store.read('history');

      await KeyValueHistoryRepository(store).upsertAll(const <HistoryEntry>[]);

      expect(await store.read('history'), before, reason: 'an empty bulk write is not a rewrite');
      expect(await history.timeline(), hasLength(1));
    });

    test('test_historyKeyOf_isTheOneSpellingEveryCallerUses', () {
      final ref = ContentRef(sourceId: 's', contentId: 'c', kind: ContentKind.vod);

      expect(historyKeyOf(ref), 's/c/vod');
      expect(HistoryEntry(ref: ref, updatedAt: now).identityKey, historyKeyOf(ref));
    });
  });
}

/// Counts which repository methods ran, so "one bulk write" is an observation and not a claim.
final class _CountingRepository implements HistoryRepository {
  _CountingRepository(this.inner);

  final HistoryRepository inner;
  int upsertAllCalls = 0;
  int singleUpsertCalls = 0;

  @override
  Future<List<HistoryEntry>> entries() => inner.entries();

  @override
  Future<void> upsert(HistoryEntry entry) async {
    singleUpsertCalls++;
    await inner.upsert(entry);
  }

  @override
  Future<void> upsertAll(Iterable<HistoryEntry> entries) async {
    upsertAllCalls++;
    await inner.upsertAll(entries);
  }

  @override
  Future<void> remove(ContentRef ref) async {
    await inner.remove(ref);
  }

  @override
  Future<int> removeWhere(bool Function(HistoryEntry) test) async {
    return inner.removeWhere(test);
  }

  @override
  Future<void> clear() async {
    await inner.clear();
  }
}
