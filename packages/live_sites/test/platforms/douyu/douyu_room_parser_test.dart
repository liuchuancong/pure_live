import 'dart:convert';

import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_failure.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_room_parser.dart';
import 'package:test/test.dart';

String _body(Object? data, {Object? error}) =>
    jsonEncode({'error': ?error, 'msg': error == null ? '' : 'refused', 'data': ?data});

/// A `cate/list` answer with one category holding [areas].
String _cate(List<Object?> groups, List<Object?> areas) => _body({'cate1Info': groups, 'cate2Info': areas});

/// One `mixList`/`allpage` entry.
Map<String, Object?> _listed({
  Object? rid = 101,
  Object? type = 1,
  String rn = 'title &amp; more',
  String nn = 'Ann',
  Object? ol = '1.2万',
  String av = 'avatar_v3/2026/face.jpg',
  String rs16 = 'https://rs.douyucdn.cn/cover.jpg',
  String c2name = '手游',
}) => {'rid': ?rid, 'type': ?type, 'rn': rn, 'nn': nn, 'ol': ?ol, 'av': av, 'rs16': rs16, 'c2name': c2name};

/// A `betard` room object.
Map<String, Object?> _roomJson({
  Object? roomId = 123456,
  String roomName = '直播中 &amp; 好',
  Object? showStatus = 1,
  Object? videoLoop = 0,
  Object? showTime = 1790733600,
  Object? hot = 4321,
  String ownerName = 'Ann',
  String ownerAvatar = 'avatar_v3/2026/face.jpg',
  String? pic = 'https://rs.douyucdn.cn/cover.jpg',
}) => {
  'room': {
    'room_id': ?roomId,
    'room_name': roomName,
    'show_status': ?showStatus,
    'videoLoop': ?videoLoop,
    'show_time': ?showTime,
    'room_biz_all': {'hot': ?hot},
    'owner_name': ownerName,
    'owner_avatar': ownerAvatar,
    'second_lvl_name': '手游分区',
    'show_details': 'desc &amp; more',
    'room_pic': ?pic,
  },
};

final Matcher _apiChanged = throwsA(isA<DouyuFailure>().having((f) => f.kind, 'kind', DouyuFailureKind.apiChanged));

/// What the envelope makes of [body]: the kind it refuses with, or null when
/// it accepts the answer.
Object? _kindOf(String body, {int status = 200}) {
  try {
    DouyuRoomParser.checked(body, status: status, what: 'x');
    return null;
  } on DouyuFailure catch (failure) {
    return failure.kind;
  }
}

void main() {
  group('the envelope', () {
    test('the shared statuses are named before the body is read', () {
      expect(_kindOf('{}', status: 403), DouyuFailureKind.riskControl);
      expect(_kindOf('{}', status: 412), DouyuFailureKind.rateLimited);
      expect(_kindOf('{}', status: 429), DouyuFailureKind.rateLimited);
      expect(_kindOf('{}', status: 500), DouyuFailureKind.network);
      expect(_kindOf('{"error":1,"msg":"no"}'), DouyuFailureKind.apiChanged);
      expect(_kindOf('{"code":0,"data":{}}'), isNull, reason: 'zero is an answer');
      expect(_kindOf('<html></html>'), DouyuFailureKind.apiChanged);
      expect(_kindOf('[1,2]'), DouyuFailureKind.apiChanged);
      expect(
        _kindOf('{"code":0}', status: 301),
        DouyuFailureKind.apiChanged,
        reason: 'a redirect body is not read as data',
      );
    });

    test("a non-zero error or code carries the platform's message", () {
      expect(
        () => DouyuRoomParser.checked(jsonEncode({'error': 2, 'msg': 'bad param'}), status: 200, what: 'cate/list'),
        throwsA(
          isA<DouyuFailure>().having((f) => f.message, 'message', allOf(contains('cate/list'), contains('bad param'))),
        ),
      );
      expect(
        () => DouyuRoomParser.checked(jsonEncode({'code': -5}), status: 200, what: 'x'),
        throwsA(isA<DouyuFailure>().having((f) => f.message, 'message', contains('error -5'))),
      );
    });
  });

  group('the catalog', () {
    test('each leaf area is matched to its category and sorted by id', () {
      final areas = DouyuRoomParser.areas(
        _cate(
          [
            {'cate1Id': 2, 'cate1Name': '网游 &amp; 手游'},
            {'cate1Name': 'no id'},
            {'cate1Id': 1, 'cate1Name': '单机'},
          ],
          [
            {'cate2Id': 20, 'cate2Name': '王者', 'cate1Id': 2, 'icon': '//cdn.douyucdn.cn/a.png'},
            {'cate2Id': 3, 'cate2Name': '小', 'cate1Id': 1, 'smallIcon': 'https://cdn.douyucdn.cn/b.png'},
            {'cate2Id': 9, 'cate2Name': '没有图', 'cate1Id': 1},
            {'cate2Name': 'no id', 'cate1Id': 1},
            {'cate2Id': 4, 'cate2Name': '别的分类', 'cate1Id': 7, 'pic': 'cdn.douyucdn.cn/c.png'},
          ],
        ),
      );
      expect(areas.map((area) => area.areaId), ['3', '9', '20']);
      expect(areas.first.areaName, '小');
      expect(areas.first.parentAreaId, '1');
      expect(areas.first.parentAreaName, '单机');
      expect(areas.last.parentAreaName, '网游 & 手游', reason: 'entities are decoded once');
      expect(areas.first.iconUrl, 'https://cdn.douyucdn.cn/b.png');
      expect(areas[1].iconUrl, isEmpty, reason: 'no icon, smallIcon or pic is no picture');
      expect(areas[2].iconUrl, 'https://cdn.douyucdn.cn/a.png', reason: 'a scheme-less host is made https');
    });

    test('a catalog whose lists are not lists is a changed API', () {
      expect(() => DouyuRoomParser.areas(_body({'cate1Info': <String, Object?>{}})), _apiChanged);
      expect(() => DouyuRoomParser.areas(_body(null)), _apiChanged);
      expect(DouyuRoomParser.areas(_body({'cate1Info': <Object?>[], 'cate2Info': <Object?>[]})), isEmpty);
    });
  });

  group('the room lists', () {
    test('only type 1 entries are rooms, and the page ends when the list says so', () {
      final first = DouyuRoomParser.roomList(
        _body({
          'rl': [_listed(), _listed(rid: 102, type: 2), _listed(rid: 0), _listed(rid: 103, ol: null)],
          'pgcnt': 3,
        }),
        page: 1,
      );
      expect(first.rooms.map((room) => room.roomId), ['101', '103']);
      expect(first.hasMore, isTrue);
      expect(first.rooms.first.content.title, 'title & more');
      expect(first.rooms.first.anchor!.name, 'Ann');
      expect(first.rooms.first.audience.popularity, 12000, reason: 'the list writes its heat as text');
      expect(first.rooms.first.links.webUrl, 'https://www.douyu.com/101');
      expect(first.rooms.first.area!.areaName, '手游');
      expect(first.rooms.first.broadcast.liveStatus, LiveStatus.live);

      final last = DouyuRoomParser.roomList(
        _body({
          'rl': [_listed()],
          'pgcnt': 3,
        }),
        page: 3,
      );
      expect(last.hasMore, isFalse);
      expect(
        DouyuRoomParser.roomList(_body({'rl': <Object?>[], 'pgcnt': 9}), page: 1).hasMore,
        isFalse,
        reason: 'an empty page ends the paging whatever the count says',
      );
      expect(DouyuRoomParser.roomList(_body({'pgcnt': 0}), page: 1).rooms, isEmpty);
      expect(
        DouyuRoomParser.roomList(
          _body({
            'rl': [_listed()],
            'pgcnt': 0,
          }),
          page: 9,
        ).hasMore,
        isTrue,
        reason: 'allpage always says zero, so only an empty list ends it',
      );
      expect(() => DouyuRoomParser.roomList(_body({'rl': 'not a list'}), page: 1), _apiChanged);
    });

    test('an anchor avatar is a path the CDN serves, and "null" is no path', () {
      expect(
        DouyuRoomParser.anchorAvatar('avatar_v3/2026/face.jpg'),
        'https://apic.douyucdn.cn/upload/avatar_v3/2026/face.jpg_middle.jpg',
      );
      expect(
        DouyuRoomParser.anchorAvatar('/avatar_v3/2026/face.jpg'),
        'https://apic.douyucdn.cn/upload/avatar_v3/2026/face.jpg_middle.jpg',
      );
      expect(DouyuRoomParser.anchorAvatar('https://cdn.example/f.jpg'), 'https://cdn.example/f.jpg');
      expect(DouyuRoomParser.anchorAvatar('//cdn.example/f.jpg'), 'https://cdn.example/f.jpg');
      for (final value in [null, '', '   ', 'null', 'NULL', 'a b/c.jpg', '中文/脸.jpg']) {
        expect(DouyuRoomParser.anchorAvatar(value), isEmpty, reason: '$value is not an address to hand a loader');
      }
    });
  });

  group('search', () {
    test('a live room, a loop room and an offline one are told apart', () {
      List<LiveSearchResult> search(List<Object?> rows) => DouyuRoomParser.searchRooms(_body({'relateShow': rows}));

      final results = search([
        {'rid': 1, 'roomName': 'live', 'isLive': 1, 'roomType': 0, 'hot': '900', 'nickName': 'Ann'},
        {'rid': 2, 'roomName': 'loop', 'isLive': 1, 'roomType': 3},
        {'rid': 3, 'roomName': 'off', 'isLive': 0, 'roomType': 0},
        {'rid': 3, 'roomName': 'odd', 'isLive': 1, 'roomType': 4},
        {'roomName': 'no rid'},
        'not a row',
      ]);
      expect(results, hasLength(4), reason: 'only a row without an rid is dropped');
      final rooms = [for (final result in results) (result as RoomSearchResult).room];
      expect(rooms.map((room) => room.broadcast.liveStatus), [
        LiveStatus.live,
        LiveStatus.replay,
        LiveStatus.offline,
        LiveStatus.offline,
      ]);
      expect(rooms.first.audience.popularity, 900);
      expect(rooms.first.anchor!.name, 'Ann');
    });

    test('a streamer is live only when their room is, and their rid is the room', () {
      final results = DouyuRoomParser.searchAnchors(
        _body({
          'relateUser': [
            {
              'anchorInfo': {
                'rid': 7,
                'nickName': 'Ann &amp; Co',
                'isLive': 1,
                'roomType': 0,
                'avatar': 'avatar_v3/x/y.jpg',
              },
            },
            {
              'anchorInfo': {'rid': 8, 'isLive': 1, 'roomType': 3},
            },
            {
              'anchorInfo': {'nickName': 'no room'},
            },
            {'noInfo': <String, Object?>{}},
          ],
        }),
      );
      expect(results, hasLength(2));
      final anchors = [for (final result in results) (result as AnchorSearchResult).anchor];
      expect(anchors.first.name, 'Ann & Co');
      expect(anchors.first.liveStatus, LiveStatus.live);
      expect(anchors.first.avatarUrl, 'https://apic.douyucdn.cn/upload/avatar_v3/x/y.jpg_middle.jpg');
      expect(anchors.last.liveStatus, LiveStatus.offline, reason: 'a loop room is not the streamer being live');
      expect((results.first as AnchorSearchResult).roomId, '7');
    });
  });

  group('the room detail', () {
    ({LiveRoom room, String rid, Object? gifts}) detail(
      String body, {
      String requestedId = '654321',
      int status = 200,
    }) => DouyuRoomParser.roomDetail(body, requestedId: requestedId, status: status);

    test('the asked-for id stays the identity and the canonical rid rides along', () {
      final read = detail(jsonEncode(_roomJson()));
      expect(read.room.roomId, '654321', reason: 'a follow keeps the id the user knows');
      expect(read.rid, '123456', reason: 'signing, streams and danmaku use the canonical rid');
      expect(read.room.content.title, '直播中 & 好');
      expect(read.room.content.introduction, 'desc & more');
      expect(read.room.anchor!.name, 'Ann');
      expect(read.room.area!.areaName, '手游分区');
      expect(read.room.audience.popularity, 4321);
      expect(read.room.audience.primaryMetric, LiveAudienceMetricType.popularity);
      expect(read.room.broadcast.liveStatus, LiveStatus.live);
      expect(read.room.broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(1790733600000, isUtc: true));
      expect(read.room.links.webUrl, 'https://www.douyu.com/654321');
      expect(read.room.content.coverUrl, 'https://rs.douyucdn.cn/cover.jpg');
      expect(
        detail(jsonEncode(_roomJson()), requestedId: ' 654321 ').room.roomId,
        '654321',
        reason: 'the id is trimmed before it becomes the identity',
      );
    });

    test('a loop room, a replay title and an offline room are three different answers', () {
      expect(detail(jsonEncode(_roomJson(videoLoop: 1))).room.broadcast.liveStatus, LiveStatus.replay);
      expect(detail(jsonEncode(_roomJson(videoLoop: 1))).room.broadcast.startedAt, isNull);
      expect(
        detail(jsonEncode(_roomJson(roomName: '【回放】昨晚'))).room.broadcast.liveStatus,
        LiveStatus.offline,
        reason: 'the title says the show is over even when the status field still says one',
      );
      expect(detail(jsonEncode(_roomJson(showStatus: 2))).room.broadcast.liveStatus, LiveStatus.offline);
      expect(detail(jsonEncode(_roomJson(showStatus: null))).room.broadcast.liveStatus, LiveStatus.offline);
      expect(
        detail(jsonEncode(_roomJson(showStatus: 2))).room.broadcast.startedAt,
        isNull,
        reason: "offline the start time is the last show's",
      );
    });

    test('a JSON-encoded string body is read like the object it holds', () {
      final wrapped = jsonEncode(jsonEncode(_roomJson()));
      expect(detail(wrapped).rid, '123456');
    });

    test('an HTML page, a missing room or an unusable rid is not a room', () {
      expect(
        () => detail('<html><body><p>该房间目前没有开放</p></body></html>'),
        throwsA(
          isA<DouyuFailure>()
              .having((f) => f.kind, 'kind', DouyuFailureKind.notFound)
              .having((f) => f.message, 'message', contains('该房间目前没有开放')),
        ),
        reason: 'the old client showed this as a missing room, and so do we',
      );
      expect(() => detail('{}'), _apiChanged);
      expect(() => detail(jsonEncode({'room': <String, Object?>{}})), _apiChanged);
      for (final id in [0, -1, null, 'abc']) {
        expect(() => detail(jsonEncode(_roomJson(roomId: id))), _apiChanged, reason: 'room_id $id is not a room');
      }
      expect(() => detail(jsonEncode(_roomJson()), status: 403), throwsA(isA<DouyuFailure>()));
      expect(
        () => detail('{"room":1}', status: 301),
        throwsA(isA<DouyuFailure>().having((f) => f.message, 'message', contains('HTTP 301'))),
      );
    });
  });

  group('the rid an address or a page names', () {
    test('a room page names its canonical rid in one of two shapes', () {
      expect(DouyuRoomParser.roomIdInPage('<script>window.room_id = 4321;</script>'), '4321');
      expect(DouyuRoomParser.roomIdInPage(r'{\"room_id\":\"4321\"}'), '4321', reason: 'the escaped form in the data');
      expect(DouyuRoomParser.roomIdInPage('"room_id": 4321'), '4321');
      expect(DouyuRoomParser.roomIdInPage('<html>home page</html>'), isNull);
      expect(DouyuRoomParser.roomIdInPage('window.room_id = 0;'), isNull);
    });

    test('only a douyu address with a numeric first segment is a room', () {
      String? at(String url) => DouyuRoomParser.roomIdAt(Uri.parse(url));

      expect(at('https://www.douyu.com/123456'), '123456');
      expect(at('https://douyu.com/123456'), '123456');
      expect(at('https://m.douyu.com/123456?yexp=1'), '123456');
      expect(at('https://www.douyu.com/靓号'), isNull, reason: 'an alias page has to be followed first');
      expect(at('https://www.douyu.com/'), isNull);
      expect(at('https://example.com/123456'), isNull);
      expect(at('https://douyu.com.evil.example/123'), isNull);
      expect(at('https://www.douyu.com/g/dianjing'), isNull);
    });

    test('a room key is what the platform accepts as an address', () {
      expect(DouyuRoomParser.isRoomKey('123456'), isTrue);
      expect(DouyuRoomParser.isRoomKey('good-name_1'), isTrue);
      expect(DouyuRoomParser.isRoomKey('a' * 64), isTrue);
      for (final key in ['', 'a b', 'a/b', 'a中文', 'a' * 65]) {
        expect(DouyuRoomParser.isRoomKey(key), isFalse, reason: '"$key" is not an address');
      }
      expect(DouyuRoomParser.isNumericRid('123456'), isTrue);
      expect(DouyuRoomParser.isNumericRid('1' * 19), isFalse, reason: 'eighteen digits is as far as it goes');
      expect(DouyuRoomParser.isNumericRid('01'), isTrue, reason: 'a leading zero is still digits');
      expect(DouyuRoomParser.roomId('0'), isNull);
      expect(DouyuRoomParser.roomId(0), isNull);
      expect(DouyuRoomParser.roomId('12'), '12');
      expect(DouyuRoomParser.roomId(12.0), '12');
      expect(DouyuRoomParser.roomId(12.5), isNull);
    });
  });
}
