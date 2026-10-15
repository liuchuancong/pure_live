import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_anchor_provider.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/capabilities/live_hot_provider.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/capabilities/live_web_search_provider.dart';
import 'package:live_sites/src/core/live_site_context.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/core/live_site_runtime_info.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/tiktok/api/tiktok_endpoints.dart';
import 'package:live_sites/src/platforms/tiktok/api/tiktok_http.dart';
import 'package:live_sites/src/platforms/tiktok/parsers/tiktok_failure.dart';
import 'package:live_sites/src/platforms/tiktok/parsers/tiktok_json.dart';
import 'package:live_sites/src/platforms/tiktok/parsers/tiktok_link.dart';
import 'package:live_sites/src/platforms/tiktok/parsers/tiktok_room_parser.dart';
import 'package:live_sites/src/platforms/tiktok/tiktok_site.dart';
import 'package:test/test.dart';

/// The clock of the tests: 2026-09-30, in the afternoon.
final DateTime _at = DateTime.utc(2026, 9, 30, 14);

/// The end of a pull URL signed for 14 days.
final DateTime _expiresAt = DateTime.utc(2026, 10, 14, 14);

final int _expire = _expiresAt.millisecondsSinceEpoch ~/ 1000;

const String _user = 'luna';
const String _other = 'kira';
const String _userId = '7106458262936009';
const String _liveRoom = '7300000000000000001';
const String _avatar = 'https://p16-sign-va.tiktokcdn.com/img/a.png';
const String _cover = 'https://p19-webcast.tiktokcdn.com/img/cover.png';

String _flv() => 'https://pull-flv-va01.tiktokcdn-us.com/webcast/1.flv?expire=$_expire&signature=abc';
String _flv2() => 'https://pull-flv-va02.tiktokcdn-us.com/webcast/1.flv?expire=$_expire&signature=abc';
String _hls() => 'https://pull-hls-va01.tiktokcdn.com/webcast/1.m3u8?expire=$_expire&signature=abc';
String _hls2() => 'https://pull-hls-va02.tiktokcdn.com/webcast/2.m3u8?expire=$_expire&signature=abc';

String _json(Object? data) => jsonEncode(data);

Map<String, Object?> _userFixture({
  String uniqueId = _user,
  Object? id = _userId,
  Object? nickname = 'Luna',
  Object? secret = false,
  Object? roomId = _liveRoom,
  Object? avatar = _avatar,
  Object? signature = 'hi',
  Object? secUid = 'Sec-1',
}) => {
  'id': id,
  'uniqueId': uniqueId,
  'nickname': nickname,
  'avatarLarger': avatar,
  'signature': signature,
  'secret': secret,
  'roomId': roomId,
  'secUid': secUid,
};

String _sdk({String vCodec = 'avc', String resolution = '720x1280', Object? vbitrate = 1200000}) =>
    jsonEncode({'VCodec': vCodec, 'resolution': resolution, 'vbitrate': vbitrate});

Map<String, Object?> _tier(Object? flv, Object? hls, {Object? sdk}) => {
  'main': {'flv': ?flv, 'hls': ?hls, 'sdk_params': sdk ?? _sdk()},
};

Object _labels(Map<String, String> labels) => [
  for (final entry in labels.entries) {'sdk_key': entry.key, 'name': entry.value},
];

Map<String, Object?> _pull(String streamData, {Object? labels}) => {
  'pull_data': {
    'stream_data': streamData,
    'options': {'qualities': ?labels},
  },
};

String _streamDataJson(Map<String, Object?> tiers) => jsonEncode({'data': tiers});

Map<String, Object?> _live({
  Object? status = 2,
  bool withStreams = true,
  Object? title = 'Good game',
  Object? startTime = 1790000000,
  Object? paidEvent,
  Object? liveSubOnly,
  Object? coverUrl = _cover,
}) => {
  'status': status,
  'title': title,
  'startTime': startTime,
  'streamId': '7300000000000000002',
  'liveRoomStats': {'userCount': 42, 'enterCount': 900},
  'coverUrl': coverUrl,
  if (withStreams)
    'streamData': _pull(_streamDataJson({'origin': _tier(_flv(), _hls())}), labels: _labels({'origin': 'Original'})),
  'paidEvent': ?paidEvent,
  'liveSubOnly': ?liveSubOnly,
};

String _userRoom({
  int statusCode = 0,
  Object? message = 'ok',
  Map<String, Object?>? user,
  Map<String, Object?>? live,
  Object? stats,
}) => _json({
  'statusCode': statusCode,
  'message': message,
  'data': {
    'user': user ?? _userFixture(),
    'liveRoom': live ?? _live(),
    'stats': stats ?? const {'followerCount': 1234},
  },
});

String _roomInfo({int statusCode = 0, Object? id = _liveRoom, String displayId = _user}) => _json({
  'status_code': statusCode,
  'data': {
    'id': id,
    'owner': {'display_id': displayId},
  },
});

/// A short link landing page: its canonical address names `user` (an empty
/// one names nobody), the body carries the hydration state.
String _landing({String user = _user}) =>
    '<html><head><link rel="canonical" href="https://www.tiktok.com/@$user/live"/></head><body>'
    '${user.isEmpty ? '' : '"uniqueId":"$user"'}</body></html>';

LiveResponse _resp(int status, String body) =>
    LiveResponse(statusCode: status, headers: const {}, bodyBytes: Uint8List.fromList(utf8.encode(body)));

final class _Seen {
  new(LiveRequest request) : url = request.url, headers = request.headers;
  final Uri url;
  final Map<String, String> headers;
}

final class _FakeHttp implements LiveHttp {
  new(this.onSend);
  final FutureOr<LiveResponse> Function(_Seen request) onSend;
  final List<_Seen> sent = [];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    final seen = _Seen(request);
    sent.add(seen);
    return await onSend(seen);
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}
}

/// The answers of the site: the user's LIVE (the answer is about the
/// `uniqueId` that was asked; `ghost` does not exist), the owner of a LIVE
/// room, and the page a short link lands on (`vt` lands nowhere).
LiveResponse _ordinary(_Seen request) {
  final path = request.url.path;
  if (path == '/api-live/user/room/') {
    final uniqueId = request.url.queryParameters['uniqueId'] ?? _user;
    if (uniqueId == 'ghost') {
      return _resp(200, _userRoom(statusCode: TiktokEndpoints.missingUserCode, message: 'user not exist'));
    }
    return _resp(200, _userRoom(user: _userFixture(uniqueId: uniqueId)));
  }
  if (path == '/webcast/room/info/') {
    return _resp(200, _roomInfo());
  }
  if (request.url.host == 'vt.tiktok.com') {
    return _resp(200, _landing(user: ''));
  }
  return _resp(200, _landing());
}

({TiktokSite site, _FakeHttp http}) _adapter({
  LiveResponse Function(_Seen request)? onSend,
  bool Function()? preferH264,
}) {
  final http = _FakeHttp(onSend ?? _ordinary);
  return (site: TiktokSite(http: TiktokHttp(http), preferH264: preferH264, now: () => _at), http: http);
}

T _right<T>(Either<LiveSiteError, T> either) => either.match((left) => throw StateError('$left'), (right) => right);

LiveSiteError _leftOf<T>(Either<LiveSiteError, T> either) =>
    either.match((left) => left, (right) => throw StateError('not a left: $either'));

TiktokFailureKind _kindOf<T>(T Function() run) {
  try {
    run();
  } on TiktokFailure catch (failure) {
    return failure.kind;
  }
  fail('no throw');
}

LiveRoom _parsedRoom({
  Map<String, Object?>? user,
  Map<String, Object?>? live,
  Object? stats,
  bool includeMedia = true,
}) {
  final who = (user ?? _userFixture())['uniqueId']! as String;
  return TiktokRoomParser.room(
    _userRoom(user: user, live: live, stats: stats),
    username: who,
    includeMedia: includeMedia,
    issuedAt: _at,
  );
}

TiktokRoomData _handleOf(LiveRoom room) => room.runtime.streamHandle! as TiktokRoomData;

/// The quality ids of `streams` in the order `qualities` offers them.
List<String> _qualityIds(List<TiktokStream> streams, {required bool preferH264}) => TiktokRoomParser.qualities(
  TiktokRoomData(username: _user, userId: _userId, state: TiktokState.live, issuedAt: _at, streams: streams),
  preferH264: preferH264,
).map((quality) => quality.qualityId!).toList(growable: false);

void main() {
  group('status, body and readers', () {
    test('a status says what kind of answer it is', () {
      expect(_kindOf(() => TiktokJson.checkStatus(400, 'x')), TiktokFailureKind.apiChanged);
      expect(_kindOf(() => TiktokJson.checkStatus(401, 'x')), TiktokFailureKind.riskControl);
      expect(_kindOf(() => TiktokJson.checkStatus(403, 'x')), TiktokFailureKind.riskControl);
      expect(_kindOf(() => TiktokJson.checkStatus(404, 'x')), TiktokFailureKind.notFound);
      expect(_kindOf(() => TiktokJson.checkStatus(420, 'x')), TiktokFailureKind.rateLimited);
      expect(_kindOf(() => TiktokJson.checkStatus(429, 'x')), TiktokFailureKind.rateLimited);
      for (final status in [301, 302, 500, 503]) {
        expect(_kindOf(() => TiktokJson.checkStatus(status, 'x')), TiktokFailureKind.network);
      }
      TiktokJson.checkStatus(200, 'x');
    });

    test('an answer is bounded, must be JSON and must be an object', () {
      expect(
        () => TiktokJson.envelope('', status: 200, what: 'x'),
        throwsA(predicate((e) => '$e'.contains('empty answer'))),
      );
      expect(
        () => TiktokJson.envelope('<html>', status: 200, what: 'x'),
        throwsA(predicate((e) => '$e'.contains('not JSON'))),
      );
      expect(
        () => TiktokJson.envelope('["array"]', status: 200, what: 'x'),
        throwsA(predicate((e) => '$e'.contains('expected an object'))),
      );
      expect(
        () => TiktokJson.envelope('{"a":"${'x' * (12 * 1024 * 1024)}"}', status: 200, what: 'x'),
        throwsA(predicate((e) => '$e'.contains('answer over'))),
      );
      expect(TiktokJson.envelope('{"a":1}', status: 200, what: 'x'), {'a': 1});
      expect(
        () => TiktokJson.envelope('nope', status: 401, what: 'x'),
        throwsA(predicate((e) => '$e'.contains('HTTP 401'))),
        reason: 'the status is judged before the body',
      );
    });

    test('identities are strict, card fields are lenient', () {
      expect(TiktokJson.username('Luna', 'x'), 'luna');
      expect(() => TiktokJson.username('not a user!', 'x'), throwsA(anything));
      expect(() => TiktokJson.username(null, 'x'), throwsA(anything));
      expect(TiktokJson.longId(_userId, 'x'), _userId);
      expect(TiktokJson.longId(7106458262936009, 'x'), _userId);
      expect(() => TiktokJson.longId('12', 'x'), throwsA(anything));
      expect(TiktokJson.lenientLongId('12'), isEmpty);
      expect(TiktokJson.lenientLongId(_userId), _userId);
      expect(TiktokJson.lenientText(' a '), 'a');
      expect(TiktokJson.lenientText('x' * 8193), isEmpty);
      expect(() => TiktokJson.optionalText(7, 'x'), throwsA(anything));
      expect(TiktokJson.optionalText(null, 'x'), isEmpty);
      expect(TiktokJson.integer('42'), 42);
      expect(TiktokJson.integer(2.0), 2);
      expect(TiktokJson.integer(2.5), isNull);
      expect(TiktokJson.lenientCount(-1), isNull);
      expect(TiktokJson.lenientCount('7'), 7);
      expect(() => TiktokJson.optionalBool('yes', 'x'), throwsA(anything));
      expect(TiktokJson.optionalBool(null, 'x'), isNull);
      expect(TiktokJson.resolution('720X1280'), '720x1280');
      expect(TiktokJson.resolution('big'), isEmpty);
      expect(TiktokJson.tier('Origin', 'x'), 'origin');
      expect(() => TiktokJson.tier('a b', 'x'), throwsA(anything));
      expect(TiktokJson.codec(null, 'h264', 'x'), 'h264');
      expect(TiktokJson.codec('bytevc1', 'h264', 'x'), 'h265');
      expect(() => TiktokJson.codec('mpeg2', 'h264', 'x'), throwsA(anything));
      expect(TiktokJson.startTime(1790000000), DateTime.fromMillisecondsSinceEpoch(1790000000 * 1000, isUtc: true));
      expect(TiktokJson.startTime(100), isNull);
      expect(TiktokJson.startTime(4102444801), isNull);
      expect(TiktokJson.image(['https://evil.com/a.png', _avatar]), _avatar, reason: 'only trusted hosts');
    });
  });

  group('room card', () {
    test('a live room is read whole, its streams in the handle', () {
      final room = _parsedRoom();
      expect(room.platform, 'tiktok');
      expect(room.roomId, _user);
      expect(room.content.title, 'Good game');
      expect(room.content.coverUrl, _cover);
      expect(room.content.introduction, 'hi');
      expect(room.content.notice, TiktokEndpoints.chatNotice);
      expect(room.anchor?.anchorId, _userId);
      expect(room.anchor?.name, 'Luna');
      expect(room.anchor?.avatarUrl, _avatar);
      expect(room.anchor?.followerCount, 1234);
      expect(room.anchor?.liveStatus, LiveStatus.live);
      expect(room.audience.onlineViewers, 42);
      expect(room.audience.totalViewers, 900);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(1790000000 * 1000, isUtc: true));
      expect(room.broadcast.restriction, LiveRestriction.none);
      expect(room.links.webUrl, TiktokEndpoints.roomUrl(_user));
      final handle = _handleOf(room);
      expect(handle.username, _user);
      expect(handle.state, TiktokState.live);
      expect(handle.userId, _userId);
      expect(handle.secUid, 'Sec-1');
      expect(handle.liveRoomId, _liveRoom);
      expect(handle.streamId, '7300000000000000002');
      expect(handle.streams, hasLength(1));
      expect(handle.streams.single.id, 'h264:origin');
      expect(handle.streams.single.flvUrls, [Uri.parse(_flv())]);
      expect(handle.streams.single.hlsUrls, [Uri.parse(_hls())]);
      expect(handle.streams.single.label, 'Original');
      expect(handle.streams.single.resolution, '720x1280');
      expect(handle.streams.single.bitrate, 1200000);
      expect(handle.streams.single.urls, [Uri.parse(_flv()), Uri.parse(_hls())], reason: 'flv first');
    });

    test('an offline room carries no audience and no streams', () {
      final room = _parsedRoom(live: _live(status: 4));
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.audience.onlineViewers, isNull);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.unknown);
      expect(room.broadcast.startedAt, isNull);
      expect(room.broadcast.restriction, isNull);
      expect(_handleOf(room).state, TiktokState.offline);
      expect(_handleOf(room).streams, isEmpty);
    });

    test('a status the site does not name stays unknown', () {
      final room = _parsedRoom(live: _live(status: 7));
      expect(room.broadcast.liveStatus, LiveStatus.unknown);
      expect(_handleOf(room).state, TiktokState.unknown);
    });

    test('the answer must be about the user that was asked', () {
      expect(
        () => TiktokRoomParser.room(_userRoom(), username: _other, includeMedia: true, issuedAt: _at),
        throwsA(predicate((e) => '$e'.contains('asked $_other'))),
      );
    });

    test('a missing user is not-found, any other code api-changed', () {
      expect(
        _kindOf(
          () => TiktokRoomParser.room(
            _userRoom(statusCode: TiktokEndpoints.missingUserCode),
            username: _user,
            includeMedia: true,
            issuedAt: _at,
          ),
        ),
        TiktokFailureKind.notFound,
      );
      expect(
        _kindOf(
          () => TiktokRoomParser.room(
            _userRoom(statusCode: 19881007, message: 'user_not_found here'),
            username: _user,
            includeMedia: true,
            issuedAt: _at,
          ),
        ),
        TiktokFailureKind.notFound,
      );
      expect(
        _kindOf(
          () => TiktokRoomParser.room(_userRoom(statusCode: 7), username: _user, includeMedia: true, issuedAt: _at),
        ),
        TiktokFailureKind.apiChanged,
      );
    });

    test('a search card reads no streams', () {
      expect(_parsedRoom(includeMedia: false).runtime.streamHandle, isNull);
    });

    test('an empty title falls back to the name', () {
      expect(_parsedRoom(live: _live(title: '')).content.title, 'Luna');
    });

    test('who may watch is read in order', () {
      LiveRestriction of(Map<String, Object?> user, Map<String, Object?> live) =>
          TiktokRoomParser.restrictionOf(user, live);

      expect(of({..._userFixture(), 'secret': true}, _live()), LiveRestriction.private);
      expect(of(_userFixture(), _live(liveSubOnly: 1)), LiveRestriction.subscribersOnly);
      expect(of(_userFixture(), _live(paidEvent: {'paid_type': 2})), LiveRestriction.paid);
      expect(of(_userFixture(), _live(paidEvent: [])), LiveRestriction.none);
      expect(
        () => of({..._userFixture(), 'secret': 'yes'}, _live()),
        throwsA(predicate((e) => '$e'.contains('user.secret'))),
      );
    });

    test('a restricted live reads no streams even on entry', () {
      final room = _parsedRoom(user: _userFixture(secret: true));
      expect(room.broadcast.restriction, LiveRestriction.private);
      expect(_handleOf(room).streams, isEmpty);
    });

    test('malformed card fields lose themselves', () {
      final room = _parsedRoom(
        user: _userFixture(nickname: 'x' * 9000, avatar: 'https://evil.com/a.png', id: 12),
        live: _live(title: 'x' * 9000, coverUrl: 'http://p19-webcast.tiktokcdn.com/img/cover.png'),
        stats: 'nope',
      );
      expect(room.content.title, isEmpty);
      expect(room.anchor?.name, isEmpty);
      expect(room.anchor?.avatarUrl, isNull);
      expect(room.anchor?.anchorId, isEmpty);
      expect(room.content.coverUrl, isEmpty);
      expect(room.anchor?.followerCount, isNull);
    });
  });

  group('stream containers', () {
    TiktokRoomData dataOf(Map<String, Object?> live, {Map<String, Object?>? user}) =>
        _handleOf(_parsedRoom(user: user, live: live));

    test('tiers are read per codec, the audio-only one left out', () {
      final data = dataOf({
        ..._live(),
        'streamData': _pull(
          _streamDataJson({
            'origin': _tier(_flv(), _hls()),
            'sd': _tier(
              null,
              _hls2(),
              sdk: _sdk(resolution: '480x854', vbitrate: 'x'),
            ),
            'ao': _tier(_flv(), _hls()),
          }),
          labels: _labels({'origin': 'Original'}),
        ),
        'hevcStreamData': _pull(
          _streamDataJson({'origin': _tier(_flv2(), null, sdk: _sdk(vCodec: 'bytevc1'))}),
          labels: _labels({'origin': 'Original'}),
        ),
      });
      expect(data.skipped, isEmpty);
      expect(data.streams.map((stream) => stream.id), ['h264:origin', 'h264:sd', 'h265:origin']);
      expect(data.streams[0].label, 'Original');
      expect(data.streams[0].resolution, '720x1280');
      expect(data.streams[0].bitrate, 1200000);
      expect(data.streams[1].label, isEmpty, reason: 'the options named no sd tier');
      expect(data.streams[1].resolution, '480x854');
      expect(data.streams[1].bitrate, isNull, reason: 'a count that is no number is none');
      expect(data.streams[2].flvUrls, [Uri.parse(_flv2())]);
      expect(data.streams[2].hlsUrls, isEmpty);
    });

    test('a tier of the same codec in both containers is one stream', () {
      final data = dataOf({
        ..._live(),
        'streamData': _pull(_streamDataJson({'hd': _tier(_flv(), null)}), labels: _labels({'hd': 'HD'})),
        'hevcStreamData': _pull(_streamDataJson({'hd': _tier(null, _hls())}), labels: _labels({'hd': 'HD'})),
      });
      expect(data.streams, hasLength(1));
      expect(data.streams.single.id, 'h264:hd');
      expect(data.streams.single.flvUrls, [Uri.parse(_flv())]);
      expect(data.streams.single.hlsUrls, [Uri.parse(_hls())]);
      expect(data.streams.single.label, 'HD');
    });

    test('a repeated URL is kept once', () {
      final data = dataOf({
        ..._live(),
        'streamData': _pull(_streamDataJson({'hd': _tier('${_flv()} ', _hls())}), labels: const []),
      });
      expect(data.streams.single.flvUrls, [Uri.parse(_flv())], reason: 'trimmed and deduplicated');
    });

    test('a broken part costs only itself', () {
      final data = dataOf({
        ..._live(),
        'streamData': _pull(
          _streamDataJson({
            'bad key': _tier(_flv(), _hls()),
            'nomain': {},
            'badsdk': _tier(_flv(), _hls(), sdk: 'not json'),
            'badcodec': _tier(_flv(), _hls(), sdk: _sdk(vCodec: 'mpeg2')),
            'evilurl': _tier('https://evil.com/1.flv', 'https://evil.com/1.m3u8'),
            'good': _tier(_flv(), _hls()),
          }),
          labels: _labels({'good': 'Good'}),
        ),
      });
      expect(data.streams.map((stream) => stream.id), ['h264:good']);
      expect(data.skipped, hasLength(6));
      expect(data.skipped.join('; '), contains('tier "bad key"'));
      expect(data.skipped.join('; '), contains('expected an object'));
      expect(data.skipped.join('; '), contains('not JSON'));
      expect(data.skipped.join('; '), contains('codec mpeg2'));
      expect(data.skipped.join('; '), contains('evilurl'));
    });

    test('a whole container that cannot be read is skipped, noted', () {
      final data = dataOf({
        ..._live(),
        'streamData': _pull('not json', labels: const []),
        'hevcStreamData': _pull(
          _streamDataJson({for (var index = 0; index < 33; index++) 't$index': _tier(_flv(), _hls())}),
          labels: const [],
        ),
      });
      expect(data.streams, isEmpty);
      expect(data.skipped, hasLength(2));
      expect(data.skipped.join('; '), contains('not JSON'));
      expect(data.skipped.join('; '), contains('33 tiers'));
    });

    test('an over-large stream_data loses itself, an empty one is passed over', () {
      final data = dataOf({
        ..._live(),
        'streamData': _pull('x' * (4 * 1024 * 1024 + 1), labels: const []),
        'hevcStreamData': _pull('', labels: const []),
      });
      expect(data.streams, isEmpty);
      expect(data.skipped, hasLength(1));
      expect(data.skipped.single, contains('expected a string'));
      expect(TiktokRoomParser.unplayable(data)?.kind, TiktokFailureKind.apiChanged);
    });
  });

  group('qualities, names and lines', () {
    List<TiktokStream> streamsOf(Map<String, Object?> live) => _handleOf(_parsedRoom(live: live)).streams;

    test('the tiers rank best first, H.264 before H.265', () {
      final streams = streamsOf({
        ..._live(),
        'streamData': _pull(
          _streamDataJson({
            'sd': _tier(_flv(), null, sdk: _sdk(resolution: '480x854')),
            'uhd': _tier(_flv(), null, sdk: _sdk(resolution: '')),
            'origin': _tier(_flv(), _hls()),
          }),
          labels: _labels({'origin': 'Original'}),
        ),
        'hevcStreamData': _pull(
          _streamDataJson({
            'origin': _tier(_flv2(), null, sdk: _sdk(vCodec: 'h265')),
            'zzz': _tier(null, _hls2(), sdk: _sdk(vCodec: 'h265')),
          }),
          labels: _labels({'origin': 'Original'}),
        ),
      });
      expect(_qualityIds(streams, preferH264: true), ['h264:origin', 'h264:uhd', 'h264:sd', 'h265:origin', 'h265:zzz']);
      expect(_qualityIds(streams, preferH264: false), [
        'h264:origin',
        'h265:origin',
        'h264:uhd',
        'h264:sd',
        'h265:zzz',
      ]);
    });

    test('a quality is named the site way, twice means the tier joins', () {
      final streams = streamsOf({
        ..._live(),
        'streamData': _pull(
          _streamDataJson({
            'origin': _tier(_flv(), _hls()),
            'hd': _tier(_flv(), null),
            'sd': _tier(_flv(), null, sdk: _sdk(resolution: '')),
            'uhd': _tier(_flv(), null, sdk: _sdk(resolution: '')),
          }),
          labels: _labels({'hd': '720p', 'sd': '720p'}),
        ),
        'hevcStreamData': _pull(
          _streamDataJson({
            'zzz': _tier(
              null,
              _hls2(),
              sdk: _sdk(vCodec: 'bytevc1', resolution: ''),
            ),
          }),
          labels: const [],
        ),
      });
      final qualities = TiktokRoomParser.qualities(
        TiktokRoomData(username: _user, userId: _userId, state: TiktokState.live, issuedAt: _at, streams: streams),
      );
      expect(qualities.map((quality) => quality.label), ['原画', '超清', '720p (hd)', '720p (sd)', 'ZZZ · H.265']);
      expect(qualities.first.codec, LiveStreamCodec.avc);
      expect(qualities.last.codec, LiveStreamCodec.hevc);
      expect(qualities.first.platformOrder, greaterThan(qualities.last.platformOrder));
      expect(TiktokRoomParser.qualityName(streams[1]), '720p', reason: 'the site own name wins');
      final frames60 = streamsOf({
        ..._live(),
        'streamData': _pull(
          _streamDataJson({'uhd_60': _tier(_flv(), null, sdk: _sdk(resolution: '1080p'))}),
          labels: const [],
        ),
      }).single;
      expect(TiktokRoomParser.qualityName(frames60), '1080p60');
    });

    test('a stored per-protocol id names its quality', () {
      expect(TiktokRoomParser.qualityIdFromLegacy('h264:origin:flv'), 'h264:origin');
      expect(TiktokRoomParser.qualityIdFromLegacy('H265:ORIGIN:HLS'), 'h265:origin');
      expect(TiktokRoomParser.qualityIdFromLegacy(' h264:origin '), 'h264:origin');
      expect(TiktokRoomParser.qualityIdFromLegacy('h264:origin'), 'h264:origin');
    });

    TiktokRoomData playableData() => TiktokRoomData(
      username: _user,
      userId: _userId,
      state: TiktokState.live,
      issuedAt: _at,
      streams: streamsOf(_live()),
    );

    test('the lines are FLV then HLS, with headers and a lease', () {
      final data = playableData();
      final lines = TiktokRoomParser.lines(data, TiktokRoomParser.qualities(data).first);
      expect(lines, hasLength(2));
      expect(lines[0].url, _flv());
      expect(lines[0].format, LiveStreamFormat.flv);
      expect(lines[0].lineLabel, 'flv');
      expect(lines[0].codec, LiveStreamCodec.avc);
      expect(lines[0].headers['referer'], TiktokEndpoints.roomUrl(_user));
      expect(lines[0].headers['user-agent'], TiktokEndpoints.userAgent);
      expect(lines[1].url, _hls());
      expect(lines[1].format, LiveStreamFormat.hls);
      expect(lines[1].lineLabel, 'hls');
      // The lease stops an hour before the 14-day expiry.
      expect(lines[0].lease!.expiresAt, _expiresAt);
      expect(lines[0].lease!.refreshAt, _expiresAt.subtract(const Duration(hours: 1)));
      expect(lines[0].lease!.requiresReconnect, isFalse, reason: 'an established flv connection keeps flowing');
      expect(lines[1].lease!.requiresReconnect, isTrue, reason: 'an expired playlist ends playback');
    });

    test('a second URL of a protocol is numbered', () {
      final doubled = playableData().streams.single;
      final lines = TiktokRoomParser.lines(
        TiktokRoomData(
          username: _user,
          userId: _userId,
          state: TiktokState.live,
          issuedAt: _at,
          streams: [
            TiktokStream(
              id: doubled.id,
              qualityId: doubled.qualityId,
              codec: doubled.codec,
              label: doubled.label,
              flvUrls: [Uri.parse(_flv()), Uri.parse(_flv2())],
              hlsUrls: doubled.hlsUrls,
            ),
          ],
        ),
        null,
      );
      expect(lines.map((line) => line.lineLabel), ['flv', 'flv#2', 'hls']);
    });

    test('no quality picks the default, a legacy id names the same one', () {
      final data = playableData();
      expect(TiktokRoomParser.lines(data, null).map((line) => line.url), [_flv(), _hls()]);
      expect(
        TiktokRoomParser.lines(data, const LivePlayQuality(label: 'x', qualityId: 'h264:origin:flv')).first.url,
        _flv(),
      );
      expect(
        () => TiktokRoomParser.lines(data, const LivePlayQuality(label: 'x', qualityId: 'h265:origin')),
        throwsA(predicate((e) => '$e'.contains('not offered'))),
      );
    });

    test('a lease needs a future expire', () {
      expect(TiktokRoomParser.lease(Uri.parse('https://x.tiktokcdn.com/a.flv'), _at), isNull);
      expect(TiktokRoomParser.lease(Uri.parse('https://x.tiktokcdn.com/a.flv?expire=0'), _at), isNull);
      final past = DateTime.utc(2026, 9, 29);
      expect(
        TiktokRoomParser.lease(
          Uri.parse('https://x.tiktokcdn.com/a.flv?expire=${past.millisecondsSinceEpoch ~/ 1000}'),
          _at,
        ),
        isNull,
      );
      // A short lifetime renews at a quarter of it, not the whole hour.
      final soon = _at.add(const Duration(minutes: 40));
      final lease = TiktokRoomParser.lease(
        Uri.parse('https://x.tiktokcdn.com/a.flv?expire=${soon.millisecondsSinceEpoch ~/ 1000}'),
        _at,
      );
      expect(lease!.refreshAt, _at.add(const Duration(minutes: 30)));
      expect(lease.expiresAt, soon);
    });
  });

  group('owner, unplayable and short link pages', () {
    test('room/info names the owner', () {
      expect(TiktokRoomParser.owner(_roomInfo(), liveRoomId: _liveRoom), _user);
      expect(
        _kindOf(() => TiktokRoomParser.owner(_roomInfo(statusCode: 1404), liveRoomId: _liveRoom)),
        TiktokFailureKind.notFound,
      );
      expect(
        _kindOf(() => TiktokRoomParser.owner(_roomInfo(id: '12'), liveRoomId: _liveRoom)),
        TiktokFailureKind.apiChanged,
      );
      expect(
        _kindOf(() => TiktokRoomParser.owner(_roomInfo(displayId: 'not a user!'), liveRoomId: _liveRoom)),
        TiktokFailureKind.apiChanged,
      );
      expect(
        _kindOf(() => TiktokRoomParser.owner(_roomInfo(id: '7300000000000000099'), liveRoomId: _liveRoom)),
        TiktokFailureKind.apiChanged,
        reason: 'an answer about another LIVE room',
      );
    });

    test('a live room that cannot play says why', () {
      TiktokRoomData dataOf(Map<String, Object?> live, {Map<String, Object?>? user}) =>
          _handleOf(_parsedRoom(user: user, live: live));

      expect(TiktokRoomParser.unplayable(dataOf(_live())), isNull);
      expect(TiktokRoomParser.unplayable(dataOf(_live(status: 4)))!.message, contains('is offline'));
      expect(TiktokRoomParser.unplayable(dataOf(_live(status: 7)))!.message, contains('not known'));
      expect(
        TiktokRoomParser.unplayable(dataOf(_live(), user: _userFixture(secret: true)))!.message,
        contains('followers only'),
      );
      expect(TiktokRoomParser.unplayable(dataOf(_live(liveSubOnly: 1)))!.message, contains('subscribers only'));
      expect(TiktokRoomParser.unplayable(dataOf(_live(paidEvent: {'paid_type': 1})))!.message, contains('a paid LIVE'));
      expect(
        TiktokRoomParser.unplayable(dataOf(_live(withStreams: false)))?.kind,
        TiktokFailureKind.streamUnavailable,
        reason: 'live without a stream',
      );
      final broken = dataOf({
        ..._live(),
        'streamData': _pull(_streamDataJson({'bad key': _tier(_flv(), _hls())}), labels: const []),
      });
      expect(
        TiktokRoomParser.unplayable(broken)?.kind,
        TiktokFailureKind.apiChanged,
        reason: 'streams were sent but none could be read',
      );
    });

    test('the page a short link lands on names the user', () {
      expect(
        TiktokRoomParser.usernameInPage('<link rel="canonical" href="https://www.tiktok.com/@luna/live"/>'),
        _user,
      );
      expect(
        TiktokRoomParser.usernameInPage('<meta property="og:url" content="https://www.tiktok.com/@luna/video/123"/>'),
        _user,
      );
      expect(TiktokRoomParser.usernameInPage('{"a":1,"uniqueId":"Luna"}'), _user, reason: 'the hydration state');
      expect(TiktokRoomParser.usernameInPage('<html>nothing</html>'), isNull);
      expect(TiktokRoomParser.usernameInPage('<a href="https://www.tiktok.com/@luna">x</a>'), isNull);
      expect(_kindOf(() => TiktokRoomParser.usernameInPage('x', status: 403)), TiktokFailureKind.riskControl);
      expect(
        _kindOf(() => TiktokRoomParser.usernameInPage('')),
        TiktokFailureKind.riskControl,
        reason: 'an empty page is the anonymous refusal',
      );
    });
  });

  group('links', () {
    test('a user page and a share/live page are rooms', () {
      expect(TiktokLink.parse('https://www.tiktok.com/@luna/live')?.kind, TiktokLinkKind.username);
      expect(TiktokLink.parse('https://www.tiktok.com/@luna/live')?.id, _user);
      expect(TiktokLink.parse('http://m.tiktok.com/@Luna/')?.id, _user, reason: 'lower case, live optional');
      expect(TiktokLink.parse('https://www.tiktok.com/share/live/$_liveRoom')?.kind, TiktokLinkKind.liveRoom);
      expect(TiktokLink.parse('https://www.tiktok.com/SHARE/LIVE/$_liveRoom/')?.id, _liveRoom);
    });

    test('anything else is no room', () {
      for (final bad in [
        'https://www.tiktok.com/@luna/video/123',
        'https://www.tiktok.com/@luna/live?x=1#f',
        'https://www.tiktok.com/@not a user!',
        'https://www.tiktok.com/share/live/12',
        'https://www.tiktok.com/share/live/0$_liveRoom',
        'https://evil.com/@luna/live',
        'ftp://www.tiktok.com/@luna/live',
        'https://u:l@www.tiktok.com/@luna/live',
        'not a link',
      ]) {
        expect(TiktokLink.parse(bad), isNull, reason: bad);
      }
      // Dot segments are normalized by Uri.parse before the path is read,
      // exactly as the reference read them.
      expect(TiktokLink.parse('https://www.tiktok.com/a/../@luna/live')?.id, _user);
    });

    test('a keyword is a username with or without @', () {
      expect(TiktokLink.lookup(' luna ')?.id, _user);
      expect(TiktokLink.lookup('@luna')?.id, _user);
      expect(TiktokLink.lookup('luna!'), isNull);
      expect(TiktokLink.lookup(''), isNull);
      expect(TiktokLink.lookup('https://www.tiktok.com/@luna/live')?.kind, TiktokLinkKind.username);
    });

    test('the share short links are known', () {
      expect(TiktokLink.shortLink('https://vm.tiktok.com/ZSabc/'), Uri.parse('https://vm.tiktok.com/ZSabc/'));
      expect(TiktokLink.shortLink('https://vt.tiktok.com/ZSabc'), isNotNull);
      expect(TiktokLink.shortLink('https://www.tiktok.com/t/ZSabc'), isNotNull);
      expect(TiktokLink.shortLink('https://www.tiktok.com/t/ZSabc/more'), isNull);
      expect(TiktokLink.shortLink('https://evil.tiktok.com/ZSabc'), isNull);
      expect(TiktokLink.ownsHost('www.tiktok.com'), isTrue);
      expect(TiktokLink.ownsHost('vm.tiktok.com'), isTrue);
      expect(TiktokLink.ownsHost('example.com'), isFalse);
    });
  });

  group('failure mapping', () {
    test('a kind maps to its Either-side error', () {
      <TiktokFailureKind, Type>{
        TiktokFailureKind.notFound: LiveSiteNotFound,
        TiktokFailureKind.apiChanged: LiveSiteParseError,
        TiktokFailureKind.network: LiveSiteNetworkError,
        TiktokFailureKind.riskControl: LiveSiteRateLimitError,
        TiktokFailureKind.rateLimited: LiveSiteRateLimitError,
        TiktokFailureKind.streamUnavailable: LiveSiteContentUnavailable,
        TiktokFailureKind.invalidArgument: LiveSiteInvalidArgument,
      }.forEach((kind, error) {
        final mapped = TiktokFailure(kind, 'x').toLiveSiteError('tiktok');
        expect(mapped.runtimeType, error, reason: '$kind');
        expect(mapped.message, 'x');
      });
    });

    test('only a transport failure or a throttle is transient', () {
      for (final kind in TiktokFailureKind.values) {
        expect(
          TiktokFailure(kind, 'x').isTransient,
          kind == TiktokFailureKind.network || kind == TiktokFailureKind.rateLimited,
          reason: '$kind',
        );
      }
    });
  });

  group('adapter wiring', () {
    test('the manifest and the five capabilities the platform can serve', () async {
      final adapter = _adapter();
      expect(adapter.site.manifest.id, 'tiktok');
      expect(adapter.site.runtimeInfo.status, LiveSiteStatus.ready);
      await adapter.site.initialize(
        const LiveSiteContext(platform: LiveTargetPlatform.windows, locale: 'zh-CN', defaultLocale: 'en-US'),
      );
      expect(adapter.site.capability<LiveRoomProvider>(), isNotNull);
      expect(adapter.site.capability<LiveDiscoveryProvider>(), isNotNull);
      expect(adapter.site.capability<LiveSearchProvider>(), isNotNull);
      expect(adapter.site.capability<LivePlaybackProvider>(), isNotNull);
      expect(adapter.site.capability<LiveLinkResolver>(), isNotNull);
      expect(adapter.site.capability<LiveDanmakuProvider>(), isNull, reason: 'the reference ships no danmaku');
      expect(adapter.site.capability<LiveAreaProvider>(), isNull, reason: 'TikTok has no categories');
      expect(adapter.site.capability<LiveHotProvider>(), isNull);
      expect(adapter.site.capability<LiveAnchorProvider>(), isNull);
      expect(adapter.site.capability<LiveWebSearchProvider>(), isNull);
      await adapter.site.dispose();
    });

    test('an entry is one request, and playback reads its streams', () async {
      final adapter = _adapter();
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_user));
      expect(adapter.http.sent, hasLength(1));
      final request = adapter.http.sent.single;
      expect(request.url.host, 'www.tiktok.com');
      expect(request.url.path, '/api-live/user/room/');
      expect(request.url.queryParameters['uniqueId'], _user);
      expect(request.url.queryParameters['aid'], '1988');
      expect(request.headers['referer'], TiktokEndpoints.roomUrl(_user));
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.runtime.streamHandle, isA<TiktokRoomData>());
      // The qualities and lines come from the entry, without a request.
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      final before = adapter.http.sent.length;
      final qualities = _right(await playback.getQualities(roomId: _user));
      expect(qualities.single.qualityId, 'h264:origin');
      expect(qualities.single.label, '原画');
      final lines = _right(await playback.getLines(roomId: _user));
      expect(lines, hasLength(2));
      expect(lines.first.headers['referer'], TiktokEndpoints.roomUrl(_user));
      expect(adapter.http.sent.length, before, reason: 'the entry already holds the streams');
      await adapter.site.dispose();
    });

    test('a room that cannot play names the reason', () async {
      final offline = _adapter(
        onSend: (request) => switch (request.url.path) {
          '/api-live/user/room/' => _resp(200, _userRoom(live: _live(status: 4))),
          _ => _ordinary(request),
        },
      );
      final room = _right(await offline.site.capability<LiveRoomProvider>()!.getRoom(_user));
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(
        _leftOf(await offline.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _user)),
        isA<LiveSiteContentUnavailable>(),
      );

      final restricted = _adapter(
        onSend: (request) => switch (request.url.path) {
          '/api-live/user/room/' => _resp(200, _userRoom(live: _live(liveSubOnly: 1))),
          _ => _ordinary(request),
        },
      );
      expect(
        _leftOf(await restricted.site.capability<LivePlaybackProvider>()!.getLines(roomId: _user)),
        isA<LiveSiteContentUnavailable>(),
      );
    });

    test('a room id that is no username is refused before any request', () async {
      final adapter = _adapter();
      expect(
        _leftOf(await adapter.site.capability<LiveRoomProvider>()!.getRoom('not a user!')),
        isA<LiveSiteNotFound>(),
      );
      expect(_leftOf(await adapter.site.capability<LiveRoomProvider>()!.getRoom('')), isA<LiveSiteNotFound>());
      expect(
        _leftOf(
          await adapter.site.capability<LivePlaybackProvider>()!.getQualities(roomId: 'way.too.long.to.be.a.username'),
        ),
        isA<LiveSiteNotFound>(),
      );
      expect(adapter.http.sent, isEmpty);
      await adapter.site.dispose();
    });

    test('a user the site does not know is not-found', () async {
      final adapter = _adapter();
      expect(_leftOf(await adapter.site.capability<LiveRoomProvider>()!.getRoom('ghost')), isA<LiveSiteNotFound>());
      await adapter.site.dispose();
    });

    test('a refused or throttled answer is mapped at the boundary', () async {
      final refused = _adapter(onSend: (_) => _resp(401, 'nope'));
      expect(_leftOf(await refused.site.capability<LiveRoomProvider>()!.getRoom(_user)), isA<LiveSiteRateLimitError>());
      final throttled = _adapter(onSend: (_) => _resp(429, 'nope'));
      expect(
        _leftOf(await throttled.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _user)),
        isA<LiveSiteRateLimitError>(),
      );
      final broken = _adapter(onSend: (_) => throw const ConnectFailure('refused'));
      expect(_leftOf(await broken.site.capability<LiveRoomProvider>()!.getRoom(_user)), isA<LiveSiteNetworkError>());
    });

    test('the directory is an empty last page, a page below 1 a caller error', () async {
      final adapter = _adapter();
      final page = _right(await adapter.site.capability<LiveRoomProvider>()!.getRooms(const LivePageRequest()));
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
      final discovery = _right(await adapter.site.capability<LiveDiscoveryProvider>()!.getRecommendedRooms());
      expect(discovery.items, isEmpty);
      expect(discovery.hasMore, isFalse);
      expect(adapter.http.sent, isEmpty, reason: 'nothing is requested');
      expect(
        _leftOf(await adapter.site.capability<LiveRoomProvider>()!.getRooms(const LivePageRequest(page: 0))),
        isA<LiveSiteInvalidArgument>(),
      );
      expect(
        _leftOf(
          await adapter.site.capability<LiveDiscoveryProvider>()!.getRecommendedRooms(
            request: const LivePageRequest(page: 0),
          ),
        ),
        isA<LiveSiteInvalidArgument>(),
      );
      await adapter.site.dispose();
    });

    test('a search finds the user a keyword or link names', () async {
      final adapter = _adapter();
      final search = adapter.site.capability<LiveSearchProvider>()!;
      expect(search.supportedTargets, {LiveSearchTarget.rooms});
      expect(
        _leftOf(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.anchors))),
        isA<LiveSiteUnsupported>(),
      );

      final byName = await search.search(const LiveSearchRequest(query: '@$_user', target: LiveSearchTarget.rooms));
      final named = (_right(byName).items.single as RoomSearchResult).room;
      expect(named.roomId, _user);
      expect(named.broadcast.liveStatus, LiveStatus.live);
      expect(named.runtime.streamHandle, isNull, reason: 'a search card reads no streams');
      expect(adapter.http.sent, hasLength(1));

      await search.search(
        const LiveSearchRequest(query: 'https://www.tiktok.com/@$_user/live', target: LiveSearchTarget.rooms),
      );
      expect(adapter.http.sent, hasLength(2));

      expect(
        _right(await search.search(const LiveSearchRequest(query: 'ghost', target: LiveSearchTarget.rooms))).items,
        isEmpty,
      );
      expect(
        _right(await search.search(const LiveSearchRequest(query: 'not a user!', target: LiveSearchTarget.rooms)))
            .items,
        isEmpty,
      );
      expect(
        _right(await search.search(const LiveSearchRequest(query: _user, target: LiveSearchTarget.rooms, page: 2)))
            .items,
        isEmpty,
      );
      expect(
        _right(await search.search(const LiveSearchRequest(query: _user, target: LiveSearchTarget.rooms, pageSize: 0)))
            .items,
        isEmpty,
      );
      await adapter.site.dispose();
    });

    test('a share/live link and a short link find their room', () async {
      final adapter = _adapter();
      final search = adapter.site.capability<LiveSearchProvider>()!;
      final byShare = await search.search(
        const LiveSearchRequest(query: 'https://www.tiktok.com/share/live/$_liveRoom', target: LiveSearchTarget.rooms),
      );
      expect((_right(byShare).items.single as RoomSearchResult).room.roomId, _user);
      expect(adapter.http.sent.map((seen) => seen.url.path).toList(), [
        '/webcast/room/info/',
        '/api-live/user/room/',
      ], reason: 'the owner first, then the card');

      final byShort = await search.search(
        const LiveSearchRequest(query: 'https://vm.tiktok.com/ZSabc/', target: LiveSearchTarget.rooms),
      );
      expect((_right(byShort).items.single as RoomSearchResult).room.roomId, _user);
      expect(adapter.http.sent[2].url.host, 'vm.tiktok.com', reason: 'the short link itself is read');

      expect(
        _right(
          await search.search(
            const LiveSearchRequest(query: 'https://vt.tiktok.com/ZZZZZZ/', target: LiveSearchTarget.rooms),
          ),
        ).items,
        isEmpty,
        reason: 'a landing page that names no user',
      );

      final refused = _adapter(
        onSend: (request) => request.url.host == 'vm.tiktok.com' ? _resp(403, 'nope') : _ordinary(request),
      );
      expect(
        _leftOf(
          await refused.site.capability<LiveSearchProvider>()!.search(
            const LiveSearchRequest(query: 'https://vm.tiktok.com/ZSabc/', target: LiveSearchTarget.rooms),
          ),
        ),
        isA<LiveSiteRateLimitError>(),
      );
      await adapter.site.dispose();
      await refused.site.dispose();
    });

    test('links are canonicalized, broadcasts and short links need a request', () async {
      final adapter = _adapter();
      final link = adapter.site.capability<LiveLinkResolver>()!;
      expect(
        _right(await link.resolve(Uri.parse('https://www.tiktok.com/@$_user/live'))),
        Uri.parse(TiktokEndpoints.roomUrl(_user)),
      );
      expect(adapter.http.sent, isEmpty, reason: 'a user link needs no request');
      expect(
        _right(await link.resolve(Uri.parse('https://www.tiktok.com/share/live/$_liveRoom'))),
        Uri.parse(TiktokEndpoints.roomUrl(_user)),
      );
      expect(adapter.http.sent.single.url.path, '/webcast/room/info/');
      expect(
        _right(await link.resolve(Uri.parse('https://vm.tiktok.com/ZSabc/'))),
        Uri.parse(TiktokEndpoints.roomUrl(_user)),
      );
      expect(_leftOf(await link.resolve(Uri.parse('https://example.com/@x/live'))), isA<LiveSiteUnsupported>());
      expect(
        _leftOf(await link.resolve(Uri.parse('https://www.tiktok.com/@$_user/video/123'))),
        isA<LiveSiteNotFound>(),
        reason: 'a video is no room',
      );
      final gone = _adapter(
        onSend: (request) => switch (request.url.path) {
          '/webcast/room/info/' => _resp(200, _roomInfo(statusCode: 1404)),
          _ => _ordinary(request),
        },
      );
      expect(
        _leftOf(
          await gone.site.capability<LiveLinkResolver>()!.resolve(
            Uri.parse('https://www.tiktok.com/share/live/$_liveRoom'),
          ),
        ),
        isA<LiveSiteNotFound>(),
      );
      await adapter.site.dispose();
      await gone.site.dispose();
    });

    test('the prefer-H.264 setting is consulted at each call', () async {
      var calls = 0;
      final adapter = _adapter(
        preferH264: () {
          calls++;
          return false;
        },
      );
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      expect(_right(await playback.getQualities(roomId: _user)), hasLength(1));
      expect(calls, 1, reason: 'one consult per call');
      expect(_right(await playback.getLines(roomId: _user)), hasLength(2));
      expect(calls, 2);
      await adapter.site.dispose();
    });

    test('an entered room keeps its streams for playback', () async {
      final adapter = _adapter();
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      await adapter.site.detail(_user);
      expect(adapter.http.sent, hasLength(1));
      expect(_right(await playback.getQualities(roomId: _user)), hasLength(1));
      expect(adapter.http.sent, hasLength(1), reason: 'the entry is kept');
      await adapter.site.detail(_other);
      expect(adapter.http.sent, hasLength(2));
      expect(_right(await playback.getQualities(roomId: _user)), hasLength(1));
      expect(_right(await playback.getQualities(roomId: _other)), hasLength(1));
      expect(adapter.http.sent, hasLength(2), reason: 'both entries are kept');
      await adapter.site.dispose();
    });

    test('the stream cache forgets the oldest beyond its bound', () async {
      final adapter = _adapter();
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      for (var index = 0; index < 70; index++) {
        await adapter.site.detail('user$index');
      }
      expect(adapter.http.sent, hasLength(70));
      expect(_right(await playback.getQualities(roomId: 'user0')), hasLength(1));
      expect(adapter.http.sent, hasLength(71), reason: 'user0 was evicted, so playback enters again');
      expect(_right(await playback.getQualities(roomId: 'user69')), hasLength(1));
      expect(adapter.http.sent, hasLength(71), reason: 'the last entered room is kept');
      await adapter.site.dispose();
    });
  });
}
