import 'dart:async' show Completer;
import 'dart:convert' show jsonEncode, utf8;
import 'dart:typed_data' show Uint8List;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:live_storage/live_storage.dart';
import 'package:live_vod/live_vod.dart' show BilibiliVodClient;
import 'package:pure_live/modules/vod/controller/vod_controller.dart' show vodClientProvider;
import 'package:pure_live/modules/vod/controller/vod_social.dart';

/// The dynamic feed's cursored walk and the personal lists behind the
/// account: the cursor each page hands the next, the walk that ends on a
/// repeated cursor, the guest that reads empty without a request, and the
/// signed-in reads that carry the viewer's own id.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageStores stores;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  tearDown(() => stores.close());

  ProviderContainer containerOver(_RouteStub stub, {String cookie = ''}) =>
      ProviderContainer(overrides: [vodClientProvider.overrideWith((ref) => BilibiliVodClient(stub, cookie: cookie))]);

  group('the dynamic walk', () {
    test('opens, hands the cursor on, and ends where the cursor stands still', () async {
      final stub = _RouteStub()
        ..routes['/x/polymer/web-dynamic/v1/feed/all'] = jsonEncode({
          'code': 0,
          'data': {
            'items': [
              {
                'id_str': 'd1',
                'modules': {
                  'module_author': {'name': '甲', 'pub_ts': 1700000000},
                  'module_dynamic': {
                    'desc': {'text': '更新了'},
                    'major': {
                      'archive': {'bvid': 'BV1abcdefghi'},
                    },
                  },
                },
              },
              {
                'id_str': 'd2',
                'modules': {
                  'module_author': {'name': '乙'},
                },
              },
              {
                'modules': {
                  'module_author': {'name': '没有 id'},
                },
              },
            ],
            'offset': 'cursor-1',
            'has_more': true,
          },
        });
      final container = containerOver(stub, cookie: 'SESSDATA=abc; bili_jct=t');
      addTearDown(container.dispose);
      container.listen(vodDynamicsProvider, (_, _) {});
      final controller = container.read(vodDynamicsProvider.notifier);

      await controller.open();
      var feed = container.read(vodDynamicsProvider);
      expect(feed.items.map((item) => item.id), ['d1', 'd2']); // the bad row stays out
      expect(feed.items.first.bvid, 'BV1abcdefghi');
      expect(feed.offset, 'cursor-1');
      expect(feed.hasMore, isTrue);
      expect(feed.loaded, isTrue);
      expect(feed.loading, isFalse);

      // open again asks nothing.
      await controller.open();
      expect(stub.seen, hasLength(1));

      // The next block carries its own cursor.
      stub.routes['/x/polymer/web-dynamic/v1/feed/all'] = jsonEncode({
        'code': 0,
        'data': {
          'items': [
            {
              'id_str': 'd3',
              'modules': {
                'module_author': {'name': '丙'},
              },
            },
          ],
          'offset': 'cursor-2',
          'has_more': true,
        },
      });
      await controller.loadMore();
      feed = container.read(vodDynamicsProvider);
      expect(feed.items.map((item) => item.id), ['d1', 'd2', 'd3']);
      expect(feed.offset, 'cursor-2');
      expect(stub.seen.last.url.queryParameters['offset'], 'cursor-1');

      // The answer repeats the cursor: the walk would stand still, so it
      // ends instead of paging forever.
      await controller.loadMore();
      feed = container.read(vodDynamicsProvider);
      expect(feed.hasMore, isFalse);
      expect(feed.items, hasLength(3));
      await controller.loadMore(); // the ended walk asks for nothing
      expect(stub.seen, hasLength(3));
    });

    test('a failure names itself and the refresh reads the head again', () async {
      final stub = _RouteStub()..routes['/x/polymer/web-dynamic/v1/feed/all'] = '{"code":-312,"message":"风控"}';
      final container = containerOver(stub, cookie: 'SESSDATA=abc; bili_jct=t');
      addTearDown(container.dispose);
      container.listen(vodDynamicsProvider, (_, _) {});
      final controller = container.read(vodDynamicsProvider.notifier);

      // A failed first page is loaded-but-empty: open itself will not
      // re-ask, the refresh does.
      await controller.open();
      var feed = container.read(vodDynamicsProvider);
      expect(feed.loaded, isTrue);
      expect(feed.error, isNotNull);
      expect(feed.hasMore, isFalse);
      expect(feed.items, isEmpty);

      stub.routes['/x/polymer/web-dynamic/v1/feed/all'] = jsonEncode({
        'code': 0,
        'data': {
          'items': [
            {
              'id_str': 'd9',
              'modules': {
                'module_author': {'name': '甲'},
              },
            },
          ],
          'offset': 'cursor-9',
          'has_more': false,
        },
      });
      await controller.refresh();
      feed = container.read(vodDynamicsProvider);
      expect(feed.error, isNull);
      expect(feed.items.single.id, 'd9');
      expect(feed.hasMore, isFalse);
    });
  });

  group('the personal lists behind the account', () {
    test('a guest reads empty without asking the lists', () async {
      final stub = _RouteStub()..routes['/x/web-interface/nav'] = '{"code":-101,"message":"账号未登录","data":null}';
      final container = containerOver(stub);
      addTearDown(container.dispose);

      final following = vodFollowingProvider(1);
      container.listen(following, (_, _) {});
      await container.read(following.notifier).open();
      expect(container.read(following).seasons, isEmpty);
      expect(await container.read(vodWatchLaterProvider.future), isEmpty);
      // The nav read happened; the lists themselves were never asked.
      expect(stub.seen.map((request) => request.url.path), ['/x/web-interface/nav']);
    });

    test('the signed-in reads carry the viewer own id and pages', () async {
      final stub = _RouteStub()
        ..routes['/x/web-interface/nav'] = jsonEncode({
          'code': 0,
          'data': {'isLogin': true, 'mid': 42, 'uname': '甲', 'face': ''},
        });
      final container = containerOver(stub, cookie: 'SESSDATA=abc; bili_jct=t');
      addTearDown(container.dispose);

      stub.routes['/x/v2/history/toview'] = jsonEncode({
        'code': 0,
        'data': {
          'list': [
            {'bvid': 'BV1aaaaaaaaa', 'title': '稍后再看一'},
            {'title': '没有 bvid'},
          ],
        },
      });
      final watchLater = await container.read(vodWatchLaterProvider.future);
      expect(watchLater.single.id, 'BV1aaaaaaaaa'); // the bad row stays out

      final following = vodFollowingProvider(1);
      container.listen(following, (_, _) {});
      final controller = container.read(following.notifier);
      stub.routes['/x/space/bangumi/follow/list'] = jsonEncode({
        'code': 0,
        'data': {
          'list': [
            {'season_id': 5, 'title': '追的番'},
          ],
          'total': 21,
        },
      });
      await controller.open();
      var bangumi = container.read(following);
      expect(bangumi.seasons.single.title, '追的番');
      expect(bangumi.hasMore, isTrue); // 1 * 20 < 21
      var asked = stub.seen.last.url.queryParameters;
      expect(asked['vmid'], '42'); // the viewer's own mid, never a guess
      expect(asked['type'], '1');

      stub.routes['/x/space/bangumi/follow/list'] = jsonEncode({
        'code': 0,
        'data': {
          'list': [
            {'season_id': 5, 'title': '追的番'},
            {'season_id': 6, 'title': '第二页的番'},
          ],
          'total': 21,
        },
      });
      await controller.loadMore();
      bangumi = container.read(following);
      expect(bangumi.seasons.map((season) => season.seasonId), [5, 6]);
      expect(bangumi.nextPage, 3);
      expect(bangumi.hasMore, isFalse); // 2 * 20 >= 21
      asked = stub.seen.last.url.queryParameters;
      expect(asked['pn'], '2');

      // The cinema shelf asks its own type.
      final cinema = vodFollowingProvider(2);
      container.listen(cinema, (_, _) {});
      await container.read(cinema.notifier).open();
      expect(stub.seen.last.url.queryParameters['type'], '2');
    });
  });
}

/// A transport answering by exact path, with one route holdable.
final class _RouteStub implements LiveHttp {
  final Map<String, String> routes = {};
  final List<LiveRequest> seen = [];
  final Map<String, Completer<String>> _gates = {};

  void hold(String path, Completer<String> gate) => _gates[path] = gate;

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    seen.add(request);
    final body = routes[request.url.path];
    if (body == null) throw StateError('no answer for ${request.url.path}');
    final gate = _gates[request.url.path];
    final answer = gate == null ? body : await gate.future;
    return LiveResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      bodyBytes: Uint8List.fromList(utf8.encode(answer)),
    );
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnsupportedError('the client buffers');

  @override
  void close() {}
}
