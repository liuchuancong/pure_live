// Module: test/showroom/showroom_source_test.dart
// Purpose: The SHOWROOM source against a canned transport: the snapshot paging, the two-name room, the status
// agreement rule and the tier menu.
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

const String _onlivesKey = 'www.showroom-live.com/api/live/onlives';
const String _statusKey = 'www.showroom-live.com/api/room/status';
const String _profileKey = 'www.showroom-live.com/api/room/profile';
const String _infoKey = 'www.showroom-live.com/api/live/live_info';
const String _streamsKey = 'www.showroom-live.com/api/live/streaming_url';

final DateTime _now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
const ContentRef _room = ContentRef(sourceId: 'showroom.live', contentId: '123', kind: ContentKind.liveRoom);

NetworkClient _client(ScriptedTransport transport) => NetworkClient(
  adapter: transport,
  clock: () => _now,
  settings: const NetworkSettings(retry: RetryPolicy(attempts: 1)),
);

(ScriptedTransport, ShowroomSource) _source(Map<String, List<String>> script) {
  final transport = ScriptedTransport(script);
  return (transport, ShowroomSource(client: _client(transport), clock: () => _now));
}

Map<String, Object?> _live({
  int roomId = 123,
  String slug = 'abc',
  String name = '名前',
  String telop = 'タイトル',
  int genreId = 0,
  String genreName = '人気',
  int viewNum = 900,
  int premium = 0,
}) => <String, Object?>{
  'room_id': roomId,
  'room_url_key': slug,
  'main_name': name,
  'image_square': 'https://image.showroom-live.com/$roomId.jpg',
  'genre_id': genreId,
  'genre_name': genreName,
  'follower_num': 30,
  'view_num': viewNum,
  'telop': telop,
  'premium_room_type': premium,
};

String _snapshot(List<Object?> genres) => jsonEncode(<String, Object?>{'onlives': genres});

Map<String, Object?> _genre(int id, String name, List<Object?> lives) => <String, Object?>{
  'genre_id': id,
  'genre_name': name,
  'lives': lives,
};

String _profile({
  bool onAir = true,
  int roomId = 123,
  int premium = 0,
  int viewNum = 900,
  int startedAt = 1697000000,
}) => jsonEncode(<String, Object?>{
  'room_id': roomId,
  'room_url_key': 'abc',
  'main_name': '名前',
  'is_onlive': onAir,
  'image_square': 'https://image.showroom-live.com/123.jpg',
  'genre_id': 0,
  'genre_name': '人気',
  'description': '紹介',
  'follower_num': 30,
  'view_num': viewNum,
  'premium_room_type': premium,
  'current_live_started_at': startedAt,
});

String _info({int roomId = 123, int status = 2, String host = 'chat.showroom-live.com', String key = 'k-1'}) =>
    jsonEncode(<String, Object?>{'room_id': roomId, 'live_status': status, 'bcsvr_host': host, 'bcsvr_key': key});

String _streams({bool empty = false}) => jsonEncode(<String, Object?>{
  'streaming_url_list': empty
      ? <Object?>[]
      : <Object?>[
          <String, Object?>{
            'id': 1,
            'type': 'hls_all',
            'label': '自動',
            'quality': 0,
            'url': 'https://a.showroom-txlive.com/hls/123_all.m3u8',
            'is_default': true,
          },
          <String, Object?>{
            'id': 2,
            'type': 'hls',
            'label': '高画質',
            'quality': 1000,
            'url': 'https://a.showroom-txlive.com/hls/123_hi.m3u8',
            'is_default': false,
          },
          <String, Object?>{
            'id': 3,
            'type': 'rtmp',
            'label': 'rtmp',
            'quality': 500,
            'url': 'rtmp://a.showroom-txlive.com/live',
            'is_default': false,
          },
        ],
});

/// The snapshot body, decoded the way the client hands it to the reader.
ShowroomCatalog catalogOf(String body) => showroomCatalog(jsonDecode(body));

void main() {
  group('test_showroomSource_snapshot', () {
    test('test_theSnapshotIsPagedLocallyAndStatesItsTotal', () async {
      final (transport, showroom) = _source(<String, List<String>>{
        _onlivesKey: <String>[
          _snapshot(<Object?>[
            _genre(0, '人気', <Object?>[
              for (var index = 0; index < 35; index++) _live(roomId: 1000 + index, slug: 'room$index'),
            ]),
          ]),
        ],
      });
      final first = await showroom.feed(PageRequest.first);
      expect(first.items, hasLength(showroomPageSize));
      expect(first.total, 35);
      expect(first.hasMore, isTrue);
      final second = await showroom.feed(const PageRequest(page: 2));
      expect(second.items, hasLength(5));
      expect(second.hasMore, isFalse);
      expect(transport.requestsTo(_onlivesKey), 1);
    });

    test('test_thePopularBlockIsGenreZeroAndFallsBackToEverything', () {
      final withZero = catalogOf(
        _snapshot(<Object?>[
          _genre(0, '人気', <Object?>[_live()]),
          _genre(5, '音楽', <Object?>[_live(roomId: 124)]),
        ]),
      );
      expect(withZero.popular.map((live) => live.roomId), <int>[123]);
      final withoutZero = catalogOf(
        _snapshot(<Object?>[
          _genre(5, '音楽', <Object?>[_live(roomId: 124)]),
        ]),
      );
      expect(withoutZero.popular.map((live) => live.roomId), <int>[124]);
    });

    test('test_anIdleGenreCarriesAMessageCellAndARealRowIsStillStrict', () {
      final catalog = catalogOf(
        _snapshot(<Object?>[
          _genre(0, '人気', <Object?>[_live()]),
          _genre(7, '待機', <Object?>[
            <String, Object?>{'cell_type': 7, 'message': 'ただいま放送中はありません'},
          ]),
        ]),
      );
      expect(catalog.genre(7)!.lives, isEmpty);
      // A row that is neither a cell nor a live is the endpoint changing, not an empty genre.
      expect(
        () => showroomCatalog(
          _snapshot(<Object?>[
            _genre(0, '人気', <Object?>[
              <String, Object?>{'name': 'no id'},
            ]),
          ]),
        ),
        throwsA(isA<ShowroomFailure>()),
      );
    });

    test('test_theSameGenreTwiceDoesNotDoubleItsRooms', () {
      final catalog = catalogOf(
        _snapshot(<Object?>[
          _genre(0, '人気', <Object?>[_live()]),
          _genre(0, '人気2', <Object?>[_live(roomId: 999)]),
        ]),
      );
      expect(catalog.genres, hasLength(1));
      expect(catalog.popular.map((live) => live.roomId), <int>[123]);
    });

    test('test_theSnapshotIsReusedForItsHalfMinuteAndFailuresAreNotCached', () async {
      var now = _now;
      final transport = ScriptedTransport(<String, List<String>>{
        _onlivesKey: <String>[
          _snapshot(<Object?>[
            _genre(0, '人気', <Object?>[_live()]),
          ]),
        ],
      });
      final showroom = ShowroomSource(
        client: NetworkClient(
          adapter: transport,
          clock: () => now,
          settings: const NetworkSettings(retry: RetryPolicy(attempts: 1)),
        ),
        clock: () => now,
      );
      await showroom.feed(PageRequest.first);
      now = now.add(const Duration(seconds: 20));
      await showroom.feed(PageRequest.first);
      expect(transport.requestsTo(_onlivesKey), 1);
      now = now.add(const Duration(seconds: 20));
      await showroom.feed(PageRequest.first);
      expect(transport.requestsTo(_onlivesKey), 2);
    });

    test('test_anUnknownGenreIsRefusedAndAnAbsentOneIsMissing', () async {
      final (_, showroom) = _source(<String, List<String>>{
        _onlivesKey: <String>[
          _snapshot(<Object?>[
            _genre(0, '人気', <Object?>[_live()]),
          ]),
        ],
      });
      await expectLater(showroom.browse(const ContentQuery(category: 'not-a-number')), throwsA(isA<ShowroomFailure>()));
      await expectLater(
        showroom.browse(const ContentQuery(category: '77')),
        throwsA(predicate<ShowroomFailure>((ShowroomFailure error) => error.missing)),
      );
    });

    test('test_theSearchIsASnapshotFilterAndItsCountMeansThat', () async {
      final (transport, showroom) = _source(<String, List<String>>{
        _onlivesKey: <String>[
          _snapshot(<Object?>[
            _genre(0, '人気', <Object?>[_live(), _live(roomId: 124, slug: 'other', name: 'ベタ', telop: '別の部屋')]),
          ]),
        ],
      });
      expect((await showroom.search(const SearchQuery(keyword: 'abc'))).items, hasLength(1));
      expect((await showroom.search(const SearchQuery(keyword: '124'))).items.single.ref.contentId, '124');
      expect((await showroom.search(const SearchQuery(keyword: '音楽'))).items, isEmpty);
      expect(transport.requestsTo(_onlivesKey), 1, reason: 'one snapshot serves every page');
      final anchors = await showroom.searchAnchors(const SearchQuery(keyword: 'ベタ'));
      expect(anchors.items.single.name, 'ベタ');
      expect(anchors.items.single.isLiveNow, isTrue);
    });

    test('test_theRoomHasTwoNamesAndTheHandleIsResolvedOnce', () async {
      final (transport, showroom) = _source(<String, List<String>>{
        _statusKey: <String>[
          jsonEncode(<String, Object?>{'room_id': 123}),
        ],
        _profileKey: <String>[_profile()],
        _infoKey: <String>[_info()],
        _streamsKey: <String>[_streams(), _streams()],
        _onlivesKey: <String>[
          _snapshot(<Object?>[
            _genre(0, '人気', <Object?>[_live()]),
          ]),
        ],
      });
      // A pasted handle costs the extra resolution; the durable number does not.
      expect(
        (await showroom.room(const ContentRef(sourceId: 'showroom.live', contentId: 'abc', kind: ContentKind.liveRoom)))
            .link,
        'https://www.showroom-live.com/r/abc',
      );
      expect(transport.requestsTo(_statusKey), 1);
      await showroom.room(_room);
      expect(transport.requestsTo(_statusKey), 1);
    });

    test('test_theUrlFormsAndTheReservedWordsAreUnderstood', () {
      expect(showroomRoomFromUri(Uri.parse('https://www.showroom-live.com/abc')), 'abc');
      expect(showroomRoomFromUri(Uri.parse('https://www.showroom-live.com/r/abc')), 'abc');
      expect(showroomRoomFromUri(Uri.parse('https://www.showroom-live.com/room/profile?room_id=123')), '123');
      expect(showroomRoomFromUri(Uri.parse('https://www.showroom-live.com/search')), isNull);
      expect(showroomRoomFromUri(Uri.parse('https://www.showroom-live.com/room/profile')), isNull);
      expect(showroomRoomFromUri(Uri.parse('https://evil.example/abc')), isNull);
      expect(showroomRoomReference('123'), '123');
      expect(() => showroomSlug('has space'), throwsA(isA<ShowroomFailure>()));
    });
  });

  group('test_showroomSource_room', () {
    test('test_theProfileMustBeAboutTheRoomAsked', () async {
      final (_, showroom) = _source(<String, List<String>>{
        _profileKey: <String>[_profile(roomId: 555)],
      });
      await expectLater(showroom.room(_room), throwsA(isA<ShowroomFailure>()));
    });

    test('test_theTwoEndpointsMustAgreeOrTheRoomIsUnknown', () async {
      final (_, disagree) = _source(<String, List<String>>{
        _profileKey: <String>[_profile(onAir: true)],
        _infoKey: <String>[_info(status: 0)],
      });
      final room = await disagree.room(_room);
      expect(room.state, LiveRoomState.unknown);
      expect(room.extra['showroom.disagreement'], isTrue);
      expect(room.audience, isNull, reason: 'a room that is not agreed-on-air reports no audience');

      final (_, offline) = _source(<String, List<String>>{
        _profileKey: <String>[_profile(onAir: false)],
        _infoKey: <String>[_info(status: 0)],
      });
      expect((await offline.room(_room)).state, LiveRoomState.ended);
    });

    test('test_aStatusAboveTwoIsTheSiteChangingNotAnOfflineRoom', () async {
      final (_, showroom) = _source(<String, List<String>>{
        _profileKey: <String>[_profile()],
        _infoKey: <String>[_info(status: 5)],
      });
      await expectLater(
        showroom.room(_room),
        throwsA(isA<ShowroomFailure>().having((ShowroomFailure e) => e.message, 'message', contains('status 5'))),
      );
    });

    test('test_viewNumIsTrafficNotAHeadcount', () async {
      final (_, showroom) = _source(<String, List<String>>{
        _profileKey: <String>[_profile(viewNum: 900)],
        _infoKey: <String>[_info()],
        _streamsKey: <String>[_streams()],
      });
      final room = await showroom.room(_room);
      expect(room.audiencePrimary, 900);
      expect(room.audienceMetric, LiveAudienceMetric.totalViewers);
      expect(room.startedAt, DateTime.utc(2023, 10, 11, 4, 53, 20));
      expect(showroomStartedAt(0), isNull);
      expect(showroomStartedAt(915148800), isNull, reason: 'a 1999 start is not this broadcast');
      expect(showroomStartedAt(4133980800), isNull, reason: 'a 2101 start is a placeholder, not this broadcast');
    });

    test('test_aPremiumRoomIsGatedWithoutGuessingHow', () async {
      final (_, showroom) = _source(<String, List<String>>{
        _profileKey: <String>[_profile(premium: 2)],
        _infoKey: <String>[_info()],
        _streamsKey: <String>[_streams()],
      });
      final room = await showroom.room(_room);
      expect(room.restriction, LiveRestriction.unknown);
      expect(room.requiresAuth, isTrue);
    });

    test('test_theLiveStatusSkipsTheStreamList', () async {
      final (transport, showroom) = _source(<String, List<String>>{
        _profileKey: <String>[_profile()],
        _infoKey: <String>[_info()],
      });
      expect((await showroom.liveStatus(_room)).state, LiveRoomState.live);
      expect(transport.requestsTo(_streamsKey), 0);
    });

    test('test_theChatHandshakeNeedsBothHostAndKey', () async {
      final (_, showroom) = _source(<String, List<String>>{
        _profileKey: <String>[_profile()],
        _infoKey: <String>[_info(host: 'evil.example/', key: '')],
        _streamsKey: <String>[_streams()],
      });
      final payload = (await showroom.room(_room)).danmakuPayload;
      expect(payload.containsKey('host'), isFalse);
      expect(payload.containsKey('key'), isFalse);
      expect(payload['roomId'], 123);
    });
  });

  group('test_showroomSource_play', () {
    test('test_theMenuIsTheSitesOwnTiersAndThereIsNoLineAxis', () async {
      final (_, showroom) = _source(<String, List<String>>{
        _profileKey: <String>[_profile()],
        _infoKey: <String>[_info()],
        _streamsKey: <String>[_streams()],
      });
      final qualities = await showroom.qualities(_room);
      // hls_all is the site's own automatic tier and ranks above the fixed ones; rtmp is not played here at all.
      expect(qualities.map((option) => option.label), <String>['自動', '原画']);
      expect(qualities.first.isDefault, isTrue);
      await expectLater(showroom.resolve(_room, line: const SelectionRef('2')), throwsA(isA<StateError>()));
    });

    test('test_resolvePicksTheDefaultTierAndKeepsTheChoiceOnRefresh', () async {
      final (transport, showroom) = _source(<String, List<String>>{
        _profileKey: <String>[_profile(), _profile()],
        _infoKey: <String>[_info(), _info()],
        _streamsKey: <String>[_streams(), _streams()],
      });
      final ticket = await showroom.resolve(_room);
      expect(ticket.uri.path, endsWith('123_all.m3u8'));
      expect(ticket.metadata.extra['showroom.label'], '自動');
      final fixed = await showroom.resolve(_room, quality: const SelectionRef('hls:2:1000'));
      expect(fixed.uri.path, endsWith('123_hi.m3u8'));
      expect(fixed.metadata.extra['showroom.quality'], 'hls:2:1000');
      final again = await showroom.refresh(fixed, RefreshReason.expiring);
      expect(again.uri, fixed.uri);
      expect(transport.requestsTo(_streamsKey), 3);
    });

    test('test_anOnAirRoomWithNoStreamIsUnplayable', () async {
      final (_, showroom) = _source(<String, List<String>>{
        _profileKey: <String>[_profile()],
        _infoKey: <String>[_info()],
        _streamsKey: <String>[_streams(empty: true)],
      });
      final room = await showroom.room(_room);
      expect(room.state, LiveRoomState.live);
      expect(room.restriction, LiveRestriction.unplayable);
      expect(await showroom.qualities(_room), isEmpty);
      await expectLater(
        showroom.resolve(_room),
        throwsA(isA<StateError>().having((StateError e) => e.message, 'message', contains('no address'))),
      );
    });

    test('test_aDisagreedRoomIsNotPlayedSilently', () async {
      final (_, showroom) = _source(<String, List<String>>{
        _profileKey: <String>[_profile(onAir: false)],
        _infoKey: <String>[_info(status: 2)],
      });
      await expectLater(
        showroom.resolve(_room),
        throwsA(isA<StateError>().having((StateError e) => e.message, 'message', contains('disagrees'))),
      );
    });

    test('test_anAddressOutsideTheSiteHostsIsNeverOpened', () {
      expect(() => showroomMediaUrl('https://a.showroom-txlive.com/hls/1.m3u8'), returnsNormally);
      expect(() => showroomMediaUrl('https://evil.example/hls/1.m3u8'), throwsA(isA<ShowroomFailure>()));
      expect(() => showroomMediaUrl('http://a.showroom-txlive.com/hls/1.m3u8'), throwsA(isA<ShowroomFailure>()));
      expect(() => showroomMediaUrl('https://a.showroom-txlive.com/hls/1.m3u8#x'), throwsA(isA<ShowroomFailure>()));
      expect(showroomCommentHost('sub.showroom-live.com:443'), '');
      expect(showroomCommentKey('has space'), '');
    });
  });
}
