import 'dart:convert';

import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kugoulive/api/kugoulive_endpoints.dart';
import 'package:live_sites/src/platforms/kugoulive/kugoulive_manifest.dart';
import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_failure.dart';
import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_room_parser.dart';
import 'package:test/test.dart';

/// A room number.
const String _room = '1234567';

/// The session id of a broadcast started at [_start], owned by kugou id 26.
const String _session = '6709e5c0h1a';

/// The same session with another broadcaster (27) after the `h`.
const String _otherOwnerSession = '6709e5c0h1b';

DateTime _start() => _startAt(_startSeconds);

DateTime _startAt(int seconds) => DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

/// A session id of the same shape as [_session], for another start.
String _sessionOf(int seconds, {String owner = '1a'}) => '${seconds.toRadixString(16)}h$owner';

/// When the platform wrote an answer: 2024-10-27, in milliseconds.
const int _answeredMs = 1730000000000;

/// 2024-10-12, the start a session id writes in its leading hex.
const int _startSeconds = 0x6709e5c0;

/// A signed media address of the CDN.
String _media(String name, {String secret = 'deadbeef', String time = '6709e5c0'}) =>
    'https://liveplay.live.kugou.com/live/$name?txSecret=$secret&txTime=$time';

Map<String, Object?> _row([Map<String, Object?>? override]) => {'roomId': _room, 'nickName': '主播', ...?override};

Map<String, Object?> _info([Map<String, Object?>? override]) => {
  'nickName': '主播',
  'userId': '88',
  'kugouId': '26',
  'imgPath': 'https://p3.fx.kgimg.com/cover.jpg',
  'userLogo': 'https://static.kugou.com/logo.png',
  'fansCount': 300,
  'publicMesg': '公告',
  'privateMesg': '',
  'limitType': 2,
  ...?override,
};

/// A `{code: 0, data: {...}}` answer of room entry.
String _enter({
  Map<String, Object?>? info,
  Map<String, Object?> data = const {},
  Object? code = 0,
  Object? msg,
  Object? times,
}) => jsonEncode({
  'code': code,
  'msg': ?msg,
  'times': ?times,
  'data': {'normalRoomInfo': info ?? _info(), ...data},
});

/// A stream answer.
String _stream({required List<Object?> lines, Object status = 1, String answered = _room}) => jsonEncode({
  'code': 0,
  'data': {'roomId': answered, 'status': status, 'lines': lines},
});

Map<String, Object?> _line(Object? sid, List<Map<String, Object?>> profiles) => {
  'sid': sid,
  'streamProfiles': profiles,
};

Map<String, Object?> _profile({
  int rate = 4,
  int codec = 1,
  int layout = 2,
  List<String> flv = const [],
  List<String> hls = const [],
}) => {'rate': rate, 'codec': codec, 'layout': layout, 'httpsFlv': flv, 'httpsHls': hls};

Object? _kindOf(void Function() read) {
  try {
    read();
    return null;
  } on KugouliveFailure catch (failure) {
    return failure.kind;
  }
}

KugouliveFailure _failure(void Function() read) {
  try {
    read();
  } on KugouliveFailure catch (failure) {
    return failure;
  }
  throw StateError('the answer was accepted');
}

void main() {
  group('the areas', () {
    test('the category links of the home page, in page order and once each', () {
      const html = '''
<a href="/pcindex/category/1002?x=1" title="音乐&amp;游戏">音乐</a>
<a href="https://fanxing.kugou.com/pcindex/category/7024" title="舞蹈">舞蹈</a>
<a href="/pcindex/category/1002" title="重复">重复</a>
<a href="/pcindex/category/3001" title="关注">关注</a>
<a href="/pcindex/category/1009" title=" 颜值 ">颜值</a>
<a href="/pcindex/category/1001" title="">空</a>
''';
      final areas = KugouliveRoomParser.areas(html);
      expect(
        [for (final area in areas) (area.areaId, area.areaName)],
        [('1002', '音乐&游戏'), ('7024', '舞蹈'), ('1009', '颜值')],
        reason: 'the personal route 3001 is not an area and a blank title is none',
      );
      expect(areas.first.parentAreaId, 'kugoulive');
      expect(areas.first.parentAreaName, KugouliveEndpoints.siteName);
    });

    test('a page that links no category gives the built-in list', () {
      final areas = KugouliveRoomParser.areas('<html><body>no links here</body></html>');
      expect(areas.map((area) => area.areaId), KugouliveEndpoints.fallbackAreas.map((area) => area.id));
      expect(areas.first.areaName, '推荐');
      expect(areas.first.areaId, KugouliveEndpoints.recommendAreaId);
    });

    test('the status table', () {
      expect(
        {
          for (final status in [451, 404, 410, 429, 401, 403, 400, 500, 302])
            status: _kindOf(() => KugouliveRoomParser.areas('x', status: status)),
        },
        {
          451: KugouliveFailureKind.regionBlocked,
          404: KugouliveFailureKind.notFound,
          410: KugouliveFailureKind.notFound,
          429: KugouliveFailureKind.rateLimited,
          401: KugouliveFailureKind.riskControl,
          403: KugouliveFailureKind.riskControl,
          400: KugouliveFailureKind.apiChanged,
          500: KugouliveFailureKind.network,
          302: KugouliveFailureKind.network,
        },
      );
    });

    test('a page over the size limit is api-changed', () {
      expect(
        _kindOf(() => KugouliveRoomParser.areas('x' * (KugouliveEndpoints.responseLimit + 1))),
        KugouliveFailureKind.apiChanged,
      );
    });
  });

  group('the ids', () {
    test('areaIdOf: 推荐 for null, the trimmed number otherwise', () {
      expect(KugouliveRoomParser.areaIdOf(null), KugouliveEndpoints.recommendAreaId);
      expect(KugouliveRoomParser.areaIdOf(' 1001 '), '1001');
      expect(KugouliveRoomParser.areaIdOf(''), isNull);
      expect(KugouliveRoomParser.areaIdOf('音乐'), isNull);
      expect(KugouliveRoomParser.areaIdOf('123456789'), isNull, reason: 'an area id is at most 8 digits');
    });

    test('cardState: positive live, 0 and -1 offline, anything else unknown', () {
      expect(KugouliveRoomParser.cardState(1), KugouliveState.live);
      expect(KugouliveRoomParser.cardState(6), KugouliveState.live);
      expect(KugouliveRoomParser.cardState('3'), KugouliveState.live);
      expect(KugouliveRoomParser.cardState(0), KugouliveState.offline);
      expect(KugouliveRoomParser.cardState(-1), KugouliveState.offline);
      expect(KugouliveRoomParser.cardState(null), KugouliveState.unknown);
      expect(KugouliveRoomParser.cardState(2.5), KugouliveState.unknown);
      expect(KugouliveRoomParser.cardState('x'), KugouliveState.unknown);
    });

    test('a room number, a room link, or nothing', () {
      expect(KugouliveEndpoints.parseRoomId(_room), _room);
      expect(KugouliveEndpoints.parseRoomId(' https://fanxing.kugou.com/$_room '), _room);
      expect(KugouliveEndpoints.parseRoomId('https://mfanxing.kugou.com/$_room/'), _room);
      expect(KugouliveEndpoints.parseRoomId('https://fanxing.kugou.com/?roomId=$_room'), _room);
      expect(KugouliveEndpoints.parseRoomId('0$_room'), isNull, reason: 'no leading zero');
      expect(KugouliveEndpoints.parseRoomId('12'), isNull, reason: 'two digits is not a room');
      expect(KugouliveEndpoints.parseRoomId('https://fanxing.kugou.com:8443/$_room'), isNull);
      expect(KugouliveEndpoints.parseRoomId('https://example.com/$_room'), isNull);
      expect(KugouliveEndpoints.parseRoomId('https://fanxing.kugou.com/$_room#x'), isNull);
    });
  });

  group('a card', () {
    test('needs a room number', () {
      expect(KugouliveRoomParser.card({}), isNull);
      expect(KugouliveRoomParser.card(_row({'roomId': '0$_room'})), isNull);
      expect(KugouliveRoomParser.card(_row({'roomId': 1234567})), isNotNull, reason: 'a number reads as text');
    });

    test('the first titled field, else the nick', () {
      expect(KugouliveRoomParser.card(_row({'label': 'a', 'topicContent': 'b'}))?.content.title, 'a');
      expect(KugouliveRoomParser.card(_row({'topicContent': 'b', 'performContent': 'c'}))?.content.title, 'b');
      expect(KugouliveRoomParser.card(_row({'performContent': 'c'}))?.content.title, 'c');
      expect(KugouliveRoomParser.card(_row())?.content.title, '主播');
      expect(KugouliveRoomParser.card(_row({'nickName': ''}))?.content.title, isEmpty);
    });

    test('the logo, then the one the answer keeps, then the cover', () {
      expect(
        KugouliveRoomParser.card(
          _row({
            'userLogo': 'https://static.kugou.com/a.png',
            'logo': 'https://static.kugou.com/b.png',
            'imgPath': 'https://p3.fx.kgimg.com/c.jpg',
          }),
        )?.anchor?.avatarUrl,
        'https://static.kugou.com/a.png',
      );
      expect(
        KugouliveRoomParser.card(
          _row({'logo': 'https://static.kugou.com/b.png', 'imgPath': 'https://p3.fx.kgimg.com/c.jpg'}),
        )?.anchor?.avatarUrl,
        'https://static.kugou.com/b.png',
      );
      expect(
        KugouliveRoomParser.card(
          _row({'userLogo': '', 'logo': 'https://static.kugou.com/b.png', 'imgPath': 'https://p3.fx.kgimg.com/c.jpg'}),
        )?.anchor?.avatarUrl,
        'https://p3.fx.kgimg.com/c.jpg',
        reason: 'a present-but-empty userLogo still hides the logo the answer also carries',
      );
    });

    test('the cover, then the image path, and an off-CDN address is nothing', () {
      expect(
        KugouliveRoomParser.card(_row({'imagePath': '//p3.fx.kgimg.com/c.jpg'}))?.content.coverUrl,
        'https://p3.fx.kgimg.com/c.jpg',
      );
      expect(
        KugouliveRoomParser.card(_row({'imgPath': 'http://static.kugou.com/a.png'}))?.content.coverUrl,
        'https://static.kugou.com/a.png',
      );
      expect(KugouliveRoomParser.card(_row({'imgPath': 'https://example.com/a.png'}))?.content.coverUrl, isEmpty);
    });

    test('a list row shows its viewers even at zero', () {
      final room = KugouliveRoomParser.card(_row({'liveStatus': 1, 'viewerNum': 0, 'hot': 88}))!;
      expect(room.audience.onlineViewers, 0);
      expect(room.audience.popularity, 88);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
    });

    test('a search row counts its viewers only while live and above zero', () {
      final live = KugouliveRoomParser.card(_row({'liveStatus': 1, 'viewerNum': 5, 'hot': 88}), search: true)!.audience;
      expect((live.onlineViewers, live.popularity, live.primaryMetric), (5, 88, LiveAudienceMetricType.onlineViewers));
      final zero = KugouliveRoomParser.card(_row({'liveStatus': 1, 'viewerNum': 0, 'hot': 88}), search: true)!.audience;
      expect(
        (zero.onlineViewers, zero.popularity, zero.primaryMetric),
        (null, 88, LiveAudienceMetricType.popularity),
        reason: 'the search answers 0 for everyone, so only a positive live count is real',
      );
      final offline = KugouliveRoomParser.card(_row({'liveStatus': 0, 'viewerNum': 400}), search: true)!.audience;
      expect(
        (offline.onlineViewers, offline.popularity, offline.primaryMetric),
        (null, null, LiveAudienceMetricType.unknown),
      );
    });

    test("the start: a search row's last live time, a list row's running time", () {
      final answered = DateTime.fromMillisecondsSinceEpoch(_answeredMs, isUtc: true);
      expect(
        KugouliveRoomParser.card(
          _row({'liveStatus': 1, 'lastLiveTime': _answeredMs ~/ 1000}),
          answeredAt: answered,
          search: true,
        )!.broadcast.startedAt,
        answered,
      );
      expect(
        KugouliveRoomParser.card(_row({'liveStatus': 1, 'livetime': 3600}), answeredAt: answered)!.broadcast.startedAt,
        answered.subtract(const Duration(hours: 1)),
      );
      expect(
        KugouliveRoomParser.card(_row({'liveStatus': 1, 'livetime': 3600}))!.broadcast.startedAt,
        isNull,
        reason: "a list row without the answer's own time cannot be dated",
      );
      expect(
        KugouliveRoomParser.card(_row({'liveStatus': 0, 'livetime': 60}), answeredAt: answered)!.broadcast.startedAt,
        isNull,
      );
    });

    test('the area, notice, link and anchor id it always carries', () {
      final room = KugouliveRoomParser.card(_row({'userId': '', 'kugouId': '99', 'fansCount': '1200'}))!;
      expect(room.platform, kugouliveSiteId);
      expect(room.roomId, _room);
      expect(room.area?.areaName, KugouliveEndpoints.siteName);
      expect(room.content.notice, KugouliveEndpoints.chatNotice);
      expect(room.links.webUrl, KugouliveEndpoints.roomUrl(_room));
      expect(room.anchor?.anchorId, '99');
      expect(room.anchor?.followerCount, 1200);
      expect(room.anchor?.liveStatus, LiveStatus.unknown);
      expect(room.broadcast.liveStatus, LiveStatus.unknown);
      expect(room.broadcast.restriction, isNull, reason: 'a card cannot tell');
      expect(KugouliveRoomParser.card(_row({'userId': '88', 'kugouId': '99'}))!.anchor?.anchorId, '88');
    });
  });

  group('the JSONP search', () {
    String jsonp(Map<String, Object?> root, {String name = 'cb'}) => '$name(${jsonEncode(root)})';

    Map<String, Object?> searchRoot(List<Object?> rows, {Object? status = 1, Object? time = _answeredMs}) => {
      'status': status,
      'time': time,
      'data': {
        'anchor': {'list': rows},
      },
    };

    test('the cards, a room once, rows without a number dropped', () {
      final rooms = KugouliveRoomParser.searchRooms(
        jsonp(
          searchRoot([
            _row({'liveStatus': 1, 'viewerNum': 0, 'hot': 88, 'lastLiveTime': _answeredMs ~/ 1000}),
            _row({'liveStatus': 1}),
            _row({'roomId': '7654321', 'liveStatus': 0, 'viewerNum': 9}),
            {'nickName': '无编号'},
          ]),
        ),
        callback: 'cb',
      );
      expect(rooms.map((room) => room.roomId), [_room, '7654321']);
      expect(rooms.first.audience.onlineViewers, isNull);
      expect(rooms.first.audience.popularity, 88);
      expect(rooms.first.broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(_answeredMs, isUtc: true));
      expect(rooms.last.audience.onlineViewers, isNull, reason: 'a finished search row shows no count');
    });

    test('an empty or missing anchor list is no rooms, not an error', () {
      expect(KugouliveRoomParser.searchRooms(jsonp({'code': 0}), callback: 'cb'), isEmpty);
      expect(KugouliveRoomParser.searchRooms(jsonp(searchRoot([])), callback: 'cb'), isEmpty);
    });

    test('nothing after the callback but a semicolon', () {
      final body = jsonp(searchRoot([_row()]));
      expect(KugouliveRoomParser.searchRooms('$body;', callback: 'cb'), hasLength(1));
      expect(
        _kindOf(() => KugouliveRoomParser.searchRooms('$body trailing', callback: 'cb')),
        KugouliveFailureKind.apiChanged,
      );
      expect(_kindOf(() => KugouliveRoomParser.searchRooms('{"code":0}')), KugouliveFailureKind.apiChanged);
      expect(_kindOf(() => KugouliveRoomParser.searchRooms('(1)(2)')), KugouliveFailureKind.apiChanged);
    });

    test('the callback must be the one this client named', () {
      final body = jsonp(searchRoot([]));
      expect(KugouliveRoomParser.searchRooms(body), hasLength(0), reason: 'without a callback any name passes');
      expect(
        _failure(() => KugouliveRoomParser.searchRooms(body, callback: 'other')).message,
        contains('JSONP to cb, not other'),
      );
      expect(
        _kindOf(() => KugouliveRoomParser.searchRooms('1cb({"code":0})')),
        KugouliveFailureKind.apiChanged,
        reason: 'a name starting with a digit is not a callback',
      );
    });

    test('status wins over code, and only 0 and 1 are answered', () {
      expect(KugouliveRoomParser.searchRooms(jsonp({'status': 0}), callback: 'cb'), isEmpty);
      expect(KugouliveRoomParser.searchRooms(jsonp({'code': 0}), callback: 'cb'), isEmpty);
      expect(
        _kindOf(() => KugouliveRoomParser.searchRooms(jsonp({'status': 2}), callback: 'cb')),
        KugouliveFailureKind.apiChanged,
      );
      expect(
        _failure(() => KugouliveRoomParser.searchRooms(jsonp({'code': -5}), callback: 'cb')).message,
        'search: code -5',
      );
      expect(
        _kindOf(() => KugouliveRoomParser.searchRooms(jsonp({'status': 5, 'code': 0}), callback: 'cb')),
        KugouliveFailureKind.apiChanged,
        reason: 'the status is read first, so a 5 there is answered even beside a 0 code',
      );
    });

    test('the transport is asked before the envelope', () {
      expect(
        _kindOf(() => KugouliveRoomParser.searchRooms(jsonp({'code': 0}), status: 404)),
        KugouliveFailureKind.notFound,
      );
      expect(_kindOf(() => KugouliveRoomParser.searchRooms('not json')), KugouliveFailureKind.apiChanged);
    });
  });

  group('room entry', () {
    test('a live room, its session start, and the chat limit is not a block', () {
      final (:room, :state) = KugouliveRoomParser.roomInfo(
        _enter(data: {'liveSessionId': _session, 'liveType': 1}),
        roomId: _room,
      );
      expect(state, KugouliveState.live);
      expect(room.roomId, _room);
      expect(room.anchor?.name, '主播');
      expect(room.anchor?.anchorId, '88');
      expect(room.anchor?.avatarUrl, 'https://static.kugou.com/logo.png');
      expect(room.content.coverUrl, 'https://p3.fx.kgimg.com/cover.jpg');
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.startedAt, _start());
      expect(room.broadcast.restriction, isNull, reason: 'the room info cannot tell');
      expect(room.audience.primaryMetric, LiveAudienceMetricType.unknown, reason: 'the list cards hold the counts');
      expect(room.audience.onlineViewers, isNull);
      expect(room.content.title, isEmpty, reason: 'the room info has no title');
      expect(KugouliveRoomParser.playbackError(state, _room), isNull);
    });

    test('liveType -1 is offline even with a session, and no session is unknown', () {
      expect(
        KugouliveRoomParser.roomInfo(_enter(data: {'liveSessionId': _session, 'liveType': -1}), roomId: _room).state,
        KugouliveState.offline,
      );
      final unknown = KugouliveRoomParser.roomInfo(_enter(data: {'liveType': 1}), roomId: _room);
      expect(unknown.state, KugouliveState.unknown);
      expect(unknown.room.broadcast.startedAt, isNull);
      expect(KugouliveRoomParser.playbackError(KugouliveState.offline, _room)!.message, 'room $_room is offline');
      expect(
        KugouliveRoomParser.playbackError(KugouliveState.unknown, _room)!.message,
        'room $_room has no live session',
      );
    });

    test('the announcements lead the notice, blanks are left out', () {
      final room = KugouliveRoomParser.roomInfo(
        _enter(info: _info({'publicMesg': ' 公共 ', 'privateMesg': '', 'nickName': '主播'})),
        roomId: _room,
      ).room;
      expect(room.content.notice, '公共\n${KugouliveEndpoints.chatNotice}');
    });

    test('no nick and no kugou id is no such room', () {
      expect(
        _failure(
          () => KugouliveRoomParser.roomInfo(_enter(info: _info({'nickName': '', 'kugouId': '0'})), roomId: _room),
        ).message,
        'room $_room',
      );
      expect(
        _kindOf(
          () => KugouliveRoomParser.roomInfo(_enter(info: _info({'nickName': '', 'kugouId': ''})), roomId: _room),
        ),
        KugouliveFailureKind.notFound,
      );
      expect(
        KugouliveRoomParser.roomInfo(
          _enter(info: _info({'nickName': '', 'kugouId': '26'})),
          roomId: _room,
        ).room.anchor?.name,
        isEmpty,
        reason: 'a numbered room without a name keeps what a follow stored',
      );
    });

    test('the envelope: no room info, an empty one, another code, no data', () {
      expect(
        _failure(() => KugouliveRoomParser.roomInfo('{"code":0,"data":{"liveSessionId":"x"}}', roomId: _room)).message,
        'getEnterRoomInfo: no normalRoomInfo',
      );
      expect(
        _kindOf(() => KugouliveRoomParser.roomInfo('{"code":0,"data":{"normalRoomInfo":{}}}', roomId: _room)),
        KugouliveFailureKind.apiChanged,
      );
      expect(
        _failure(() => KugouliveRoomParser.roomInfo('{"code":404,"msg":"房间不存在"}', roomId: _room)).message,
        'getEnterRoomInfo: code 404 房间不存在',
      );
      expect(
        _failure(() => KugouliveRoomParser.roomInfo('{"code":0,"data":{}}', roomId: _room)).message,
        'getEnterRoomInfo: no data',
      );
      expect(_kindOf(() => KugouliveRoomParser.roomInfo('not json', roomId: _room)), KugouliveFailureKind.apiChanged);
      expect(
        _kindOf(() => KugouliveRoomParser.roomInfo(_enter(), status: 451, roomId: _room)),
        KugouliveFailureKind.regionBlocked,
      );
    });

    test('a session only starts this room when it names its broadcaster', () {
      expect(
        KugouliveRoomParser.roomInfo(
          _enter(data: {'liveSessionId': _otherOwnerSession, 'liveType': 1}),
          roomId: _room,
        ).room.broadcast.startedAt,
        isNull,
        reason: 'the hex after h is the broadcaster, 26 here',
      );
      expect(
        KugouliveRoomParser.roomInfo(
          _enter(info: _info({'kugouId': '27'}), data: {'liveSessionId': _otherOwnerSession, 'liveType': 1}),
          roomId: _room,
        ).room.broadcast.startedAt,
        _start(),
      );
      expect(
        KugouliveRoomParser.roomInfo(
          _enter(info: _info({'kugouId': '0'}), data: {'liveSessionId': _otherOwnerSession, 'liveType': 1}),
          roomId: _room,
        ).room.broadcast.startedAt,
        _start(),
        reason: 'an anonymous entry asks with kugouId 0, which matches anyone',
      );
      expect(
        KugouliveRoomParser.roomInfo(
          _enter(info: _info({'kugouId': '26'}), data: {'liveSessionId': '6709e5c0h1a', 'liveType': 1}),
          roomId: _room,
        ).room.broadcast.startedAt,
        _start(),
      );
    });

    test('a start the answer cannot date is no start', () {
      expect(
        KugouliveRoomParser.roomInfo(
          _enter(data: {'liveSessionId': _session, 'liveType': 1}),
          roomId: _room,
        ).room.broadcast.startedAt,
        _start(),
      );
      expect(
        KugouliveRoomParser.roomInfo(
          _enter(data: {'liveSessionId': _session, 'liveType': 1}, times: 1000000000000),
          roomId: _room,
        ).room.broadcast.startedAt,
        isNull,
        reason: "a session started after the answer itself is not this broadcast's start",
      );
      for (final seconds in [4102444800, 946684799]) {
        expect(
          KugouliveRoomParser.roomInfo(
            _enter(data: {'liveSessionId': _sessionOf(seconds), 'liveType': 1}),
            roomId: _room,
          ).room.broadcast.startedAt,
          isNull,
          reason: 'a start outside 2000-2100 is not a date: $seconds',
        );
      }
      expect(
        KugouliveRoomParser.roomInfo(
          _enter(data: {'liveSessionId': '6709e5c1h1a', 'liveType': 1}),
          roomId: _room,
        ).room.broadcast.startedAt,
        _start().add(const Duration(seconds: 1)),
      );
    });
  });

  group('the restriction a stream answer tells', () {
    test('a login ask leads the notice; the other kinds keep it', () {
      final (:room, :state) = KugouliveRoomParser.roomInfo(
        _enter(data: {'liveSessionId': _session, 'liveType': 1}),
        roomId: _room,
      );
      expect(state, KugouliveState.live);
      final login = KugouliveRoomParser.withRestriction(room, LiveRestriction.needsLogin);
      expect(login.broadcast.restriction, LiveRestriction.needsLogin);
      expect(login.content.notice, '${KugouliveEndpoints.restrictedNotice}\n公告\n${KugouliveEndpoints.chatNotice}');
      expect(login.broadcast.liveStatus, LiveStatus.live);
      expect(login.broadcast.startedAt, _start(), reason: 'only the restriction is added');
      for (final kind in [LiveRestriction.none, LiveRestriction.unplayable]) {
        final kept = KugouliveRoomParser.withRestriction(room, kind);
        expect(kept.broadcast.restriction, kind);
        expect(kept.content.notice, room.content.notice);
      }
    });

    test('a room with no notice still gets the login line', () {
      final room = KugouliveRoomParser.card(_row({'liveStatus': 1}))!;
      final bare = room.rebuild((b) => b..content.replace(room.content.rebuild((b) => b..notice = '')));
      expect(
        KugouliveRoomParser.withRestriction(bare, LiveRestriction.needsLogin).content.notice,
        KugouliveEndpoints.restrictedNotice,
      );
    });
  });

  group('the stream answer', () {
    test('one quality per protocol, rate, codec and layout, best rate first', () {
      final variants = KugouliveRoomParser.variants(
        _stream(
          lines: [
            _line('a', [
              _profile(flv: [_media('hi.flv')], hls: [_media('hi.m3u8')]),
              _profile(rate: 2, codec: 2, layout: 1, flv: [_media('lo.flv')]),
            ]),
            _line('b', [
              _profile(flv: [_media('hi2.flv'), _media('hi.flv')]),
            ]),
          ],
        ),
        roomId: _room,
      );
      expect(variants.map((variant) => variant.id), ['flv:4:1:2', 'hls:4:1:2', 'flv:2:2:1']);
      expect(variants.first.protocol, 'flv');
      expect(variants.first.rate, 4);
      expect(variants.first.isHevc, isFalse);
      expect(variants.last.isHevc, isTrue);
      expect(
        [for (final line in variants.first.lines) (line.url, line.lineLabel, line.codec)],
        [(_media('hi.flv'), 'sida', LiveStreamCodec.avc), (_media('hi2.flv'), 'sidb', LiveStreamCodec.avc)],
        reason: "the answer's own line order within a group, and a URL once",
      );
      expect(variants[1].lines.single.format, LiveStreamFormat.hls);
      expect(variants[1].lines.single.formatSource, LivePlayFormatSource.declared);
      expect(variants.first.lines.first.headers.toMap(), KugouliveEndpoints.mediaHeaders(_room));
      expect(variants.first.lines.first.lease?.expiresAt, _start());
      expect(variants.first.lines.first.lease?.refreshAt, _start().subtract(KugouliveEndpoints.leaseLead));
    });

    test('a line without a text sid has no label', () {
      final variants = KugouliveRoomParser.variants(
        _stream(
          lines: [
            _line(7, [
              _profile(flv: [_media('a.flv')]),
            ]),
          ],
        ),
        roomId: _room,
      );
      expect(variants.single.lines.single.lineLabel, isNull);
    });

    test('a group whose URLs are all refused is gone', () {
      final variants = KugouliveRoomParser.variants(
        _stream(
          lines: [
            _line('a', [
              _profile(flv: ['http://liveplay.live.kugou.com/live/x.flv?txSecret=s&txTime=6709e5c0']),
              _profile(rate: 3, flv: [_media('ok.flv')], hls: [_media('bad.flv')]),
            ]),
          ],
        ),
        roomId: _room,
      );
      expect(variants.map((variant) => variant.id), ['flv:3:1:2']);
      expect(
        _kindOf(
          () => KugouliveRoomParser.variants(
            _stream(
              lines: [
                _line('a', [
                  _profile(flv: ['https://x.test/a.flv']),
                ]),
              ],
            ),
            roomId: _room,
          ),
        ),
        KugouliveFailureKind.streamUnavailable,
      );
    });

    test('no accepted URL at all says the room has nothing playable', () {
      expect(
        _failure(
          () => KugouliveRoomParser.variants(
            _stream(
              lines: [
                _line('a', [
                  _profile(flv: ['not a url']),
                ]),
              ],
            ),
            roomId: _room,
          ),
        ).message,
        'streamaddr: no playable URL for $_room',
      );
      expect(
        _kindOf(() => KugouliveRoomParser.variants(_stream(lines: []), roomId: _room)),
        KugouliveFailureKind.streamUnavailable,
      );
    });

    test('code -1 is a login ask, asked before the envelope', () {
      expect(
        _failure(() => KugouliveRoomParser.variants('{"code":-1,"msg":"need login"}', roomId: _room)),
        isA<KugouliveFailure>().having((failure) => failure.kind, 'kind', KugouliveFailureKind.needsLogin),
      );
      expect(
        _kindOf(() => KugouliveRoomParser.variants('{"code":-2}', roomId: _room)),
        KugouliveFailureKind.apiChanged,
      );
    });

    test('the answer must be about this room and say it is up', () {
      expect(
        _failure(
          () => KugouliveRoomParser.variants(
            _stream(lines: [], answered: '7654321'),
            roomId: _room,
          ),
        ).message,
        'streamaddr: asked $_room, got 7654321',
      );
      expect(
        _failure(() => KugouliveRoomParser.variants(_stream(lines: [], status: 0), roomId: _room)).message,
        'streamaddr: status 0',
      );
      expect(_kindOf(() => KugouliveRoomParser.variants('{"code":0}', roomId: _room)), KugouliveFailureKind.apiChanged);
      expect(
        _kindOf(() => KugouliveRoomParser.variants(_stream(lines: []), roomId: _room, status: 429)),
        KugouliveFailureKind.rateLimited,
      );
    });
  });

  group('the media gate', () {
    test('mediaUrl: the signed CDN address of the asked protocol', () {
      expect(KugouliveRoomParser.mediaUrl(_media('a.flv'), protocol: 'flv').toString(), _media('a.flv'));
      expect(
        KugouliveRoomParser.mediaUrl(_media('a.M3U8'), protocol: 'hls'),
        isNotNull,
        reason: 'the extension case is free',
      );
      expect(KugouliveRoomParser.mediaUrl(_media('a.m3u8'), protocol: 'hls'), isNotNull);
      expect(
        KugouliveRoomParser.mediaUrl(
          'https://live1.play.kugou.com/live/a.flv?txSecret=s&txTime=6709e5c0',
          protocol: 'flv',
        ),
        isNull,
        reason: 'not the play host',
      );
      for (final raw in [
        'http://liveplay.live.kugou.com/live/a.flv?txSecret=s&txTime=6709e5c0',
        'https://liveplay.live.kugou.com/a.flv?txSecret=s&txTime=6709e5c0',
        'https://liveplay.live.kugou.com/live/a.mp4?txSecret=s&txTime=6709e5c0',
        'https://liveplay.live.kugou.com/live/a.m3u8?txSecret=s&txTime=6709e5c0',
        'https://user@liveplay.live.kugou.com/live/a.flv?txSecret=s&txTime=6709e5c0',
        'https://liveplay.live.kugou.com/live/a.flv?txSecret=s&txTime=6709e5c0#x',
        'https://liveplay.live.kugou.com:8443/live/a.flv?txSecret=s&txTime=6709e5c0',
        'https://liveplay.live.kugou.com/live/a.flv?txTime=6709e5c0',
        'https://liveplay.live.kugou.com/live/a.flv?txSecret=&txTime=6709e5c0',
        'https://liveplay.live.kugou.com/live/a.flv?txSecret=s',
        'https://liveplay.live.kugou.com/live/a.flv?txSecret=s&txTime=6709e5c',
        'https://liveplay.live.kugou.com/live/a.flv?txSecret=s&txTime=6709e5cg',
      ]) {
        expect(KugouliveRoomParser.mediaUrl(raw, protocol: 'flv'), isNull, reason: raw);
      }
      expect(
        KugouliveRoomParser.mediaUrl(
          'https://liveplay.live.kugou.com/live/a.flv?txSecret=s&txTime=%FF',
          protocol: 'flv',
        ),
        isNull,
      );
    });

    test('the lease of a signed address, and none of an unsigned one', () {
      final url = _media('a.flv');
      expect(KugouliveRoomParser.invalidAt(url), _start());
      expect(KugouliveRoomParser.invalidAt('https://liveplay.live.kugou.com/live/a.flv?txSecret=s'), isNull);
      expect(KugouliveRoomParser.invalidAt('not a url'), isNull);
      expect(
        KugouliveRoomParser.refreshAt(url, now: _start().subtract(const Duration(days: 1))),
        _start().subtract(KugouliveEndpoints.leaseLead),
      );
      expect(
        KugouliveRoomParser.refreshAt(url, now: _start()),
        _start(),
        reason: 'a lease already past its lead is renewed at once',
      );
      expect(KugouliveRoomParser.lease(Uri.parse(url))?.expiresAt, _start());
      expect(
        KugouliveRoomParser.lease(
          Uri.parse('https://liveplay.live.kugou.com/live/a.flv?txSecret=s&txTime=6709e5c0123456789'),
        ),
        isNull,
        reason: 'more than 16 hex digits is not a txTime',
      );
    });

    test('codecName', () {
      expect(KugouliveRoomParser.codecName(1), LiveStreamCodec.avc);
      expect(KugouliveRoomParser.codecName(2), LiveStreamCodec.hevc);
      expect(KugouliveRoomParser.codecName(0), isNull);
    });

    test("the qualities: the answer's tiers, H.264 first by default", () {
      final variants = KugouliveRoomParser.variants(
        _stream(
          lines: [
            _line('a', [
              _profile(codec: 2, flv: [_media('hevc.flv')]),
              _profile(rate: 3, flv: [_media('avc.flv')]),
              _profile(rate: 2, hls: [_media('low.m3u8')]),
            ]),
          ],
        ),
        roomId: _room,
      );
      expect(
        KugouliveRoomParser.qualities(variants)
            .map((quality) => (quality.qualityId, quality.label, quality.platformOrder, quality.codec)),
        [
          ('flv:3:1:2', 'FLV 码率档 3', 0, LiveStreamCodec.avc),
          ('hls:2:1:2', 'HLS 码率档 2', 1, LiveStreamCodec.avc),
          ('flv:4:2:2', 'FLV 码率档 4', 2, LiveStreamCodec.hevc),
        ],
        reason: "the HEVC tiers come after the H.264 ones, each part in the answer's order",
      );
      expect(KugouliveRoomParser.qualities(variants, preferH264: false).map((quality) => quality.qualityId), [
        'flv:4:2:2',
        'flv:3:1:2',
        'hls:2:1:2',
      ]);
      expect(KugouliveRoomParser.lines(variants.first), variants.first.lines);
    });
  });
}
