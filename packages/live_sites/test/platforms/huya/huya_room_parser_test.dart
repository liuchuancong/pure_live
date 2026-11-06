import 'dart:convert';

import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_failure.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_play_parser.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_room_parser.dart';
import 'package:test/test.dart';

const String _playlist = 'https://a1.livehwc3.cn/vid/123.m3u8?vid=456&definition=yuanhua';

String _body(Object? root) => jsonEncode(root);

/// A `{"status":200,...}` envelope with [data].
String _envelope(Object? data, {int status = 200, String message = ''}) =>
    jsonEncode({'status': status, 'message': message, 'data': ?data});

/// A `profileRoom` body.
String _profile(Map<String, Object?> data, {int status = 200}) => _envelope(data, status: status);

/// A `profileRoom` data object that is live with the given extras.
Map<String, Object?> _liveData({
  Object? liveStatus = 'ON',
  Map<String, Object?>? live,
  Map<String, Object?>? profileInfo,
  Map<String, Object?>? stream,
  Map<String, Object?>? extras,
}) => {
  'liveStatus': liveStatus,
  'liveData': {'roomName': 'room &amp; name', 'introduction': 'intro &amp; more', ...?live},
  'profileInfo': {'nick': 'Ann', 'avatar180': 'https://img.huya.com/a.jpg', ...?profileInfo},
  'welcomeText': 'welcome',
  'stream': ?stream,
  ...?extras,
};

HuyaFailureKind _kindOf(String body, {int status = 200}) {
  try {
    HuyaRoomParser.json(body, status: status, what: 'x');
    return HuyaFailureKind.network;
  } on HuyaFailure catch (failure) {
    return failure.kind;
  }
}

LiveRoom _roomOf(Map<String, Object?> data, {String requestedId = '1', int status = 200}) =>
    HuyaRoomParser.profile(_profile(data), requestedId: requestedId, status: status).room;

void main() {
  group('the address a room is asked for', () {
    test('a numeric id is up to nineteen digits and an alias is a path word', () {
      expect(HuyaRoomParser.isNumericId(' 102411 '), isTrue);
      expect(HuyaRoomParser.isNumericId('1' * 19), isTrue);
      expect(HuyaRoomParser.isNumericId('1' * 20), isFalse);
      expect(HuyaRoomParser.isNumericId('10a'), isFalse);
      expect(HuyaRoomParser.isRoomKey('my-room_1'), isTrue);
      expect(HuyaRoomParser.isRoomKey('a b'), isFalse);
      expect(HuyaRoomParser.isRoomKey(''), isFalse);
    });

    test('only a huya host names a room, and a page segment is not an alias', () {
      Uri at(String path) => Uri.parse('https://www.huya.com/$path');

      expect(HuyaRoomParser.roomIdAt(at('102411')), '102411');
      expect(HuyaRoomParser.roomIdAt(Uri.parse('https://m.huya.com/102411?x=1')), '102411');
      expect(HuyaRoomParser.roomIdAt(at('my-room')), isNull, reason: 'an alias is not a number');
      expect(HuyaRoomParser.roomIdAt(Uri.parse('https://huya.com/1')), '1');
      expect(HuyaRoomParser.roomIdAt(Uri.parse('https://example.com/1')), isNull);
      expect(HuyaRoomParser.roomIdAt(Uri.parse('https://huya.com.evil.example/1')), isNull);

      expect(HuyaRoomParser.aliasAt(at('my-room')), 'my-room');
      expect(HuyaRoomParser.aliasAt(at('102411')), isNull);
      for (final page in ['g', 'search', 'download', 'live', 'cache', 'profile']) {
        expect(HuyaRoomParser.aliasAt(at(page)), isNull, reason: '/$page is a page, not a room');
      }
      expect(HuyaRoomParser.aliasAt(at('SEARCH')), isNull, reason: 'the reserved words are matched case-insensitively');
      expect(HuyaRoomParser.aliasAt(at('')), isNull);
      expect(HuyaRoomParser.aliasAt(Uri.parse('https://example.com/x')), isNull);
    });

    test('a room page names its numeric room in one of two shapes', () {
      expect(HuyaRoomParser.roomIdFromPage('<script>var TT_ROOM_DATA = {"profileRoom":102411.0};</script>'), '102411');
      expect(HuyaRoomParser.roomIdFromPage('{"x":1,"profileRoom":"402863002"}'), '402863002');
      expect(
        HuyaRoomParser.roomIdFromPage('var TT_ROOM_DATA = {"profileRoom":0};\n"profileRoom":77,'),
        isNull,
        reason: 'the loose match reads the first profileRoom in the page, which is the zero it just rejected',
      );
      expect(HuyaRoomParser.roomIdFromPage('var TT_ROOM_DATA = {broken;'), isNull);
      expect(HuyaRoomParser.roomIdFromPage('<html>home</html>'), isNull);
    });
  });

  group('the envelopes', () {
    test('the shared statuses are named before the body, and a 200-range code is read', () {
      expect(_kindOf('{}', status: 403), HuyaFailureKind.riskControl);
      expect(_kindOf('{}', status: 422), HuyaFailureKind.notFound);
      expect(_kindOf('{}', status: 429), HuyaFailureKind.rateLimited);
      expect(_kindOf('{}', status: 503), HuyaFailureKind.network);
      expect(_kindOf('{}', status: 301), HuyaFailureKind.apiChanged);
      expect(_kindOf('[1,2]'), HuyaFailureKind.apiChanged);
      expect(_kindOf('not json'), HuyaFailureKind.apiChanged);
      expect(_kindOf('{}'), isNot(HuyaFailureKind.apiChanged), reason: 'an empty object is a JSON object');
    });

    test("a body status that is not 200 is a changed API, with the platform's words", () {
      expect(
        () => HuyaRoomParser.envelope(_body({'status': 500, 'message': 'inner'}), status: 200, what: 'bussLive'),
        throwsA(
          isA<HuyaFailure>()
              .having((f) => f.kind, 'kind', HuyaFailureKind.apiChanged)
              .having((f) => f.message, 'message', contains('bussLive: status 500 inner')),
        ),
      );
      expect(
        () => HuyaRoomParser.envelope(_body({'status': 'x', 'msg': 'weird'}), status: 200, what: 'x'),
        throwsA(isA<HuyaFailure>().having((f) => f.message, 'message', contains('status null'))),
      );
      expect(HuyaRoomParser.envelope(_envelope(null), status: 200, what: 'x'), isNotEmpty);
    });
  });

  group('the catalog and the lists', () {
    test('a gid written as a number is the area id, and its picture is built', () {
      final areas = HuyaRoomParser.areas(
        _envelope([
          {'gid': 2165.0, 'gameFullName': '英雄联盟 &amp; 手游'},
          {'gid': 0, 'gameFullName': 'no id'},
          {'gameFullName': 'no gid'},
          'not an item',
        ]),
        categoryId: '1',
        categoryName: '网游',
      );
      expect(areas, hasLength(1));
      expect(areas.single.areaId, '2165');
      expect(areas.single.areaName, '英雄联盟 & 手游');
      expect(areas.single.parentAreaId, '1');
      expect(areas.single.parentAreaName, '网游');
      expect(areas.single.iconUrl, 'https://huyaimg.msstatic.com/cdnimage/game/2165-MS.jpg');
      expect(
        () => HuyaRoomParser.areas(_envelope(<Object?>[{}], status: 500), categoryId: '1', categoryName: 'x'),
        throwsA(isA<HuyaFailure>()),
      );
    });

    test('every listed room is live, and the page ends on an empty list or totalPage', () {
      final first = HuyaRoomParser.roomList(
        _envelope({
          'datas': [
            {
              'profileRoom': 102411,
              'roomName': 'name',
              'introduction': 'intro',
              'nick': 'Ann',
              'avatar180': 'https://img.huya.com/a.jpg',
              'gameFullName': '英雄联盟',
              'totalCount': 1234,
              'screenshot': 'https://img.huya.com/s.jpg',
              'isRoomPay': 1,
            },
            {'profileRoom': 0, 'roomName': 'no id'},
            {'roomName': 'no rid'},
            'not an object',
          ],
          'totalPage': 3,
        }),
        page: 1,
      );
      expect(first.rooms, hasLength(1));
      final room = first.rooms.single;
      expect(room.roomId, '102411');
      expect(room.content.title, 'intro', reason: 'the introduction is the title when it is there');
      expect(room.content.coverUrl, 'https://img.huya.com/s.jpg?x-oss-process=style/w338_h190&');
      expect(room.audience.popularity, 1234);
      expect(room.broadcast.restriction, LiveRestriction.paid);
      expect(room.links.webUrl, 'https://www.huya.com/102411');
      expect(first.hasMore, isTrue);

      final coverless = HuyaRoomParser.roomList(
        _envelope({
          'datas': [
            {'profileRoom': 2, 'roomName': 'only a name', 'screenshot': 'https://img.huya.com/s.jpg?x=1'},
          ],
          'totalPage': 0,
        }),
        page: 1,
      );
      expect(coverless.rooms.single.content.title, 'only a name');
      expect(
        coverless.rooms.single.content.coverUrl,
        'https://img.huya.com/s.jpg?x=1',
        reason: 'a queried url is left alone',
      );
      expect(coverless.hasMore, isTrue, reason: 'totalPage 0 only ends on an empty list');
      expect(HuyaRoomParser.roomList(_envelope({'datas': <Object?>[], 'totalPage': 9}), page: 1).hasMore, isFalse);
      expect(
        () => HuyaRoomParser.roomList(_envelope({'no': 1}), page: 1),
        throwsA(isA<HuyaFailure>().having((f) => f.kind, 'kind', HuyaFailureKind.apiChanged)),
      );
      final free = HuyaRoomParser.roomList(
        _envelope({
          'datas': [
            {'profileRoom': 3, 'isRoomPay': 0},
          ],
        }),
        page: 1,
      );
      expect(free.rooms.single.broadcast.restriction, LiveRestriction.none);
    });
  });

  group('search', () {
    test("a live room takes the streamer entry's id when the pair matches", () {
      final results = HuyaRoomParser.searchRooms(
        _body({
          'response': {
            '1': {
              'docs': [
                {'uid': 'u1', 'yyid': 'y1', 'room_id': 111},
                {'uid': 'u1', 'yyid': 'other', 'room_id': 999},
              ],
            },
            '3': {
              'docs': [
                {
                  'uid': 'u1',
                  'yyid': 'y1',
                  'room_id': 1,
                  'game_nick': 'Ann',
                  'game_introduction': 'a &amp; b',
                  'game_screenshot': 'https://img.huya.com/s.jpg',
                  'game_total_count': 50,
                  'gameName': '英雄联盟',
                },
                {'uid': 'u2', 'room_id': 2, 'game_nick': 'Bea'},
                {'uid': 'u1', 'yyid': 'y1', 'room_id': 111, 'game_nick': 'again'},
                {'game_nick': 'no id'},
              ],
            },
          },
        }),
        start: 0,
        rows: 10,
      );
      expect(results.map((result) => (result as RoomSearchResult).room.roomId), ['111', '2']);
      expect((results.first as RoomSearchResult).room.roomId, '111', reason: 'the streamer entry names the room');
      final first = (results.first as RoomSearchResult).room;
      expect(first.content.title, 'a & b');
      expect(first.anchor!.anchorId, 'u1');
      expect(first.anchor!.liveStatus, LiveStatus.live);
      expect(first.audience.popularity, 50);
      expect(first.broadcast.restriction, isNull, reason: 'docs carry no pay flag at all');
      expect(results, hasLength(2), reason: 'the third doc repeats an id the first already answered');
    });

    test('a later search page skips what the earlier ones already gave', () {
      List<Object?> docs(int count) => [
        for (var index = 1; index <= count; index++) {'room_id': index, 'game_nick': 'n$index'},
      ];

      String body() => jsonEncode({
        'response': {
          '1': {'docs': <Object?>[]},
          '3': {'docs': docs(30)},
        },
      });

      // The parser only skips; the caller takes its own page.
      expect(HuyaRoomParser.searchRooms(body(), start: 0, rows: 10), hasLength(30));
      final second = HuyaRoomParser.searchRooms(body(), start: 10, rows: 10);
      expect(second.map((r) => (r as RoomSearchResult).room.roomId).first, '11');
      expect(second, hasLength(20), reason: 'the platform repeats every earlier result, so page two drops them again');
      expect(
        HuyaRoomParser.searchRooms(body(), start: 40, rows: 10),
        isEmpty,
        reason: 'a start past the answer is not clamped: the whole answer is what it already gave',
      );
      expect(
        () => HuyaRoomParser.searchRooms(_body({}), start: 0, rows: 10),
        throwsA(isA<HuyaFailure>().having((f) => f.kind, 'kind', HuyaFailureKind.apiChanged)),
      );
    });

    test('a streamer is live only when the answer says so, and needs a room', () {
      final results = HuyaRoomParser.searchAnchors(
        _body({
          'response': {
            '1': {
              'docs': [
                {
                  'room_id': 5,
                  'game_nick': 'Ann &amp; Co',
                  'gameLiveOn': true,
                  'game_avatarUrl180': 'https://img.huya.com/a.jpg',
                },
                {'room_id': 6, 'gameLiveOn': 1},
                {'room_id': 7, 'gameLiveOn': 0},
                {'game_nick': 'no room'},
              ],
            },
          },
        }),
      );
      expect(results, hasLength(3));
      final anchors = [for (final result in results) (result as AnchorSearchResult)];
      expect(anchors.first.anchor.name, 'Ann & Co');
      expect(anchors.first.anchor.liveStatus, LiveStatus.live);
      expect(anchors.first.anchor.avatarUrl, 'https://img.huya.com/a.jpg');
      expect(anchors[1].anchor.liveStatus, LiveStatus.live, reason: 'the flag is written as a number too');
      expect(anchors.last.anchor.liveStatus, LiveStatus.offline);
      expect(anchors.first.roomId, '5');
    });
  });

  group('the room detail', () {
    test('the state is read as the platform writes it, and an unknown one is a changed API', () {
      for (final (value, expected) in [
        ('ON', LiveStatus.live),
        ('on', LiveStatus.live),
        ('REPLAY', LiveStatus.replay),
        ('OFF', LiveStatus.offline),
        ('OFFLINE', LiveStatus.offline),
        ('CLOSED', LiveStatus.offline),
      ]) {
        expect(_roomOf(_liveData(liveStatus: value)).broadcast.liveStatus, expected, reason: 'liveStatus $value');
      }
      for (final value in ['WAITING', '', null, 1]) {
        expect(
          () => _roomOf(_liveData(liveStatus: value)),
          throwsA(isA<HuyaFailure>().having((f) => f.kind, 'kind', HuyaFailureKind.apiChanged)),
          reason: 'liveStatus $value is not a state this client reads as offline',
        );
      }
    });

    test('a 422 is no room and another body status is a changed answer', () {
      expect(
        () => HuyaRoomParser.profile(_profile({}, status: 422), requestedId: '1'),
        throwsA(isA<HuyaFailure>().having((f) => f.kind, 'kind', HuyaFailureKind.notFound)),
      );
      expect(
        () => HuyaRoomParser.profile(_envelope({}, status: 304), requestedId: '1'),
        throwsA(isA<HuyaFailure>().having((f) => f.kind, 'kind', HuyaFailureKind.apiChanged)),
      );
      expect(
        () => HuyaRoomParser.profile(_body({'status': 200, 'data': 'not a map'}), requestedId: '1'),
        throwsA(isA<HuyaFailure>().having((f) => f.kind, 'kind', HuyaFailureKind.apiChanged)),
      );
      expect(
        () => HuyaRoomParser.profile(_body({'status': 'x'}), requestedId: '1'),
        throwsA(isA<HuyaFailure>().having((f) => f.message, 'message', contains('profileRoom status null'))),
      );
    });

    test('the asked-for id is the identity and the figures ride along', () {
      final read = HuyaRoomParser.profile(
        _profile(
          _liveData(
            live: {'totalCount': '1234', 'startTime': 1790733600, 'uid': 7},
            profileInfo: {'uid': 42, 'nick': 'Ann'},
          ),
        ),
        requestedId: ' my-room ',
      );
      expect(read.room.roomId, 'my-room');
      expect(read.room.links.webUrl, 'https://www.huya.com/my-room');
      expect(read.presenterUid, 42);
      expect(read.room.audience.popularity, 1234, reason: 'the count is written as text');
      expect(read.room.broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(1790733600000, isUtc: true));
      expect(read.room.content.notice, 'welcome');
      expect(read.room.content.coverUrl, isEmpty, reason: 'no screenshot is no cover');
      expect(read.hasStream, isFalse);
      expect(read.lines, isEmpty);
      expect(read.topSid, 0);
      expect(read.subSid, 0);
    });

    test('a live room is paid, password-protected or open, and the flags are read everywhere', () {
      LiveRestriction? of(Map<String, Object?> extras) => _roomOf(_liveData(extras: extras)).broadcast.restriction;

      expect(of({'isRoomPay': 1}), LiveRestriction.paid);
      expect(
        of({
          'liveData': {'isRoomPay': 'true'},
        }),
        LiveRestriction.paid,
      );
      expect(of({'isPayRoom': 1}), LiveRestriction.paid);
      expect(of({'isSecret': '1'}), LiveRestriction.password);
      expect(
        of({'isSecret': 1, 'isRoomPay': 1}),
        LiveRestriction.paid,
        reason: 'a paid room is not asked for a password',
      );
      expect(of({'isRoomPay': 0, 'isSecret': 0}), LiveRestriction.none);
      expect(of({}), isNull, reason: 'the answer said nothing about it');
      expect(
        _roomOf(_liveData(liveStatus: 'OFF')).broadcast.restriction,
        isNull,
        reason: 'an offline room has no restriction to warn about',
      );
    });

    test("the stream ids come from the first positive line, else the room's own pair", () {
      HuyaProfile profile(Map<String, Object?>? stream) => HuyaRoomParser.profile(
        _profile(_liveData(live: {'bitRateInfo': '[]'}, stream: stream)),
        requestedId: '1',
      );

      final listed = profile({
        'baseSteamInfoList': [
          {'lChannelId': 0, 'lSubChannelId': 0},
          {'lChannelId': 10.0, 'lSubChannelId': 20},
          {'lChannelId': 30, 'lSubChannelId': 40},
        ],
      });
      expect(listed.topSid, 10);
      expect(listed.subSid, 20);

      final fallback = profile({'baseSteamInfoList': <Object?>[]});
      expect(
        HuyaRoomParser.profile(
          _profile(_liveData(extras: {'chTopId': 1, 'subChId': 2}, stream: {'baseSteamInfoList': <Object?>[]})),
          requestedId: '1',
        ).topSid,
        1,
      );
      expect(fallback.topSid, 0);
      expect(profile(null).hasStream, isFalse, reason: 'a live room with no stream block cannot play yet');
      expect(profile({'baseSteamInfoList': []}).hasStream, isTrue);
    });

    test('a rate with a blank name is named by its bitrate, a CJK name is kept', () {
      HuyaProfile qualities(Map<String, Object?> live) => HuyaRoomParser.profile(
        _profile(_liveData(live: live)),
        requestedId: '1',
      );

      final named = qualities({
        'bitRateInfo': [
          {'sDisplayName': '蓝光8M', 'iBitRate': 0},
          {'sDisplayName': '蓝光4M', 'iBitRate': 4000},
        ],
      });
      expect(named.qualities.map((quality) => quality.label), ['蓝光8M', '蓝光4M'], reason: 'CJK names are kept');
      expect(named.qualities.map((quality) => quality.qualityId), ['0', '4000']);

      final blank = qualities({
        'bitRateInfo': [
          {'sDisplayName': '', 'iBitRate': 8000},
        ],
      });
      expect(blank.qualities.single.label, '8 Mbps', reason: 'the bitrate names what the platform did not');
      expect(blank.qualities.single.qualityId, '8000');
    });

    test('a replay carries its recording, and without one it is unplayable', () {
      final withReplay = HuyaRoomParser.profile(
        _profile(_liveData(liveStatus: 'REPLAY', live: {'hls': _playlist})),
        requestedId: '77',
      );
      expect(withReplay.room.broadcast.liveStatus, LiveStatus.replay);
      expect(withReplay.room.broadcast.startedAt, isNull, reason: 'a recording has no current start');
      expect(withReplay.room.broadcast.restriction, LiveRestriction.none);
      expect(withReplay.replay?.url, _playlist);
      expect(withReplay.replay?.videoId, 456);
      expect(withReplay.qualities.map((quality) => quality.label), ['原画']);
      expect(withReplay.qualities.single.qualityId, _playlist);
      expect(withReplay.qualities.single.platformOrder, HuyaPlayParser.sourceRank);
      expect(withReplay.lines, isEmpty);

      final bare = HuyaRoomParser.profile(
        _profile(_liveData(liveStatus: 'REPLAY', live: {'hlsUrl': 'https://a.cn/v/1.flv'})),
        requestedId: '77',
      );
      expect(bare.replay, isNull);
      expect(bare.room.broadcast.restriction, LiveRestriction.unplayable);
      expect(bare.qualities, isEmpty);

      expect(
        HuyaRoomParser.profile(
          _profile(_liveData(liveStatus: 'REPLAY', live: {'hls': _playlist.replaceFirst('vid=456&', '')})),
          requestedId: '1',
        ).replay!.videoId,
        isNull,
        reason: 'a recording with no vid is still watchable',
      );
    });

    test("a replay's other definitions are named, deduplicated and ordered", () {
      final qualities = HuyaRoomParser.replayQualities(
        _envelope({
          'moment': {
            'videoInfo': {
              'definitions': [
                {'defName': '超清', 'height': 720, 'm3u8': 'https://a.cn/v/2.m3u8?definition=1300'},
                {'defName': '原画', 'height': 1080, 'url': 'https://a.cn/v/1.m3u8?definition=yuanhua'},
                {'defName': '重复', 'height': 720, 'm3u8': 'https://a.cn/v/2.m3u8?definition=1300'},
                {'defName': '不是播放列表', 'height': 480, 'm3u8': 'https://a.cn/v/3.flv'},
                {'height': 360, 'm3u8': 'https://a.cn/v/4.m3u8?definition=350'},
              ],
            },
          },
        }),
      );
      expect(qualities.map((quality) => quality.qualityId), [
        'https://a.cn/v/1.m3u8?definition=yuanhua',
        'https://a.cn/v/2.m3u8?definition=1300',
        'https://a.cn/v/4.m3u8?definition=350',
      ]);
      expect(qualities.map((quality) => quality.label), ['原画', '超清', '360P']);
      expect(qualities.first.platformOrder, HuyaPlayParser.sourceRank);
      expect(qualities[1].platformOrder, 720);
      expect(qualities.last.platformOrder, 360);
      expect(HuyaRoomParser.replayQualities(_envelope({})), isEmpty);
      expect(HuyaRoomParser.replayQualities(_envelope(null)), isEmpty);
    });

    test('the anonymous uid is positive or nothing', () {
      expect(HuyaRoomParser.anonymousUid(_envelope({'uid': 9})), 9);
      expect(
        HuyaRoomParser.anonymousUid(
          _body({
            'data': {'uid': '9'},
          }),
        ),
        9,
      );
      expect(HuyaRoomParser.anonymousUid(_envelope({'uid': 0})), isNull);
      expect(HuyaRoomParser.anonymousUid(_envelope({'uid': 'x'})), isNull);
      expect(HuyaRoomParser.anonymousUid(_envelope({'uid': 9}), status: 500), isNull);
      expect(HuyaRoomParser.anonymousUid('nope'), isNull);
    });
  });
}
