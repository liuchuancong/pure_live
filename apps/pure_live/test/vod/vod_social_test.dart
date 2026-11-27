import 'dart:async' show Completer;
import 'dart:convert' show jsonEncode, utf8;
import 'dart:typed_data' show Uint8List;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:live_storage/live_storage.dart';
import 'package:live_vod/live_vod.dart' show BilibiliVodClient, VodFailure;
import 'package:pure_live/modules/vod/controller/vod_controller.dart' show vodClientProvider;
import 'package:pure_live/modules/vod/controller/vod_social.dart';

/// The viewer's verdicts and pages over a stubbed transport: the like and
/// follow chips' optimistic flips (and the stale read that must not revert
/// them), the rollback when the endpoint refuses, and the comment walk's
/// paging, dedup end, sort switch and retry.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageStores stores;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  tearDown(() => stores.close());

  /// The signed-in cookie the write endpoints take (`bili_jct`).
  ProviderContainer signedIn(_RouteStub stub) => ProviderContainer(
    overrides: [
      vodClientProvider.overrideWith((ref) => BilibiliVodClient(stub, cookie: 'SESSDATA=abc123; bili_jct=token456')),
    ],
  );

  group('the like chip', () {
    test('a guest stays read-only and asks nothing', () async {
      final stub = _RouteStub();
      final container = ProviderContainer(
        overrides: [vodClientProvider.overrideWith((ref) => BilibiliVodClient(stub, cookie: 'SESSDATA=abc'))],
      );
      addTearDown(container.dispose);
      container.listen(vodLikeProvider(5), (_, _) {});

      expect(container.read(vodLikeProvider(5)), isNull);
      await pumpEventQueue();
      expect(stub.seen, isEmpty); // no read, no write: the row keeps its door
    });

    test('a second tap waits for the in-flight write instead of racing it', () async {
      final stub = _RouteStub()
        ..routes['/x/web-interface/archive/has/like'] = '{"code":0,"data":[0]}'
        ..routes['/x/web-interface/archive/like'] = '{"code":0}';
      final gate = Completer<String>();
      stub.hold('/x/web-interface/archive/like', gate);
      final container = signedIn(stub);
      addTearDown(container.dispose);
      container.listen(vodLikeProvider(5), (_, _) {});
      await pumpEventQueue();
      final controller = container.read(vodLikeProvider(5).notifier);

      final first = controller.toggle();
      await controller.toggle();
      final writes = stub.seen.where((request) => request.url.path == '/x/web-interface/archive/like');
      expect(writes, hasLength(1));
      expect(container.read(vodLikeProvider(5)), isTrue);

      gate.complete('{"code":0}');
      await first;
      expect(container.read(vodLikeProvider(5)), isTrue);
    });

    test('the verdict reads, flips optimistically, and rolls back on a refusal', () async {
      final stub = _RouteStub()..routes['/x/web-interface/archive/has/like'] = '{"code":0,"data":[1]}';
      stub.routes['/x/web-interface/archive/like'] = '{"code":0}';
      final container = signedIn(stub);
      addTearDown(container.dispose);
      container.listen(vodLikeProvider(5), (_, _) {});

      await pumpEventQueue();
      expect(container.read(vodLikeProvider(5)), isTrue); // the stored like

      await container.read(vodLikeProvider(5).notifier).toggle();
      expect(container.read(vodLikeProvider(5)), isFalse);
      final unLike = stub.seen.where((request) => request.url.path == '/x/web-interface/archive/like').last;
      expect(Uri.splitQueryString(unLike.body!)['like'], '2'); // unlike takes 2
      expect(Uri.splitQueryString(unLike.body!)['csrf'], 'token456');

      await container.read(vodLikeProvider(5).notifier).toggle();
      expect(container.read(vodLikeProvider(5)), isTrue);
      final reLike = stub.seen.where((request) => request.url.path == '/x/web-interface/archive/like').last;
      expect(Uri.splitQueryString(reLike.body!)['like'], '1');

      // The endpoint refuses: the flip comes back and the failure rethrows.
      stub.routes['/x/web-interface/archive/like'] = '{"code":-101,"message":"账号未登录"}';
      await expectLater(container.read(vodLikeProvider(5).notifier).toggle(), throwsA(isA<VodFailure>()));
      expect(container.read(vodLikeProvider(5)), isTrue); // where it stood
    });
  });

  group('the follow chip', () {
    test('a second tap waits for the in-flight write instead of racing it', () async {
      final stub = _RouteStub()
        ..routes['/x/relation'] = '{"code":0,"data":{"attribute":0}}'
        ..routes['/x/relation/modify'] = '{"code":0}';
      final gate = Completer<String>();
      stub.hold('/x/relation/modify', gate);
      final container = signedIn(stub);
      addTearDown(container.dispose);
      container.listen(vodFollowUpProvider(7), (_, _) {});
      await pumpEventQueue();
      final controller = container.read(vodFollowUpProvider(7).notifier);

      final first = controller.toggle();
      await controller.toggle();
      final writes = stub.seen.where((request) => request.url.path == '/x/relation/modify');
      expect(writes, hasLength(1));
      expect(container.read(vodFollowUpProvider(7)), isTrue);

      gate.complete('{"code":0}');
      await first;
      expect(container.read(vodFollowUpProvider(7)), isTrue);
    });

    test('a stale read failure does not erase the flip', () async {
      final stub = _RouteStub();
      final gate = Completer<String>();
      stub.hold('/x/relation', gate);
      stub.routes['/x/relation/modify'] = '{"code":0}';
      final container = signedIn(stub);
      addTearDown(container.dispose);
      container.listen(vodFollowUpProvider(7), (_, _) {});

      final controller = container.read(vodFollowUpProvider(7).notifier);
      await controller.toggle();
      expect(container.read(vodFollowUpProvider(7)), isTrue);

      gate.complete('not json');
      await pumpEventQueue();
      expect(container.read(vodFollowUpProvider(7)), isTrue);
    });

    test('a stale read does not revert the flip', () async {
      final stub = _RouteStub();
      final gate = Completer<String>();
      stub.hold('/x/relation', gate);
      // The answer the stalled read carries once released: not following.
      stub.routes['/x/relation'] = '{"code":0,"data":{"attribute":0}}';
      stub.routes['/x/relation/modify'] = '{"code":0}';
      final container = signedIn(stub);
      addTearDown(container.dispose);
      container.listen(vodFollowUpProvider(7), (_, _) {});

      // The verdict's read is under way when the viewer flips.
      final controller = container.read(vodFollowUpProvider(7).notifier);
      await pumpEventQueue();
      expect(container.read(vodFollowUpProvider(7)), isNull);

      await controller.toggle();
      expect(container.read(vodFollowUpProvider(7)), isTrue);
      final follow = stub.seen.where((request) => request.url.path == '/x/relation/modify').single;
      expect(Uri.splitQueryString(follow.body!)['act'], '1');
      expect(Uri.splitQueryString(follow.body!)['re_src'], '11');

      // The stalled answer lands now — attribute 0, not following. It must
      // not overwrite what the viewer just chose.
      gate.complete('{"code":0,"data":{"attribute":0}}');
      await pumpEventQueue();
      expect(container.read(vodFollowUpProvider(7)), isTrue);

      // The un-follow still speaks its own verb.
      await controller.toggle();
      expect(container.read(vodFollowUpProvider(7)), isFalse);
      final unfollow = stub.seen.where((request) => request.url.path == '/x/relation/modify').last;
      expect(Uri.splitQueryString(unfollow.body!)['act'], '2');
    });
  });

  group('the comment walk', () {
    test('opens, pages, ends where the duplicates begin, and sorts from the head', () async {
      final stub = _RouteStub();
      final container = signedIn(stub);
      addTearDown(container.dispose);
      container.listen(vodCommentsProvider, (_, _) {});
      final controller = container.read(vodCommentsProvider.notifier);

      stub.routes['/x/v2/reply'] = jsonReply(
        replies: [
          {
            'rpid': 1,
            'member': {'uname': '甲'},
            'content': {'message': '前排'},
            'ctime': 1700000000,
            'like': 3,
          },
          {
            'rpid': 2,
            'member': {'uname': '乙'},
            'content': {'message': '同看'},
            'ctime': 1700000001,
          },
          {
            'member': {'uname': '无名'},
            'content': {'message': '没有 rpid'},
          },
        ],
        count: 100,
      );

      await controller.open(9);
      var page = controller.of(9);
      expect(page.comments.map((comment) => comment.id), [1, 2]); // the bad row stays out
      expect(page.total, 100);
      expect(page.hasMore, isTrue); // 1 * 20 < 100
      expect(page.sort, 1);
      expect(stub.seen.single.url.queryParameters['sort'], '1');

      // open again asks nothing: the page is here.
      await controller.open(9);
      expect(stub.seen.length, 1);

      // The second block adds its own rows.
      stub.routes['/x/v2/reply'] = jsonReply(
        replies: [
          {
            'rpid': 3,
            'member': {'uname': '丙'},
            'content': {'message': '三楼'},
          },
        ],
        count: 100,
      );
      await controller.loadMore(9);
      page = controller.of(9);
      expect(page.comments.map((comment) => comment.id), [1, 2, 3]);
      expect(page.nextPage, 3);
      expect(stub.seen.last.url.queryParameters['pn'], '2');

      // A block of nothing new ends the walk instead of walking in place.
      stub.routes['/x/v2/reply'] = jsonReply(
        replies: [
          {
            'rpid': 1,
            'member': {'uname': '甲'},
            'content': {'message': '前排'},
          },
        ],
        count: 100,
      );
      await controller.loadMore(9);
      page = controller.of(9);
      expect(page.comments, hasLength(3));
      expect(page.hasMore, isFalse);
      await controller.loadMore(9); // the ended walk asks for nothing
      expect(stub.seen.length, 3);

      // The sort switch reads from the head in the new order.
      stub.routes['/x/v2/reply'] = jsonReply(
        replies: [
          {
            'rpid': 9,
            'member': {'uname': '新'},
            'content': {'message': '最新'},
          },
        ],
        count: 1,
      );
      await controller.setSort(9, VodCommentsController.sortNewest);
      page = controller.of(9);
      expect(page.sort, 2);
      expect(page.comments.single.id, 9);
      expect(stub.seen.last.url.queryParameters['sort'], '2');

      // The same sort again asks nothing.
      await controller.setSort(9, VodCommentsController.sortNewest);
      expect(stub.seen.length, 4);
    });

    test('a failure names itself and the retry reads the failed page', () async {
      final stub = _RouteStub()..routes['/x/v2/reply'] = '{"code":-404,"message":"啥都木有"}';
      final container = signedIn(stub);
      addTearDown(container.dispose);
      container.listen(vodCommentsProvider, (_, _) {});
      final controller = container.read(vodCommentsProvider.notifier);

      await controller.open(3);
      var page = controller.of(3);
      expect(page.error, isNotNull);
      expect(page.hasMore, isTrue);
      expect(page.loading, isFalse);

      stub.routes['/x/v2/reply'] = jsonReply(
        replies: [
          {
            'rpid': 4,
            'member': {'uname': '丁'},
            'content': {'message': '来了'},
          },
        ],
        count: 1,
      );
      await controller.retry(3);
      page = controller.of(3);
      expect(page.error, isNull);
      expect(page.comments.single.id, 4);
      expect(stub.seen.last.url.queryParameters['pn'], '1');
    });

    test('a failed later page retries itself and keeps earlier comments', () async {
      final stub = _RouteStub();
      var secondAttempts = 0;
      stub.handlers['/x/v2/reply'] = (request) {
        final page = int.parse(request.url.queryParameters['pn'] ?? '1');
        if (page == 2 && ++secondAttempts == 1) return '{"code":-404,"message":"第二页故障"}';
        return jsonReply(
          replies: [
            {
              'rpid': page,
              'member': {'uname': '第$page页'},
              'content': {'message': '评论$page'},
            },
          ],
          count: 100,
        );
      };
      final container = signedIn(stub);
      addTearDown(container.dispose);
      container.listen(vodCommentsProvider, (_, _) {});
      final controller = container.read(vodCommentsProvider.notifier);

      await controller.open(9);
      await controller.loadMore(9);
      expect(controller.of(9).comments.map((comment) => comment.id), [1]);
      expect(controller.of(9).nextPage, 2);
      expect(controller.of(9).error, isNotNull);

      await controller.retry(9);
      expect(controller.of(9).comments.map((comment) => comment.id), [1, 2]);
      expect(controller.of(9).nextPage, 3);
      expect(controller.of(9).error, isNull);
      expect(secondAttempts, 2);
    });

    test('different videos finish their own in-flight reads', () async {
      final stub = _RouteStub();
      final gate = Completer<String>();
      stub.hold('/x/v2/reply', gate);
      stub.routes['/x/v2/reply'] = jsonReply(
        replies: [
          {
            'rpid': 8,
            'member': {'uname': '甲'},
            'content': {'message': '同一条接口'},
          },
        ],
        count: 1,
      );
      final container = signedIn(stub);
      addTearDown(container.dispose);
      container.listen(vodCommentsProvider, (_, _) {});
      final controller = container.read(vodCommentsProvider.notifier);

      final first = controller.open(9);
      final second = controller.open(10);
      await pumpEventQueue();
      gate.complete(stub.routes['/x/v2/reply']!);
      await Future.wait([first, second]);

      expect(controller.of(9).comments.single.id, 8);
      expect(controller.of(9).loading, isFalse);
      expect(controller.of(10).comments.single.id, 8);
      expect(controller.of(10).loading, isFalse);
    });

    test('an account change clears comments and drains the old response', () async {
      final stub = _RouteStub();
      final gate = Completer<String>();
      stub.hold('/x/v2/reply', gate);
      stub.routes['/x/v2/reply'] = jsonReply(
        replies: [
          {
            'rpid': 8,
            'member': {'uname': '旧账号'},
            'content': {'message': '旧评论'},
          },
        ],
        count: 1,
      );
      final container = ProviderContainer(
        overrides: [vodClientProvider.overrideWith((ref) => BilibiliVodClient(stub, cookie: 'SESSDATA=old'))],
      );
      addTearDown(container.dispose);
      container.listen(vodCommentsProvider, (_, _) {});
      final controller = container.read(vodCommentsProvider.notifier);
      final flying = controller.open(9);
      await pumpEventQueue();

      container
        ..updateOverrides([vodClientProvider.overrideWith((ref) => BilibiliVodClient(stub, cookie: 'SESSDATA=new'))])
        ..invalidate(vodCommentsProvider);
      await pumpEventQueue();
      expect(container.read(vodCommentsProvider), isEmpty);

      gate.complete(stub.routes['/x/v2/reply']!);
      await flying;
      await pumpEventQueue();
      expect(container.read(vodCommentsProvider), isEmpty);
    });
  });
}

/// The replies as the endpoint answers them.
String jsonReply({required List<Map<String, Object?>> replies, required int count}) =>
    '{"code":0,"data":{"replies":${jsonEncode(replies)},"page":{"count":$count}}}';

/// A transport answering by exact path, with one route holdable for the
/// stale-read race.
final class _RouteStub implements LiveHttp {
  final Map<String, String> routes = {};
  final Map<String, String Function(LiveRequest)> handlers = {};
  final List<LiveRequest> seen = [];
  final Map<String, Completer<String>> _gates = {};

  void hold(String path, Completer<String> gate) => _gates[path] = gate;

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    seen.add(request);
    final body = handlers[request.url.path]?.call(request) ?? routes[request.url.path];
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
