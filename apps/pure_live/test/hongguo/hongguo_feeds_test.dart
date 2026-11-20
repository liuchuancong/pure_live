import 'dart:async' show Completer;
import 'dart:convert' show jsonEncode, utf8;
import 'dart:typed_data' show Uint8List;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_client.dart' show hongguoClientProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_feeds.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart';
import 'package:pure_live/modules/hongguo/official/hongguo_official.dart' show HongguoOfficialClient;

/// The browse and latest shelves over a stubbed landpage: the selector panel
/// the first page carries, the cursor the later pages ride, the selection
/// that resets the feed and wins by generation, and the latest shelf's
/// pinned time sort.
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

      // A genre choice clears every other dimension, as the reference does.
      await controller.select(HongguoGenre.shortPlay, 'genre', 'short_play');
      expect(feedOf(HongguoGenre.shortPlay).selection, isEmpty);

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
