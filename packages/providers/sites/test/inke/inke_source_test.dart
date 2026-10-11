// Module: test/inke/inke_source_test.dart
// Purpose: The Inke source against a canned transport: finite showcases, tabs, the local filter, the identity
// checks, the verbatim pull url and the two kinds of "nothing to play".
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

const String _topKey = 'webapi.busi.inke.cn/web/Live_top_pc';
const String _hotKey = 'webapi.busi.inke.cn/web/Live_hot_pc';
const String _channelKey = 'webapi.busi.inke.cn/web/Live_channel_pc';
const String _shareKey = 'webapi.busi.inke.cn/web/live_share_pc';

final DateTime _now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
const ContentRef _room77 = ContentRef(sourceId: 'inke.live', contentId: '77', kind: ContentKind.liveRoom);

NetworkClient _client(ScriptedTransport transport) => NetworkClient(
  adapter: transport,
  clock: () => _now,
  settings: const NetworkSettings(retry: RetryPolicy(attempts: 1)),
);

(ScriptedTransport, InkeSource) _source(Map<String, List<String>> script) {
  final transport = ScriptedTransport(script);
  return (transport, InkeSource(client: _client(transport), clock: () => _now));
}

String _ok(Map<String, Object?> data) => jsonEncode(<String, Object?>{'error_code': 0, 'data': data});

const String _streamUrl = 'https://live-pull-ws.ikstatic.cn/live/900_t.flv?sign=abc&wsTime=1';

Map<String, Object?> _row({String uid = '77', String liveId = '900', String nick = '主播甲', String? addr = _streamUrl}) =>
    <String, Object?>{
      'uid': uid,
      'live_id': liveId,
      'nick': nick,
      'portrait': '//p/$uid.png',
      if (addr != null) 'stream_addr': addr,
    };

String _top({List<Object?> rows = const <Object?>[]}) => _ok(<String, Object?>{'list': rows});

String _share({String uid = '77', String liveId = '900', Object? status = 1, String nick = '主播甲', int? errorCode}) =>
    jsonEncode(<String, Object?>{
      'error_code': errorCode ?? 0,
      'data': <String, Object?>{
        if (errorCode == null) ...<String, Object?>{
          'live_uid': uid,
          'liveid': liveId,
          'status': status,
          'live_name': '深夜闲聊',
          'portrait': 'https://c/cover.jpg',
          'start_time': '1700000000',
          'media_info': <String, Object?>{'inke_id': uid, 'nick': nick, 'portrait': 'https://a/$uid.png'},
        },
      },
    });

void main() {
  group('test_inkeSource_showcase', () {
    test('test_feed_isOneFinitePageAndSaysSo', () async {
      final (transport, inke) = _source(<String, List<String>>{
        _topKey: <String>[
          _top(
            rows: <Object?>[
              _row(),
              _row(uid: '78', nick: '乙'),
            ],
          ),
        ],
      });
      final page = await inke.feed(PageRequest.first);
      expect(page.items, hasLength(2));
      expect(page.mode, PageMode.singleShot);
      expect(page.hasMore, isFalse);
      expect(page.total, 2);
      expect(transport.unconsumedKeys, isEmpty);
    });

    test('test_aSecondPageCostsNoRequest', () async {
      final (transport, inke) = _source(<String, List<String>>{
        _topKey: <String>[
          _top(rows: <Object?>[_row()]),
        ],
      });
      final page = await inke.feed(const PageRequest(page: 2));
      expect(page.items, isEmpty);
      expect(transport.requestsTo(_topKey), 0);
    });

    test('test_tabs_areBrowsedByTheirOwnKey', () async {
      final (_, inke) = _source(<String, List<String>>{
        _channelKey: <String>[
          _ok(<String, Object?>{
            'list': <Object?>[
              <String, Object?>{
                'tab_key': 'hot',
                'channel_name': '热门',
                'list': <Object?>[_row()],
              },
              <String, Object?>{'tab_key': 'game', 'channel_name': '游戏', 'list': <Object?>[]},
            ],
          }),
        ],
      });
      final categories = await inke.categories();
      expect(categories.map((category) => category.name), <String>['热门', '游戏']);
      final page = await inke.browse(const ContentQuery(category: 'hot'));
      expect(page.items, hasLength(1));
    });

    test('test_aRepeatedOrUnusableTabKeyIsRefused', () async {
      final (_, inke) = _source(<String, List<String>>{
        _channelKey: <String>[
          _ok(<String, Object?>{
            'list': <Object?>[
              <String, Object?>{'tab_key': 'hot', 'channel_name': '热门', 'list': <Object?>[]},
              <String, Object?>{'tab_key': 'hot', 'channel_name': '重复', 'list': <Object?>[]},
            ],
          }),
        ],
      });
      await expectLater(inke.categories(), throwsA(isA<InkeFailure>()));
    });

    test('test_search_isTheLocalFilterAndOnlyClaimsWhatMatchedHere', () async {
      final (_, inke) = _source(<String, List<String>>{
        _topKey: <String>[
          _top(
            rows: <Object?>[
              _row(nick: '主播甲'),
              _row(uid: '78', nick: '乙'),
            ],
          ),
        ],
        // The filter reads both catalogues, so a search test that scripts only one would fail on the other -
        // which is exactly the "the two showcases are one index" mistake, just in the transport.
        _channelKey: <String>[
          _ok(<String, Object?>{'list': <Object?>[]}),
        ],
      });
      final page = await inke.search(const SearchQuery(keyword: '主 播甲'));
      expect(page.items, isEmpty, reason: 'the filter is a substring match on the name as typed');
      final hit = await inke.search(const SearchQuery(keyword: '主播'));
      expect(hit.items, hasLength(1));
      expect(hit.total, 1);
      expect(hit.hasMore, isFalse);
    });

    test('test_aRowThatNamesNoAnchorIsDroppedNotFatal', () async {
      final (_, inke) = _source(<String, List<String>>{
        _topKey: <String>[
          _top(
            rows: <Object?>[
              _row(),
              <String, Object?>{'uid': '79', 'live_id': '901'},
            ],
          ),
        ],
      });
      final page = await inke.feed(PageRequest.first);
      expect(page.items, hasLength(1));
    });
  });

  group('test_inkeSource_room', () {
    test('test_theAnswerBecomesLiveRoomFields', () async {
      final (_, inke) = _source(<String, List<String>>{
        _shareKey: <String>[_share()],
        _topKey: <String>[
          _top(rows: <Object?>[_row()]),
        ],
        _hotKey: <String>[
          _ok(<String, Object?>{'list': <Object?>[]}),
        ],
        _channelKey: <String>[
          _ok(<String, Object?>{'list': <Object?>[]}),
        ],
      });
      final room = await inke.room(_room77);
      expect(room.state, LiveRoomState.live);
      expect(room.title, '深夜闲聊');
      expect(room.anchorName, '主播甲');
      expect(room.streamId, '900');
      expect(room.startedAt, DateTime.utc(2023, 11, 14, 22, 13, 20));
      // Inke's anonymous surface states no audience number: absent, not zero.
      expect(room.viewers, isNull);
    });

    test('test_theNoBroadcastCodeIsTheOnlyOfflineAnswer', () async {
      final (_, inke) = _source(<String, List<String>>{
        _shareKey: <String>[_share(errorCode: 1099999920)],
      });
      final status = await inke.liveStatus(_room77);
      expect(status.state, LiveRoomState.ended);
    });

    test('test_anUnknownCodeIsNotOffline', () async {
      final (_, inke) = _source(<String, List<String>>{
        _shareKey: <String>[_share(errorCode: 500)],
      });
      await expectLater(inke.liveStatus(_room77), throwsA(isA<InkeFailure>()));
    });

    test('test_anAnswerAboutAnotherUidIsRefused', () async {
      final (_, inke) = _source(<String, List<String>>{
        _shareKey: <String>[_share(uid: '88')],
      });
      await expectLater(inke.room(_room77), throwsA(isA<InkeFailure>()));
    });

    test('test_aStatusThatIsNotOnAirIsRefusedNotPlayed', () async {
      final (_, inke) = _source(<String, List<String>>{
        _shareKey: <String>[_share(status: 0)],
      });
      await expectLater(inke.room(_room77), throwsA(isA<InkeFailure>()));
    });

    test('test_thePollDoesNotReadTheCatalogues', () async {
      final (transport, inke) = _source(<String, List<String>>{
        _shareKey: <String>[_share()],
      });
      await inke.liveStatus(_room77);
      expect(transport.requestsTo(_topKey), 0);
      expect(transport.requestsTo(_hotKey), 0);
    });

    test('test_aNonNumericRoomIdNeverReachesTheEndpoint', () async {
      final (transport, inke) = _source(<String, List<String>>{
        _shareKey: <String>[_share()],
      });
      await expectLater(
        inke.room(const ContentRef(sourceId: 'inke.live', contentId: 'abc/../x', kind: ContentKind.liveRoom)),
        throwsA(isA<InkeFailure>()),
      );
      expect(transport.requestsTo(_shareKey), 0);
    });
  });

  group('test_inkeSource_play', () {
    test('test_resolve_keepsTheSignedUrlByteForByte', () async {
      final (_, inke) = _source(<String, List<String>>{
        _shareKey: <String>[_share()],
        _topKey: <String>[
          _top(rows: <Object?>[_row()]),
        ],
      });
      final ticket = await inke.resolve(_room77);
      expect(ticket.uri.toString(), _streamUrl);
      expect(ticket.uri.queryParameters['sign'], 'abc');
      expect(ticket.metadata.extra['container'], 'flv');
      expect(ticket.metadata.extra['inke.broadcastId'], '900');
      expect(ticket.headers['referer'], 'https://www.inke.cn/');
    });

    test('test_anAddressFromAnotherHostIsNeverAdopted', () async {
      final (_, inke) = _source(<String, List<String>>{
        _shareKey: <String>[_share()],
        _topKey: <String>[
          _top(rows: <Object?>[_row(addr: 'https://evil.example/live/900_t.flv?sign=abc')]),
        ],
        _hotKey: <String>[
          _ok(<String, Object?>{'list': <Object?>[]}),
        ],
        _channelKey: <String>[
          _ok(<String, Object?>{'list': <Object?>[]}),
        ],
      });
      // Not the site's pull host, and not borrowed from a different broadcast under the same uid either.
      await expectLater(inke.resolve(_room77), throwsA(isA<StateError>()));
    });

    test('test_noVerifiedUrlIsNotTheSameAsOffline', () async {
      final (_, inke) = _source(<String, List<String>>{
        _shareKey: <String>[_share()],
        _topKey: <String>[_top()],
        _hotKey: <String>[
          _ok(<String, Object?>{'list': <Object?>[]}),
        ],
        _channelKey: <String>[
          _ok(<String, Object?>{'list': <Object?>[]}),
        ],
      });
      final room = await inke.room(_room77);
      expect(room.isLive, isTrue, reason: 'the broadcast is on air; our catalogue is what came up empty');
      await expectLater(
        inke.resolve(_room77),
        throwsA(predicate<StateError>((error) => error.message.contains('no verified stream address'))),
      );
    });

    test('test_inkeOffersNeitherQualityNorLine', () async {
      final (_, inke) = _source(<String, List<String>>{
        _shareKey: <String>[_share()],
        _topKey: <String>[
          _top(rows: <Object?>[_row()]),
        ],
      });
      await expectLater(inke.resolve(_room77, quality: const SelectionRef('1080p')), throwsA(isA<StateError>()));
      await expectLater(inke.resolve(_room77, line: const SelectionRef('2')), throwsA(isA<StateError>()));
    });

    test('test_refresh_reReadsForAFreshSignedUrlAndRefusesForeignTickets', () async {
      final (_, inke) = _source(<String, List<String>>{
        _shareKey: <String>[_share()],
        _topKey: <String>[
          _top(rows: <Object?>[_row()]),
        ],
      });
      final first = await inke.resolve(_room77);
      final second = await inke.refresh(first, RefreshReason.expiring);
      expect(second.uri, first.uri);
      await expectLater(
        inke.refresh(
          MediaTicket(
            id: 'huya.live/1',
            uri: Uri.parse('https://example/x.flv'),
            kind: MediaKind.live,
            protocol: MediaProtocol.https,
            createdAt: _now.toUtc(),
          ),
          RefreshReason.manual,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('test_inkeApi_roomFromUri', () {
    test('test_aWatchPageLinkYieldsItsAnchor', () {
      expect(InkeApi.roomFromUri(Uri.parse('https://www.inke.cn/liveroom/index.html?uid=77')), '77');
    });

    test('test_aDuplicatedUidIsNotOneAnchor', () {
      expect(InkeApi.roomFromUri(Uri.parse('https://www.inke.cn/liveroom/index.html?uid=77&uid=78')), isNull);
    });

    test('test_anotherHostOrPathIsNotARoomLink', () {
      expect(InkeApi.roomFromUri(Uri.parse('https://evil.cn/liveroom/index.html?uid=77')), isNull);
      expect(InkeApi.roomFromUri(Uri.parse('https://www.inke.cn/other?uid=77')), isNull);
    });
  });
}
