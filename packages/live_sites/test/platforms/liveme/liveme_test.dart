import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site_context.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/core/live_site_runtime_info.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/liveme/api/liveme_endpoints.dart';
import 'package:live_sites/src/platforms/liveme/api/liveme_http.dart';
import 'package:live_sites/src/platforms/liveme/api/liveme_signer.dart';
import 'package:live_sites/src/platforms/liveme/liveme_site.dart';
import 'package:live_sites/src/platforms/liveme/parsers/liveme_failure.dart';
import 'package:live_sites/src/platforms/liveme/parsers/liveme_json.dart';
import 'package:live_sites/src/platforms/liveme/parsers/liveme_link.dart';
import 'package:live_sites/src/platforms/liveme/parsers/liveme_room_parser.dart';
import 'package:test/test.dart';

/// The clock of the tests: 2026-09-30, in the afternoon.
final DateTime _at = DateTime.parse('2026-09-30T14:00:00.000Z').toUtc();

const String _shortId = '12345';
const String _userId = '1012345678901';
const String _videoId = '2012345678901';
const String _otherShortId = '23456';
const String _otherUserId = '1012345678902';

const String _avatar = 'https://img.esxscloud.com/a.png';
const String _cover = 'https://img.esxscloud.com/cover.png';
const String _flv = 'https://flv.linkv.fun/liveme/stream.flv?wsTime=1';
const String _flvMore = 'https://flv2.linkv.fun/liveme/stream.flv?wsTime=2';
const String _hls = 'https://hls.linkv.fun/liveme/stream.m3u8?wsTime=1';
const String _smoothFlv = 'https://flv.linkv.fun/liveme/stream_small.flv';

String _json(Object? data) => jsonEncode(data);

String _md5Of(String value) => crypto.md5.convert(utf8.encode(value)).toString();

/// An answer envelope: `status` 200 and [data], or [status]/[msg] instead.
String _envelope(Object? data, {Object? status = 200, String msg = ''}) =>
    _json({'status': status, 'msg': msg, 'data': data});

Map<String, Object?> _videoInfo({
  Object? ushortid = _shortId,
  Object? userid = _userId,
  Object? vid = _videoId,
  String uname = '主播甲',
  String title = '晚间直播',
  String uface = _avatar,
  String videocapture = _cover,
  Object? online = 1,
  Object? status = 0,
  Object? roomstate = 0,
  Object? playnumber = 42,
  Object? watchnumber = 9001,
  Object? heat = 1234,
  Object? likenum = 77,
  Object? vtime = 1727700000,
  Object? ispvt,
  Object? livebptype,
  Object? hotLabel,
  String countryCode = 'US',
  String videosource = _flv,
  String videosourcemore = _flvMore,
  String hlsvideosource = _hls,
  String smallsource = _smoothFlv,
}) => {
  'ushortid': ushortid,
  'userid': userid,
  'vid': vid,
  'uname': uname,
  'title': title,
  'uface': uface,
  'videocapture': videocapture,
  'online': online,
  'status': status,
  'roomstate': roomstate,
  'playnumber': playnumber,
  'watchnumber': watchnumber,
  'heat': heat,
  'likenum': likenum,
  'vtime': vtime,
  'ispvt': ?ispvt,
  'livebptype': ?livebptype,
  'hot_label_v2': ?hotLabel,
  'countryCode': countryCode,
  'videosource': videosource,
  'videosourcemore': videosourcemore,
  'hlsvideosource': hlsvideosource,
  'smallsource': smallsource,
};

Map<String, Object?> _userInfo({String usign = '唱歌的', String countryCode = 'US'}) => {
  'userid': _userId,
  'uname': '主播甲',
  'usign': usign,
  'countryCode': countryCode,
};

String _queryinfoFixture({
  Map<String, Object?>? video,
  Map<String, Object?>? user,
  Object? status = 200,
  String msg = '',
}) => _envelope({'video_info': video ?? _videoInfo(), 'user_info': user ?? _userInfo()}, status: status, msg: msg);

String _mappingFixture({Object? uid = _userId, Object? vid = _videoId, Object? status = 200, String msg = ''}) =>
    _envelope({'uid': uid, 'vid': vid}, status: status, msg: msg);

String _profileFixture({Object? uid, Object? shortId, String bigFace = '', String bigCover = ''}) => _envelope({
  'user': {
    'user_info': {
      'uid': uid ?? _userId,
      'short_id': shortId ?? _shortId,
      'nickname': '主播甲',
      'big_face': bigFace,
      'face': _avatar,
      'big_cover': bigCover,
      'cover': _cover,
      'usign': '唱歌的',
      'countryCode': 'us',
    },
    'count_info': {'follower_count': 5678},
  },
});

String _featurelistFixture({List<Object?>? rows, Object? nextPage = 1}) => _envelope({
  'video_info': rows ?? [_videoInfo()],
  'next_page': nextPage,
});

String _searchFixture({List<Object?>? rows}) => _envelope({
  'data_info':
      rows ??
      [
        {'short_id': _shortId, 'user_id': _userId, 'nickname': '主播甲', 'face': _avatar, 'is_live': 1, 'fans_num': 99},
      ],
});

LiveResponse _resp(int status, String body) =>
    LiveResponse(statusCode: status, headers: const {}, bodyBytes: Uint8List.fromList(utf8.encode(body)));

final class _Seen {
  new(LiveRequest request) : method = request.method, url = request.url, headers = request.headers, body = request.body;
  final String method;
  final Uri url;
  final Map<String, String> headers;
  final String? body;
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

/// The answers of the site: the featured list, the room mapping, the anchor
/// profile, the signed broadcast and the keyword search.
LiveResponse _ordinary(_Seen request) {
  if (request.url.host == LivemeEndpoints.directoryHost) {
    return _resp(200, _featurelistFixture());
  }
  switch (request.url.path) {
    case '/liveme_ent/v1/user/uid_vid_by_short_id':
      return _resp(200, _mappingFixture());
    case '/user/getinfo':
      return _resp(200, _profileFixture());
    case '/live/queryinfosimple':
      return _resp(200, _queryinfoFixture());
    case '/search/searchKeyword':
      return _resp(200, _searchFixture());
  }
  return _resp(404, 'nope');
}

T _right<T>(Either<LiveSiteError, T> either) => either.match((left) => throw StateError('$left'), (right) => right);

LiveSiteError _leftOf<T>(Either<LiveSiteError, T> either) =>
    either.match((left) => left, (right) => throw StateError('not a left: $either'));

/// The site over a fake transport, with a fixed clock.
({LivemeSite site, _FakeHttp http}) _adapter({LiveResponse Function(_Seen request)? onSend}) {
  final http = _FakeHttp(onSend ?? _ordinary);
  return (site: LivemeSite(http: LivemeHttp(http), now: () => _at), http: http);
}

void main() {
  group('status gates and readers', () {
    test('an HTTP status says what kind of answer it is', () {
      void expectKind(int status, LivemeFailureKind kind) {
        try {
          LivemeJson.checkStatus(status, 'x');
          fail('no throw for $status');
        } on LivemeFailure catch (failure) {
          expect(failure.kind, kind);
        }
      }

      expectKind(400, LivemeFailureKind.apiChanged);
      expectKind(401, LivemeFailureKind.riskControl);
      expectKind(403, LivemeFailureKind.riskControl);
      expectKind(404, LivemeFailureKind.notFound);
      expectKind(420, LivemeFailureKind.rateLimited);
      expectKind(429, LivemeFailureKind.rateLimited);
      for (final status in [301, 500, 503]) {
        expectKind(status, LivemeFailureKind.network);
      }
      LivemeJson.checkStatus(200, 'x');
    });

    test('a business status says what kind of answer it is', () {
      Map<String, dynamic> envelopeOf(Object? status, String msg) =>
          LivemeJson.envelope(_envelope({'a': 1}, status: status, msg: msg), 'x', 200);
      expect(envelopeOf(200, ''), {
        'status': 200,
        'msg': '',
        'data': {'a': 1},
      }, reason: 'a number is read');
      expect(envelopeOf('200', '').isNotEmpty, isTrue, reason: 'a string is read');
      for (final code in [400, 404]) {
        expect(
          () => envelopeOf(code, ''),
          throwsA(predicate((e) => e is LivemeFailure && e.kind == LivemeFailureKind.notFound)),
          reason: '$code is not-found',
        );
      }
      for (final code in [401, 403]) {
        expect(
          () => envelopeOf(code, ''),
          throwsA(predicate((e) => e is LivemeFailure && e.kind == LivemeFailureKind.riskControl)),
        );
      }
      for (final code in [420, 429]) {
        expect(
          () => envelopeOf(code, ''),
          throwsA(predicate((e) => e is LivemeFailure && e.kind == LivemeFailureKind.rateLimited)),
        );
      }
      expect(
        () => envelopeOf(500, 'user not exist'),
        throwsA(predicate((e) => e is LivemeFailure && e.kind == LivemeFailureKind.notFound)),
      );
      expect(
        () => envelopeOf(502, 'bad gateway'),
        throwsA(predicate((e) => e is LivemeFailure && e.kind == LivemeFailureKind.network)),
      );
      expect(
        () => envelopeOf(402, ''),
        throwsA(predicate((e) => e is LivemeFailure && e.kind == LivemeFailureKind.apiChanged)),
      );
      expect(
        () => LivemeJson.envelope(_envelope({'a': 1}, status: null), 'x', 200),
        throwsA(predicate((e) => '$e'.contains('no status'))),
      );
    });

    test('a body must be JSON of a bounded size', () {
      expect(() => LivemeJson.envelope('<html>', 'x', 200), throwsA(predicate((e) => '$e'.contains('not JSON'))));
      expect(
        () => LivemeJson.envelope('{"a":"${'x' * 9000000}"}', 'x', 200),
        throwsA(predicate((e) => '$e'.contains('answer over'))),
      );
      expect(
        () => LivemeJson.envelope('[1]', 'x', 200),
        throwsA(predicate((e) => '$e'.contains('expected an object'))),
      );
      expect(
        () => LivemeJson.envelope(_envelope({'a': 1}), 'x', 503),
        throwsA(predicate((e) => '$e'.contains('HTTP 503'))),
        reason: 'the HTTP status is read first',
      );
    });

    test('ids, counts and texts are read strictly', () {
      expect(LivemeJson.shortId(12345, 'x'), '12345');
      expect(() => LivemeJson.shortId('012345', 'x'), throwsA(anything), reason: 'no leading zero');
      expect(() => LivemeJson.shortId('1234', 'x'), throwsA(anything), reason: 'at least five digits');
      expect(LivemeJson.longId(_videoId, 'x'), _videoId);
      expect(() => LivemeJson.longId('123', 'x'), throwsA(anything));
      expect(LivemeJson.count('42', 'x'), 42);
      expect(LivemeJson.count(null, 'x'), isNull);
      expect(LivemeJson.count('', 'x'), isNull);
      expect(() => LivemeJson.count(-1, 'x'), throwsA(anything));
      expect(() => LivemeJson.count('x', 'x'), throwsA(anything));
      expect(LivemeJson.text(null, 'x'), '');
      expect(LivemeJson.text(' hi ', 'x'), 'hi');
      expect(() => LivemeJson.text(3, 'x'), throwsA(anything));
      expect(LivemeJson.firstText(['', 'a'], 'x'), 'a');
      expect(() => LivemeJson.firstText([3], 'x'), throwsA(anything));
      expect(LivemeJson.countryCode('us'), 'US');
      expect(LivemeJson.countryCode('USA'), '');
      expect(() => LivemeJson.list('no', 'x', max: 9), throwsA(anything));
      expect(() => LivemeJson.list([1, 2, 3], 'x', max: 2), throwsA(anything));
    });

    test('a failure maps onto the Either-side errors', () {
      LiveSiteError of(LivemeFailureKind kind) => LivemeFailure(kind, 'x').toLiveSiteError('liveme');
      expect(of(LivemeFailureKind.notFound), isA<LiveSiteNotFound>());
      expect(of(LivemeFailureKind.apiChanged), isA<LiveSiteParseError>());
      expect(of(LivemeFailureKind.network), isA<LiveSiteNetworkError>());
      expect(
        of(LivemeFailureKind.riskControl),
        isA<LiveSiteRateLimitError>(),
        reason: 'a refusal folds into rate limit',
      );
      expect(of(LivemeFailureKind.rateLimited), isA<LiveSiteRateLimitError>());
      expect(of(LivemeFailureKind.streamUnavailable), isA<LiveSiteContentUnavailable>());
      expect(of(LivemeFailureKind.invalidArgument), isA<LiveSiteInvalidArgument>());
      expect(const LivemeFailure(LivemeFailureKind.network, 'x').isTransient, isTrue);
      expect(const LivemeFailure(LivemeFailureKind.rateLimited, 'x').isTransient, isTrue);
      expect(const LivemeFailure(LivemeFailureKind.riskControl, 'x').isTransient, isFalse);
      expect(const LivemeFailure(LivemeFailureKind.notFound, 'x').isTransient, isFalse);
    });
  });

  group('links', () {
    test('room, anchor and share pages are read', () {
      expect(
        LivemeLink.parse('https://liveme.com/livehot/streaming/$_shortId'),
        const LivemeLink(LivemeLinkKind.shortId, _shortId),
      );
      expect(
        LivemeLink.parse('http://WWW.LIVEME.COM/us/livehot/STREAMING/$_shortId?x=1#f'),
        const LivemeLink(LivemeLinkKind.shortId, _shortId),
        reason: 'words in any case, a locale segment, query and fragment ignored',
      );
      expect(LivemeLink.parse('https://www.liveme.com/zh-tw/u/$_userId')?.kind, LivemeLinkKind.userId);
      expect(LivemeLink.parse('https://liveme.com/v/$_videoId')?.kind, LivemeLinkKind.videoId);
      expect(LivemeLink.parse('https://liveme.com/m/v/$_videoId/index.html')?.kind, LivemeLinkKind.videoId);
      expect(LivemeLink.parseOrShortId('  $_shortId  '), const LivemeLink(LivemeLinkKind.shortId, _shortId));
      expect(LivemeLink.parseOrShortId('keyword'), isNull);
      expect(LivemeEndpoints.roomUrl(_shortId), 'https://www.liveme.com/livehot/streaming/$_shortId');
    });

    test('anything else is no link', () {
      for (final bad in [
        'https://evil.com/livehot/streaming/$_shortId',
        'https://sub.liveme.com/livehot/streaming/$_shortId',
        'ftp://liveme.com/livehot/streaming/$_shortId',
        'https://u:p@liveme.com/livehot/streaming/$_shortId',
        'https://liveme.com/livehot/streaming/012345',
        'https://liveme.com/livehot/streaming/$_shortId/extra',
        'https://liveme.com/livehot/streaming/',
        'https://liveme.com/u/123',
        'https://liveme.com/livehot/other/$_shortId',
        'https://liveme.com/livehot/../streaming/$_shortId',
        'https://liveme.com/v/$_shortId',
        'not a url',
      ]) {
        expect(LivemeLink.parse(bad), isNull, reason: bad);
      }
    });
  });

  group('signer', () {
    test('the signed form carries the web client fields and the md5 signature', () {
      const timestamp = '1727700000000';
      final signed = LivemeSigner.signAt(query: {'b': '2', 'a': '1'}, form: {'videoid': '9'}, timestamp: timestamp);
      expect(signed.fields, {
        'videoid': '9',
        'lm_s_id': LivemeSigner.clientId,
        'lm_s_ts': timestamp,
        'lm_s_str': _md5Of(timestamp),
        'lm_s_ver': '1',
        'h5': '1',
      });
      // The pairs sorted by name, then the client id, the timestamp, the
      // secret.
      final pairs = [
        'a1',
        'b2',
        'h51',
        'lm_s_id${LivemeSigner.clientId}',
        'lm_s_str${_md5Of(timestamp)}',
        'lm_s_ts$timestamp',
        'lm_s_ver1',
        'videoid9',
      ].join();
      expect(
        signed.signature,
        _md5Of(
          '$pairs${LivemeSigner.clientId}$timestamp'
          'dd46dbb442b6e4ba817d6347d2ddf493',
        ),
      );
    });

    test('the vali comes from the web client alphabet, two requests in one millisecond differ', () {
      final signer = LivemeSigner(random: math.Random(1));
      const alphabet = 'ABCDEFGHJKMNPQRSTWXYZabcdefhijkmnprstwxyz2345678';
      expect(RegExp('^[$alphabet]{4}l[$alphabet]{4}m[$alphabet]{5}\$').hasMatch(signer.vali()), isTrue);
      final now = _at;
      final first = signer.sign(query: const {}, form: const {}, now: now);
      final second = signer.sign(query: const {}, form: const {}, now: now);
      expect(first.fields['lm_s_ts'], isNot(second.fields['lm_s_ts']), reason: 'the counter digit differs');
      expect(first.signature, isNot(second.signature));
    });
  });

  group('featured list', () {
    test('the cards are read, each once, and next_page says more', () {
      final page = LivemeRoomParser.featuredPage(
        _featurelistFixture(
          rows: [
            _videoInfo(),
            _videoInfo(vid: ''),
            _videoInfo(ushortid: _otherShortId, userid: _otherUserId),
            _videoInfo(),
          ],
        ),
      );
      expect(page.rooms.map((room) => room.roomId), [_shortId, _otherShortId], reason: 'repeats left out');
      expect(page.hasMore, isTrue);
      expect(LivemeRoomParser.featuredPage(_featurelistFixture(nextPage: 0)).hasMore, isFalse);
    });

    test('a card without a short id is a union room and skipped', () {
      final page = LivemeRoomParser.featuredPage(_featurelistFixture(rows: [_videoInfo(ushortid: null), _videoInfo()]));
      expect(page.rooms, hasLength(1));
    });

    test('a broken card costs only itself, unless none is usable', () {
      final page = LivemeRoomParser.featuredPage(
        _featurelistFixture(
          rows: [
            _videoInfo(),
            _videoInfo(uname: ''),
          ],
        ),
      );
      expect(page.rooms, hasLength(1));
      expect(
        () => LivemeRoomParser.featuredPage(_featurelistFixture(rows: [_videoInfo(uname: '')])),
        throwsA(predicate((e) => '$e'.contains('uname'))),
      );
    });

    test('a list that is not one, or an over-long one, is api-changed', () {
      expect(
        () => LivemeRoomParser.featuredPage(_envelope({'video_info': 'no', 'next_page': 1})),
        throwsA(predicate((e) => '$e'.contains('expected a list'))),
      );
      expect(
        () => LivemeRoomParser.featuredPage(_featurelistFixture(rows: List.filled(101, _videoInfo()))),
        throwsA(anything),
      );
    });
  });

  group('search page', () {
    test('the anchors are read, live or not', () {
      final rooms = LivemeRoomParser.searchPage(
        _searchFixture(
          rows: [
            {'short_id': _shortId, 'user_id': _userId, 'nickname': '主播甲', 'is_live': 1, 'fans_num': 99},
            {'short_id': _otherShortId, 'user_id': _otherUserId, 'uname': '主播乙', 'is_live': 0},
            {'short_id': '34567', 'user_id': '1012345678903', 'nickname': '主播丙'},
          ],
        ),
      );
      expect(rooms.map((room) => room.roomId), [_shortId, _otherShortId, '34567']);
      expect(rooms.map((room) => room.broadcast.liveStatus), [LiveStatus.live, LiveStatus.offline, LiveStatus.unknown]);
      expect(rooms[1].content.title, '主播乙', reason: 'uname names the anchor and the title');
      expect(rooms[1].anchor?.name, '主播乙');
      expect(rooms[0].anchor?.followerCount, 99);
      expect(rooms[0].broadcast.liveStatus, LiveStatus.live);
    });

    test('a broken row costs only itself, unless none is usable', () {
      expect(
        LivemeRoomParser.searchPage(
          _searchFixture(
            rows: [
              {'short_id': _shortId, 'user_id': _userId, 'nickname': '主播甲'},
              {'short_id': _shortId, 'user_id': 'x', 'nickname': 'broken'},
            ],
          ),
        ),
        hasLength(1),
      );
      expect(
        () => LivemeRoomParser.searchPage(
          _searchFixture(
            rows: [
              {'short_id': '1', 'user_id': _userId, 'nickname': 'broken'},
            ],
          ),
        ),
        throwsA(isA<LivemeFailure>()),
      );
    });
  });

  group('room answers', () {
    test('the mapping names the user and the broadcast', () {
      expect(LivemeRoomParser.mapping(_mappingFixture()), (userId: _userId, videoId: _videoId));
      expect(LivemeRoomParser.mapping(_mappingFixture(vid: '')).videoId, '');
      expect(
        () => LivemeRoomParser.mapping(_mappingFixture(vid: '7')),
        throwsA(isA<LivemeFailure>()),
        reason: 'a video id is a long id',
      );
      expect(() => LivemeRoomParser.mapping(_mappingFixture(uid: '7')), throwsA(isA<LivemeFailure>()));
      expect(
        () => LivemeRoomParser.mapping(_mappingFixture(status: 400, msg: 'unknown short id')),
        throwsA(predicate((e) => e is LivemeFailure && e.kind == LivemeFailureKind.notFound)),
      );
    });

    test('the profile is the asked anchor, with the bigger pictures when given', () {
      final profile = LivemeRoomParser.profile(_profileFixture(), userId: _userId);
      expect(profile.shortId, _shortId);
      expect(profile.nickname, '主播甲');
      expect(profile.avatar, _avatar, reason: 'face when big_face is empty');
      expect(profile.cover, _cover);
      expect(profile.countryCode, 'US', reason: 'the code is upper-cased');
      expect(profile.followers, 5678);
      final withBig = LivemeRoomParser.profile(_profileFixture(bigFace: '$_avatar-big'), userId: _userId);
      expect(withBig.avatar, '$_avatar-big');
      expect(
        () => LivemeRoomParser.profile(_profileFixture(uid: _otherUserId), userId: _userId),
        throwsA(predicate((e) => '$e'.contains('asked'))),
      );
      expect(
        () => LivemeRoomParser.profile(
          _envelope(
            <String, Object?>{
              'user': <String, Object?>{'user_info': <String, Object?>{}},
            },
            status: 500,
            msg: 'user not exist',
          ),
          userId: _userId,
        ),
        throwsA(predicate((e) => e is LivemeFailure && e.kind == LivemeFailureKind.notFound)),
      );
    });

    test('the broadcast must be the asked one of the asked room', () {
      expect(LivemeRoomParser.video(_queryinfoFixture(), videoId: _videoId, shortId: _shortId).state, LivemeState.live);
      expect(
        () => LivemeRoomParser.video(_queryinfoFixture(), videoId: '1', shortId: _shortId),
        throwsA(predicate((e) => '$e'.contains('asked'))),
      );
      expect(
        () => LivemeRoomParser.video(_queryinfoFixture(), videoId: _videoId, shortId: _otherShortId),
        throwsA(predicate((e) => '$e'.contains('asked'))),
      );
    });

    test('online with status 0 and roomstate 0 is live, anything said otherwise is offline', () {
      expect(LivemeRoomParser.videoSnapshot(_videoInfo()).state, LivemeState.live);
      expect(LivemeRoomParser.videoSnapshot(_videoInfo(online: 0)).state, LivemeState.offline);
      expect(LivemeRoomParser.videoSnapshot(_videoInfo(status: 2)).state, LivemeState.offline);
      expect(LivemeRoomParser.videoSnapshot(_videoInfo(roomstate: 1)).state, LivemeState.offline);
      expect(LivemeRoomParser.videoSnapshot(_videoInfo(online: null)).state, LivemeState.unknown);
    });

    test('a live broadcast carries the viewers, the start and the area', () {
      final snapshot = LivemeRoomParser.videoSnapshot(_videoInfo());
      expect(snapshot.currentViewers, 42);
      expect(snapshot.totalViewers, 9001);
      expect(snapshot.heat, 1234);
      expect(snapshot.startedAt, DateTime.fromMillisecondsSinceEpoch(1727700000 * 1000, isUtc: true));
      expect(snapshot.countryCode, 'US');
      final offline = LivemeRoomParser.videoSnapshot(_videoInfo(online: 0));
      expect(offline.currentViewers, isNull);
      expect(offline.startedAt, isNull);
      expect(offline.restriction, isNull);
    });

    test('the title is the name when the broadcast has none of its own', () {
      expect(LivemeRoomParser.videoSnapshot(_videoInfo(title: '')).title, '主播甲');
      expect(LivemeRoomParser.videoSnapshot(_videoInfo(title: 'Click for fun!')).title, '主播甲');
      expect(LivemeRoomParser.videoSnapshot(_videoInfo(title: '唱歌')).title, '唱歌');
    });

    test('the pictures fall back field by field, the introduction is the signature', () {
      final snapshot = LivemeRoomParser.videoSnapshot(
        _videoInfo(uface: '', videocapture: ''),
        user: {'uname': '主播甲', 'face': '$_avatar-2', 'usign': '介绍'},
      );
      expect(snapshot.avatar, '$_avatar-2');
      expect(snapshot.cover, '', reason: 'the user has no cover field');
      expect(snapshot.bio, '介绍');
      expect(
        LivemeRoomParser.videoSnapshot(_videoInfo(videocapture: ''), user: {'uname': 'x', 'usign': 'y'}).cover,
        '',
        reason: 'smallcover is read when videocapture is empty',
      );
    });

    test('a private or paid broadcast is live and marked', () {
      expect(LivemeRoomParser.videoSnapshot(_videoInfo(ispvt: 1)).restriction, LiveRestriction.private);
      expect(LivemeRoomParser.videoSnapshot(_videoInfo(livebptype: 7)).restriction, LiveRestriction.paid);
      expect(
        LivemeRoomParser.videoSnapshot(_videoInfo(hotLabel: _json({'text': 'Paid Broadcast'}))).restriction,
        LiveRestriction.paid,
        reason: 'the label is JSON text, any case',
      );
      expect(
        LivemeRoomParser.videoSnapshot(_videoInfo(hotLabel: <String, Object?>{'text': 'paid broadcast'})).restriction,
        LiveRestriction.paid,
        reason: 'the label may arrive as an object',
      );
      expect(
        LivemeRoomParser.videoSnapshot(_videoInfo(hotLabel: 'not json')).restriction,
        LiveRestriction.none,
        reason: 'a label that does not parse says nothing',
      );
      expect(LivemeRoomParser.videoSnapshot(_videoInfo()).restriction, LiveRestriction.none);
    });

    test('the media is read only for a live unrestricted broadcast, when asked', () {
      expect(LivemeRoomParser.videoSnapshot(_videoInfo()).streams, isEmpty, reason: 'not asked');
      expect(LivemeRoomParser.videoSnapshot(_videoInfo(), media: true).streams, hasLength(2));
      expect(LivemeRoomParser.videoSnapshot(_videoInfo(ispvt: 1), media: true).streams, isEmpty);
      expect(LivemeRoomParser.videoSnapshot(_videoInfo(online: 0), media: true).streams, isEmpty);
    });

    test('a broadcast completed by the profile takes what it lacks', () {
      final video = LivemeRoomParser.videoSnapshot(_videoInfo(uface: '', videocapture: '', countryCode: ''));
      final profile = LivemeRoomParser.profile(_profileFixture(), userId: _userId);
      final merged = LivemeRoomParser.withProfile(video, profile);
      expect(merged.avatar, profile.avatar);
      expect(merged.cover, profile.cover);
      expect(merged.countryCode, 'US');
      expect(merged.followers, 5678);
      expect(merged.bio, '唱歌的');
      final offline = LivemeRoomParser.offline(profile);
      expect(offline.state, LivemeState.offline);
      expect(offline.title, '主播甲');
      expect(offline.cover, _cover);
    });

    test('the room carries the v2 shape', () {
      final snapshot = LivemeRoomParser.videoSnapshot(_videoInfo(), user: _userInfo(), media: true);
      final data = LivemeRoomParser.roomData(snapshot);
      final room = LivemeRoomParser.room(snapshot, data: data);
      expect(room.platform, 'liveme');
      expect(room.roomId, _shortId);
      expect(room.content.title, '晚间直播');
      expect(room.content.coverUrl, _cover);
      expect(room.content.introduction, '唱歌的');
      expect(room.content.notice, LivemeEndpoints.chatNotice);
      expect(room.anchor?.anchorId, _userId);
      expect(room.anchor?.name, '主播甲');
      expect(room.anchor?.avatarUrl, _avatar);
      expect(room.anchor?.followerCount, isNull, reason: 'only the profile says followers');
      expect(room.area?.areaName, 'US', reason: 'the country code is the area display');
      expect(room.audience.popularity, 1234);
      expect(room.audience.onlineViewers, 42);
      expect(room.audience.totalViewers, 9001);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.popularity, reason: 'the heat leads');
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.startedAt, isNotNull);
      expect(room.broadcast.restriction, LiveRestriction.none);
      expect(room.links.webUrl, LivemeEndpoints.roomUrl(_shortId));
      expect(room.runtime.streamHandle, same(data));
      // Without heat, the concurrent viewers lead.
      final card = LivemeRoomParser.room(LivemeRoomParser.videoSnapshot(_videoInfo(heat: null)));
      expect(card.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      // An offline anchor room has no figures and no area when unnamed.
      final offlineRoom = LivemeRoomParser.room(LivemeRoomParser.videoSnapshot(_videoInfo(online: 0, countryCode: '')));
      expect(offlineRoom.broadcast.liveStatus, LiveStatus.offline);
      expect(offlineRoom.audience.primaryMetric, LiveAudienceMetricType.unknown);
      expect(offlineRoom.area, isNull);
      expect(offlineRoom.runtime.streamHandle, isNull);
    });
  });

  group('streams', () {
    LivemeRoomData dataOf(Map<String, Object?> video, {LiveRestriction? restriction}) => LivemeRoomData(
      shortId: _shortId,
      userId: _userId,
      videoId: _videoId,
      state: LivemeState.live,
      restriction: restriction,
      streams: LivemeRoomParser.streams(video),
    );

    test('the media urls are read out of fields, json text and objects, each once', () {
      final video = _videoInfo(
        videosource: _json([
          _flv,
          {'u': _flvMore},
        ]),
        videosourcemore: '',
        hlsvideosource: _json([_hls]),
        smallsource: _json({
          'a': [_smoothFlv],
        }),
      );
      final streams = LivemeRoomParser.streams(video);
      expect(streams, hasLength(2));
      expect(streams.first.flv, [_flv, _flvMore], reason: 'each once, in field order');
      expect(streams.first.hls, [_hls]);
      expect(streams.last.qualityId, LivemeEndpoints.smoothQualityId);
      expect(streams.last.flv, [_smoothFlv]);
      expect(streams.last.hls, isEmpty);
    });

    test('a media url is https on the site cdn, refused without its suffix', () {
      expect(
        LivemeRoomParser.mediaUrl('http://flv.linkv.fun/x/stream.flv', LiveStreamFormat.flv),
        'https://flv.linkv.fun/x/stream.flv',
        reason: 'the web player forces https too',
      );
      expect(
        LivemeRoomParser.mediaUrl('https://a.emolm.com/x/stream.flv', LiveStreamFormat.flv),
        'https://a.emolm.com/x/stream.flv',
        reason: 'a subdomain of the cdn',
      );
      expect(
        LivemeRoomParser.mediaUrl('http://media.example.com/x/stream.flv', LiveStreamFormat.flv),
        'http://media.example.com/x/stream.flv',
        reason: 'another host is kept as written',
      );
      expect(
        LivemeRoomParser.mediaUrl('https://flv.linkv.fun:8080/x/stream.flv', LiveStreamFormat.flv),
        'https://flv.linkv.fun:8080/x/stream.flv',
        reason: 'an explicit port is kept as written',
      );
      for (final bad in [
        'http://flv.linkv.fun/x/stream.m3u8',
        'https://flv.linkv.fun/x/stream.flv#f',
        'https://u:p@flv.linkv.fun/x/stream.flv',
        'https://flv.linkv.fun/x/stream',
        'https://flv.linkv.fun/x/stream.flv extra',
        '',
      ]) {
        expect(LivemeRoomParser.mediaUrl(bad, LiveStreamFormat.flv), isNull, reason: bad);
      }
    });

    test('an image is https on the image hosts, absolute already or made so', () {
      expect(LivemeRoomParser.image('http://img.esxscloud.com/a.png'), 'https://img.esxscloud.com/a.png');
      expect(LivemeRoomParser.image('https://www.liveme.com/a.png'), 'https://www.liveme.com/a.png');
      expect(LivemeRoomParser.image('https://evil.com/a.png'), '');
      expect(LivemeRoomParser.image(3), '');
      expect(LivemeRoomParser.image('https://img.esxscloud.com/a.png#f'), '');
    });

    test('the qualities are 原画 and 流畅, best first', () {
      final qualities = LivemeRoomParser.qualities(dataOf(_videoInfo()));
      expect(qualities.map((quality) => quality.qualityId), [
        LivemeEndpoints.sourceQualityId,
        LivemeEndpoints.smoothQualityId,
      ]);
      expect(qualities.map((quality) => quality.label), ['原画', '流畅']);
      expect(qualities.map((quality) => quality.platformOrder), [0, 1]);
    });

    test('the lines are flv then hls, with the media headers and no lease', () {
      final lines = LivemeRoomParser.lines(dataOf(_videoInfo()), LivemeEndpoints.sourceQualityId);
      expect(lines, hasLength(3));
      expect(lines.map((line) => line.lineLabel), ['flv', 'flv#2', 'hls']);
      expect(lines.map((line) => line.format), [LiveStreamFormat.flv, LiveStreamFormat.flv, LiveStreamFormat.hls]);
      expect(lines.every((line) => line.formatSource == LivePlayFormatSource.declared), isTrue);
      expect(lines.every((line) => line.lease == null), isTrue, reason: 'the wsABStime is not enforced');
      expect(lines.first.headers['referer'], LivemeEndpoints.roomUrl(_shortId));
      expect(lines.first.headers['origin'], LivemeEndpoints.origin);
      expect(lines.first.url, _flv);
      expect(lines.last.url, _hls);
      // The smooth quality has its flv lines alone.
      final smooth = LivemeRoomParser.lines(dataOf(_videoInfo()), LivemeEndpoints.smoothQualityId);
      expect(smooth, hasLength(1));
      expect(smooth.single.url, _smoothFlv);
    });

    test('the stored quality ids of the reference name the same qualities', () {
      expect(LivemeEndpoints.qualityIdFromLegacy('source-flv'), LivemeEndpoints.sourceQualityId);
      expect(LivemeEndpoints.qualityIdFromLegacy('HLS'), LivemeEndpoints.sourceQualityId);
      expect(LivemeEndpoints.qualityIdFromLegacy('smooth-FLV'), LivemeEndpoints.smoothQualityId);
      final lines = LivemeRoomParser.lines(dataOf(_videoInfo()), 'source-flv');
      expect(lines, hasLength(3));
    });

    test('a broadcast that cannot play says why, a quality it lacks too', () {
      expect(
        () => LivemeRoomParser.qualities(
          LivemeRoomData(
            shortId: _shortId,
            userId: _userId,
            state: LivemeState.live,
            restriction: LiveRestriction.paid,
          ),
        ),
        throwsA(predicate((e) => '$e'.contains('restricted (paid)'))),
      );
      expect(
        () =>
            LivemeRoomParser.qualities(LivemeRoomData(shortId: _shortId, userId: _userId, state: LivemeState.offline)),
        throwsA(predicate((e) => '$e'.contains('is offline'))),
      );
      expect(
        () => LivemeRoomParser.qualities(LivemeRoomData(shortId: _shortId, userId: _userId, state: LivemeState.live)),
        throwsA(predicate((e) => '$e'.contains('no media URL'))),
      );
      expect(
        () => LivemeRoomParser.lines(
          dataOf(_videoInfo(videosource: '', videosourcemore: '', hlsvideosource: '')),
          'source',
        ),
        throwsA(predicate((e) => '$e'.contains('not offered'))),
      );
      expect(
        () => LivemeRoomParser.lines(dataOf(_videoInfo()), 'bogus'),
        throwsA(predicate((e) => '$e'.contains('not offered'))),
      );
      expect(LivemeRoomParser.restricted(_shortId, LiveRestriction.none), isNull);
      expect(LivemeRoomParser.restricted(_shortId, null), isNull);
      expect(LivemeRoomParser.restricted(_shortId, LiveRestriction.private), isA<LivemeFailure>());
    });
  });

  group('adapter wiring', () {
    test('the manifest and the five capabilities the platform can serve', () async {
      final adapter = _adapter();
      final site = adapter.site;
      expect(site.manifest.id, 'liveme');
      expect(site.runtimeInfo.status, LiveSiteStatus.ready);
      await site.initialize(
        const LiveSiteContext(platform: LiveTargetPlatform.windows, locale: 'zh-CN', defaultLocale: 'en-US'),
      );
      expect(site.capability<LiveRoomProvider>(), isNotNull);
      expect(site.capability<LiveDiscoveryProvider>(), isNotNull);
      expect(site.capability<LiveSearchProvider>(), isNotNull);
      expect(site.capability<LivePlaybackProvider>(), isNotNull);
      expect(site.capability<LiveLinkResolver>(), isNotNull);
      expect(site.capability<LiveAreaProvider>(), isNull, reason: 'LiveMe has no categories');
      expect(site.capability<LiveDanmakuProvider>(), isNull, reason: 'the reference has no danmaku');
      expect(site.capability<LiveSiteCapability>(), isNull);
      await site.dispose();
    });

    test('the recommendations and the directory are featured pages', () async {
      final adapter = _adapter();
      final page = _right(
        await adapter.site.capability<LiveDiscoveryProvider>()!.getRecommendedRooms(
          request: const LivePageRequest(page: 2, pageSize: 100),
        ),
      );
      final sent = adapter.http.sent.single;
      expect(sent.url.host, LivemeEndpoints.directoryHost);
      expect(sent.url.path, '/live/featurelist');
      expect(sent.url.queryParameters['page_index'], '2');
      expect(sent.url.queryParameters['page_size'], '50', reason: 'the page size is cut to the platform limit');
      expect(sent.url.queryParameters['countryCode'], 'GLOBAL');
      expect(sent.headers['referer'], '${LivemeEndpoints.origin}/livehot');
      expect(page.items.single.roomId, _shortId);
      expect(page.hasMore, isTrue);
      // The directory asks the platform's own page size.
      await adapter.site.capability<LiveRoomProvider>()!.getRooms(const LivePageRequest(page: 3));
      expect(adapter.http.sent.last.url.queryParameters['page_size'], '${LivemeEndpoints.pageSize}');
      expect(adapter.http.sent.last.url.queryParameters['page_index'], '3');
      // A page below 1 is a caller error, without a request.
      final before = adapter.http.sent.length;
      expect(
        _leftOf(await adapter.site.capability<LiveRoomProvider>()!.getRooms(const LivePageRequest(page: 0))),
        isA<LiveSiteInvalidArgument>(),
      );
      expect(adapter.http.sent.length, before);
    });

    test('an entry is the mapping, the profile and the signed broadcast', () async {
      final adapter = _adapter();
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_shortId));
      expect(adapter.http.sent.map((seen) => seen.url.path), [
        '/liveme_ent/v1/user/uid_vid_by_short_id',
        '/user/getinfo',
        '/live/queryinfosimple',
      ]);
      final mapping = adapter.http.sent.first;
      expect(mapping.url.queryParameters['short_id'], _shortId);
      expect(mapping.headers['referer'], LivemeEndpoints.roomUrl(_shortId));
      final post = adapter.http.sent.last;
      expect(post.method, 'POST');
      expect(post.url.path, '/live/queryinfosimple');
      expect(post.url.queryParameters['alias'], 'liveme');
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(post.headers['lm-s-sign'] ?? ''), isTrue);
      final form = Uri.splitQueryString(post.body ?? '');
      expect(form['videoid'], _videoId);
      expect(form['lm_s_id'], LivemeSigner.clientId);
      expect(form['h5'], '1');
      expect(form.keys, containsAll(['_time', 'thirdchannel', 'area', 'vali']));
      // The room is the short id, live, marked with its figures and handles.
      expect(room.roomId, _shortId);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.popularity);
      expect(room.runtime.streamHandle, isA<LivemeRoomData>());
      // The playback reads the entry's stream data without a request.
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      final before = adapter.http.sent.length;
      final qualities = _right(await playback.getQualities(roomId: _shortId));
      expect(qualities, hasLength(2));
      final lines = _right(await playback.getLines(roomId: _shortId));
      expect(lines, hasLength(3));
      expect(adapter.http.sent.length, before, reason: 'the entry already holds the media');
    });

    test('an anchor without a broadcast is offline, and says why it cannot play', () async {
      final adapter = _adapter(
        onSend: (request) => switch (request.url.path) {
          '/liveme_ent/v1/user/uid_vid_by_short_id' => _resp(200, _mappingFixture(vid: '')),
          '/user/getinfo' => _resp(200, _profileFixture()),
          _ => _resp(200, '{}'),
        },
      );
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_shortId));
      expect(adapter.http.sent, hasLength(2), reason: 'the mapping and the profile alone');
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.runtime.streamHandle, isNotNull, reason: 'the entry keeps the empty data');
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      final before = adapter.http.sent.length;
      expect(
        _leftOf(await playback.getQualities(roomId: _shortId)),
        isA<LiveSiteContentUnavailable>().having((left) => '$left', 'text', contains('offline')),
      );
      expect(adapter.http.sent.length, before, reason: 'no request for a room the platform called offline');
    });

    test('a private broadcast is entered live and marked, and its stream refuses', () async {
      final adapter = _adapter(
        onSend: (request) => switch (request.url.path) {
          '/live/queryinfosimple' => _resp(200, _queryinfoFixture(video: _videoInfo(ispvt: 1))),
          _ => _ordinary(request),
        },
      );
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_shortId));
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.restriction, LiveRestriction.private);
      final before = adapter.http.sent.length;
      expect(
        _leftOf(await adapter.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _shortId)),
        isA<LiveSiteContentUnavailable>().having((left) => '$left', 'text', contains('restricted')),
      );
      expect(adapter.http.sent.length, before);
    });

    test('a playback asked without an entry fetches the broadcast, once', () async {
      final adapter = _adapter(
        onSend: (request) => switch (request.url.path) {
          '/live/queryinfosimple' => _resp(
            200,
            _queryinfoFixture(
              video: _videoInfo(videosource: '', videosourcemore: '', hlsvideosource: '', smallsource: ''),
            ),
          ),
          _ => _ordinary(request),
        },
      );
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      expect(
        _leftOf(await playback.getQualities(roomId: _shortId)),
        isA<LiveSiteContentUnavailable>().having((left) => '$left', 'text', contains('no media URL')),
      );
      expect(adapter.http.sent.map((seen) => seen.url.path), [
        '/liveme_ent/v1/user/uid_vid_by_short_id',
        '/live/queryinfosimple',
      ]);
      // A room id that is no short id is refused without a request.
      final before = adapter.http.sent.length;
      expect(_leftOf(await playback.getQualities(roomId: 'not-a-room')), isA<LiveSiteNotFound>());
      expect(adapter.http.sent.length, before);
    });

    test('a search finds the keyword, the short id and the links', () async {
      final adapter = _adapter();
      final search = adapter.site.capability<LiveSearchProvider>()!;
      expect(search.supportedTargets, {LiveSearchTarget.rooms});
      expect(
        _leftOf(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.anchors))),
        isA<LiveSiteUnsupported>(),
      );
      final byKeyword = await search.search(
        const LiveSearchRequest(query: '唱歌', target: LiveSearchTarget.rooms, pageSize: 100),
      );
      expect((_right(byKeyword).items.single as RoomSearchResult).room.roomId, _shortId);
      expect(_right(byKeyword).hasMore, isNull, reason: 'the site does not say');
      final sent = adapter.http.sent.last;
      expect(sent.url.path, '/search/searchKeyword');
      expect(sent.url.queryParameters['keyword'], '唱歌');
      expect(sent.url.queryParameters['page'], '1');
      expect(sent.url.queryParameters['pageSize'], '40', reason: 'the page size is cut to the platform limit');
      // A short id or a room link finds its room, on page 1 only.
      final byShortId = await search.search(const LiveSearchRequest(query: _shortId, target: LiveSearchTarget.rooms));
      expect((_right(byShortId).items.single as RoomSearchResult).room.roomId, _shortId);
      expect(adapter.http.sent, hasLength(4), reason: 'keyword, mapping, profile, broadcast');
      final byLink = await search.search(
        const LiveSearchRequest(
          query: 'https://liveme.com/livehot/streaming/$_shortId',
          target: LiveSearchTarget.rooms,
        ),
      );
      expect(_right(byLink).items, hasLength(1));
      // A share link asks for its short id first.
      final byShare = await search.search(
        const LiveSearchRequest(query: 'https://liveme.com/v/$_videoId', target: LiveSearchTarget.rooms),
      );
      expect((_right(byShare).items.single as RoomSearchResult).room.roomId, _shortId);
      expect(adapter.http.sent.last.url.path, '/live/queryinfosimple');
      // Nothing without a request for the refusals.
      final before = adapter.http.sent.length;
      final longKeyword = 'x' * 257;
      expect(
        _right(await search.search(const LiveSearchRequest(query: _shortId, target: LiveSearchTarget.rooms, page: 2)))
            .items,
        isEmpty,
      );
      expect(
        _right(await search.search(const LiveSearchRequest(query: ' ', target: LiveSearchTarget.rooms))).items,
        isEmpty,
      );
      expect(
        _leftOf(await search.search(LiveSearchRequest(query: longKeyword, target: LiveSearchTarget.rooms))),
        isA<LiveSiteInvalidArgument>(),
      );
      expect(adapter.http.sent.length, before);
    });

    test('a search that finds nothing says so, an unknown room included', () async {
      final adapter = _adapter(
        onSend: (request) => switch (request.url.path) {
          '/liveme_ent/v1/user/uid_vid_by_short_id' => _resp(
            200,
            _mappingFixture(status: 400, msg: 'unknown short id'),
          ),
          _ => _ordinary(request),
        },
      );
      final results = await adapter.site.capability<LiveSearchProvider>()!.search(
        const LiveSearchRequest(query: _shortId, target: LiveSearchTarget.rooms),
      );
      expect(_right(results).items, isEmpty, reason: 'an unknown room finds nothing');
    });

    test('a link is canonicalized; a share or anchor page asks for its room', () async {
      final adapter = _adapter();
      final link = adapter.site.capability<LiveLinkResolver>()!;
      expect(
        _right(await link.resolve(Uri.parse('https://liveme.com/livehot/streaming/$_shortId'))),
        Uri.parse(LivemeEndpoints.roomUrl(_shortId)),
      );
      expect(adapter.http.sent, isEmpty, reason: 'a room page needs no request');
      expect(
        _right(await link.resolve(Uri.parse('https://www.liveme.com/u/$_userId'))),
        Uri.parse(LivemeEndpoints.roomUrl(_shortId)),
      );
      expect(adapter.http.sent.single.url.path, '/user/getinfo');
      expect(
        _right(await link.resolve(Uri.parse('https://liveme.com/m/v/$_videoId/index.html'))).pathSegments.last,
        _shortId,
      );
      expect(adapter.http.sent.last.url.path, '/live/queryinfosimple');
      expect(
        _leftOf(await link.resolve(Uri.parse('https://example.com/livehot/streaming/$_shortId'))),
        isA<LiveSiteUnsupported>(),
      );
      expect(_leftOf(await link.resolve(Uri.parse('https://liveme.com/livehot'))), isA<LiveSiteNotFound>());
    });

    test('a status the gate refuses is mapped at the boundary', () async {
      final refused = _adapter(onSend: (_) => _resp(401, 'nope'));
      expect(
        _leftOf(await refused.site.capability<LiveRoomProvider>()!.getRoom(_shortId)),
        isA<LiveSiteRateLimitError>(),
      );
      final throttled = _adapter(onSend: (_) => _resp(429, 'nope'));
      expect(
        _leftOf(await throttled.site.capability<LiveDiscoveryProvider>()!.getRecommendedRooms()),
        isA<LiveSiteRateLimitError>(),
      );
      final broken = _adapter(onSend: (_) => _resp(200, 'not json'));
      expect(_leftOf(await broken.site.capability<LiveRoomProvider>()!.getRoom(_shortId)), isA<LiveSiteParseError>());
    });

    test('a transport breakdown is a network failure, anything else unexpected', () async {
      final down = _adapter(onSend: (_) => throw const ConnectFailure('refused'));
      expect(_leftOf(await down.site.capability<LiveRoomProvider>()!.getRoom(_shortId)), isA<LiveSiteNetworkError>());
      final odd = _adapter(onSend: (_) => throw StateError('surprise'));
      expect(_leftOf(await odd.site.capability<LiveRoomProvider>()!.getRoom(_shortId)), isA<LiveSiteUnexpectedError>());
    });

    test('an answer about another room or anchor is a parse failure', () async {
      final swapped = _adapter(
        onSend: (request) => switch (request.url.path) {
          '/user/getinfo' => _resp(200, _profileFixture(shortId: _otherShortId)),
          _ => _ordinary(request),
        },
      );
      expect(
        _leftOf(await swapped.site.capability<LiveRoomProvider>()!.getRoom(_shortId)),
        isA<LiveSiteParseError>().having((left) => '$left', 'text', contains('getinfo')),
      );
      final foreign = _adapter(
        onSend: (request) => switch (request.url.path) {
          '/live/queryinfosimple' => _resp(200, _queryinfoFixture(video: _videoInfo(userid: _otherUserId))),
          _ => _ordinary(request),
        },
      );
      expect(
        _leftOf(await foreign.site.capability<LiveRoomProvider>()!.getRoom(_shortId)),
        isA<LiveSiteParseError>().having((left) => '$left', 'text', contains('not the anchor')),
      );
    });
  });
}
