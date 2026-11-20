import 'dart:async' show Completer;
import 'dart:convert' show jsonEncode, utf8;
import 'dart:typed_data' show Uint8List;

import 'package:dio/dio.dart' show Headers, HttpClientAdapter, RequestOptions, ResponseBody;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show DioFactory, LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:live_storage/live_storage.dart';
import 'package:live_vod/live_vod.dart' show BilibiliVodClient;
import 'package:pure_live/app/app.dart' show networkFactoryProvider;
import 'package:pure_live/modules/live/archive/archive_catalog_controller.dart';
import 'package:pure_live/modules/vod/controller/vod_controller.dart' show vodClientProvider;

/// The replay catalog over stubbed transports: the walk that filters and
/// opens a creator's collections, the archive rows it keeps, the pager and
/// the collection switch, the guards that ask nothing, and the newer start
/// that silences an older one.
void main() {
  late StorageStores stores;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  tearDown(() => stores.close());

  group('the bilibili walk', () {
    late _RouteStub http;
    late ProviderContainer container;

    setUp(() {
      http = _RouteStub();
      container = ProviderContainer(overrides: [vodClientProvider.overrideWith((ref) => BilibiliVodClient(http))]);
    });

    tearDown(() => container.dispose());

    /// Two qualifying collections (a season and a series), one plain
    /// uploads series that must stay out, the season freshest.
    void installCollections({int total = 1}) {
      http.routes['seasons_series_list'] = jsonEncode({
        'code': 0,
        'data': {
          'items_lists': {
            'seasons_list': [
              {
                'meta': {'mid': 42, 'season_id': 7, 'name': '直播回放', 'last_update_ts': 300},
              },
            ],
            'series_list': [
              {
                'meta': {'mid': 42, 'series_id': 9, 'name': '我的上传合集'},
              },
              {
                'meta': {'mid': 99, 'season_id': 8, 'name': '直播回放', 'last_update_ts': 999},
              },
              {
                'meta': {'mid': 42, 'series_id': 5, 'name': '直播 录像', 'last_update_ts': 100},
              },
            ],
            'page': {'total': total},
          },
        },
      });
    }

    test('start keeps the replay-labelled collections, freshest first, and opens it', () async {
      installCollections();
      http.routes['seasons_archives_list'] = jsonEncode({
        'code': 0,
        'data': {
          'archives': [
            {'bvid': 'BV1abcdefghi', 'title': '回放一', 'duration': 120, 'pubdate': 1704067200},
            {'bvid': 'BVshort', 'title': '坏行不进目录'},
            {'bvid': 'BV1abcdefghi', 'title': '重复行不留'},
            {'title': '没有 bvid'},
          ],
          'page': {'total': 25},
        },
      });

      final controller = container.read(archiveCatalogProvider.notifier);
      await controller.start(siteId: 'bilibili', creator: '42');
      final state = container.read(archiveCatalogProvider);

      expect(state.opening, isFalse);
      expect(state.openingError, isNull);
      // The uploads series and the other creator's replay stay out; the
      // freshest replay label leads.
      expect(state.collections.map((item) => item.key), ['season:7', 'series:5']);
      expect(state.selectedKey, 'season:7');
      // The bad rows never land; the duplicate keeps one seat.
      expect(state.recordings, hasLength(1));
      expect(state.recordings.first.display.id, 'BV1abcdefghi');
      expect(state.recordings.first.display.title, '回放一');
      expect(state.recordings.first.bilibili, isNotNull);
      expect(state.page, 1);
      expect(state.hasMore, isTrue); // 1 * 20 < 25
      expect(state.error, isNull);
    });

    test('an empty answer is honest: no collections, nothing loading', () async {
      http.routes['seasons_series_list'] = jsonEncode({
        'code': 0,
        'data': {
          'items_lists': {
            'seasons_list': const <Object>[],
            'series_list': const <Object>[],
            'page': {'total': 0},
          },
        },
      });

      await container.read(archiveCatalogProvider.notifier).start(siteId: 'bilibili', creator: '42');
      final state = container.read(archiveCatalogProvider);
      expect(state.opening, isFalse);
      expect(state.collections, isEmpty);
      expect(state.recordings, isEmpty);
      expect(state.hasMore, isFalse);
    });

    test('select reads another collection from its head, and the guards ask nothing', () async {
      installCollections();
      http.routes['seasons_archives_list'] = jsonEncode({
        'code': 0,
        'data': {
          'archives': const <Object>[],
          'page': {'total': 0},
        },
      });

      final controller = container.read(archiveCatalogProvider.notifier);
      await controller.start(siteId: 'bilibili', creator: '42');
      final afterStart = http.seen.length;

      // The same key, an unknown key: neither asks.
      await controller.select('season:7');
      await controller.select('season:999');
      expect(http.seen.length, afterStart);
      expect(container.read(archiveCatalogProvider).selectedKey, 'season:7');

      // The other collection reads its own endpoint.
      http.routes['series/archives'] = jsonEncode({
        'code': 0,
        'data': {
          'archives': [
            {'bvid': 'BV1zzzzzzzzz', 'title': '系列回放', 'duration': 60, 'pubdate': 1704000000},
          ],
          'page': {'total': 1},
        },
      });
      await controller.select('series:5');
      final state = container.read(archiveCatalogProvider);
      expect(state.selectedKey, 'series:5');
      expect(state.recordings.single.display.id, 'BV1zzzzzzzzz');
      expect(state.loading, isFalse);
      expect(http.seen.sublist(afterStart).join(' '), contains('series/archives'));
    });

    test('loadMore appends the next block and stops where the station does', () async {
      installCollections(total: 21);
      http.routes['seasons_archives_list'] = jsonEncode({
        'code': 0,
        'data': {
          'archives': [
            {'bvid': 'BV1aaaaaaaaa', 'title': '第一块', 'duration': 10, 'pubdate': 1704067200},
          ],
          'page': {'total': 21},
        },
      });

      final controller = container.read(archiveCatalogProvider.notifier);
      await controller.start(siteId: 'bilibili', creator: '42');
      expect(container.read(archiveCatalogProvider).recordings, hasLength(1));

      http.routes['seasons_archives_list'] = jsonEncode({
        'code': 0,
        'data': {
          'archives': [
            {'bvid': 'BV1bbbbbbbbb', 'title': '第二块', 'duration': 10, 'pubdate': 1704070000},
          ],
          'page': {'total': 21},
        },
      });
      await controller.loadMore();
      final state = container.read(archiveCatalogProvider);
      expect(state.recordings.map((pick) => pick.display.id), ['BV1aaaaaaaaa', 'BV1bbbbbbbbb']);
      expect(state.page, 2);
      // 2 * 20 = 40 is past 21: the walk is over.
      expect(state.hasMore, isFalse);

      // An ended walk asks for nothing more.
      await controller.loadMore();
      expect(state.page, 2);
    });

    test('a failed archive page names the failure and keeps the collection', () async {
      installCollections();
      http.routes['seasons_archives_list'] = jsonEncode({'code': -404, 'message': '啥都木有'});

      await container.read(archiveCatalogProvider.notifier).start(siteId: 'bilibili', creator: '42');
      final state = container.read(archiveCatalogProvider);
      expect(state.loading, isFalse);
      expect(state.error, isNotNull);
      // The collection itself stays selected for the retry.
      expect(state.selectedKey, 'season:7');
      expect(state.recordings, isEmpty);

      // The retry reads the same head.
      http.routes['seasons_archives_list'] = jsonEncode({
        'code': 0,
        'data': {
          'archives': [
            {'bvid': 'BV1ccccccccc', 'title': '重试到了', 'duration': 30, 'pubdate': 1704067200},
          ],
          'page': {'total': 0},
        },
      });
      await container.read(archiveCatalogProvider.notifier).reload();
      expect(container.read(archiveCatalogProvider).recordings.single.display.title, '重试到了');
    });

    test('a newer start silences the older walk, even after its answer lands', () async {
      installCollections();
      final gate = Completer<String>();
      http.hold('seasons_archives_list', gate);

      final controller = container.read(archiveCatalogProvider.notifier);
      final first = controller.start(siteId: 'bilibili', creator: '42');

      // The second start names another creator and answers at once.
      http.routes['seasons_series_list'] = jsonEncode({
        'code': 0,
        'data': {
          'items_lists': {
            'seasons_list': const <Object>[],
            'series_list': const <Object>[],
            'page': {'total': 0},
          },
        },
      });
      await controller.start(siteId: 'bilibili', creator: '43');
      final afterSecond = container.read(archiveCatalogProvider);
      expect(afterSecond.creator, '43');
      expect(afterSecond.collections, isEmpty);
      expect(afterSecond.opening, isFalse);

      // The stalled answer lands now; it must not overwrite the newer walk.
      gate.complete(
        jsonEncode({
          'code': 0,
          'data': {
            'archives': [
              {'bvid': 'BV1ddddddddd', 'title': '迟到的目录', 'duration': 10, 'pubdate': 1704067200},
            ],
            'page': {'total': 0},
          },
        }),
      );
      await first;
      await pumpEventQueue();
      final state = container.read(archiveCatalogProvider);
      expect(state.creator, '43');
      expect(state.recordings, isEmpty);
      expect(state.opening, isFalse);
    });

    test('the guards before any walk ask nothing', () async {
      final controller = container.read(archiveCatalogProvider.notifier);

      await controller.start(siteId: 'bilibili', creator: ''); // an empty creator
      expect(container.read(archiveCatalogProvider).siteId, isNull);
      expect(http.seen, isEmpty);

      await controller.reload(); // no selection yet
      await controller.loadMore(); // no collection yet
      expect(http.seen, isEmpty);

      // The same target twice asks once.
      installCollections();
      http.routes['seasons_archives_list'] = jsonEncode({
        'code': 0,
        'data': {
          'archives': const <Object>[],
          'page': {'total': 0},
        },
      });
      await controller.start(siteId: 'bilibili', creator: '42');
      final afterFirst = http.seen.length;
      await controller.start(siteId: 'bilibili', creator: '42');
      expect(http.seen.length, afterFirst);
    });
  });

  group('the douyu walk', () {
    late _DioStub adapter;
    late ProviderContainer container;

    setUp(() {
      adapter = _DioStub();
      container = ProviderContainer(
        overrides: [
          networkFactoryProvider.overrideWith(
            (ref) => DioFactory(
              // The stubbed adapter answers every route with the canned body.
              adapterFactory: (route) => adapter,
            ),
          ),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('start resolves the presenter id, reads the sessions flattened, and pages on', () async {
      adapter.routes['/betard/8808'] = jsonEncode({
        'room': {'up_id': 'author42'},
      });
      adapter.routes['authorShowVideoList'] = jsonEncode({
        'error': 0,
        'data': {
          'list': [
            {
              'video_list': [
                {'vid': 'vidhash0001', 'title': '直播回放 0101', 'start_time': 1704067200},
                {'vid': 'vidhash0002', 'title': '直播回放 0102', 'start_time': 1704153600},
              ],
            },
          ],
          'count': 12,
        },
      });

      final controller = container.read(archiveCatalogProvider.notifier);
      await controller.start(siteId: 'douyu', creator: '8808');
      var state = container.read(archiveCatalogProvider);
      expect(state.opening, isFalse);
      expect(state.openingError, isNull);
      expect(state.recordings.map((pick) => pick.display.id), ['vidhash0001', 'vidhash0002']);
      expect(state.recordings.first.douyu, isNotNull);
      expect(state.hasMore, isTrue); // 1 * 10 < 12
      expect(state.page, 1);

      // The next page reuses the resolved presenter id.
      adapter.routes['authorShowVideoList'] = jsonEncode({
        'error': 0,
        'data': {
          'list': [
            {
              'video_list': [
                {'vid': 'vidhash0003', 'title': '直播回放 0103', 'start_time': 1704240000},
              ],
            },
          ],
          'count': 12,
        },
      });
      await controller.loadMore();
      state = container.read(archiveCatalogProvider);
      expect(state.recordings.map((pick) => pick.display.id), ['vidhash0001', 'vidhash0002', 'vidhash0003']);
      // 2 * 10 = 20 is past 12: the walk is over.
      expect(state.hasMore, isFalse);

      final asks = adapter.seen.where((url) => url.contains('authorShowVideoList')).toList();
      expect(asks.first, contains('up_id=author42'));
      expect(asks.last, contains('page=2'));
    });

    test('a room answer without a presenter names the failure', () async {
      adapter.routes['/betard/8808'] = jsonEncode({
        'room': {'up_id': '0'},
      });
      await container.read(archiveCatalogProvider.notifier).start(siteId: 'douyu', creator: '8808');
      final state = container.read(archiveCatalogProvider);
      expect(state.opening, isFalse);
      expect(state.openingError, isNotNull);
      expect(state.recordings, isEmpty);
    });

    test('an error envelope names the failure, not an empty catalog', () async {
      adapter.routes['/betard/8808'] = jsonEncode({
        'room': {'up_id': 'author42'},
      });
      adapter.routes['authorShowVideoList'] = jsonEncode({'error': 5, 'message': ' gone '});
      await container.read(archiveCatalogProvider.notifier).start(siteId: 'douyu', creator: '8808');
      final state = container.read(archiveCatalogProvider);
      expect(state.opening, isFalse);
      expect(state.openingError, isNotNull);
      expect(state.recordings, isEmpty);
    });
  });
}

/// A transport answering by route: the tests' JSON bodies keyed by a path
/// fragment, with one route holdable for the stale-answer race.
final class _RouteStub implements LiveHttp {
  final Map<String, Object> routes = {};
  final List<String> seen = [];
  final Map<String, Completer<String>> _gates = {};

  /// Holds the next [fragment] answer until the test completes [gate].
  void hold(String fragment, Completer<String> gate) {
    _gates[fragment] = gate;
  }

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    final url = request.url;
    seen.add('${url.path}?${url.query}');
    final route = routes.entries.firstWhere((entry) => url.path.contains(entry.key)).value;
    final gate = _gates[routes.entries.firstWhere((entry) => url.path.contains(entry.key)).key];
    final body = gate == null ? route as String : await gate.future;
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

/// The dio adapter the douyu walk's factory builds its clients over: the
/// same route answers, read from the final request options.
final class _DioStub implements HttpClientAdapter {
  final Map<String, String> routes = {};
  final List<String> seen = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final url = options.uri;
    seen.add('${url.path}?${url.query}');
    final route = routes.entries.firstWhere((entry) => url.path.contains(entry.key)).value;
    return ResponseBody.fromString(
      route,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
