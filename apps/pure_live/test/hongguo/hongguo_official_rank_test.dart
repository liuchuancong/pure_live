import 'dart:convert' show jsonEncode, utf8;
import 'dart:typed_data' show Uint8List;

import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:pure_live/modules/hongguo/official/hongguo_official.dart'
    show HongguoOfficialClient, HongguoOfficialFailure, HongguoWebsiteBoard;

/// The public page's own data, read as data: the router blob's balanced
/// extraction and the words it says when the page has none, the registry
/// key a pointer names, the board payload's two wrappings (the inline `p`
/// and the pointer into the `r` registry), the rows a board maps and the
/// ones it skips, and the whole-board read's guards.
void main() {
  group('the router blob', () {
    test('the balanced braces come out whole, quotes and all', () {
      const html =
          r'''<html><body><script>window._ROUTER_DATA = {"loaderData":{"detail_page":{"seriesDetail":{"series_name":"剧{name}","quote":"he said \"hi\"","n":1}}}};</script>''';
      final router = HongguoOfficialClient.extractRouter(html);
      final detail = router['loaderData']! as Map<String, Object?>;
      final page = detail['detail_page']! as Map<String, Object?>;
      final series = page['seriesDetail']! as Map<String, Object?>;
      expect(series['series_name'], '剧{name}'); // braces inside a string are not depth
      expect(series['quote'], 'he said "hi"'); // an escaped quote does not close the string
    });

    test('a page without the data says so, in its own words', () {
      expect(
        () => HongguoOfficialClient.extractRouter('<html>nothing here</html>'),
        throwsA(isA<HongguoOfficialFailure>().having((e) => e.message, 'message', '页面没有内容数据')),
      );
    });

    test('a marker without a blob is a format, not an absence', () {
      expect(
        () => HongguoOfficialClient.extractRouter('<script>window._ROUTER_DATA = oops;</script>'),
        throwsA(isA<HongguoOfficialFailure>().having((e) => e.message, 'message', '页面数据格式错误')),
      );
    });

    test('a blob that never closes is incomplete', () {
      expect(
        () => HongguoOfficialClient.extractRouter('<script>window._ROUTER_DATA = {"a":</script>'),
        throwsA(isA<HongguoOfficialFailure>().having((e) => e.message, 'message', '页面数据不完整')),
      );
    });

    test('a balanced blob that is not an object is refused', () {
      expect(
        () => HongguoOfficialClient.extractRouter('<script>window._ROUTER_DATA = [1,2];</script>'),
        throwsA(isA<HongguoOfficialFailure>().having((e) => e.message, 'message', '页面数据格式错误')),
      );
    });
  });

  group('the registry key', () {
    test('the pointer names its entry, quotes and escaped slashes off', () {
      expect(HongguoOfficialClient.namespacedLoaderKey('"content"'), 'content');
      expect(HongguoOfficialClient.namespacedLoaderKey(r'rank_hot-drama\/page'), 'rank_hot-drama/page');
      expect(HongguoOfficialClient.namespacedLoaderKey(null), '');
    });
  });

  group('the board payload', () {
    late _RouteStub stub;
    late HongguoOfficialClient client;

    Map<String, Object?> payload({
      bool success = true,
      Object? rankList = const [
        {
          'seriesId': '7100001',
          'title': '剧',
          'rank': 1,
          'heatText': '热度第一',
          'scoreText': '8.6',
          'favoriteText': '12.3万收藏',
          'likeText': '4.5万点赞',
          'episodeCount': 3,
          'tags': ['甜宠', '复仇', '逆袭', '古装', '悬疑', '第六个'],
          'statusTags': ['爆剧', '新剧', '  独播  '],
          'cover': 'https://img.example/a.jpg',
          'description': '简介',
        },
        {
          'id': '7100002',
          'title': '乙',
          'rank': 2,
          'episodeVids': ['1', '2', '3', '4'],
        },
        {'seriesId': 'no-number', 'title': '坏'},
        {'title': '无id'},
      ],
      int totalPages = 2,
    }) => {
      'isSuccess': success,
      'rankList': rankList,
      'pagination': {'totalPages': totalPages},
    };

    String page({required String shape, Object? withPayload}) {
      final boardPayload = withPayload is Map<String, Object?> ? withPayload : payload();
      final encoded = jsonEncode(boardPayload).replaceAll('"', '&quot;');
      final registryValue = jsonEncode(boardPayload).replaceAll('"', '&quot;');
      final inlineArgs = jsonEncode([
        'rank_hot-drama/page',
        [
          {
            'key': 'content',
            'routerDataFnName': 'p',
            'routerDataFnArgs': [boardPayload],
          },
        ],
      ]).replaceAll('"', '&quot;');
      final pointerArgs = jsonEncode([r'rank_hot-drama\/page', '"content"']).replaceAll('"', '&quot;');
      final registryArgs = jsonEncode(['rank_hot-drama/page', 'content', boardPayload]).replaceAll('"', '&quot;');
      return switch (shape) {
        'p' => '<html><script data-fn-name="mergeLoaderData" data-fn-args="$inlineArgs"></script></html>',
        's' =>
          '<html> <script data-fn-name="r" data-fn-args="$registryArgs"></script>'
              ' <script data-fn-name="mergeLoaderData" data-fn-args="$pointerArgs"></script></html>',
        _ => '<html>$encoded$registryValue</html>', // neither wrapping: no board here
      };
    }

    setUp(() {
      stub = _RouteStub();
      client = HongguoOfficialClient(http: stub);
    });

    test('the board page answers the inline wrapping', () async {
      stub.routeFor('rank/hot-drama', (request) => page(shape: 'p'));
      final answer = await client.websiteRank(HongguoWebsiteBoard.all);

      expect(answer.items, hasLength(2)); // the two rows a rank row can be read from
      expect(answer.totalPages, 2);
      expect(answer.hasMore, isTrue); // page one of two with titles on it
    });

    test('a continuation page answers the pointer wrapping', () async {
      stub.routeFor('rank/hot-drama', (request) => page(shape: 's'));
      final answer = await client.websiteRank(HongguoWebsiteBoard.all);
      expect(answer.items, hasLength(2)); // the registry carries the same payload
    });

    test('a page with neither wrapping has no board', () async {
      stub.routeFor('rank/hot-drama', (request) => page(shape: 'none'));
      expect(
        () => client.websiteRank(HongguoWebsiteBoard.all),
        throwsA(isA<HongguoOfficialFailure>().having((e) => e.message, 'message', '剧集榜单暂不可用')),
      );
    });

    test('the rows a board maps, and the ones it skips', () async {
      stub.routeFor('rank/hot-drama', (request) => page(shape: 'p'));
      final answer = await client.websiteRank(HongguoWebsiteBoard.all);
      final first = answer.items.first;

      expect(first.seriesId, '7100001');
      expect(first.rank, 1);
      expect(first.hot, '热度第一');
      expect(first.score, '8.6');
      expect(first.favoriteText, '12.3万收藏');
      expect(first.likeText, '4.5万点赞');
      expect(first.episodeCount, 3); // the count the row states
      expect(first.category, '甜宠 / 复仇 / 逆袭 / 古装 / 悬疑'); // five tags, no more
      expect(first.coverTags, ['爆剧', '新剧']); // two corner tags, trimmed
      expect(first.cover, 'https://img.example/a.jpg');
      expect(first.intro, '简介');

      final second = answer.items[1]; // id under its other name, count from its vids
      expect(second.seriesId, '7100002');
      expect(second.episodeCount, 4); // the vids' length, when no count is stated
      // the unnumbered id and the titleless row were skipped, not crashed on
    });

    test('a board the station refuses, in shape or in success', () async {
      stub.routeFor('rank/hot-drama', (request) => page(shape: 'p', withPayload: payload(success: false)));
      expect(
        () => client.websiteRank(HongguoWebsiteBoard.all),
        throwsA(isA<HongguoOfficialFailure>().having((e) => e.message, 'message', '剧集榜单暂不可用')),
      );

      final stub2 = _RouteStub()
        ..routeFor('rank/hot-drama', (request) {
          final bad = payload()..['rankList'] = 'junk';
          return page(shape: 'p', withPayload: bad);
        });
      final client2 = HongguoOfficialClient(http: stub2);
      expect(
        () => client2.websiteRank(HongguoWebsiteBoard.all),
        throwsA(isA<HongguoOfficialFailure>().having((e) => e.message, 'message', '剧集榜单格式已变化')),
      );
    });

    test('a board with no pagination has no walk', () async {
      stub.routeFor('rank/hot-drama', (request) {
        final bare = payload()..['pagination'] = null;
        return page(shape: 'p', withPayload: bare);
      });
      expect(
        () => client.websiteRank(HongguoWebsiteBoard.all),
        throwsA(isA<HongguoOfficialFailure>().having((e) => e.message, 'message', '剧集分页信息缺失')),
      );
    });

    test('the last page does not promise another', () async {
      stub.routeFor('rank/hot-drama', (request) => page(shape: 'p'));
      final answer = await client.websiteRank(HongguoWebsiteBoard.all, page: 2);
      expect(answer.hasMore, isFalse); // page two of two
    });

    test('the whole board reads page by page, and guards its own shape', () async {
      stub.routeFor('rank/hot-drama', (request) {
        final p = request.url.queryParameters['page'] ?? '1';
        return page(
          shape: 'p',
          withPayload: payload(
            rankList: [
              if (p == '1') const {'seriesId': '7100001', 'title': '剧'} else {'seriesId': '7100002', 'title': '乙'},
            ],
          ),
        );
      });
      final whole = await client.websiteRankSnapshot(HongguoWebsiteBoard.all);
      expect(whole.map((s) => s.seriesId), ['7100001', '7100002']); // both pages, in order
    });

    test("a board longer than the website's five pages is refused", () async {
      stub.routeFor('rank/hot-drama', (request) => page(shape: 'p', withPayload: payload(totalPages: 6)));
      expect(
        () => client.websiteRankSnapshot(HongguoWebsiteBoard.all),
        throwsA(isA<HongguoOfficialFailure>().having((e) => e.message, 'message', '榜单页数超出预期')),
      );
    });

    test('a page that answers nothing mid-walk stops the read', () async {
      stub.routeFor('rank/hot-drama', (request) {
        final p = request.url.queryParameters['page'] ?? '1';
        return page(
          shape: 'p',
          withPayload: payload(
            totalPages: 3,
            rankList: p == '2'
                ? const []
                : const [
                    {'seriesId': '7100001', 'title': '剧'},
                  ],
          ),
        );
      });
      expect(
        () => client.websiteRankSnapshot(HongguoWebsiteBoard.all),
        throwsA(isA<HongguoOfficialFailure>().having((e) => e.message, 'message', '榜单未读完整')),
      );
    });
  });
}

/// A transport answering by route fragment.
final class _RouteStub implements LiveHttp {
  final Map<String, String Function(LiveRequest)> _routes = {};

  void routeFor(String fragment, String Function(LiveRequest) answer) => _routes[fragment] = answer;

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    final entry = _routes.entries.firstWhere(
      (entry) => request.url.toString().contains(entry.key),
      orElse: () => throw StateError('no answer for ${request.url}'),
    );
    return LiveResponse(
      statusCode: 200,
      headers: const {'content-type': 'text/html'},
      bodyBytes: Uint8List.fromList(utf8.encode(entry.value(request))),
    );
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnsupportedError('the client buffers');

  @override
  void close() {}
}
