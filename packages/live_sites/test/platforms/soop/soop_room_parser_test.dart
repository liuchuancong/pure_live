import 'dart:convert';

import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/soop/api/soop_endpoints.dart';
import 'package:live_sites/src/platforms/soop/danmaku/soop_danmaku_codec.dart';
import 'package:live_sites/src/platforms/soop/parsers/soop_failure.dart';
import 'package:live_sites/src/platforms/soop/parsers/soop_json.dart';
import 'package:live_sites/src/platforms/soop/parsers/soop_room_parser.dart';
import 'package:test/test.dart';

const String _id = 'tester_1';
final DateTime _now = DateTime.utc(2026, 10, 1, 12);

/// An `api.php` answer of 3.x: a result and a data object.
String _api(Map<String, Object?> data) => jsonEncode({'result': 1, 'data': data});

/// A bare JSON answer (the player API, the stream manager, the lists).
String _root(Map<String, Object?> root) => jsonEncode(root);

/// A `CHANNEL` of `player_live_api.php`.
String _channel(Map<String, Object?> fields) => jsonEncode({'CHANNEL': fields});

Map<String, Object?> _item([Map<String, Object?>? override]) => {
  'user_id': _id,
  'broad_title': '直播标题',
  'user_nick': '主播甲',
  'broad_start': '2026-09-22 19:59:31',
  'total_view_cnt': '1,234',
  'category_name': '游戏',
  ...?override,
};

Object? _kindOf(void Function() answer) {
  try {
    answer();
    return null;
  } on SoopFailure catch (failure) {
    return failure.kind;
  }
}

SoopFailure _failure(void Function() answer) {
  try {
    answer();
  } on SoopFailure catch (failure) {
    return failure;
  }
  throw StateError('the answer was accepted');
}

void main() {
  group('the answers and their gates', () {
    test('a status keeps its kind, and a body over a megabyte is refused', () {
      expect(_kindOf(() => SoopJson.checkStatus(200, 'x')), isNull);
      expect(_kindOf(() => SoopJson.checkStatus(429, 'x')), SoopFailureKind.rateLimited);
      expect(_kindOf(() => SoopJson.checkStatus(500, 'x')), SoopFailureKind.network);
      expect(_kindOf(() => SoopJson.checkStatus(503, 'x')), SoopFailureKind.network);
      expect(_kindOf(() => SoopJson.checkStatus(401, 'x')), SoopFailureKind.riskControl);
      expect(_kindOf(() => SoopJson.checkStatus(403, 'x')), SoopFailureKind.riskControl);
      expect(_kindOf(() => SoopJson.checkStatus(404, 'x')), SoopFailureKind.apiChanged);
      expect(_kindOf(() => SoopJson.checkStatus(302, 'x')), SoopFailureKind.apiChanged);
      expect(
        _kindOf(() => SoopJson.checkBody('漢' * 400000, 'x', 200)),
        SoopFailureKind.apiChanged,
        reason: 'the limit is counted in UTF-8 bytes',
      );
      expect(_kindOf(() => SoopJson.checkBody('x' * 100, 'x', 200)), isNull);
    });

    test('the two envelopes', () {
      expect(SoopJson.data(_api({'a': 1}), status: 200, what: 'x'), {'a': 1});
      expect(SoopJson.data('{"data":{"a":1}}', status: 200, what: 'x'), {'a': 1}, reason: 'no result is no refusal');
      expect(
        _kindOf(() => SoopJson.data('{"result":0,"data":{}}', status: 200, what: 'x')),
        SoopFailureKind.apiChanged,
      );
      expect(_kindOf(() => SoopJson.data('{"result":"1","data":{}}', status: 200, what: 'x')), isNull);
      expect(_kindOf(() => SoopJson.data('{"result":1}', status: 200, what: 'x')), SoopFailureKind.apiChanged);
      expect(_kindOf(() => SoopJson.root('<html>', status: 200, what: 'x')), SoopFailureKind.apiChanged);
      expect(_kindOf(() => SoopJson.root('[]', status: 200, what: 'x')), SoopFailureKind.apiChanged);
      expect(SoopJson.listField(null, 'x', '{}'), isEmpty);
      expect(_kindOf(() => SoopJson.listField('x', 'x', '{}')), SoopFailureKind.apiChanged);
      expect(SoopJson.tryDecode('not json'), isNull);
    });

    test("the readers of this platform's fields", () {
      expect(SoopJson.string(' a '), 'a');
      expect(SoopJson.string('   '), isNull);
      expect(SoopJson.string(7), '7');
      expect(SoopJson.integer('12'), 12);
      expect(SoopJson.integer(12.0), 12, reason: 'a double that is whole is still an int');
      expect(SoopJson.integer(12.5), isNull);
      expect(SoopJson.count(-3), isNull);
      expect(SoopJson.count(0), 0);
      expect(SoopJson.display('A&amp;B &lt;x&gt;'), 'A&B <x>');
      expect(SoopJson.text(null), isEmpty, reason: 'a missing field is written as the empty string');
      for (final value in [true, 1, '1', 'Y', 'yes', 'TRUE', 1.0]) {
        expect(SoopJson.truthy(value), isTrue, reason: '$value');
      }
      for (final value in [false, 0, '0', 'N', 'no', null, 2]) {
        expect(SoopJson.truthy(value), isFalse, reason: '$value');
      }
      expect(SoopJson.url('https://a.co/x.m3u8')?.host, 'a.co');
      expect(SoopJson.url('ftp://a.co/x'), isNull);
      expect(SoopJson.url(''), isNull);
      expect(SoopJson.image('https://img.sooplive.co.kr/a.jpg'), 'https://img.sooplive.co.kr/a.jpg');
      expect(SoopJson.image('//img.sooplive.co.kr/a.jpg'), 'https://img.sooplive.co.kr/a.jpg');
      expect(SoopJson.image(null), isEmpty);
    });
  });

  group('the catalog and the lists', () {
    test('one page of areas, and the next page rule of 3.x', () {
      final body = _api({
        'list': [
          {'category_no': '1', 'category_name': 'LOL&amp;游戏', 'cate_img': '//img.sooplive.co.kr/1.jpg'},
          {'category_no': '2', 'category_name': '音乐'},
          {'category_name': '没有号'},
          'not a row',
        ],
        'is_more': 'Y',
      });
      final page = SoopRoomParser.categoryPage(body);
      expect(page.areas.map((area) => area.areaId), ['1', '2']);
      expect(page.areas.first.areaName, 'LOL&游戏');
      expect(page.areas.first.iconUrl, 'https://img.sooplive.co.kr/1.jpg');
      expect(page.areas.first.parentAreaId, SoopEndpoints.category.id);
      expect(page.areas.first.parentAreaName, SoopEndpoints.category.name);
      expect(page.hasMore, isTrue);
      expect(
        SoopRoomParser.categoryPage(
          _api({
            'list': [
              for (var i = 0; i < 120; i++) {'category_no': '$i'},
            ],
          }),
        ).hasMore,
        isTrue,
        reason: 'without the flag a full page means another one',
      );
      expect(
        SoopRoomParser.categoryPage(
          _api({
            'list': [
              {'category_no': '1'},
            ],
          }),
        ).hasMore,
        isFalse,
      );
      expect(
        SoopRoomParser.categoryPage(
          _api({
            'list': [
              for (var i = 0; i < 120; i++) {'category_no': '1'},
            ],
            'is_more': 'N',
          }),
        ).hasMore,
        isFalse,
        reason: 'the flag says so, and every row shares one id',
      );
      expect(
        SoopRoomParser.categoryPage(_api({'list': [], 'is_more': 'Y'})).hasMore,
        isFalse,
        reason: 'an empty page has nothing to continue',
      );
    });

    test('the three list shapes make the same cards', () {
      final area = SoopRoomParser.areaRooms(
        _api({
          'list': [
            _item({'thumbnail': 'https://img.sooplive.co.kr/t.jpg', 'user_profile_img': '//img.sooplive.co.kr/a.jpg'}),
          ],
        }),
        areaName: '游戏分区',
      );
      final recommend = SoopRoomParser.recommendRooms(
        _root({
          'broad': [
            _item({'broad_thumb': 'https://img.sooplive.co.kr/r.jpg'}),
          ],
        }),
      );
      final search = SoopRoomParser.searchRooms(
        _root({
          'RESULT': '1',
          'REAL_BROAD': [
            _item({'broad_img': 'https://img.sooplive.co.kr/s.jpg', 'broad_cate_name': '电竞'}),
          ],
        }),
      );
      for (final room in [area.single, recommend.single, search.single]) {
        expect(room.roomId, _id);
        expect(room.anchor?.name, '主播甲');
        expect(room.broadcast.liveStatus, LiveStatus.live, reason: 'the lists only carry what is on air');
        expect(room.audience.onlineViewers, 1234);
        expect(room.broadcast.startedAt, DateTime.utc(2026, 9, 22, 10, 59, 31));
        expect(room.links.webUrl, 'https://play.sooplive.co.kr/$_id');
      }
      expect(area.single.content.coverUrl, 'https://img.sooplive.co.kr/t.jpg');
      expect(area.single.anchor?.avatarUrl, 'https://img.sooplive.co.kr/a.jpg');
      expect(area.single.area?.areaName, '游戏分区');
      expect(recommend.single.area?.areaName, '游戏', reason: 'the recommendation names its own category');
      expect(search.single.content.coverUrl, 'https://img.sooplive.co.kr/s.jpg');
      expect(search.single.area?.areaName, '电竞');
      expect(
        SoopRoomParser.recommendRooms(
          _root({
            'broad': [
              {'user_nick': '没有号'},
            ],
          }),
        ),
        isEmpty,
      );
      expect(
        SoopRoomParser.areaRooms(
          _api({
            'list': [
              _item({'user_id': null}),
            ],
          }),
          areaName: 'x',
        ),
        isEmpty,
      );
    });

    test('the search falls back to the field 3.x read', () {
      final both = SoopRoomParser.searchRooms(
        _root({
          'REAL_BROAD': [
            _item({'broad_cate_name': '新字段', 'standard_broad_cate_name': '旧字段'}),
          ],
        }),
      );
      expect(both.single.area?.areaName, '新字段');
      final older = SoopRoomParser.searchRooms(
        _root({
          'REAL_BROAD': [
            _item({'standard_broad_cate_name': '旧字段'}),
          ],
        }),
      );
      expect(older.single.area?.areaName, '旧字段');
      expect(
        _failure(() => SoopRoomParser.searchRooms(_root({'RESULT': '0', 'REAL_BROAD': []}))).message,
        contains('RESULT 0'),
      );
      expect(SoopRoomParser.searchRooms(_root({'RESULT': '1', 'REAL_BROAD': []})), isEmpty);
      expect(
        _kindOf(() => SoopRoomParser.searchRooms(_root({'RESULT': 1, 'REAL_BROAD': 'x'}))),
        SoopFailureKind.apiChanged,
      );
    });

    test('a card without a streamer id is not a card', () {
      expect(SoopRoomParser.card(_item({'user_id': '  '}), cover: null), isNull);
      final card = SoopRoomParser.card(
        _item({'total_view_cnt': null, 'pc_view_cnt': '7', 'mobile_view_cnt': '3'}),
        cover: null,
        area: '',
      )!;
      expect(
        card.anchor?.avatarUrl,
        SoopEndpoints.avatar(_id),
        reason: "a list without a picture builds the platform's own",
      );
      expect(card.audience.onlineViewers, 10);
      expect(card.area, isNull, reason: 'an empty area name is no area');
      expect(card.content.title, '直播标题');
    });
  });

  group('the audience of a list or a channel', () {
    test('the totals come first, the split counts only add up', () {
      expect(SoopRoomParser.onlineViewers({'total_view_cnt': '1,234'}), '1234');
      expect(SoopRoomParser.onlineViewers({'view_cnt': 42}), '42');
      expect(SoopRoomParser.onlineViewers({'VIEW_CNT': '07'}), '7');
      expect(SoopRoomParser.onlineViewers({'total_view_cnt': '0', 'view_cnt': '9'}), '9');
      expect(SoopRoomParser.onlineViewers({'total_view_cnt': '0'}), '0');
      expect(
        SoopRoomParser.onlineViewers({'total_view_cnt': 'null', 'pc_view_cnt': '5', 'mobile_view_cnt': '5'}),
        '10',
      );
      expect(SoopRoomParser.onlineViewers({'pc_view_cnt': '5', 'mobile_view_cnt': '0'}), '5');
      expect(SoopRoomParser.onlineViewers({'current_view_cnt': '3', 'm_current_view_cnt': '4'}), '7');
      expect(SoopRoomParser.onlineViewers({'pc_view_cnt': '0', 'mobile_view_cnt': '0'}), '0');
      expect(SoopRoomParser.onlineViewers({'pc_view_cnt': 'abc'}), isEmpty);
      expect(SoopRoomParser.onlineViewers({}), isEmpty);
      expect(SoopRoomParser.onlineViewers({'total_view_cnt': '1.5万'}), isEmpty, reason: 'no bucketed text here');
    });
  });

  group('player_live_api, the room itself', () {
    test('the channel must be there and must answer', () {
      expect(SoopRoomParser.channel(_channel({'RESULT': '1'})).result, 1);
      expect(_kindOf(() => SoopRoomParser.channel(_root({'CHANNEL': 'x'}))), SoopFailureKind.apiChanged);
      expect(_kindOf(() => SoopRoomParser.channel(_root({}))), SoopFailureKind.apiChanged);
      expect(_failure(() => SoopRoomParser.channel(_root({'CHANNEL': {}}))).message, contains('no CHANNEL.RESULT'));
      expect(_kindOf(() => SoopRoomParser.channel('<html>', status: 429)), SoopFailureKind.rateLimited);
    });

    ({LiveRoom room, SoopRoomData? data, SoopDanmakuArgs? danmaku}) detail(
      Map<String, Object?> fields, {
      bool withDanmaku = false,
      String requestedId = _id,
      DateTime? now,
    }) => SoopRoomParser.roomDetail(
      _channel(fields),
      requestedId: requestedId,
      now: now ?? _now,
      withDanmaku: withDanmaku,
    );

    test('the answers that carry no stream', () {
      expect(detail({'RESULT': 0}).room.broadcast.liveStatus, LiveStatus.offline);
      expect(detail({'RESULT': '0'}).room.roomId, _id);
      expect(detail({'RESULT': 0}).room.content.title, isEmpty);
      expect(detail({'RESULT': -2}).room.broadcast.liveStatus, LiveStatus.banned);
      expect(
        detail({'RESULT': 1}).room.broadcast.liveStatus,
        LiveStatus.offline,
        reason: 'an answer without VIEWPRESET has nothing to play',
      );
      expect(detail({'RESULT': 1}).data, isNull);
      for (final (result, restriction) in [
        (-6, LiveRestriction.adult),
        (-8, LiveRestriction.password),
        (-14, LiveRestriction.subscribersOnly),
      ]) {
        final room = detail({'RESULT': result, 'TITLE': '受限的直播', 'BTIME': '60'}).room;
        expect(room.broadcast.liveStatus, LiveStatus.live, reason: '$result is on air, just not for us');
        expect(room.broadcast.restriction, restriction, reason: '$result');
        expect(room.content.title, '受限的直播');
        expect(room.anchor?.liveStatus, LiveStatus.live);
        expect(room.content.coverUrl, isEmpty, reason: 'a restricted answer names no thumbnail');
      }
      expect(detail({'RESULT': -14}).room.broadcast.startedAt, isNull, reason: 'the elapsed time is not given for -14');
      expect(_kindOf(() => detail({'RESULT': -3})), SoopFailureKind.apiChanged);
      expect(_failure(() => detail({'RESULT': -3})).message, contains('RESULT -3'));
    });

    test('a live answer is the room, its data and, when asked, its chat', () {
      final answer = detail({
        'RESULT': 1,
        'BNO': '12345678',
        'BJID': 'other_2',
        'BJNICK': '主播&amp;甲',
        'TITLE': '直播标题',
        'BTIME': '120',
        'CATEGORY_TAGS': ['游戏', ' LOL '],
        'total_view_cnt': '30',
        'RMD': 'https://live.sooplive.co.kr/',
        'CDN': 'gs_cdn_pc_web',
        'CHATNO': '99887766',
        'CHDOMAIN': 'chat-6E0A4C4E.sooplive.com',
        'CHPT': '4999',
        'VIEWPRESET': [
          {'name': 'original', 'bps': '8000', 'vcodec': 'H264'},
          {'name': 'auto'},
        ],
      }, withDanmaku: true);
      final room = answer.room;
      expect(room.roomId, _id, reason: 'the identity is the one that was asked for');
      expect(room.anchor?.anchorId, _id);
      expect(room.anchor?.name, '主播&甲');
      expect(
        room.anchor?.avatarUrl,
        SoopEndpoints.logo('other_2'),
        reason: "the picture is built from the broadcast's own id",
      );
      expect(room.content.coverUrl, 'https://liveimg.sooplive.co.kr/m/12345678?_t=${_now.millisecondsSinceEpoch}');
      expect(room.area?.areaName, '游戏', reason: 'the first tag is the area');
      expect(room.audience.onlineViewers, 30);
      expect(room.broadcast.startedAt, _now.subtract(const Duration(seconds: 120)));
      expect(room.broadcast.restriction, isNull, reason: 'a live answer whose flags say nothing leaves it unknown');
      expect(answer.data?.bno, '12345678');
      expect(answer.data?.rmd, 'https://live.sooplive.co.kr/');
      expect(answer.data?.cdn, 'gs_cdn_pc_web');
      expect(answer.data?.presets.map((preset) => preset.name), ['original', 'auto']);
      expect(answer.data?.codecOf('original'), 'avc');
      expect(answer.danmaku?.chatNo, '99887766');
      expect(detail({'RESULT': 1, 'VIEWPRESET': []}, withDanmaku: true).danmaku, isNull);
      expect(detail({'RESULT': 1, 'VIEWPRESET': []}).data?.presets, isEmpty);
      expect(detail({'RESULT': 1, 'VIEWPRESET': [], 'BJID': null}).room.anchor?.avatarUrl, SoopEndpoints.logo(_id));
      expect(detail({'RESULT': 1, 'VIEWPRESET': [], 'CATEGORY_TAGS': []}).room.area, isNull);
      expect(detail({'RESULT': 1, 'VIEWPRESET': [], 'BPWD': 'Y'}).room.broadcast.restriction, LiveRestriction.password);
      expect(
        detail({'RESULT': 1, 'VIEWPRESET': [], 'P_MIN_TIER': '2'}).room.broadcast.restriction,
        LiveRestriction.subscribersOnly,
      );
      expect(detail({'RESULT': 1, 'VIEWPRESET': [], 'GRADE': '19'}).room.broadcast.restriction, LiveRestriction.adult);
      expect(detail({'RESULT': 1, 'VIEWPRESET': []}, requestedId: '  $_id  ').room.roomId, _id);
      expect(detail({'RESULT': 1, 'VIEWPRESET': [], 'BTIME': '0'}).room.broadcast.startedAt, isNull);
    });

    test('the danmaku arguments need a host, a channel and a port', () {
      SoopDanmakuArgs? args(Map<String, Object?> fields) => SoopRoomParser.danmakuArgs(fields, roomId: _id);
      final fromDomain = args({'CHATNO': '1', 'CHDOMAIN': 'chat-aa.bb.com', 'CHPT': '4999'})!;
      expect(fromDomain.url.toString(), 'wss://chat-aa.bb.com:5000/Websocket/$_id');
      expect(fromDomain.plainUrl.toString(), 'ws://chat-aa.bb.com:4999/Websocket/$_id');
      expect(fromDomain.url.port, 5000, reason: 'the TLS port is the plain one plus one');
      final fromIp = args({'CHATNO': '1', 'CHIP': '110.10.76.78', 'CHPT': '4999'})!;
      expect(
        fromIp.url.host,
        'chat-6e0a4c4e.sooplive.com',
        reason: 'the hex host is written upper-case but a Uri lower-cases it',
      );
      expect(
        args({'CHATNO': '1', 'CHIP': '110.10.76', 'CHPT': '4999'}),
        isNull,
        reason: 'three numbers are not an IPv4',
      );
      expect(args({'CHATNO': '1', 'CHIP': '999.1.1.1', 'CHPT': '4999'}), isNull);
      expect(args({'CHATNO': '', 'CHPT': '4999', 'CHDOMAIN': 'a.b'}), isNull, reason: 'no channel number, no chat');
      expect(args({'CHPT': '0', 'CHDOMAIN': 'a.b', 'CHATNO': '1'}), isNull);
      expect(args({'CHPT': '65535', 'CHDOMAIN': 'a.b', 'CHATNO': '1'}), isNull);
      expect(args({'CHDOMAIN': 'a.b', 'CHATNO': '1'}), isNull);
      expect(
        args({'CHATNO': '1', 'CHDOMAIN': 'a.b', 'CHPT': '4999', 'ROOM': _id})!.headers['origin'],
        'https://${SoopEndpoints.playHost}',
      );
      expect(SoopRoomParser.danmakuArgs({'CHATNO': '1', 'CHDOMAIN': 'a.b', 'CHPT': '4999'}, roomId: '  '), isNull);
    });
  });

  group('the station, and what room entry makes of it', () {
    Map<String, Object?> channelFields([Map<String, Object?>? override]) => {
      'RESULT': 1,
      'BNO': '12345678',
      'BJID': _id,
      'TITLE': '直播标题',
      'VIEWPRESET': <Map<String, Object?>>[
        {'name': 'original'},
      ],
      ...?override,
    };
    final data = SoopRoomParser.roomDetail(_channel(channelFields()), requestedId: _id, now: _now).data;

    SoopStation station({Map<String, Object?>? broad, Map<String, Object?>? station}) => SoopRoomParser.station(
      _root({
        'station': {'user_nick': '主播甲', 'station_title': '频道标语', 'broad_start': '2026-09-22 19:59:31', ...?station},
        'profile_image': 'https://cdn.sooplive.co.kr/a.jpg',
        'broad': ?broad,
      }),
    );

    test('an unknown streamer is not an API change', () {
      expect(_failure(() => SoopRoomParser.station(_root({'code': '9000'}))).message, contains('no such streamer'));
      expect(_kindOf(() => SoopRoomParser.station(_root({'code': 9000}))), SoopFailureKind.notFound);
      expect(_kindOf(() => SoopRoomParser.station(_root({}))), SoopFailureKind.apiChanged);
      expect(_kindOf(() => SoopRoomParser.station(_root({'station': 'x'}))), SoopFailureKind.apiChanged);
      final read = station(
        broad: {'broad_no': '12345678', 'broad_title': 'A&amp;B', 'current_sum_viewer': '250', 'is_password': 'Y'},
      );
      expect(read.nick, '主播甲');
      expect(read.introduction, '频道标语');
      expect(read.avatar, 'https://cdn.sooplive.co.kr/a.jpg');
      expect(read.broadcast?.bno, '12345678');
      expect(read.broadcast?.title, 'A&B');
      expect(read.broadcast?.viewers, 250);
      expect(read.broadcast?.startedAt, DateTime.utc(2026, 9, 22, 10, 59, 31));
      expect(read.broadcast?.restriction, LiveRestriction.password);
      expect(station().broadcast, isNull, reason: 'a station that is not broadcasting names no broadcast');
      expect(
        station(broad: {'broad_no': null}).broadcast?.restriction,
        LiveRestriction.none,
        reason: 'a broadcast with no flags is open to all',
      );
      expect(station(broad: {'subscription_only': '1'}).broadcast?.bno, isEmpty);
    });

    test('the station fills what the player API lacks', () {
      final room = SoopRoomParser.withStation(
        SoopRoomParser.roomDetail(_channel(channelFields()), requestedId: _id, now: _now).room,
        data,
        station(broad: {'broad_no': '12345678', 'current_sum_viewer': '250'}),
        now: _now,
      );
      expect(room.content.introduction, '频道标语');
      expect(room.anchor?.name, '主播甲', reason: 'the answer had no nick of its own');
      expect(room.anchor?.avatarUrl, 'https://cdn.sooplive.co.kr/a.jpg');
      expect(room.audience.onlineViewers, 250, reason: 'the player API carries no audience');
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.startedAt, DateTime.utc(2026, 9, 22, 10, 59, 31));
      final kept = SoopRoomParser.withStation(
        SoopRoomParser.roomDetail(
          _channel(channelFields({'BJNICK': '甲', 'TITLE': '标题', 'total_view_cnt': '9'})),
          requestedId: _id,
          now: _now,
        ).room,
        data,
        station(
          broad: {'broad_no': '12345678', 'broad_title': '别的标题', 'current_sum_viewer': '250'},
          station: {'user_nick': '乙'},
        ),
        now: _now,
      );
      expect(kept.anchor?.name, '甲', reason: 'a name the answer gave is not overwritten');
      expect(kept.content.title, '标题', reason: 'the broadcast title wins while it says something');
      expect(kept.audience.onlineViewers, 250, reason: 'the station counts what is watching now');
    });

    test('a broadcast that ended between the answers is not merged', () {
      final live = SoopRoomParser.roomDetail(_channel(channelFields()), requestedId: _id, now: _now);
      final other = SoopRoomParser.withStation(
        live.room,
        data,
        station(broad: {'broad_no': '87654321', 'current_sum_viewer': '250'}),
        now: _now,
      );
      expect(other.audience.onlineViewers, isNull, reason: 'the station is describing a different broadcast');
      final banned = SoopRoomParser.withStation(
        SoopRoomParser.roomDetail(_channel({'RESULT': -2}), requestedId: _id, now: _now).room,
        null,
        station(broad: {'broad_no': '1', 'current_sum_viewer': '5'}),
        now: _now,
      );
      expect(banned.broadcast.liveStatus, LiveStatus.banned, reason: 'a banned room stays banned');
    });

    test('on air for the platform but not for this client is unplayable', () {
      final offline = SoopRoomParser.roomDetail(_channel({'RESULT': 0}), requestedId: _id, now: _now).room;
      final hidden = SoopRoomParser.withStation(offline, null, station(broad: {'broad_no': '12345678'}), now: _now);
      expect(hidden.broadcast.liveStatus, LiveStatus.live, reason: 'the station says it is broadcasting');
      expect(hidden.broadcast.restriction, LiveRestriction.unplayable);
      expect(hidden.content.title, isEmpty);
      expect(hidden.content.coverUrl, 'https://liveimg.sooplive.co.kr/m/12345678?_t=${_now.millisecondsSinceEpoch}');
      final passworded = SoopRoomParser.withStation(
        offline,
        null,
        station(broad: {'broad_no': '1', 'is_password': 'Y', 'broad_title': '有密码'}),
        now: _now,
      );
      expect(passworded.broadcast.restriction, LiveRestriction.password);
      expect(passworded.content.title, '有密码', reason: 'a restricted answer has no title of its own');
      expect(SoopRoomParser.noStream(passworded).kind, SoopFailureKind.streamUnavailable);
      expect(SoopRoomParser.noStream(passworded).message, contains('is password-protected'));
      expect(SoopRoomParser.noStream(hidden).message, contains('is live'));
      final adult = SoopRoomParser.withStation(
        SoopRoomParser.roomDetail(_channel({'RESULT': -6}), requestedId: _id, now: _now).room,
        null,
        station(broad: {'broad_no': '1'}),
        now: _now,
      );
      expect(
        adult.broadcast.restriction,
        LiveRestriction.adult,
        reason: 'the answer already said it is age-restricted',
      );
      expect(SoopRoomParser.noStream(adult).kind, SoopFailureKind.needsLogin);
      expect(
        SoopRoomParser.noStream(SoopRoomParser.roomDetail(_channel({'RESULT': 0}), requestedId: _id, now: _now).room)
            .message,
        contains('is offline'),
      );
    });
  });

  group('restrictions, times and pictures', () {
    test('the flags state the hardest thing first', () {
      expect(SoopRoomParser.restrictionOf(), isNull, reason: 'nothing said is nothing known');
      expect(SoopRoomParser.restrictionOf(password: 'N'), LiveRestriction.none);
      expect(SoopRoomParser.restrictionOf(password: 'Y', subscribers: 2, grade: 19), LiveRestriction.password);
      expect(SoopRoomParser.restrictionOf(subscribers: 2, grade: 19), LiveRestriction.subscribersOnly);
      expect(SoopRoomParser.restrictionOf(grade: 19), LiveRestriction.adult);
      expect(SoopRoomParser.restrictionOf(grade: 18), LiveRestriction.none);
      expect(SoopRoomParser.restrictionOf(subscribers: '0'), LiveRestriction.none);
    });

    test('two restrictions merge to the harder one', () {
      expect(SoopRoomParser.stricter(null, null), isNull);
      expect(SoopRoomParser.stricter(LiveRestriction.none, LiveRestriction.adult), LiveRestriction.adult);
      expect(SoopRoomParser.stricter(LiveRestriction.password, LiveRestriction.adult), LiveRestriction.password);
      expect(
        SoopRoomParser.stricter(LiveRestriction.adult, LiveRestriction.subscribersOnly),
        LiveRestriction.subscribersOnly,
      );
      expect(SoopRoomParser.stricter(LiveRestriction.none, LiveRestriction.none), LiveRestriction.none);
      expect(SoopRoomParser.stricter(LiveRestriction.none, null), LiveRestriction.none);
    });

    test('Korean times and elapsed ones', () {
      expect(SoopRoomParser.koreanTime('2026-09-22 19:59:31'), DateTime.utc(2026, 9, 22, 10, 59, 31));
      expect(
        SoopRoomParser.koreanTime('2026-09-22T19:59:31.0'),
        DateTime.utc(2026, 9, 22, 10, 59, 31),
        reason: 'lists add the fraction',
      );
      expect(SoopRoomParser.koreanTime('2026-02-30 10:00:00'), isNull);
      expect(SoopRoomParser.koreanTime('2026-09-22'), isNull);
      expect(SoopRoomParser.koreanTime(null), isNull);
      expect(SoopRoomParser.koreanTime('1970-01-01 00:00:00'), isNull, reason: 'the epoch is not a start');
      expect(SoopRoomParser.startedBefore('120', _now), _now.subtract(const Duration(seconds: 120)));
      expect(SoopRoomParser.startedBefore(120, _now), _now.subtract(const Duration(seconds: 120)));
      expect(SoopRoomParser.startedBefore('0', _now), isNull);
      expect(SoopRoomParser.startedBefore('-5', _now), isNull);
      expect(SoopRoomParser.startedBefore('x', _now), isNull);
      expect(
        SoopRoomParser.cover('12345678', _now),
        'https://liveimg.sooplive.co.kr/m/12345678?_t=${_now.millisecondsSinceEpoch}',
      );
      expect(SoopRoomParser.cover('', _now), isEmpty, reason: 'no broadcast number, no thumbnail');
    });

    test('the presets of a broadcast', () {
      final presets = SoopRoomParser.presets([
        {'name': ' original ', 'bps': '8000', 'vcodec': 'H264'},
        {'name': 'hd', 'bps': 'x', 'vcodec': 'h265'},
        {'name': 'sd', 'vcodec': 'hev1'},
        {'bps': '100'},
        'not a row',
      ]);
      expect(presets.map((preset) => preset.name), ['original', 'hd', 'sd']);
      expect(presets.first.bps, 8000);
      expect(presets[1].bps, 0, reason: 'a bitrate that does not read is 0');
      expect(presets.first.codec, 'avc');
      expect(presets[1].codec, 'hevc');
      expect(presets[2].codec, null, reason: 'hev1 is not a codec this platform writes');
      expect(SoopRoomParser.presets(null), isEmpty);
      expect(SoopRoomParser.presets({'name': 'hd'}), isEmpty, reason: 'the answer is a list or nothing');
    });
  });

  group('the quality table and the stream requests', () {
    test('names, order and the legacy transcodes', () {
      final qualities = SoopRoomParser.qualities([
        const SoopPreset(name: 'auto'),
        const SoopPreset(name: 'original', bps: 8000, codec: 'avc'),
        const SoopPreset(name: 'hd8k', bps: 5000),
        const SoopPreset(name: 'hd4k', bps: 3000),
        const SoopPreset(name: 'HD', bps: 1500),
        const SoopPreset(name: 'hd', bps: 9000),
        const SoopPreset(name: 'sd', bps: 700),
        const SoopPreset(name: 'webrtc_source'),
      ]);
      expect(qualities.map((quality) => quality.qualityId), ['original', 'hd8k', 'hd4k', 'HD', 'sd', 'webrtc_source']);
      expect(qualities.map((quality) => quality.label), ['原画', '蓝光', '超清', '高清', '标清', 'webrtc_source']);
      expect(qualities.first.platformOrder, 0, reason: 'the order index is the position, best first');
      expect(qualities.last.platformOrder, qualities.length - 1);
      expect(SoopRoomParser.qualityName(const SoopPreset(name: 'master')), '蓝光');
      expect(SoopRoomParser.qualityName(const SoopPreset(name: 'fhd')), '超清');
      expect(SoopRoomParser.qualityName(const SoopPreset(name: 'low')), '流畅');
      expect(SoopRoomParser.qualityName(const SoopPreset(name: 'origion')), '原画');
      expect(SoopRoomParser.qualityName(const SoopPreset(name: 'blue')), '蓝光');
      expect(
        SoopRoomParser.qualityName(const SoopPreset(name: '中文名字')),
        '中文名字',
        reason: 'a Chinese name is shown as it is',
      );
      expect(
        SoopRoomParser.qualityName(const SoopPreset(name: 'x', bps: 1500)),
        'x',
        reason: 'a name nobody maps is shown as it is',
      );
      expect(
        SoopRoomParser.qualityName(const SoopPreset(name: ' ', bps: 1500)),
        '2 Kbps',
        reason: 'only a nameless preset is labelled by its bitrate',
      );
      expect(SoopRoomParser.qualityName(const SoopPreset(name: ' ', bps: 2500000)), '2.5 Mbps');
      expect(SoopRoomParser.qualitySort('original', 0), greaterThan(SoopRoomParser.qualitySort('hd', 49999999)));
      expect(SoopRoomParser.qualitySort('other', 50000000), 50000000, reason: 'outside a tier the bitrate is the rank');
      expect(
        SoopRoomParser.qualitySort('hd', 60000000),
        300000000 + 49999999,
        reason: 'the bitrate is clamped inside a tier',
      );
      expect(SoopRoomParser.qualities(const <SoopPreset>[]), isEmpty);
    });

    test('the stream assignment request and its answer', () {
      expect(SoopRoomParser.returnType('gs_cdn_pc_web'), 'gs_cdn_pc_web');
      expect(SoopRoomParser.returnType('pc_web_gs_cdn_x'), 'gs_cdn_pc_web');
      expect(SoopRoomParser.returnType('lg_cdn'), 'lg_cdn_pc_web');
      expect(SoopRoomParser.returnType('akamai'), 'akamai');
      final url = SoopRoomParser.assignUrl(
        rmd: 'https://live.sooplive.co.kr/',
        cdn: 'akamai',
        bno: '12345678',
        quality: 'original',
      );
      expect(url.path, '/broad_stream_assign.html');
      expect(url.queryParameters['return_type'], 'akamai');
      expect(url.queryParameters['broad_key'], '12345678-common-original-hls');
      expect(
        SoopRoomParser.assignUrl(rmd: 'https://live.sooplive.co.kr', cdn: 'x', bno: '1', quality: 'hd').path,
        '/broad_stream_assign.html',
        reason: 'a trailing slash on RMD is not doubled',
      );
      for (final rmd in ['', 'not a url', 'ftp://live.sooplive.co.kr', 'https:///no-host']) {
        expect(
          _failure(() => SoopRoomParser.assignUrl(rmd: rmd, cdn: 'x', bno: '1', quality: 'hd')).message,
          contains('is not a URL'),
          reason: rmd,
        );
      }
      expect(
        SoopRoomParser.assignedPlaylist(_root({'result': 1, 'view_url': 'https://m.sooplive.co.kr/a.m3u8'})),
        'https://m.sooplive.co.kr/a.m3u8',
      );
      expect(_failure(() => SoopRoomParser.assignedPlaylist(_root({'result': '0'}))).message, contains('result 0'));
      expect(
        _kindOf(() => SoopRoomParser.assignedPlaylist(_root({'result': 1, 'view_url': 'ftp://x/y'}))),
        SoopFailureKind.apiChanged,
      );
      expect(_kindOf(() => SoopRoomParser.assignedPlaylist(_root({'result': 1}))), SoopFailureKind.apiChanged);
    });

    test('the stream key and the line it makes', () {
      expect(SoopRoomParser.aid(_channel({'RESULT': 1, 'AID': 'abc123'})), 'abc123');
      expect(
        _failure(() => SoopRoomParser.aid(_channel({'RESULT': -6, 'AID': 'abc'}))).message,
        contains('age-restricted'),
      );
      expect(_failure(() => SoopRoomParser.aid(_channel({'RESULT': -6}))).kind, SoopFailureKind.needsLogin);
      expect(_failure(() => SoopRoomParser.aid(_channel({'RESULT': 0, 'AID': 'abc'}))).message, contains('RESULT 0'));
      expect(
        _failure(() => SoopRoomParser.aid(_channel({'RESULT': 0}), password: true)).message,
        contains('password-protected'),
      );
      expect(_failure(() => SoopRoomParser.aid(_channel({'RESULT': 1}))).message, contains('RESULT 1'));
      final line = SoopRoomParser.resolution(
        playlist: 'https://m.sooplive.co.kr/a.m3u8?x=1',
        aid: 'abc123',
        roomId: _id,
        cdn: 'gs_cdn_pc_web',
        codec: 'hevc',
      );
      expect(line.url, 'https://m.sooplive.co.kr/a.m3u8?x=1&aid=abc123');
      expect(line.format, LiveStreamFormat.hls);
      expect(line.codec, LiveStreamCodec.hevc);
      expect(line.lineLabel, 'gs_cdn_pc_web', reason: 'the CDN code is also the line name');
      expect(line.lease, isNull, reason: 'a playlist with its key keeps working; recovery asks again');
      expect(
        SoopRoomParser.resolution(playlist: 'https://m.sooplive.co.kr/a.flv', aid: 'k', roomId: _id, cdn: '').format,
        LiveStreamFormat.flv,
      );
      expect(
        SoopRoomParser.resolution(playlist: 'https://m.sooplive.co.kr/a.flv', aid: 'k', roomId: _id, cdn: '').lineLabel,
        'm.sooplive.co.kr',
      );
      expect(
        SoopRoomParser.resolution(playlist: 'https://m.sooplive.co.kr/a.m3u8', aid: 'k', roomId: _id, cdn: 'x').codec,
        isNull,
      );
      expect(
        SoopRoomParser.resolution(playlist: 'https://m.sooplive.co.kr/a.m3u8', aid: 'k', roomId: _id, cdn: 'x').headers,
        isNotEmpty,
      );
    });
  });
}
