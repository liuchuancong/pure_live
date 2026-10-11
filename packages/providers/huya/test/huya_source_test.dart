// Module: test/huya_source_test.dart
// Purpose: Drive the huya source over a scripted transport: listing, categories, search, resolve and refresh.
// Author: liuchuancong
// Created: 2026-10-11
//
// No live byte has been fetched for these fixtures; the shapes are transcribed from the protocol notes. What
// the tests buy is that a weird answer degrades the way this file claims - one odd row, one dead group, one
// missing url - rather than throwing away the page or opening a guessed host.

import 'dart:convert';

import 'package:pure_live_huya/pure_live_huya.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_network/testing.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:test/test.dart';

final DateTime _now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

/// base64 of `@/$1/$0-$2-$3?ws=1`, the shape the server ships in `fm`.
const String _fm = 'QC8kMS8kMC0kMi0kMz93cz0x';

/// A live anti code whose wsTime (1700000000) is the scripted clock itself, so the lease is current.
String _antiCode({String wsTime = '6553f100'}) =>
    Uri(queryParameters: <String, String>{'fm': _fm, 'ctype': 'html', 'wsTime': wsTime, 't': '100'}).query;

String _roomList({int page = 1, int totalPage = 3, String? extraRows}) => jsonEncode(<String, Object?>{
  'status': 200,
  'data': <String, Object?>{
    'page': page,
    'totalPage': totalPage,
    'datas': <Object?>[
      <String, Object?>{
        'profileRoom': '123456',
        'introduction': '午夜电台',
        'nick': '主播甲',
        'gameFullName': '星光',
        'screenshot': 'https://img.huya.com/a.jpg',
        'totalCount': '98765',
      },
      <String, Object?>{
        'profileRoom': '234567',
        'roomName': '无简介',
        'screenshot': 'https://img.huya.com/b.jpg?x=1',
        'totalCount': 42,
      },
      'not-a-room',
      if (extraRows != null) jsonDecode(extraRows),
    ],
  },
});

String _profile({String? override}) =>
    override ??
    jsonEncode(<String, Object?>{
      'status': 200,
      'data': <String, Object?>{
        'liveData': <String, Object?>{
          'introduction': '峡谷上分',
          'sRoomName': '房间1',
          'nick': '主播乙',
          'userCount': '555',
          'screenshot': 'https://img.huya.com/cover.jpg',
        },
        'stream': <String, Object?>{
          'baseSteamInfoList': <Object?>[
            <String, Object?>{
              'sStreamName': 'stream-one',
              'sHlsUrl': 'https://hls-a.example.com/src',
              'sFlvUrl': 'https://flv-a.example.com/src',
              'sHlsAntiCode': _antiCode(),
            },
            <String, Object?>{
              'sStreamName': 'stream-two',
              'sFlvUrl': 'https://other.example.com/flv/src',
              'sFlvAntiCode': _antiCode(),
            },
          ],
        },
      },
    });

/// The published scripted transport, aliased so the script helpers below read as this file's own vocabulary.
typedef _Scripted = ScriptedTransport;

NetworkClient _client(_Scripted transport) => NetworkClient(
  adapter: transport,
  clock: () => _now,
  // One attempt per request: the failure bodies (`!…`) are connection errors, which the production retry
  // policy legitimately re-attempts, and a source test wants one request per call or the counts mean nothing.
  settings: const NetworkSettings(retry: RetryPolicy(attempts: 1)),
);

HuyaSource _source(_Scripted transport) => HuyaSource(client: _client(transport), clock: () => _now);

final Map<String, List<String>> _defaultScript = <String, List<String>>{
  'www.huya.com/cache.php': <String>[_roomList()],
  'mp.huya.com/cache.php': <String>[_profile()],
  'search.cdn.huya.com/': <String>[
    jsonEncode(<String, Object?>{
      'response': <String, Object?>{
        '3': <String, Object?>{
          'docs': <Object?>[
            <String, Object?>{
              'room_id': '999',
              'game_introduction': '搜索命中',
              'game_nick': '主播丙',
              'gameName': '王者',
              'game_screenshot': 'https://img.huya.com/s.jpg',
              'game_onlineCount': 12,
            },
            42,
          ],
        },
      },
    }),
  ],
  'live.cdn.huya.com/liveconfig/game/bussLive': <String>[
    // Answered in call order: group 1, then 2, then 8, then 3 - each shape the gid field has shipped as.
    '{"data":[{"gid":{"value":"200,300"},"gameFullName":"网游甲"}]}',
    '{"data":[{"gid":201,"gameFullName":"单机甲"}]}',
    '{"data":[{"gid":"800","gameFullName":"娱乐甲"}]}',
    '{"data":[{"gid":3001.0,"gameFullName":"手游甲"}]}',
  ],
};

void main() {
  late _Scripted transport;
  late HuyaSource source;

  setUp(() {
    transport = _Scripted(_copy(_defaultScript));
    source = _source(transport);
  });

  tearDown(() => source.dispose());

  group('test_huyaSource_feed', () {
    test('test_feed_mapsRowsAndSkipsWhatIsNotARow', () async {
      final page = await source.feed(PageRequest(page: 1, pageSize: 20));

      expect(page.items, hasLength(2), reason: 'a string in the row list is dropped, not thrown on');
      expect(page.items.first.ref.contentId, '123456');
      expect(page.items.first.title, '午夜电台');
      expect(page.items.first.subtitle, '主播甲 · 星光');
      expect(page.items.first.metadata.popularity, 98765, reason: 'the count arrives as a string sometimes');
      expect(page.items.last.title, '无简介', reason: 'roomName is the fallback when introduction is absent');
      expect(page.items.last.cover, 'https://img.huya.com/b.jpg?x=1', reason: 'a query already on it is left alone');
      expect(page.items.first.cover, endsWith('?x-oss-process=style/w338_h190&'));
      expect(page.hasMore, isTrue);
    });

    test('test_feed_aMissingDatasFieldIsAMalformedAnswerAndAnEmptyOneIsNot', () async {
      transport = _Scripted(<String, List<String>>{
        'www.huya.com/cache.php': <String>['{"status":200,"data":{"page":1}}'],
      });
      final malformed = _source(transport);
      await expectLater(
        malformed.feed(PageRequest()),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('without data.datas'))),
      );

      transport = _Scripted(<String, List<String>>{
        'www.huya.com/cache.php': <String>['{"status":200,"data":{"page":4,"totalPage":4,"datas":[]}}'],
      });
      final empty = _source(transport);
      final page = await empty.feed(PageRequest(page: 4));
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse, reason: 'the last page is an answer, not a crash');
    });

    test('test_feed_withoutTotalPageItDoesNotClaimThereIsMore', () async {
      transport = _Scripted(<String, List<String>>{
        'www.huya.com/cache.php': <String>[
          jsonEncode(<String, Object?>{
            'data': <String, Object?>{
              'page': 1,
              'datas': <Object>[
                {'profileRoom': '1'},
              ],
            },
          }),
        ],
      });
      final noTotal = _source(transport);

      expect((await noTotal.feed(PageRequest())).hasMore, isFalse);
    });

    test('test_browse_routesACategoryThroughItsGameId', () async {
      await source.browse(ContentQuery(category: '200', page: PageRequest(page: 2, pageSize: 20)));

      final query = transport.requests.single.uri.queryParameters;
      expect(query['gameId'], '200');
      expect(query['page'], '2');
    });

    test('test_browse_withoutACategoryIsTheRecommendFeed', () async {
      await source.browse(ContentQuery());

      expect(transport.requests.single.uri.queryParameters.containsKey('gameId'), isFalse);
    });
  });

  group('test_huyaSource_categories', () {
    test('test_categories_convergesEveryGidShapeUnderTheFourGroups', () async {
      final tree = await source.categories();

      expect(tree.where((row) => row.parentId == null).map((row) => row.id), <String>[
        '1',
        '2',
        '8',
        '3',
      ], reason: 'the four top groups come first in their own order');
      expect(tree.map((row) => row.id), containsAll(<String>['200', '201', '800', '3001']));
      expect(tree.firstWhere((row) => row.id == '200').parentId, '1');
      expect(tree.firstWhere((row) => row.id == '200').icon, contains('/cdnimage/game/200-MS.jpg'));
    });

    test('test_categories_cachesOnlyACompleteTree', () async {
      transport = _Scripted(<String, List<String>>{
        // Group 2's answer throws, so the tree that comes back has three groups' games and no fourth.
        'live.cdn.huya.com/liveconfig/game/bussLive': <String>[
          '{"data":[{"gid":200,"gameFullName":"网游甲"}]}',
          '!this group is down',
          '{"data":[{"gid":800,"gameFullName":"娱乐甲"}]}',
          '{"data":[{"gid":3001,"gameFullName":"手游甲"}]}',
        ],
      });
      final flaky = _source(transport);

      final partial = await flaky.categories();
      expect(partial.map((row) => row.id), isNot(contains('201')));
      expect(transport.requestsTo('live.cdn.huya.com/liveconfig/game/bussLive'), 4);
      await flaky.categories();
      expect(
        transport.requestsTo('live.cdn.huya.com/liveconfig/game/bussLive'),
        8,
        reason: 'a partial tree is not pinned',
      );

      transport = _Scripted(<String, List<String>>{
        'live.cdn.huya.com/liveconfig/game/bussLive': <String>['{"data":[]}'],
      });
      final whole = _source(transport);
      final complete = await whole.categories();
      await whole.categories();
      expect(transport.requestsTo('live.cdn.huya.com/liveconfig/game/bussLive'), 4, reason: 'a complete one is');
      expect(complete.length, 4);
      flaky.dispose();
      whole.dispose();
    });

    test('test_categories_aGroupThatThrowsStillLeavesTheRest', () async {
      transport = _Scripted(<String, List<String>>{
        'live.cdn.huya.com/liveconfig/game/bussLive': <String>['not json at all'],
      });
      final broken = _source(transport);

      final tree = await broken.categories();
      expect(tree.map((row) => row.id), <String>['1', '2', '8', '3']);
      broken.dispose();
    });
  });

  group('test_huyaSource_search', () {
    test('test_search_pagesByStartAndDropsNonRows', () async {
      final page = await source.search(SearchQuery(keyword: '主播', page: PageRequest(page: 3, pageSize: 20)));

      expect(page.items, hasLength(1), reason: 'the scripted docs contain one number');
      expect(page.items.first.ref.contentId, '999');
      expect(page.items.first.metadata.popularity, 12);
      final query = transport.requests.single.uri.queryParameters;
      expect(query['start'], '40');
      expect(query['rows'], '20');
      expect(page.hasMore, isFalse);
    });
  });

  group('test_huyaSource_resolve', () {
    test('test_resolve_prefersTheHlsHostTheServerActuallyGave', () async {
      final ticket = await source.resolve(
        ContentRef(sourceId: huyaSourceId, contentId: '123456', kind: ContentKind.liveRoom),
      );

      expect(ticket.uri.toString(), startsWith('https://hls-a.example.com/src/stream-one.m3u8?'));
      expect(ticket.protocol, MediaProtocol.hls);
      expect(ticket.kind, MediaKind.live);
      expect(ticket.uri.queryParameters.containsKey('fm'), isFalse);
      expect(ticket.uri.queryParameters['wsSecret'], isNotNull);
      expect(ticket.uri.queryParameters['codec'], '264');
      expect(ticket.headers['referer'], 'https://www.huya.com/');
      expect(ticket.metadata.extra[huyaLineKey], 1);
      expect(ticket.metadata.extra[huyaLineCountKey], 2);
      expect(ticket.metadata.title, '峡谷上分');
      expect(ticket.createdAt, _now.toUtc());
    });

    test('test_resolve_lineTwoOpensTheSecondCdnAndRemembersIt', () async {
      final ticket = await source.resolve(
        ContentRef(sourceId: huyaSourceId, contentId: '123456', kind: ContentKind.liveRoom),
        line: SelectionRef('2'),
        quality: SelectionRef('1080p'),
      );

      // Entry two ships only an flv url, so this is the fallback path - and it must not rewrite the host's
      // own 'flv' text by accident: the base here is https://other.example.com/flv/src.
      expect(ticket.uri.host, 'other.example.com');
      expect(ticket.uri.path, '/hls/src/stream-two.m3u8');
      expect(ticket.metadata.extra[huyaLineKey], 2);
      expect(ticket.metadata.extra['huya.requestedQuality'], '1080p');
    });

    test('test_resolve_anUnknownLineIsRefusedRatherThanPlayedAsLineOne', () async {
      final ref = ContentRef(sourceId: huyaSourceId, contentId: '123456', kind: ContentKind.liveRoom);

      await expectLater(
        source.resolve(ref, line: SelectionRef('js-live')),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', allOf(contains('2 CDN line'), contains('js-live'))),
        ),
      );
      await expectLater(source.resolve(ref, line: SelectionRef('3')), throwsA(isA<StateError>()));
      expect(transport.requestsTo('mp.huya.com/cache.php'), 2);
      expect(transport.requestsTo('www.huya.com/cache.php'), 0, reason: 'no ticket was minted either way');
    });

    test('test_resolve_aRoomWithoutStreamsIsNamed', () async {
      transport = _Scripted(<String, List<String>>{
        'mp.huya.com/cache.php': <String>['{"status":200,"data":{"liveData":{"sRoomName":"空闲"}}}'],
      });
      final offline = _source(transport);

      await expectLater(
        offline.resolve(ContentRef(sourceId: huyaSourceId, contentId: '7', kind: ContentKind.liveRoom)),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('is not streaming'))),
      );
    });

    test('test_resolve_aClosedRoomCarriesTheSiteMessage', () async {
      transport = _Scripted(<String, List<String>>{
        'mp.huya.com/cache.php': <String>['{"status":404,"message":"房间不存在"}'],
      });
      final missing = _source(transport);

      await expectLater(
        missing.detail(ContentRef(sourceId: huyaSourceId, contentId: '77', kind: ContentKind.liveRoom)),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('房间不存在'))),
      );
    });

    test('test_resolve_anExpiredLeaseRefusesInsteadOfOpeningAUrlThatWillFourOhThree', () async {
      transport = _Scripted(<String, List<String>>{
        'mp.huya.com/cache.php': <String>[
          _profile(
            override: jsonEncode(<String, Object?>{
              'status': 200,
              'data': <String, Object?>{
                'stream': <String, Object?>{
                  'baseSteamInfoList': <Object?>[
                    <String, Object?>{
                      'sStreamName': 's',
                      'sHlsUrl': 'https://h.example.com/src',
                      'sHlsAntiCode': _antiCode(wsTime: '6553e800'),
                    },
                  ],
                },
              },
            }),
          ),
        ],
      });
      final stale = _source(transport);

      await expectLater(
        stale.resolve(ContentRef(sourceId: huyaSourceId, contentId: '7', kind: ContentKind.liveRoom)),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('lease expired'))),
      );
    });

    test('test_refresh_renewsTheSameLine', () async {
      final first = await source.resolve(
        ContentRef(sourceId: huyaSourceId, contentId: '123456', kind: ContentKind.liveRoom),
        line: SelectionRef('2'),
      );
      final again = await source.refresh(first, RefreshReason.expired);

      expect(again.uri.host, first.uri.host);
      expect(again.uri.path, first.uri.path);
      expect(again.metadata.extra[huyaLineKey], 2);
      expect(again.id, first.id);
      expect(transport.requestsTo('mp.huya.com/cache.php'), 2, reason: 'a fresh lease is a fresh profileRoom ask');
    });

    test('test_refresh_aTicketFromAnotherSourceIsRefused', () async {
      await expectLater(
        source.refresh(
          MediaTicket(
            id: 'other/1',
            uri: Uri.parse('https://example.com/x.m3u8'),
            kind: MediaKind.live,
            protocol: MediaProtocol.hls,
            createdAt: _now.toUtc(),
          ),
          RefreshReason.manual,
        ),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('does not name a room'))),
      );
    });
  });
}

Map<String, List<String>> _copy(Map<String, List<String>> source) => <String, List<String>>{
  for (final entry in source.entries) entry.key: List<String>.of(entry.value),
};
