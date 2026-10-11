// Module: test/soop/soop_source_test.dart
// Purpose: The SOOP source against a canned transport: the result codes, the split audience fields, the tier
// ranking and the assign-plus-sign play path.
// Author: liuchuancong
// Created: 2026-10-11
//
// Bodies are written to the field names the v1 line reads, not recorded from the site (README 未验证).

import 'dart:convert';

import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_network/testing.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_sites/pure_live_sites.dart';
import 'package:test/test.dart';

const String _searchKey = 'sch.sooplive.co.kr/api.php';
const String _homeKey = 'live.sooplive.co.kr/api/main_broad_list_api.php';
const String _playerKey = 'live.sooplive.co.kr/afreeca/player_live_api.php';
const String _assignKey = 'fls.sooplive.co.kr/live/broad_stream_assign.html';

final DateTime _now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
const ContentRef _room = ContentRef(sourceId: 'soop.live', contentId: 'soopuser', kind: ContentKind.liveRoom);
const String _viewpreset = '''[{"name":"Original","bps":0},{"name":"auto","bps":0},{"name":"HD","bps":3000000}]''';

NetworkClient _client(ScriptedTransport transport) => NetworkClient(
  adapter: transport,
  clock: () => _now,
  settings: const NetworkSettings(retry: RetryPolicy(attempts: 1)),
);

(ScriptedTransport, SoopSource) _source(Map<String, List<String>> script, {String? cookie}) {
  final transport = ScriptedTransport(script);
  return (transport, SoopSource(client: _client(transport), clock: () => _now, cookie: cookie));
}

Map<String, Object?> _channelJson({int result = 1, String cdn = 'gs_cdn_premium', Object? presets = _viewpreset}) =>
    <String, Object?>{
      'CHANNEL': <String, Object?>{
        'RESULT': result,
        if (result == 1) 'BNO': '12345678',
        'BJID': 'soopuser',
        'BJNICK': ' BJ-NICK ',
        'TITLE': '방송 &amp; 제목',
        'RMD': 'https://fls.sooplive.co.kr/live/',
        'CDN': cdn,
        'CATEGORY_TAGS': <Object?>['게임'],
        if (presets != null) 'VIEWPRESET': jsonDecode(presets as String),
        'VIEW_CNT': '1,234',
        'CHATNO': '99',
        'CHDOMAIN': 'chtr.sooplive.co.kr',
        'CHPT': 9000,
      },
    };

String _channel({int result = 1, String cdn = 'gs_cdn_premium', Object? presets = _viewpreset}) =>
    jsonEncode(_channelJson(result: result, cdn: cdn, presets: presets));

String _rows(List<Object?> rows) => jsonEncode(<String, Object?>{
  'data': <String, Object?>{'list': rows},
});

Map<String, Object?> _listRow({String userId = 'soopuser', String title = '제목', String viewers = '1,234'}) =>
    <String, Object?>{
      'user_id': userId,
      'user_nick': '닉',
      'broad_title': title,
      'thumbnail': '//img.sooplive.co.kr/t.jpg',
      'broad_cate_name': '게임',
      'total_view_cnt': viewers,
    };

void main() {
  group('test_soopSource_readers', () {
    test('test_theAudienceIsSplitAcrossPcAndMobile', () {
      expect(soopViewers(<String, Object?>{'total_view_cnt': '2,500'}), 2500);
      expect(soopViewers(<String, Object?>{'VIEW_CNT': 12}), 12);
      // No combined field: the two platform figures add up.
      expect(soopViewers(<String, Object?>{'pc_view_cnt': '10', 'mobile_view_cnt': '5'}), 15);
      expect(soopViewers(<String, Object?>{'current_view_cnt': '0', 'm_current_view_cnt': '0'}), 0);
      // An explicit zero is a stated zero; a room that named nothing at all is null.
      expect(soopViewers(<String, Object?>{'view_cnt': '0'}), 0);
      expect(soopViewers(<String, Object?>{'other': 1}), isNull);
    });

    test('test_theTierNameRanksAboveAnAbsentBitrate', () {
      final tiers = soopQualities(jsonDecode(_viewpreset));
      // `auto` is the player's decision, not a tier a viewer is asked to pick.
      expect(tiers.map((SoopQuality tier) => tier.name), <String>['Original', 'HD']);
      expect(tiers.first.rank, greaterThan(tiers.last.rank), reason: 'Original has no bps and still leads');
      expect(tiers.first.bitrateBps, isNull);
      expect(tiers.last.bitrateBps, 3000000);
    });

    test('test_anUnfamiliarTierKeepsItsOwnNameAndSortsByRate', () {
      final tiers = soopQualities(<Object?>[
        <String, Object?>{'name': 'QUANTUM', 'bps': 8000000},
        <String, Object?>{'name': 'HD', 'bps': 3000000},
      ]);
      // The known tier outranks the unknown one even though its bitrate is lower: the table is the site's order.
      // A name off the table has no tier rank, so it sorts by its stated rate alone and lands below the
      // site's own HD tier rather than above it on bandwidth.
      expect(tiers.map((SoopQuality tier) => tier.name), <String>['HD', 'QUANTUM']);
      expect(soopTierSort('QUANTUM', 8000000), 8000000);
      expect(soopTierSort('HD', 3000000), 300000000 + 3000000);
    });

    test('test_theChatSocketPortIsTheTlsNeighbour', () {
      expect(
        soopChatUrl(<String, Object?>{'CHDOMAIN': 'chtr.sooplive.co.kr', 'CHPT': 9000}, 'soopuser'),
        'wss://chtr.sooplive.co.kr:9001/Websocket/soopuser',
      );
      // No host: the site's own naming rebuilds it from the chat IPv4.
      expect(
        soopChatUrl(<String, Object?>{'CHIP': '123.45.6.7', 'CHPT': '9000'}, 'soopuser'),
        // Hostnames are case-insensitive and Uri normalises the authority to lower case.
        'wss://chat-7b2d0607.sooplive.co.kr:9001/Websocket/soopuser',
      );
      expect(() => soopChatUrl(<String, Object?>{'CHPT': 9000}, 'soopuser'), throwsA(isA<SoopFailure>()));
      expect(
        () => soopChatUrl(<String, Object?>{'CHDOMAIN': 'x', 'CHPT': 65535}, 'soopuser'),
        throwsA(isA<SoopFailure>()),
      );
    });

    test('test_theReturnTypeAndBroadKeyAreTheSitesOwnShapes', () {
      expect(soopReturnType('gs_cdn_premium'), 'gs_cdn_pc_web');
      expect(soopReturnType('lg_cdn_x'), 'lg_cdn_pc_web');
      expect(soopReturnType('edge'), 'edge');
      expect(soopBroadKey('12345678', 'hd'), '12345678-common-hd-hls');
      expect(soopAssignUri('https://fls.sooplive.co.kr/live').path, '/live/broad_stream_assign.html');
      expect(() => soopAssignUri('fls.sooplive.co.kr'), throwsA(isA<SoopFailure>()));
    });

    test('test_theDisplayTextIsUnescapedAndTheIdIsLowercased', () {
      expect(soopDisplay('방송 &amp; 제목'), '방송 & 제목');
      expect(soopRoomId('SoopUser'), 'soopuser');
      expect(() => soopRoomId('a'), throwsA(isA<SoopFailure>()));
      expect(soopRoomFromUri(Uri.parse('https://play.sooplive.co.kr/soopuser')), 'soopuser');
      expect(soopRoomFromUri(Uri.parse('https://sooplive.co.kr/soopuser/live')), isNull);
      expect(soopChatHostFromIp('1.2.3'), '');
    });
  });

  group('test_soopSource_channel', () {
    test('test_theResultCodeDecidesWhatIsKnown', () async {
      final (_, live) = _source(<String, List<String>>{
        _playerKey: <String>[_channel()],
      });
      final room = await live.room(_room);
      expect(room.state, LiveRoomState.live);
      expect(room.title, '방송 & 제목');
      expect(room.streamId, '12345678');
      expect(room.reportedStateCode, 1);
      expect(room.audiencePrimary, 1234);
      expect(room.sitePayload['rmd'], 'https://fls.sooplive.co.kr/live/');
      expect(room.danmakuPayload['url'], 'wss://chtr.sooplive.co.kr:9001/Websocket/soopuser');

      final (_, off) = _source(<String, List<String>>{
        _playerKey: <String>[_channel(result: 0, presets: null)],
      });
      final ended = await off.room(_room);
      expect(ended.state, LiveRoomState.ended);
      expect(ended.audiencePrimary, 0, reason: 'the site explicitly says nobody is live');

      final (_, banned) = _source(<String, List<String>>{
        _playerKey: <String>[_channel(result: -2, presets: null)],
      });
      final bannedRoom = await banned.room(_room);
      expect(bannedRoom.state, LiveRoomState.ended);
      expect(bannedRoom.restriction, LiveRestriction.unplayable);
      expect(bannedRoom.extra['soop.banned'], isTrue);

      // A code the line does not know is a session or shape problem, not proof that the channel ended.
      final (_, odd) = _source(<String, List<String>>{
        _playerKey: <String>[_channel(result: 2, presets: null)],
      });
      await expectLater(odd.room(_room), throwsA(isA<SoopFailure>()));
    });

    test('test_theAnswerAboutAnotherChannelIsRefused', () async {
      final (_, source) = _source(<String, List<String>>{
        _playerKey: <String>[
          jsonEncode(<String, Object?>{
            'CHANNEL': <String, Object?>{'RESULT': 1, 'BNO': '1', 'BJID': 'other', 'VIEW_CNT': 1},
          }),
        ],
      });
      await expectLater(source.room(_room), throwsA(isA<SoopFailure>()));
    });

    test('test_aDoubleEncodedAnswerIsDecodedOnceMore', () async {
      // The site sometimes answers with a json string that itself contains json.
      final (_, source) = _source(<String, List<String>>{
        _playerKey: <String>[jsonEncode(_channel())],
      });
      expect((await source.room(_room)).state, LiveRoomState.live);
    });

    test('test_aChannelWithNoTierIsUnplayableAndSaysSo', () async {
      final (_, source) = _source(<String, List<String>>{
        _playerKey: <String>[_channel(presets: '[]')],
      });
      final room = await source.room(_room);
      expect(room.state, LiveRoomState.live);
      expect(room.restriction, LiveRestriction.unplayable);
      expect(await source.qualities(_room), isEmpty);
      await expectLater(
        source.resolve(_room),
        throwsA(isA<StateError>().having((StateError e) => e.message, 'message', contains('no tier'))),
      );
    });

    test('test_aBrokenChatEndpointDoesNotHideTheRoom', () async {
      final body = _channelJson();
      (body['CHANNEL']! as Map<String, Object?>)['CHPT'] = 0;
      final (_, source) = _source(<String, List<String>>{
        _playerKey: <String>[jsonEncode(body)],
      });
      final room = await source.room(_room);
      expect(room.state, LiveRoomState.live);
      expect(room.danmakuPayload.containsKey('url'), isFalse);
    });
  });

  group('test_soopSource_lists', () {
    test('test_theCategoryTablePagesUntilAShortPage', () async {
      final full = <Object?>[
        for (var index = 0; index < soopCategoryPageSize; index++)
          <String, Object?>{
            'category_no': '$index',
            'category_name': '카테고리 $index',
            'cate_img': '//img.sooplive.co.kr/$index.png',
          },
      ];
      final (transport, source) = _source(<String, List<String>>{
        _searchKey: <String>[
          _rows(full),
          _rows(<Object?>[
            <String, Object?>{'category_no': '999', 'category_name': '마지막'},
            <String, Object?>{'category_no': 'bad id', 'category_name': '거른'},
          ]),
        ],
      });
      final categories = await source.categories();
      expect(categories, hasLength(soopCategoryPageSize + 1));
      expect(categories.last.id, '999');
      expect(transport.requestsTo(_searchKey), 2);
    });

    test('test_aGridRowWithoutAUserIdFailsThePage', () async {
      final (_, source) = _source(<String, List<String>>{
        _searchKey: <String>[
          _rows(<Object?>[
            <String, Object?>{'broad_title': 'no id'},
          ]),
        ],
      });
      await expectLater(source.browse(const ContentQuery(category: '11')), throwsA(isA<SoopFailure>()));
    });

    test('test_theHomepageBlockFillsOnePage', () async {
      final (transport, source) = _source(<String, List<String>>{
        _homeKey: <String>[
          jsonEncode(<String, Object?>{
            'broad': <Object?>[_listRow(), _listRow(userId: 'other')],
          }),
        ],
      });
      final page = await source.feed(PageRequest.first);
      expect(page.items.map((item) => item.ref.contentId), <String>['soopuser', 'other']);
      expect(transport.requestsTo(_searchKey), 0);
    });

    test('test_aSearchTermIsCheckedBeforeItIsSent', () async {
      final (transport, source) = _source(<String, List<String>>{
        _searchKey: <String>[
          jsonEncode(<String, Object?>{'REAL_BROAD': <Object?>[]}),
        ],
      });
      await expectLater(source.search(const SearchQuery(keyword: '')), throwsA(isA<SoopFailure>()));
      await expectLater(source.search(SearchQuery(keyword: 'x' * 101)), throwsA(isA<SoopFailure>()));
      expect(transport.requestsTo(_searchKey), 0);
    });
  });

  group('test_soopSource_play', () {
    test('test_theAddressIsAssignedAndThenSigned', () async {
      final (transport, source) = _source(<String, List<String>>{
        _playerKey: <String>[
          _channel(),
          jsonEncode(<String, Object?>{
            'CHANNEL': <String, Object?>{'RESULT': 1, 'AID': 'aid-1'},
          }),
        ],
        _assignKey: <String>[
          jsonEncode(<String, Object?>{'view_url': 'https://fls.sooplive.co.kr/live/12345678.m3u8'}),
        ],
      });
      final ticket = await source.resolve(_room);
      expect(ticket.uri.path, '/live/12345678.m3u8');
      expect(ticket.uri.queryParameters['aid'], 'aid-1');
      expect(ticket.metadata.extra['soop.quality'], 'Original');
      final assign = transport.requests.firstWhere((request) => request.hostKey == _assignKey).uri;
      expect(assign.queryParameters['return_type'], 'gs_cdn_pc_web');
      expect(assign.queryParameters['broad_key'], '12345678-common-Original-hls');
    });

    test('test_anAskedTierIsKeptAndAnUnknownOneIsRecorded', () async {
      final (_, source) = _source(<String, List<String>>{
        _playerKey: <String>[
          _channel(),
          jsonEncode(<String, Object?>{
            'CHANNEL': <String, Object?>{'RESULT': 1, 'AID': 'aid-2'},
          }),
          _channel(),
          jsonEncode(<String, Object?>{
            'CHANNEL': <String, Object?>{'RESULT': 1, 'AID': 'aid-3'},
          }),
        ],
        _assignKey: <String>[
          jsonEncode(<String, Object?>{'view_url': 'https://fls.sooplive.co.kr/live/hd.m3u8'}),
          jsonEncode(<String, Object?>{'view_url': 'https://fls.sooplive.co.kr/live/top.m3u8'}),
        ],
      });
      final hd = await source.resolve(_room, quality: const SelectionRef('hd'));
      expect(hd.uri.path, '/live/hd.m3u8');
      // The ask was lower-cased while the channel names the tier `HD`; the site's own spelling is what the
      // assignment and the ticket carry.
      expect(hd.metadata.extra['soop.quality'], 'HD');
      expect(hd.metadata.extra.containsKey('soop.requestedQuality'), isFalse);
      // A tier the channel no longer offers falls back to the top one, and the ask is written down.
      final gone = await source.resolve(_room, quality: const SelectionRef('8k'));
      expect(gone.uri.path, '/live/top.m3u8');
      expect(gone.metadata.extra['soop.requestedQuality'], '8k');
    });

    test('test_thereIsNoLineAxisAndNoReusedAid', () async {
      final (transport, source) = _source(<String, List<String>>{
        _playerKey: <String>[
          _channel(),
          jsonEncode(<String, Object?>{
            'CHANNEL': <String, Object?>{'RESULT': 1, 'AID': 'aid-a'},
          }),
          _channel(),
          jsonEncode(<String, Object?>{
            'CHANNEL': <String, Object?>{'RESULT': 1, 'AID': 'aid-b'},
          }),
        ],
        _assignKey: <String>[
          jsonEncode(<String, Object?>{'view_url': 'https://fls.sooplive.co.kr/live/x.m3u8'}),
          jsonEncode(<String, Object?>{'view_url': 'https://fls.sooplive.co.kr/live/x.m3u8'}),
        ],
      });
      await expectLater(source.resolve(_room, line: const SelectionRef('2')), throwsA(isA<StateError>()));
      final ticket = await source.resolve(_room);
      final again = await source.refresh(ticket, RefreshReason.expiring);
      // The aid is signed per request, so a refresh is a new signature and not a reuse of the old query.
      expect(again.uri.queryParameters['aid'], isNot(ticket.uri.queryParameters['aid']));
      expect(transport.requestsTo(_assignKey), 2);
    });

    test('test_theOperatorCookieTravelsWithTheMedia', () async {
      final (transport, source) = _source(<String, List<String>>{
        _playerKey: <String>[
          _channel(),
          jsonEncode(<String, Object?>{
            'CHANNEL': <String, Object?>{'RESULT': 1, 'AID': 'aid'},
          }),
        ],
        _assignKey: <String>[
          jsonEncode(<String, Object?>{'view_url': 'https://fls.sooplive.co.kr/live/x.m3u8'}),
        ],
      }, cookie: 'pando_tv_id=abc');
      final ticket = await source.resolve(_room);
      expect(ticket.headers['cookie'], 'pando_tv_id=abc');
      expect(transport.requests.first.header('cookie'), 'pando_tv_id=abc');
    });

    test('test_qualitiesNeverTouchTheSigningPair', () async {
      final (transport, source) = _source(<String, List<String>>{
        _playerKey: <String>[_channel()],
      });
      final qualities = await source.qualities(_room);
      expect(qualities.map((option) => option.label), <String>['Original', 'HD']);
      expect(transport.requestsTo(_assignKey), 0);
    });
  });
}
