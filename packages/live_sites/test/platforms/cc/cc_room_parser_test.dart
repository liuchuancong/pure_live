import 'dart:convert';

import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/cc/api/cc_endpoints.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_failure.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_play_parser.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_room_parser.dart';
import 'package:test/test.dart';

// Fixture bodies encoded from E:\study\Pure_live\fixtures\cc
// (S02-area-page1, S03-live-page1, S04-search-page1, S05-*).

/// The start of the live area row, Beijing time, as UTC.
final DateTime _startedAt = DateTime.parse('2026-09-14T06:53:45.000Z');

Map<String, Object?> _areaRow({
  Object? cuteid = 341438909,
  Object? title = '《蛋仔派对》抖音巅峰杯',
  Object? nickname = '巅峰杯',
  Object? status = 1,
  Object? startat = '2026-09-14 14:53:45',
  Object? webccVisitor = 298945,
  Object? visionVisitor = 716,
  Object? gameName = '蛋仔派对',
  Object? gamename = '蛋仔派对',
  bool withStreams = true,
}) => {
  'cuteid': cuteid,
  'title': title,
  'nickname': nickname,
  'status': status,
  'startat': startat,
  'webcc_visitor': webccVisitor,
  'vision_visitor': visionVisitor,
  'game_name': gameName,
  'gamename': gamename,
  'purl': 'http://cc.fp.ps.netease.com/file/6aab6128abfc40028d7ee08aUCIYCrbq07',
  'cover': 'http://cc.fp.ps.netease.com/file/6ab9436767a2f9b676f80ff1ebgmOUUT07',
  'poster': 'http://cc.fp.ps.netease.com/file/6ab9436767a2f9b676f80ff1ebgmOUUT07',
  if (withStreams)
    'stream_list': {
      'high': {
        'vbr': 2000,
        'CDN_FMT': {'fws': 'wsSecret=x&wsTime=y'},
        'streamname': 'tc1',
      },
    },
};

const String _gametypeEcho = '9141';

String _areaBody(List<Object?> lives, {Object? gametype = _gametypeEcho}) =>
    jsonEncode({'videos': <Object?>[], 'gametype': ?gametype, 'lives': lives});

Map<String, Object?> _searchRow({
  Object? cuteid = 700700,
  Object? title = '姑苏跑玉山河',
  Object? nickname = '【谜底】老王2026',
  Object? status,
  Object? startat = '2026-07-26 17:40:29',
  Object? hotScore = 0,
  Object? followerNum = 2929971,
  Object? cover,
}) => {
  'cuteid': cuteid,
  'title': title,
  'nickname': nickname,
  'status': status,
  'startat': startat,
  'hot_score': hotScore,
  'follower_num': followerNum,
  'portrait': 'http://cc.fp.ps.netease.com/file/5e7395f58b7427d5bd670e2ftEqOBJyg02',
  'portraiturl': 'http://cc.fp.ps.netease.com/file/5e7395f58b7427d5bd670e2ftEqOBJyg02',
  'cover': cover,
  'poster': null,
  'game_name': '《梦幻西游》电脑版',
};

String _searchBody(List<Object?> rows) => jsonEncode({
  'webcc_anchor': {'count': rows.length, 'result': rows},
});

/// The S05-lives answer of an anchor broadcasting in channel [channel].
String _lives(String ccid, {Object? channel}) => jsonEncode({
  'msg': '',
  'code': 'OK',
  'data': {
    ccid: {'is_black': 0, 'channel_id': ?channel, 'ccid': ccid},
  },
});

/// The S05-channel-live row.
Map<String, Object?> _channelRow({
  Object? ccid = 341438909,
  Object? status = 1,
  Object? nolive,
  Object? personalLabel = '',
  Object? followerNum = 303,
}) => {
  'ccid': ccid,
  'cuteid': ccid,
  'cid': 5728999,
  'channel_id': 5728999,
  'uid': 260267129,
  'status': status,
  'nolive': nolive,
  'title': '《蛋仔派对》抖音巅峰杯',
  'nickname': '巅峰杯',
  'gamename': '蛋仔派对',
  'personal_label': personalLabel,
  'follower_num': followerNum,
  'startat': '2026-09-14 14:53:45',
  'webcc_visitor': 293325,
  'hot_score': 293325,
  'vision_visitor': 654,
  'purl': 'http://cc.fp.ps.netease.com/file/6aab6128abfc40028d7ee08aUCIYCrbq07',
  'cover': 'http://cc.fp.ps.netease.com/file/6ab9436767a2f9b676f80ff1ebgmOUUT07',
  'poster': null,
  'm3u8': 'http://cgi.v.cc.163.com/redirect/video/341438909.m3u8?secret=bac6536f08',
  'stream_list': {
    'original': {
      'vbr': 7999,
      'CDN_FMT': {'ali': 'auth_key=1790612944-key', 'fws': 'wsSecret=7c76c698&wsTime=6ab94450'},
      'streamname': '544d36afcaffd8355a34260267129',
    },
    'high': {
      'vbr': 2000,
      'CDN_FMT': {'fws': 'wsSecret=x'},
      'streamname': 'tc1',
    },
    'medium': {
      'vbr': 1000,
      'CDN_FMT': {'fws': 'wsSecret=y'},
      'streamname': 'tc2',
    },
    'low': {
      'vbr': 600,
      'CDN_FMT': {'fws': 'wsSecret=z'},
      'streamname': 'tc4',
    },
  },
};

String _channelBody(List<Object?> rows) => jsonEncode({'now_time': 1790526551, 'data': rows});

/// The S05-page-offline `__NEXT_DATA__` payload, as the page wraps it.
String _pageHtml(Map<String, Object?> info) =>
    '<!DOCTYPE html><html><head><script id="__NEXT_DATA__" type="application/json">'
    '${jsonEncode({
      'props': {
        'pageProps': {'roomInfoInitData': info},
      },
    })}'
    '</script></head><body></body></html>';

Map<String, Object?> _pageInfo({
  Object? nickname = '路人7758',
  Object? ccid = 376267758,
  Object micfirst = const {
    'uid': 297533520,
    'ccid': 376267758,
    'nickname': '路人7758',
    'purl': 'http://cc.res.netease.com/webcc/portrait/nsep/22_v2',
    'portraiturl': '',
  },
}) => {
  'announcement': '',
  'gamename': '其他游戏',
  'gametype': 0,
  'room_id': 3043777,
  'purl': 'http://cc.res.netease.com/webcc/portrait/nsep/22_v2',
  'ccid': ccid,
  'follower_num': 39802,
  'uid': 297533520,
  'nickname': nickname,
  'live_title': '路人7758的直播',
  'channel_id': 6734256,
  'live': {
    'gametype': -1,
    'title': '路人7758的直播',
    'follower_num': 39802,
    'gamename': '其他游戏',
    'uid': 297533520,
    'ccid': 376267758,
    'channel_id': 6734256,
  },
  'micfirst': micfirst,
};

CcFailure _failure(Object? Function() read) {
  try {
    read();
  } on CcFailure catch (failure) {
    return failure;
  }
  throw StateError('the answer was accepted');
}

void main() {
  group('areaRooms (S02-area-page1)', () {
    final body = _areaBody([
      _areaRow(),
      _areaRow(
        cuteid: 351834961,
        title: '【重播】第二十届蛋仔冲冲冲巅峰对决',
        nickname: '蛋仔冲冲冲锦标赛',
        startat: '2025-12-12 10:27:35',
        webccVisitor: 105150,
        visionVisitor: 1,
      ),
      _areaRow(cuteid: 'not-a-number', title: '没有有效 cuteid 的一行'),
    ]);

    test('the live rows carry heat and viewers side by side', () {
      final rooms = CcRoomParser.areaRooms(body, gametype: _gametypeEcho);
      expect(rooms, hasLength(2));
      final first = rooms[0];
      expect(first.roomId, '341438909');
      expect(first.platform, 'cc');
      expect(first.content.title, '《蛋仔派对》抖音巅峰杯');
      expect(first.anchor?.name, '巅峰杯');
      expect(first.anchor?.avatarUrl, 'http://cc.fp.ps.netease.com/file/6aab6128abfc40028d7ee08aUCIYCrbq07');
      expect(first.content.coverUrl, 'http://cc.fp.ps.netease.com/file/6ab9436767a2f9b676f80ff1ebgmOUUT07');
      expect(first.area?.areaName, '蛋仔派对');
      expect(first.audience.popularity, 298945);
      expect(first.audience.onlineViewers, 716);
      expect(first.audience.primaryMetric, LiveAudienceMetricType.popularity);
      expect(first.broadcast.liveStatus, LiveStatus.live);
      expect(first.broadcast.startedAt, _startedAt);
      expect(first.broadcast.restriction, LiveRestriction.none);
      expect(first.links.webUrl, 'https://cc.163.com/341438909/');
    });

    test('a "【重播】" rebroadcast is a replay (9-3)', () {
      final room = CcRoomParser.areaRooms(body, gametype: _gametypeEcho)[1];
      expect(room.roomId, '351834961');
      expect(room.broadcast.liveStatus, LiveStatus.replay);
      expect(room.broadcast.startedAt, DateTime.parse('2025-12-12T02:27:35.000Z'));
    });

    test('a row without a valid cuteid is skipped', () {
      final rooms = CcRoomParser.areaRooms(body, gametype: _gametypeEcho);
      expect(rooms.map((room) => room.roomId), everyElement(isNot('not-a-number')));
    });

    test('the answer must echo the gametype and hold a lives list', () {
      expect(
        _failure(() => CcRoomParser.areaRooms(_areaBody([], gametype: 9142), gametype: _gametypeEcho)).kind,
        CcFailureKind.apiChanged,
      );
      expect(_failure(() => CcRoomParser.areaRooms('[]', gametype: _gametypeEcho)).kind, CcFailureKind.apiChanged);
      expect(
        _failure(() => CcRoomParser.areaRooms('not json', gametype: _gametypeEcho)).kind,
        CcFailureKind.apiChanged,
      );
    });

    test('more than 1000 rows are api-changed', () {
      final rows = List<Object?>.generate(1001, (index) => _areaRow(cuteid: index + 1));
      expect(
        _failure(() => CcRoomParser.areaRooms(_areaBody(rows), gametype: _gametypeEcho)).kind,
        CcFailureKind.apiChanged,
      );
    });

    test('status 0 is offline, anything else unknown, and off air has no start', () {
      final rooms = CcRoomParser.areaRooms(
        _areaBody([_areaRow(cuteid: 2, status: 0), _areaRow(cuteid: 3, status: 9)]),
        gametype: _gametypeEcho,
      );
      expect(rooms[0].broadcast.liveStatus, LiveStatus.offline);
      expect(rooms[0].broadcast.startedAt, isNull);
      expect(rooms[1].broadcast.liveStatus, LiveStatus.unknown);
    });
  });

  group('recommendRooms (S03-live-page1)', () {
    test('every card is on air, the area read from gamename (9-2)', () {
      final row = _areaRow()
        ..remove('status')
        ..remove('game_name')
        ..remove('stream_list');
      final rooms = CcRoomParser.recommendRooms(_areaBody([row]));
      expect(rooms, hasLength(1));
      expect(rooms[0].broadcast.liveStatus, LiveStatus.live);
      expect(rooms[0].area?.areaName, '蛋仔派对');
      expect(rooms[0].broadcast.restriction, isNull);
    });

    test('a rebroadcast of the feed is a replay; no lives list is api-changed', () {
      final rooms = CcRoomParser.recommendRooms(_areaBody([_areaRow(title: '【重播】决赛日')]));
      expect(rooms[0].broadcast.liveStatus, LiveStatus.replay);
      expect(_failure(() => CcRoomParser.recommendRooms('{}')).kind, CcFailureKind.apiChanged);
    });
  });

  group('searchRooms (S04-search-page1)', () {
    test('an offline streamer shows the portrait as cover and followers as audience', () {
      final rooms = CcRoomParser.searchRooms(_searchBody([_searchRow()]));
      expect(rooms, hasLength(1));
      final room = rooms[0];
      expect(room.roomId, '700700');
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.content.coverUrl, 'http://cc.fp.ps.netease.com/file/5e7395f58b7427d5bd670e2ftEqOBJyg02');
      expect(room.anchor?.followerCount, 2929971);
      expect(room.audience.popularity, isNull);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.followers);
      expect(room.area?.areaName, '《梦幻西游》电脑版');
    });

    test('an on-air card shows the broadcast cover and heat; a rebroadcast a replay (9-5)', () {
      final rooms = CcRoomParser.searchRooms(
        _searchBody([
          _searchRow(
            cuteid: 163163,
            title: '【重播】第242届武神坛-淘汰赛',
            status: 1,
            hotScore: 222646,
            followerNum: 1682378,
            cover: 'http://cc.fp.ps.netease.com/file/6ab9436643f99b2fadba9ccbYS2mI8DL07',
          ),
        ]),
      );
      final room = rooms.single;
      expect(room.broadcast.liveStatus, LiveStatus.replay);
      expect(room.content.coverUrl, 'http://cc.fp.ps.netease.com/file/6ab9436643f99b2fadba9ccbYS2mI8DL07');
      expect(room.audience.popularity, 222646);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.popularity);
      expect(room.broadcast.startedAt, DateTime.parse('2026-07-26T09:40:29.000Z'));
    });

    test('an offline streamer keeps no heat even with a hot_score (search visitors lie)', () {
      final rooms = CcRoomParser.searchRooms(_searchBody([_searchRow(hotScore: 5000)]));
      expect(rooms[0].audience.popularity, isNull);
    });

    test('no webcc_anchor is api-changed', () {
      expect(_failure(() => CcRoomParser.searchRooms('{"webcc":1}')).kind, CcFailureKind.apiChanged);
    });

    test('the anchors of the search (3.x did the same)', () {
      final rooms = CcRoomParser.searchRooms(_searchBody([_searchRow()]));
      final anchors = CcRoomParser.searchAnchors(rooms);
      expect(anchors.single.platform, 'cc');
      expect(anchors.single.anchorId, '700700');
      expect(anchors.single.name, '【谜底】老王2026');
      expect(anchors.single.liveStatus, LiveStatus.offline);
    });
  });

  group('liveChannel (S05-lives-*)', () {
    test('the channel an anchor broadcasts in', () {
      expect(CcRoomParser.liveChannel(_lives('341438909', channel: 5728999), ccid: '341438909'), '5728999');
    });

    test('an offline or unknown anchor has none', () {
      expect(CcRoomParser.liveChannel(_lives('376267758'), ccid: '376267758'), isNull);
      expect(CcRoomParser.liveChannel(_lives('88888888888'), ccid: '88888888888'), isNull);
    });

    test('HTTP 400 is not-found; a wrong code or no entry is api-changed', () {
      expect(_failure(() => CcRoomParser.liveChannel('', ccid: 'x', status: 400)).kind, CcFailureKind.notFound);
      expect(
        _failure(() => CcRoomParser.liveChannel('{"code":"Err"}', ccid: '341438909')).kind,
        CcFailureKind.apiChanged,
      );
      expect(
        _failure(() => CcRoomParser.liveChannel('{"code":"OK","data":{}}', ccid: '341438909')).kind,
        CcFailureKind.apiChanged,
      );
    });
  });

  group('channelRoom (S05-channel-live)', () {
    test('the live room of the channel, its tier list riding the runtime handle', () {
      final room = CcRoomParser.channelRoom(_channelBody([_channelRow()]), ccid: '341438909');
      expect(room, isNotNull);
      expect(room!.roomId, '341438909');
      expect(room.content.title, '《蛋仔派对》抖音巅峰杯');
      expect(room.anchor?.name, '巅峰杯');
      expect(room.anchor?.anchorId, '260267129');
      expect(room.area?.areaName, '蛋仔派对');
      expect(room.audience.popularity, 293325);
      expect(room.audience.onlineViewers, 654);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.popularity);
      expect(room.anchor?.followerCount, 303);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.startedAt, _startedAt);
      expect(room.broadcast.restriction, LiveRestriction.none);
      expect(room.links.webUrl, 'https://cc.163.com/341438909/');
      expect(room.runtime.streamHandle, isA<CcRoomData>());
      final data = room.runtime.streamHandle! as CcRoomData;
      expect(data.streams?['original'], isNotNull);
      expect(data.playlist, 'http://cgi.v.cc.163.com/redirect/video/341438909.m3u8?secret=bac6536f08');
    });

    test('a channel without a room (nolive, no rows) is null; another anchor api-changed', () {
      expect(CcRoomParser.channelRoom(_channelBody([]), ccid: '376267758'), isNull);
      expect(CcRoomParser.channelRoom(_channelBody([_channelRow(nolive: 1)]), ccid: '341438909'), isNull);
      expect(
        _failure(() => CcRoomParser.channelRoom(_channelBody([_channelRow(ccid: 999)]), ccid: '341438909')).kind,
        CcFailureKind.apiChanged,
      );
    });

    test('status 0 is offline; the label leads the introduction and notice', () {
      final room = CcRoomParser.channelRoom(
        _channelBody([_channelRow(status: 0, personalLabel: '每晚八点开播')]),
        ccid: '341438909',
      );
      expect(room!.broadcast.liveStatus, LiveStatus.offline);
      expect(room.broadcast.startedAt, isNull);
      expect(room.content.introduction, '每晚八点开播');
      expect(room.content.notice, '每晚八点开播');
    });
  });

  group('pageRoom (S05-page-*)', () {
    test('the offline room of an anchor without a live channel', () {
      final room = CcRoomParser.pageRoom(_pageHtml(_pageInfo()), ccid: '376267758');
      expect(room.roomId, '376267758');
      expect(room.anchor?.name, '路人7758');
      expect(room.content.title, '路人7758的直播');
      expect(room.anchor?.avatarUrl, 'http://cc.res.netease.com/webcc/portrait/nsep/22_v2');
      expect(room.area?.areaName, '其他游戏');
      expect(room.audience.popularity, 39802);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.followers);
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.broadcast.startedAt, isNull);
      expect(room.links.webUrl, 'https://cc.163.com/376267758/');
    });

    test('code 404 (no ccid) is not-found, with the platform reason', () {
      final failure = _failure(
        () => CcRoomParser.pageRoom(_pageHtml({'code': 404, 'reason': 'no ccid'}), ccid: '88888888888'),
      );
      expect(failure.kind, CcFailureKind.notFound);
      expect(failure.message, contains('no ccid'));
    });

    test('a page without the data or the nickname is api-changed; another ccid too', () {
      expect(_failure(() => CcRoomParser.pageRoom('<html></html>', ccid: '376267758')).kind, CcFailureKind.apiChanged);
      expect(
        _failure(
          () => CcRoomParser.pageRoom(
            _pageHtml(_pageInfo(nickname: '', micfirst: {'ccid': 376267758})),
            ccid: '376267758',
          ),
        ).kind,
        CcFailureKind.apiChanged,
      );
      expect(
        _failure(() => CcRoomParser.pageRoom(_pageHtml(_pageInfo(ccid: 1, micfirst: {'ccid': 1})), ccid: '376267758'))
            .kind,
        CcFailureKind.apiChanged,
      );
    });

    test('a bad status is gated like an API answer', () {
      expect(_failure(() => CcRoomParser.pageRoom('', ccid: '376267758', status: 429)).kind, CcFailureKind.rateLimited);
      expect(_failure(() => CcRoomParser.pageRoom('', ccid: '376267758', status: 500)).kind, CcFailureKind.network);
    });
  });

  group('anchorExists (S09-exists-*)', () {
    test('code 0 is an account, code 4 (没有对应的ccid) is none', () {
      expect(CcRoomParser.anchorExists('{"msg":"","code":0,"data":{}}'), isTrue);
      expect(CcRoomParser.anchorExists('{"msg":"没有对应的ccid","code":4,"data":{}}'), isFalse);
    });

    test('any other code is api-changed', () {
      expect(_failure(() => CcRoomParser.anchorExists('{"code":2}')).kind, CcFailureKind.apiChanged);
    });
  });

  group('ids and links', () {
    test('a positive decimal ccid without leading zeros, on the three link forms', () {
      expect(CcEndpoints.roomIdFromUrl('https://cc.163.com/341438909'), '341438909');
      expect(
        CcEndpoints.roomIdFromUrl('https://cc.163.com/341438909/?open=blizzardtv&from=8382&platform=ds'),
        '341438909',
      );
      expect(CcEndpoints.roomIdFromUrl('http://cc.163.com//720953'), '720953');
      expect(CcEndpoints.roomIdFromUrl('https://h5.cc.163.com/cc/720953'), '720953');
      expect(CcEndpoints.roomIdFromUrl('https://ds.163.com/glive/?ccid=720953'), '720953');
      expect(CcEndpoints.roomIdFromUrl('https://CC.163.COM/720953'), '720953');
    });

    test('leading zeros fold; 0 and non-numbers name no room', () {
      expect(CcEndpoints.roomIdFromUrl('https://cc.163.com/0720953'), '720953');
      expect(CcEndpoints.roomIdFromUrl('https://cc.163.com/0'), isNull);
      expect(CcEndpoints.roomIdFromUrl('https://cc.163.com/n/ds_category/mhxy/'), isNull);
      expect(CcEndpoints.roomIdFromUrl('https://cc.163.com/'), isNull);
      expect(CcEndpoints.roomIdFromUrl('https://h5.cc.163.com/cc/'), isNull);
      expect(CcEndpoints.roomIdFromUrl('https://ds.163.com/glive/'), isNull);
    });

    test('another host, scheme or shape names no room', () {
      expect(CcEndpoints.roomIdFromUrl('ftp://cc.163.com/720953'), isNull);
      expect(CcEndpoints.roomIdFromUrl('https://example.com/720953'), isNull);
      expect(CcEndpoints.roomIdFromUrl('https://h5.cc.163.com/live/720953'), isNull);
      expect(CcEndpoints.roomIdFromUrl('https://ds.163.com/play/?ccid=720953'), isNull);
    });

    test('the host decides: a port or user info on it changes nothing (the reference rule)', () {
      expect(CcEndpoints.roomIdFromUrl('https://cc.163.com:8443/720953'), '720953');
      expect(CcEndpoints.roomIdFromUrl('https://user:pw@cc.163.com/720953'), '720953');
    });

    test('the play lines carry the media headers', () {
      final headers = CcEndpoints.mediaHeaders('341438909');
      expect(headers['user-agent'], CcEndpoints.userAgent);
      expect(headers['origin'], 'https://cc.163.com');
      expect(headers['referer'], 'https://cc.163.com/341438909/');
      expect(CcEndpoints.mediaHeaders('')['referer'], 'https://cc.163.com/');
    });
  });
}
