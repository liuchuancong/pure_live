import 'dart:async' show Completer;
import 'dart:convert' show jsonEncode, utf8;
import 'dart:typed_data' show Uint8List;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_social.dart';
import 'package:pure_live/modules/hongguo/official/hongguo_comments.dart' show HongguoCommentClient;
import 'package:pure_live/modules/hongguo/official/hongguo_related.dart' show HongguoRelatedClient;

/// The episode's comment list, the danmaku chain and the related works over
/// stubbed transports: the keyed swaps that never land a stale answer, the
/// paging by the server's cursor, the windows that chain by time, and the
/// series seat that never shows in its own related shelf.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageStores stores;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  tearDown(() => stores.close());

  /// One comment row as the endpoint spells it.
  Map<String, Object?> commentRow(String id, {String group = '7100002', int status = 1, String text = '好'}) => {
    'comment_id': id,
    'stat': {'digg_count': 3},
    'comment': {
      'common': {
        'group_id': group,
        'status': status,
        'content': {'text': text},
        'user_info': {
          'base_info': {'user_name': '甲', 'user_avatar': 'https://p3.example/a.jpg'},
        },
        'create_timestamp': 1700000000,
      },
      'expand': <String, Object?>{},
    },
  };

  String commentPage({required List<Map<String, Object?>> rows, required bool hasMore, String cursor = 'c2'}) =>
      jsonEncode({
        'code': 0,
        'data': {
          'common_list_info': {'has_more': hasMore, 'cursor': cursor, 'total': 50},
          'data_list': rows,
        },
      });

  group('the comment walk', () {
    test('opens, keeps the keyed order, pages, and drops the bad rows', () async {
      final stub = _RouteStub()
        ..routeFor('comment/list/7100002', (request) {
          final body = bodyOf(request);
          return body.contains('"cursor":"c1"')
              ? commentPage(rows: [commentRow('c9', text: '第二页')], hasMore: false)
              : commentPage(
                  rows: [
                    commentRow('c1'),
                    commentRow('c2', group: '7100009', text: '别的分集'),
                    commentRow('c3', status: 0, text: '被删'),
                    {
                      'comment_id': 'c4',
                      'comment': {
                        'common': {
                          'group_id': '7100002',
                          'status': 1,
                          'content': {'text': '无展开'},
                        },
                      },
                    },
                    commentRow('c1', text: '重复的 id'),
                    commentRow('c5', text: '  '),
                  ],
                  hasMore: true,
                  cursor: 'c1',
                );
        });
      final container = ProviderContainer(
        overrides: [hongguoCommentClientProvider.overrideWith((ref) => HongguoCommentClient(http: stub))],
      );
      addTearDown(container.dispose);
      container.listen(hongguoCommentsProvider, (_, _) {});
      final controller = container.read(hongguoCommentsProvider.notifier);

      await controller.open('7100001', '7100002');
      var page = container.read(hongguoCommentsProvider);
      expect(page.items.map((comment) => comment.id), ['c1']); // the bad rows never land
      expect(page.items.single.author, '甲');
      expect(page.items.single.likes, 3);
      expect(page.total, 50);
      expect(page.hasMore, isTrue);

      // The same pair again keeps its list without a re-ask.
      await controller.open('7100001', '7100002');
      expect(stub.seen, hasLength(1));

      // The next page rides the server's cursor.
      await controller.loadMore();
      page = container.read(hongguoCommentsProvider);
      expect(page.items.map((comment) => comment.id), ['c1', 'c9']);
      expect(page.hasMore, isFalse);
      expect(bodyOf(stub.seen.last), contains('"cursor":"c1"'));

      // The ended walk asks for nothing.
      await controller.loadMore();
      expect(stub.seen, hasLength(2));
    });

    test('a keyed swap lands the newer pair, not the older ask', () async {
      final gate = Completer<String>();
      final stub = _RouteStub()
        ..hold('comment/list/7100001', gate)
        ..routeFor(
          'comment/list/7100001',
          (request) => commentPage(
            rows: [commentRow('old', group: '7100001', text: '迟到的旧页')],
            hasMore: false,
          ),
        )
        ..routeFor(
          'comment/list/7100003',
          (request) => commentPage(
            rows: [commentRow('new', group: '7100003', text: '新页')],
            hasMore: false,
          ),
        );
      final container = ProviderContainer(
        overrides: [hongguoCommentClientProvider.overrideWith((ref) => HongguoCommentClient(http: stub))],
      );
      addTearDown(container.dispose);
      container.listen(hongguoCommentsProvider, (_, _) {});
      final controller = container.read(hongguoCommentsProvider.notifier);

      // The first pair's read is under way when the viewer opens another.
      final first = controller.open('7100001', '7100001');
      await pumpEventQueue();
      await controller.open('7100001', '7100003');
      var page = container.read(hongguoCommentsProvider);
      expect(page.items.single.id, 'new');

      // The stalled answer lands now; it must not join the new pair's page.
      gate.complete(commentPage(rows: [commentRow('old', group: '7100001')], hasMore: false));
      await first;
      await pumpEventQueue();
      page = container.read(hongguoCommentsProvider);
      expect(page.items.single.id, 'new');
    });

    test('a failure names itself and the retry reads the held pair', () async {
      final stub = _RouteStub()..routeFor('comment/list/7100004', (request) => '{"code":403,"message":"拒绝"}');
      final container = ProviderContainer(
        overrides: [hongguoCommentClientProvider.overrideWith((ref) => HongguoCommentClient(http: stub))],
      );
      addTearDown(container.dispose);
      container.listen(hongguoCommentsProvider, (_, _) {});
      final controller = container.read(hongguoCommentsProvider.notifier);

      await controller.open('7100001', '7100004');
      var page = container.read(hongguoCommentsProvider);
      expect(page.error, isNotNull);
      expect(page.hasMore, isFalse);

      stub.routeFor(
        'comment/list/7100004',
        (request) => commentPage(
          rows: [commentRow('c7', group: '7100004', text: '恢复')],
          hasMore: false,
        ),
      );
      await controller.retry();
      page = container.read(hongguoCommentsProvider);
      expect(page.error, isNull);
      expect(page.items.single.id, 'c7');
    });
  });

  group('the danmaku chain', () {
    test('the first window lands ordered, the view slices it, and stop clears', () async {
      final stub = _RouteStub()
        ..routeFor('comment/list/7100002', (request) {
          final body = bodyOf(request);
          if (!body.contains('"comment_type":20')) {
            return commentPage(rows: [], hasMore: false); // not a danmaku ask
          }
          return jsonEncode({
            'code': 0,
            'data': {
              'extra': {'next_query_danmaku_list_time': 60000},
              'data_list': [
                {
                  'comment': {
                    'comment_id': 'd2',
                    'common': {
                      'group_id': '7100002',
                      'status': 1,
                      'content': {'text': '稍后'},
                    },
                    'expand': {'offset_time': 30000},
                  },
                },
                {
                  'comment': {
                    'comment_id': 'd1',
                    'common': {
                      'group_id': '7100002',
                      'status': 1,
                      'content': {'text': '开场'},
                    },
                    'expand': {'offset_time': 1000},
                  },
                },
                {
                  'comment': {
                    'comment_id': 'd3',
                    'common': {
                      'group_id': '7100002',
                      'status': 1,
                      'content': {'text': '窗外'},
                    },
                    'expand': {'offset_time': 60001},
                  },
                },
                {
                  'comment': {
                    'comment_id': 'd4',
                    'common': {
                      'group_id': '7100002',
                      'status': 1,
                      'content': {'text': '负窗'},
                    },
                    'expand': {'offset_time': -1},
                  },
                },
              ],
            },
          });
        });
      final container = ProviderContainer(
        overrides: [hongguoCommentClientProvider.overrideWith((ref) => HongguoCommentClient(http: stub))],
      );
      addTearDown(container.dispose);
      container.listen(hongguoDanmakuProvider, (_, _) {});
      final controller = container.read(hongguoDanmakuProvider.notifier)..start('7100001', '7100002', 300000, () => 0);
      await pumpEventQueue();
      var chain = container.read(hongguoDanmakuProvider);
      expect(chain.items.map((item) => item.$2), ['开场', '稍后']); // time-ordered
      expect(chain.nextMs, 60000); // the window advanced
      expect(chain.error, isNull);
      expect(chain.between(0, 30000).single.$2, '开场'); // the slice is half-open

      // The same chain asked again does not tear down or re-fetch.
      controller.start('7100001', '7100002', 300000, () => 0);
      expect(stub.seen, hasLength(1));
      expect(container.read(hongguoDanmakuProvider).items, hasLength(2));

      controller.stop();
      chain = container.read(hongguoDanmakuProvider);
      expect(chain.items, isEmpty);
      expect(chain.nextMs, 0);
    });

    test('a failed window keeps the cursor where it was', () async {
      final stub = _RouteStub()..routeFor('comment/list/7100003', (request) => '{"code":500,"message":"挂了"}');
      final container = ProviderContainer(
        overrides: [hongguoCommentClientProvider.overrideWith((ref) => HongguoCommentClient(http: stub))],
      );
      addTearDown(container.dispose);
      container.listen(hongguoDanmakuProvider, (_, _) {});
      container.read(hongguoDanmakuProvider.notifier).start('7100001', '7100003', 300000, () => 0);
      await pumpEventQueue();
      final chain = container.read(hongguoDanmakuProvider);
      expect(chain.error, isNotNull);
      expect(chain.nextMs, 0); // the same window will be asked again
      expect(chain.items, isEmpty);
    });
  });

  group('the related shelf', () {
    test('the current series never shows, and the rows keep their seasons', () async {
      final stub = _RouteStub()
        ..routeFor(
          'bookapi/plan',
          (request) => jsonEncode({
            'code': 0,
            'data': [
              {
                'show_type': 547,
                'cell_name': '相关作品',
                'video_data': [
                  {
                    'series_id': '7100003',
                    'title': '第二季',
                    'content_type': 1004,
                    'episode_cnt': 20,
                    'tag_info': {'text': '第2季'},
                  },
                  {'series_id': '7100004', 'title': '待上线', 'content_type': 1007},
                  {'series_id': '7100001', 'title': '当前剧自己', 'content_type': 1004, 'episode_cnt': 10},
                  {'series_id': '7100005', 'title': '零集', 'content_type': 1004, 'episode_cnt': 0},
                  {'series_id': 'bad_id', 'title': '坏行', 'content_type': 1004, 'episode_cnt': 5},
                ],
              },
              {
                'show_type': 1,
                'cell_name': '别的栏目',
                'video_data': [
                  {'series_id': '7100006', 'title': '别的栏目行', 'content_type': 1004, 'episode_cnt': 3},
                ],
              },
            ],
          }),
        );
      final container = ProviderContainer(
        overrides: [hongguoRelatedClientProvider.overrideWith((ref) => HongguoRelatedClient(http: stub))],
      );
      addTearDown(container.dispose);
      container.listen(hongguoRelatedProvider, (_, _) {});
      final controller = container.read(hongguoRelatedProvider.notifier);

      await controller.open('7100001');
      final shelf = container.read(hongguoRelatedProvider);
      expect(shelf.items.map((work) => work.series.title), ['第二季', '待上线']); // self, empty and bad rows stay out
      expect(shelf.items.first.season, '第2季');
      expect(shelf.items.last.upcoming, isTrue); // the 1007 type is the waiting one
      expect(shelf.error, isNull);

      // The held series keeps its shelf; nothing re-asks.
      await controller.open('7100001');
      expect(stub.seen, hasLength(1));
    });
  });
}

/// The ask's JSON body, read out of the request.
String bodyOf(LiveRequest request) =>
    request.body ?? utf8.decode(request.bodyBytes ?? Uint8List.fromList(const []), allowMalformed: true);

/// A transport answering by route fragment, each route free to read the ask.
final class _RouteStub implements LiveHttp {
  final Map<String, String Function(LiveRequest)> _routes = {};
  final List<LiveRequest> seen = [];
  final Map<String, Completer<String>> _gates = {};

  void routeFor(String fragment, String Function(LiveRequest) answer) => _routes[fragment] = answer;

  void hold(String fragment, Completer<String> gate) => _gates[fragment] = gate;

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
