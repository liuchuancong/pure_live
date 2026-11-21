import 'dart:convert' show jsonDecode, jsonEncode, utf8;
import 'dart:typed_data' show Uint8List;

import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart';
import 'package:pure_live/modules/hongguo/official/hongguo_account.dart' show HongguoCredentials;
import 'package:pure_live/modules/hongguo/official/hongguo_home_feed.dart';

/// The home feed, argued over a stubbed platform: the bookmall tab walks
/// its nested cards with the session cursor (offset by one each page), the
/// category shelf signs its POST and rides the server's next_offset, a
/// signed-in feed personalizes the query and carries the cookie, and every
/// refusal — a bad code, an empty answer, a broken session mark, a stale
/// run of repeats — fails with its own plain words.
void main() {
  Map<String, Object?> row(String id, String title, {String? cover, String? intro, int episodes = 12}) => {
    'series_id': id,
    'series_title': title,
    'series_cover': cover ?? 'https://cdn.example/$id.jpg',
    'series_intro': intro ?? '简介$id',
    'episode_cnt': episodes,
  };

  String mallPage({required String session, required List<Map<String, Object?>> videos, int code = 0}) => jsonEncode({
    'code': code,
    'data': {
      'tab_item': [
        {'tab_type': '2', 'cell_data': <Object?>[]},
        {
          'tab_type': '16',
          'session_id': session,
          'cell_data': [
            {
              'cell_data': [
                {'video_data': videos},
              ],
            },
            {'cell_data': <Object?>[]}, // an empty group among the cards
          ],
        },
      ],
    },
  });

  String landpage({required List<Map<String, Object?>> videos, String session = 'cat-1', int nextOffset = 5}) =>
      jsonEncode({
        'code': 0,
        'data': {'video_data': videos, 'session_id': session, 'next_offset': nextOffset},
      });

  Map<String, Object?> bodyOf(LiveRequest request) =>
      jsonDecode(utf8.decode(request.bodyBytes!)) as Map<String, Object?>;

  group('the bookmall walk', () {
    test('the nested cards land as series, the bad rows stay out', () async {
      final stub = _FeedStub()
        ..route(
          'bookmall/tab',
          mallPage(
            session: 'sess-1',
            videos: [
              {'video_detail': row('7100001', '第一剧')}, // the detail the player wants
              row('7100002', '裸行剧'), // no detail wrapper: the row itself
              {'video_detail': row('7100003', '另一组')}, // a second card group's row
            ],
          ),
        );
      final feed = HongguoHomeFeed(http: stub);

      final items = await feed.page(null);
      expect(items.map((series) => series.seriesId), ['7100001', '7100002', '7100003']);
      expect(items.first.title, '第一剧');
      expect(items.first.episodeCount, 12);

      final request = stub.calls.single;
      expect(request.url.queryParameters['offset'], '0');
      expect(request.url.queryParameters['client_req_type'], '1'); // a first ask
      expect(request.url.queryParameters.containsKey('session_id'), isFalse); // no session yet
      expect(request.method, 'GET');
    });

    test('the row shapes collapse to one series: aliases, slashes and the filters', () async {
      final stub = _FeedStub()
        ..route(
          'bookmall/tab',
          mallPage(
            session: 'sess-1',
            videos: [
              {'series_id': '7100002', 'book_name': '书名剧', 'video_desc': '简介书', 'cover': 'https://cdn.example/b.jpg'},
              row('abc', '字母id'), // a series id is a number
              row('7100003', '  '), // a blank says nothing
              {'video_detail': row('7100004', '详情剧', cover: r'https:\/\/cdn.example\/d.jpg')},
              row('7100001', '第一剧'), // the same id twice: one card
            ],
          ),
        );
      final feed = HongguoHomeFeed(http: stub);

      final items = await feed.page(null);
      expect(items.map((series) => series.seriesId), ['7100002', '7100004', '7100001']);
      expect(items[0].title, '书名剧'); // the book alias carried the name
      expect(items[0].intro, '简介书');
      expect(items[1].cover, 'https://cdn.example/d.jpg'); // the escaped slashes came back
    });

    test('the second page rides the session and its own client type', () async {
      final stub = _FeedStub()..route('bookmall/tab', mallPage(session: 'sess-1', videos: [row('7100001', '第一剧')]));
      final feed = HongguoHomeFeed(http: stub);
      await feed.page(null);

      stub.route('bookmall/tab', mallPage(session: 'sess-2', videos: [row('7100009', '第二页')]));
      final second = await feed.page(null);
      expect(second.single.seriesId, '7100009');
      final request = stub.calls.last;
      expect(request.url.queryParameters['offset'], '1'); // the mall walks by one
      expect(request.url.queryParameters['client_req_type'], '2');
      expect(request.url.queryParameters['session_id'], 'sess-1'); // the ask carried the old session
    });

    test('a crowded batch keeps thirty', () async {
      final videos = [for (var i = 1; i <= 31; i++) row('72${i.toString().padLeft(4, '0')}', '第$i剧')];
      final stub = _FeedStub()..route('bookmall/tab', mallPage(session: 'sess-1', videos: videos));
      final feed = HongguoHomeFeed(http: stub);

      final items = await feed.page(null);
      expect(items, hasLength(30));
    });
  });

  group('the category walk', () {
    test('the shelf signs its post and rides the next offset', () async {
      final stub = _FeedStub()..route('landpage', landpage(videos: [row('7300001', '分类剧')]));
      final feed = HongguoHomeFeed(http: stub);

      final items = await feed.page(HongguoGenre.shortPlay);
      expect(items.single.seriesId, '7300001');

      final request = stub.calls.single;
      expect(request.method, 'POST');
      expect(request.url.path, contains('landpage'));
      expect(request.headers.containsKey('x-gorgon'), isTrue); // the signature flew
      expect(request.url.queryParameters.containsKey('offset'), isFalse); // the offset lives in the body
      expect(request.url.queryParameters.containsKey('tab_type'), isFalse);
      expect(request.url.queryParameters['aid'], '8662');
      final body = bodyOf(request);
      expect(body['req_scene'], 'default');
      expect(body['offset'], 0);
      expect(body['limit'], 24);
      expect(body['session_id'], '');
      expect(body['filter_ids'], '');
      expect((body['select_items']! as Map<String, Object?>)['genre'], ['short_play']);

      // The second page takes the server's offset, the session and the seen ids.
      stub.route('landpage', landpage(videos: [row('7300002', '第二页')], session: 'cat-2', nextOffset: 9));
      await feed.page(HongguoGenre.shortPlay);
      final second = bodyOf(stub.calls.last);
      expect(second['offset'], 5);
      expect(second['session_id'], 'cat-1');
      expect(second['filter_ids'], '7300001');
      expect(stub.calls.last.url.queryParameters.containsKey('session_id'), isFalse);
    });

    test('the comic shelf names its own scene', () async {
      final stub = _FeedStub()..route('landpage', landpage(videos: [row('7400001', '漫剧')], nextOffset: 3));
      final feed = HongguoHomeFeed(http: stub);

      await feed.page(HongguoGenre.comicSeries);
      expect(bodyOf(stub.calls.single)['req_scene'], 'comic_series');
    });
  });

  group('the signed-in walk', () {
    test('the account personalizes the query and carries its cookie', () async {
      final stub = _FeedStub()..route('bookmall/tab', mallPage(session: 'sess-1', videos: [row('7100001', '第一剧')]));
      final feed = HongguoHomeFeed(
        http: stub,
        account: const HongguoCredentials(
          cookie: 'sessionid=abc; install_id=711999',
          deviceId: '710999',
          installId: '711999',
          device: {'channel': 'acc_channel', 'device_type': 'MiPhone', 'resolution': '1080*2400'},
        ),
      );

      await feed.page(null);
      final query = stub.calls.single.url.queryParameters;
      expect(query['channel'], 'acc_channel'); // the account's own channel
      expect(query['device_type'], 'MiPhone');
      expect(query['resolution'], '1080*2400');
      expect(query['device_id'], '710999');
      expect(query['iid'], '711999');
      expect(query['ssmix'], 'a'); // the unnamed fields keep the fingerprint
      expect(stub.calls.single.headers['Cookie'], 'sessionid=abc; install_id=711999');
    });

    test('a device with no channel drops the channel, and a blank cookie carries none', () async {
      final stub = _FeedStub()..route('bookmall/tab', mallPage(session: 'sess-1', videos: [row('7100001', '第一剧')]));
      final feed = HongguoHomeFeed(
        http: stub,
        account: const HongguoCredentials(cookie: '', deviceId: '710999'),
      );

      await feed.page(null);
      final request = stub.calls.single;
      expect(request.url.queryParameters.containsKey('channel'), isFalse); // the account's feed has no channel
      expect(request.headers.containsKey('Cookie'), isFalse); // a blank cookie stays off
    });
  });

  group('the refusals', () {
    Future<String> failing(_FeedStub stub) async {
      final feed = HongguoHomeFeed(http: stub);
      try {
        await feed.page(null);
        return 'no failure';
      } on HongguoHomeFeedFailure catch (error) {
        return error.message;
      }
    }

    test('each refusal names what went wrong', () async {
      expect(
        await failing(_FeedStub()..route('bookmall/tab', mallPage(session: 's', videos: const [], code: 7))),
        '推荐暂不可用（错误码 7），请稍后刷新',
      );
      expect(await failing(_FeedStub()..route('bookmall/tab', '   ')), '推荐接口返回空响应，请稍后重试');
      expect(
        await failing(_FeedStub()..route('bookmall/tab', 'not-json')),
        startsWith('推荐数据格式已变化（'),
      ); // a body that is not JSON says so in the feed's words
      expect(await failing(_FeedStub()..route('bookmall/tab', jsonEncode({'code': 0, 'data': 'flat'}))), '推荐数据格式已变化');
      expect(
        await failing(
          _FeedStub()..route(
            'bookmall/tab',
            jsonEncode({
              'code': 0,
              'data': {'tab_item': <Object?>[]},
            }),
          ),
        ),
        '推荐数据格式已变化',
      ); // no tab of the feed's own
      expect(
        await failing(
          _FeedStub()..route('bookmall/tab', mallPage(session: 'bad\nsession', videos: [row('7100001', '第一剧')])),
        ),
        '推荐分页标记无效',
      );
      expect(
        await failing(_FeedStub()..route('bookmall/tab', mallPage(session: 's', videos: [row('abc', '字母id')]))),
        '暂时没有新的推荐，请稍后换一批', // a batch of only bad rows keeps asking, then gives up
      );
      final down = _FeedStub()
        ..route('bookmall/tab', mallPage(session: 's', videos: const []))
        ..status = 503;
      expect(await failing(down), '推荐请求失败（HTTP 503）');
    });

    test('a batch of only bad rows keeps asking, and three in a row give up', () async {
      final stub = _FeedStub()
        ..route(
          'bookmall/tab',
          mallPage(
            session: 'sess-1',
            videos: [
              row('abc', '字母id'), // no row survives the filters: an empty batch
              row('7100003', '  '),
            ],
          ),
        );
      final feed = HongguoHomeFeed(http: stub);

      expect(feed.page(null), throwsA(_feed('暂时没有新的推荐，请稍后换一批')));
      await pumpEventQueue();
      expect(stub.calls, hasLength(3)); // three asks, then the honest giving up
    });

    test('two empty batches then a fresh one still answer', () async {
      final stub = _FeedStub()
        ..routeEach('bookmall/tab', [
          mallPage(session: 'sess-1', videos: [row('abc', '字母id')]),
          mallPage(session: 'sess-2', videos: [row('7100003', '  ')]),
          mallPage(session: 'sess-3', videos: [row('7100009', '第三批来了')]),
        ]);
      final feed = HongguoHomeFeed(http: stub);

      final items = await feed.page(null);
      expect(items.single.seriesId, '7100009');
      expect(stub.calls, hasLength(3));
      expect(stub.calls.last.url.queryParameters['offset'], '2'); // the empty asks walked too
    });
  });
}

Matcher _feed(String message) => isA<HongguoHomeFeedFailure>().having((error) => error.message, 'message', message);

/// The platform the feed's tests code against: routes by a path fragment,
/// remembers every ask, and answers with whatever status it was given.
final class _FeedStub implements LiveHttp {
  final Map<String, String> _routes = {};
  final Map<String, List<String>> _sequences = {};
  final calls = <LiveRequest>[];
  int status = 200;

  void route(String fragment, String body) => _routes[fragment] = body;

  /// Answers the fragment with the given bodies in order; the last one
  /// repeats once the queue runs dry.
  void routeEach(String fragment, List<String> bodies) {
    _routes[fragment] = bodies.last;
    _sequences[fragment] = bodies;
  }

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    calls.add(request);
    final entry = _routes.entries.firstWhere(
      (entry) => request.url.path.contains(entry.key),
      orElse: () => throw StateError('no answer for ${request.url.path}'),
    );
    final queue = _sequences[entry.key];
    final body = queue == null || queue.isEmpty ? entry.value : queue.removeAt(0);
    return LiveResponse(statusCode: status, headers: const {}, bodyBytes: Uint8List.fromList(utf8.encode(body)));
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnsupportedError('the feed buffers');

  @override
  void close() {}
}
