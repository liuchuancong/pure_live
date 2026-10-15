import 'dart:convert';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/capabilities/live_hot_provider.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site_context.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/core/live_site_runtime_info.dart';
import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_content/room_content.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/inke/api/inke_endpoints.dart';
import 'package:live_sites/src/platforms/inke/api/inke_http.dart';
import 'package:live_sites/src/platforms/inke/inke_site.dart';
import 'package:live_sites/src/platforms/inke/parsers/inke_failure.dart';
import 'package:live_sites/src/platforms/inke/parsers/inke_json.dart';
import 'package:live_sites/src/platforms/inke/parsers/inke_room_parser.dart';
import 'package:test/test.dart';

/// The clock of the tests: 2026-09-30, in the afternoon.
final DateTime _at = DateTime.parse('2026-09-30T14:00:00.000Z').toUtc();

const String _uid = '12345';
const String _otherUid = '67890';
const String _liveId = '9876543210987654';

/// `_at` in Unix seconds: the leases' issue time.
final int _atSeconds = _at.millisecondsSinceEpoch ~/ 1000;

/// Two hours after the clock, in hexadecimal Unix seconds: a pull URL's
/// `wsABStime`.
final String _hexExpiry = (_atSeconds + 2 * 3600).toRadixString(16);

/// The broadcast's start, an hour before the clock.
final int _startedSeconds = _atSeconds - 3600;

String _json(Object? data) => jsonEncode(data);

LiveResponse _resp(int status, String body) =>
    LiveResponse(statusCode: status, headers: const {}, bodyBytes: Uint8List.fromList(utf8.encode(body)));

String _flvUrl(String liveId) =>
    'https://live-pull-ws.ikstatic.cn/live/${liveId}_t.flv?wsABStime=$_hexExpiry&wsSecret=abc';

String _zegoUrl(String liveId) =>
    'http://live-pull-zego.ikstatic.cn/inkemain/${liveId}_0_en.flv?wsABStime=$_hexExpiry&codecInfo=8192';

Map<String, Object?> _row({String uid = _uid, String liveId = _liveId, String nick = '主播甲'}) => {
  'uid': uid,
  'live_id': liveId,
  'nick': nick,
  'portrait': 'https://img.inke.cn/a.png',
  'stream_addr': _flvUrl(liveId),
};

Map<String, Object?> _liveRow({
  String uid = _uid,
  String liveId = _liveId,
  String title = '晚间弹唱',
  int status = 1,
  Object? streamAddr,
  Object? zegoAddr,
  Object? numbers = const {'real': 42},
  Object? heat = 9001,
}) => {
  'creator': uid,
  'id': liveId,
  'status': status,
  'name': title,
  'cover': 'https://img.inke.cn/cover.png',
  'start_time': _startedSeconds,
  'numbers': numbers,
  'online_users': heat,
  'stream_addr': streamAddr ?? _flvUrl(liveId),
  'stream_multi_addr': zegoAddr ?? _zegoUrl(liveId),
};

/// A hot-list row: the broadcast with its creator as the app gives it there.
Map<String, Object?> _hotRow({String uid = _uid, String nick = '主播甲'}) => {
  ..._liveRow(uid: uid),
  'creator': {'id': uid, 'nick': nick, 'portrait': 'https://img.inke.cn/a.png'},
};

String _shareFixture({
  int code = 0,
  Object? uid = _uid,
  Object? liveId = _liveId,
  String nick = '主播甲',
  Object? liveName = '晚间弹唱',
  Object? status = 1,
}) => _json({
  'error_code': code,
  'data': {
    'live_uid': uid,
    'status': status,
    'liveid': liveId,
    'live_name': liveName,
    'portrait': 'https://img.inke.cn/room.png',
    'media_info': {'nick': nick, 'inke_id': uid, 'portrait': 'https://img.inke.cn/a.png'},
  },
});

String _publishFixture({Object? live, int dmError = 0}) => _json({'dm_error': dmError, 'live': ?live});

String _topFixture({Object? list}) => _json({
  'error_code': 0,
  'data': {
    'list': list ?? <Map<String, Object?>>[_row()],
  },
});

String _channelsFixture({Object? list}) => _json({
  'error_code': 0,
  'data': {
    'list':
        list ??
        <Map<String, Object?>>[
          {
            'tab_key': 'dance',
            'channel_name': '舞蹈',
            'list': [_row()],
          },
          {'tab_key': 'sing', 'channel_name': '唱见', 'list': []},
        ],
  },
});

String _hotFixture({Object? lives}) => _json({
  'dm_error': 0,
  'lives': lives ?? <Map<String, Object?>>[_hotRow()],
});

final class _Seen {
  new(LiveRequest request) : url = request.url;
  final Uri url;
}

final class _FakeHttp implements LiveHttp {
  new(this.onSend);
  final LiveResponse Function(_Seen request) onSend;
  final List<_Seen> sent = [];
  bool closed = false;

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    final seen = _Seen(request);
    sent.add(seen);
    return onSend(seen);
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();

  @override
  void close() => closed = true;
}

/// The site over a fake transport, with a movable clock.
({InkeSite site, _FakeHttp http, void Function(Duration) advance}) _adapter({
  LiveResponse Function(_Seen request)? onSend,
  bool Function()? preferH264,
}) {
  final http = _FakeHttp(onSend ?? _ordinary);
  var clock = _at;
  final site = InkeSite(http: InkeHttp(http), preferH264: preferH264, now: () => clock);
  return (site: site, http: http, advance: (Duration by) => clock = clock.add(by));
}

/// The answers of the site: the room, the broadcast, the showcases and the
/// hot list.
LiveResponse _ordinary(_Seen request) {
  final path = request.url.path;
  if (path == '/web/live_share_pc') return _resp(200, _shareFixture());
  if (path == '/api/live/now_publish') return _resp(200, _publishFixture(live: _liveRow()));
  if (path == '/web/Live_top_pc') return _resp(200, _topFixture());
  if (path == '/web/Live_channel_pc') return _resp(200, _channelsFixture());
  if (path == '/api/live/simpleall') return _resp(200, _hotFixture());
  return _resp(404, 'nope');
}

T _right<T>(Either<LiveSiteError, T> either) => either.match((left) => throw StateError('$left'), (right) => right);

LiveSiteError _leftOf<T>(Either<LiveSiteError, T> either) =>
    either.match((left) => left, (right) => throw StateError('not a left: $either'));

/// A site error's type, for the gate checks.
Matcher failureKind(InkeFailureKind kind) => isA<InkeFailure>().having((failure) => failure.kind, 'kind', kind);

void main() {
  group('envelopes and readers', () {
    test('a status says what kind of answer it is', () {
      void expectKind(int status, InkeFailureKind kind) {
        try {
          InkeJson.checkStatus(status, 'x');
          fail('no throw for $status');
        } on InkeFailure catch (failure) {
          expect(failure.kind, kind);
        }
      }

      expectKind(401, InkeFailureKind.riskControl);
      expectKind(403, InkeFailureKind.riskControl);
      expectKind(404, InkeFailureKind.notFound);
      expectKind(429, InkeFailureKind.rateLimited);
      for (final status in [301, 500, 503]) {
        expectKind(status, InkeFailureKind.network);
      }
      InkeJson.checkStatus(200, 'x');
    });

    test('the body is bounded and must be a JSON object', () {
      expect(() => InkeJson.json('<html>', 'x', 200), throwsA(failureKind(InkeFailureKind.apiChanged)));
      expect(
        () => InkeJson.json('{"a":"${'x' * 1100000}"}', 'x', 200),
        throwsA(predicate((failure) => '$failure'.contains('answer over'))),
      );
      expect(() => InkeJson.json('[1,2]', 'x', 200), throwsA(failureKind(InkeFailureKind.apiChanged)));
      expect(InkeJson.json('{"a":1}', 'x', 200), {'a': 1});
    });

    test('a website answer needs error_code 0, or the offline code', () {
      expect(InkeRoomParser.webData('{"error_code":0,"data":{"a":1}}', what: 'w'), {'a': 1});
      expect(InkeRoomParser.webData('{"error_code":${InkeEndpoints.noLiveCode}}', what: 'w', offline: true), isNull);
      for (final (body, offline) in [
        ('{"data":{}}', false), // no error_code
        ('{"error_code":22,"data":{}}', false),
        ('{"error_code":"x","data":{}}', false),
        ('{"error_code":${InkeEndpoints.noLiveCode},"data":{}}', false), // offline code without offline
      ]) {
        expect(
          () => InkeRoomParser.webData(body, what: 'w', offline: offline),
          throwsA(failureKind(InkeFailureKind.apiChanged)),
        );
      }
    });

    test('an app answer needs dm_error 0', () {
      expect(InkeRoomParser.appData('{"dm_error":0,"a":1}', what: 'w'), {'dm_error': 0, 'a': 1});
      for (final body in ['{"a":1}', '{"dm_error":3}', '{"dm_error":"x"}']) {
        expect(() => InkeRoomParser.appData(body, what: 'w'), throwsA(failureKind(InkeFailureKind.apiChanged)));
      }
    });

    test('ids, counts and times are read strictly', () {
      expect(InkeJson.idOrNull(12345), '12345');
      expect(InkeJson.idOrNull(' 12345 '), '12345');
      expect(InkeJson.idOrNull('0123'), isNull, reason: 'no leading zero');
      expect(InkeJson.idOrNull('1234567890123456789'), isNull, reason: 'at most 18 digits');
      expect(InkeJson.idOrNull('abc'), isNull);
      expect(() => InkeJson.idOf('x', 'field'), throwsA(predicate((failure) => '$failure'.contains('field'))));
      expect(InkeJson.count('42'), 42);
      expect(InkeJson.count(-1), isNull);
      expect(InkeJson.count('x'), isNull);
      expect(
        InkeJson.startedAt(_startedSeconds),
        DateTime.fromMillisecondsSinceEpoch(_startedSeconds * 1000, isUtc: true),
      );
      expect(InkeJson.startedAt(_startedSeconds * 1000), isNull, reason: 'milliseconds are not seconds');
      expect(InkeJson.startedAt(0), isNull);
      expect(InkeJson.text(' 甲 '), '甲');
      expect(InkeJson.text(3), '');
    });

    test('a failure folds refusals into the throttle and names the transient kinds', () {
      const refusal = InkeFailure(InkeFailureKind.riskControl, 'refused');
      expect(refusal.toLiveSiteError('inke'), isA<LiveSiteRateLimitError>());
      expect(
        const InkeFailure(InkeFailureKind.rateLimited, 'slow').toLiveSiteError('inke'),
        isA<LiveSiteRateLimitError>(),
      );
      expect(const InkeFailure(InkeFailureKind.notFound, 'no').toLiveSiteError('inke'), isA<LiveSiteNotFound>());
      expect(const InkeFailure(InkeFailureKind.apiChanged, 'bad').toLiveSiteError('inke'), isA<LiveSiteParseError>());
      expect(const InkeFailure(InkeFailureKind.network, 'down').toLiveSiteError('inke'), isA<LiveSiteNetworkError>());
      expect(
        const InkeFailure(InkeFailureKind.streamUnavailable, 'dark').toLiveSiteError('inke'),
        isA<LiveSiteContentUnavailable>(),
      );
      expect(
        const InkeFailure(InkeFailureKind.invalidArgument, 'no').toLiveSiteError('inke'),
        isA<LiveSiteInvalidArgument>(),
      );
      expect(const InkeFailure(InkeFailureKind.network, 'down').isTransient, isTrue);
      expect(const InkeFailure(InkeFailureKind.rateLimited, 'slow').isTransient, isTrue);
      for (final kind in [
        InkeFailureKind.notFound,
        InkeFailureKind.apiChanged,
        InkeFailureKind.riskControl,
        InkeFailureKind.streamUnavailable,
        InkeFailureKind.invalidArgument,
      ]) {
        expect(InkeFailure(kind, 'x').isTransient, isFalse, reason: kind.name);
      }
    });
  });

  group('showcases', () {
    test('the areas are the top list and then the channels, under 映客', () {
      final areas = InkeRoomParser.areas(_channelsFixture());
      expect(areas.map((area) => area.areaId), ['Live_top_pc', 'dance', 'sing']);
      expect(areas.first.areaName, '官网推荐');
      expect(areas.every((area) => area.parentAreaId == 'inke' && area.parentAreaName == '映客'), isTrue);
      expect(areas.every((area) => area.platform == 'inke'), isTrue);
    });

    test('a channel without a key, a name or rows is skipped, a duplicate key too', () {
      final areas = InkeRoomParser.areas(
        _channelsFixture(
          list: <Map<String, Object?>>[
            {'tab_key': 'bad key!', 'channel_name': 'X', 'list': []},
            {'tab_key': 'good', 'channel_name': '', 'list': []},
            {'tab_key': 'good', 'channel_name': 'Y', 'list': 'no rows'},
            {
              'tab_key': 'good',
              'channel_name': '舞蹈',
              'list': [_row()],
            },
            {'tab_key': 'good', 'channel_name': ' again', 'list': []},
          ],
        ),
      );
      expect(areas.map((area) => area.areaId), ['Live_top_pc', 'good']);
      expect(areas.last.areaName, '舞蹈');
    });

    test('more channels than the platform has, or no list, is api-changed', () {
      for (final list in <Object>[
        List.filled(101, {'tab_key': 'a', 'channel_name': 'A', 'list': <Object>[]}),
        'no list',
        List.filled(1001, 'x'),
      ]) {
        expect(() => InkeRoomParser.areas(_channelsFixture(list: list)), throwsA(isA<InkeFailure>()));
      }
    });

    test('a top page lists each live room once, with the nickname as title', () {
      final rooms = InkeRoomParser.topPage(
        _topFixture(
          list: <Map<String, Object?>>[
            _row(),
            _row(),
            _row(uid: _otherUid, liveId: '87654321'),
          ],
        ),
      );
      expect(rooms.map((room) => room.roomId), [_uid, _otherUid]);
      expect(rooms.first.content.title, '主播甲');
      expect(rooms.first.anchor?.name, '主播甲');
      expect(rooms.first.anchor?.avatarUrl, 'https://img.inke.cn/a.png');
      expect(rooms.first.content.coverUrl, 'https://img.inke.cn/a.png');
      expect(rooms.first.broadcast.liveStatus, LiveStatus.live);
      expect(rooms.first.broadcast.effectiveLiveStatus, LiveStatus.live);
      expect(rooms.first.links.webUrl, InkeEndpoints.roomUrl(_uid, liveId: _liveId));
      expect(rooms.first.audience.onlineViewers, isNull);
    });

    test('a showcase row without a uid, broadcast id or name is skipped', () {
      final rooms = InkeRoomParser.topPage(
        _topFixture(
          list: <Map<String, Object?>>[
            _row(),
            _row(liveId: '0123'),
            {'uid': _otherUid, 'live_id': '87654321'},
          ],
        ),
      );
      expect(rooms, hasLength(1));
    });

    test('a channel page is the channel once, an unknown one is not-found', () {
      expect(InkeRoomParser.channelPage(_channelsFixture(), tabKey: 'dance').map((room) => room.roomId), [_uid]);
      expect(
        () => InkeRoomParser.channelPage(_channelsFixture(), tabKey: 'nope'),
        throwsA(failureKind(InkeFailureKind.notFound)),
      );
      expect(InkeRoomParser.channelRooms(_channelsFixture()).map((room) => room.roomId), [_uid]);
    });
  });

  group('hot list', () {
    test('a live row carries the app title, cover, audience and start', () {
      final rooms = InkeRoomParser.hotPage(_hotFixture());
      expect(rooms, hasLength(1));
      final room = rooms.single;
      expect(room.roomId, _uid);
      expect(room.content.title, '晚间弹唱');
      expect(room.content.coverUrl, 'https://img.inke.cn/cover.png');
      expect(room.audience.onlineViewers, 42);
      expect(room.audience.popularity, 9001);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      expect(room.broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(_startedSeconds * 1000, isUtc: true));
      expect(room.broadcast.restriction, LiveRestriction.none, reason: 'the app gave a line');
      expect(room.links.webUrl, InkeEndpoints.roomUrl(_uid, liveId: _liveId));
    });

    test('a row without lines says nothing about a restriction', () {
      final room = InkeRoomParser.hotPage(
        _hotFixture(
          lives: <Map<String, Object?>>[
            {..._hotRow(uid: _otherUid), 'numbers': '', 'stream_addr': '', 'stream_multi_addr': ''},
          ],
        ),
      ).single;
      expect(room.broadcast.restriction, isNull);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.popularity, reason: 'the heat remains');
    });

    test('a stand-in title reads as no title, so the nickname stands in', () {
      final room = InkeRoomParser.hotPage(
        _hotFixture(
          lives: <Map<String, Object?>>[
            {..._hotRow(), 'name': InkeEndpoints.placeholderTitle},
          ],
        ),
      ).single;
      expect(room.content.title, '主播甲');
    });

    test('a row that is not a live broadcast with an anchor and an id is skipped', () {
      final rooms = InkeRoomParser.hotPage(
        _hotFixture(
          lives: <Map<String, Object?>>[
            _hotRow(),
            {..._hotRow(uid: _otherUid), 'status': 0},
            {'id': '87654321', 'status': 1},
            {
              'creator': {'id': _otherUid, 'nick': '乙'},
              'status': 1,
            },
          ],
        ),
      );
      expect(rooms.map((room) => room.roomId), [_uid]);
    });
  });

  group('search filter', () {
    LiveRoom card(String uid, String nick) => LiveRoom.normalized(
      platform: 'inke',
      roomId: uid,
      content: RoomContent(title: nick),
      anchor: LiveAnchor.normalized(platform: 'inke', anchorId: uid, name: nick),
    );

    test('nicknames match case-ignored, each uid once at its first place', () {
      final matches = InkeRoomParser.searchShowcases(
        '  甲 ',
        [card(_uid, '主播甲'), card(_otherUid, '小甲')],
        hot: [card(_uid, '甲缩略')],
      );
      expect(matches.rooms.map((room) => room.anchor?.name), ['甲缩略', '小甲'], reason: 'the hot card wins');
      expect(matches.hasMore, isFalse);
      final upper = InkeRoomParser.searchShowcases('ABC', [card(_uid, 'xAbcY')]);
      expect(upper.rooms, hasLength(1));
      expect(InkeRoomParser.searchShowcases('', [card(_uid, '甲')]).rooms, isEmpty);
    });

    test('a room the hot list also has is its hot card, and pages slice', () {
      final showcase = [card(_uid, '主播甲'), card(_otherUid, '小甲')];
      final hot = LiveRoom.normalized(
        platform: 'inke',
        roomId: _uid,
        content: const RoomContent(title: '热榜标题'),
        anchor: LiveAnchor.normalized(platform: 'inke', anchorId: _uid, name: '主播甲'),
      );
      final first = InkeRoomParser.searchShowcases('甲', showcase, hot: [hot], pageSize: 1);
      expect(first.rooms.single.content.title, '热榜标题', reason: 'the hot card upgrades the match');
      expect(first.hasMore, isTrue);
      final second = InkeRoomParser.searchShowcases('甲', showcase, hot: [hot], page: 2, pageSize: 1);
      expect(second.rooms.single.anchor?.name, '小甲');
      expect(second.hasMore, isFalse);
    });
  });

  group('room detail and broadcast', () {
    test('a live room carries the website answer and its broadcast id', () {
      final room = InkeRoomParser.detail(_shareFixture(), uid: _uid);
      expect(room.roomId, _uid);
      expect(room.anchor?.name, '主播甲');
      expect(room.content.title, '晚间弹唱');
      expect(room.anchor?.avatarUrl, 'https://img.inke.cn/a.png');
      expect(room.content.coverUrl, 'https://img.inke.cn/room.png');
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.links.webUrl, InkeEndpoints.roomUrl(_uid, liveId: _liveId));
      expect(room.runtime.streamHandle, isA<InkeRoomData>());
      expect((room.runtime.streamHandle! as InkeRoomData).liveId, _liveId);
    });

    test('the stand-in title reads as no title', () {
      expect(
        InkeRoomParser.detail(_shareFixture(liveName: InkeEndpoints.placeholderTitle), uid: _uid).content.title,
        '主播甲',
      );
      expect(InkeRoomParser.detail(_shareFixture(liveName: ''), uid: _uid).content.title, '主播甲');
    });

    test('an answer about another room or anchor, or a dead status, is api-changed', () {
      for (final body in [
        _shareFixture(uid: _otherUid),
        _shareFixture(status: 0),
        _shareFixture(status: '2'),
        _shareFixture(nick: ''),
      ]) {
        expect(() => InkeRoomParser.detail(body, uid: _uid), throwsA(failureKind(InkeFailureKind.apiChanged)));
      }
    });

    test('the offline code is an offline room with nothing but the uid', () {
      final room = InkeRoomParser.detail(_shareFixture(code: InkeEndpoints.noLiveCode), uid: _uid);
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.anchor, isNull);
      expect(room.content.title, '');
      expect(room.links.webUrl, InkeEndpoints.roomUrl(_uid));
      expect(room.runtime.streamHandle, isNull);
    });

    test('withBroadcast merges the app answer over the website room', () {
      final room = InkeRoomParser.detail(_shareFixture(liveName: ''), uid: _uid);
      final data = InkeRoomData(
        liveId: _liveId,
        broadcast: InkeRoomParser.broadcast(_publishFixture(live: _liveRow()), uid: _uid),
        receivedAt: _at,
      );
      final merged = InkeRoomParser.withBroadcast(room, data.broadcast!, receivedAt: _at, data: data);
      expect(merged.content.title, '晚间弹唱', reason: 'the app title replaces the stand-in');
      expect(merged.content.coverUrl, 'https://img.inke.cn/cover.png');
      expect(merged.audience.onlineViewers, 42);
      expect(merged.broadcast.startedAt, isNotNull);
      expect(merged.broadcast.restriction, LiveRestriction.none);
      expect(merged.links.webUrl, InkeEndpoints.roomUrl(_uid, liveId: _liveId));
      expect(merged.runtime.streamHandle, same(data));
      // An app answer without lines or figures leaves the website's own.
      final bare = InkeRoomParser.broadcast(
        _publishFixture(
          live: {
            ..._liveRow(title: '', streamAddr: '', zegoAddr: '', numbers: null, heat: null),
            'cover': '',
          },
        ),
        uid: _uid,
      )!;
      final kept = InkeRoomParser.withBroadcast(room, bare, receivedAt: _at, data: data);
      expect(kept.content.title, '主播甲', reason: 'no app title, the website nickname stands');
      expect(kept.content.coverUrl, 'https://img.inke.cn/room.png');
      expect(kept.audience.primaryMetric, LiveAudienceMetricType.unknown);
      expect(kept.broadcast.restriction, isNull);
    });

    test('now_publish answers null for no broadcast and reads the fields', () {
      expect(InkeRoomParser.broadcast(_publishFixture(), uid: _uid), isNull, reason: 'live is absent');
      expect(InkeRoomParser.broadcast(_publishFixture(), uid: _uid), isNull);
      expect(InkeRoomParser.broadcast(_publishFixture(live: _liveRow(status: 0)), uid: _uid), isNull);
      final broadcast = InkeRoomParser.broadcast(_publishFixture(live: _liveRow()), uid: _uid)!;
      expect(broadcast.liveId, _liveId);
      expect(broadcast.pullUrl, _flvUrl(_liveId));
      expect(broadcast.originUrl, _zegoUrl(_liveId));
      expect(broadcast.title, '晚间弹唱');
      expect(broadcast.startedAt, isNotNull);
      expect(broadcast.online, 42);
      expect(broadcast.heat, 9001);
      expect(broadcast.hasLine, isTrue);
      expect(
        () => InkeRoomParser.broadcast(
          _publishFixture(live: _liveRow(uid: _otherUid)),
          uid: _uid,
        ),
        throwsA(failureKind(InkeFailureKind.apiChanged)),
      );
      expect(
        InkeRoomParser.broadcast(
          _publishFixture(live: _liveRow(numbers: 'x')),
          uid: _uid,
        )!.online,
        isNull,
        reason: 'numbers that is no map has no real count',
      );
    });
  });

  group('pull urls and leases', () {
    test('a pull url must be the cdn address of its own broadcast', () {
      expect(InkeRoomParser.plainFlv(_flvUrl(_liveId), liveId: _liveId), _flvUrl(_liveId));
      expect(InkeRoomParser.zegoFlv(_zegoUrl(_liveId), liveId: _liveId), _zegoUrl(_liveId));
      for (final (value, liveId) in [
        (_flvUrl(_liveId), '87654321'), // another broadcast
        (_zegoUrl(_liveId), _liveId), // the zego host is not the ws one
        (_flvUrl(_liveId).replaceFirst('/live/', '/other/'), _liveId),
        (_flvUrl(_liveId).replaceFirst('.flv', '.m3u8'), _liveId),
        ('${_flvUrl(_liveId)}#f', _liveId),
        ('https://u:pw@live-pull-ws.ikstatic.cn/live/${_liveId}_t.flv?wsABStime=$_hexExpiry', _liveId),
        ('https://evil.com/live/${_liveId}_t.flv', _liveId),
        (_flvUrl(_liveId).replaceFirst('ikstatic.cn', 'ikstatic.cn:8080'), _liveId),
        (null, _liveId),
        ('', _liveId),
        ('not a url', _liveId),
      ]) {
        expect(InkeRoomParser.plainFlv(value, liveId: liveId), isNull, reason: '$value for $liveId');
      }
    });

    test('the zego codec is hevc when codecInfo says 8192', () {
      expect(InkeRoomParser.zegoCodec(_zegoUrl(_liveId)), LiveStreamCodec.hevc);
      expect(InkeRoomParser.zegoCodec(_zegoUrl(_liveId).replaceFirst('8192', '256')), isNull);
      expect(InkeRoomParser.zegoCodec(_flvUrl(_liveId)), isNull);
    });

    test('the lease stops at wsABStime, renewed a quarter or the lead before', () {
      final line = InkeRoomParser.flvLine(_flvUrl(_liveId), issuedAt: _at);
      expect(line.format, LiveStreamFormat.flv);
      expect(line.formatSource, LivePlayFormatSource.declared);
      expect(line.codec, LiveStreamCodec.avc);
      expect(line.lineLabel, 'ws');
      expect(line.headers, InkeEndpoints.headers);
      final lease = line.lease!;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch((_atSeconds + 2 * 3600) * 1000, isUtc: true);
      expect(lease.expiresAt, expiresAt);
      expect(lease.refreshAt, expiresAt.subtract(InkeEndpoints.leaseLead), reason: 'a quarter of 2 h is past the lead');

      // A short lifetime renews a quarter before.
      final short = (_atSeconds + 8).toRadixString(16);
      final shortUrl = _flvUrl(_liveId).replaceFirst(_hexExpiry, short);
      final shortLease = InkeRoomParser.lease(shortUrl, issuedAt: _at)!;
      expect(shortLease.refreshAt, shortLease.expiresAt!.subtract(const Duration(seconds: 2)));

      // No lease when the expiry is past, absent or not hexadecimal.
      final past = (_atSeconds - 10).toRadixString(16);
      expect(InkeRoomParser.lease(_flvUrl(_liveId).replaceFirst(_hexExpiry, past), issuedAt: _at), isNull);
      expect(InkeRoomParser.lease('https://live-pull-ws.ikstatic.cn/live/${_liveId}_t.flv', issuedAt: _at), isNull);
      expect(InkeRoomParser.lease(_zegoUrl(_liveId).replaceFirst(_hexExpiry, 'zz'), issuedAt: _at), isNull);

      // The zego line keeps its codec and its own label.
      final zego = InkeRoomParser.zegoLine(_zegoUrl(_liveId), issuedAt: _at);
      expect(zego.codec, LiveStreamCodec.hevc);
      expect(zego.lineLabel, 'zego');
      expect(zego.lease, isNotNull);
    });
  });

  group('links', () {
    test('a web room page and an app share page name the uid', () {
      expect(InkeEndpoints.roomIdFromUri(Uri.parse('https://www.inke.cn/liveroom/index.html?uid=$_uid')), _uid);
      expect(InkeEndpoints.roomIdFromUri(Uri.parse('https://inke.cn/liveroom/index.html?uid=$_uid')), _uid);
      expect(InkeEndpoints.roomIdFromUri(Uri.parse('http://inke.com/liveroom/index.html?uid=$_uid')), _uid);
      expect(InkeEndpoints.roomIdFromUri(Uri.parse('https://mlive2.inke.cn/app/share.html?uid=$_uid&x=1')), _uid);
      expect(InkeEndpoints.roomIdFromUri(Uri.parse('https://mlive.inke.cn/app/x?uid=$_uid')), _uid);
    });

    test('anything else names no uid', () {
      for (final url in [
        'https://www.inke.cn/liveroom/index.html?uid=$_uid&uid=6',
        'https://www.inke.cn/liveroom/index.html?uid=abc',
        'https://www.inke.cn/liveroom/index.html?uid=0$_uid',
        'https://www.inke.cn/other.html?uid=$_uid',
        'https://mlive2.inke.cn/live/share.html?uid=$_uid',
        'https://evil.inke.cn/liveroom/index.html?uid=$_uid',
        'https://u:pw@www.inke.cn/liveroom/index.html?uid=$_uid',
        'https://www.inke.cn:8080/liveroom/index.html?uid=$_uid',
        'ftp://www.inke.cn/liveroom/index.html?uid=$_uid',
      ]) {
        expect(InkeEndpoints.roomIdFromUri(Uri.tryParse(url)), isNull, reason: url);
      }
      expect(InkeEndpoints.roomIdFromUri(null), isNull);
    });

    test('the canonical room page keeps a single numeric broadcast id', () {
      final withId = Uri.parse('https://www.inke.cn/liveroom/index.html?uid=$_uid&id=$_liveId');
      expect(InkeEndpoints.canonicalRoomUrl(withId, _uid), withId);
      final without = Uri.parse('https://www.inke.cn/liveroom/index.html?uid=$_uid&x=1');
      expect(InkeEndpoints.canonicalRoomUrl(without, _uid), Uri.parse(InkeEndpoints.roomUrl(_uid)));
      final odd = Uri.parse('https://www.inke.cn/liveroom/index.html?uid=$_uid&id=abc&id=1');
      expect(
        InkeEndpoints.canonicalRoomUrl(odd, _uid),
        Uri.parse(InkeEndpoints.roomUrl(_uid)),
        reason: 'a repeated or non-numeric id is not kept',
      );
      expect(
        InkeEndpoints.canonicalRoomUrl(Uri.parse('https://mlive2.inke.cn/app/s?uid=$_uid'), _uid),
        Uri.parse(InkeEndpoints.roomUrl(_uid)),
        reason: 'a share page never keeps a broadcast id',
      );
    });

    test('the host test tells our pages from foreign ones', () {
      expect(InkeEndpoints.isOurHost('www.inke.cn'), isTrue);
      expect(InkeEndpoints.isOurHost('mlive2.inke.cn'), isTrue);
      expect(InkeEndpoints.isOurHost('a.b.inke.com'), isTrue);
      expect(InkeEndpoints.isOurHost('notinke.cn'), isFalse);
      expect(InkeEndpoints.isOurHost('example.com'), isFalse);
      expect(InkeEndpoints.isChannelKey('dance'), isTrue);
      expect(InkeEndpoints.isChannelKey('Live_top_pc'), isFalse, reason: 'the top area is no channel key');
      expect(InkeEndpoints.isChannelKey('x'), isTrue);
      expect(InkeEndpoints.isChannelKey('x y'), isFalse);
    });
  });

  group('adapter wiring', () {
    test('the manifest and the six capabilities, and no chat', () async {
      final adapter = _adapter();
      final site = adapter.site;
      expect(site.manifest.id, 'inke');
      expect(site.manifest.localizedName('zh-CN', 'en-US'), '映客');
      expect(site.runtimeInfo.status, LiveSiteStatus.ready);
      await site.initialize(
        const LiveSiteContext(platform: LiveTargetPlatform.windows, locale: 'zh-CN', defaultLocale: 'en-US'),
      );
      expect(site.capability<LiveRoomProvider>(), isNotNull);
      expect(site.capability<LiveAreaProvider>(), isNotNull);
      expect(site.capability<LiveDiscoveryProvider>(), isNotNull);
      expect(site.capability<LiveSearchProvider>(), isNotNull);
      expect(site.capability<LivePlaybackProvider>(), isNotNull);
      expect(site.capability<LiveLinkResolver>(), isNotNull);
      expect(site.capability<LiveDanmakuProvider>(), isNull, reason: 'Inke has no chat to join');
      expect(site.capability<LiveHotProvider>(), isNull, reason: 'the hot list rides the room provider');
      expect(site.capability<LiveSiteCapability>(), isNull);
      expect(identical(site.capability<LiveRoomProvider>(), site.capability<LiveRoomProvider>()), isTrue);
      await site.dispose();
      expect(adapter.http.closed, isTrue);
    });

    test('the hot list is the recommendations and the directory, one page', () async {
      final adapter = _adapter();
      final discovery = adapter.site.capability<LiveDiscoveryProvider>()!;
      final first = _right(await discovery.getRecommendedRooms());
      expect(first.items.map((room) => room.roomId), [_uid]);
      expect(first.hasMore, isFalse);
      expect(first.items.single.audience.onlineViewers, 42);
      expect(adapter.http.sent.single.url.host, 'service.inke.cn');
      expect(adapter.http.sent.single.url.path, '/api/live/simpleall');
      final rooms = adapter.site.capability<LiveRoomProvider>()!;
      final second = _right(await rooms.getRooms(const LivePageRequest(page: 2)));
      expect(second.items, isEmpty);
      expect(second.hasMore, isFalse);
      expect(adapter.http.sent, hasLength(1), reason: 'a later page asks nothing');
      expect(_leftOf(await rooms.getRooms(const LivePageRequest(page: 0))), isA<LiveSiteInvalidArgument>());
    });

    test('the areas come from the catalog, the top list and channels serve rooms', () async {
      final adapter = _adapter();
      final area = adapter.site.capability<LiveAreaProvider>()!;
      expect(_right(await area.getAreas()).map((entry) => entry.areaId), ['Live_top_pc', 'dance', 'sing']);
      final top = _right(await area.getAreaRooms(areaId: 'Live_top_pc'));
      expect(top.items.map((room) => room.roomId), [_uid]);
      expect(adapter.http.sent.last.url, InkeEndpoints.topUrl);
      final dance = _right(await area.getAreaRooms(areaId: 'dance'));
      expect(dance.items.map((room) => room.roomId), [_uid]);
      expect(adapter.http.sent.last.url, InkeEndpoints.channelsUrl);
      expect(_right(await area.getAreaRooms(areaId: 'dance', request: const LivePageRequest(page: 2))).items, isEmpty);
      expect(adapter.http.sent.last.url, InkeEndpoints.channelsUrl, reason: 'page 2 asks nothing new');
      expect(_leftOf(await area.getAreaRooms(areaId: 'nope')), isA<LiveSiteNotFound>());
      expect(_leftOf(await area.getAreaRooms(areaId: 'bad key!')), isA<LiveSiteInvalidArgument>());
      expect(
        _leftOf(await area.getAreaRooms(areaId: 'dance', request: const LivePageRequest(page: 0))),
        isA<LiveSiteInvalidArgument>(),
      );
    });

    test('an entry is the room and the app broadcast, and the streams come from it', () async {
      final adapter = _adapter();
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_uid));
      expect(adapter.http.sent.map((seen) => seen.url.path), ['/web/live_share_pc', '/api/live/now_publish']);
      expect(adapter.http.sent.first.url.queryParameters['uid'], _uid);
      expect(adapter.http.sent.last.url.queryParameters['id'], _uid);
      expect(room.content.title, '晚间弹唱', reason: 'the app title');
      expect(room.audience.onlineViewers, 42);
      expect(room.audience.popularity, 9001);
      expect(room.broadcast.startedAt, isNotNull);
      expect(room.broadcast.restriction, LiveRestriction.none);
      expect(room.runtime.streamHandle, isA<InkeRoomData>());

      // The qualities and lines come from the entry, without another request.
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      final qualities = _right(await playback.getQualities(roomId: _uid));
      expect(qualities.map((quality) => quality.qualityId), ['flv', 'origin']);
      expect(qualities.first.label, 'FLV');
      expect(qualities.first.codec, LiveStreamCodec.avc);
      expect(qualities.last.label, '原画');
      expect(qualities.last.codec, LiveStreamCodec.hevc);
      final lines = _right(await playback.getLines(roomId: _uid));
      expect(adapter.http.sent, hasLength(2), reason: 'the entry answer is still fresh');
      expect(lines, hasLength(1));
      expect(lines.single.url, _flvUrl(_liveId));
      expect(lines.single.headers, InkeEndpoints.headers);
      expect(lines.single.lease, isNotNull);
      expect(_right(await playback.getLines(roomId: _uid, quality: qualities.last)).single.url, _zegoUrl(_liveId));
      expect(
        _leftOf(
          await playback.getLines(
            roomId: _uid,
            quality: qualities.first.copyWith(qualityId: '720p'),
          ),
        ),
        isA<LiveSiteContentUnavailable>(),
      );
    });

    test('with "prefer H.264" off the original comes first and is the default', () async {
      final adapter = _adapter(preferH264: () => false);
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      final qualities = _right(await playback.getQualities(roomId: _uid));
      expect(qualities.map((quality) => quality.qualityId), ['origin', 'flv']);
      expect(_right(await playback.getLines(roomId: _uid)).single.url, _zegoUrl(_liveId));
    });

    test('a stale entry answer is refreshed', () async {
      final adapter = _adapter();
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      await adapter.site.capability<LiveRoomProvider>()!.getRoom(_uid);
      expect(adapter.http.sent, hasLength(2));
      _right(await playback.getLines(roomId: _uid));
      expect(adapter.http.sent, hasLength(2));
      adapter.advance(const Duration(seconds: 31));
      _right(await playback.getLines(roomId: _uid));
      expect(adapter.http.sent, hasLength(3), reason: 'the answer aged past the reuse window');
      expect(adapter.http.sent.last.url.path, '/api/live/now_publish');
    });

    test('a room the platform calls offline is offline, and its streams say so', () async {
      final adapter = _adapter(
        onSend: (request) {
          final path = request.url.path;
          if (path == '/web/live_share_pc') return _resp(200, _shareFixture(code: InkeEndpoints.noLiveCode));
          return _ordinary(request);
        },
      );
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_uid));
      expect(adapter.http.sent, hasLength(1));
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      expect(_leftOf(await playback.getQualities(roomId: _uid)), isA<LiveSiteContentUnavailable>());
      expect(_leftOf(await playback.getLines(roomId: _uid)), isA<LiveSiteContentUnavailable>());
      expect(adapter.http.sent, hasLength(1), reason: 'the remembered offline state answers without a request');
    });

    test('an id that is not a uid is not-found without a request', () async {
      final adapter = _adapter();
      expect(_leftOf(await adapter.site.capability<LiveRoomProvider>()!.getRoom('abc')), isA<LiveSiteNotFound>());
      expect(adapter.http.sent, isEmpty);
      expect(
        _leftOf(await adapter.site.capability<LivePlaybackProvider>()!.getQualities(roomId: '0123')),
        isA<LiveSiteNotFound>(),
      );
    });

    test('the app failing leaves the website room, and the streams recover', () async {
      var publishFails = true;
      final adapter = _adapter(
        onSend: (request) {
          final path = request.url.path;
          if (path == '/api/live/now_publish' && publishFails) return _resp(500, 'boom');
          return _ordinary(request);
        },
      );
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_uid));
      expect(adapter.http.sent, hasLength(2), reason: 'the app was asked');
      expect(room.content.title, '晚间弹唱', reason: 'the website answer stands');
      expect(room.runtime.streamHandle, isA<InkeRoomData>());
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      expect(_right(await playback.getQualities(roomId: _uid)).map((quality) => quality.qualityId), ['flv']);
      publishFails = false;
      final lines = _right(await playback.getLines(roomId: _uid));
      expect(lines.single.url, _flvUrl(_liveId), reason: 'a fresh app answer serves the line');
      expect(adapter.http.sent.last.url.path, '/api/live/now_publish');
    });

    test('without an app line the showcases are looked through, in order', () async {
      final adapter = _adapter(
        onSend: (request) {
          final path = request.url.path;
          if (path == '/api/live/now_publish') {
            return _resp(200, _publishFixture(live: _liveRow(streamAddr: 'https://evil/x.flv')));
          }
          return _ordinary(request);
        },
      );
      await adapter.site.capability<LiveRoomProvider>()!.getRoom(_uid);
      final lines = _right(await adapter.site.capability<LivePlaybackProvider>()!.getLines(roomId: _uid));
      expect(adapter.http.sent.map((seen) => seen.url.path).skip(2), [
        '/web/Live_top_pc',
      ], reason: 'the top list holds the broadcast');
      expect(lines.single.url, _flvUrl(_liveId));
    });

    test('the app saying the anchor is not live is stream-unavailable', () async {
      final adapter = _adapter(
        onSend: (request) {
          final path = request.url.path;
          if (path == '/api/live/now_publish') return _resp(200, _publishFixture(live: _liveRow(status: 0)));
          return _ordinary(request);
        },
      );
      await adapter.site.capability<LiveRoomProvider>()!.getRoom(_uid);
      final error = _leftOf(await adapter.site.capability<LivePlaybackProvider>()!.getLines(roomId: _uid));
      expect(error, isA<LiveSiteContentUnavailable>());
      expect(adapter.http.sent.map((seen) => seen.url.path), hasLength(3), reason: 'the showcases are not asked');
    });

    test('a status the gate refuses is mapped at the boundary', () async {
      final refused = _adapter(onSend: (_) => _resp(401, 'nope'));
      expect(_leftOf(await refused.site.capability<LiveRoomProvider>()!.getRoom(_uid)), isA<LiveSiteRateLimitError>());
      final gone = _adapter(onSend: (_) => _resp(404, 'nope'));
      expect(_leftOf(await gone.site.capability<LiveRoomProvider>()!.getRoom(_uid)), isA<LiveSiteNotFound>());
      final broken = _adapter(onSend: (_) => _resp(200, '<html>'));
      expect(_leftOf(await broken.site.capability<LiveRoomProvider>()!.getRoom(_uid)), isA<LiveSiteParseError>());
      final down = _adapter(onSend: (_) => throw const ConnectFailure('refused'));
      expect(_leftOf(await down.site.capability<LiveRoomProvider>()!.getRoom(_uid)), isA<LiveSiteNetworkError>());
    });

    test('a search finds the uid, the link and the keyword', () async {
      final adapter = _adapter();
      final search = adapter.site.capability<LiveSearchProvider>()!;
      expect(search.supportedTargets, {LiveSearchTarget.rooms});
      expect(
        _leftOf(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.anchors))),
        isA<LiveSiteUnsupported>(),
      );
      final byUid = await search.search(const LiveSearchRequest(query: ' $_uid ', target: LiveSearchTarget.rooms));
      expect((_right(byUid).items.single as RoomSearchResult).room.roomId, _uid);
      expect(adapter.http.sent.map((seen) => seen.url.path), ['/web/live_share_pc', '/api/live/now_publish']);
      expect(_right(byUid).hasMore, isNull);
      final page2 = await search.search(const LiveSearchRequest(query: _uid, target: LiveSearchTarget.rooms, page: 2));
      expect(_right(page2).items, isEmpty);
      final byLink = await search.search(
        const LiveSearchRequest(
          query: 'https://mlive2.inke.cn/app/share.html?uid=$_uid',
          target: LiveSearchTarget.rooms,
        ),
      );
      expect((_right(byLink).items.single as RoomSearchResult).room.roomId, _uid);
      final foreign = await search.search(
        const LiveSearchRequest(query: 'https://example.com/room/1', target: LiveSearchTarget.rooms),
      );
      expect(_right(foreign).items, isEmpty);
      expect(adapter.http.sent, hasLength(4), reason: 'a foreign link asks nothing');
      final byKeyword = await search.search(const LiveSearchRequest(query: '主播', target: LiveSearchTarget.rooms));
      expect(_right(byKeyword).items.map((item) => (item as RoomSearchResult).room.roomId), [_uid]);
      expect(adapter.http.sent.length, 7, reason: 'the top list, the channels and the hot list');
      expect(adapter.http.sent.skip(4).map((seen) => seen.url.path), [
        '/web/Live_top_pc',
        '/web/Live_channel_pc',
        '/api/live/simpleall',
      ]);
      final blank = await search.search(const LiveSearchRequest(query: '  ', target: LiveSearchTarget.rooms));
      expect(_right(blank).items, isEmpty);
    });

    test('a search the platform would refuse is refused, without a request', () async {
      final adapter = _adapter();
      final search = adapter.site.capability<LiveSearchProvider>()!;
      expect(
        _leftOf(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.rooms, page: 10001))),
        isA<LiveSiteInvalidArgument>(),
      );
      expect(
        _leftOf(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.rooms, pageSize: 61))),
        isA<LiveSiteInvalidArgument>(),
      );
      expect(
        _leftOf(await search.search(LiveSearchRequest(query: 'x' * 101, target: LiveSearchTarget.rooms))),
        isA<LiveSiteInvalidArgument>(),
      );
      expect(
        _leftOf(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.rooms, page: 0))),
        isA<LiveSiteInvalidArgument>(),
      );
      expect(adapter.http.sent, isEmpty);
    });

    test('a search keeps the hot rooms when the hot list fails', () async {
      final adapter = _adapter(
        onSend: (request) {
          if (request.url.path == '/api/live/simpleall') return _resp(500, 'boom');
          return _ordinary(request);
        },
      );
      final result = await adapter.site.capability<LiveSearchProvider>()!.search(
        const LiveSearchRequest(query: '主播', target: LiveSearchTarget.rooms),
      );
      expect(_right(result).items, hasLength(1), reason: 'the showcases still match');
      final dead = _adapter(
        onSend: (request) {
          if (request.url.path == '/web/Live_top_pc') return _resp(500, 'boom');
          return _ordinary(request);
        },
      );
      expect(
        _leftOf(
          await dead.site.capability<LiveSearchProvider>()!.search(
            const LiveSearchRequest(query: '主播', target: LiveSearchTarget.rooms),
          ),
        ),
        isA<LiveSiteNetworkError>(),
      );
    });

    test('search pages slice the matches and say whether more follow', () async {
      final adapter = _adapter(
        onSend: (request) {
          final path = request.url.path;
          if (path == '/web/Live_channel_pc') {
            return _resp(
              200,
              _channelsFixture(
                list: [
                  {
                    'tab_key': 'dance',
                    'channel_name': '舞蹈',
                    'list': [
                      _row(uid: _otherUid, liveId: '87654321', nick: '主播乙'),
                      _row(uid: '55555', liveId: '11111111', nick: '主播丙'),
                    ],
                  },
                ],
              ),
            );
          }
          return _ordinary(request);
        },
      );
      final search = adapter.site.capability<LiveSearchProvider>()!;
      final first = await search.search(
        const LiveSearchRequest(query: '主播', target: LiveSearchTarget.rooms, pageSize: 2),
      );
      expect(_right(first).items.map((item) => (item as RoomSearchResult).room.roomId), [_uid, _otherUid]);
      expect(_right(first).hasMore, isTrue);
      final second = await search.search(
        const LiveSearchRequest(query: '主播', target: LiveSearchTarget.rooms, page: 2, pageSize: 2),
      );
      expect(_right(second).items.map((item) => (item as RoomSearchResult).room.roomId), ['55555']);
      expect(_right(second).hasMore, isFalse);
    });

    test('a link is canonicalized without a request', () async {
      final adapter = _adapter();
      final link = adapter.site.capability<LiveLinkResolver>()!;
      expect(
        _right(await link.resolve(Uri.parse('https://www.inke.cn/liveroom/index.html?uid=$_uid&id=$_liveId'))),
        Uri.parse('https://www.inke.cn/liveroom/index.html?uid=$_uid&id=$_liveId'),
      );
      expect(
        _right(await link.resolve(Uri.parse('https://mlive2.inke.cn/app/share.html?uid=$_uid'))),
        Uri.parse(InkeEndpoints.roomUrl(_uid)),
      );
      expect(adapter.http.sent, isEmpty);
      expect(
        _leftOf(await link.resolve(Uri.parse('https://www.inke.cn/liveroom/index.html?uid=abc'))),
        isA<LiveSiteNotFound>(),
      );
      expect(_leftOf(await link.resolve(Uri.parse('https://example.com/x'))), isA<LiveSiteUnsupported>());
    });
  });
}
