import 'dart:convert';
import 'dart:typed_data';

// The fakes hand back whole records, and a record pattern must name every
// field of the matched value; the field identifications are not redundant.
// ignore_for_file: simplify_variable_pattern

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
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/platforms/weibo/api/weibo_endpoints.dart';
import 'package:live_sites/src/platforms/weibo/api/weibo_http.dart';
import 'package:live_sites/src/platforms/weibo/parsers/weibo_failure.dart';
import 'package:live_sites/src/platforms/weibo/parsers/weibo_json.dart';
import 'package:live_sites/src/platforms/weibo/parsers/weibo_room_parser.dart';
import 'package:live_sites/src/platforms/weibo/weibo_site.dart';
import 'package:test/test.dart';

const String _id = '1022:2321325347923495092258';
const String _otherId = '1042152:0123456789abcdef0123456789abcdef';
const String _flv = 'https://kitty.live.weibo.net/alicdn/1022_2321_wb720avc.flv?t=1';
const String _hls = 'https://kitty.live.weibo.net/alicdn/1022_2321_wb720avc.m3u8?t=1';
const String _replay = 'http://playback.weibo.com/replay/1022_2321_wb1080avc_index.m3u8';

/// A live start in epoch milliseconds (late September 2026).
const int _startMs = 1790733600000;

String _json(Object? data) => jsonEncode(data);

LiveResponse _resp(int status, String body, {Map<String, String> headers = const {}}) =>
    LiveResponse(statusCode: status, headers: headers, bodyBytes: Uint8List.fromList(utf8.encode(body)));

/// The envelope both endpoints answer with.
String _envelope(Object? data, {int code = 100000, int err = 0, Object? msg}) =>
    _json({'code': code, 'error_code': err, 'msg': ?msg, 'data': ?data});

/// `show_pc_live`'s answer.
String _detailFixture({
  int code = 100000,
  int err = 0,
  Object? msg,
  Object? liveId = _id,
  Object? uid = 9001,
  Object? status = 1,
  Object? watchLimit = 0,
  Object? playSwitch = 1,
  Object? title = '晚间弹唱',
  Object? nick = '主播甲',
  Object? avatar = 'https://img.weibo.com/a1024.jpg',
  Object? profile = 'https://img.weibo.com/a50.jpg',
  Object? cover = 'https://img.weibo.com/cover.jpg',
  Object? flv = _flv,
  Object? hls,
  Object? replayUrl,
  Object? startTime = _startMs,
  Object? dialog,
}) => _envelope(
  {
    'liveId': ?liveId,
    'status': ?status,
    'watch_limit': ?watchLimit,
    'play_switch': ?playSwitch,
    'title': ?title,
    'cover': ?cover,
    'startTime': ?startTime,
    'live_origin_flv_url': ?flv,
    'live_origin_hls_url': ?hls,
    'replay_origin_url': ?replayUrl,
    'pay_dialog_info': ?dialog,
    'user': {'uid': ?uid, 'screenName': ?nick, 'avatar': ?avatar, 'profileImageUrl': ?profile},
  },
  code: code,
  err: err,
  msg: msg,
);

/// A snapshot row.
Map<String, Object?> _row({String id = _id, Object? nick = '主播甲', Object? uid = 9001}) => {
  'liveid': id,
  'nickname': ?nick,
  'uid': ?uid,
  'cover': 'https://img.weibo.com/cover.jpg',
};

/// `pc_recommend/list.json`'s answer.
String _recommendFixture({Object? rows}) => _envelope({'data': ?rows});

final class _Seen {
  new(LiveRequest request) : url = request.url, site = request.site, headers = request.headers;
  final Uri url;
  final String? site;
  final Map<String, String> headers;
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

/// The site over a fake transport.
({WeiboSite site, _FakeHttp http}) _adapter({LiveResponse Function(_Seen request)? onSend}) {
  final http = _FakeHttp(onSend ?? _ordinary);
  return (site: WeiboSite(http: WeiboHttp(http)), http: http);
}

/// The answers of the site: the snapshot and one live broadcast.
LiveResponse _ordinary(_Seen request) {
  final path = request.url.path;
  if (path == WeiboEndpoints.recommendPath) return _resp(200, _recommendFixture(rows: [_row()]));
  if (path == WeiboEndpoints.detailPath) return _resp(200, _detailFixture());
  return _resp(404, 'nope');
}

/// The site with per-path answers scripted; every asked path is remembered.
({WeiboSite site, _FakeHttp http, List<String> asked}) _scripted(String? Function(String path) answer) {
  final asked = <String>[];
  final (site: site, http: http) = _adapter(
    onSend: (request) {
      asked.add(request.url.path);
      final body = answer(request.url.path);
      return body == null ? _ordinary(request) : _resp(200, body);
    },
  );
  return (site: site, http: http, asked: asked);
}

T _right<T>(Either<LiveSiteError, T> either) => either.match((left) => throw StateError('$left'), (right) => right);

LiveSiteError _leftOf<T>(Either<LiveSiteError, T> either) =>
    either.match((left) => left, (right) => throw StateError('not a left: $either'));

/// A site error's type, for the gate checks.
Matcher failureKind(WeiboFailureKind kind) => isA<WeiboFailure>().having((failure) => failure.kind, 'kind', kind);

void main() {
  group('envelope and gates', () {
    test('a status says what kind of answer it is', () {
      void expectKind(int status, WeiboFailureKind kind) {
        try {
          WeiboJson.checkStatus(status, 'x');
          fail('no throw for $status');
        } on WeiboFailure catch (failure) {
          expect(failure.kind, kind);
        }
      }

      expectKind(401, WeiboFailureKind.riskControl);
      expectKind(403, WeiboFailureKind.riskControl);
      expectKind(404, WeiboFailureKind.notFound);
      expectKind(429, WeiboFailureKind.rateLimited);
      for (final status in [302, 500, 503]) {
        expectKind(status, WeiboFailureKind.network);
      }
      WeiboJson.checkStatus(200, 'x');
    });

    test('a good answer is the data object', () {
      expect(WeiboJson.data('{"code":100000,"error_code":0,"data":{"a":1}}', what: 'w'), {'a': 1});
    });

    test('an oversize answer fails without being parsed', () {
      final big = '{"code":100000,"error_code":0,"data":{"a":"${'x' * 1100000}"}}';
      expect(
        () => WeiboJson.data(big, what: 'w'),
        throwsA(predicate((failure) => '$failure'.contains('answer over'), 'names the size gate')),
      );
    });

    test('broken envelopes are api-changed', () {
      for (final body in [
        '<html>', // not JSON
        '[1,2]', // not an object
        '{"error_code":0,"data":{}}', // no code
        '{"code":100000,"data":{}}', // no error_code
        '{"code":"x","error_code":0,"data":{}}', // code not an int
        '{"code":-1,"error_code":0,"data":{}}', // code negative
        '{"code":200,"error_code":0,"data":{}}', // code but not 100000
        '{"code":100000,"error_code":2,"data":{}}', // error_code but not 0
        '{"code":100000,"error_code":0}', // no data
        '{"code":100000,"error_code":0,"data":[]}', // data not an object
      ]) {
        expect(() => WeiboJson.data(body, what: 'w'), throwsA(failureKind(WeiboFailureKind.apiChanged)), reason: body);
      }
    });

    test('the missing code is not-found on the detail only', () {
      const missing = '{"code":100000,"error_code":27401,"msg":"LiveRoom does not exists!","data":{}}';
      expect(
        () => WeiboJson.data(missing, what: 'show_pc_live', missing: true),
        throwsA(failureKind(WeiboFailureKind.notFound)),
      );
      expect(
        () => WeiboJson.data(missing, what: 'show_pc_live', missing: true),
        throwsA(predicate((failure) => '$failure'.contains('LiveRoom does not exists!'))),
      );
      // Without the missing gate it is the ordinary api-changed.
      expect(() => WeiboJson.data(missing, what: 'w'), throwsA(failureKind(WeiboFailureKind.apiChanged)));
    });

    test('failures map to the Either-side errors and name the transient kinds', () {
      expect(const WeiboFailure(WeiboFailureKind.notFound, 'no').toLiveSiteError('weibo'), isA<LiveSiteNotFound>());
      expect(
        const WeiboFailure(WeiboFailureKind.apiChanged, 'bad').toLiveSiteError('weibo'),
        isA<LiveSiteParseError>(),
      );
      expect(
        const WeiboFailure(WeiboFailureKind.network, 'down').toLiveSiteError('weibo'),
        isA<LiveSiteNetworkError>(),
      );
      expect(
        const WeiboFailure(WeiboFailureKind.riskControl, 'refused').toLiveSiteError('weibo'),
        isA<LiveSiteRateLimitError>(),
      );
      expect(
        const WeiboFailure(WeiboFailureKind.rateLimited, 'slow').toLiveSiteError('weibo'),
        isA<LiveSiteRateLimitError>(),
      );
      expect(
        const WeiboFailure(WeiboFailureKind.streamUnavailable, 'dark').toLiveSiteError('weibo'),
        isA<LiveSiteContentUnavailable>(),
      );
      expect(
        const WeiboFailure(WeiboFailureKind.invalidArgument, 'no').toLiveSiteError('weibo'),
        isA<LiveSiteInvalidArgument>(),
      );
      expect(const WeiboFailure(WeiboFailureKind.network, 'down').isTransient, isTrue);
      expect(const WeiboFailure(WeiboFailureKind.rateLimited, 'slow').isTransient, isTrue);
      for (final kind in [
        WeiboFailureKind.notFound,
        WeiboFailureKind.apiChanged,
        WeiboFailureKind.riskControl,
        WeiboFailureKind.streamUnavailable,
        WeiboFailureKind.invalidArgument,
      ]) {
        expect(WeiboFailure(kind, 'x').isTransient, isFalse, reason: kind.name);
      }
    });
  });

  group('the snapshot', () {
    test('rows become live cards with the scope notice and decoded nicknames', () {
      final rooms = WeiboRoomParser.snapshot(_recommendFixture(rows: [_row(nick: '甲 &amp; 乙 &#65;')]));
      expect(rooms.single.roomId, _id);
      expect(rooms.single.content.title, '甲 & 乙 A');
      expect(rooms.single.content.notice, WeiboEndpoints.roomScopeNotice);
      expect(rooms.single.anchor?.anchorId, '9001');
      expect(rooms.single.content.coverUrl, 'https://img.weibo.com/cover.jpg');
      expect(rooms.single.broadcast.liveStatus, LiveStatus.live);
      expect(rooms.single.broadcast.restriction, isNull, reason: 'the snapshot does not tell restrictions');
      expect(rooms.single.links.webUrl, 'https://weibo.com/l/wblive/p/show/$_id');
    });

    test('bad rows are skipped and a broadcast listed twice comes once', () {
      final rooms = WeiboRoomParser.snapshot(
        _recommendFixture(
          rows: <Object?>[
            'not a row',
            {'liveid': 1022}, // no string id
            {'liveid': 'no id'}, // no id shape
            {'liveid': _id, 'nickname': '甲', 'uid': 'not-an-int'}, // the uid leaves the anchor out
            {'liveid': _id}, // a repeat
            {'liveid': _otherId, 'nickname': 7}, // a nickname that is no string
          ],
        ),
      );
      expect(rooms.map((room) => room.roomId), [_id, _otherId]);
      expect(rooms.first.anchor, isNull);
      expect(rooms.first.content.title, '甲');
      expect(rooms.last.content.title, '');
    });

    test('an empty list is an empty page, but rows with none usable are api-changed', () {
      expect(WeiboRoomParser.snapshot(_recommendFixture(rows: [])), isEmpty);
      expect(
        () => WeiboRoomParser.snapshot(
          _recommendFixture(
            rows: [
              'x',
              {'liveid': 'bad'},
            ],
          ),
        ),
        throwsA(failureKind(WeiboFailureKind.apiChanged)),
      );
    });

    test('a list that is not a list or longer than 500 is api-changed', () {
      expect(
        () => WeiboRoomParser.snapshot(_recommendFixture(rows: 'data')),
        throwsA(failureKind(WeiboFailureKind.apiChanged)),
      );
      final many = List.generate(501, (i) => _row(id: '1022:${'a' * 16}$i'));
      expect(
        () => WeiboRoomParser.snapshot(_recommendFixture(rows: many)),
        throwsA(failureKind(WeiboFailureKind.apiChanged)),
      );
    });

    test('page 1 asks once, page 2 is empty without a request', () async {
      final (site: site, http: http) = _adapter();
      final discovery = site.capability<LiveDiscoveryProvider>()!;
      final rooms = _right(await discovery.getRecommendedRooms()).items;
      expect(rooms.single.roomId, _id);
      expect(http.sent, hasLength(1));
      expect(http.sent.single.url.query, 'count=100&uid=');
      final second = _right(await discovery.getRecommendedRooms(request: const LivePageRequest(page: 2)));
      expect(second.items, isEmpty);
      expect(second.hasMore, isFalse);
      expect(http.sent, hasLength(1), reason: 'page 2 costs no request');
    });

    test('a page below 1 is a caller error without a request', () async {
      final (site: site, http: http) = _adapter();
      final discovery = site.capability<LiveDiscoveryProvider>()!;
      expect(
        _leftOf(await discovery.getRecommendedRooms(request: const LivePageRequest(page: 0))),
        isA<LiveSiteInvalidArgument>(),
      );
      expect(http.sent, isEmpty);
    });
  });

  group('the room detail', () {
    LiveRoom parsed({int status = 1, int limit = 0, int play = 1, Object? flv = _flv, Object? replayUrl}) =>
        WeiboRoomParser.detail(
          _detailFixture(status: status, watchLimit: limit, playSwitch: play, flv: flv, replayUrl: replayUrl),
          liveId: _id,
        );

    WeiboRoomData dataOf(LiveRoom room) => room.runtime.streamHandle! as WeiboRoomData;

    test('a live broadcast plays with its URLs, start and pictures', () {
      final room = WeiboRoomParser.detail(_detailFixture(hls: _flv), liveId: _id);
      expect(room.roomId, _id);
      expect(room.anchor?.anchorId, '9001');
      expect(room.anchor?.name, '主播甲');
      expect(room.anchor?.avatarUrl, 'https://img.weibo.com/a1024.jpg', reason: 'the 1024 avatar comes first');
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(_startMs, isUtc: true));
      expect(room.broadcast.restriction, LiveRestriction.none);
      expect(room.content.title, '晚间弹唱');
      expect(room.content.notice, WeiboEndpoints.roomScopeNotice);
      expect(dataOf(room).mediaUrls, [_flv], reason: 'the HLS field repeating the FLV is deduped');
      expect(dataOf(room).ownerId, 9001);
      expect(room.links.webUrl, 'https://weibo.com/l/wblive/p/show/$_id');
    });

    test('a missing avatar falls back to the profile picture', () {
      final room = WeiboRoomParser.detail(_detailFixture(avatar: null, profile: '//img.weibo.com/p.jpg'), liveId: _id);
      expect(room.anchor?.avatarUrl, 'https://img.weibo.com/p.jpg');
    });

    test('the states map 1 to live, 3 to replay, 5 to offline and the rest to unknown', () {
      expect(parsed().broadcast.liveStatus, LiveStatus.live);
      expect(parsed(status: 3, flv: null, replayUrl: _replay).broadcast.liveStatus, LiveStatus.replay);
      expect(parsed(status: 5, flv: null).broadcast.liveStatus, LiveStatus.offline);
      expect(parsed(status: 0, flv: null).broadcast.liveStatus, LiveStatus.unknown);
      expect(parsed(status: 9, flv: null).broadcast.liveStatus, LiveStatus.unknown);
    });

    test('the watch limits name the restriction', () {
      expect(parsed(limit: 8).broadcast.restriction, LiveRestriction.appOnly);
      expect(parsed(limit: 10).broadcast.restriction, LiveRestriction.private);
      expect(parsed(limit: 11).broadcast.restriction, LiveRestriction.private);
      expect(parsed(limit: 12).broadcast.restriction, LiveRestriction.paid);
      expect(parsed(limit: 9).broadcast.restriction, LiveRestriction.unplayable, reason: 'a limit not on record');
      expect(parsed(limit: 77).broadcast.restriction, LiveRestriction.unplayable);
    });

    test('a restricted broadcast reads no URLs, names its kind and carries the tip', () {
      final room = WeiboRoomParser.detail(
        _detailFixture(watchLimit: 10, dialog: {'buy_tip': '本场直播只有主播的好友可观看'}),
        liveId: _id,
      );
      expect(dataOf(room).mediaUrls, isEmpty, reason: 'only a public live broadcast reads its URLs');
      expect(dataOf(room).tip, '本场直播只有主播的好友可观看');
      expect(room.content.notice, '${WeiboEndpoints.restrictedNotice}\n${WeiboEndpoints.roomScopeNotice}');
      final error = WeiboRoomParser.unplayable(dataOf(room))!;
      expect(error.kind, WeiboFailureKind.streamUnavailable);
      expect(error.message, contains('restricted broadcast (private, watch_limit 10)'));
      expect(error.message, contains('本场直播只有主播的好友可观看'));
    });

    test('play_switch 0 is switched off', () {
      final room = parsed(play: 0);
      expect(room.broadcast.restriction, LiveRestriction.unplayable);
      expect(room.content.notice, contains(WeiboEndpoints.disabledNotice));
      expect(WeiboRoomParser.unplayable(dataOf(room))!.message, contains('play_switch 0'));
    });

    test('public without a URL is unplayable, other states give no restriction', () {
      expect(parsed(flv: null).broadcast.restriction, LiveRestriction.unplayable);
      expect(parsed(status: 3, flv: null).broadcast.restriction, LiveRestriction.unplayable);
      expect(parsed(status: 3, flv: null, replayUrl: _replay).broadcast.restriction, LiveRestriction.none);
      expect(parsed(status: 5, flv: null).broadcast.restriction, isNull);
      expect(parsed(status: 0, flv: null).broadcast.restriction, isNull);
      expect(
        WeiboRoomParser.unplayable(dataOf(parsed(status: 5, flv: null)))!.message,
        contains('the broadcast has ended'),
      );
      expect(
        WeiboRoomParser.unplayable(dataOf(parsed(status: 3, flv: null)))!.message,
        contains('an ended broadcast without a replay'),
      );
    });

    test('media URLs are strict and the replay is made https', () {
      for (final value in [
        'http:// a.flv',
        r'http://\a.flv',
        'ftp://host/a.flv',
        'http://user@host/a.flv',
        'http://host/a.flv#x',
        '',
      ]) {
        expect(WeiboJson.mediaUrl(value), isNull, reason: value);
      }
      expect(WeiboJson.mediaUrl('http://host/a.flv'), 'http://host/a.flv');
      expect(WeiboJson.replayUrl('http://host/a.m3u8'), 'https://host/a.m3u8');
      expect(WeiboJson.replayUrl('https://host/a.m3u8'), 'https://host/a.m3u8');
      expect(WeiboJson.replayUrl('nonsense'), isNull);
      final room = parsed(status: 3, flv: null, replayUrl: _replay);
      expect(dataOf(room).replayUrl, 'https://playback.weibo.com/replay/1022_2321_wb1080avc_index.m3u8');
    });

    test('a bad media URL only drops that line', () {
      final room = WeiboRoomParser.detail(
        _detailFixture(flv: 'ftp://nope/a.flv', hls: 'https://host/alicdn/real_wb720avc.flv'),
        liveId: _id,
      );
      expect(dataOf(room).mediaUrls, ['https://host/alicdn/real_wb720avc.flv']);
    });

    test('start times out of bounds are no time', () {
      expect(WeiboJson.startedAt(0), isNull);
      expect(WeiboJson.startedAt(999999999999), isNull, reason: 'before 2001');
      expect(WeiboJson.startedAt(10000000000000), isNull, reason: '2286 and after');
      expect(WeiboJson.startedAt('1790733600000'), isNull, reason: 'a string is no time');
      expect(WeiboJson.startedAt(_startMs), DateTime.fromMillisecondsSinceEpoch(_startMs, isUtc: true));
      expect(
        parsed(status: 3, flv: null, replayUrl: _replay).broadcast.startedAt,
        isNull,
        reason: 'read while live only',
      );
    });

    test('the answer must be the asked broadcast, of the asked anchor', () {
      expect(
        () => WeiboRoomParser.detail(_detailFixture(liveId: _otherId), liveId: _id),
        throwsA(failureKind(WeiboFailureKind.apiChanged)),
      );
      expect(
        () => WeiboRoomParser.detail(_detailFixture(), liveId: _id, ownerId: 9002),
        throwsA(predicate((failure) => '$failure'.contains('9001, not of 9002'))),
      );
      for (final body in [
        _detailFixture(liveId: 'x'),
        _detailFixture(uid: 0),
        _detailFixture(uid: null),
        _detailFixture(status: null),
        _detailFixture(status: 'x'),
        _detailFixture(watchLimit: -1),
        _detailFixture(playSwitch: 2),
        _detailFixture(playSwitch: null),
      ]) {
        expect(
          () => WeiboRoomParser.detail(body, liveId: _id),
          throwsA(failureKind(WeiboFailureKind.apiChanged)),
          reason: body,
        );
      }
      // Fields the parser does not use are not checked; a cover that is no
      // string only leaves it empty (18-8).
      expect(WeiboRoomParser.detail(_detailFixture(cover: 3), liveId: _id).content.coverUrl, '');
    });

    test('the missing code is not-found through the capability', () async {
      final (site: site, http: http) = _adapter(
        onSend: (_) => _resp(200, _detailFixture(err: 27401, msg: 'LiveRoom does not exists!')),
      );
      expect(_leftOf(await site.capability<LiveRoomProvider>()!.getRoom(_id)), isA<LiveSiteNotFound>());
      expect(http.sent.single.url.query, 'live_id=1022%3A2321325347923495092258', reason: 'the id is query-encoded');
    });

    test('an id that is no broadcast id is not-found without a request', () async {
      final (site: site, http: http) = _adapter();
      expect(_leftOf(await site.capability<LiveRoomProvider>()!.getRoom('1022:short')), isA<LiveSiteNotFound>());
      expect(
        _leftOf(await site.capability<LivePlaybackProvider>()!.getQualities(roomId: 'nonsense')),
        isA<LiveSiteNotFound>(),
      );
      expect(http.sent, isEmpty);
    });

    test('entry and directory answers shape the models', () async {
      final (site: site, http: http) = _adapter();
      final room = _right(await site.capability<LiveRoomProvider>()!.getRoom(_id));
      expect(room.platform, 'weibo');
      expect(room.broadcast.liveStatus, LiveStatus.live);
      final page = _right(await site.capability<LiveRoomProvider>()!.getRooms(const LivePageRequest()));
      expect(page.items.single.roomId, _id);
      expect(page.hasMore, isFalse);
      expect(http.sent, hasLength(2));
      expect(http.sent.every((seen) => seen.site == 'weibo'), isTrue);
      expect(http.sent.every((seen) => seen.headers['referer'] == 'https://weibo.com/l/wblive/'), isTrue);
      expect(http.sent.every((seen) => seen.headers['user-agent'] == 'Mozilla/5.0'), isTrue);
    });
  });

  group('lines', () {
    test('the URL decides format, codec and line label', () {
      final flvLine = WeiboRoomParser.line('https://kitty.live.weibo.net/alicdn/1022_2321_wb720avc.flv?t=1');
      expect(flvLine.format, LiveStreamFormat.flv);
      expect(flvLine.formatSource, LivePlayFormatSource.inferred);
      expect(flvLine.codec, LiveStreamCodec.avc);
      expect(flvLine.lineLabel, 'alicdn');
      expect(flvLine.headers, isEmpty, reason: 'the media requests carry no headers');
      expect(flvLine.lease, isNull, reason: 'the URLs carry no signature or expiry');
      expect(flvLine.singleUse, isFalse);
      expect(WeiboRoomParser.line('https://h.live.weibo.com/x.m3u8').format, LiveStreamFormat.hls);
      expect(WeiboRoomParser.line('https://h.live.weibo.com/x_hevc.m3u8').codec, LiveStreamCodec.hevc);
      expect(WeiboRoomParser.line('https://h.live.weibo.com/x_h265.m3u8').codec, LiveStreamCodec.hevc);
      expect(WeiboRoomParser.line('https://h.live.weibo.com/x.mp4').format, LiveStreamFormat.other);
      expect(WeiboRoomParser.line('https://h.live.weibo.com/x.mp4').codec, isNull);
      expect(WeiboRoomParser.line('https://one.host/name.flv').lineLabel, 'one.host', reason: 'one segment: the host');
    });
  });

  group('links', () {
    test('the watch page names its broadcast', () {
      expect(WeiboEndpoints.liveIdFromUrl('https://weibo.com/l/wblive/p/show/$_id'), _id);
      expect(WeiboEndpoints.liveIdFromUrl('http://www.weibo.com/l/wblive/m/show/$_id/'), _id);
      expect(WeiboEndpoints.liveIdFromUrl('https://weibo.com:443/l/wblive/p/show/$_id'), _id);
      expect(WeiboEndpoints.liveIdFromUrl('https://weibo.com/l/wblive/p/show/$_id?x=1'), _id);
    });

    test('the colon may be escaped once, never twice', () {
      expect(WeiboEndpoints.liveIdFromUrl('https://weibo.com/l/wblive/p/show/1022%3A2321325347923495092258'), _id);
      expect(WeiboEndpoints.liveIdFromUrl('https://weibo.com/l/wblive/p/show/1022%3a2321325347923495092258'), _id);
      expect(WeiboEndpoints.liveIdFromUrl('https://weibo.com/l/wblive/p/show/1022%253A2321325347923495092258'), isNull);
    });

    test('other shapes are no room', () {
      for (final raw in [
        'https://weibo.com/u/9001', // a profile
        'https://weibo.com/l/wblive/p/show/x/$_id', // two segments
        'https://weibo.com/l/wblive/x/show/$_id', // neither p nor m
        'ftp://weibo.com/l/wblive/p/show/$_id', // not http(s)
        'https://user@weibo.com/l/wblive/p/show/$_id', // user info
        'https://weibo.com:8443/l/wblive/p/show/$_id', // a port
        'https://weibo.com/l/wblive/p/show/1022 :2321325347923495092258', // a space
        r'https://weibo.com/l/wblive/p/show/1022\ :2321325347923495092258', // a backslash
        'weibo.com/l/wblive/p/show/$_id', // no scheme
      ]) {
        expect(WeiboEndpoints.liveIdFromUrl(raw), isNull, reason: raw);
      }
    });

    test('the media centre asks exactly one id', () {
      expect(WeiboEndpoints.liveIdFromUrl('https://live.media.weibo.com/live/show?id=$_id'), _id);
      expect(
        WeiboEndpoints.liveIdFromUrl('https://live.media.weibo.com/live/show?id=1022%3A2321325347923495092258'),
        _id,
      );
      expect(WeiboEndpoints.liveIdFromUrl('https://live.media.weibo.com/live/show?id=$_id&id=$_otherId'), isNull);
      expect(WeiboEndpoints.liveIdFromUrl('https://live.media.weibo.com/live/show'), isNull);
      expect(WeiboEndpoints.liveIdFromUrl('https://live.media.weibo.com/other?id=$_id'), isNull);
    });

    test('exactRoom takes ids and links, never texts with spaces', () {
      expect(WeiboEndpoints.exactRoom(_id), _id);
      expect(WeiboEndpoints.exactRoom(' https://weibo.com/l/wblive/p/show/$_id '), _id);
      expect(WeiboEndpoints.exactRoom('hello world'), isNull);
      expect(
        WeiboEndpoints.exactRoom('weibo.com/l/wblive/p/show/$_id'),
        isNull,
        reason: 'a scheme-less link is no room',
      );
    });

    test('short links are t.cn codes on https', () {
      expect(WeiboEndpoints.shortLink('https://t.cn/A6J8Y0lY'), Uri.https('t.cn', '/A6J8Y0lY'));
      expect(WeiboEndpoints.shortLink('http://t.cn/A6J8Y0lY/'), Uri.https('t.cn', '/A6J8Y0lY'), reason: 'over https');
      expect(
        WeiboEndpoints.shortLink('https://t.cn/A6J8Y0lY?x=1#f'),
        Uri.https('t.cn', '/A6J8Y0lY'),
        reason: 'query and fragment dropped',
      );
      expect(WeiboEndpoints.shortLink('https://t.cn/abc'), isNull, reason: 'short of four characters');
      expect(WeiboEndpoints.shortLink('https://t.cn/a/b'), isNull);
      expect(WeiboEndpoints.shortLink('https://t.cn:8443/A6J8Y0lY'), isNull);
    });

    test('the resolver canonicalizes room links without a request', () async {
      final (site: site, http: http) = _adapter();
      final link = site.capability<LiveLinkResolver>()!;
      final fromPath = _right(
        await link.resolve(Uri.parse('http://www.weibo.com/l/wblive/m/show/1022%3A2321325347923495092258')),
      );
      expect('$fromPath', 'https://weibo.com/l/wblive/p/show/$_id');
      final fromCentre = _right(await link.resolve(Uri.parse('https://live.media.weibo.com/live/show?id=$_id')));
      expect('$fromCentre', 'https://weibo.com/l/wblive/p/show/$_id');
      expect(http.sent, isEmpty);
      expect(_leftOf(await link.resolve(Uri.parse('https://weibo.com/u/9001'))), isA<LiveSiteNotFound>());
      expect(_leftOf(await link.resolve(Uri.parse('https://live.douyin.com/12345'))), isA<LiveSiteUnsupported>());
    });

    test('a t.cn hop leads to the room, to sorry, or nowhere', () async {
      Future<LiveSiteError?> via(String body, {int status = 200, Map<String, String> headers = const {}}) async {
        final (site: site, http: _) = _adapter(
          onSend: (request) {
            if (request.url.path == WeiboEndpoints.detailPath) return _resp(200, _detailFixture());
            return _resp(status, body, headers: headers);
          },
        );
        final result = await site.capability<LiveLinkResolver>()!.resolve(Uri.parse('https://t.cn/A6J8Y0lY'));
        return result.match<LiveSiteError?>((left) => left, (right) {
          expect('$right', 'https://weibo.com/l/wblive/p/show/$_id');
          return null;
        });
      }

      expect(
        await via('', status: 302, headers: {'location': 'https://weibo.com/l/wblive/p/show/$_id'}),
        isNull,
        reason: 'the redirect names a room',
      );
      expect(await via('', status: 302, headers: {'location': 'http://weibo.com/sorry'}), isA<LiveSiteNotFound>());
      expect(await via('', status: 302, headers: {'location': 'https://live.douyin.com/123'}), isA<LiveSiteNotFound>());
      expect(await via('<html>landed</html>'), isA<LiveSiteNotFound>(), reason: 'an answer without a redirect');
      expect(await via('nope', status: 404), isA<LiveSiteNotFound>(), reason: 'HTTP 404 is no room');
    });

    test('a t.cn answer with another status fails as the status gate says', () async {
      final (site: site, http: http) = _adapter(onSend: (_) => _resp(429, ''));
      final error = _leftOf(await site.capability<LiveLinkResolver>()!.resolve(Uri.parse('https://t.cn/A6J8Y0lY')));
      expect(error, isA<LiveSiteRateLimitError>());
      expect(http.sent, hasLength(1));
    });
  });

  group('search', () {
    test('a broadcast id or room link finds that room', () async {
      final (site: site, http: http) = _adapter();
      final search = site.capability<LiveSearchProvider>()!;
      final byId = _right(await search.search(const LiveSearchRequest(query: _id, target: LiveSearchTarget.rooms)));
      expect(byId.items, hasLength(1));
      expect(byId.hasMore, isFalse);
      final byLink = _right(
        await search.search(
          const LiveSearchRequest(
            query: 'https://weibo.com/l/wblive/p/show/1022%3A2321325347923495092258',
            target: LiveSearchTarget.rooms,
          ),
        ),
      );
      expect(byLink.items, hasLength(1));
      expect(http.sent.map((seen) => seen.url.path), [WeiboEndpoints.detailPath, WeiboEndpoints.detailPath]);
    });

    test('a missing broadcast finds nothing', () async {
      final (site: site, http: http) = _adapter(
        onSend: (request) => request.url.path == WeiboEndpoints.detailPath
            ? _resp(200, _detailFixture(err: 27401, msg: 'LiveRoom does not exists!'))
            : _resp(200, _recommendFixture(rows: [])),
      );
      final result = _right(
        await site.capability<LiveSearchProvider>()!.search(
          const LiveSearchRequest(query: _id, target: LiveSearchTarget.rooms),
        ),
      );
      expect(result.items, isEmpty);
      expect(http.sent, hasLength(1), reason: 'the detail asked once; no snapshot after the miss');
    });

    test('a t.cn keyword is followed once, then the room is asked', () async {
      final (site: site, http: http) = _adapter(
        onSend: (request) {
          if (request.url.host == 't.cn') {
            return _resp(302, '', headers: {'location': 'https://weibo.com/l/wblive/p/show/$_id'});
          }
          if (request.url.path == WeiboEndpoints.detailPath) return _resp(200, _detailFixture());
          return _resp(404, 'must not ask the snapshot');
        },
      );
      final result = _right(
        await site.capability<LiveSearchProvider>()!.search(
          const LiveSearchRequest(query: 'https://t.cn/A6J8Y0lY', target: LiveSearchTarget.rooms),
        ),
      );
      expect(result.items, hasLength(1));
      expect(http.sent.map((seen) => seen.url.host), ['t.cn', 'weibo.com']);
    });

    test('a t.cn that leads elsewhere finds nothing, without asking the snapshot', () async {
      final (site: site, http: http) = _adapter(
        onSend: (request) {
          if (request.url.host == 't.cn') return _resp(302, '', headers: {'location': 'http://weibo.com/sorry'});
          return _resp(404, 'must not ask anything else');
        },
      );
      final result = _right(
        await site.capability<LiveSearchProvider>()!.search(
          const LiveSearchRequest(query: 'https://t.cn/A6J8Y0lY', target: LiveSearchTarget.rooms),
        ),
      );
      expect(result.items, isEmpty);
      expect(http.sent, hasLength(1));
    });

    test('other links and blanks find nothing, without a request', () async {
      final (site: site, http: http) = _adapter();
      final search = site.capability<LiveSearchProvider>()!;
      for (final query in ['https://example.com/x', '', '   ', 'https://weibo.com/u/9001']) {
        final result = _right(await search.search(LiveSearchRequest(query: query, target: LiveSearchTarget.rooms)));
        expect(result.items, isEmpty, reason: query);
      }
      expect(http.sent, isEmpty);
    });

    test('a keyword filters the snapshot by nickname, case ignored, page 1 only', () async {
      final (site: site, http: http) = _adapter(
        onSend: (_) => _resp(
          200,
          _recommendFixture(
            rows: [
              _row(nick: 'Alpha 甲'),
              _row(id: _otherId, nick: 'beta 乙'),
            ],
          ),
        ),
      );
      final search = site.capability<LiveSearchProvider>()!;
      final found = _right(
        await search.search(const LiveSearchRequest(query: ' ALPHA ', target: LiveSearchTarget.rooms)),
      );
      expect(found.items, hasLength(1));
      expect(found.hasMore, isFalse);
      final page2 = _right(
        await search.search(const LiveSearchRequest(query: 'alpha', target: LiveSearchTarget.rooms, page: 2)),
      );
      expect(page2.items, isEmpty);
      final cut = _right(
        await search.search(const LiveSearchRequest(query: '甲', target: LiveSearchTarget.rooms, pageSize: 1)),
      );
      expect(cut.items, hasLength(1));
      expect(http.sent.where((seen) => seen.url.path == WeiboEndpoints.recommendPath), isNotEmpty);
    });

    test('out-of-bounds pages and sizes are caller errors without a request', () async {
      final (site: site, http: http) = _adapter();
      final search = site.capability<LiveSearchProvider>()!;
      for (final request in [
        const LiveSearchRequest(query: '甲', target: LiveSearchTarget.rooms, page: 0),
        const LiveSearchRequest(query: '甲', target: LiveSearchTarget.rooms, pageSize: 0),
        const LiveSearchRequest(query: '甲', target: LiveSearchTarget.rooms, pageSize: 1001),
      ]) {
        expect(
          _leftOf(await search.search(request)),
          isA<LiveSiteInvalidArgument>(),
          reason: '${request.page}/${request.pageSize}',
        );
      }
      expect(
        _leftOf(await search.search(const LiveSearchRequest(query: '甲', target: LiveSearchTarget.areas))),
        isA<LiveSiteUnsupported>(),
      );
      expect(http.sent, isEmpty);
    });
  });

  group('playback', () {
    test('a live quality re-reads the detail and plays the FLV first', () async {
      final (site: site, http: _, asked: asked) = _scripted(
        (path) => path == WeiboEndpoints.detailPath ? _detailFixture(hls: _hls) : null,
      );
      final room = _right(await site.capability<LiveRoomProvider>()!.getRoom(_id));
      final playback = site.capability<LivePlaybackProvider>()!;
      expect(_right(await playback.getQualities(roomId: room.roomId)), [WeiboEndpoints.original]);
      expect(asked, hasLength(1), reason: 'the qualities come from the kept detail, no request');
      final lines = _right(await playback.getLines(roomId: room.roomId, quality: WeiboEndpoints.original));
      expect(lines.map((line) => line.url), [_flv, _hls], reason: 'FLV before HLS');
      expect(lines.first.format, LiveStreamFormat.flv);
      expect(lines.last.format, LiveStreamFormat.hls);
      expect(asked, hasLength(2), reason: 'the live playback asked the detail again, once');
    });

    test('a null quality takes what the broadcast plays', () async {
      final (site: site, http: http, asked: _) = _scripted(
        (path) => path == WeiboEndpoints.detailPath ? _detailFixture(hls: _flv) : null,
      );
      await site.detail(_id);
      final lines = _right(await site.capability<LivePlaybackProvider>()!.getLines(roomId: _id));
      expect(lines.single.url, _flv);
      expect(http.sent, hasLength(2), reason: 'the live default still re-reads the detail');
    });

    test('a live read without a kept detail costs one request', () async {
      final (site: site, http: http, asked: _) = _scripted(
        (path) => path == WeiboEndpoints.detailPath ? _detailFixture(hls: _flv) : null,
      );
      final lines = _right(
        await site.capability<LivePlaybackProvider>()!.getLines(roomId: _id, quality: WeiboEndpoints.original),
      );
      expect(lines.single.url, _flv);
      expect(http.sent, hasLength(1));
    });

    test('the re-read must still be the same anchor', () async {
      var reads = 0;
      final (site: site, http: http, asked: _) = _scripted((path) {
        if (path != WeiboEndpoints.detailPath) return null;
        reads++;
        return reads > 1 ? _detailFixture(uid: 9002) : null;
      });
      await site.detail(_id);
      final error = _leftOf(
        await site.capability<LivePlaybackProvider>()!.getLines(roomId: _id, quality: WeiboEndpoints.original),
      );
      expect(error, isA<LiveSiteParseError>());
      expect(error.message, contains('not of 9001'));
      expect(http.sent, hasLength(2));
    });

    test('a broadcast that ended meanwhile is refused, never silently its replay', () async {
      var reads = 0;
      final (site: site, http: http, asked: _) = _scripted((path) {
        if (path != WeiboEndpoints.detailPath) return null;
        reads++;
        return reads > 1 ? _detailFixture(status: 5, flv: null) : null;
      });
      await site.detail(_id);
      final error = _leftOf(
        await site.capability<LivePlaybackProvider>()!.getLines(roomId: _id, quality: WeiboEndpoints.original),
      );
      expect(error, isA<LiveSiteContentUnavailable>());
      expect(error.message, contains('the broadcast has ended'));
      expect(http.sent, hasLength(2), reason: 'the re-read answered, then the gate refused');
    });

    test('asking the replay of a live broadcast refuses without a request', () async {
      final (site: site, http: http) = _adapter();
      await site.detail(_id);
      final before = http.sent.length;
      final error = _leftOf(
        await site.capability<LivePlaybackProvider>()!.getLines(roomId: _id, quality: WeiboEndpoints.replay),
      );
      expect(error, isA<LiveSiteContentUnavailable>());
      expect(error.message, contains('not a replay'));
      expect(http.sent, hasLength(before));
    });

    test('a replay plays its stored recording without another request', () async {
      final (site: site, http: http, asked: _) = _scripted(
        (path) => path == WeiboEndpoints.detailPath ? _detailFixture(status: 3, flv: null, replayUrl: _replay) : null,
      );
      final room = _right(await site.capability<LiveRoomProvider>()!.getRoom(_id));
      final playback = site.capability<LivePlaybackProvider>()!;
      expect(_right(await playback.getQualities(roomId: room.roomId)), [WeiboEndpoints.replay]);
      final lines = _right(await playback.getLines(roomId: room.roomId, quality: WeiboEndpoints.replay));
      expect(lines.single.url, 'https://playback.weibo.com/replay/1022_2321_wb1080avc_index.m3u8');
      expect(lines.single.format, LiveStreamFormat.hls);
      expect(lines.single.codec, LiveStreamCodec.avc);
      expect(lines.single.lineLabel, 'replay');
      expect(http.sent, hasLength(1), reason: 'the stored replay URL plays; the detail was asked once');
    });

    test('a replay asked without a kept detail reads the detail once', () async {
      final (site: site, http: http, asked: _) = _scripted(
        (path) => path == WeiboEndpoints.detailPath ? _detailFixture(status: 3, flv: null, replayUrl: _replay) : null,
      );
      final lines = _right(
        await site.capability<LivePlaybackProvider>()!.getLines(roomId: _id, quality: WeiboEndpoints.replay),
      );
      expect(lines.single.url, startsWith('https://'));
      expect(http.sent, hasLength(1));
    });

    test('asking the live quality of an ended broadcast names the replay', () async {
      final (site: site, http: http, asked: _) = _scripted(
        (path) => path == WeiboEndpoints.detailPath ? _detailFixture(status: 3, flv: null, replayUrl: _replay) : null,
      );
      final error = _leftOf(
        await site.capability<LivePlaybackProvider>()!.getLines(roomId: _id, quality: WeiboEndpoints.original),
      );
      expect(error, isA<LiveSiteContentUnavailable>());
      expect(error.message, contains('its replay is quality replay'));
      expect(http.sent, hasLength(1), reason: 'the read answers once, then the gate refuses');
    });

    test('restricted, switched-off, unknown and URL-less broadcasts refuse the qualities', () async {
      for (final (fixture, needle) in [
        (_detailFixture(watchLimit: 10), 'restricted broadcast (private, watch_limit 10)'),
        (_detailFixture(playSwitch: 0), 'play_switch 0'),
        (_detailFixture(status: 0, flv: null), 'status 0'),
        (_detailFixture(flv: null), 'live without a media URL'),
      ]) {
        final (site: site, http: http, asked: _) = _scripted(
          (path) => path == WeiboEndpoints.detailPath ? fixture : null,
        );
        await site.detail(_id);
        final error = _leftOf(await site.capability<LivePlaybackProvider>()!.getQualities(roomId: _id));
        expect(error, isA<LiveSiteContentUnavailable>(), reason: needle);
        expect(error.message, contains(needle));
        expect(http.sent, hasLength(1), reason: 'the kept detail answers without a request');
      }
    });

    test('another quality is not offered', () async {
      final (site: site, http: http) = _adapter();
      await site.detail(_id);
      final error = _leftOf(
        await site.capability<LivePlaybackProvider>()!.getLines(
          roomId: _id,
          quality: const LivePlayQuality(label: '高清', qualityId: '720'),
        ),
      );
      expect(error, isA<LiveSiteContentUnavailable>());
      expect(error.message, contains('quality 720 is not offered'));
      expect(http.sent, hasLength(1));
    });
  });

  group('areas and wiring', () {
    test('the one area is 公开推荐 under the platform, without a request', () async {
      final (site: site, http: http) = _adapter();
      final areas = _right(await site.capability<LiveAreaProvider>()!.getAreas());
      expect(areas.single.areaId, 'live');
      expect(areas.single.areaName, '公开推荐');
      expect(areas.single.parentAreaId, 'weibo');
      expect(areas.single.parentAreaName, '微博直播');
      expect(http.sent, isEmpty);
    });

    test('the area holds the snapshot; other areas and pages say so', () async {
      final (site: site, http: http) = _adapter();
      final area = site.capability<LiveAreaProvider>()!;
      final rooms = _right(await area.getAreaRooms(areaId: 'live'));
      expect(rooms.items.single.roomId, _id);
      expect(_leftOf(await area.getAreaRooms(areaId: 'nope')), isA<LiveSiteInvalidArgument>());
      expect(http.sent, hasLength(1));
      final latePage = _right(await area.getAreaRooms(areaId: 'live', request: const LivePageRequest(page: 2)));
      expect(latePage.items, isEmpty);
      expect(latePage.hasMore, isFalse);
      expect(
        _leftOf(await area.getAreaRooms(areaId: 'live', request: const LivePageRequest(page: 0))),
        isA<LiveSiteInvalidArgument>(),
      );
      expect(http.sent, hasLength(1), reason: 'pages beyond the first cost no request');
    });

    test('the site speaks through its manifest and its capabilities', () async {
      final (site: site, http: http) = _adapter();
      expect(site.manifest.id, 'weibo');
      expect(site.manifest.localizedName('zh-CN', 'en-US'), '微博直播');
      expect(site.manifest.localizedName('en-US', 'en-US'), 'Weibo Live');
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
      expect(site.capability<LiveDanmakuProvider>(), isNull, reason: 'the platform has no chat');
      expect(site.capability<LiveSiteCapability>(), isNull, reason: 'a type the site does not offer at all');
      await site.dispose();
      expect(http.closed, isTrue);
    });
  });
}
