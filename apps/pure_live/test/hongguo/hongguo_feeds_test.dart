import 'dart:async' show Completer, unawaited;
import 'dart:convert' show jsonEncode, utf8;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_client.dart' show hongguoClientProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_feeds.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart';
import 'package:pure_live/modules/hongguo/official/hongguo_official.dart'
    show HongguoOfficialClient, HongguoSearchCursor, HongguoWebsiteBoard;

/// The browse and latest shelves over a stubbed landpage: the selector panel
/// the first page carries, the cursor the later pages ride, the selection
/// that resets the feed and wins by generation (the 类型 row's choice
/// riding the ask itself), and the latest shelf's pinned time sort. The
/// website boards' whole-list snapshots and the station search's walk —
/// its dedupe, its fallback to the website, its machine's own words —
/// stand in with a scripted client.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageStores stores;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  tearDown(() => stores.close());

  /// The landpage answer's rows and selector, as the station spells them.
  String landpage({
    required List<Map<String, Object?>> rows,
    bool withPanel = true,
    bool hasMore = false,
    int nextOffset = 24,
    String session = 'sess-1',
  }) => jsonEncode({
    'code': 0,
    'data': {
      'video_data': rows,
      if (withPanel)
        'selector_rows': [
          {
            'type': 'genre',
            'items': [
              {'selector_item_id': 'short_play', 'show_name': '短剧'},
              {'selector_item_id': 'nope id!', 'show_name': '坏项'},
            ],
          },
          {
            'type': 'category_dim_theme',
            'items': [
              {'selector_item_id': 'theme1', 'show_name': '悬疑'},
            ],
          },
          {'type': 'unknown_dim', 'items': const <Object?>[]},
        ],
      'has_more': hasMore,
      if (hasMore) 'next_offset': nextOffset,
      'session_id': session,
    },
  });

  Map<String, Object?> row(String id, String title) => {
    'series_id': id,
    'title': title,
    'episode_cnt': 12,
    'video_desc': '简介 $title',
    'category_schema': '[{"name":"悬疑"},{"name":"都市"}]',
  };

  /// The ask's JSON body, read out of the signed request.
  String bodyOf(LiveRequest request) =>
      request.body ?? utf8.decode(request.bodyBytes ?? Uint8List.fromList(const []), allowMalformed: true);

  group('the browse shelf', () {
    late _RouteStub stub;
    late ProviderContainer container;

    setUp(() {
      stub = _RouteStub();
      container = ProviderContainer(
        overrides: [hongguoClientProvider.overrideWith((ref) => HongguoOfficialClient(http: stub))],
      );
      addTearDown(container.dispose);
      container.listen(hongguoBrowseProvider, (_, _) {});
    });

    HongguoBrowseController shelf() => container.read(hongguoBrowseProvider.notifier);
    HongguoBrowseFeed feedOf(HongguoGenre genre) => container.read(hongguoBrowseProvider.notifier).feedOf(genre);

    test('the first page carries the panel, the later pages ride the cursor', () async {
      stub.routeFor(
        '/landpage',
        (request) => bodyOf(request).contains('"req_type":"only_content"')
            ? landpage(rows: [row('201', '第二页'), row('bad', '')], withPanel: false)
            : landpage(rows: [row('101', '第一页'), row('x', '坏行')], hasMore: true),
      );

      final controller = shelf();
      await controller.open(HongguoGenre.shortPlay);
      var feed = feedOf(HongguoGenre.shortPlay);
      expect(feed.items.map((series) => series.seriesId), ['101']); // the bad rows stay out
      expect(feed.items.single.title, '第一页');
      // The panel rides the first page alone, bad options dropped, unknown
      // dimensions left out.
      expect(feed.groups.map((group) => group.type), ['genre', 'category_dim_theme']);
      expect(feed.groups.first.items.map((option) => option.id), ['short_play']);
      expect(feed.hasMore, isTrue);
      expect(feed.selection, isEmpty);
      expect(feed.error, isNull);

      // open again asks nothing.
      await controller.open(HongguoGenre.shortPlay);
      expect(stub.seen, hasLength(1));
      final first = stub.seen.single;
      final firstBody = bodyOf(first);
      expect(firstBody, contains('"req_type":"default"'));
      expect(firstBody, contains('"genre":["short_play"]')); // the shelf's own genre rides along

      await controller.loadMore(HongguoGenre.shortPlay);
      feed = feedOf(HongguoGenre.shortPlay);
      expect(feed.items.map((series) => series.seriesId), ['101', '201']);
      expect(feed.hasMore, isFalse); // the page said no
      expect(feed.groups, hasLength(2)); // the panel stays from the first page
      final second = stub.seen.last;
      expect(second.url.path, first.url.path);
      expect(bodyOf(second), contains('"req_type":"only_content"'));
      expect(bodyOf(second), contains('"session_id":"sess-1"'));
      expect(bodyOf(second), contains('"offset":24'));

      // The ended walk asks for nothing more.
      await controller.loadMore(HongguoGenre.shortPlay);
      expect(stub.seen, hasLength(2));
    });

    test('a selection resets the feed, the genre clears the rest, and the newer ask wins', () async {
      stub.routeFor(
        '/landpage',
        (request) => landpage(rows: [row('301', bodyOf(request).contains('theme2') ? '选了主题二' : '选了主题一')]),
      );

      final controller = shelf();
      await controller.select(HongguoGenre.shortPlay, 'category_dim_theme', 'theme1');
      expect(feedOf(HongguoGenre.shortPlay).selection, {'category_dim_theme': 'theme1'});
      expect(feedOf(HongguoGenre.shortPlay).items.single.title, '选了主题一');
      expect(bodyOf(stub.seen.last), contains('"category_dim_theme":["theme1"]'));

      // Two asks race for the shelf: the newer selection wins, the older
      // answer never lands.
      final older = controller.select(HongguoGenre.shortPlay, 'category_dim_theme', 'theme1');
      final newer = controller.select(HongguoGenre.shortPlay, 'category_dim_theme', 'theme2');
      await older;
      await newer;
      final raced = feedOf(HongguoGenre.shortPlay);
      expect(raced.selection, {'category_dim_theme': 'theme2'});
      expect(raced.items.single.title, '选了主题二');

      // A 类型 choice replaces the shelf kind: the other dimensions drop,
      // and the ask rides the chosen kind — the tab's own wire only stands
      // in when no 类型 was picked.
      await controller.select(HongguoGenre.shortPlay, 'genre', 'short_play');
      expect(feedOf(HongguoGenre.shortPlay).selection, {'genre': 'short_play'});
      expect(bodyOf(stub.seen.last), contains('"genre":["short_play"]'));

      await controller.select(HongguoGenre.shortPlay, 'genre', 'comic_series');
      expect(feedOf(HongguoGenre.shortPlay).selection, {'genre': 'comic_series'});
      expect(bodyOf(stub.seen.last), contains('"genre":["comic_series"]')); // the chosen kind, not the tab's
      expect(bodyOf(stub.seen.last), contains('"category_dim_theme":[]')); // the other kind's dimensions ride empty

      await controller.select(HongguoGenre.shortPlay, 'category_dim_theme', 'theme1');
      expect(feedOf(HongguoGenre.shortPlay).selection, {'genre': 'comic_series', 'category_dim_theme': 'theme1'});
      expect(bodyOf(stub.seen.last), contains('"genre":["comic_series"]')); // the chosen kind carries the walk

      await controller.select(HongguoGenre.shortPlay, 'genre', null);
      expect(feedOf(HongguoGenre.shortPlay).selection, {
        'category_dim_theme': 'theme1',
      }); // the row cleared: the tab's kind rides again

      // Clearing one dimension drops just that key; clear drops them all.
      await controller.select(HongguoGenre.shortPlay, 'category_dim_theme', 'theme1');
      expect(feedOf(HongguoGenre.shortPlay).selection, {'category_dim_theme': 'theme1'});
      await controller.select(HongguoGenre.shortPlay, 'category_dim_theme', null);
      expect(feedOf(HongguoGenre.shortPlay).selection, isEmpty);
    });

    test('a failed page names itself, the retry reads the head, and success clears it', () async {
      stub.routeFor('/landpage', (request) => '{"code":-312,"message":"风控"}');
      final controller = shelf();
      await controller.open(HongguoGenre.shortPlay);
      var feed = feedOf(HongguoGenre.shortPlay);
      expect(feed.error, isNotNull);
      expect(feed.items, isEmpty);
      expect(feed.hasMore, isFalse);

      // open will not re-ask a failed shelf; the retry does.
      await controller.open(HongguoGenre.shortPlay);
      final afterFailedOpen = stub.seen.length;

      stub.routeFor('/landpage', (request) => landpage(rows: [row('401', '重试到了')]));
      await controller.retry(HongguoGenre.shortPlay);
      feed = feedOf(HongguoGenre.shortPlay);
      expect(feed.error, isNull);
      expect(feed.items.single.seriesId, '401');
      expect(stub.seen.length, afterFailedOpen + 1);
    });

    test('two shelves keep their own asks and their own feeds', () async {
      stub.routeFor(
        '/landpage',
        (request) => landpage(rows: [row('501', bodyOf(request).contains('"genre":["comic_series"]') ? '漫剧页' : '短剧页')]),
      );
      final controller = shelf();

      await controller.open(HongguoGenre.shortPlay);
      await controller.open(HongguoGenre.comicSeries);

      expect(feedOf(HongguoGenre.shortPlay).items.single.title, '短剧页');
      expect(feedOf(HongguoGenre.comicSeries).items.single.title, '漫剧页');
      // One shelf's ask never aborts the other's, and both stay settled.
      expect(feedOf(HongguoGenre.shortPlay).loading, isFalse);
      expect(feedOf(HongguoGenre.comicSeries).loading, isFalse);
    });
  });

  group('the latest shelf', () {
    test('the time sort is pinned and the walk pages', () async {
      final stub = _RouteStub();
      var calls = 0;
      stub.routeFor('/landpage', (request) {
        calls++;
        return landpage(
          rows: [row(calls == 1 ? '601' : '602', '最新 $calls')],
          withPanel: calls == 1,
          hasMore: calls == 1,
        );
      });
      final container = ProviderContainer(
        overrides: [hongguoClientProvider.overrideWith((ref) => HongguoOfficialClient(http: stub))],
      );
      addTearDown(container.dispose);
      container.listen(hongguoLatestProvider, (_, _) {});
      final controller = container.read(hongguoLatestProvider.notifier);

      await controller.open(HongguoGenre.shortPlay);
      var feed = container.read(hongguoLatestProvider.notifier).feedOf(HongguoGenre.shortPlay);
      expect(feed.items.single.seriesId, '601');
      // The pinned sort rides every ask, first page included.
      expect(bodyOf(stub.seen.single), contains('"sort":["online_time"]'));
      expect(bodyOf(stub.seen.single), contains('"online_time":["days_7"]'));

      await controller.loadMore(HongguoGenre.shortPlay);
      feed = container.read(hongguoLatestProvider.notifier).feedOf(HongguoGenre.shortPlay);
      expect(feed.items.map((series) => series.seriesId), ['601', '602']);
      expect(feed.hasMore, isFalse);
    });

    test('a failed shelf answers its error, and the retry reads again', () async {
      final stub = _RouteStub()..routeFor('/landpage', (request) => '{"code":0,"data":"不是对象"}');
      final container = ProviderContainer(
        overrides: [hongguoClientProvider.overrideWith((ref) => HongguoOfficialClient(http: stub))],
      );
      addTearDown(container.dispose);
      container.listen(hongguoLatestProvider, (_, _) {});
      final controller = container.read(hongguoLatestProvider.notifier);

      await controller.open(HongguoGenre.shortPlay);
      var feed = container.read(hongguoLatestProvider.notifier).feedOf(HongguoGenre.shortPlay);
      expect(feed.error, isNotNull);
      expect(feed.hasMore, isFalse);

      stub.routeFor('/landpage', (request) => landpage(rows: [row('701', '恢复了')]));
      await controller.retry(HongguoGenre.shortPlay);
      feed = container.read(hongguoLatestProvider.notifier).feedOf(HongguoGenre.shortPlay);
      expect(feed.error, isNull);
      expect(feed.items.single.seriesId, '701');
    });
  });

  group('the boards', () {
    late _ScriptedClient client;
    late ProviderContainer container;

    setUp(() {
      client = _ScriptedClient();
      container = ProviderContainer(overrides: [hongguoClientProvider.overrideWithValue(client)]);
      addTearDown(container.dispose);
      container.listen(hongguoRankProvider, (_, _) {});
    });

    HongguoRankFeed feedOf(HongguoWebsiteBoard board) => container.read(hongguoRankProvider.notifier).feedOf(board);

    test('a board reads once, renews behind its rows, and moves its stamp', () async {
      const board = HongguoWebsiteBoard.all;
      final controller = container.read(hongguoRankProvider.notifier);

      unawaited(controller.open(board));
      client.rankGates.removeAt(0).complete([series('a'), series('b'), series('c')]);
      await _tick();
      final firstRead = feedOf(board).readAt;
      expect(firstRead, greaterThan(0));
      expect(feedOf(board).items, hasLength(3));

      // The fresh snapshot answers; only a stale one renews by itself.
      await controller.open(board);
      expect(client.rankAsks, [board]);

      unawaited(controller.refresh(board));
      expect(feedOf(board).renewing, isTrue); // the rows stay on screen
      expect(feedOf(board).loading, isFalse);
      expect(feedOf(board).items, hasLength(3));
      client.rankGates.removeAt(0).complete([series('d'), series('e')]);
      await _tick();
      expect(feedOf(board).items.map((item) => item.seriesId), ['d', 'e']);
      expect(feedOf(board).renewing, isFalse);
      expect(feedOf(board).readAt, greaterThanOrEqualTo(firstRead));
    });

    test('an in-flight board never doubles its ask', () async {
      const board = HongguoWebsiteBoard.real;
      final controller = container.read(hongguoRankProvider.notifier);

      unawaited(controller.open(board)); // held at its gate
      await controller.open(board);
      await controller.refresh(board);
      expect(client.rankAsks, [board]); // one ask at a time

      client.rankGates.removeAt(0).complete([series('a')]);
      await _tick();
      unawaited(controller.refresh(board));
      expect(client.rankAsks, [board, board]); // free again, the walk asks once
    });

    test('topics read their rows, and the years stay out', () async {
      const board = HongguoWebsiteBoard.comic;
      final controller = container.read(hongguoRankProvider.notifier);

      unawaited(controller.open(board));
      client.rankGates.removeAt(0).complete([
        series('a', category: '甜宠 / 都市 / 2024'),
        series('b', category: '甜宠'),
        series('c', category: '逆袭'),
      ]);
      await _tick();

      final topics = controller.topicsOf(board);
      expect(topics.first.topic, '甜宠'); // the most frequent leads
      expect(topics.first.count, 2);
      expect(topics.map((entry) => entry.topic), containsAll(['都市', '逆袭'])); // 2024 is a year, no topic

      expect(controller.rowsOf(board, '甜宠').map((item) => item.seriesId), ['a', 'b']); // the board's own order
      expect(controller.rowsOf(board, '逆袭').map((item) => item.seriesId), ['c']);
      expect(controller.rowsOf(board, ''), hasLength(3)); // no topic: everything
    });

    test('a refused snapshot keeps the held board, and an empty one stays quiet', () async {
      const board = HongguoWebsiteBoard.ai;
      final controller = container.read(hongguoRankProvider.notifier);

      client.rankFailure = Exception('refused');
      await controller.open(board); // the ask itself throws: it comes home
      expect(feedOf(board).error, isNotNull);

      await controller.open(board);
      expect(client.rankAsks, hasLength(1)); // no read storm behind the error

      client.rankFailure = null;
      // the errored board stays quiet on open; the viewer's own ask reads again
      unawaited(controller.refresh(board));
      client.rankGates.removeAt(0).complete([series('a')]);
      await _tick();
      expect(feedOf(board).error, isNull);

      client.rankFailure = Exception('refused again');
      await controller.refresh(board); // the ask throws again: the rows stay
      expect(feedOf(board).items.single.seriesId, 'a');
      expect(feedOf(board).error, isNotNull);
      expect(feedOf(board).renewing, isFalse);
    });
  });

  group('the station search', () {
    late _ScriptedClient client;
    late ProviderContainer container;
    late HongguoSearchController controller;

    setUp(() {
      client = _ScriptedClient();
      container = ProviderContainer(overrides: [hongguoClientProvider.overrideWithValue(client)]);
      addTearDown(container.dispose);
      container.listen(hongguoSearchProvider, (_, _) {});
      controller = container.read(hongguoSearchProvider.notifier);
    });

    Future<void> firstSearch(String word) async {
      unawaited(controller.search(word));
      await _tick();
    }

    Future<void> releaseWebsite({required List<HongguoSeries> items, required bool hasMore}) async {
      client.websiteGates.removeAt(0).complete((items: items, hasMore: hasMore));
      await _tick();
    }

    test('the walk dedupes the rows a page replays', () async {
      await firstSearch('甜宠');
      client.appSearchGates.removeAt(0).complete((
        items: [series('1'), series('2')],
        hasMore: true,
        next: const HongguoSearchCursor(page: 2, searchId: 'sid', passback: 'pb'),
      ));
      await _tick();

      unawaited(controller.loadMore());
      client.appSearchGates.removeAt(0).complete((
        items: [series('2'), series('3')], // the platform replays one row across pages
        hasMore: false,
        next: null,
      ));
      await _tick();
      expect(controller.state.items.map((item) => item.seriesId), ['1', '2', '3']);
    });

    test('a refused app door walks onto the website, and stays there for its pages', () async {
      client.appSearchFailure = Exception('refused');
      unawaited(controller.search('霸总'));
      await releaseWebsite(items: [series('w1')], hasMore: true);
      expect(client.websiteSearchAsks, [('霸总', 1)]);
      expect(controller.state.error, isNull); // the fallback answered
      expect(controller.state.items.single.seriesId, 'w1');

      unawaited(controller.loadMore());
      await releaseWebsite(items: [series('w2')], hasMore: false);
      expect(client.websiteSearchAsks, [('霸总', 1), ('霸总', 2)]); // the track carries its own pages
      expect(client.appSearchWords, ['霸总']); // the refused door paid once
      expect(controller.state.items.map((item) => item.seriesId), ['w1', 'w2']);

      // a fresh ask tries the app's door again, so a station that comes
      // back is picked up
      client.appSearchFailure = null;
      unawaited(controller.search('甜宠'));
      client.appSearchGates.removeAt(0).complete((items: [series('a1')], hasMore: false, next: null));
      await _tick();
      expect(client.appSearchWords, ['霸总', '甜宠']);
      expect(controller.state.items.single.seriesId, 'a1');
    });

    test('both doors refusing names the first, and no walk is left to ride', () async {
      client
        ..appSearchFailure = Exception('app refused')
        ..websiteSearchFailure = Exception('website refused');
      await controller.search('霸总'); // both doors throw at the ask: it comes home

      expect(controller.state.error, isNotNull); // the app door's words, the page's own
      expect(controller.state.items, isEmpty);
      expect(controller.state.hasMore, isFalse);

      await controller.loadMore();
      expect(client.websiteSearchAsks, [('霸总', 1)]); // the one refused ask, and none after
    });

    test('the committed word leads the history, said once in any case', () async {
      unawaited(controller.search('甜宠'));
      unawaited(controller.search('言情'));
      expect(controller.state.history, ['言情', '甜宠']);

      unawaited(controller.search('SWEET'));
      unawaited(controller.search('sweet')); // one word said twice, not two words
      expect(controller.state.history, ['sweet', '言情', '甜宠']);

      for (var i = 0; i < 25; i++) {
        unawaited(controller.search('词$i'));
      }
      expect(controller.state.history, hasLength(kHongguoHistoryCount)); // the machine keeps twenty
      expect(controller.state.history.first, '词24');
    });

    test('a blank field clears the results and keeps the words', () async {
      await firstSearch('甜宠');
      client.appSearchGates.removeAt(0).complete((items: [series('1')], hasMore: false, next: null));
      await _tick();
      expect(controller.state.items, isNotEmpty);

      await controller.search('  ');
      expect(controller.state.query, isEmpty);
      expect(controller.state.items, isEmpty);
      expect(controller.state.history.first, '甜宠'); // the words stay
    });

    test("the machine's own words come back after a restart, strangers skipped", () async {
      await StoragePrefs.setString('hongguo.search.history', jsonEncode(['老剧', '', 42, '新剧']));
      final restarted = ProviderContainer(overrides: [hongguoClientProvider.overrideWithValue(client)]);
      addTearDown(restarted.dispose);
      restarted.listen(hongguoSearchProvider, (_, _) {});
      expect(restarted.read(hongguoSearchProvider).history, ['老剧', '新剧']);

      await StoragePrefs.setString('hongguo.search.history', 'not json');
      final junked = ProviderContainer(overrides: [hongguoClientProvider.overrideWithValue(client)]);
      addTearDown(junked.dispose);
      junked.listen(hongguoSearchProvider, (_, _) {});
      expect(junked.read(hongguoSearchProvider).history, isEmpty);
    });

    testWidgets('the typing pause asks, a blank drops, and a newer ask wins', (tester) async {
      await tester.pumpWidget(const SizedBox.shrink()); // the clock the timers ride

      controller.suggest('甜');
      expect(controller.state.suggesting, isFalse); // the pause, not the ask
      expect(client.suggestionAsks, isEmpty);

      await tester.pump(const Duration(milliseconds: 350));
      expect(client.suggestionAsks, ['甜']);
      expect(controller.state.suggesting, isTrue);
      client.suggestionGates.removeAt(0).complete(['甜宠', '甜蜜']);
      await tester.pump();
      expect(controller.state.suggestions, ['甜宠', '甜蜜']);
      expect(controller.state.suggesting, isFalse);

      controller.suggest('  ');
      expect(controller.state.suggestions, isEmpty); // the blank drops the held words

      // two pauses race: the older answer never lands
      controller.suggest('甲');
      await tester.pump(const Duration(milliseconds: 350));
      controller.suggest('乙');
      await tester.pump(const Duration(milliseconds: 350));
      client.suggestionGates.removeAt(0).complete(['甲词']);
      await tester.pump();
      expect(controller.state.suggestions, isEmpty); // the older answer is thrown away
      expect(controller.state.suggesting, isTrue);

      client.suggestionGates.removeAt(0).complete(['乙词']);
      await tester.pump();
      expect(controller.state.suggestions, ['乙词']);
    });

    testWidgets('a failed suggestion only says so', (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());

      client.suggestionFailure = Exception('refused');
      controller.suggest('甜');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(controller.state.suggestionError, isNotNull); // the words' failure is named
      expect(controller.state.suggesting, isFalse);
      expect(controller.state.suggestions, isEmpty);

      controller.suggest('  '); // the blank drops the held words — their failure line drops with them
      expect(controller.state.suggestionError, isNull);

      await tester.pump(const Duration(milliseconds: 200)); // the log's own coalescing timer
    });

    test('a failed suggestion leaves the search itself untouched', () async {
      client.suggestionFailure = Exception('refused');
      unawaited(controller.search('甜宠'));
      client.appSearchGates.removeAt(0).complete((items: [series('1')], hasMore: false, next: null));
      await _tick();
      expect(controller.state.items.single.seriesId, '1'); // the viewer can still search what they typed
      expect(controller.state.suggestionError, isNull); // the suggestion's failure rides its own field
    });
  });
}

Future<void> _tick() => Future<void>.delayed(const Duration(milliseconds: 1));

/// One series card, as the lists hand it around.
HongguoSeries series(String id, {String category = ''}) =>
    HongguoSeries(seriesId: id, title: '剧$id', category: category);

/// The client's stand-in for the boards and the search: every ask is
/// recorded and every answer is held at a gate the test releases; a set
/// failure throws at the ask itself. The transport underneath never runs —
/// the five overridden methods are all these controllers ask of it.
final class _ScriptedClient extends HongguoOfficialClient {
  _ScriptedClient() : super(http: _RouteStub());

  final List<String> appSearchWords = [];
  final List<(String, int)> websiteSearchAsks = [];
  final List<String> suggestionAsks = [];
  final List<HongguoWebsiteBoard> rankAsks = [];

  final List<Completer<({List<HongguoSeries> items, bool hasMore, HongguoSearchCursor? next})>> appSearchGates = [];
  final List<Completer<({List<HongguoSeries> items, bool hasMore})>> websiteGates = [];
  final List<Completer<List<HongguoSeries>>> rankGates = [];
  final List<Completer<List<String>>> suggestionGates = [];

  Exception? appSearchFailure;
  Exception? websiteSearchFailure;
  Exception? rankFailure;
  Exception? suggestionFailure;

  @override
  Future<({List<HongguoSeries> items, bool hasMore, HongguoSearchCursor? next})> appSearch(
    String keyword, {
    HongguoSearchCursor? cursor,
    HongguoGenre genre = HongguoGenre.shortPlay,
  }) {
    appSearchWords.add(keyword);
    final failure = appSearchFailure;
    if (failure != null) throw failure;
    final gate = Completer<({List<HongguoSeries> items, bool hasMore, HongguoSearchCursor? next})>();
    appSearchGates.add(gate);
    return gate.future;
  }

  @override
  Future<({List<HongguoSeries> items, bool hasMore})> websiteSearch(String keyword, {int page = 1}) {
    websiteSearchAsks.add((keyword, page));
    final failure = websiteSearchFailure;
    if (failure != null) throw failure;
    final gate = Completer<({List<HongguoSeries> items, bool hasMore})>();
    websiteGates.add(gate);
    return gate.future;
  }

  @override
  Future<List<String>> searchSuggestions(String keyword) {
    suggestionAsks.add(keyword);
    final failure = suggestionFailure;
    if (failure != null) throw failure;
    final gate = Completer<List<String>>();
    suggestionGates.add(gate);
    return gate.future;
  }

  @override
  Future<List<HongguoSeries>> websiteRankSnapshot(HongguoWebsiteBoard board) {
    rankAsks.add(board);
    final failure = rankFailure;
    if (failure != null) throw failure;
    final gate = Completer<List<HongguoSeries>>();
    rankGates.add(gate);
    return gate.future;
  }
}

/// A transport answering by route fragment, each route free to read the ask.
final class _RouteStub implements LiveHttp {
  final Map<String, String Function(LiveRequest)> _routes = {};
  final List<LiveRequest> seen = [];
  final Map<String, Completer<String>> _gates = {};

  /// Answers every request whose path contains [fragment] with what
  /// [answer] reads out of the ask.
  void routeFor(String fragment, String Function(LiveRequest) answer) => _routes[fragment] = answer;

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    seen.add(request);
    final entry = _routes.entries.firstWhere(
      (entry) => request.url.path.contains(entry.key),
      orElse: () => throw StateError('no answer for ${request.url.path}'),
    );
    final gate = _gates[entry.key];
    final body = gate == null ? entry.value(request) : await gate.future;
    return LiveResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      bodyBytes: Uint8List.fromList(utf8.encode(body)),
    );
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnsupportedError('the client buffers');

  @override
  void close() {}
}
