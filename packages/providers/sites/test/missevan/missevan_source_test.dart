// Module: test/missevan/missevan_source_test.dart
// Purpose: The Missevan source against a canned transport: native pagination, the two-line pull, the room/creator
// identity checks and the offline-room rule.
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

const String _metaKey = 'fm.missevan.com/api/v2/meta/data';
const String _listKey = 'fm.missevan.com/api/v2/chatroom/open/list';
const String _searchKey = 'fm.missevan.com/api/v2/chatroom/search';
const String _roomKey = 'fm.missevan.com/api/v2/live/777';

const ContentRef _room777 = ContentRef(sourceId: 'missevan.live', contentId: '777', kind: ContentKind.liveRoom);

NetworkClient _client(ScriptedTransport transport) => NetworkClient(
  adapter: transport,
  settings: const NetworkSettings(retry: RetryPolicy(attempts: 1)),
);

(ScriptedTransport, MissevanSource) _source(Map<String, List<String>> script) {
  final transport = ScriptedTransport(script);
  return (transport, MissevanSource(client: _client(transport)));
}

String _ok(Map<String, Object?> info) => jsonEncode(<String, Object?>{'code': 0, 'info': info});

Map<String, Object?> _row({int open = 1, String roomId = '777'}) => <String, Object?>{
  'room_id': roomId,
  'creator_id': '88',
  'name': '夜话节目',
  'creator_username': '主播甲',
  'cover_url': '//c/$roomId.jpg',
  'creator_iconurl': '//a/88.png',
  'creator_introduction': '简介',
  'announcement': '公告',
  'catalog_name': '电台',
  'status': <String, Object?>{'open': open},
  'statistics': <String, Object?>{'score': 4321, 'attention_count': 999},
  if (open == 1)
    'channel': <String, Object?>{
      'flv_pull_url': 'http://live.example.bilivideo.com/live/$roomId.flv?expires=1800000000',
      'hls_pull_url': 'http://live.example.bilivideo.com/live/$roomId.m3u8?expires=1800000000',
    },
};

String _page({
  Object? p = 1,
  Object? pagesize = missevanServerPageSize,
  List<Object?> rows = const <Object?>[],
  int maxpage = 3,
  int count = 60,
  String key = 'Datas',
}) => _ok(<String, Object?>{
  'pagination': <String, Object?>{'p': p, 'pagesize': pagesize, 'maxpage': maxpage, 'count': count},
  key: rows,
});

void main() {
  group('test_missevanSource_directory', () {
    test('test_feed_reportsTheServersPageSizeAndTotal', () async {
      final (transport, missevan) = _source(<String, List<String>>{
        _listKey: <String>[
          _page(
            rows: <Object?>[
              _row(),
              _row(roomId: '778'),
            ],
          ),
        ],
      });
      final page = await missevan.feed(const PageRequest(pageSize: 50));
      expect(page.items, hasLength(2));
      expect(page.pageSize, missevanServerPageSize);
      expect(page.total, 60);
      expect(page.hasMore, isTrue);
      expect(transport.unconsumedKeys, isEmpty);
    });

    test('test_closedRoomsAreNotOnTheLiveGrid', () async {
      final (_, missevan) = _source(<String, List<String>>{
        _listKey: <String>[
          _page(
            rows: <Object?>[
              _row(),
              _row(open: 0, roomId: '779'),
            ],
            maxpage: 1,
            count: 2,
          ),
        ],
      });
      final page = await missevan.feed(PageRequest.first);
      expect(page.items.map((item) => item.ref.contentId), <String>['777']);
    });

    test('test_aPageThatDoesNotEchoTheRequestIsRefused', () async {
      // Someone else's `p` is a cache or a redirect; paging on top of it duplicates or skips rooms.
      final (_, missevan) = _source(<String, List<String>>{
        _listKey: <String>[
          _page(p: 2, rows: <Object?>[_row()]),
        ],
      });
      await expectLater(missevan.feed(PageRequest.first), throwsA(isA<MissevanFailure>()));
    });

    test('test_tabs_becomeTheTypeColonIdKeyTheListNeeds', () async {
      final (_, missevan) = _source(<String, List<String>>{
        _metaKey: <String>[
          _ok(<String, Object?>{
            'tabs': <Object?>[
              <String, Object?>{'type': 'catalog', 'catalog_id': 5, 'name': '电台', 'icon_url': '//i/5.png'},
              <String, Object?>{'type': 'tag', 'tag_id': 9, 'name': '音乐'},
            ],
          }),
        ],
      });
      final categories = await missevan.categories();
      expect(categories.map((category) => category.id), <String>['catalog:5', 'tag:9']);
      expect(categories.first.icon, 'https://i/5.png');
    });

    test('test_aTabWithoutItsTypedIdFieldIsASchemaChange', () async {
      final (_, missevan) = _source(<String, List<String>>{
        _metaKey: <String>[
          _ok(<String, Object?>{
            'tabs': <Object?>[
              <String, Object?>{'type': 'catalog', 'id': 5, 'name': '字段名不对'},
            ],
          }),
        ],
      });
      await expectLater(missevan.categories(), throwsA(isA<MissevanFailure>()));
    });

    test('test_search_returnsOfflineCreatorsToo', () async {
      final (_, missevan) = _source(<String, List<String>>{
        _searchKey: <String>[
          _page(rows: <Object?>[_row(open: 0)], maxpage: 1, count: 1, key: 'data'),
        ],
      });
      final page = await missevan.search(const SearchQuery(keyword: '主播'));
      expect(page.items, hasLength(1));
    });

    test('test_anEmptyOrControlCharacterKeywordNeverReachesTheEndpoint', () async {
      final (transport, missevan) = _source(<String, List<String>>{
        _searchKey: <String>[_page()],
      });
      await expectLater(missevan.search(const SearchQuery(keyword: '  ')), throwsA(isA<MissevanFailure>()));
      await expectLater(missevan.search(const SearchQuery(keyword: 'a\nb')), throwsA(isA<MissevanFailure>()));
      expect(transport.requestsTo(_searchKey), 0);
    });
  });

  group('test_missevanSource_room', () {
    test('test_theRoomAnswerBecomesLiveRoomFieldsWithItsScoreKind', () async {
      final (_, missevan) = _source(<String, List<String>>{
        _roomKey: <String>[
          _ok(<String, Object?>{
            'room': {..._row(), 'channel': _row()['channel']},
            'creator': <String, Object?>{'user_id': 88, 'iconurl': '//a/88.png', 'introduction': '主播简介'},
          }),
        ],
      });
      final room = await missevan.room(_room777);
      expect(room.state, LiveRoomState.live);
      expect(room.title, '夜话节目');
      expect(room.notice, '公告');
      expect(room.link, 'https://fm.missevan.com/live/777');
      // score is a heat number and attention_count is followers: neither is a headcount of the room.
      expect(room.audienceMetric, LiveAudienceMetric.popularity);
      expect(room.audienceCountsPeople, isFalse);
      expect(room.followers, 999);
    });

    test('test_aRoomAnswerAboutSomeoneElseIsRefused', () async {
      final (_, missevan) = _source(<String, List<String>>{
        _roomKey: <String>[
          _ok(<String, Object?>{
            'room': _row(roomId: '778'),
            'creator': <String, Object?>{'user_id': 88},
          }),
        ],
      });
      await expectLater(missevan.room(_room777), throwsA(isA<MissevanFailure>()));
    });

    test('test_aCreatorBlockNamingAnotherPersonIsRefused', () async {
      final (_, missevan) = _source(<String, List<String>>{
        _roomKey: <String>[
          _ok(<String, Object?>{
            'room': _row(),
            'creator': <String, Object?>{'user_id': 99},
          }),
        ],
      });
      await expectLater(missevan.room(_room777), throwsA(isA<MissevanFailure>()));
    });

    test('test_theMissingRoomCodeIsTheOnlyNotFoundAnswer', () async {
      final (_, missevan) = _source(<String, List<String>>{
        _roomKey: <String>[
          jsonEncode(<String, Object?>{'code': 500030004}),
        ],
      });
      await expectLater(
        missevan.room(_room777),
        throwsA(predicate<MissevanFailure>((failure) => failure.code == 500030004)),
      );
      final (_, other) = _source(<String, List<String>>{
        _roomKey: <String>[
          jsonEncode(<String, Object?>{'code': 400}),
        ],
      });
      // Another non-zero code is a service failure, not proof the broadcast ended.
      await expectLater(other.room(_room777), throwsA(predicate<MissevanFailure>((f) => f.code == 400)));
    });

    test('test_anOfflineRoomNeverLooksAtItsStaleChannelUrls', () async {
      final (_, missevan) = _source(<String, List<String>>{
        _roomKey: <String>[
          _ok(<String, Object?>{'room': _row(open: 0)}),
        ],
      });
      final room = await missevan.room(_room777);
      expect(room.isLive, isFalse);
      expect(room.sitePayload, isEmpty);
      await expectLater(missevan.resolve(_room777), throwsA(isA<StateError>()));
    });
  });

  group('test_missevanSource_play', () {
    setUp(() {});

    test('test_theTwoContainersAreLinesAndTheirQueryIsKeptVerbatim', () async {
      final (_, missevan) = _source(<String, List<String>>{
        _roomKey: <String>[
          _ok(<String, Object?>{'room': _row()}),
        ],
      });
      final lines = await missevan.lines(_room777);
      expect(lines.map((line) => line.id), <String>['1', '2']);
      final ticket = await missevan.resolve(_room777);
      expect(ticket.uri.scheme, 'https');
      expect(ticket.uri.queryParameters['expires'], '1800000000');
      expect(ticket.metadata.extra['container'], 'flv');
      expect(ticket.headers['origin'], 'https://fm.missevan.com');
    });

    test('test_aPullAddressFromAnotherCdnFamilyIsRefused', () async {
      final row = _row();
      (row['channel']! as Map<String, Object?>)['flv_pull_url'] =
          'https://evil.example.com/live/777.flv?expires=1800000000';
      final (_, missevan) = _source(<String, List<String>>{
        _roomKey: <String>[
          _ok(<String, Object?>{'room': row}),
        ],
      });
      await expectLater(missevan.resolve(_room777), throwsA(isA<MissevanFailure>()));
    });

    test('test_anUnreadableExpiryIsRefusedRatherThanPlayed', () async {
      final row = _row();
      (row['channel']! as Map<String, Object?>)['hls_pull_url'] =
          'https://live.example.bilivideo.com/live/777.m3u8?expires=abc';
      final (_, missevan) = _source(<String, List<String>>{
        _roomKey: <String>[
          _ok(<String, Object?>{'room': row}),
        ],
      });
      await expectLater(missevan.resolve(_room777), throwsA(isA<MissevanFailure>()));
    });

    test('test_theSingleProfileIsNotInventedAsTwoQualities', () async {
      final (_, missevan) = _source(<String, List<String>>{
        _roomKey: <String>[
          _ok(<String, Object?>{'room': _row()}),
        ],
      });
      final qualities = await missevan.qualities(_room777);
      expect(qualities.map((option) => option.label), <String>['原画']);
      await expectLater(missevan.resolve(_room777, quality: const SelectionRef('1080p')), throwsA(isA<StateError>()));
    });

    test('test_refresh_reReadsAndStaysOnTheSameContainer', () async {
      final (transport, missevan) = _source(<String, List<String>>{
        _roomKey: <String>[
          _ok(<String, Object?>{'room': _row()}),
          _ok(<String, Object?>{'room': _row()}),
        ],
      });
      final first = await missevan.resolve(_room777, line: const SelectionRef('2'));
      final second = await missevan.resolve(_room777, line: const SelectionRef('1'));
      expect(first.uri.path.endsWith('.m3u8'), isTrue);
      expect(second.uri.path.endsWith('.flv'), isTrue);
      final again = await missevan.refresh(first, RefreshReason.expiring);
      expect(again.uri, first.uri);
      expect(transport.requestsTo(_roomKey), 3);
    });
  });

  group('test_missevanApi_roomFromUri', () {
    test('test_aWatchPageLinkYieldsItsRoom', () {
      expect(MissevanApi.roomFromUri(Uri.parse('https://fm.missevan.com/live/777')), '777');
      expect(MissevanApi.roomFromUri(Uri.parse('https://fm.missevan.com/live/777/')), '777');
    });

    test('test_anyOtherPathOrHostIsNotARoom', () {
      expect(MissevanApi.roomFromUri(Uri.parse('https://fm.missevan.com/live/abc')), isNull);
      expect(MissevanApi.roomFromUri(Uri.parse('https://evil.example/live/777')), isNull);
      expect(MissevanApi.roomFromUri(Uri.parse('https://fm.missevan.com/live/777/x')), isNull);
    });
  });
}
