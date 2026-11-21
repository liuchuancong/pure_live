import 'dart:convert' show jsonDecode, jsonEncode, utf8;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:live_vod/live_vod.dart' show BilibiliVodClient;
import 'package:pure_live/app/logging/app_log.dart' show appLog;
import 'package:pure_live/modules/vod/controller/vod_controller.dart';

/// The station's signed walks — an uploader's space and the home
/// recommendation feed — argued over a stub transport: the keys the nav
/// answer carries sign the ask (a w_rid and a wts ride the query), a space
/// that is not a number asks nothing, another uploader starts the page
/// over, a repeat never lands twice, a failed page is the walk's own
/// error, and a nav answer without keys fails the signed ask plainly.
void main() {
  const navBody =
      '{"code":-101,"data":{"wbi_img":{'
      '"img_url":"https://i0.hdslb.com/bfs/wbi/11111111111111111111111111111111.png",'
      '"sub_url":"https://i0.hdslb.com/bfs/wbi/22222222222222222222222222222222.png"}}}';

  late _StubHttp http;

  setUp(() {
    http = _StubHttp()..route('web-interface/nav', _jsonFuture(jsonDecode(navBody) as Object));
  });

  Map<String, Object?> spaceRow(String bvid, String title) => {'bvid': bvid, 'title': title, 'length': '03:30'};

  ProviderContainer containerWith() {
    final client = BilibiliVodClient(http, cookie: 'SESSDATA=abc', log: appLog.forCategory('vod.api'));
    final container = ProviderContainer(overrides: [vodClientProvider.overrideWithValue(client)])
      ..listen(vodUploaderProvider, (_, _) {})
      ..listen(vodFeedProvider, (_, _) {});
    addTearDown(container.dispose);
    return container;
  }

  group('the uploader space', () {
    test('a space opens signed, and the signature rides the ask', () async {
      http.route('wbi/arc/search', (url) async {
        final rid = url.queryParameters['w_rid'] ?? '';
        expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(rid), isTrue, reason: 'w_rid=$rid'); // the signed mark
        expect(int.tryParse(url.queryParameters['wts'] ?? ''), isNotNull); // the stamp beside it
        expect(url.queryParameters['mid'], '977');
        return _ok(
          jsonEncode({
            'code': 0,
            'data': {
              'list': {
                'vlist': [spaceRow('BV1', '空间视频')],
              },
              'page': {'count': 88},
            },
          }),
        );
      });
      final container = containerWith();
      final notifier = container.read(vodUploaderProvider.notifier);

      await notifier.open('977');
      final state = container.read(vodUploaderProvider);
      expect(state.mid, '977');
      expect(state.videos.single.bvid, 'BV1');
      expect(state.total, 88);
      expect(state.hasMore, isTrue); // one page of thirty, eighty-eight held
      expect(http.calls.where((uri) => uri.path.contains('nav')), hasLength(1)); // the keys came once
    });

    test('a space that is not a number asks nothing', () async {
      final container = containerWith();
      final notifier = container.read(vodUploaderProvider.notifier);

      await notifier.open('not-a-mid');
      final state = container.read(vodUploaderProvider);
      expect(state.videos, isEmpty);
      expect(state.error, isNull);
      expect(http.calls, isEmpty); // a room number is not a uid; nothing flew
    });

    test('another uploader starts the page over', () async {
      http.route(
        'wbi/arc/search',
        (url) async => _ok(
          jsonEncode({
            'code': 0,
            'data': {
              'list': {
                'vlist': [spaceRow('BV${url.queryParameters['mid']}', '${url.queryParameters['mid']} 的视频')],
              },
              'total': 1,
            },
          }),
        ),
      );
      final container = containerWith();
      final notifier = container.read(vodUploaderProvider.notifier);

      await notifier.open('977');
      await notifier.open('888');
      final state = container.read(vodUploaderProvider);
      expect(state.mid, '888');
      expect(state.videos.single.bvid, 'BV888'); // the first space's rows are gone
    });

    test('a second page drops what the space already held', () async {
      var call = 0;
      http.route('wbi/arc/search', (url) async {
        call += 1;
        return _ok(
          jsonEncode({
            'code': 0,
            'data': {
              'list': {
                'vlist': [spaceRow('BV1', '第一条'), if (call > 1) spaceRow('BV2', '第二条')],
              },
              'page': {'count': 88},
            },
          }),
        );
      });
      final container = containerWith();
      final notifier = container.read(vodUploaderProvider.notifier);

      await notifier.open('977');
      expect(container.read(vodUploaderProvider).videos, hasLength(1));
      await notifier.loadMore();
      expect(container.read(vodUploaderProvider).videos.map((video) => video.bvid), ['BV1', 'BV2']);
    });

    test("a failed page lands as the walk's own error", () async {
      http.route('wbi/arc/search', (url) async => throw StateError('the space is down'));
      final container = containerWith();
      final notifier = container.read(vodUploaderProvider.notifier);

      await notifier.open('977');
      final state = container.read(vodUploaderProvider);
      expect(state.error, isNotNull);
      expect(state.hasMore, isFalse);
      expect(state.loading, isFalse);
    });
  });

  group('the recommendation feed', () {
    test('the feed signs its ask and answers non-empty pages as more', () async {
      http.route('wbi/index/top/feed/rcmd', (url) async {
        expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(url.queryParameters['w_rid'] ?? ''), isTrue);
        return _ok(
          jsonEncode({
            'code': 0,
            'data': {
              'item': [
                {'bvid': 'BVr1', 'title': '推荐一', 'author': 'UP主', 'duration': 100},
              ],
            },
          }),
        );
      });
      final container = containerWith();
      final notifier = container.read(vodFeedProvider.notifier);

      await notifier.open('recommend');
      final feed = container.read(vodFeedProvider.notifier).feedOf('recommend');
      expect(feed.videos.single.bvid, 'BVr1');
      expect(feed.hasMore, isTrue); // rows came back, so another draw is worth asking
    });

    test('a nav answer without keys fails the signed ask plainly', () async {
      http.route(
        'web-interface/nav',
        _jsonFuture(<String, Object?>{'code': 0, 'data': <String, Object?>{}}),
      ); // no wbi_img
      final container = containerWith();
      final notifier = container.read(vodFeedProvider.notifier);

      await notifier.open('recommend');
      final feed = container.read(vodFeedProvider.notifier).feedOf('recommend');
      expect(feed.error, isNotNull);
      expect(feed.videos, isEmpty);
      expect(feed.hasMore, isFalse);
    });
  });
}

Future<LiveResponse> Function(Uri) _jsonFuture(Object json) =>
    (url) async => _ok(jsonEncode(json));

LiveResponse _ok(String body) => LiveResponse(statusCode: 200, headers: const {}, bodyBytes: utf8.encode(body));

/// The transport the station's tests code against: routes by a path
/// fragment and remembers every ask.
final class _StubHttp implements LiveHttp {
  final calls = <Uri>[];
  final Map<String, Future<LiveResponse> Function(Uri url)> _routes = {};

  /// Answers every call whose path carries [fragment] with [answer].
  void route(String fragment, Future<LiveResponse> Function(Uri url) answer) => _routes[fragment] = answer;

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    calls.add(request.url);
    for (final route in _routes.entries) {
      if (request.url.path.contains(route.key)) return await route.value(request.url);
    }
    throw StateError('the stub holds no answer for ${request.url.path}');
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}
}
