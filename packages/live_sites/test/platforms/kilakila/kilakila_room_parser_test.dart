import 'dart:convert';

import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kilakila/api/kilakila_endpoints.dart';
import 'package:live_sites/src/platforms/kilakila/kilakila_manifest.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_failure.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_json.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_room_parser.dart';
import 'package:test/test.dart';

const String _uid = '501';
const String _broadcastId = '7001';
final DateTime _issued = DateTime.utc(2026, 10, 1, 4);

Map<String, Object?> _user([Map<String, Object?>? override]) => {
  'id': _uid,
  'nickname': '主播甲',
  'headPortraitUrl': 'https://img.kilakila.cn/avatar.jpg',
  ...?override,
};

Map<String, Object?> _room([Map<String, Object?>? override]) => {
  'roomIdStr': _broadcastId,
  'uid': _uid,
  'title': '直播标题',
  'status': 4,
  'goldPrice': 0,
  'backPic': 'https://img.kilakila.cn/cover.jpg',
  'defaultBackgroundPicUrl': 'https://img.kilakila.cn/default.jpg',
  'watchNumber': 30,
  'onlineNumber': 12,
  'actualTime': 1760000000000,
  'userInfo': _user(),
  ...?override,
};

/// A `pcLive/timeline` answer wrapping `{h, b}` twice.
String _timeline({
  List<Object?> rows = const [],
  int page = 1,
  int pageSize = 10,
  Object? last,
  Object? code = 200,
  Object? bodyCode = 200,
  Object? success = true,
  Object? pageNo,
  Object? pageSizeEcho,
}) => jsonEncode({
  'code': code,
  'data': {
    'body': {
      'h': {'code': bodyCode, 'success': success},
      'b': {'pageNo': pageNo ?? page, 'pageSize': pageSizeEcho ?? pageSize, 'isLastPage': ?last, 'data': rows},
    },
  },
});

Map<String, Object?> _row({Object? dataType = 8, Map<String, Object?>? room, Map<String, Object?>? user}) => {
  'dataType': dataType,
  'roomResq': room ?? _room(),
  'userResp': user ?? _user(),
};

String _profile({Object? user = true, Object? card = const <String, Object?>{}, Object? code = 200}) => jsonEncode({
  'code': code,
  'data': {
    'userResp': user == true
        ? _user({
            'statisticInfo': {'followerNumber': 9},
          })
        : user,
    'liveCard': card,
  },
});

String _info({Map<String, Object?>? room, Object? code = 200, Object? success = true}) => jsonEncode({
  'h': {'code': code, 'success': success},
  'b': room ?? _room(),
});

/// A pull URL of this broadcast with its `auth_key` ending at `expires`.
String _pull(String extension, {DateTime? expires, String extra = ''}) =>
    'https://${KilakilaEndpoints.mediaHost}/hrs/$_broadcastId.$extension'
    '?auth_key=${(expires ?? _issued.add(const Duration(days: 30))).millisecondsSinceEpoch ~/ 1000}-0-0-md5$extra';

Object? _kindOf(void Function() answer) {
  try {
    answer();
    return null;
  } on KilakilaFailure catch (failure) {
    return failure.kind;
  }
}

KilakilaFailure _failure(void Function() answer) {
  try {
    answer();
  } on KilakilaFailure catch (failure) {
    return failure;
  }
  throw StateError('the answer was accepted');
}

void main() {
  group('the gates of an answer', () {
    test('a status other than 200', () {
      expect(_kindOf(() => KilakilaJson.checkStatus(200, 'x')), isNull);
      expect(_kindOf(() => KilakilaJson.checkStatus(401, 'x')), KilakilaFailureKind.riskControl);
      expect(_kindOf(() => KilakilaJson.checkStatus(403, 'x')), KilakilaFailureKind.riskControl);
      expect(_kindOf(() => KilakilaJson.checkStatus(404, 'x')), KilakilaFailureKind.notFound);
      expect(_kindOf(() => KilakilaJson.checkStatus(429, 'x')), KilakilaFailureKind.rateLimited);
      expect(_kindOf(() => KilakilaJson.checkStatus(500, 'x')), KilakilaFailureKind.network);
      expect(_kindOf(() => KilakilaJson.checkStatus(302, 'x')), KilakilaFailureKind.network);
      expect(
        _kindOf(() => KilakilaJson.checkBody('漢' * 400000, 'x', 200)),
        KilakilaFailureKind.apiChanged,
        reason: 'the megabyte is counted in UTF-8 bytes',
      );
    });

    test('the two envelopes', () {
      expect(KilakilaJson.json('{"a":1}', 'x', 200), {'a': 1});
      expect(_kindOf(() => KilakilaJson.json('nope', 'x', 200)), KilakilaFailureKind.apiChanged);
      expect(_kindOf(() => KilakilaJson.json('[]', 'x', 200)), KilakilaFailureKind.apiChanged);
      expect(_kindOf(() => KilakilaJson.code(null, 'x')), KilakilaFailureKind.apiChanged);
      expect(_failure(() => KilakilaJson.code('201', 'x')).message, 'x: code 201');
      expect(_kindOf(() => KilakilaJson.code(200, 'x')), isNull);
      expect(
        _failure(
          () => KilakilaJson.header({
            'h': {'code': 200, 'success': 'true'},
          }, 'x'),
        ).message,
        contains('h.success is true'),
        reason: 'the flag must really be true',
      );
      expect(_kindOf(() => KilakilaJson.header({}, 'x')), KilakilaFailureKind.apiChanged);
    });

    test('the field readers', () {
      expect(KilakilaJson.text(' a '), 'a');
      expect(KilakilaJson.text(7), isEmpty);
      expect(KilakilaJson.integer('12'), 12);
      expect(KilakilaJson.integer(1.5), isNull);
      expect(KilakilaJson.count('0'), 0);
      expect(KilakilaJson.count(-1), isNull);
      expect(KilakilaJson.nonNegative(0, 'x'), 0);
      expect(_kindOf(() => KilakilaJson.nonNegative(-1, 'x')), KilakilaFailureKind.apiChanged);
      expect(KilakilaJson.id(7, 'x'), '7');
      expect(KilakilaJson.id('9007199254740991', 'x'), '9007199254740991');
      for (final bad in [0, -1, '01', '', 'abc', 9007199254740992, null, 1.5]) {
        expect(_kindOf(() => KilakilaJson.id(bad, 'x')), KilakilaFailureKind.apiChanged, reason: '$bad');
      }
      expect(KilakilaJson.startedAt(1760000000000), DateTime.fromMillisecondsSinceEpoch(1760000000000, isUtc: true));
      for (final bad in [0, -1, 1760000000, 'x', 1760000000000.5, 99999999999999]) {
        expect(KilakilaJson.startedAt(bad), isNull, reason: '$bad');
      }
      expect(KilakilaJson.picture('//img.kilakila.cn/a.jpg'), 'https://img.kilakila.cn/a.jpg');
      expect(KilakilaJson.picture('https://u@img/a.jpg'), isEmpty, reason: 'user info is dropped');
      expect(KilakilaJson.picture(7), isEmpty);
    });

    test('the platform has two timelines and no request for them', () {
      final areas = KilakilaRoomParser.areas();
      expect(areas.map((area) => area.areaId), ['0', '107']);
      expect(areas.map((area) => area.areaName), ['热门直播', '萌星推荐']);
      expect(areas.every((area) => area.parentAreaName == KilakilaEndpoints.categoryName), isTrue);
      expect(areas.every((area) => area.parentAreaId == 'kilakila'), isTrue);
      expect(areas.first.platform, kilakilaSiteId);
    });
  });

  group('the timeline', () {
    ({List<KilakilaBroadcast> rooms, bool hasMore}) read({
      List<Object?> rows = const [],
      int page = 1,
      int pageSize = 10,
      int type = 0,
      Object? last,
      Object? code,
      Object? bodyCode,
      Object? success,
      Object? pageNo,
      Object? pageSizeEcho,
    }) => KilakilaRoomParser.timelinePage(
      _timeline(
        rows: rows,
        page: page,
        pageSize: pageSize,
        last: last,
        code: code ?? 200,
        bodyCode: bodyCode ?? 200,
        success: success ?? true,
        pageNo: pageNo,
        pageSizeEcho: pageSizeEcho,
      ),
      page: page,
      pageSize: pageSize,
      type: type,
    );

    test('the echo must be the page that was asked for', () {
      expect(read(rows: [_row()]).rooms.single.broadcastId, _broadcastId);
      expect(_failure(() => read(pageNo: 2)).message, contains('echo pageNo 2, pageSize 10'));
      expect(_kindOf(() => read(pageSizeEcho: '20')), KilakilaFailureKind.apiChanged);
      expect(_kindOf(() => read(last: 'true')), KilakilaFailureKind.apiChanged, reason: 'isLastPage must be a boolean');
      expect(_kindOf(() => read(code: 500)), KilakilaFailureKind.apiChanged);
      expect(_kindOf(() => read(bodyCode: 201)), KilakilaFailureKind.apiChanged);
      expect(_kindOf(() => read(success: false)), KilakilaFailureKind.apiChanged);
      expect(_failure(() => read(rows: [_row(dataType: 'x')])).message, contains('1 broken rows, none usable'));
      expect(
        _kindOf(
          () => read(
            rows: [
              _row(dataType: 9),
              _row(dataType: 'x'),
            ],
          ),
        ),
        KilakilaFailureKind.apiChanged,
        reason: 'one broken row and nothing usable fails the page',
      );
      expect(
        read(rows: [_row(), _row(dataType: 9)]).rooms,
        hasLength(1),
        reason: 'a row of another type is skipped, not broken',
      );
      expect(_kindOf(() => read(rows: [_row()])), isNull);
    });

    test('rows of the right types, once per broadcast and per anchor', () {
      Map<String, Object?> rowFor(String broadcast, String uid, {Object? dataType = 8}) => _row(
        dataType: dataType,
        user: _user({'id': uid}),
        room: {
          'roomIdStr': broadcast,
          'uid': uid,
          'title': '直播标题',
          'status': 4,
          'goldPrice': 0,
          'userInfo': _user({'id': uid}),
        },
      );
      final rows = [
        rowFor('7001', '501'),
        rowFor('7002', '502'),
        rowFor('7001', '503'),
        rowFor('7003', '504', dataType: 2),
        rowFor('7004', '501', dataType: 2),
        rowFor('7005', '505', dataType: 9),
      ];
      expect(read(rows: rows, type: 107).rooms.map((entry) => entry.broadcastId), [
        '7001',
        '7002',
        '7003',
      ], reason: 'the rising-stars timeline also takes type 2 rows, once per broadcast and once per anchor');
      expect(read(rows: rows).rooms.map((entry) => entry.broadcastId), [
        '7001',
        '7002',
      ], reason: 'without 107 the type 2 rows are skipped, and the duplicate broadcast drops first');
      expect(read(rows: [_row(dataType: 2)]).rooms, isEmpty);
    });

    test('the timeline ends at the last page, an empty page, or the page cap', () {
      expect(read(rows: [_row()], last: false).hasMore, isTrue);
      expect(read(rows: [_row()], last: true).hasMore, isFalse);
      expect(read(rows: [_row()]).hasMore, isTrue, reason: 'no flag is not a refusal to continue');
      expect(read().hasMore, isFalse);
      expect(read(rows: [_row()], page: KilakilaEndpoints.maxPages).hasMore, isFalse);
      expect(read(rows: [_row(dataType: 9)]).hasMore, isTrue, reason: 'rows of other types do not end the list');
    });

    test('a broadcast is its anchor, its state and its figures', () {
      final broadcast = read(rows: [_row()]).rooms.single;
      expect(broadcast.uid, _uid);
      expect(broadcast.title, '直播标题');
      expect(broadcast.nick, '主播甲');
      expect(broadcast.cover, 'https://img.kilakila.cn/cover.jpg');
      expect(broadcast.avatar, 'https://img.kilakila.cn/avatar.jpg');
      expect(broadcast.status, 4);
      expect(broadcast.isLive, isTrue);
      expect(broadcast.hasEnded, isFalse);
      expect(broadcast.restriction, LiveRestriction.none);
      expect(broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(1760000000000, isUtc: true));
      expect(broadcast.online, 12);
      expect(broadcast.total, 30);
      expect(broadcast.flv, isNull, reason: 'the timeline hands out no pull URLs');
      expect(
        read(
          rows: [
            _row(room: _room({'backPic': '', 'defaultBackgroundPicUrl': 'https://img.kilakila.cn/d.jpg'})),
          ],
        ).rooms.single.cover,
        'https://img.kilakila.cn/d.jpg',
        reason: 'the default background is the fallback cover',
      );
      expect(
        read(
          rows: [
            _row(room: _room({'goldPrice': 30})),
          ],
        ).rooms.single.restriction,
        LiveRestriction.paid,
      );
      expect(
        read(
          rows: [
            _row(room: _room({'status': 10})),
          ],
        ).rooms.single.hasEnded,
        isTrue,
      );
      expect(
        read(
          rows: [
            _row(room: _room({'status': 3})),
          ],
        ).rooms.single.isLive,
        isFalse,
        reason: '3 is not a state we name',
      );
      expect(
        _kindOf(() => read(rows: [_row(user: _room())])),
        KilakilaFailureKind.apiChanged,
        reason: 'a row whose owner block is not an object is broken',
      );
      expect(
        _kindOf(
          () => read(
            rows: [
              _row(room: _room({'title': ''})),
            ],
          ),
        ),
        KilakilaFailureKind.apiChanged,
      );
      expect(
        _kindOf(
          () => read(
            rows: [
              _row(room: _room({'uid': '999'})),
            ],
          ),
        ),
        KilakilaFailureKind.apiChanged,
        reason: 'the room and its owner block must be the same anchor',
      );
    });
  });

  group('the search page', () {
    String entry(String href, String nick, {String? avatar}) =>
        '<a href="$href"><span class="anchor-name">$nick</span>'
        '${avatar == null ? '' : '<span class="anchorHeaderImg"><img src="$avatar"></span>'}</a>';
    String page(List<String> entries) => '<html><div class="userList">${entries.join()}</div></html>';

    test('the keyword is cut at 100 code units, never inside a pair', () {
      expect(KilakilaRoomParser.searchKeyword('  主播  '), '主播');
      expect(KilakilaRoomParser.searchKeyword(''), isEmpty);
      expect(KilakilaRoomParser.searchKeyword('a' * 150).length, KilakilaEndpoints.keywordLimit);
      expect(
        KilakilaRoomParser.searchKeyword('a' * 99 + '🐥🐥').length,
        99,
        reason: 'the pair that would be split is left out',
      );
      expect(KilakilaRoomParser.searchKeyword('${'a' * 99}   ').length, 99, reason: 'the cut is trimmed again');
    });

    test('an anchor per link', () {
      final rooms = KilakilaRoomParser.searchPage(
        page([
          entry('/zhubo/$_uid', '主播甲', avatar: '//img.kilakila.cn/a.jpg'),
          entry('/zhubo/502', '乙'),
          entry('/zhubo/$_uid', '重复的'),
          entry('/zhubo/0', '零号'),
          entry('/user/503', '不是主播页'),
          entry('/zhubo/504', '  '),
        ]),
      );
      expect(rooms.map((room) => room.roomId), [_uid, '502'], reason: 'a repeated anchor is one room');
      expect(rooms.first.content.title, '主播甲', reason: 'the name is also the title');
      expect(rooms.first.anchor?.name, '主播甲');
      expect(rooms.first.anchor?.avatarUrl, 'https://img.kilakila.cn/a.jpg');
      expect(rooms.first.anchor?.liveStatus, LiveStatus.unknown, reason: 'the page says nothing about broadcasts');
      expect(rooms.first.broadcast.liveStatus, LiveStatus.unknown);
      expect(rooms.first.links.webUrl, 'https://${KilakilaEndpoints.ownerHost}/index/roomuser/uid/$_uid');
      expect(rooms.first.audience.primaryMetric, isNull, reason: 'the anchor room names no metric');
      expect(_kindOf(() => KilakilaRoomParser.searchPage('<html/>')), KilakilaFailureKind.apiChanged);
      expect(
        _kindOf(() => KilakilaRoomParser.searchPage(page([entry('/x/1', '甲')]))),
        KilakilaFailureKind.apiChanged,
        reason: 'a page whose entries are all broken is a changed page',
      );
      expect(_kindOf(() => KilakilaRoomParser.searchPage('<div class="userList"></div>')), isNull);
      final tooMany = page([for (var i = 0; i < 101; i++) entry('/zhubo/${i + 1}', '甲')]);
      expect(_kindOf(() => KilakilaRoomParser.searchPage(tooMany)), KilakilaFailureKind.apiChanged);
      expect(_kindOf(() => KilakilaRoomParser.searchPage('<html/>', status: 429)), KilakilaFailureKind.rateLimited);
    });
  });

  group('the anchor and the broadcast', () {
    test('personalH5 gives the anchor and, at most, its current broadcast', () {
      final profile = KilakilaRoomParser.profile(_profile(card: _room()), uid: _uid);
      expect(profile.nick, '主播甲');
      expect(profile.avatar, 'https://img.kilakila.cn/avatar.jpg');
      expect(profile.followers, 9);
      expect(profile.current?.broadcastId, _broadcastId);
      expect(
        KilakilaRoomParser.profile(_profile(card: {'roomSourceType': 1, 'recommendSource': 2}), uid: _uid).current,
        isNull,
      );
      expect(KilakilaRoomParser.profile(_profile(card: {}), uid: _uid).current, isNull);
      expect(
        _kindOf(() => KilakilaRoomParser.profile(_profile(card: {'roomSourceType': 'x'}), uid: _uid)),
        KilakilaFailureKind.apiChanged,
        reason: 'a routing default that is not a number is not a routing default',
      );
      expect(
        _failure(() => KilakilaRoomParser.profile(_profile(card: _room({'uid': '999'})), uid: _uid)).message,
        contains('liveCard of another anchor'),
      );
      expect(
        _kindOf(
          () => KilakilaRoomParser.profile(_profile(user: _user({'id': '999', 'statisticInfo': null})), uid: _uid),
        ),
        KilakilaFailureKind.apiChanged,
      );
      expect(
        _kindOf(() => KilakilaRoomParser.profile(_profile(user: _user({'nickname': '  '})), uid: _uid)),
        KilakilaFailureKind.apiChanged,
      );
      expect(
        KilakilaRoomParser.profile(
          _profile(
            user: _user({
              'statisticInfo': {'followerNumber': -1},
            }),
          ),
          uid: _uid,
        ).followers,
        isNull,
      );
      expect(KilakilaRoomParser.profile(_profile(user: _user({'statisticInfo': 'x'})), uid: _uid).followers, isNull);
      expect(_kindOf(() => KilakilaRoomParser.profile(_profile(code: 1013), uid: _uid)), KilakilaFailureKind.notFound);
      expect(_kindOf(() => KilakilaRoomParser.profile(_profile(code: 500), uid: _uid)), KilakilaFailureKind.apiChanged);
      expect(
        _kindOf(() => KilakilaRoomParser.profile(_profile(user: null), uid: _uid)),
        KilakilaFailureKind.apiChanged,
      );
      expect(
        _kindOf(() => KilakilaRoomParser.profile(_profile(card: null), uid: _uid)),
        KilakilaFailureKind.apiChanged,
        reason: 'a profile without a liveCard block is a changed answer',
      );
    });

    test('getRoomInfo is the broadcast with its pull URLs', () {
      KilakilaBroadcast info([Map<String, Object?>? override]) => KilakilaRoomParser.roomInfo(
        _info(room: _room({'flvPlayUrl': _pull('flv'), 'hlsPlayUrl': _pull('m3u8'), ...?override})),
        broadcastId: _broadcastId,
        uid: _uid,
      );
      final broadcast = info();
      expect(broadcast.flv, _pull('flv'));
      expect(broadcast.hls, _pull('m3u8'));
      expect(broadcast.isLive, isTrue);
      expect(
        info({'flvPlayUrl': 'https://pull.live.hongrenshuo.com.cn/hrs/9999.flv?auth_key=9-0-0-x'}).flv,
        isNull,
        reason: 'a pull URL of another broadcast is not this one',
      );
      expect(info({'flvPlayUrl': 'rtmp://pull.live.hongrenshuo.com.cn/hrs/$_broadcastId.flv'}).flv, isNull);
      expect(info({'flvPlayUrl': 'https://evil.example/hrs/$_broadcastId.flv?auth_key=9-0-0-x'}).flv, isNull);
      expect(
        info({'flvPlayUrl': _pull('flv')}).hls,
        _pull('m3u8'),
        reason: 'an flv address is never read as the hls one',
      );
      expect(
        KilakilaRoomParser.roomInfo(_info(room: _room({'pushFlow': 'rtmp://x'})), broadcastId: _broadcastId).flv,
        isNull,
        reason: 'the push address is never read',
      );
      expect(
        _kindOf(() => KilakilaRoomParser.roomInfo(_info(code: 5201), broadcastId: _broadcastId)),
        KilakilaFailureKind.notFound,
      );
      expect(
        _failure(() => KilakilaRoomParser.roomInfo(_info(code: 5966), broadcastId: _broadcastId)).message,
        contains('historical replay'),
      );
      expect(
        _kindOf(() => KilakilaRoomParser.roomInfo(_info(code: 500), broadcastId: _broadcastId)),
        KilakilaFailureKind.apiChanged,
      );
      expect(
        _kindOf(() => KilakilaRoomParser.roomInfo(_info(success: false), broadcastId: _broadcastId)),
        KilakilaFailureKind.apiChanged,
      );
      expect(
        _failure(
          () => KilakilaRoomParser.roomInfo(_info(room: _room({'roomIdStr': '7002'})), broadcastId: _broadcastId),
        ).message,
        contains('another broadcast or anchor'),
      );
      expect(
        _kindOf(() => KilakilaRoomParser.roomInfo(_info(), broadcastId: _broadcastId, uid: '999')),
        KilakilaFailureKind.apiChanged,
      );
      expect(KilakilaRoomParser.roomInfo(_info(), broadcastId: _broadcastId).uid, _uid, reason: 'uid is optional');
    });

    test('the pull URL rules, kept as written', () {
      expect(KilakilaRoomParser.mediaUrl(_pull('flv'), broadcastId: _broadcastId, isHls: false), _pull('flv'));
      for (final url in [
        '',
        'https://pull.live.hongrenshuo.com.cn/hrs/$_broadcastId.m3u8',
        'https://pull.live.hongrenshuo.com.cn/hrs/$_broadcastId.flv',
        'https://pull.live.hongrenshuo.com.cn/hls/$_broadcastId.flv?auth_key=9-0-0-x',
        'http://pull.live.hongrenshuo.com.cn/hrs/$_broadcastId.flv?auth_key=9-0-0-x',
        'https://pull.live.hongrenshuo.com.cn:8443/hrs/$_broadcastId.flv?auth_key=9-0-0-x',
        'https://u:p@pull.live.hongrenshuo.com.cn/hrs/$_broadcastId.flv?auth_key=9-0-0-x',
        'https://pull.live.hongrenshuo.com.cn/hrs/$_broadcastId.flv?auth_key=9-0-0-x#f',
        'https://pull.live.hongrenshuo.com.cn/hrs/$_broadcastId.flv',
        'https://pull.live.hongrenshuo.com.cn/hrs/$_broadcastId.flv?auth_key=',
        'https://pull.live.hongrenshuo.com.cn/hrs/$_broadcastId.flv?auth_key=9-0-0-x&auth_key=9-0-0-y',
        'https://pull.live.hongrenshuo.com.cn/hrs/$_broadcastId.flv?auth_key=${'9' * 1025}',
        'https://pull.live.hongrenshuo.com.cn/hrs/$_broadcastId.flv?x=1 2',
      ]) {
        expect(
          KilakilaRoomParser.mediaUrl(url, broadcastId: _broadcastId, isHls: false),
          isNull,
          reason: url.length > 120 ? '${url.substring(0, 60)}…' : url,
        );
      }
      expect(KilakilaRoomParser.mediaUrl(7, broadcastId: _broadcastId, isHls: false), isNull);
      expect(
        KilakilaRoomParser.mediaUrl(
          'https://${KilakilaEndpoints.mediaHost}/hrs/$_broadcastId.m3u8?auth_key=9',
          broadcastId: _broadcastId,
          isHls: true,
        ),
        endsWith('auth_key=9'),
      );
    });

    test('the lease of a pull URL', () {
      final expires = _issued.add(const Duration(days: 30));
      final lease = KilakilaRoomParser.lease(_pull('flv', expires: expires), issuedAt: _issued, isHls: false)!;
      expect(lease.expiresAt, expires);
      expect(lease.refreshAt, expires.subtract(KilakilaEndpoints.leaseLead));
      expect(lease.requiresReconnect, isFalse, reason: 'an established FLV connection is not cut by the expiry');
      expect(
        KilakilaRoomParser.lease(_pull('m3u8', expires: expires), issuedAt: _issued, isHls: true)!.requiresReconnect,
        isTrue,
      );
      final soon = KilakilaRoomParser.lease(
        _pull('flv', expires: _issued.add(const Duration(minutes: 8))),
        issuedAt: _issued,
        isHls: false,
      )!;
      expect(
        soon.expiresAt!.difference(soon.refreshAt),
        const Duration(minutes: 2),
        reason: 'never more than a quarter',
      );
      expect(KilakilaRoomParser.lease('https://x/a.flv', issuedAt: _issued, isHls: false), isNull);
      expect(
        KilakilaRoomParser.lease(
          _pull('flv', expires: _issued.subtract(const Duration(hours: 1))),
          issuedAt: _issued,
          isHls: false,
        ),
        isNull,
      );
      final past = KilakilaRoomParser.lease(
        _pull('flv', expires: _issued.subtract(const Duration(hours: 1))),
        issuedAt: _issued,
        isHls: false,
        allowExpired: true,
      )!;
      expect(past.refreshAt, past.expiresAt!.subtract(KilakilaEndpoints.leaseLead));
      expect(
        KilakilaRoomParser.lease(_pull('flv', expires: DateTime.utc(1970)), issuedAt: _issued, isHls: false),
        isNull,
        reason: 'an expiry that is not in the future is no lease',
      );
    });
  });

  group('rooms, qualities and lines', () {
    KilakilaBroadcast broadcast([Map<String, Object?>? override]) => KilakilaRoomParser.roomInfo(
      _info(room: _room({'flvPlayUrl': _pull('flv'), 'hlsPlayUrl': _pull('m3u8'), ...?override})),
      broadcastId: _broadcastId,
    );
    KilakilaRoomData data({KilakilaBroadcast? room}) =>
        KilakilaRoomData(issuedAt: _issued, broadcast: room ?? broadcast());
    final profile = KilakilaRoomParser.profile(
      _profile(
        card: {
          'roomIdStr': '7002',
          'uid': _uid,
          'title': '卡片标题',
          'status': 4,
          'goldPrice': 0,
          'backPic': 'https://img.kilakila.cn/card.jpg',
          'userInfo': _user(),
          'onlineNumber': 5,
          'actualTime': 1760000000000,
        },
      ),
      uid: _uid,
    );

    test("a broadcast becomes the anchor's room", () {
      final room = KilakilaRoomParser.room(broadcast());
      expect(room.roomId, _uid, reason: 'the room is the anchor, not the broadcast');
      expect(room.content.title, '直播标题');
      expect(room.content.coverUrl, 'https://img.kilakila.cn/cover.jpg');
      expect(room.anchor?.name, '主播甲');
      expect(room.anchor?.liveStatus, LiveStatus.live);
      expect(room.audience.onlineViewers, 12);
      expect(room.audience.totalViewers, 30);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      expect(room.broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(1760000000000, isUtc: true));
      expect(room.broadcast.restriction, LiveRestriction.none);
      expect(room.links.webUrl, KilakilaEndpoints.ownerUrl(_uid));
      final ended = KilakilaRoomParser.room(broadcast({'status': 10, 'onlineNumber': 12}));
      expect(ended.broadcast.liveStatus, LiveStatus.offline);
      expect(ended.audience.onlineViewers, isNull, reason: 'an ended broadcast shows no figures');
      expect(ended.audience.primaryMetric, LiveAudienceMetricType.unknown);
      expect(ended.broadcast.startedAt, isNull);
      expect(ended.broadcast.restriction, isNull);
      final waiting = KilakilaRoomParser.room(broadcast({'status': 3}));
      expect(waiting.broadcast.liveStatus, LiveStatus.unknown);
      expect(
        KilakilaRoomParser.room(broadcast({'status': 3, 'goldPrice': 5})).broadcast.restriction,
        isNull,
        reason: 'only a live broadcast says what keeps it from playing',
      );
    });

    test('the profile adds the introduction and the follower count', () {
      final searched = KilakilaRoomParser.profileRoom(profile);
      expect(searched.broadcast.liveStatus, LiveStatus.offline);
      expect(searched.content.title, '主播甲');
      expect(searched.content.introduction, isNull);
      final detail = KilakilaRoomParser.profileDetail(profile);
      expect(detail.content.title, '卡片标题', reason: 'the current broadcast names the room');
      expect(detail.anchor?.followerCount, 9);
      expect(detail.broadcast.liveStatus, LiveStatus.live);
      final none = KilakilaRoomParser.profileDetail(KilakilaRoomParser.profile(_profile(), uid: _uid));
      expect(none.broadcast.liveStatus, LiveStatus.offline);
      expect(none.content.title, isEmpty, reason: 'an anchor without a broadcast has no title of its own');
      expect(none.anchor?.followerCount, 9);
      final entered = KilakilaRoomParser.enteredRoom(profile, broadcast());
      expect(entered.content.title, '直播标题', reason: 'a card of another broadcast adds nothing');
      expect(entered.audience.onlineViewers, 12);
      final same = KilakilaRoomParser.enteredRoom(
        KilakilaRoomParser.profile(
          _profile(card: _room({'onlineNumber': 5, 'backPic': 'https://img.kilakila.cn/card.jpg'})),
          uid: _uid,
        ),
        KilakilaRoomParser.roomInfo(
          _info(room: _room({'flvPlayUrl': _pull('flv'), 'onlineNumber': null, 'backPic': ''})),
          broadcastId: _broadcastId,
        ),
      );
      expect(same.audience.onlineViewers, 5, reason: 'the card has the listeners now');
      expect(same.content.coverUrl, 'https://img.kilakila.cn/card.jpg', reason: 'and the real cover');
      expect(same.broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(1760000000000, isUtc: true));
    });

    test('one quality, and the lines it offers', () {
      final qualities = KilakilaRoomParser.qualities(data());
      expect(qualities.single.qualityId, KilakilaEndpoints.qualityId);
      expect(qualities.single.label, '原画');
      expect(
        _failure(() => KilakilaRoomParser.qualities(data(room: broadcast({'goldPrice': 30})))).message,
        contains('is restricted (paid)'),
      );
      expect(
        _failure(() => KilakilaRoomParser.qualities(data(room: broadcast({'status': 10})))).message,
        contains('has status 10'),
        reason: 'the paid check comes first, the live one second',
      );
      expect(
        _failure(() => KilakilaRoomParser.qualities(data(room: broadcast({'flvPlayUrl': null, 'hlsPlayUrl': null}))))
            .message,
        contains('no pull URL'),
      );
      expect(
        _failure(() => KilakilaRoomParser.qualities(data(room: broadcast({'status': 10, 'goldPrice': 30})))).message,
        contains('restricted (paid)'),
        reason: 'the paid check comes before the live one',
      );
      final none = KilakilaRoomData(issuedAt: _issued);
      expect(_failure(() => KilakilaRoomParser.qualities(none)).message, contains('no current broadcast'));
      final lines = KilakilaRoomParser.lines(data(), KilakilaEndpoints.qualityId);
      expect(lines.map((line) => line.url), [_pull('flv'), _pull('m3u8')], reason: 'FLV then HLS');
      expect(lines.map((line) => line.format), [LiveStreamFormat.flv, LiveStreamFormat.hls]);
      expect(lines.map((line) => line.lineLabel), ['flv', 'hls']);
      expect(lines.first.headers.toMap(), KilakilaEndpoints.headers);
      expect(lines.first.lease?.requiresReconnect, isFalse);
      expect(lines[1].lease?.requiresReconnect, isTrue);
      expect(
        KilakilaRoomParser.lines(data(room: broadcast({'hlsPlayUrl': 'x'})), 'flv'),
        hasLength(1),
        reason: 'a bad URL only drops its own line',
      );
      for (final wanted in ['flv', 'hls', 'FLV']) {
        expect(
          KilakilaRoomParser.lines(data(), wanted),
          hasLength(2),
          reason: '$wanted is the legacy name of the one quality',
        );
      }
      expect(
        KilakilaRoomParser.lines(data(), 'original'),
        hasLength(2),
        reason: 'the one quality is asked for by name',
      );
      expect(_failure(() => KilakilaRoomParser.lines(data(), 'auto')).message, contains('quality auto is not offered'));
      expect(_kindOf(() => KilakilaRoomParser.lines(none, 'flv')), KilakilaFailureKind.streamUnavailable);
    });
  });
}
