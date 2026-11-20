import 'dart:async' show Completer;
import 'dart:convert' show jsonEncode, utf8;
import 'dart:typed_data' show Uint8List;

import 'package:dio/dio.dart' show Headers, HttpClientAdapter, RequestOptions, ResponseBody;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show DioFactory, LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/app.dart' show networkFactoryProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_account_state.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart';
import 'package:pure_live/modules/hongguo/official/hongguo_account.dart' show HongguoAccountClient, HongguoCredentials;

/// The account session and the shelves behind it over stubbed transports:
/// the login that survives a plain failure but yields to a revoked one (and
/// to a sign-out that lands while its read is under way), the cloud
/// favorites, history and reservations as the endpoints spell them, and the
/// home feed's held session — where a retry during a load must keep the
/// newer answer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageStores stores;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  tearDown(() => stores.close());

  /// The stored login, as the controller restores it. The key lives
  /// privately in the controller; this is the same string it reads.
  Future<void> seedLogin(HongguoCredentials credentials) =>
      StoragePrefs.setString('hongguo.account.credentials', credentials.toJson());

  String profileAnswer({String id = '42', String name = '甲'}) => jsonEncode({
    'code': 0,
    'data': {'biz_user_id': id, 'user_name': name},
  });

  group('the account session', () {
    late _LiveStub stub;
    late ProviderContainer container;

    setUp(() {
      stub = _LiveStub();
      container = ProviderContainer(
        overrides: [hongguoAccountClientProvider.overrideWith((ref) => HongguoAccountClient(http: stub))],
      );
      addTearDown(container.dispose);
    });

    test('restores the stored login, reads the profile, and carries the cookie', () async {
      await seedLogin(const HongguoCredentials(cookie: 'sid=1'));
      stub.routeFor('user/info/v1', (request) => profileAnswer());
      container.listen(hongguoAccountProvider, (_, _) {});
      final controller = container.read(hongguoAccountProvider.notifier);

      // The restore answers at once: the login held, the profile not yet.
      final restored = container.read(hongguoAccountProvider);
      expect(restored.credentials?.cookie, 'sid=1');
      expect(restored.signedIn, isTrue);
      expect(restored.profile, isNull);
      expect(restored.loading, isTrue); // the page's profile read is pending

      await controller.refreshProfile();
      final state = container.read(hongguoAccountProvider);
      expect(state.profile?.id, '42');
      expect(state.profile?.nickname, '甲');
      expect(state.loading, isFalse);
      expect(state.error, isNull);
      expect(stub.seen.single.headers['Cookie'], 'sid=1'); // the login rides every ask
      expect(StoragePrefs.getString('hongguo.account.credentials'), isNotNull);
    });

    test('a login the platform refuses signs itself out', () async {
      await seedLogin(const HongguoCredentials(cookie: 'sid=1'));
      stub.routeFor('user/info/v1', (request) => '{"code":-7200,"message":"账号已在别处登录"}');
      container.listen(hongguoAccountProvider, (_, _) {});
      final controller = container.read(hongguoAccountProvider.notifier);

      await controller.refreshProfile();
      final state = container.read(hongguoAccountProvider);
      expect(state.signedIn, isFalse); // the refused login is gone
      expect(state.error, contains('重新登录'));
      await pumpEventQueue();
      expect(StoragePrefs.getString('hongguo.account.credentials'), isNull); // the storage followed
    });

    test('a plain failure keeps the login and names itself', () async {
      await seedLogin(const HongguoCredentials(cookie: 'sid=1'));
      stub.routeFor('user/info/v1', (request) => '   '); // the empty answer is not a refusal
      container.listen(hongguoAccountProvider, (_, _) {});
      final controller = container.read(hongguoAccountProvider.notifier);

      await controller.refreshProfile();
      final state = container.read(hongguoAccountProvider);
      expect(state.signedIn, isTrue); // still held
      expect(state.error, contains('空响应'));
      await pumpEventQueue();
      expect(StoragePrefs.getString('hongguo.account.credentials'), isNotNull);
    });

    test('a sign-out during the profile read owns the state, not the late answer', () async {
      await seedLogin(const HongguoCredentials(cookie: 'sid=1'));
      final gate = Completer<String>();
      final stub = _LiveStub()
        ..hold('user/info/v1', gate)
        ..routeFor('user/info/v1', (request) => profileAnswer(name: '迟到的旧资料'));
      final container = ProviderContainer(
        overrides: [hongguoAccountClientProvider.overrideWith((ref) => HongguoAccountClient(http: stub))],
      );
      addTearDown(container.dispose);
      container.listen(hongguoAccountProvider, (_, _) {});
      final controller = container.read(hongguoAccountProvider.notifier);

      // The profile read is under way when the viewer signs out.
      final reading = controller.refreshProfile();
      await pumpEventQueue();
      await controller.signOut();
      expect(container.read(hongguoAccountProvider).signedIn, isFalse);

      // The stalled answer lands now, carrying the old login. It must not
      // sign the viewer back in.
      gate.complete(profileAnswer(name: '迟到的旧资料'));
      await reading;
      await pumpEventQueue();
      final state = container.read(hongguoAccountProvider);
      expect(state.signedIn, isFalse); // the late answer stayed out
      expect(state.profile, isNull);
      expect(state.error, isNull);
      await pumpEventQueue();
      expect(StoragePrefs.getString('hongguo.account.credentials'), isNull);
    });
  });

  group('the cloud shelves', () {
    test('a guest asks nothing and reads the empty shelves', () async {
      final stub = _LiveStub();
      final container = ProviderContainer(
        overrides: [hongguoAccountClientProvider.overrideWith((ref) => HongguoAccountClient(http: stub))],
      );
      addTearDown(container.dispose);

      await container.read(hongguoAccountFavoritesProvider.notifier).refresh();
      await container.read(hongguoAccountHistoryProvider.notifier).refresh();
      await container.read(hongguoReservationsProvider.notifier).refresh();

      final favorites = container.read(hongguoAccountFavoritesProvider);
      expect(favorites.items, isEmpty);
      expect(favorites.error, isNull);
      expect(container.read(hongguoAccountHistoryProvider).items, isEmpty);
      expect(container.read(hongguoReservationsProvider).online, isEmpty);
      expect(stub.seen, isEmpty); // signed out, the shelves read locally
    });

    test('the favorites walk parses both row shapes, sorts, and reads back after a write', () async {
      final stub = _LiveStub()
        ..routeFor(
          'bookshelf/video/info',
          (request) => jsonEncode({
            'code': 0,
            'data': {
              'video_shelf_info': [
                {
                  // The nested shape: the series lives under video_data.
                  'video_data': {'series_id': '901', 'series_title': '剧一', 'episode_cnt': 12, 'cover': 'https://c/1'},
                  'collect_time': 1700000000,
                },
                {'book_id': '902', 'book_name': '剧二', 'abstract': '简介二', 'episode_cnt': 8},
                {'series_id': '903'}, // no title anywhere: out
                {
                  // The same series again, collected earlier: out.
                  'video_data': {'series_id': '901', 'series_title': '剧一'},
                  'collect_time': 1699999999,
                },
              ],
            },
          }),
        )
        ..routeFor('bookshelf/video/update', (request) => '{"code":0}');
      final container = ProviderContainer(
        overrides: [hongguoAccountClientProvider.overrideWith((ref) => HongguoAccountClient(http: stub))],
      );
      addTearDown(container.dispose);
      await seedLogin(const HongguoCredentials(cookie: 'sid=1'));
      container.listen(hongguoAccountProvider, (_, _) {});
      final controller = container.read(hongguoAccountFavoritesProvider.notifier);

      await controller.refresh();
      final shelf = container.read(hongguoAccountFavoritesProvider);
      expect(shelf.items.map((favorite) => favorite.series.seriesId), ['901', '902']); // newest first, deduped
      expect(shelf.items.first.series.title, '剧一');
      expect(shelf.items.first.collectedAt, 1700000000000); // seconds became milliseconds
      expect(shelf.items.last.collectedAt, 0); // the shelf that never said stays unknown
      expect(shelf.items.last.series.episodeCount, 8);
      expect(shelf.error, isNull);

      // The write is acknowledged, then the shelf is read back.
      await controller.setFavorite(const HongguoSeries(seriesId: '904', title: '剧四'), add: true);
      var updates = stub.seen.where((request) => request.url.path.contains('bookshelf/video/update'));
      expect(updates, hasLength(1));
      expect(bodyOf(updates.single), contains('"book_id":"904"'));
      expect(bodyOf(updates.single), contains('"video_shelf_operate_type":0'));

      // The removal speaks its own verb.
      await controller.setFavorite(const HongguoSeries(seriesId: '904', title: '剧四'), add: false);
      updates = stub.seen.where((request) => request.url.path.contains('bookshelf/video/update'));
      expect(updates, hasLength(2));
      expect(bodyOf(updates.last), contains('"video_shelf_operate_type":1'));

      // A refused write is swallowed; the read-back decides what the shelf holds.
      stub.routeFor('bookshelf/video/update', (request) => '{"code":-2,"message":"拒了"}');
      await controller.setFavorite(const HongguoSeries(seriesId: '905', title: '剧五'), add: true);
      updates = stub.seen.where((request) => request.url.path.contains('bookshelf/video/update'));
      expect(updates, hasLength(3));
      final shelfAfter = container.read(hongguoAccountFavoritesProvider);
      expect(shelfAfter.items.map((favorite) => favorite.series.seriesId), ['901', '902']);
      expect(shelfAfter.error, isNull); // the shelf read answered, so no error shows
    });

    test('the history walk resolves the series names and falls back to the id', () async {
      final stub = _LiveStub()
        ..routeFor(
          'read_progress/list',
          (request) => jsonEncode({
            'code': 0,
            'video_data': [
              {
                'series_id': '701',
                'vid': '90001',
                'vid_index': 2,
                'last_watch_time': 1700000000,
                'current_play_time': 5000,
                'current_total_time': 60000,
              },
              {
                'series_id': '701', // the same series again, further behind: out
                'vid': '90001',
                'vid_index': 1,
                'last_watch_time': 1699999999,
                'current_play_time': 1000,
              },
              {'book_id': '702', 'vid': '90002', 'last_watch_time': 170000000000}, // past the seconds cap: raw
              {'series_id': 'x', 'vid': '90003'}, // a non-numeric id: out
            ],
          }),
        )
        ..routeFor(
          'multi-detail/v1',
          (request) => jsonEncode({
            'code': 0,
            'data': [
              {'book_id': '701', 'book_name': '剧一', 'episode_cnt': 12},
            ],
          }),
        );
      final container = ProviderContainer(
        overrides: [hongguoAccountClientProvider.overrideWith((ref) => HongguoAccountClient(http: stub))],
      );
      addTearDown(container.dispose);
      await seedLogin(const HongguoCredentials(cookie: 'sid=1'));
      container.listen(hongguoAccountProvider, (_, _) {});
      final controller = container.read(hongguoAccountHistoryProvider.notifier);

      await controller.refresh();
      final history = container.read(hongguoAccountHistoryProvider);
      expect(history.items.map((entry) => entry.series.seriesId), ['701', '702']); // newest watch first
      expect(history.items.map((entry) => entry.series.title), ['剧一', '702']); // the unresolved id stands in
      expect(history.items.map((entry) => entry.episodeIndex), [1, 0]); // the 0-based seats
      expect(history.items.first.positionMs, 5000);
      expect(history.items.first.updatedAt, 1700000000000); // seconds became milliseconds
      expect(history.items.last.updatedAt, 170000000000); // past the cap, taken as it came
      expect(history.error, isNull);
      final details = stub.seen.last;
      expect(details.url.path, contains('multi-detail'));
      expect(details.url.queryParameters['book_id'], '701,702'); // one batch for the names
    });

    test('the reservations walk splits the shelves and fills the missing counts', () async {
      final stub = _LiveStub()
        ..routeFor('subscribe/list', (request) {
          final online = request.url.queryParameters['is_online'];
          return jsonEncode({
            'code': 0,
            'data': {
              'subscribe_items': online == 'true'
                  ? [
                      {
                        'subscribe_data': {'series_id': '801', 'series_title': '上线剧'},
                        'is_online': true,
                        'schedule_publish_time': 1700000000,
                      },
                      {
                        // Marked for the other shelf: out.
                        'subscribe_data': {'series_id': '803', 'series_title': '错架剧'},
                        'is_online': false,
                      },
                    ]
                  : [
                      {
                        // An unpublished one: the reservation id, never a playback id.
                        'item_id': '802',
                        'series_title': '待上线剧',
                        'expected_rec_text': '明天上线',
                      },
                    ],
            },
          });
        })
        ..routeFor(
          'multi-detail/v1',
          (request) => jsonEncode({
            'code': 0,
            'data': [
              {'book_id': '801', 'drama_chapter_number': 12},
            ],
          }),
        );
      final container = ProviderContainer(
        overrides: [hongguoAccountClientProvider.overrideWith((ref) => HongguoAccountClient(http: stub))],
      );
      addTearDown(container.dispose);
      await seedLogin(const HongguoCredentials(cookie: 'sid=1'));
      container.listen(hongguoAccountProvider, (_, _) {});
      final controller = container.read(hongguoReservationsProvider.notifier);

      await controller.refresh();
      final state = container.read(hongguoReservationsProvider);
      expect(state.online.single.series.seriesId, '801');
      expect(state.online.single.series.episodeCount, 12); // the batch filled the count in
      expect(state.online.single.series.hot, '已上线'); // the badge the row itself could not say
      expect(state.online.single.publishAt, 1700000000000);
      expect(state.upcoming.single.series.seriesId, 'reservation:802');
      expect(state.upcoming.single.publishText, '明天上线');
      expect(state.upcoming.single.online, isFalse);
      expect(state.error, isNull);

      final subscribeAsks = stub.seen.where((request) => request.url.path.contains('subscribe/list'));
      expect(subscribeAsks, hasLength(2));
      expect(subscribeAsks.first.url.queryParameters['is_online'], 'true');
      expect(subscribeAsks.last.url.queryParameters['is_online'], 'false');
      // One details batch, for the online shelf only: the waiting one has no
      // numeric id to resolve.
      final detailsAsks = stub.seen.where((request) => request.url.path.contains('multi-detail'));
      expect(detailsAsks, hasLength(1));
      expect(detailsAsks.single.url.queryParameters['book_id'], '801');
    });
  });

  group('the home walk', () {
    late _DioStub adapter;
    late ProviderContainer container;

    setUp(() {
      adapter = _DioStub();
      container = ProviderContainer(
        overrides: [networkFactoryProvider.overrideWith((ref) => DioFactory(adapterFactory: (route) => adapter))],
      );
      addTearDown(container.dispose);
      container.listen(hongguoHomeProvider, (_, _) {});
    });

    Map<String, Object?> card(String id, String title) => {'series_id': id, 'series_title': title};

    String landpage({required List<Map<String, Object?>> rows, String session = 'sess-9', int? nextOffset}) =>
        jsonEncode({
          'code': 0,
          'data': {'video_data': rows, 'session_id': session, 'next_offset': ?nextOffset},
        });

    test('opens, rides the session cursor, waits out a failure, and retries fresh', () async {
      adapter.routeFor('landpage/v', (options) {
        final body = bodyOfDio(options);
        return body.contains('"offset":24')
            ? landpage(rows: [card('603', '三')], nextOffset: 48)
            : landpage(rows: [card('601', '一'), card('602', '二')], nextOffset: 24);
      });
      final controller = container.read(hongguoHomeProvider.notifier);

      await controller.open(HongguoGenre.shortPlay);
      var home = container.read(hongguoHomeProvider);
      expect(home.items.map((series) => series.seriesId), ['601', '602']);
      expect(home.genre, HongguoGenre.shortPlay);
      expect(home.error, isNull);

      // The held feed answers at once.
      await controller.open(HongguoGenre.shortPlay);
      expect(adapter.seen, hasLength(1));

      // The next batch rides the session and keeps the seen ids out.
      await controller.loadMore();
      home = container.read(hongguoHomeProvider);
      expect(home.items.map((series) => series.seriesId), ['601', '602', '603']);
      final second = bodyOfDio(adapter.seen[1]);
      expect(second, contains('"session_id":"sess-9"'));
      expect(second, contains('"filter_ids":"601,602"'));

      // A failed batch keeps the rows and waits: open asks nothing more,
      // only the retry does.
      adapter.routeFor('landpage/v', (options) => '{"code":-2,"message":"挂了"}');
      await controller.loadMore();
      home = container.read(hongguoHomeProvider);
      expect(home.error, contains('-2'));
      expect(home.items, hasLength(3));
      await controller.open(HongguoGenre.shortPlay);
      expect(adapter.seen, hasLength(3)); // the failed feed waits

      adapter.routeFor('landpage/v', (options) => landpage(rows: [card('604', '四')]));
      await controller.retry();
      home = container.read(hongguoHomeProvider);
      expect(home.error, isNull);
      expect(home.items.single.seriesId, '604'); // a retry runs the feed from its head
    });

    test('a retry during a load keeps the newer answer, not the stalled one', () async {
      final gate = Completer<String>();
      adapter
        ..hold('landpage/v', gate)
        ..routeFor('landpage/v', (options) => landpage(rows: [card('609', '新')]));
      final controller = container.read(hongguoHomeProvider.notifier);

      // The first batch is under way when the viewer retries.
      final opening = controller.open(HongguoGenre.shortPlay);
      await pumpEventQueue();
      expect(container.read(hongguoHomeProvider).loading, isTrue);

      await controller.retry();
      expect(container.read(hongguoHomeProvider).items.single.seriesId, '609');

      // The stalled first session lands now; its answer must stay out.
      gate.complete(landpage(rows: [card('601', '旧')], nextOffset: 24));
      await opening;
      await pumpEventQueue();
      expect(container.read(hongguoHomeProvider).items.single.seriesId, '609');
    });
  });
}

/// The ask's JSON body, read out of the request.
String bodyOf(LiveRequest request) =>
    request.body ?? utf8.decode(request.bodyBytes ?? Uint8List.fromList(const []), allowMalformed: true);

/// The dio ask's JSON body, read out of the options.
String bodyOfDio(RequestOptions options) {
  final data = options.data;
  if (data is Uint8List) return utf8.decode(data, allowMalformed: true);
  if (data is String) return data;
  return '';
}

/// A transport answering by route fragment, each route free to read the ask.
final class _LiveStub implements LiveHttp {
  final Map<String, String Function(LiveRequest)> _routes = {};
  final List<LiveRequest> seen = [];
  final Map<String, Completer<String>> _gates = {};

  void routeFor(String fragment, String Function(LiveRequest) answer) => _routes[fragment] = answer;

  /// Gates the first matching ask; later asks pass free.
  void hold(String fragment, Completer<String> gate) => _gates[fragment] = gate;

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    seen.add(request);
    final entry = _routes.entries.firstWhere(
      (entry) => request.url.path.contains(entry.key),
      orElse: () => throw StateError('no answer for ${request.url.path}'),
    );
    final gate = _gates[entry.key];
    if (gate != null) {
      _gates.remove(entry.key);
      return _answer(await gate.future);
    }
    return _answer(entry.value(request));
  }

  LiveResponse _answer(String body) => LiveResponse(
    statusCode: 200,
    headers: const {'content-type': 'application/json'},
    bodyBytes: Uint8List.fromList(utf8.encode(body)),
  );

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnsupportedError('the client buffers');

  @override
  void close() {}
}

/// A dio adapter answering by route fragment, each route free to read the
/// ask; the gate holds only the first matching ask.
final class _DioStub implements HttpClientAdapter {
  final Map<String, String Function(RequestOptions)> _routes = {};
  final List<RequestOptions> seen = [];
  final Map<String, Completer<String>> _gates = {};

  void routeFor(String fragment, String Function(RequestOptions) answer) => _routes[fragment] = answer;

  void hold(String fragment, Completer<String> gate) => _gates[fragment] = gate;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add(options);
    final entry = _routes.entries.firstWhere(
      (entry) => options.uri.path.contains(entry.key),
      orElse: () => throw StateError('no answer for ${options.uri.path}'),
    );
    final gate = _gates[entry.key];
    if (gate != null) {
      _gates.remove(entry.key);
      return _answer(await gate.future);
    }
    return _answer(entry.value(options));
  }

  ResponseBody _answer(String body) => ResponseBody.fromString(
    body,
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}
