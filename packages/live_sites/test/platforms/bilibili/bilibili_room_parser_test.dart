import 'dart:convert';

import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_endpoints.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_failure.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_room_parser.dart';
import 'package:test/test.dart';

/// An answer as the platform writes it.
String _body(Object? data, {int code = 0, String message = ''}) =>
    jsonEncode({'code': code, 'message': message, 'data': data});

/// The `data` of `getInfoByRoom`.
Map<String, Object?> _detailData({
  Object? roomId = 1234567890123,
  Object? liveStatus = 1,
  Object? specialType,
  Object? online = 42,
  Object? watched,
  String? description,
  String title = 'a &amp; b',
}) => {
  'room_info': {
    'room_id': ?roomId,
    'live_status': ?liveStatus,
    'live_start_time': 1790733600,
    'special_type': ?specialType,
    'online': ?online,
    'area_id': 1,
    'area_name': '网格直播',
    'title': title,
    'cover': '//i0.hdslb.com/cover.png',
    'description': ?description,
  },
  'anchor_info': {
    'base_info': {'uid': '9', 'uname': 'Ann &amp; Co', 'face': 'https://x.example/face.png'},
  },
  'news_info': {'content': 'hi &amp; bye'},
  'watched_show': ?watched,
};

/// The room of a `getInfoByRoom` answer, asked for as [requestedId].
LiveRoom _room(Object? data, {String requestedId = '23058', int status = 200}) =>
    BilibiliRoomParser.roomDetail(_body(data), requestedId: requestedId, status: status).room;

/// A `getInfoByRoom` answer read as api-changed.
final Matcher _apiChanged = throwsA(
  isA<BilibiliFailure>().having((f) => f.kind, 'kind', BilibiliFailureKind.apiChanged),
);

/// What [status] and [body] make of the envelope, or null when it is accepted.
BilibiliFailureKind? _refuse(String body, {int status = 200, Set<int> extraNotFound = const {}}) {
  try {
    BilibiliRoomParser.checked(body, what: 'x', status: status, extraNotFound: extraNotFound);
    return null;
  } on BilibiliFailure catch (failure) {
    return failure.kind;
  }
}

void main() {
  group('the envelope every answer wears', () {
    test('a status of 412 is throttling and 5xx is the network', () {
      expect(_refuse('{}', status: 412), BilibiliFailureKind.rateLimited);
      expect(_refuse('{}', status: 500), BilibiliFailureKind.network);
      expect(_refuse('{}', status: 503), BilibiliFailureKind.network);
      expect(_refuse('{}'), BilibiliFailureKind.apiChanged, reason: 'an envelope with no code');
      expect(_refuse('{"code":0,"data":{}}'), isNull, reason: 'zero with a good status is an answer');
      expect(BilibiliRoomParser.checked('{"code":0}', what: 'x'), isNotEmpty);
    });

    test('the codes say what the room should do next', () {
      expect(
        _refuse('{"code":-352,"message":"no"}'),
        BilibiliFailureKind.riskControl,
        reason: 'the WBI signature was refused',
      );
      expect(_refuse('{"code":-412,"message":"no"}'), BilibiliFailureKind.rateLimited);
      expect(_refuse('{"code":-101,"message":"no"}'), BilibiliFailureKind.needsLogin);
      for (final notFound in BilibiliRoomParser.notFoundCodes) {
        expect(_refuse('{"code":$notFound,"message":"no"}'), BilibiliFailureKind.notFound);
      }
      expect(
        _refuse('{"code":19002003,"message":"no"}'),
        BilibiliFailureKind.apiChanged,
        reason: 'an unknown code is a changed API',
      );
      expect(_refuse('{"code":7,"message":"no"}'), BilibiliFailureKind.apiChanged);
      expect(_refuse('{"code":7,"message":"no"}', extraNotFound: {7}), BilibiliFailureKind.notFound);
    });

    test('a body that is not an object, or a code 0 with a failed status, is api-changed', () {
      for (final body in ['not json', '[1,2]', '"a string"', '']) {
        expect(() => BilibiliRoomParser.checked(body, what: 'x'), _apiChanged, reason: '$body carries no envelope');
      }
      expect(
        () => BilibiliRoomParser.checked('{"code":0}', what: 'x', status: 404),
        throwsA(isA<BilibiliFailure>().having((f) => f.message, 'message', contains('HTTP 404'))),
        reason: 'a 404 is not an answer even when the code says zero',
      );
    });
  });

  group('the room as the user asked for it', () {
    test('a live room carries its names, its figures and its canonical long id', () {
      final read = BilibiliRoomParser.roomDetail(
        _body(
          _detailData(
            watched: {'switch': true, 'num': 12000, 'num_desc': '1.2万人看过'},
            description: '<p>line1</p><p><br></p><p>line2</p>',
          ),
        ),
        requestedId: '23058',
      );
      final room = read.room;
      expect(read.longId, '1234567890123', reason: 'every stream and danmaku request needs the canonical id');
      expect(room.roomId, '23058', reason: "a follow's identity does not change when the long id is different");
      expect(room.content.title, 'a & b', reason: 'entities are decoded once');
      expect(room.content.coverUrl, 'https://i0.hdslb.com/cover.png');
      expect(room.content.introduction, 'line1\n\nline2', reason: 'block ends become line breaks, tags drop');
      expect(room.content.notice, 'hi & bye');
      expect(room.anchor!.anchorId, '9');
      expect(room.anchor!.name, 'Ann & Co');
      expect(room.anchor!.avatarUrl, 'https://x.example/face.png@100w.jpg');
      expect(room.anchor!.liveStatus, LiveStatus.live);
      expect(room.area!.areaId, '1');
      expect(room.area!.areaName, '网格直播');
      expect(room.audience.popularity, 42);
      expect(room.audience.totalViewers, 12000);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.popularity);
      expect(room.broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(1790733600000, isUtc: true));
      expect(room.broadcast.restriction, isNull, reason: 'the answer wrote no special_type at all');
      expect(room.links.webUrl, '${BilibiliEndpoints.origin}/23058');
      expect(room.links.webUrl, isNot(contains(read.longId)));
    });

    test('the carousel is not live, and only a live paid room is restricted', () {
      final carousel = _room(_detailData(liveStatus: 2, specialType: 1, watched: {'switch': true, 'num': 9000}));
      expect(carousel.broadcast.liveStatus, LiveStatus.carousel);
      expect(carousel.broadcast.startedAt, isNull, reason: 'a looping old video has no start worth showing');
      expect(carousel.broadcast.restriction, LiveRestriction.none);
      expect(carousel.audience.totalViewers, isNull, reason: 'a hidden figure is not a watched count');

      final paid = _room(_detailData(specialType: 1));
      expect(paid.broadcast.restriction, LiveRestriction.paid);
      expect(_room(_detailData(specialType: 2)).broadcast.restriction, LiveRestriction.none);
      expect(_room(_detailData(specialType: 0)).broadcast.restriction, LiveRestriction.none);
      expect(_room(_detailData()).broadcast.restriction, isNull, reason: 'the answer says nothing');
      expect(_room(_detailData(liveStatus: '3')).broadcast.liveStatus, LiveStatus.offline);
      expect(_room(_detailData(liveStatus: null)).broadcast.liveStatus, LiveStatus.offline);
    });

    test('a watched figure only counts when the room switched it on', () {
      expect(_room(_detailData(watched: {'switch': false, 'num': 5000})).audience.totalViewers, isNull);
      expect(_room(_detailData(watched: {'switch': true})).audience.totalViewers, isNull);
      final noOnline = _room(_detailData(online: null, watched: {'switch': true, 'num': 5000}));
      expect(noOnline.audience.popularity, isNull);
      expect(noOnline.audience.primaryMetric, LiveAudienceMetricType.totalViewers);
      expect(_room(_detailData(online: -1)).audience.popularity, isNull, reason: 'a negative figure is none');
    });

    test('a room the answer does not describe is a changed API, not an empty room', () {
      expect(() => BilibiliRoomParser.roomDetail(_body(null), requestedId: '1'), _apiChanged);
      expect(() => BilibiliRoomParser.roomDetail(_body({}), requestedId: '1'), _apiChanged);
      expect(
        () => BilibiliRoomParser.roomDetail(
          _body({
            'room_info': {'room_id': 1},
          }),
          requestedId: '1',
        ),
        _apiChanged,
      );
      for (final roomId in [0, -1, null, 'abc']) {
        expect(
          () => BilibiliRoomParser.roomDetail(_body(_detailData(roomId: roomId)), requestedId: '1'),
          _apiChanged,
          reason: 'a room with no positive canonical id cannot be asked for anything',
        );
      }
      expect(
        () => BilibiliRoomParser.roomDetail(_body(_detailData(), code: -404), requestedId: '1'),
        throwsA(isA<BilibiliFailure>().having((f) => f.kind, 'kind', BilibiliFailureKind.notFound)),
      );
    });

    test('a room id is trimmed and an address is read for it', () {
      expect(_room(_detailData(), requestedId: ' 23058 ').roomId, '23058');
      expect(BilibiliRoomParser.roomDetail(_body(_detailData()), requestedId: '23058').room.roomId, '23058');
    });
  });

  group('the rest of the room path', () {
    test('the one-bit status ask says only whether the room is live', () {
      bool live(Object? status) => BilibiliRoomParser.liveStatus(_body({'live_status': status}));

      expect(live(1), isTrue);
      expect(live('1'), isTrue);
      for (final status in [0, 2, 'round', null]) {
        expect(live(status), isFalse, reason: 'live_status $status is not a live room');
      }
      expect(live(-1), isFalse);
      expect(() => BilibiliRoomParser.liveStatus('no json'), _apiChanged);
    });

    test('the danmaku endpoints keep the general gateway first and drop repeats', () {
      final info = BilibiliRoomParser.danmakuInfo(
        _body({
          'token': 'tok',
          'host_list': [
            {'host': 'broadcastlv.chat.bilibili.com', 'wss_port': 443},
            {'host': 'danmaku70-chat.bilibili.com', 'wss_port': 2202},
            {'host': 'danmaku70-chat.bilibili.com', 'wss_port': 2202},
            {'wss_port': 443},
            'not a host',
          ],
        }),
      );
      expect(info.token, 'tok');
      expect(info.servers.map((uri) => uri.toString()), [
        BilibiliEndpoints.danmakuGateway,
        'wss://danmaku70-chat.bilibili.com:2202/sub',
      ]);
      expect(info.servers, hasLength(2), reason: 'the list naming the gateway again is not a second server');
      expect(
        () => BilibiliRoomParser.danmakuInfo(_body({'host_list': <Object?>[]})),
        throwsA(isA<BilibiliFailure>().having((f) => f.kind, 'kind', BilibiliFailureKind.apiChanged)),
        reason: 'joining without a token is not a thing this client does',
      );
      expect(BilibiliRoomParser.danmakuInfo(_body({'token': 't', 'host_list': <Object?>[]})).servers, hasLength(1));
    });

    test('the guest buvid pair is appended to a login that has none of its own', () {
      expect(BilibiliRoomParser.cookie(buvid3: 'B3', buvid4: 'B4'), 'buvid3=B3;buvid4=B4;');
      expect(
        BilibiliRoomParser.cookie(buvid3: 'B3', buvid4: '', loginCookie: 'SESSDATA=x'),
        'SESSDATA=x;buvid3=B3;buvid4=;',
      );
      expect(
        BilibiliRoomParser.cookie(buvid3: 'G3', buvid4: 'G4', loginCookie: 'buvid3=MINE;SESSDATA=x'),
        'buvid3=MINE;SESSDATA=x',
        reason: "the user's own identity is never replaced by the guest pair",
      );
      expect(BilibiliRoomParser.cookie(buvid3: 'B3', buvid4: 'B4', loginCookie: '  '), 'buvid3=B3;buvid4=B4;');
      expect(BilibiliRoomParser.cookie(buvid3: 'B3', buvid4: 'B4', loginCookie: 'a=1;'), 'a=1;buvid3=B3;buvid4=B4;');
    });

    test('the uid is the cookie first, and a stored one only answers for it', () {
      expect(BilibiliRoomParser.danmakuUid(cookie: '', storedUid: 99), 0);
      expect(BilibiliRoomParser.danmakuUid(cookie: 'DedeUserID=7;', storedUid: 99), 7);
      expect(
        BilibiliRoomParser.danmakuUid(cookie: 'dedeuserid=7', storedUid: 99),
        7,
        reason: 'the field is matched loosely',
      );
      expect(BilibiliRoomParser.danmakuUid(cookie: 'DedeUserID=0;', storedUid: 99), 99);
      expect(BilibiliRoomParser.danmakuUid(cookie: 'SESSDATA=x', storedUid: 99), 99);
      expect(BilibiliRoomParser.danmakuUid(cookie: 'SESSDATA=x', storedUid: 0), 0);
    });

    test('an area id is the pair the list request needs', () {
      expect(BilibiliRoomParser.splitAreaId('1,2'), (parentAreaId: '1', areaId: '2'));
      expect(BilibiliRoomParser.splitAreaId(' 1,2 '), (parentAreaId: '1', areaId: '2'));
      expect(BilibiliRoomParser.splitAreaId('a,b,c'), (
        parentAreaId: 'a,b',
        areaId: 'c',
      ), reason: 'split at the last comma');
      expect(BilibiliRoomParser.splitAreaId('2'), (parentAreaId: '', areaId: '2'));
      expect(BilibiliRoomParser.splitAreaId(',2'), (parentAreaId: '', areaId: ',2'));
      expect(BilibiliRoomParser.splitAreaId('1,'), (parentAreaId: '', areaId: '1,'));
    });

    test('a super chat without both bounds is left out', () {
      final chats = BilibiliRoomParser.superChats(
        _body({
          'list': [
            {
              'id': 'sc-1',
              'message': 'pinned &amp; loud',
              'price': 30,
              'start_time': 1790733600,
              'end_time': 1790733700,
              'background_color': '#793749',
              'user_info': {'uname': 'Ann &amp; Co', 'face': 'https://x/f.png'},
            },
            {'id': 'sc-2', 'start_time': 1790733600},
            {'id': 'sc-3', 'end_time': 1790733700},
            'not an entry',
          ],
        }),
      );
      final one = chats.single;
      expect(chats, hasLength(1), reason: 'a window needs a start and an end');
      expect(one.messageId, 'sc-1');
      expect(one.text, 'pinned &amp; loud', reason: 'the message itself is shown as it came');
      expect(one.userName, 'Ann & Co');
      expect(one.faceUrl, 'https://x/f.png@200w.jpg');
      expect(one.price.amount, 30);
      expect(one.price.currency, 'CNY');
      expect(one.display.backgroundColor, '#793749');
      expect(one.endTime!.difference(one.startTime!).inSeconds, 100);
      expect(BilibiliRoomParser.superChats(_body({})), isEmpty);
      expect(() => BilibiliRoomParser.superChats(_body([], code: -412)), throwsA(isA<BilibiliFailure>()));
    });

    test('the area list pairs each leaf with its category', () {
      final areas = BilibiliRoomParser.areas(
        _body([
          {
            'id': 6,
            'name': '手游',
            'list': [
              {'id': 1153, 'parent_id': 6, 'name': '王者荣耀', 'pic': '//i0.hdslb.com/a.png'},
              {'name': 'no id'},
            ],
          },
          {'list': <Object?>[]},
        ]),
      );
      expect(areas, hasLength(1));
      expect(areas.single.areaId, '6,1153');
      expect(areas.single.areaName, '王者荣耀');
      expect(areas.single.parentAreaId, '6');
      expect(areas.single.parentAreaName, '手游');
      expect(areas.single.iconUrl, 'https://i0.hdslb.com/a.png@100w.png');
      expect(
        () => BilibiliRoomParser.areas(_body('not a list')),
        throwsA(isA<BilibiliFailure>().having((f) => f.kind, 'kind', BilibiliFailureKind.apiChanged)),
      );
    });
  });
}
