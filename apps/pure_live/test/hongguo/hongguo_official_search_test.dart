import 'dart:convert' show jsonEncode, utf8;
import 'dart:typed_data' show Uint8List;

import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:pure_live/modules/hongguo/official/hongguo_official.dart'
    show HongguoOfficialClient, HongguoOfficialFailure;

/// The website's search words and its search page: the suggestions a
/// half-typed word buys (each one named, or displayed, and never twice),
/// and the result page's rows — under their wrapper or beside it, titled by
/// whichever of its three names it carries, heated by its own block — and
/// the ways a wrong page says so.
void main() {
  late _RouteStub stub;
  late HongguoOfficialClient client;

  setUp(() {
    stub = _RouteStub();
    client = HongguoOfficialClient(http: stub);
  });

  group('the suggestions', () {
    test('a half-typed word buys named words, once each, eight at most', () async {
      stub.routeFor('suggestion', (request) {
        return jsonEncode({
          'suggest_list': [
            {'name': '甜宠剧'},
            {
              'display_words': ['  复仇剧  '],
            }, // no name: the display stands in, trimmed
            {'name': '甜宠剧'}, // the same word twice: the second is dropped
            {'name': ''}, // neither name nor display: dropped
            {'display_words': <Object?>[]}, // an empty display: dropped
            {'name': 'a' * 81}, // longer than a word may be: dropped
            {'name': '古装剧'},
            {'name': '逆袭剧'},
            {'name': '悬疑剧'},
            {'name': '古偶剧'},
            {'name': '甜剧'},
          ],
        });
      });
      final words = await client.searchSuggestions('甜');

      expect(words, ['甜宠剧', '复仇剧', '古装剧', '逆袭剧', '悬疑剧', '古偶剧', '甜剧']); // seven, once each
    });

    test('a blank word asks nothing at all', () async {
      expect(await client.searchSuggestions('   '), isEmpty);
      expect(await client.searchSuggestions('a' * 81), isEmpty);
      expect(stub.seen, isEmpty); // no ask left the form
    });

    test('a shapeless answer names itself', () async {
      stub.routeFor('suggestion', (request) => jsonEncode(<String, Object?>{'data': <String, Object?>{}}));
      expect(
        () => client.searchSuggestions('甜'),
        throwsA(isA<HongguoOfficialFailure>().having((e) => e.message, 'message', '搜索联想暂不可用')),
      );
    });
  });

  group('the search page', () {
    Map<String, Object?> searchPage({int pageNum = 1, int totalPages = 3, bool? hasMore, List<Object?>? rows}) => {
      'pageNum': pageNum,
      'totalPages': totalPages,
      'hasMore': ?hasMore,
      'searchList':
          rows ??
          [
            {
              'video_data': {
                'series_id': '7100001',
                'series_name': '剧',
                'episode_cnt': 80,
                'series_cover': r'https:\/\/img.example\/a.jpg',
                'series_intro': '简介',
                'hot_score_data': {'text': '热度第一'},
                'tags': [
                  {'name': '甜宠'},
                  {'name': '复仇'},
                ],
              },
            },
            {
              // no wrapper: the row itself carries the series
              'series_id': '7100002',
              'series_title': '乙',
              'episode_cnt': 3,
              'hot': '热度乙',
              'category_list': ['古装', '权谋'],
            },
            {
              'series_id': '7100003',
              // no series_name, no series_title: the row's own name
              'name': '丙',
            },
            {'series_id': '7100004'}, // no title at all: skipped
            {'series_name': '无编号'},
            'not-a-row',
          ],
    };

    test('the rows read under their wrapper or beside it, by their own names', () async {
      stub.routeFor('api/search/result', (request) => jsonEncode(searchPage()));
      final answer = await client.websiteSearch('剧');

      expect(answer.items, hasLength(3));
      final first = answer.items.first;
      expect(first.seriesId, '7100001');
      expect(first.title, '剧');
      expect(first.episodeCount, 80);
      expect(first.cover, 'https://img.example/a.jpg'); // the escapes cleaned off
      expect(first.intro, '简介');
      expect(first.hot, '热度第一'); // the heat block's own words, not the count again
      expect(first.category, '甜宠 / 复仇');

      final second = answer.items[1]; // the wrapperless row, titled by its other name
      expect(second.seriesId, '7100002');
      expect(second.title, '乙');
      expect(second.hot, '热度乙');
      expect(second.category, '古装 / 权谋');

      final third = answer.items[2];
      expect(third.title, '丙'); // the row's own name, when the series has none
    });

    test('the walk follows the page the answer names, or its total', () async {
      stub.routeFor('api/search/result', (request) => jsonEncode(searchPage()));
      expect((await client.websiteSearch('剧')).hasMore, isTrue); // page one of three

      stub.routeFor('api/search/result', (request) => jsonEncode(searchPage(pageNum: 2, totalPages: 0)));
      expect((await client.websiteSearch('剧', page: 2)).hasMore, isFalse); // no total, no walk

      stub.routeFor('api/search/result', (request) => jsonEncode(searchPage(hasMore: true)));
      expect((await client.websiteSearch('剧')).hasMore, isTrue); // the station's own say-so
    });

    test('a page the answer did not name is refused', () async {
      stub.routeFor('api/search/result', (request) => jsonEncode(searchPage(pageNum: 5)));
      expect(
        () => client.websiteSearch('剧'),
        throwsA(isA<HongguoOfficialFailure>().having((e) => e.message, 'message', '搜索页码不匹配')),
      );
    });

    test('a list in another shape is refused', () async {
      stub.routeFor('api/search/result', (request) {
        final page = searchPage();
        page['searchList'] = 'junk';
        return jsonEncode(page);
      });
      expect(
        () => client.websiteSearch('剧'),
        throwsA(isA<HongguoOfficialFailure>().having((e) => e.message, 'message', '搜索数据结构已变化')),
      );
    });
  });
}

/// A transport answering by route fragment, and remembering its asks.
final class _RouteStub implements LiveHttp {
  final Map<String, String Function(LiveRequest)> _routes = {};
  final List<LiveRequest> seen = [];

  void routeFor(String fragment, String Function(LiveRequest) answer) => _routes[fragment] = answer;

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    seen.add(request);
    final entry = _routes.entries.firstWhere(
      (entry) => request.url.toString().contains(entry.key),
      orElse: () => throw StateError('no answer for ${request.url}'),
    );
    return LiveResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      bodyBytes: Uint8List.fromList(utf8.encode(entry.value(request))),
    );
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnsupportedError('the client buffers');

  @override
  void close() {}
}
