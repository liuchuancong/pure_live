import 'dart:convert' show jsonEncode, utf8;
import 'dart:typed_data' show Uint8List;

import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:pure_live/modules/hongguo/official/hongguo_official.dart'
    show HongguoDiscoveryCursor, HongguoOfficialClient, HongguoOfficialFailure;

/// The app's own discovery and search, read from their JSON answers: the
/// landpage's rows and its one-time selector panel, the walk's cursor and
/// the ways a bad answer names itself; the search tab of the shelf asked
/// for, its rows' three-name fallback and its highlight strip, and the
/// passback the next page carries.
void main() {
  late _RouteStub stub;
  late HongguoOfficialClient client;

  setUp(() {
    stub = _RouteStub();
    client = HongguoOfficialClient(http: stub);
  });

  Map<String, Object?> discoveryBody({
    int code = 0,
    Object? videoData = const <Object?>[
      {
        'series_id': '7100001',
        'title': '剧',
        'episode_cnt': 80,
        'cover': 'https://img.example/a.jpg',
        'video_desc': '简介',
        'category_schema': '[{"name":"甜宠"},{"name":"复仇"}]',
      },
      {'series_id': 'nope', 'title': '坏'},
      {'title': '无id'},
    ],
    bool hasMore = true,
    int nextOffset = 24,
    String session = 'sess1',
    Object? selectorRows = const <Object?>[
      {
        'type': 'genre',
        'items': [
          {'selector_item_id': 'short_play', 'show_name': '短剧'},
          {'selector_item_id': 'comic_series', 'show_name': '漫剧'},
          {'selector_item_id': 'not allowed space', 'show_name': '坏'},
          {'selector_item_id': 'ok_but_no_name', 'show_name': ''},
        ],
      },
      {
        'type': 'category_dim_theme',
        'items': [
          {'selector_item_id': 'theme:sweet', 'show_name': '甜宠'},
        ],
      },
      {'type': 'unknown_dim', 'items': <Object?>[]},
      'not-a-row',
    ],
  }) => {
    'code': code,
    'data': {
      'video_data': videoData,
      'has_more': hasMore,
      'next_offset': nextOffset,
      'session_id': session,
      'selector_rows': ?selectorRows,
    },
  };

  group('the discovery landpage', () {
    test('the first page carries its rows and its selector panel', () async {
      stub.routeFor('category/landpage', (request) => jsonEncode(discoveryBody()));
      final page = await client.discovery();

      expect(page.items, hasLength(1)); // the numbered, titled row; the rest skipped
      expect(page.items.first.seriesId, '7100001');
      expect(page.items.first.episodeCount, 80);
      expect(page.items.first.category, '甜宠 / 复仇'); // the schema's names joined

      expect(page.groups, hasLength(2)); // the two known dimensions; the unknown one and the junk dropped
      expect(page.groups[0].rowName, '类型');
      expect(page.groups[0].items.map((o) => o.id), ['short_play', 'comic_series']); // ids the pattern allows
      expect(page.groups[1].rowName, '主题');

      expect(page.hasMore, isTrue);
      expect(page.next?.offset, 24);
      expect(page.next?.session, 'sess1');
      expect(page.next?.page, 2);
    });

    test('a panel without the genre dimension is refused', () async {
      stub.routeFor('category/landpage', (request) {
        final body = discoveryBody(
          selectorRows: <Object?>[
            {'type': 'category_dim_theme', 'items': <Object?>[]},
          ],
        );
        return jsonEncode(body);
      });
      expect(
        () => client.discovery(),
        throwsA(isA<HongguoOfficialFailure>().having((e) => e.message, 'message', '分类筛选条件缺失')),
      );
    });

    test('rows that all fail their shape are a format, not an empty shelf', () async {
      stub.routeFor('category/landpage', (request) {
        return jsonEncode(
          discoveryBody(
            videoData: [
              {'series_id': 'nope', 'title': '坏'},
            ],
          ),
        );
      });
      expect(
        () => client.discovery(),
        throwsA(isA<HongguoOfficialFailure>().having((e) => e.message, 'message', '分类剧集格式异常')),
      );
    });

    test('a refused session names the service', () async {
      stub.routeFor('category/landpage', (request) => jsonEncode(discoveryBody(code: 7)));
      expect(
        () => client.discovery(),
        throwsA(isA<HongguoOfficialFailure>().having((e) => e.message, 'message', '分类服务暂不可用')),
      );
    });

    test('a walk that goes backwards has no next page to offer', () async {
      stub.routeFor('category/landpage', (request) => jsonEncode(discoveryBody(nextOffset: 0)));
      expect(
        () => client.discovery(cursor: const HongguoDiscoveryCursor(offset: 24, session: 'sess1', page: 2)),
        throwsA(isA<HongguoOfficialFailure>().having((e) => e.message, 'message', '分类续页信息异常')),
      );

      final stub2 = _RouteStub()..routeFor('category/landpage', (request) => jsonEncode(discoveryBody(session: '')));
      final client2 = HongguoOfficialClient(http: stub2);
      expect(
        () => client2.discovery(cursor: const HongguoDiscoveryCursor(offset: 24, session: 'sess1', page: 2)),
        throwsA(isA<HongguoOfficialFailure>().having((e) => e.message, 'message', '分类续页信息异常')),
      );
    });

    test('the walk continues without the panel, and an end stays an end', () async {
      stub.routeFor('category/landpage', (request) {
        return jsonEncode(discoveryBody(hasMore: false, selectorRows: null));
      });
      final page = await client.discovery(cursor: const HongguoDiscoveryCursor(offset: 24, session: 'sess1', page: 2));

      expect(page.groups, isEmpty); // a continuation asks for content only
      expect(page.hasMore, isFalse);
      expect(page.next, isNull); // the end stays an end
    });

    test('an answer with no rows in it is a missing list', () async {
      stub.routeFor('category/landpage', (request) {
        final body = discoveryBody(videoData: null);
        return jsonEncode(body);
      });
      expect(
        () => client.discovery(),
        throwsA(isA<HongguoOfficialFailure>().having((e) => e.message, 'message', '分类剧集列表缺失')),
      );
    });
  });

  Map<String, Object?> searchBody({
    int code = 0,
    Object? tabs = const <Object?>[
      {'tab_type': 19, 'data': <Object?>[]},
      {
        'tab_type': 11,
        'search_id': 'sid1',
        'passback': 'pb1',
        'next_offset': 20,
        'has_more': true,
        'data': [
          {
            'book_id': 'book9',
            'search_result_id': 'sr9',
            'search_high_light': {
              'title': {'text': '剧<em>名</em>'},
            },
            'video_data': [
              {
                'series_id': '7100009',
                'title': '剧名',
                'episode_cnt': 12,
                'cover': 'https://img.example/a.jpg',
                'video_desc': '简介',
                'rec_text': '热度',
                'sub_title': '副标题',
              },
            ],
          },
          {
            'book_id': 'book8',
            'video_data': [
              {'title': '无编号'},
            ],
          },
          {
            'book_id': '9000007',
            'search_result_id': '9500007',
            'video_data': [
              {'title': '回退编号', 'episode_cnt': 3, 'cover_url': 'https://img.example/b.jpg'},
            ],
          },
          {'video_data': <Object?>[]},
          'not-a-cell',
        ],
      },
    ],
  }) => {'code': code, 'search_tabs': tabs};

  group('the app search', () {
    test('the asked shelf answers its rows, their highlights and their fallbacks', () async {
      stub.routeFor('search/tab', (request) => jsonEncode(searchBody()));
      final answer = await client.appSearch('剧');

      expect(answer.items, hasLength(2));
      final first = answer.items.first;
      expect(first.seriesId, '7100009');
      expect(first.title, '剧名'); // the highlight's tags stripped off
      expect(first.episodeCount, 12);
      expect(first.hot, '热度');
      expect(first.category, '副标题');

      final second = answer.items[1]; // no series_id: the book's, then the result's
      expect(second.seriesId, '9000007'); // no series_id: the book's own number
      expect(second.title, '回退编号');
      expect(second.cover, 'https://img.example/b.jpg'); // the cover's other name

      expect(answer.hasMore, isTrue);
      expect(answer.next?.page, 2);
      expect(answer.next?.searchId, 'sid1');
      expect(answer.next?.passback, 'pb1');
      expect(answer.next?.offset, 20);
    });

    test('each shelf reads the tab asked for, not the first one listed', () async {
      stub.routeFor('search/tab', (request) => jsonEncode(searchBody()));
      // tab_type 19 sits first in the fixture and answers nothing: the
      // live-action ask must skip it and read tab 11.
      final answer = await client.appSearch('漫');
      expect(answer.items, hasLength(2)); // the default ask's own shelf
    });

    test('a shelf with no tab of its own is refused', () async {
      stub.routeFor(
        'search/tab',
        (request) => jsonEncode(
          searchBody(
            tabs: const <Object?>[
              {'tab_type': 19, 'data': <Object?>[]},
            ],
          ),
        ),
      );
      expect(
        () => client.appSearch('剧'),
        throwsA(isA<HongguoOfficialFailure>().having((e) => e.message, 'message', '剧集搜索暂不可用')),
      );
    });

    test('a refused session names the service, and a shapeless one its shape', () async {
      stub.routeFor('search/tab', (request) => jsonEncode(searchBody(code: 9)));
      expect(
        () => client.appSearch('剧'),
        throwsA(isA<HongguoOfficialFailure>().having((e) => e.message, 'message', '搜索接口暂不可用')),
      );

      final stub2 = _RouteStub()
        ..routeFor('search/tab', (request) => jsonEncode({'code': 0, 'data': <String, Object?>{}}));
      final client2 = HongguoOfficialClient(http: stub2);
      expect(
        () => client2.appSearch('剧'),
        throwsA(isA<HongguoOfficialFailure>().having((e) => e.message, 'message', '搜索格式异常')),
      );
    });

    test('the tabs ride one level down when the answer nests them', () async {
      stub.routeFor('search/tab', (request) {
        final body = searchBody();
        return jsonEncode(<String, Object?>{
          'code': 0,
          'data': <String, Object?>{'search_tabs': body['search_tabs']},
        });
      });
      final answer = await client.appSearch('剧');
      expect(answer.items, hasLength(2)); // the nested answer reads the same
    });

    test('an end stays an end', () async {
      stub.routeFor('search/tab', (request) {
        final tab = (searchBody()['search_tabs']! as List<Object?>)[1]! as Map<String, Object?>;
        final ended = {...tab, 'has_more': false};
        return jsonEncode(
          searchBody(
            tabs: <Object?>[
              {'tab_type': 19, 'data': <Object?>[]},
              ended,
            ],
          ),
        );
      });
      final answer = await client.appSearch('剧');
      expect(answer.hasMore, isFalse);
      expect(answer.next, isNull);
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
      headers: const {'content-type': 'application/json'},
      bodyBytes: Uint8List.fromList(utf8.encode(entry.value(request))),
    );
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnsupportedError('the client buffers');

  @override
  void close() {}
}
