// Module: test/kugou/kugou_source_test.dart
// Purpose: The Kugou source against a canned transport: scraped categories, the directory, jsonp search, the
// on-air rule and the signed per-profile urls.
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

const String _homeKey = 'fanxing.kugou.com';
const String _directoryKey = 'fx1.service.kugou.com/mfanxing-home/h5/cdn/room/index/list';
const String _searchKey = 'fx1.service.kugou.com/pt_search/pcsearch/v1/type_all.jsonp';
const String _roomKey = 'service2.fanxing.kugou.com/roomcen/room/web/cdn/getEnterRoomInfo';
const String _mediaKey = 'fx1.service.kugou.com/video/pc/live/pull/mutiline/streamaddr';

final DateTime _now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
const ContentRef _room55 = ContentRef(sourceId: 'kugou.live', contentId: '55', kind: ContentKind.liveRoom);

NetworkClient _client(ScriptedTransport transport) => NetworkClient(
  adapter: transport,
  clock: () => _now,
  settings: const NetworkSettings(retry: RetryPolicy(attempts: 1)),
);

(ScriptedTransport, KugouSource) _source(Map<String, List<String>> script) {
  final transport = ScriptedTransport(script);
  return (transport, KugouSource(client: _client(transport), clock: () => _now));
}

String _ok(Map<String, Object?> data) => jsonEncode(<String, Object?>{'status': 0, 'data': data});

const String _flv = 'https://liveplay.live.kugou.com/live/55_1.flv?txSecret=abcdef0123456789&txTime=6553F100';
const String _hls = 'https://liveplay.live.kugou.com/live/55_1.m3u8?txSecret=abcdef0123456789&txTime=6553F100';

String _room({int liveType = 1, String session = 'sess-1', String nick = '主播甲'}) => _ok(<String, Object?>{
  'liveType': liveType,
  'liveSessionId': session,
  'liveName': '歌谣夜',
  'normalRoomInfo': <String, Object?>{
    'nickName': nick,
    'kugouId': '900',
    'userId': '700',
    'imgPath': '//img/55.jpg',
    'userLogo': '/logo/900.png',
    'publicMesg': '公告',
    'fansCount': 1200,
  },
});

String _media({String roomId = '55', int status = 1, List<Object?>? profiles}) => _ok(<String, Object?>{
  'roomId': roomId,
  'status': status,
  'lines': <Object?>[
    <String, Object?>{
      'streamProfiles':
          profiles ??
          <Object?>[
            <String, Object?>{
              'rate': 1200,
              'codec': 1,
              'layout': 0,
              'httpsFlv': <Object?>[
                _flv,
                'https://other.example/live/55_1.flv?txSecret=abcdef0123456789&txTime=6553F100',
              ],
              'httpsHls': <Object?>[_hls],
            },
          ],
    },
  ],
});

void main() {
  group('test_kugouSource_listing', () {
    test('test_feed_usesTheSitesOwnContinuationFlag', () async {
      final (transport, kugou) = _source(<String, List<String>>{
        _directoryKey: <String>[
          _ok(<String, Object?>{
            'hasNextPage': true,
            'list': <Object?>[
              <String, Object?>{
                'roomId': 55,
                'nickName': '甲',
                'liveName': '歌谣夜',
                'imgPath': '//i/55.jpg',
                'online': 30,
              },
              <String, Object?>{
                'uiType': 'star',
                'data': <String, Object?>{'roomId': '56', 'nickName': '乙', 'hot': 12},
              },
              <String, Object?>{'roomId': 'not-a-room', 'nickName': '丙'},
            ],
          }),
        ],
      });
      final page = await kugou.feed(PageRequest.first);
      // The wrapped `star` row is a room; the row whose id is not a number is not.
      expect(page.items.map((item) => item.ref.contentId), <String>['55', '56']);
      expect(page.hasMore, isTrue);
      expect(page.items.first.title, '歌谣夜');
      expect(transport.unconsumedKeys, isEmpty);
    });

    test('test_categories_areScrapedAndSkipThePersonalRoutes', () async {
      final (_, kugou) = _source(<String, List<String>>{
        _homeKey: <String>[
          '<a href="/pcindex/category/2517?x=1" title="音乐">x</a>'
              '<a href="https://fanxing.kugou.com/pcindex/category/3001" title="我的收藏">y</a>'
              '<a href="/pcindex/category/2517" title="音乐">dup</a>',
        ],
      });
      final categories = await kugou.categories();
      expect(categories.map((category) => category.id), <String>['2517']);
    });

    test('test_anEmptyScrapeFallsBackRatherThanClaimingNoCategories', () async {
      final (_, kugou) = _source(<String, List<String>>{
        _homeKey: <String>['<html></html>'],
      });
      final categories = await kugou.categories();
      expect(categories, isNotEmpty, reason: 'a page we could not read is not a site with no categories');
    });

    test('test_search_checksTheCallbackItAskedFor', () async {
      final (_, kugou) = _source(<String, List<String>>{
        _searchKey: <String>['otherCallback({"status":0,"data":{"anchor":{"list":[]}}});'],
      });
      await expectLater(kugou.search(const SearchQuery(keyword: '甲')), throwsA(isA<KugouFailure>()));
    });

    test('test_search_secondPageAsksNothing', () async {
      final (transport, kugou) = _source(<String, List<String>>{
        _searchKey: <String>['x({"status":0,"data":{"anchor":{"list":[{"roomId":"55","nickName":"甲"}]}}});'],
      });
      final page = await kugou.search(const SearchQuery(keyword: '甲', page: PageRequest(page: 2)));
      expect(page.items, isEmpty);
      expect(transport.requestsTo(_searchKey), 0);
    });
  });

  group('test_kugouSource_room', () {
    test('test_sessionPlusTypeIsOnAirAndBecomesLiveRoomFields', () async {
      final (transport, kugou) = _source(<String, List<String>>{
        _roomKey: <String>[_room()],
      });
      final room = await kugou.room(_room55);
      expect(room.state, LiveRoomState.live);
      expect(room.title, '歌谣夜');
      expect(room.anchorName, '主播甲');
      expect(room.anchorId, '900');
      expect(room.followers, 1200);
      expect(room.introduction, '公告');
      expect(room.viewers, isNull, reason: 'the entry answer states no audience number');
      // liveStatus must not read the media endpoint.
      expect(transport.requestsTo(_mediaKey), 0);
    });

    test('test_liveTypeMinusOneIsTheOnlyOfflineAnswer', () async {
      final (_, kugou) = _source(<String, List<String>>{
        _roomKey: <String>[_room(liveType: -1, session: '')],
      });
      expect((await kugou.room(_room55)).state, LiveRoomState.ended);
    });

    test('test_aMissingSessionIsUnknownNotEnded', () async {
      final (_, kugou) = _source(<String, List<String>>{
        _roomKey: <String>[_room(session: '')],
      });
      expect((await kugou.room(_room55)).state, LiveRoomState.unknown);
    });

    test('test_anAnswerWithoutAnAnchorIsRefused', () async {
      final (_, kugou) = _source(<String, List<String>>{
        _roomKey: <String>[
          _ok(<String, Object?>{'liveType': 1, 'normalRoomInfo': <String, Object?>{}}),
        ],
      });
      await expectLater(kugou.room(_room55), throwsA(isA<KugouFailure>()));
    });
  });

  group('test_kugouSource_play', () {
    test('test_qualitiesAreTheProfilesAndLinesTheUrlsInsideOne', () async {
      final (_, kugou) = _source(<String, List<String>>{
        _roomKey: <String>[_room()],
        _mediaKey: <String>[_media()],
      });
      final qualities = await kugou.qualities(_room55);
      expect(qualities.map((option) => option.id), <String>['flv:1200:1:0', 'hls:1200:1:0']);
      expect(qualities.first.bitrateKbps, 1200);
      expect(qualities.first.label, 'flv 1200');
      // One profile carries two flv urls; only the verified host family survives, so the line menu has one entry.
      final lines = await kugou.lines(_room55);
      expect(lines.map((line) => line.id), <String>['1']);
    });

    test('test_anUnsignedOrForeignHostUrlIsDroppedNotOpened', () async {
      final (_, kugou) = _source(<String, List<String>>{
        _roomKey: <String>[_room()],
        _mediaKey: <String>[
          _media(
            profiles: <Object?>[
              <String, Object?>{
                'rate': 600,
                'codec': 1,
                'layout': 0,
                'httpsFlv': <Object?>['https://evil.example/live/55_1.flv?txSecret=deadbeefdeadbeef&txTime=6553F100'],
              },
            ],
          ),
        ],
      });
      await expectLater(kugou.resolve(_room55), throwsA(isA<KugouFailure>()));
    });

    test('test_aMediaAnswerAboutAnotherRoomIsRefused', () async {
      final (_, kugou) = _source(<String, List<String>>{
        _roomKey: <String>[_room()],
        _mediaKey: <String>[_media(roomId: '66')],
      });
      await expectLater(kugou.resolve(_room55), throwsA(isA<KugouFailure>()));
    });

    test('test_resolve_keepsTheSignedQueryAndTheProfileOnRefresh', () async {
      final (_, kugou) = _source(<String, List<String>>{
        _roomKey: <String>[_room()],
        _mediaKey: <String>[_media()],
      });
      final ticket = await kugou.resolve(_room55, quality: const SelectionRef('hls:1200:1:0'));
      expect(ticket.uri.path.endsWith('.m3u8'), isTrue);
      expect(ticket.uri.queryParameters['txSecret'], 'abcdef0123456789');
      expect(ticket.protocol, MediaProtocol.hls);
      final again = await kugou.refresh(ticket, RefreshReason.expiring);
      expect(again.metadata.extra['kugou.quality'], 'hls:1200:1:0');
      expect(again.uri, ticket.uri);
    });

    test('test_anUnknownLineIsRefusedRatherThanPlayedAsLineOne', () async {
      final (_, kugou) = _source(<String, List<String>>{
        _roomKey: <String>[_room()],
        _mediaKey: <String>[_media()],
      });
      await expectLater(kugou.resolve(_room55, line: const SelectionRef('3')), throwsA(isA<StateError>()));
    });

    test('test_anOfflineRoomIsNamedAsOffline', () async {
      final (_, kugou) = _source(<String, List<String>>{
        _roomKey: <String>[_room(liveType: -1, session: '')],
        _mediaKey: <String>[_media()],
      });
      await expectLater(kugou.resolve(_room55), throwsA(isA<StateError>()));
    });
  });
}
