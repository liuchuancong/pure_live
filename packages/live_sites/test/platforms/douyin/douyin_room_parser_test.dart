import 'dart:convert';

import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_failure.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_room_parser.dart';
import 'package:test/test.dart';

const String _webRid = '127453393722';
const String _broadcast = '7700781210271812361';

/// A picture as douyin sends it: a `url_list` whose first entry is used.
Map<String, Object?> _image(String url) => {
  'url_list': [url],
};

/// `room.stream_url` with one quality — enough for a live room to be playable.
Map<String, Object?> get _streamUrl => {
  'flv_pull_url': {'FULL_HD1': 'https://pull.example.com/a.flv?expire=1790000000'},
};

/// A room object as a detail answer holds it; [override] replaces a field (and
/// a null value removes it).
Map<String, Object?> _room([Map<String, Object?>? override]) => {
  'id_str': _broadcast,
  'status': 2,
  'title': '直播中',
  'owner': {'web_rid': _webRid, 'id_str': '555', 'nickname': '主播'},
  'stats': {'user_count': 12},
  'cover': _image('//p3.douyinpic.com/cover.jpg'),
  'stream_url': _streamUrl,
  ...?override,
};

/// A room with its own identity, for a list that must not collide with [_webRid].
Map<String, Object?> _otherRoom(String webRid, [Map<String, Object?>? override]) => _room({
  'owner': {'web_rid': webRid, 'id_str': '555', 'nickname': '主播'},
  ...?override,
});

/// `room/web/enter/` for [_webRid].
String _enter({List<Object?> rooms = const [], Map<String, Object?>? user, Object? roomStatus}) => jsonEncode({
  'status_code': 0,
  'data': {'data': rooms, 'user': ?user, 'room_status': ?roomStatus},
});

/// `room/reflow/info/` for a broadcast room_id.
String _reflow(Map<String, Object?> room) => jsonEncode({
  'status_code': 0,
  'data': {'room': room},
});

/// `partition/detail/room/v2` for a page asked at [offset].
String _partitionPage(List<Object?> rooms, {Object? count, Object? offset}) => jsonEncode({
  'status_code': 0,
  'data': {'data': rooms, 'count': ?count, 'offset': ?offset},
});

/// An answer whose only content is a platform `status_code`.
String _code(Object code, {Object? msg, Map<String, Object?>? data}) =>
    jsonEncode({'status_code': code, 'status_msg': ?msg, 'data': ?data});

/// The general search's body: every JSON document framed as
/// `<hex byte length>\r\n<document>\r\n` and the body ended by `0\r\n\r\n`.
String _frame(Iterable<String> documents) => [
  for (final document in documents) '${utf8.encode(document).length.toRadixString(16)}\r\n$document\r\n',
  '0\r\n\r\n',
].join();

/// One search answer of [cards].
String _searchOf(List<Map<String, Object?>> cards) => _frame([
  jsonEncode({'data': cards}),
]);

/// A page's React Server Component payload, as the page pushes it.
String _page(Iterable<String> rows) => [for (final row in rows) 'self.__pace_f.push([1,${jsonEncode(row)}]);'].join();

/// A JSON row: `<id>:<document>` on one line.
String _jsonRow(String id, Map<String, Object?> value) => '$id:${jsonEncode(value)}\n';

/// A text row: `<id>:T<hex byte length>,<text>` — the form the page uses for
/// the pieces it does not inline.
String _textRow(String id, String value) => '$id:T${utf8.encode(value).length.toRadixString(16)},$value\n';

Object? _kindOf(void Function() answer) {
  try {
    answer();
    return null;
  } on DouyinFailure catch (failure) {
    return failure.kind;
  }
}

DouyinFailure _failure(void Function() answer) {
  try {
    answer();
  } on DouyinFailure catch (failure) {
    return failure;
  }
  throw StateError('the answer was accepted');
}

void main() {
  group('the shape of an address', () {
    test('more than sixteen digits is a broadcast, not a room', () {
      expect(DouyinRoomParser.isBroadcastId(_broadcast), isTrue);
      expect(DouyinRoomParser.isBroadcastId(_webRid), isFalse);
      expect(DouyinRoomParser.isBroadcastId(' 7700781210271812361 '), isTrue, reason: 'pasted with blanks');
      expect(DouyinRoomParser.isBroadcastId('1' * 16), isFalse, reason: 'sixteen digits is still a room');
      expect(DouyinRoomParser.isBroadcastId('1' * 17), isTrue, reason: 'one more digit makes it a broadcast');
      expect(DouyinRoomParser.isBroadcastId('770078121027181236a'), isFalse);
      expect(DouyinRoomParser.isBroadcastId(''), isFalse);
    });

    test('a room address is one to thirty-two digits', () {
      expect(DouyinRoomParser.isRoomKey(_webRid), isTrue);
      expect(DouyinRoomParser.isRoomKey(' 12 '), isTrue);
      expect(DouyinRoomParser.isRoomKey('1' * 32), isTrue);
      expect(DouyinRoomParser.isRoomKey('1' * 33), isFalse);
      expect(DouyinRoomParser.isRoomKey(_broadcast), isTrue, reason: 'a broadcast is a room address too');
      expect(DouyinRoomParser.isRoomKey('abc'), isFalse, reason: 'douyin has no letter aliases');
      expect(DouyinRoomParser.isRoomKey(''), isFalse);
    });
  });

  group('what a refusal means', () {
    test('a captcha header is risk control whatever the status says', () {
      expect(
        _kindOf(
          () => DouyinRoomParser.checked(
            '{"status_code":0}',
            what: 'feed',
            status: 200,
            headers: {'bdturing-verify': '1'},
          ),
        ),
        DouyinFailureKind.riskControl,
      );
      expect(
        _kindOf(
          () => DouyinRoomParser.checked(
            '{"status_code":0}',
            what: 'feed',
            status: 200,
            headers: {'X-VC-BDTuring-Parameters': 'a=1'},
          ),
        ),
        DouyinFailureKind.riskControl,
        reason: 'the header name is matched any case',
      );
      expect(
        _kindOf(
          () => DouyinRoomParser.checked(
            '{"status_code":0}',
            what: 'feed',
            status: 200,
            headers: {'bdturing-verify': ''},
          ),
        ),
        isNull,
        reason: 'a header with no value says nothing',
      );
    });

    test('the status codes sort themselves out', () {
      expect(_kindOf(() => DouyinRoomParser.checkHttp('{}', 429, const {}, 'feed')), DouyinFailureKind.rateLimited);
      expect(_kindOf(() => DouyinRoomParser.checkHttp('{}', 500, const {}, 'feed')), DouyinFailureKind.network);
      expect(_kindOf(() => DouyinRoomParser.checkHttp('{}', 503, const {}, 'feed')), DouyinFailureKind.network);
      expect(_kindOf(() => DouyinRoomParser.checkHttp('{}', 401, const {}, 'feed')), DouyinFailureKind.riskControl);
      expect(_kindOf(() => DouyinRoomParser.checkHttp('{}', 403, const {}, 'feed')), DouyinFailureKind.riskControl);
      expect(_kindOf(() => DouyinRoomParser.checkHttp('{}', 301, const {}, 'feed')), DouyinFailureKind.apiChanged);
      expect(
        _kindOf(() => DouyinRoomParser.checkHttp('  ', 200, const {}, 'feed')),
        DouyinFailureKind.riskControl,
        reason: 'an empty 200 is a client the edge will not serve',
      );
      expect(_kindOf(() => DouyinRoomParser.checkHttp('{}', 204, const {}, 'feed')), isNull);
      expect(_kindOf(() => DouyinRoomParser.checkHttp('{}', 200, const {}, 'feed')), isNull);
    });

    test('the platform codes inside a good answer', () {
      expect(DouyinRoomParser.checked('{"status_code":0}', what: 'x', status: 200), {'status_code': 0});
      expect(DouyinRoomParser.checked('{}', what: 'x', status: 200), isEmpty, reason: 'no code at all is no error');
      expect(_kindOf(() => DouyinRoomParser.checked('{"status_code":"0"}', what: 'x', status: 200)), isNull);
      expect(
        _kindOf(() => DouyinRoomParser.checked(_code(4001038), what: 'x', status: 200)),
        DouyinFailureKind.notFound,
      );
      expect(
        _kindOf(() => DouyinRoomParser.checked(_code(2483), what: 'x', status: 200)),
        DouyinFailureKind.needsLogin,
      );
      expect(
        _kindOf(() => DouyinRoomParser.checked(_code(20003), what: 'x', status: 200)),
        DouyinFailureKind.needsLogin,
      );
      expect(_kindOf(() => DouyinRoomParser.checked(_code(7), what: 'x', status: 200)), DouyinFailureKind.apiChanged);
      expect(
        _failure(() => DouyinRoomParser.checked(_code(7, msg: '坏掉了'), what: 'x', status: 200)).message,
        contains('x: status_code 7 坏掉了'),
      );
    });

    test('the message is read from whichever field the answer fills', () {
      expect(
        _failure(() => DouyinRoomParser.checked(_code(2483, msg: '顶'), what: 'x', status: 200)).message,
        endsWith('顶'),
      );
      expect(
        _failure(() => DouyinRoomParser.checked(_code(2483, data: {'prompts': '提示'}), what: 'x', status: 200)).message,
        endsWith('提示'),
      );
      expect(
        _failure(() => DouyinRoomParser.checked(_code(2483, data: {'message': '消息'}), what: 'x', status: 200)).message,
        endsWith('消息'),
      );
    });

    test('a body that is not JSON is a challenge page, and the status comes first', () {
      expect(
        _kindOf(() => DouyinRoomParser.checked('<html>验证</html>', what: 'x', status: 200)),
        DouyinFailureKind.riskControl,
      );
      expect(
        _kindOf(() => DouyinRoomParser.checked('[1,2]', what: 'x', status: 200)),
        DouyinFailureKind.riskControl,
        reason: 'an array is not an answer',
      );
      expect(
        _kindOf(() => DouyinRoomParser.checked('<html>验证</html>', what: 'x', status: 429)),
        DouyinFailureKind.rateLimited,
        reason: 'the transport refuses before the body is read',
      );
      expect(
        _failure(() => DouyinRoomParser.checked('<html>验证</html>', what: 'x', status: 200)).message,
        contains('<html>验证'),
        reason: 'the snippet rides along for diagnostics',
      );
    });
  });

  group('the anonymous cookie of a home page', () {
    test('ttwid is the login and UIFID_TEMP rides along', () {
      expect(DouyinRoomParser.anonymousCookie({'set-cookie': 'ttwid=abc; Path=/; HttpOnly'}), 'ttwid=abc');
      expect(
        DouyinRoomParser.anonymousCookie({'Set-Cookie': 'ttwid=abc; Path=/, UIFID_TEMP=xyz; Path=/; Max-Age=60'}),
        'ttwid=abc; UIFID_TEMP=xyz',
        reason: 'the transport joins repeated headers into one string',
      );
      expect(DouyinRoomParser.anonymousCookie({'set-cookie': 'UIFID_TEMP=xyz; Path=/'}), isNull);
      expect(DouyinRoomParser.anonymousCookie({'set-cookie': 'ttwid=; Path=/'}), isNull);
      expect(DouyinRoomParser.anonymousCookie({'set-cookie': ''}), isNull);
      expect(DouyinRoomParser.anonymousCookie(const {}), isNull);
    });
  });

  group('the area id', () {
    test('is the partition and its type, split at the last comma', () {
      expect(DouyinRoomParser.partition('21152,1'), (partition: '21152', type: '1'));
      expect(DouyinRoomParser.partition(' 21152 , 1 '), (partition: '21152', type: '1'));
      expect(DouyinRoomParser.partition('a,b,3'), (partition: 'a,b', type: '3'));
      expect(_kindOf(() => DouyinRoomParser.partition('21152')), DouyinFailureKind.notFound);
      expect(_kindOf(() => DouyinRoomParser.partition(',1')), DouyinFailureKind.notFound);
      expect(_kindOf(() => DouyinRoomParser.partition('21152,')), DouyinFailureKind.notFound);
      expect(_failure(() => DouyinRoomParser.partition('21152')).message, contains('"21152"'));
    });
  });

  group('the areas of the home page', () {
    test('a top lists itself first, then its sub-partitions and their games', () {
      Map<String, Object?> node(String id, String type, String title) => {
        'partition': {'id_str': id, 'type': type, 'title': title},
      };
      final top = <String, Object?>{
        ...node('21152', '1', '游戏'),
        'sub_partition': [
          <String, Object?>{
            ...node('21153', '1', '射击'),
            'sub_partition': [node('21155', '1', '绝地求生'), node('21156', '1', 'APEX')],
          },
          <String, Object?>{
            ...node('21154', '1', '竞技'),
            'sub_partition': [node('21155', '1', '绝地求生')],
          },
        ],
      };
      final page = _page([
        _jsonRow('0', {
          'nodes': {
            'categoryData': [
              top,
              {'no_partition': 1},
            ],
          },
        }),
      ]);
      final areas = DouyinRoomParser.areas(page);
      expect(areas.map((area) => area.areaId), ['21152,1', '21153,1', '21155,1', '21156,1', '21154,1']);
      expect(areas.first.parentAreaId, '21152,1', reason: 'the top area is its own "all"');
      expect(areas[2].parentAreaId, '21153,1', reason: 'a game belongs to the sub-partition it was listed under');
      expect(areas.map((area) => area.areaName), ['游戏', '射击', '绝地求生', 'APEX', '竞技']);
      expect(areas.every((area) => area.platform == 'douyin'), isTrue);
    });

    test('a page that names no categories changed the API', () {
      expect(
        _kindOf(
          () => DouyinRoomParser.areas(
            _page([
              _jsonRow('0', {'other': 1}),
            ]),
          ),
        ),
        DouyinFailureKind.apiChanged,
      );
      expect(
        _kindOf(
          () => DouyinRoomParser.areas(
            _page([
              _jsonRow('0', {
                'nodes': {'categoryData': 'x'},
              }),
            ]),
          ),
        ),
        DouyinFailureKind.apiChanged,
      );
      expect(
        _kindOf(() => DouyinRoomParser.areas(_page([_textRow('0', '{"categoryData":{"categoryData":[]}}')]))),
        DouyinFailureKind.apiChanged,
        reason: 'a text row never carries the payload',
      );
    });

    test('a payload split over two pushes rejoins', () {
      final row = _jsonRow('0', {
        'nodes': {
          'categoryData': [
            {
              'partition': <String, Object?>{'id_str': '1', 'type': '2', 'title': 'A'},
            },
          ],
        },
      });
      final middle = row.length ~/ 2;
      final areas = DouyinRoomParser.areas(_page([row.substring(0, middle), row.substring(middle)]));
      expect(areas.single.areaId, '1,2');
    });
  });

  group('the rooms of a partition', () {
    test('every card is live and the identity is the web_rid first', () {
      final body = _partitionPage(
        [
          {
            'web_rid': _webRid,
            'tag_name': '金铲铲之战',
            'room': {..._room(), 'web_rid': '999', 'category': '720'},
          },
          {'web_rid': '0', 'room': _otherRoom('100')},
          {
            'room': {'id_str': _broadcast, 'title': '甲'},
          },
          {'room': _room()},
          'not a room',
          {
            'web_rid': _webRid,
            'room': _room({'title': '重复的'}),
          },
        ],
        count: 40,
        offset: 36,
      );
      final page = DouyinRoomParser.partitionRooms(body, offset: 0);
      expect(page.rooms.map((room) => room.roomId), [_webRid, '100', _broadcast]);
      expect(page.rooms.first.content.title, '直播中');
      expect(
        page.rooms.first.content.coverUrl,
        'https://p3.douyinpic.com/cover.jpg',
        reason: 'a // address is completed',
      );
      expect(page.rooms.first.anchor?.anchorId, '555');
      expect(page.rooms.first.anchor?.name, '主播');
      expect(page.rooms.first.area?.areaName, '金铲铲之战');
      expect(page.rooms.first.area?.areaId, '720');
      expect(page.rooms[1].area?.areaName, isEmpty, reason: 'the host names no area and none was asked for');
      expect(page.rooms.every((room) => room.broadcast.liveStatus == LiveStatus.live), isTrue);
      expect(page.rooms.first.links.webUrl, 'https://live.douyin.com/$_webRid');
      expect(page.rooms.first.audience.onlineViewers, 12);
      expect(page.rooms.first.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
    });

    test('the asked-for area name fills in when the card says none', () {
      final body = _partitionPage([
        {'web_rid': '1', 'room': _room(), 'tag_name': ''},
        {
          'web_rid': '2',
          'room': _otherRoom('2', {
            'partition_road_map': <Map<String, Object?>>[
              {'title': 'LOL'},
              {'title': '更多'},
            ],
          }),
        },
      ]);
      final rooms = DouyinRoomParser.partitionRooms(body, offset: 0, areaName: '英雄联盟').rooms;
      expect(rooms.first.area?.areaName, '英雄联盟', reason: 'an empty tag is no name');
      expect(rooms[1].area?.areaName, '英雄联盟', reason: 'a road map does not name the partition that was asked for');
      expect(rooms[1].area?.areaId, 'LOL', reason: 'but it does name the area id');
    });

    test('more pages follow only while the count is positive and the offset advances', () {
      Map<String, Object?> card(String id) => {'web_rid': id, 'room': _otherRoom(id)};
      expect(
        DouyinRoomParser.partitionRooms(_partitionPage([card('1')], count: 40, offset: 36), offset: 0).hasMore,
        isTrue,
      );
      expect(
        DouyinRoomParser.partitionRooms(_partitionPage([card('1')], count: 40, offset: 36), offset: 36).hasMore,
        isFalse,
        reason: 'the offset did not move',
      );
      expect(
        DouyinRoomParser.partitionRooms(_partitionPage([card('1')], count: 40, offset: 36), offset: 40).hasMore,
        isFalse,
        reason: 'it went backwards',
      );
      expect(
        DouyinRoomParser.partitionRooms(_partitionPage([card('1')], count: 0, offset: 36), offset: 0).hasMore,
        isFalse,
      );
      expect(
        DouyinRoomParser.partitionRooms(_partitionPage([card('1')], offset: 8), offset: 0).hasMore,
        isTrue,
        reason: 'a missing count is not a refusal to continue',
      );
      expect(
        DouyinRoomParser.partitionRooms(_partitionPage([card('1')], count: 40), offset: 0).hasMore,
        isFalse,
        reason: 'an answer that names no next offset has no next page',
      );
    });

    test('an answer without its room list changed the API', () {
      expect(_kindOf(() => DouyinRoomParser.partitionRooms('{"data":{}}', offset: 0)), DouyinFailureKind.apiChanged);
      expect(_kindOf(() => DouyinRoomParser.partitionRooms('{}', offset: 0)), DouyinFailureKind.apiChanged);
      expect(
        _kindOf(() => DouyinRoomParser.partitionRooms('{"data":{"data":{}}}', offset: 0)),
        DouyinFailureKind.apiChanged,
      );
    });
  });

  group('the recommended feed', () {
    test('both generations of the answer are read', () {
      final older = jsonEncode({
        'data': [
          {
            'id_str': _broadcast,
            'title': '旧格式',
            'owner': {'web_rid': _webRid, 'nickname': '甲', 'avatar_thumb': _image('https://p3/a.jpg')},
          },
        ],
      });
      final newer = jsonEncode({
        'data': {
          'data': [
            {
              'data': jsonEncode(_room({'title': '信封里的房间'})),
              'tag_name': 'lol',
            },
            {
              'room': _otherRoom('777', {'title': 'room 里'}),
            },
            {
              'id_str': '7700781210271812361',
              'nickname': '只有主播',
              'owner': {'nickname': '乙', 'avatar_large': _image('https://p3/c.jpg')},
            },
            {'title': '没有号'},
          ],
        },
      });
      final rooms = [...DouyinRoomParser.feed(older), ...DouyinRoomParser.feed(newer)];
      expect(rooms.map((room) => room.roomId), [_webRid, _webRid, '777', '7700781210271812361']);
      expect(rooms[0].anchor?.avatarUrl, 'https://p3/a.jpg');
      expect(rooms[1].content.title, '信封里的房间', reason: 'a room encoded as a string is still the room');
      expect(rooms[1].area?.areaName, 'lol');
      expect(rooms[2].content.title, 'room 里');
      expect(rooms[3].anchor?.name, '乙');
      expect(rooms[3].content.title, '乙', reason: 'with no title of its own the streamer names the card');
      expect(rooms[3].area?.areaName, DouyinRoomParser.recommendArea, reason: 'a room that names no area is 热门推荐');
    });

    test('the area is the road map or the tags before the default', () {
      final body = jsonEncode({
        'data': {
          'data': [
            {
              'room': _otherRoom('1', {
                'partition_road_map': <Map<String, Object?>>[
                  {'title': '射击'},
                ],
              }),
            },
            {
              'tags': <Map<String, Object?>>[
                {'name': '音乐'},
              ],
              'room': _otherRoom('2'),
            },
            {
              'tags': <Map<String, Object?>>[{}],
              'room': _otherRoom('3'),
            },
          ],
        },
      });
      expect(DouyinRoomParser.feed(body).map((room) => room.area?.areaName), [
        '射击',
        '音乐',
        DouyinRoomParser.recommendArea,
      ]);
    });

    test('a card that is not a room is dropped, and the list must be a list', () {
      expect(DouyinRoomParser.feed('{"data":{"data":[1,null,{}]}}'), isEmpty);
      expect(_kindOf(() => DouyinRoomParser.feed('{}')), DouyinFailureKind.apiChanged);
      expect(_kindOf(() => DouyinRoomParser.feed('{"data":{"other":1}}')), DouyinFailureKind.apiChanged);
    });
  });

  group('the search cards', () {
    final live = <String, Object?>{
      'status': 2,
      'id_str': _broadcast,
      'web_rid': _webRid,
      'title': '搜索里的房间',
      'video_feed_tag': '英雄联盟',
      'category': '720',
      'uid': '555',
      'cover': _image('https://p3/cover.jpg'),
      'owner': {
        'web_rid': _webRid,
        'id_str': '555',
        'nickname': '主播',
        'avatar_large': _image('https://p3/big.jpg'),
        'avatar_thumb': _image('https://p3/small.jpg'),
      },
      'room': {
        'user_count_str': '3.6万',
        'partition_road_map': <Map<String, Object?>>[
          {'title': '射击'},
        ],
      },
    };

    test('a room nested in rawdata is read, and status 2 is live', () {
      final offline = jsonEncode({
        'id_str': '999',
        'status': 4,
        'title': '下播了',
        'owner': {'nickname': '乙'},
      });
      final items = DouyinRoomParser.searchRooms(
        _searchOf([
          {
            'lives': {'rawdata': jsonEncode(live)},
          },
          {
            'aweme_info': {
              'live_info': {'rawdata': offline},
            },
          },
          {'rawdata': live},
          {'nothing': 1},
        ]),
      );
      expect(items, hasLength(2));
      expect(items.first.roomId, _broadcast, reason: 'the broadcast is what a result opens');
      expect(items.first.room.roomId, _webRid, reason: 'the identity of the result is the web_rid of the room');
      expect(items.first.room.anchor?.liveStatus, LiveStatus.live);
      expect(items.first.room.broadcast.liveStatus, LiveStatus.live);
      expect(items[1].room.anchor?.liveStatus, LiveStatus.offline);
      expect(items[1].room.roomId, '999', reason: 'with no web_rid the room id is the identity');
      expect(
        items.first.room.content.coverUrl,
        'https://p3/big.jpg',
        reason: 'the card shows the streamer, not the cover',
      );
      expect(items.first.room.anchor?.avatarUrl, 'https://p3/small.jpg');
      expect(items.first.room.area?.areaName, '英雄联盟');
      expect(items.first.room.area?.areaId, '720');
      expect(items.first.room.audience.onlineViewers, 36000);
      expect(items.first.room.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      expect(items.first.room.anchor?.anchorId, '555');
    });

    test('a title is the room, else the card, else the streamer', () {
      expect(
        DouyinRoomParser.searchRooms(
          _searchOf([
            {
              'live_info': {'rawdata': '{"id_str":"1","title":"房间名"}'},
            },
          ]),
        ).single.room.content.title,
        '房间名',
      );
      expect(
        DouyinRoomParser.searchRooms(
          _searchOf([
            {
              'desc': '描述',
              'lives': {
                'raw_data': {'id_str': '1'},
              },
            },
          ]),
        ).single.room.content.title,
        '描述',
        reason: 'with no title the description of the card names it',
      );
      expect(
        DouyinRoomParser.searchRooms(
          _searchOf([
            {
              'lives': {
                'rawdata': {
                  'id_str': '1',
                  'owner': <String, Object?>{'nickname': '甲'},
                },
              },
            },
          ]),
        ).single.room.content.title,
        '甲',
      );
      expect(
        DouyinRoomParser.searchRooms(
          _searchOf([
            {
              'search_keyword': '主播甲',
              'lives': {
                'rawdata': {'id_str': '1'},
              },
            },
          ]),
        ).single.room.area?.areaName,
        '主播甲',
        reason: 'the keyword searched is the last thing that could name the area',
      );
    });

    test('an unframed body is one document, and framing is all or nothing', () {
      final plain = jsonEncode({
        'data': [
          {
            'data': {'rawdata': '{"id_str":"1"}'},
          },
        ],
      });
      expect(DouyinRoomParser.searchRooms(plain).single.roomId, '1');
      expect(
        _kindOf(() => DouyinRoomParser.searchRooms('ff\r\n{"data":[]}')),
        DouyinFailureKind.apiChanged,
        reason: 'a chunk shorter than its header says',
      );
      expect(
        _kindOf(() => DouyinRoomParser.searchRooms('2\r\n{}\r\nzz\r\n')),
        DouyinFailureKind.apiChanged,
        reason: 'a header that is not a hex length is not a framed body',
      );
      expect(_kindOf(() => DouyinRoomParser.searchRooms('0\r\n\r\n')), DouyinFailureKind.apiChanged);
    });

    test('the room of a card without an identity is not a result', () {
      expect(
        DouyinRoomParser.searchRooms(
          _searchOf([
            {
              'lives': {'rawdata': '{"title":"没有号"}'},
            },
          ]),
        ),
        isEmpty,
      );
      expect(
        _kindOf(() => DouyinRoomParser.searchRooms(_frame([_code(2483)]))),
        DouyinFailureKind.needsLogin,
        reason: 'an anonymous search is answered inside a 200',
      );
    });
  });

  group('the partition search', () {
    test('matches become areas of their own id', () {
      final body = jsonEncode({
        'data': {
          'SearchResult': [
            {
              'partition': {'id_str': '21152', 'type': '1', 'title': '游戏'},
            },
            {
              'partition': {'id_str': '21153'},
            },
            {'other': 1},
          ],
        },
      });
      final areas = DouyinRoomParser.partitionSearch(body);
      expect(areas.map((area) => area.areaId), ['21152,1']);
      expect(areas.single.areaName, '游戏');
      expect(areas.single.parentAreaId, isNull);
      expect(DouyinRoomParser.partitionSearch('{}'), isEmpty);
    });
  });

  group('the detail answers', () {
    test('enter: the room is the first of the list', () {
      expect(_kindOf(() => DouyinRoomParser.enter(_enter(), webRid: _webRid)), DouyinFailureKind.notFound);
      expect(_failure(() => DouyinRoomParser.enter(_enter(), webRid: '777')).message, contains('no room for 777'));
      expect(_kindOf(() => DouyinRoomParser.enter('{"data":{}}', webRid: '1')), DouyinFailureKind.apiChanged);
      expect(_kindOf(() => DouyinRoomParser.enter(_enter(rooms: ['x']), webRid: '1')), DouyinFailureKind.apiChanged);
      final parsed = DouyinRoomParser.enter(_enter(rooms: [_room()]), webRid: ' $_webRid ');
      expect(parsed.room.roomId, _webRid, reason: 'the identity is the one that was asked for, blanks and all');
      expect(parsed.roomId, _broadcast, reason: 'the broadcast rides along for danmaku and deep links');
      expect(parsed.streamUrl, _streamUrl);
      expect(parsed.sessionEnded, isFalse);
      expect(parsed.userUniqueId, isNull);
    });

    test('live or not is the status, else the room_status', () {
      bool liveOf(Map<String, Object?> room, {Object? roomStatus}) =>
          DouyinRoomParser.enter(
            _enter(rooms: [room], roomStatus: roomStatus),
            webRid: _webRid,
          ).room.broadcast.liveStatus ==
          LiveStatus.live;
      expect(liveOf(_room()), isTrue);
      expect(liveOf(_room({'status': '2'})), isTrue, reason: 'a status written as text is still two');
      expect(liveOf(_room({'status': 4})), isFalse);
      expect(liveOf(_room({'status': 0})), isFalse);
      expect(liveOf(_room({'status': null})), isFalse, reason: 'no status at all is not a broadcast');
      expect(liveOf(_room({'status': null}), roomStatus: 0), isTrue);
      expect(liveOf(_room({'status': null}), roomStatus: 2), isFalse, reason: 'room_status 2 is an ended show');
      expect(liveOf(_room({'status': null}), roomStatus: '0'), isTrue);
    });

    test('an offline room is drawn without the live-only fields', () {
      final parsed = DouyinRoomParser.enter(
        _enter(
          rooms: [
            _room({
              'status': 4,
              'cover': _image('https://p3.douyinpic.com/cover.jpg'),
              'stream_url': _streamUrl,
              'stats': {'user_count': 12, 'total_user': 4000},
              'start_time': 1760000000,
            }),
          ],
          user: <String, Object?>{
            'id_str': '555',
            'nickname': '主播',
            'signature': '个人简介',
            'avatar_thumb': _image('https://p3/a.jpg'),
          },
        ),
        webRid: _webRid,
      );
      final room = parsed.room;
      expect(room.content.coverUrl, isEmpty, reason: 'a room that is not on air shows no cover');
      expect(room.audience.onlineViewers, isNull);
      expect(room.audience.totalViewers, isNull);
      expect(room.broadcast.startedAt, isNull);
      expect(room.broadcast.restriction, LiveRestriction.none);
      expect(parsed.streamUrl, isNull, reason: 'the stream of a dead broadcast is not handed to the player');
      expect(room.anchor?.anchorId, '555', reason: 'data.user names the streamer when the room does not');
      expect(room.anchor?.avatarUrl, 'https://p3/a.jpg');
      expect(room.content.introduction, isNull, reason: 'the signature belongs to the owner of the room');
    });

    test('a live room keeps its cover, its start and what it costs to watch', () {
      DouyinRoomParse parse(Map<String, Object?> room) =>
          DouyinRoomParser.enter(_enter(rooms: [room]), webRid: _webRid);
      final started = DateTime.fromMillisecondsSinceEpoch(1760000000 * 1000, isUtc: true);
      expect(parse(_room()).room.content.coverUrl, 'https://p3.douyinpic.com/cover.jpg');
      expect(parse(_room({'start_time': 1760000000})).room.broadcast.startedAt, started);
      expect(parse(_room({'start_time': 1760000000})).room.broadcast.restriction, LiveRestriction.none);
      expect(parse(_room()).room.anchor?.anchorId, '555', reason: 'while live the owner of the room itself wins');
      expect(
        parse(_room({'start_time': 0, 'create_time': 1750000000})).room.broadcast.startedAt,
        DateTime.fromMillisecondsSinceEpoch(1750000000 * 1000, isUtc: true),
        reason: 'lists write a placeholder 0 for the start, so create_time names it',
      );
      expect(parse(_room({'start_time': 'x'})).room.broadcast.startedAt, isNull);
      expect(
        parse(
          _room({
            'stream_url': {'flv_pull_url': <String, Object?>{}},
          }),
        ).room.broadcast.restriction,
        LiveRestriction.unplayable,
        reason: 'a stream with no quality for this client cannot be watched',
      );
      expect(parse(_room({'stream_url': null})).room.broadcast.restriction, LiveRestriction.unplayable);
      expect(
        parse(
          _room({
            'owner': <String, Object?>{'signature': '个人简介'},
          }),
        ).room.content.introduction,
        '个人简介',
      );
    });

    test('the area of a detail answer is its game, else the deepest partition', () {
      String areaOf(Map<String, Object?> room, {Map<String, Object?>? roadMap}) => DouyinRoomParser.enter(
        jsonEncode({
          'data': {
            'data': [room],
            'partition_road_map': ?roadMap,
          },
        }),
        webRid: _webRid,
      ).room.area!.areaName;
      expect(
        areaOf(
          _room({
            'game_data': {
              'game_tag_info': {'game_tag_name': '英雄联盟'},
            },
          }),
        ),
        '英雄联盟',
      );
      expect(
        areaOf(
          _room(),
          roadMap: {
            'partition': {'id_str': '1', 'type': '1', 'title': '游戏'},
            'sub_partition': <String, Object?>{
              'partition': {'id_str': '2', 'type': '1', 'title': '射击'},
            },
          },
        ),
        '射击',
        reason: 'the sub-partition is more specific than the partition',
      );
      expect(
        areaOf(
          _room(),
          roadMap: {
            'partition': <String, Object?>{'id_str': '1', 'type': '1', 'title': '游戏'},
          },
        ),
        '游戏',
      );
      expect(areaOf(_room()), isEmpty, reason: 'a room outside the game partitions names none');
    });

    test('reflow: the identity is the web_rid of the owner and a four has ended', () {
      expect(_kindOf(() => DouyinRoomParser.reflow('{"data":{}}')), DouyinFailureKind.apiChanged);
      expect(
        _kindOf(() => DouyinRoomParser.reflow(_reflow({'owner': <String, Object?>{}}))),
        DouyinFailureKind.apiChanged,
      );
      expect(
        _failure(
          () => DouyinRoomParser.reflow(
            _reflow({
              'owner': {'web_rid': 'abc'},
            }),
          ),
        ).message,
        contains('not numeric'),
      );
      final parsed = DouyinRoomParser.reflow(_reflow(_room({'status': 4, 'start_time': 1760000000})));
      expect(parsed.room.roomId, _webRid);
      expect(parsed.sessionEnded, isTrue, reason: 'status 4 is the queried broadcast being over');
      expect(parsed.roomId, _broadcast);
      expect(parsed.room.broadcast.startedAt, isNull, reason: 'an ended broadcast is not on air');
      expect(DouyinRoomParser.reflow(_reflow(_room())).sessionEnded, isFalse);
      expect(DouyinRoomParser.reflowWebRid(_reflow(_room())), _webRid);
      expect(
        DouyinRoomParser.reflowWebRid(
          _reflow({
            'owner': <String, Object?>{'web_rid': 'abc'},
          }),
        ),
        isNull,
      );
      expect(DouyinRoomParser.reflowWebRid('{}'), isNull);
      expect(DouyinRoomParser.reflowWebRid('<html>'), isNull);
    });
  });

  group('the room page', () {
    Map<String, Object?> pageState({Object? uid = '7418529638527418529'}) => {
      'roomStore': {
        'roomInfo': {
          'room': _room({'cover': r'$9', 'title': r'$$直播中'}),
          'anchor': {'id_str': '555', 'nickname': '主播', 'avatar_thumb': _image('https://p3/a.jpg')},
        },
      },
      'userStore': {
        'odin': {'user_unique_id': uid},
      },
    };

    test('a reference row is resolved, and an empty initial store is passed over', () {
      final html = _page([
        _jsonRow('0', {
          'roomStore': {'roomInfo': <String, Object?>{}},
        }),
        _jsonRow('1', pageState()),
        _textRow('9', 'https://p3.douyinpic.com/cover.jpg'),
      ]);
      final parsed = DouyinRoomParser.roomPage(html, webRid: _webRid);
      expect(parsed.room.content.coverUrl, 'https://p3.douyinpic.com/cover.jpg', reason: 'a dollar field is that row');
      expect(parsed.room.content.title, r'$直播中', reason: 'a doubled dollar is an escaped one, not a reference');
      expect(parsed.room.anchor?.name, '主播', reason: 'the anchor of the page is the streamer');
      expect(parsed.userUniqueId, '7418529638527418529');
      expect(parsed.roomId, _broadcast);
      expect(parsed.room.broadcast.restriction, LiveRestriction.none);
      expect(parsed.room.links.webUrl, 'https://live.douyin.com/$_webRid');
    });

    test('a visitor id is nineteen digits or nothing', () {
      String pageOf(Object? uid) => _page([_jsonRow('0', pageState(uid: uid))]);
      expect(DouyinRoomParser.roomPage(pageOf('741852963852741852'), webRid: _webRid).userUniqueId, isNull);
      expect(DouyinRoomParser.roomPage(pageOf('abc'), webRid: _webRid).userUniqueId, isNull);
      expect(DouyinRoomParser.roomPage(pageOf(null), webRid: _webRid).userUniqueId, isNull);
      expect(
        DouyinRoomParser.roomPage(pageOf('7418529638527418529'), webRid: _webRid).userUniqueId,
        '7418529638527418529',
      );
    });

    test('a page without the room state changed the API', () {
      expect(_kindOf(() => DouyinRoomParser.roomPage('<html>没有状态</html>', webRid: '1')), DouyinFailureKind.apiChanged);
      expect(
        _kindOf(
          () => DouyinRoomParser.roomPage(
            _page([
              _jsonRow('0', {
                'roomStore': {'roomInfo': <String, Object?>{}},
              }),
            ]),
            webRid: '1',
          ),
        ),
        DouyinFailureKind.apiChanged,
      );
      expect(
        _kindOf(
          () => DouyinRoomParser.roomPage(
            _page([_jsonRow('0', pageState())]),
            webRid: '1',
            headers: {'bdturing-verify': '1'},
          ),
        ),
        DouyinFailureKind.riskControl,
      );
    });

    test('the room a page names is read from its state, else its text', () {
      expect(DouyinRoomParser.roomIdInPage(_page([_jsonRow('0', pageState())])), _webRid);
      expect(DouyinRoomParser.roomIdInPage('<html>window._ROUTER_DATA = {"web_rid":"12745"}'), '12745');
      expect(DouyinRoomParser.roomIdInPage('<html>https://live.douyin.com/12745?x=1</html>'), '12745');
      expect(DouyinRoomParser.roomIdInPage('<html>live.douyin.com/abc</html>'), isNull);
      expect(DouyinRoomParser.roomIdInPage('<html></html>'), isNull);
      expect(
        DouyinRoomParser.roomIdInPage(
          _page([
            _jsonRow('0', {
              'roomStore': {
                'roomInfo': {
                  'room': <String, Object?>{'id_str': '12745'},
                },
              },
            }),
          ]),
        ),
        '12745',
        reason: 'with no owner the room id of the page is the id',
      );
    });

    test('a broadcast id is only read off a reflow path', () {
      expect(DouyinRoomParser.broadcastIdInPath('/webcast/room/reflow/$_broadcast'), _broadcast);
      expect(DouyinRoomParser.broadcastIdInPath('reflow/777/'), '777');
      expect(DouyinRoomParser.broadcastIdInPath('/webcast/room/reflow/abc'), isNull);
      expect(DouyinRoomParser.broadcastIdInPath('/webcast/room/reflowx/777'), isNull);
      expect(DouyinRoomParser.broadcastIdInPath('/webcast/room/enter/777'), isNull);
    });
  });

  group('the account', () {
    test('the nickname of a signed-in visitor, or a login is needed', () {
      expect(DouyinRoomParser.account('{"data":{"nickname":"我的号"}}'), '我的号');
      expect(_kindOf(() => DouyinRoomParser.account(_code(20003))), DouyinFailureKind.needsLogin);
      expect(_kindOf(() => DouyinRoomParser.account('{"data":{}}')), DouyinFailureKind.apiChanged);
      expect(_kindOf(() => DouyinRoomParser.account('{"data":{"nickname":""}}')), DouyinFailureKind.apiChanged);
    });
  });

  group('the audience', () {
    test('an exact figure beats the bucketed text', () {
      expect(DouyinRoomParser.onlineViewers({'user_count': 30}), 30);
      expect(DouyinRoomParser.onlineViewers({'user_count': '30'}), 30);
      expect(DouyinRoomParser.onlineViewers({'user_count_str': '30.6万'}), 306000);
      expect(DouyinRoomParser.onlineViewers({'user_count': 0}), 0, reason: 'nobody online is a figure, not a gap');
      expect(DouyinRoomParser.onlineViewers({'online_user_count': false}), isNull, reason: 'a flag is not a count');
      expect(DouyinRoomParser.onlineViewers({'user_count_str': '万'}), isNull);
      expect(DouyinRoomParser.onlineViewers(const {}), isNull);
      expect(
        DouyinRoomParser.onlineViewers({
          'user_count_str': '30.6万',
          'stats': <String, Object?>{'user_count': 12},
        }),
        12,
        reason: 'the exact integer wins over the bucketed text however late it comes',
      );
    });

    test('the display value counts only under the type that means it', () {
      expect(
        DouyinRoomParser.onlineViewers({
          'room_view_stats': {'display_type': 1, 'display_value': 44},
        }),
        44,
      );
      expect(
        DouyinRoomParser.onlineViewers({
          'room_view_stats': <String, Object?>{'display_value': 44},
        }),
        isNull,
      );
      expect(
        DouyinRoomParser.onlineViewers({
          'room_view_stats': {'display_type': 3, 'display_value': 44},
        }),
        isNull,
        reason: 'type 3 displays the cumulative count, not this one',
      );
      expect(
        DouyinRoomParser.onlineViewers({
          'room_view_stats': {'display_type': 1, 'user_count': 7},
        }),
        7,
      );
    });

    test('the cumulative count is the other half of the display', () {
      expect(
        DouyinRoomParser.totalViewers({
          'room_view_stats': {'display_type': 1, 'display_value': 44},
        }),
        isNull,
        reason: 'a room shown by its online count has no cumulative figure',
      );
      expect(
        DouyinRoomParser.totalViewers({
          'room_view_stats': <String, Object?>{'display_value': 44},
        }),
        44,
      );
      expect(
        DouyinRoomParser.totalViewers({
          'room_view_stats': {'display_type': 3, 'display_value': 44},
        }),
        44,
      );
      expect(
        DouyinRoomParser.totalViewers({
          'stats': <String, Object?>{'total_user': 0},
        }),
        isNull,
        reason: 'a zero total says nothing',
      );
      expect(DouyinRoomParser.totalViewers(<String, Object?>{'total_user_str': '1.2亿'}), 120000000);
      expect(
        DouyinRoomParser.totalViewers({
          'room_view_stats': <String, Object?>{'display_value': 5},
          'total_user': 500,
        }),
        5,
        reason: 'the display is the one the room itself shows',
      );
    });

    test('the fields of the room itself are searched before its view stats and stats', () {
      expect(
        DouyinRoomParser.onlineViewers(<String, Object?>{
          'online_user_count': 9,
          'room_view_stats': <String, Object?>{'user_count': 3},
        }),
        9,
      );
      expect(
        DouyinRoomParser.onlineViewers({
          'room_view_stats': <String, Object?>{'online_user_for_anchor': 8},
        }),
        8,
      );
      expect(
        DouyinRoomParser.totalViewers({
          'stats': <String, Object?>{'total_user_str': '2千'},
        }),
        2000,
      );
      expect(
        DouyinRoomParser.totalViewers({
          'room_view_stats': <String, Object?>{'total_user': 3},
          'stats': <String, Object?>{'total_user': 9},
        }),
        3,
      );
    });
  });
}
