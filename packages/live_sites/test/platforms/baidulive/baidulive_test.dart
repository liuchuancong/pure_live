// Test fakes re-create the platform's constructor shapes, whose naming rules
// the public surface's lints govern.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
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
import 'package:live_sites/src/core/live_site_context.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/core/live_site_runtime_info.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/baidulive/api/baidulive_endpoints.dart';
import 'package:live_sites/src/platforms/baidulive/api/baidulive_http.dart';
import 'package:live_sites/src/platforms/baidulive/baidulive_manifest.dart';
import 'package:live_sites/src/platforms/baidulive/baidulive_site.dart';
import 'package:live_sites/src/platforms/baidulive/danmaku/baidulive_danmaku_codec.dart';
import 'package:live_sites/src/platforms/baidulive/parsers/baidulive_failure.dart';
import 'package:live_sites/src/platforms/baidulive/parsers/baidulive_json.dart';
import 'package:live_sites/src/platforms/baidulive/parsers/baidulive_play_parser.dart';
import 'package:live_sites/src/platforms/baidulive/parsers/baidulive_room_parser.dart';
import 'package:test/test.dart';

// The clock every fixed-time assertion reads: 2026-09-30 14:00 UTC.
final DateTime _at = DateTime.parse('2026-09-30T14:00:00.000Z');

const String _roomId = '7530951';
const String _otherRoom = '7530952';
const String _deviceId = 'device-1';

// JSON fixtures ---------------------------------------------------------------

String _json(Object? value) => jsonEncode(value);

/// An `{errno: 0, data: …}` envelope.
String _envelope(Object? data, {int errno = 0, String errmsg = ''}) =>
    _json({'errno': errno, if (errmsg.isNotEmpty) 'errmsg': errmsg, 'data': data});

/// A feed answer of [items], its session and its `tab` block.
String _feedFixture({
  List<Object?> items = const [],
  Object? tab,
  Object? innerErrno = 0,
  Object? sessionId = 'session-1',
  Object? refreshIndex = 1,
}) => _envelope({
  'feed': {'inner_errno': innerErrno, 'items': items, 'session_id': sessionId, 'refresh_index': refreshIndex},
  'tab': ?tab,
});

Map<String, Object?> _tabFixture({int innerErrno = 0, List<Object?> items = const []}) => {
  'inner_errno': innerErrno,
  'items': items,
};

/// A feed card.
Map<String, Object?> _card({
  Object? roomId = _roomId,
  int liveStatus = 1,
  String uk = 'anchor-uk',
  String name = '主播甲',
  Object? avatar = 'https://pic.bdimg.com/a.png',
  Object? title = '晚间聊天',
  Object? cover = 'https://pic.bdimg.com/cover.png',
  Object? liveTag = '闲聊',
  Object? leftLabel,
  Object? audience = 1200,
  Object? hasPayService,
  Object? playUrl,
}) => {
  'room_id': roomId,
  'live_status': liveStatus,
  'host': {'uk': uk, 'name': name, 'avatar': avatar},
  'title': title,
  'cover': cover,
  'live_tag': liveTag,
  'left_label': ?leftLabel,
  'audience_count': audience,
  'has_pay_service': ?hasPayService,
  'play_url': ?playUrl,
};

/// A room command 371 answer whose `data.371` holds [command].
String _roomFixture(Object? command) => _envelope({'371': command});

/// A recording address of the room the platform's replay gate accepts.
String _replayUrl(String name) => 'https://replay.bdstatic.com/replay/2026_09_$_roomId/$name';

/// The media URLs of a live room: the source in AVC (named by
/// `live_hls_url`), a 720p clarity tier in both codecs, a 480p `url_list`
/// tier that also has the platform's current CDN as a backup, and the source
/// in H.265.
Map<String, Object?> _liveVideo() => {
  'title': '晚间聊天',
  'cover': {'cover_100': 'https://pic.bdimg.com/cover.png', 'vertical_cover': 'https://pic.bdimg.com/v.png'},
  'description': '主播的介绍',
  'msg_hls_url': _listUrl('chat'),
  'live_hls_url': 'https://hls-live.bdstatic.com/live/live_$_roomId.m3u8',
  'live_flv_url_origin': 'https://hls-live.bdstatic.com/live/live_$_roomId.flv',
  'hevc_url': 'https://p1.liveshow.bdstatic.com/live/live_$_roomId-hevc.flv',
  'play_url': 'https://p1.liveshow.bdstatic.com/live/live_$_roomId-720.flv',
  'url_clarity_list': [
    {
      'resolution': 720,
      'urls': {
        'avc_flv': 'https://p1.liveshow.bdstatic.com/live/live_$_roomId-720.flv',
        'hls': 'https://p1.liveshow.bdstatic.com/live/live_$_roomId-720/playlist.m3u8',
        'hevc_flv': 'https://p1.liveshow.bdstatic.com/live/live_$_roomId-720-hevc.flv',
      },
    },
  ],
  'url_list': [
    {
      'resolution': 480,
      'urls': [
        {
          'flv': 'https://p2.liveshow.bdstatic.com/live/live_$_roomId-480.flv',
          'hls': 'http://b1.liveshow.lss-user.baidubce.com/live/live_$_roomId-480.m3u8',
        },
      ],
    },
  ],
};

/// A signed message list of [name]: 180 days from 2026-09-30 12:00 UTC, its
/// separators escaped as recorded answers wrote them.
String _listUrl(
  String name, {
  String time = '2026-09-30T12%3A00%3A00Z',
  String seconds = '15552000',
  String scheme = 'https',
  String version = 'bce-auth-v1',
}) =>
    '$scheme://liveshowstatic.baidu.com/msg/$name/$name.m3u8'
    '?authorization=$version%2Fak%2F$time%2F$seconds%2Fhost%2Fsignature';

Map<String, Object?> _liveCommand({int status = 0, Map<String, Object?>? video, Map<String, Object?>? extra}) => {
  'error_code': 0,
  'status': status,
  'share_url': 'https://live.baidu.com/m/room/$_roomId',
  'category': '闲聊',
  'online_users': 1300,
  'create_time': 1727700000,
  'real_fans_num': 42000,
  'host': {
    'uk': 'anchor-uk',
    'nick_name': '主播甲',
    'image': {'image_33': 'https://pic.bdimg.com/a.png'},
    'fans': 41000,
  },
  'video': video ?? _liveVideo(),
  'chat_msg_hls_url': _listUrl('chat'),
  'reliable_msg_hls_url': _listUrl('reliable'),
  'host_msg_hls_url': _listUrl('host'),
  'msg_hls_pull_internal_in_second': 3,
  ...?extra,
};

/// The live room of the full command, as the parser reads it.
BaiduliveRoom _full() => BaiduliveRoomParser.room(_roomFixture(_liveCommand()), expectedRoomId: _roomId);

// Transport and timer fakes ---------------------------------------------------

final class _Seen {
  _Seen(LiveRequest request)
    : method = request.method,
      url = request.url,
      body = request.body,
      headers = request.headers;

  final String method;
  final Uri url;
  final String? body;
  final Map<String, String> headers;

  Map<String, String> get query => url.queryParameters;
  String get path => url.path;
}

final class _FakeHttp implements LiveHttp {
  _FakeHttp(this.onSend);

  final FutureOr<LiveResponse> Function(_Seen request) onSend;
  final List<_Seen> sent = [];

  List<_Seen> get posts => sent.where((seen) => seen.method == 'POST').toList();
  int get requestCount => sent.length;
  int get postCount => posts.length;

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

LiveResponse _resp(int status, Object body) => LiveResponse(
  statusCode: status,
  headers: const {},
  bodyBytes: body is String ? Uint8List.fromList(utf8.encode(body)) : Uint8List.fromList(body as List<int>),
);

/// The website's two answers: the feed POST and the room command GET; 404 for
/// anything else (a message list that is not there).
LiveResponse Function(_Seen) _api({String? feed, String? room}) => (seen) {
  if (seen.method == 'POST') return _resp(200, feed ?? _feedFixture());
  if (seen.path == BaiduliveEndpoints.roomPath) {
    return _resp(200, room ?? _roomFixture(_liveCommand()));
  }
  return _resp(404, 'nothing here');
};

BaiduliveSite _bound({
  String? feed,
  String? room,
  LiveResponse Function(_Seen)? onSend,
  bool? preferH264,
  DateTime Function()? now,
  String? deviceId = _deviceId,
  _FakeHttp? transport,
}) {
  final http = transport ?? _FakeHttp(onSend ?? _api(feed: feed, room: room));
  return BaiduliveSite(
    http: BaiduliveHttp(http),
    now: now ?? () => _at,
    deviceId: deviceId,
    preferH264: preferH264 == null ? null : () => preferH264,
  );
}

T _right<T>(Either<LiveSiteError, T> either) => either.match((left) => throw StateError('$left'), (right) => right);

LiveSiteError _leftOf<T>(Either<LiveSiteError, T> either) =>
    either.match((left) => left, (right) => throw StateError('not a left: $either'));

/// The failures the parsers throw, read straight off an answer.
BaiduliveFailure _roomFailure(String body, {int status = 200, String roomId = _roomId}) {
  try {
    BaiduliveRoomParser.room(body, expectedRoomId: roomId, status: status);
  } on BaiduliveFailure catch (failure) {
    return failure;
  }
  throw StateError('no failure for ${BaiduliveJson.snippet(body)}');
}

BaiduliveFailure _pageFailure(String body, {int status = 200}) {
  try {
    BaiduliveRoomParser.page(body, status: status);
  } on BaiduliveFailure catch (failure) {
    return failure;
  }
  throw StateError('no failure for the feed page');
}

void main() {
  group('identity and lifecycle', () {
    test('the manifest carries the stable id, the name and the icon', () async {
      final site = _bound();
      expect(site.manifest.id, baiduliveSiteId);
      expect(site.manifest.localizedName('zh-CN', 'en-US'), '百度直播');
      expect(site.manifest.localizedName('en-GB', 'en-US'), 'Baidu Live');
      expect(site.manifest.icon?.path, 'assets/platforms/baidulive.png');
      expect(site.runtimeInfo.status, LiveSiteStatus.ready);
      await site.initialize(
        const LiveSiteContext(platform: LiveTargetPlatform.windows, locale: 'zh', defaultLocale: 'en'),
      );
      expect(site.capability<LiveAreaProvider>(), isNotNull);
      expect(site.capability<LiveDiscoveryProvider>(), isNotNull);
      expect(site.capability<LiveRoomProvider>(), isNotNull);
      expect(site.capability<LiveSearchProvider>(), isNotNull);
      expect(site.capability<LivePlaybackProvider>(), isNotNull);
      expect(site.capability<LiveDanmakuProvider>(), isNotNull);
      expect(site.capability<LiveLinkResolver>(), isNotNull);
      expect(site.capability<LiveHotProvider>(), isNull);
      expect(site.capability<LiveRoomProvider>(), same(site.capability<LiveRoomProvider>()));
      await site.dispose();
    });
  });

  group('ids and links', () {
    test('a room id is 6 to 20 digits not starting with zero', () {
      expect(BaiduliveEndpoints.normalizeRoomId('123456'), '123456');
      expect(BaiduliveEndpoints.normalizeRoomId(' 12345678901234567890 '), '12345678901234567890');
      expect(BaiduliveEndpoints.normalizeRoomId('0123456'), isNull);
      expect(BaiduliveEndpoints.normalizeRoomId('12345'), isNull);
      expect(BaiduliveEndpoints.normalizeRoomId('123456789012345678901'), isNull);
      expect(BaiduliveEndpoints.normalizeRoomId('12 3456'), isNull);
      expect(BaiduliveEndpoints.parseRoomId('$_roomId '), _roomId);
      expect(BaiduliveEndpoints.roomUrl(_roomId), 'https://live.baidu.com/m/room/$_roomId');
    });

    test('the room page, the PC player and the share page name a room', () {
      expect(BaiduliveEndpoints.roomIdFromUrl('https://live.baidu.com/m/room/$_roomId'), _roomId);
      expect(BaiduliveEndpoints.roomIdFromUrl('http://live.baidu.com//m//room//$_roomId//'), _roomId);
      expect(BaiduliveEndpoints.roomIdFromUrl('https://live.baidu.com:443/m/room/$_roomId'), _roomId);
      expect(BaiduliveEndpoints.roomIdFromUrl('http://live.baidu.com:80/m/room/$_roomId'), _roomId);
      expect(BaiduliveEndpoints.roomIdFromUrl('HTTP://LIVE.Baidu.com/m/room/$_roomId'), _roomId);
      expect(
        BaiduliveEndpoints.roomIdFromUrl('https://live.baidu.com/m/media/pclive/pchome/live.html?room_id=$_roomId&t=1'),
        _roomId,
      );
      expect(
        BaiduliveEndpoints.roomIdFromUrl(
          'https://live.baidu.com/m/media/multipage/liveshow/index/AbC-9_z?room_id=$_roomId',
        ),
        _roomId,
      );
      expect(BaiduliveEndpoints.parseRoomId('https://live.baidu.com/m/room/$_roomId'), _roomId);
    });

    test('everything else names no room, a link that cannot be decoded too', () {
      expect(BaiduliveEndpoints.roomIdFromUrl('https://live.baidu.com:8443/m/room/$_roomId'), isNull);
      expect(BaiduliveEndpoints.roomIdFromUrl('https://user:pw@live.baidu.com/m/room/$_roomId'), isNull);
      expect(BaiduliveEndpoints.roomIdFromUrl('https://live.baidu.com/m/room/$_roomId#top'), isNull);
      expect(BaiduliveEndpoints.roomIdFromUrl('ftp://live.baidu.com/m/room/$_roomId'), isNull);
      expect(BaiduliveEndpoints.roomIdFromUrl('https://example.com/m/room/$_roomId'), isNull);
      // The room page's own path decides, whatever a stray query names.
      expect(BaiduliveEndpoints.roomIdFromUrl('https://live.baidu.com/m/room/$_roomId?room_id=123456'), _roomId);
      expect(
        BaiduliveEndpoints.roomIdFromUrl('https://live.baidu.com/m/media/pchome/live.html?room_id=$_roomId'),
        isNull,
      );
      expect(
        BaiduliveEndpoints.roomIdFromUrl(
          'https://live.baidu.com/m/media/multipage/liveshow/index/a/b?room_id=$_roomId',
        ),
        isNull,
      );
      expect(
        BaiduliveEndpoints.roomIdFromUrl(
          'https://live.baidu.com/m/media/multipage/liveshow/index/${'x' * 65}?room_id=$_roomId',
        ),
        isNull,
      );
      expect(BaiduliveEndpoints.roomIdFromUrl('https://live.baidu.com/m/room/%'), isNull);
      expect(BaiduliveEndpoints.roomIdFromUrl('https://live.baidu.com/m/room/12345'), isNull);
    });

    test('the resolver canonicalizes its own links without a request', () async {
      final http = _FakeHttp(_api());
      final link = _bound(transport: http).capability<LiveLinkResolver>()!;
      final player = Uri.parse('https://live.baidu.com/m/media/pclive/pchome/live.html?room_id=$_roomId');
      expect(_right(await link.resolve(player)).toString(), 'https://live.baidu.com/m/room/$_roomId');
      expect(http.requestCount, 0);
      expect(_leftOf(await link.resolve(Uri.parse('https://example.com/m/room/$_roomId'))), isA<LiveSiteUnsupported>());
      expect(
        _leftOf(await link.resolve(Uri.parse('https://live.baidu.com/m/other/$_roomId'))),
        isA<LiveSiteNotFound>(),
      );
    });
  });

  group('client names, the feed form and its signature', () {
    test('the injected device id names both the feed and the room command', () async {
      final http = _FakeHttp(_api());
      final site = _bound(transport: http);
      await site.recommend(1, 20);
      await site.detail(_roomId);
      final form = Uri.splitQueryString(http.posts.single.body!);
      expect(form['uid'], _deviceId);
      expect(form['timestamp'], '${_at.millisecondsSinceEpoch ~/ 1000}');
      expect(site.feedDevice, _deviceId);
      expect(site.roomDevice(), _deviceId);
      final query = http.sent.last.query;
      expect(query['uid'], _deviceId);
      expect(query['cmd'], '371');
      expect(query['action'], 'star');
      expect(query['service'], 'bdbox');
      expect(query['osname'], 'pc');
      expect(query['ua'], '360_740_ANDROID_0');
      expect(query['_'], '${_at.millisecondsSinceEpoch}');
      expect(jsonDecode(query['data']!), {
        'data': {'room_id': _roomId, 'device_id': _deviceId, 'source_type': 0},
        'replay_slice': 0,
        'nid': '',
        'schemeParams': {
          'src_pre': 'pc',
          'src_suf': 'other',
          'bd_vid': '',
          'share_uid': '',
          'share_cuk': '',
          'share_ecid': '',
          'zb_tag': '',
          'shareTaskInfo': '{"room_id":"$_roomId"}',
          'share_from': '',
          'ext_params': '',
          'nid': '',
        },
      });
    });

    test('without one the clock spells them', () {
      final site = _bound(deviceId: null);
      expect(site.feedDevice, 'pc-${_at.microsecondsSinceEpoch.toRadixString(36)}purelivedev');
      expect(site.roomDevice(), 'pc-${_at.microsecondsSinceEpoch.toRadixString(36)}baidulive');
    });

    test("the feed form is the website's fields, signed without its sign", () {
      final channel = BaiduliveEndpoints.fallbackCategories.first;
      final first = BaiduliveEndpoints.feedForm(
        channel: channel,
        first: true,
        deviceId: _deviceId,
        now: _at,
        sessionId: '',
        refreshIndex: 1,
      );
      expect(first.keys.toList(), [
        'appname',
        'sid',
        'ua',
        'uid',
        'timestamp',
        'source',
        'resource',
        'scene',
        'session_id',
        'refresh_type',
        'refresh_index',
        'tab',
        'channel_id',
        'sign',
      ]);
      expect(first['resource'], 'banner,tab,feed');
      expect(first['refresh_type'], '0');
      expect(first['session_id'], '');
      expect(first['tab'], 'rec');
      expect(first['channel_id'], '570');
      expect(first['scene'], 'pc_channel');
      expect(first['appname'], 'pclive');
      expect(first['source'], 'pclive');
      expect(first['ua'], '320_480_pc_1.0_0');
      final later = BaiduliveEndpoints.feedForm(
        channel: channel,
        first: false,
        deviceId: _deviceId,
        now: _at,
        sessionId: 'session-1',
        refreshIndex: 4,
      );
      expect(later['resource'], 'feed');
      expect(later['refresh_type'], '1');
      expect(later['session_id'], 'session-1');
      expect(later['refresh_index'], '4');
      final unsigned = {...first}..remove('sign');
      expect(first['sign'], BaiduliveEndpoints.signFeed(unsigned));
      // The sorted fields decide, not their order, and `sign` never counts.
      expect(BaiduliveEndpoints.signFeed({'a': '1', 'b': '2'}), BaiduliveEndpoints.signFeed({'b': '2', 'a': '1'}));
      expect(BaiduliveEndpoints.signFeed({...unsigned, 'sign': 'zzz'}), first['sign']);
      expect(
        BaiduliveEndpoints.signFeed({'appname': 'pclive', 'sid': ''}),
        md5.convert(utf8.encode('appname=pclive&sid=&CtmXzYPtdE58nCCcvqM0ectyqW3N5rfY')).toString(),
      );
      expect(BaiduliveEndpoints.signFeed({}), BaiduliveEndpoints.signFeed({'sign': 'ignored'}));
    });

    test('the body keeps empty fields bare, as the website sent them', () {
      final body = BaiduliveEndpoints.feedBody(
        BaiduliveEndpoints.feedForm(
          channel: BaiduliveEndpoints.fallbackCategories.first,
          first: true,
          deviceId: _deviceId,
          now: _at,
          sessionId: '',
          refreshIndex: 1,
        ),
      );
      expect(body, contains('sid&'));
      expect(body, isNot(contains('sid=')));
      expect(Uri.splitQueryString(body)['session_id'], isEmpty);
    });

    test("every request is tagged baidulive and carries the website's headers", () async {
      final http = _FakeHttp(_api());
      final site = _bound(transport: http);
      await site.recommend(1, 20);
      await site.detail(_roomId);
      expect(http.posts.single.headers, BaiduliveEndpoints.feedHeaders);
      expect(http.sent.last.headers, BaiduliveEndpoints.apiHeaders);
      expect(http.posts.single.url, BaiduliveEndpoints.feedUrl);
      expect(http.sent.last.url.scheme, 'https');
      expect(http.sent.last.url.host, 'mbd.baidu.com');
    });
  });

  group('envelopes and statuses', () {
    test('a non-zero errno is a parse failure naming the platform answer', () {
      final failure = _roomFailure(_envelope(null, errno: 7, errmsg: '服务异常'));
      expect(failure.kind, BaiduliveFailureKind.apiChanged);
      expect(failure.message, 'searchbox 371: errno 7 服务异常');
      expect(_pageFailure(_json({'errno': '7', 'data': null})).kind, BaiduliveFailureKind.apiChanged);
      expect(_roomFailure('<html>').message, 'searchbox 371: not JSON');
      expect(_roomFailure('[1,2]').message, 'searchbox 371: not a JSON object');
    });

    test('an answer over the size limit is a parse failure', () {
      final huge = 'x' * (BaiduliveEndpoints.responseLimit + 1);
      expect(_roomFailure(huge).kind, BaiduliveFailureKind.apiChanged);
      expect('${_roomFailure(huge)}', contains('over ${BaiduliveEndpoints.responseLimit} characters'));
    });

    test('each status the platform answers with is told apart', () {
      const expected = {
        400: BaiduliveFailureKind.apiChanged,
        422: BaiduliveFailureKind.apiChanged,
        401: BaiduliveFailureKind.riskControl,
        403: BaiduliveFailureKind.riskControl,
        451: BaiduliveFailureKind.regionBlocked,
        404: BaiduliveFailureKind.notFound,
        410: BaiduliveFailureKind.notFound,
        429: BaiduliveFailureKind.rateLimited,
        500: BaiduliveFailureKind.network,
        503: BaiduliveFailureKind.network,
        302: BaiduliveFailureKind.network,
        204: null,
        200: null,
        199: BaiduliveFailureKind.network,
      };
      for (final MapEntry(key: status, value: kind) in expected.entries) {
        final failure = BaiduliveJson.statusError(status, 'feed');
        expect(failure?.kind, kind, reason: 'HTTP $status');
        if (failure != null) expect(failure.message, 'feed: HTTP $status', reason: 'HTTP $status');
      }
      expect(BaiduliveJson.statusError(422, 'feed')!.toLiveSiteError(baiduliveSiteId), isA<LiveSiteParseError>());
      expect(BaiduliveJson.statusError(403, 'feed')!.toLiveSiteError(baiduliveSiteId), isA<LiveSiteRateLimitError>());
      expect(
        BaiduliveJson.statusError(451, 'feed')!.toLiveSiteError(baiduliveSiteId),
        isA<LiveSiteContentUnavailable>(),
      );
      expect(BaiduliveJson.statusError(410, 'feed')!.toLiveSiteError(baiduliveSiteId), isA<LiveSiteNotFound>());
      expect(BaiduliveJson.statusError(500, 'feed')!.toLiveSiteError(baiduliveSiteId), isA<LiveSiteNetworkError>());
      expect(
        const BaiduliveFailure(BaiduliveFailureKind.invalidArgument, 'x').toLiveSiteError(baiduliveSiteId),
        isA<LiveSiteInvalidArgument>(),
      );
      expect(BaiduliveJson.statusError(404, 'feed')!.isTransient, isFalse);
      expect(BaiduliveJson.statusError(429, 'feed')!.isTransient, isTrue);
      expect(BaiduliveJson.statusError(500, 'feed')!.isTransient, isTrue);
    });

    test('a status gate is applied before the body is read', () {
      expect(_roomFailure('<html>', status: 404).kind, BaiduliveFailureKind.notFound);
      expect(_pageFailure('', status: 500).kind, BaiduliveFailureKind.network);
    });

    test('a transport breakdown is a network failure, a cancellation is left alone', () async {
      final failing = _bound(transport: _FakeHttp((_) => throw const ConnectFailure('dns')));
      expect(_leftOf(await failing.capability<LiveRoomProvider>()!.getRoom(_roomId)), isA<LiveSiteNetworkError>());
      final cancelled = _bound(transport: _FakeHttp((_) => throw const CancelledFailure()));
      final left = _leftOf(await cancelled.capability<LiveRoomProvider>()!.getRoom(_roomId));
      expect(left, isA<LiveSiteUnexpectedError>());
      expect(left.message, contains('cancelled'));
    });
  });

  group('feed pages', () {
    test("the feed's inner_errno must be 0 and the session must be named", () {
      expect(_pageFailure(_feedFixture(innerErrno: 5)).kind, BaiduliveFailureKind.apiChanged);
      expect('${_pageFailure(_feedFixture(innerErrno: 5))}', contains('inner_errno 5'));
      expect('${_pageFailure(_feedFixture(sessionId: ''))}', contains('session , refresh_index 1'));
      expect('${_pageFailure(_feedFixture(refreshIndex: -1))}', contains('refresh_index -1'));
      expect('${_pageFailure(_feedFixture(refreshIndex: 'one'))}', contains('refresh_index one'));
      expect('${_pageFailure(_feedFixture(items: [_card()], sessionId: null))}', contains('session null,'));
    });

    test('cards of one room repeat once, and a full page has more', () {
      final nine = [for (var index = 0; index < 9; index++) _card(roomId: '${123456 + index}')];
      final page = BaiduliveRoomParser.page(_feedFixture(items: nine));
      expect(page.hasMore, isFalse);
      expect(page.refreshIndex, 1);
      expect(page.sessionId, 'session-1');
      expect(page.categories, isEmpty);
      final ten = [for (var index = 0; index < 10; index++) _card(roomId: '${123456 + index}')];
      expect(BaiduliveRoomParser.page(_feedFixture(items: ten, sessionId: 's2', refreshIndex: 2)).hasMore, isTrue);
      final twice = BaiduliveRoomParser.page(
        _feedFixture(
          items: [
            _card(),
            _card(title: '第二次'),
            _card(roomId: 'nope'),
          ],
        ),
      );
      expect(twice.rooms, hasLength(1));
      expect(twice.rooms.single.title, '晚间聊天');
    });

    test('a card maps its state, audience and restriction', () {
      BaiduliveRoom cardRoom(Map<String, Object?> card) => BaiduliveRoomParser.card(card)!;
      expect(cardRoom(_card()).state, BaiduliveState.live);
      expect(cardRoom(_card(liveStatus: 0)).state, BaiduliveState.preview);
      expect(cardRoom(_card(liveStatus: 2)).state, BaiduliveState.offline);
      expect(cardRoom(_card(liveStatus: 3)).state, BaiduliveState.replay);
      expect(cardRoom({..._card(), 'live_status': null}).state, BaiduliveState.unknown);
      expect(cardRoom(_card(liveStatus: 9)).state, BaiduliveState.unknown);
      expect(cardRoom(_card(liveStatus: 9)).currentViewers, isNull);
      expect(cardRoom(_card(liveStatus: 0, audience: 50)).currentViewers, isNull);
      expect(cardRoom(_card(liveStatus: 3, audience: 50)).currentViewers, isNull);
      expect(cardRoom(_card(audience: 50)).currentViewers, 50);
      expect(cardRoom(_card(audience: '51')).currentViewers, 51);
      expect(cardRoom(_card(audience: -1)).currentViewers, isNull);
      expect(cardRoom(_card()).followers, isNull);
      expect(cardRoom(_card(liveTag: null, leftLabel: {'text': '地方'})).category, '地方');
      expect(cardRoom(_card(title: '')).title, '主播甲');
      expect(cardRoom(_card(title: '', name: '')).title, '');
      expect(cardRoom(_card(avatar: 'http://pic.bdimg.com/a.png')).avatar, '');
      expect(cardRoom(_card(avatar: 'https://sub.pic.bdimg.com/a.png')).avatar, 'https://sub.pic.bdimg.com/a.png');
      expect(cardRoom(_card(avatar: 'https://example.com/a.png')).avatar, '');
      expect(cardRoom(_card(avatar: 'https://pic.bdimg.com/a.png#x')).avatar, '');
      expect(cardRoom(_card(cover: 'https://x.bcebos.com/c.png')).cover, 'https://x.bcebos.com/c.png');
      expect(cardRoom(_card(cover: 'https://evil-bdimg.com/c.png')).cover, '');
      expect(BaiduliveRoomParser.card(_card(roomId: 'nope')), isNull);
      expect(BaiduliveRoomParser.card(const <String, Object?>{}), isNull);
      // 30-5: the restriction a card does tell, and the one it does not.
      expect(cardRoom(_card(hasPayService: 1)).restriction, LiveRestriction.paid);
      expect(cardRoom(_card(liveStatus: 3, hasPayService: 1)).restriction, LiveRestriction.paid);
      expect(cardRoom(_card(hasPayService: 0)).restriction, LiveRestriction.none);
      expect(cardRoom(_card()).restriction, isNull);
      expect(cardRoom(_card(liveStatus: 0, hasPayService: 1)).restriction, isNull);
      expect(cardRoom(_card(liveStatus: 2)).restriction, isNull);
      expect(cardRoom(_card(liveStatus: 3)).restriction, LiveRestriction.unplayable);
      expect(cardRoom(_card(liveStatus: 3, playUrl: _replayUrl('a.m3u8'))).restriction, LiveRestriction.none);
      expect(
        cardRoom(_card(liveStatus: 3, playUrl: 'https://replay.bdstatic.com/other/a.m3u8')).restriction,
        LiveRestriction.unplayable,
      );
      expect(cardRoom(_card(hasPayService: 1)).paid, isTrue);
      expect(cardRoom(_card()).blocked, isFalse);
      expect(cardRoom(_card(hasPayService: 1)).unavailable!.kind, BaiduliveFailureKind.streamUnavailable);
      expect(cardRoom(_card(liveStatus: 3)).unavailable!.message, '$_roomId ended without a recording (unplayable)');
      expect(cardRoom(_card()).unavailable!.message, '$_roomId has no stream');
      expect(cardRoom(_card(liveStatus: 0)).unavailable!.message, '$_roomId is preview');
      // A card carries no stream of its own, so playback never reads one off
      // the directory: the room command decides.
      expect(
        cardRoom(_card(liveStatus: 3, playUrl: _replayUrl('a.m3u8'))).unavailable!.message,
        contains('ended without a recording'),
      );
    });

    test("the tab block brings the platform's channels and refuses bad ones", () {
      final channels = BaiduliveRoomParser.channels(
        _tabFixture(
          items: [
            {'type': 'REC', 'name': '推荐', 'channel_id': 570},
            {'type': 'rec', 'name': '重复', 'channel_id': 571},
            {'type': 'shopping', 'name': '购物', 'channel_id': '574'},
            {'type': 'a_b9', 'name': '合法', 'channel_id': 5},
            {'type': 'a-b', 'name': '非法', 'channel_id': 5},
            {'type': '1news', 'name': '非法', 'channel_id': 5},
            {'type': 'news', 'name': '', 'channel_id': 575},
            {'type': 'leisure', 'name': '休闲', 'channel_id': 0},
            {'type': 'finance', 'name': '财经', 'channel_id': 611},
            'not an object',
          ],
        ),
      );
      expect(channels.map((channel) => channel.id), ['rec', 'shopping', 'a_b9', 'finance']);
      expect(channels.first.name, '推荐');
      expect(channels[1].channelId, 574);
      expect(BaiduliveRoomParser.channels(_tabFixture(innerErrno: 3)), isEmpty);
      expect(BaiduliveRoomParser.channels(null), isEmpty);
      expect(BaiduliveRoomParser.channels(const <String, Object?>{}), isEmpty);
      expect(BaiduliveRoomParser.channels({'inner_errno': 0, 'items': 'not a list'}), isEmpty);
      // A failed tab block leaves the page intact (unlike 3.x).
      final page = BaiduliveRoomParser.page(
        _feedFixture(
          tab: _tabFixture(
            innerErrno: 3,
            items: [
              {'type': 'rec', 'name': '推荐', 'channel_id': 570},
            ],
          ),
        ),
      );
      expect(page.categories, isEmpty);
      expect(page.rooms, isEmpty);
    });

    test("the areas group under the platform, in the platform's order", () {
      final areas = BaiduliveRoomParser.areas(BaiduliveEndpoints.fallbackCategories);
      expect(areas.first.areaId, 'rec');
      expect(areas.first.areaName, '推荐');
      expect(areas.first.platform, baiduliveSiteId);
      expect(areas.first.parentAreaId, 'baidulive');
      expect(areas.first.parentAreaName, '百度直播');
      expect(areas.last.position, BaiduliveEndpoints.fallbackCategories.length - 1);
      expect(BaiduliveRoomParser.areas(const []), isEmpty);
    });
  });

  group('directory paging', () {
    test('page 1 starts the session and later pages continue it', () async {
      List<Object?> full(int page) => [
        for (var index = 0; index < BaiduliveEndpoints.fullPage; index++) _card(roomId: '${_roomId}0$page$index'),
      ];
      final http = _FakeHttp((seen) {
        final form = Uri.splitQueryString(seen.body!);
        final page = int.parse(form['refresh_index']!);
        return _resp(200, _feedFixture(items: full(page), sessionId: 'session-$page', refreshIndex: page));
      });
      final discovery = _bound(transport: http).capability<LiveDiscoveryProvider>()!;
      final first = _right(await discovery.getRecommendedRooms());
      expect(first.items, hasLength(BaiduliveEndpoints.fullPage));
      expect(first.hasMore, isTrue);
      final form = Uri.splitQueryString(http.posts.single.body!);
      expect(form['resource'], 'banner,tab,feed');
      expect(form['session_id'], isEmpty);
      expect(form['refresh_index'], '1');
      final unsigned = {...form}..remove('sign');
      expect(form['sign'], BaiduliveEndpoints.signFeed(unsigned));
      expect(http.requestCount, 1);

      final second = _right(await discovery.getRecommendedRooms(request: const LivePageRequest(page: 2)));
      final secondForm = Uri.splitQueryString(http.posts.last.body!);
      expect(secondForm['resource'], 'feed');
      expect(secondForm['session_id'], 'session-1');
      expect(secondForm['refresh_index'], '2');
      expect(second.items.first.roomId, '${_roomId}020');
      expect(http.requestCount, 2);

      // The page a session served last is replayed without a request (30-6).
      final replay = _right(await discovery.getRecommendedRooms(request: const LivePageRequest(page: 2)));
      expect(replay.items.first.roomId, '${_roomId}020');
      expect(http.requestCount, 2);

      // A page that is not the session's next is empty without a request, and
      // so is one past the last page the directory ever asks for.
      for (final page in [9, BaiduliveEndpoints.maxPage + 1]) {
        final skipped = _right(await discovery.getRecommendedRooms(request: LivePageRequest(page: page)));
        expect(skipped.items, isEmpty, reason: 'page $page');
        expect(skipped.hasMore, isFalse, reason: 'page $page');
      }
      expect(http.requestCount, 2);

      // Page 1 always starts the session over.
      await discovery.getRecommendedRooms();
      expect(http.postCount, 3);
      expect(Uri.splitQueryString(http.posts.last.body!)['session_id'], isEmpty);
    });

    test('a page below one asks for nothing', () async {
      final http = _FakeHttp(_api());
      final site = _bound(transport: http);
      final discovery = site.capability<LiveDiscoveryProvider>()!;
      final area = site.capability<LiveAreaProvider>()!;
      expect(_right(await discovery.getRecommendedRooms(request: const LivePageRequest(page: 0))).items, isEmpty);
      expect(_right(await discovery.getRecommendedRooms(request: const LivePageRequest(pageSize: 0))).items, isEmpty);
      expect(_right(await area.getAreaRooms(areaId: 'rec', request: const LivePageRequest(page: -1))).items, isEmpty);
      expect(
        _right(await area.getAreaRooms(areaId: 'rec', request: const LivePageRequest(pageSize: 0))).items,
        isEmpty,
      );
      expect(
        _right(await site.capability<LiveRoomProvider>()!.getRooms(const LivePageRequest(page: 0))).items,
        isEmpty,
      );
      expect((await site.directory(0)).rooms, isEmpty);
      expect(http.requestCount, 0);
    });

    test('a page repeats no room of its session and ends while nothing is fresh', () async {
      String room(int index) => '${123456 + index}';
      final http = _FakeHttp((seen) {
        final form = Uri.splitQueryString(seen.body!);
        final page = int.parse(form['refresh_index']!);
        final ids = switch (page) {
          1 => [for (var index = 0; index < 10; index++) room(index)],
          2 => [for (var index = 8; index < 18; index++) room(index)],
          _ => [for (var index = 0; index < 18; index++) room(index)],
        };
        return _resp(
          200,
          _feedFixture(
            items: [for (final id in ids) _card(roomId: id)],
            refreshIndex: page,
          ),
        );
      });
      final site = _bound(transport: http);
      final first = await site.directory(1);
      expect(first.rooms, hasLength(10));
      expect(first.hasMore, isTrue);
      final second = await site.directory(2);
      expect(second.rooms.map((listed) => listed.roomId), [
        room(10),
        room(11),
        room(12),
        room(13),
        room(14),
        room(15),
        room(16),
        room(17),
      ]);
      expect(second.hasMore, isTrue);
      // A page of only repeats brings no room and ends the list.
      final third = await site.directory(3);
      expect(third.rooms, isEmpty);
      expect(third.hasMore, isFalse);
      // The session is over: a later page is empty without a request.
      expect((await site.directory(4)).rooms, isEmpty);
      expect(http.postCount, 3);
    });

    test('a full page that moved the session on has more', () async {
      final items = [for (var index = 0; index < 10; index++) _card(roomId: '${123456 + index}')];
      final site = _bound(onSend: (_) => _resp(200, _feedFixture(items: items)));
      expect((await site.directory(1)).hasMore, isTrue);
      expect((await site.directory(2)).hasMore, isFalse);
    });

    test('a full page that does not move the session on ends the list', () async {
      final items = [for (var index = 0; index < 10; index++) _card(roomId: '${123456 + index}')];
      final http = _FakeHttp((_) => _resp(200, _feedFixture(items: items)));
      final site = _bound(transport: http);
      expect((await site.directory(1)).hasMore, isTrue);
      expect((await site.directory(2)).hasMore, isFalse);
      expect(http.postCount, 2);
    });

    test('areas come without a request and an unknown one is refused before one', () async {
      final http = _FakeHttp(_api());
      final site = _bound(transport: http);
      final areas = _right(await site.capability<LiveAreaProvider>()!.getAreas());
      expect(areas.map((area) => area.areaId), [
        'rec',
        'shopping',
        'finance',
        'health',
        'education',
        'news',
        'leisure',
      ]);
      expect(http.requestCount, 0);
      final unknown = _leftOf(await site.capability<LiveAreaProvider>()!.getAreaRooms(areaId: 'sport'));
      expect(unknown, isA<LiveSiteInvalidArgument>());
      expect(unknown.message, contains('sport'));
      expect(
        _leftOf(await site.capability<LiveAreaProvider>()!.getAreaRooms(areaId: ' REC ')),
        isA<LiveSiteInvalidArgument>(),
      );
      expect(
        _leftOf(await site.capability<LiveAreaProvider>()!.getAreaRooms(areaId: '')),
        isA<LiveSiteInvalidArgument>(),
      );
      expect(http.requestCount, 0);

      // The first feed page's tab list replaces the catalog.
      final listed = _FakeHttp(
        _api(
          feed: _feedFixture(
            items: [_card()],
            tab: _tabFixture(
              items: [
                {'type': 'games', 'name': '游戏', 'channel_id': 700},
              ],
            ),
          ),
        ),
      );
      final withTabs = _bound(transport: listed);
      await withTabs.directory(1);
      expect(_right(await withTabs.capability<LiveAreaProvider>()!.getAreas()).single.areaId, 'games');
      expect(
        _leftOf(await withTabs.capability<LiveAreaProvider>()!.getAreaRooms(areaId: 'rec')),
        isA<LiveSiteInvalidArgument>(),
      );
    });

    test('the recommendations and the "推荐" channel keep separate sessions (30-6)', () async {
      final http = _FakeHttp((seen) {
        final form = Uri.splitQueryString(seen.body!);
        final items = [for (var index = 0; index < 10; index++) _card(roomId: '${123456 + index}')];
        return _resp(200, _feedFixture(items: items, sessionId: 'session-${form['tab']}'));
      });
      final site = _bound(transport: http);
      await site.capability<LiveDiscoveryProvider>()!.getRecommendedRooms();
      await site.capability<LiveAreaProvider>()!.getAreaRooms(areaId: 'rec');
      await site.capability<LiveAreaProvider>()!.getAreaRooms(areaId: 'rec', request: const LivePageRequest(page: 2));
      final third = Uri.splitQueryString(http.posts.last.body!);
      expect(third['session_id'], 'session-rec');
      expect(third['refresh_index'], '2');
      expect(http.postCount, 3);
    });

    test('a page size cuts the rooms of the feed page', () async {
      final items = [for (var index = 0; index < 10; index++) _card(roomId: '${123456 + index}')];
      final http = _FakeHttp((_) => _resp(200, _feedFixture(items: items)));
      final site = _bound(transport: http);
      final page = _right(
        await site.capability<LiveAreaProvider>()!.getAreaRooms(
          areaId: 'rec',
          request: const LivePageRequest(pageSize: 3),
        ),
      );
      expect(page.items, hasLength(3));
      expect(page.hasMore, isTrue);
      expect(page.totalCount, isNull);
      expect(page.nextCursor, isNull);
      expect(page.items.first.broadcast.effectiveLiveStatus, LiveStatus.live);
      expect(page.items.first.runtime.streamHandle, isNull);
      expect(page.items.first.runtime.danmakuHandle, isNull);
      expect(http.postCount, 1);
    });
  });

  group('the room command', () {
    test('a room that is not there is not-found, another answer is parse', () {
      expect(_roomFailure(_envelope({'other': 1})).kind, BaiduliveFailureKind.notFound);
      expect(_roomFailure(_envelope({'371': null})).message, 'room $_roomId');
      expect(_roomFailure(_roomFixture({'error_code': 1})).message, 'room $_roomId: error_code 1');
      expect(_roomFailure(_roomFixture({'error_code': 4})).kind, BaiduliveFailureKind.notFound);
      expect(_roomFailure(_roomFixture({'error_code': 2})).message, 'searchbox 371: error_code 2');
      expect(_roomFailure(_roomFixture({'error_code': 'x'})).kind, BaiduliveFailureKind.apiChanged);
      expect(_roomFailure(_roomFixture({'template': 'live'})).kind, BaiduliveFailureKind.apiChanged);
      expect(_roomFailure(_roomFixture({'error_code': 0})).message, 'room $_roomId: no host or video');
      expect(
        _roomFailure(_roomFixture(_liveCommand(extra: {'share_url': 'https://live.baidu.com/m/room/$_otherRoom'})))
            .kind,
        BaiduliveFailureKind.apiChanged,
      );
      expect(
        '${_roomFailure(_roomFixture(_liveCommand(extra: {'share_url': 'https://live.baidu.com/m/room/$_otherRoom'})))}',
        contains('share_url of room $_otherRoom for $_roomId'),
      );
      // A share_url that is no link at all tells nothing (3.x did not refuse it).
      expect(
        BaiduliveRoomParser.room(
          _roomFixture(_liveCommand(extra: {'share_url': 'not a link'})),
          expectedRoomId: _roomId,
        ).roomId,
        _roomId,
      );
      expect(_roomFailure(_roomFixture(_liveCommand()), roomId: _otherRoom).kind, BaiduliveFailureKind.apiChanged);
    });

    test('an announced broadcast answers as a preview template', () {
      final room = BaiduliveRoomParser.room(
        _roomFixture({
          'template': 'preview',
          'status': 1,
          'host': {'name': ''},
          'source': '主播甲',
          'uk': 'anchor-uk',
          'title': '预告',
          'avatar': 'https://pic.bdimg.com/a.png',
          'cover': 'https://pic.bdimg.com/c.png',
          'vertical_cover': 'https://pic.bdimg.com/v.png',
          'description': '明天八点',
        }),
        expectedRoomId: _roomId,
      );
      expect(room.state, BaiduliveState.preview);
      expect(room.nick, '主播甲');
      expect(room.userId, 'anchor-uk');
      expect(room.title, '预告');
      expect(room.avatar, 'https://pic.bdimg.com/a.png');
      expect(room.cover, 'https://pic.bdimg.com/c.png');
      expect(room.introduction, '明天八点');
      expect(room.restriction, isNull);
      expect(room.variants, isEmpty);
      expect(room.unavailable!.kind, BaiduliveFailureKind.streamUnavailable);
      expect(BaiduliveRoomParser.liveRoom(room).broadcast.effectiveLiveStatus, LiveStatus.offline);
      expect(
        BaiduliveRoomParser.room(
          _roomFixture({
            'template': 'preview',
            'status': 0,
            'host': {'name': ''},
          }),
          expectedRoomId: _roomId,
        ).state,
        BaiduliveState.live,
      );
    });

    test('the status table, the audience and the start are read while live', () {
      BaiduliveRoom room(int status) =>
          BaiduliveRoomParser.room(_roomFixture(_liveCommand(status: status)), expectedRoomId: _roomId);
      expect(room(0).state, BaiduliveState.live);
      expect(room(-1).state, BaiduliveState.preview);
      expect(room(1).state, BaiduliveState.preview);
      expect(room(2).state, BaiduliveState.offline);
      expect(room(20).state, BaiduliveState.offline);
      expect(room(3).state, BaiduliveState.replay);
      expect(room(11).state, BaiduliveState.unknown);
      expect(room(11).unavailable!.message, '$_roomId is unknown');
      for (final status in [-1, 2, 3, 11]) {
        expect(room(status).currentViewers, isNull, reason: 'status $status');
        expect(room(status).startedAt, isNull, reason: 'status $status');
        expect(room(status).danmaku, isNull, reason: 'status $status');
      }
      expect(room(0).currentViewers, 1300);
      expect(room(0).startedAt, DateTime.fromMillisecondsSinceEpoch(1727700000000, isUtc: true));
      expect(room(0).followers, 42000);
      expect(room(0).introduction, '主播的介绍');
      expect(room(0).category, '闲聊');
      expect(room(0).cover, 'https://pic.bdimg.com/cover.png');
      expect(room(0).avatar, 'https://pic.bdimg.com/a.png');
      expect(room(0).danmaku, isA<BaiduliveDanmakuArgs>());
      expect(room(0).variants, isNotEmpty);
      // real_fans_num, else the host's fans.
      expect(
        BaiduliveRoomParser.room(
          _roomFixture(_liveCommand(extra: {'real_fans_num': null})),
          expectedRoomId: _roomId,
        ).followers,
        41000,
      );
      expect(
        BaiduliveRoomParser.room(
          _roomFixture(_liveCommand(extra: {'online_users': 'x'})),
          expectedRoomId: _roomId,
        ).currentViewers,
        isNull,
      );
      // create_time: positive whole seconds of at most ten digits.
      for (final seconds in [17277000000000, 0, -5, null, 'x']) {
        expect(
          BaiduliveRoomParser.room(
            _roomFixture(_liveCommand(extra: {'create_time': seconds})),
            expectedRoomId: _roomId,
          ).startedAt,
          isNull,
          reason: '$seconds',
        );
      }
      expect(
        BaiduliveRoomParser.room(
          _roomFixture(
            _liveCommand(
              extra: {
                'video': {
                  'cover': {'vertical_cover': 'https://pic.bdimg.com/v.png'},
                },
              },
            ),
          ),
          expectedRoomId: _roomId,
        ).cover,
        'https://pic.bdimg.com/v.png',
      );
    });

    test('paid, forbidden and banned keep their state and set the restriction (30-5)', () {
      BaiduliveRoom room(Map<String, Object?> extra) =>
          BaiduliveRoomParser.room(_roomFixture(_liveCommand(extra: extra)), expectedRoomId: _roomId);
      expect(room({'has_pay_service': 1}).restriction, LiveRestriction.paid);
      expect(room({'is_forbidden_url': 1}).restriction, LiveRestriction.unplayable);
      expect(room({'ban_status': 2}).restriction, LiveRestriction.unplayable);
      expect(room({'has_pay_service': 1, 'is_forbidden_url': 1}).restriction, LiveRestriction.unplayable);
      expect(room({}).restriction, LiveRestriction.none);
      expect(room({'has_pay_service': 1}).paid, isTrue);
      expect(room({'ban_status': 1}).blocked, isTrue);
      expect(room({'is_forbidden_url': 1}).blocked, isTrue);
      expect('${room({'has_pay_service': 1}).unavailable}', contains('restricted (paid)'));
      expect('${room({'ban_status': 1}).unavailable}', contains('forbidden or banned'));
      expect(room({'status': 3, 'replay_list': null}).restriction, LiveRestriction.unplayable);
      final bare = BaiduliveRoomParser.room(
        _roomFixture(
          _liveCommand(
            extra: {
              'video': {'title': '没有流'},
            },
          ),
        ),
        expectedRoomId: _roomId,
      );
      expect(bare.variants, isEmpty);
      expect(bare.restriction, LiveRestriction.unplayable);
      expect('${bare.unavailable}', contains('has no stream'));
      final shown = BaiduliveRoomParser.liveRoom(room({'has_pay_service': 1}));
      expect(shown.content.notice, '${BaiduliveEndpoints.restrictedNotice}\n${BaiduliveEndpoints.chatNotice}');
      expect(BaiduliveRoomParser.liveRoom(room({})).content.notice, BaiduliveEndpoints.chatNotice);
      expect(BaiduliveRoomParser.liveRoom(room({})).broadcast.isRestricted, isFalse);
      expect(BaiduliveRoomParser.liveRoom(room({'has_pay_service': 1})).broadcast.isRestricted, isTrue);
    });

    test('the room shown to the user falls back where the answer is silent', () {
      final sparse = BaiduliveRoomParser.room(
        _roomFixture({
          'error_code': 0,
          'status': 2,
          'host': {'uk': ''},
          'video': {'title': ''},
        }),
        expectedRoomId: _roomId,
      );
      final room = BaiduliveRoomParser.liveRoom(sparse);
      expect(room.platform, baiduliveSiteId);
      expect(room.roomId, _roomId);
      expect(room.identityKey, 'baidulive:$_roomId');
      expect(room.anchor?.anchorId, _roomId);
      expect(room.anchor?.name, '');
      expect(room.content.title, '');
      expect(room.area?.areaName, '百度直播');
      expect(room.audience.primaryMetric, LiveAudienceMetricType.unknown);
      expect(room.audience.onlineViewers, isNull);
      expect(room.links.webUrl, 'https://live.baidu.com/m/room/$_roomId');
      expect(room.broadcast.effectiveLiveStatus, LiveStatus.offline);
      expect(room.content.introduction, isNull);
      expect(room.runtime.streamHandle, isNull);
      expect(room.runtime.danmakuHandle, isNull);
      expect(BaiduliveRoomParser.liveRoom(sparse, withData: true).runtime.streamHandle, sparse);

      final full = BaiduliveRoomParser.liveRoom(_full(), withData: true);
      expect(full.anchor?.anchorId, 'anchor-uk');
      expect(full.anchor?.name, '主播甲');
      expect(full.anchor?.followerCount, 42000);
      expect(full.anchor?.avatarUrl, 'https://pic.bdimg.com/a.png');
      expect(full.area?.areaName, '闲聊');
      expect(full.audience.onlineViewers, 1300);
      expect(full.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      expect(full.broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(1727700000000, isUtc: true));
      expect(full.content.coverUrl, 'https://pic.bdimg.com/cover.png');
      expect(full.runtime.danmakuHandle, isA<BaiduliveDanmakuArgs>());
      // withChat alone keeps the lists and not the streams (a refresh).
      final refreshed = BaiduliveRoomParser.liveRoom(_full(), withChat: true);
      expect(refreshed.runtime.danmakuHandle, isA<BaiduliveDanmakuArgs>());
      expect(refreshed.runtime.streamHandle, isNull);
      // An ended broadcast is a replay, not an offline room.
      final ended = BaiduliveRoomParser.room(
        _roomFixture({
          'error_code': 0,
          'status': 3,
          'video': {'title': '回放'},
          'replay_list': [
            {'video': _replayUrl('a.m3u8')},
          ],
        }),
        expectedRoomId: _roomId,
      );
      expect(BaiduliveRoomParser.liveRoom(ended).broadcast.effectiveLiveStatus, LiveStatus.replay);
      expect(BaiduliveRoomParser.liveRoom(ended).broadcast.isRecord, isTrue);
      expect(BaiduliveRoomParser.liveRoom(ended).broadcast.isPlayableNow, isTrue);
    });

    test('a room command fills what a card of the same room knew', () async {
      final card = _card(cover: 'https://pic.bdimg.com/c.png', audience: 900);
      final http = _FakeHttp((seen) {
        if (seen.method == 'POST') return _resp(200, _feedFixture(items: [card]));
        return _resp(
          200,
          _roomFixture({
            'error_code': 0,
            'status': 0,
            'host': {'uk': 'anchor-uk'},
            'video': {'live_flv_url': 'https://hls-live.bdstatic.com/live/live_$_roomId.flv'},
            'online_users': null,
          }),
        );
      });
      final site = _bound(transport: http);
      await site.directory(1);
      final room = await site.detail(_roomId);
      expect(room.content.title, '晚间聊天');
      expect(room.anchor?.name, '主播甲');
      expect(room.anchor?.avatarUrl, 'https://pic.bdimg.com/a.png');
      expect(room.content.coverUrl, 'https://pic.bdimg.com/c.png');
      expect(room.area?.areaName, '闲聊');
      expect(room.audience.onlineViewers, 900);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      // An ended room no longer shows the viewers of its card.
      final known = BaiduliveRoomParser.card(card)!;
      final ended = BaiduliveRoomParser.room(
        _roomFixture({
          'error_code': 0,
          'status': 3,
          'host': {'uk': 'anchor-uk'},
        }),
        expectedRoomId: _roomId,
      ).enrich(known);
      expect(ended.currentViewers, isNull);
      expect(ended.nick, '主播甲');
      expect(ended.followers, isNull);
      expect(known.enrich(known).roomId, _roomId);
    });

    test("room entry keeps the answer as the room's stream data", () async {
      final http = _FakeHttp(_api());
      final site = _bound(transport: http);
      final room = _right(await site.capability<LiveRoomProvider>()!.getRoom(_roomId));
      expect(room.runtime.streamHandle, isA<BaiduliveRoom>());
      expect((room.runtime.streamHandle! as BaiduliveRoom).variants, isNotEmpty);
      expect(http.requestCount, 1);
      // The refresh and the recording answer are the same one command.
      expect(
        _right(await site.capability<LiveRoomProvider>()!.getRoom('https://live.baidu.com/m/room/$_roomId')).roomId,
        _roomId,
      );
      expect(http.requestCount, 2);
    });
  });

  group('the chat lists of a room command (M5.26)', () {
    test('a valid chat list is required; http becomes https', () {
      Uri? list(Object? value) => BaiduliveRoomParser.messageList(value);
      expect(
        list('https://liveshowstatic.baidu.com/chat.m3u8').toString(),
        'https://liveshowstatic.baidu.com/chat.m3u8',
      );
      expect(list('http://liveshowstatic.baidu.com/chat.m3u8')!.scheme, 'https');
      expect(list('https://LIVESHOWSTATIC.BAIDU.COM/chat.m3u8').toString().startsWith('https://'), isTrue);
      expect(list('https://example.com/chat.m3u8'), isNull);
      expect(list('https://liveshowstatic.baidu.com/chat.txt'), isNull);
      expect(list('ftp://liveshowstatic.baidu.com/chat.m3u8'), isNull);
      expect(list('https://user@liveshowstatic.baidu.com/chat.m3u8'), isNull);
      expect(list('https://liveshowstatic.baidu.com/chat.m3u8#frag'), isNull);
      expect(list(null), isNull);

      final args = BaiduliveRoomParser.danmakuArgs(_liveCommand(), _roomId)!;
      expect(args.roomId, _roomId);
      expect(args.chatList.toString(), _listUrl('chat'));
      expect(args.reliableList.toString(), _listUrl('reliable'));
      expect(args.hostList.toString(), _listUrl('host'));
      expect(args.toString(), 'BaiduliveDanmakuArgs($_roomId)');
      final videoOnly = BaiduliveRoomParser.danmakuArgs({
        'error_code': 0,
        'video': {'msg_hls_url': _listUrl('chat')},
      }, _roomId)!;
      expect(videoOnly.chatList.toString(), _listUrl('chat'));
      expect(videoOnly.reliableList, isNull);
      expect(videoOnly.hostList, isNull);
      expect(videoOnly.pullInterval, BaiduliveEndpoints.defaultPullInterval);
      expect(videoOnly.expiresAt, isNotNull);
      expect(
        BaiduliveRoomParser.danmakuArgs({
          'error_code': 0,
          'chat_msg_hls_url': 'https://example.com/a.m3u8',
          'video': {'msg_hls_url': 'https://example.com/b.m3u8'},
        }, _roomId),
        isNull,
      );
      expect(videoOnly, isNot(equals(args)));
      expect(videoOnly, equals(videoOnly));
      expect(videoOnly.hashCode, videoOnly.hashCode);
      final plain = BaiduliveDanmakuArgs(
        roomId: _roomId,
        chatList: Uri.parse('https://liveshowstatic.baidu.com/a/a.m3u8'),
      );
      expect(plain.expiresAt, isNull);
      expect(plain.isExpiredAt(_at), isFalse);
      expect(plain.pullInterval, BaiduliveEndpoints.defaultPullInterval);
    });

    test("the poll interval is clamped to the platform's 1 to 10 seconds", () {
      BaiduliveDanmakuArgs args(Object? seconds) =>
          BaiduliveRoomParser.danmakuArgs(_liveCommand(extra: {'msg_hls_pull_internal_in_second': seconds}), _roomId)!;
      expect(args(3).pullInterval, const Duration(seconds: 3));
      expect(args(20).pullInterval, const Duration(seconds: 10));
      expect(args(1).pullInterval, const Duration(seconds: 1));
      expect(args('4').pullInterval, const Duration(seconds: 4));
      expect(args(0).pullInterval, BaiduliveEndpoints.defaultPullInterval);
      expect(args(-2).pullInterval, BaiduliveEndpoints.defaultPullInterval);
      expect(args(null).pullInterval, BaiduliveEndpoints.defaultPullInterval);
      expect(
        BaiduliveRoomParser.danmakuArgs({
          'error_code': 0,
          'video': {'msg_hls_url': _listUrl('chat'), 'msg_hls_pull_internal_in_second': 8},
        }, _roomId)!.pullInterval,
        const Duration(seconds: 8),
      );
    });

    test("the signature's expiry is read from its time and validity", () {
      expect(
        BaiduliveRoomParser.signatureExpiry(Uri.parse(_listUrl('chat'))),
        DateTime.parse('2026-09-30T12:00:00Z').add(const Duration(seconds: 15552000)),
      );
      expect(BaiduliveRoomParser.signatureExpiry(Uri.parse('https://liveshowstatic.baidu.com/a.m3u8')), isNull);
      expect(BaiduliveRoomParser.signatureExpiry(Uri.parse('https://liveshowstatic.baidu.com/a.m3u8?x=1')), isNull);
      expect(
        BaiduliveRoomParser.signatureExpiry(Uri.parse(_listUrl('chat', time: '2026-13-45T12%3A00%3A00Z'))),
        isNull,
      );
      expect(BaiduliveRoomParser.signatureExpiry(Uri.parse(_listUrl('chat', time: 'yesterday'))), isNull);
      expect(BaiduliveRoomParser.signatureExpiry(Uri.parse(_listUrl('chat', seconds: '0'))), isNull);
      expect(BaiduliveRoomParser.signatureExpiry(Uri.parse(_listUrl('chat', seconds: 'abc'))), isNull);
      expect(BaiduliveRoomParser.signatureExpiry(Uri.parse(_listUrl('chat', seconds: '12345678901'))), isNull);
      expect(BaiduliveRoomParser.signatureExpiry(Uri.parse(_listUrl('chat', version: 'bce-auth-v2'))), isNull);
      // Plain separators, as some recorded answers wrote them.
      expect(
        BaiduliveRoomParser.signatureExpiry(
          Uri.parse(
            'https://liveshowstatic.baidu.com/a/a.m3u8'
            '?authorization=bce-auth-v1/ak/2026-09-30T12:00:00Z/60/host/sig',
          ),
        ),
        DateTime.parse('2026-09-30T12:01:00Z'),
      );
      final expired = BaiduliveRoomParser.danmakuArgs(
        _liveCommand(
          extra: {'chat_msg_hls_url': _listUrl('chat', time: '2026-09-29T12%3A00%3A00Z', seconds: '3600')},
        ),
        _roomId,
      )!;
      expect(expired.isExpiredAt(_at), isTrue);
      expect(BaiduliveRoomParser.danmakuArgs(_liveCommand(), _roomId)!.isExpiredAt(_at), isFalse);
      expect(
        BaiduliveRoomParser.danmakuArgs(_liveCommand(), _roomId)!.isExpiredAt(_at.subtract(const Duration(days: 300))),
        isFalse,
      );
    });
  });

  group('qualities and lines', () {
    test('the media gate keeps the hosts it trusts and their scheme rules', () {
      Uri? url(String raw, {LiveStreamFormat format = LiveStreamFormat.flv}) =>
          BaidulivePlayParser.mediaUrl(raw, roomId: _roomId, format: format);
      // 30-9: flv-live answers http; its https certificate does not match.
      expect(
        url('https://flv-live.bdstatic.com/live/live_$_roomId.flv').toString(),
        'http://flv-live.bdstatic.com/live/live_$_roomId.flv',
      );
      expect(url('http://flv-live.bdstatic.com/live/live_$_roomId.flv')!.scheme, 'http');
      expect(url('http://hls-live.bdstatic.com/live/live_$_roomId.flv')!.scheme, 'https');
      expect(url('https://p1.liveshow.bdstatic.com/live/live_$_roomId.flv')!.scheme, 'https');
      // The platform's current CDN is kept as given, as a backup line (30-1).
      expect(url('http://b1.liveshow.lss-user.baidubce.com/live/live_$_roomId.flv')!.scheme, 'http');
      expect(url('https://b1.liveshow.lss-user.baidubce.com/live/live_$_roomId.flv')!.scheme, 'https');
      expect(url('http://b1.liveshow.lss-user.baidubce.com/live/live_$_roomId.m3u8'), isNull);
      expect(url('https://example.com/live/live_$_roomId.flv'), isNull);
      expect(url('https://lss-user.baidubce.com/live/live_$_roomId.flv'), isNull);
      expect(url('https://hls-live.bdstatic.com:8443/live/live_$_roomId.flv'), isNull);
      expect(url('https://flv-live.bdstatic.com:8080/live/live_$_roomId.flv'), isNull);
      expect(url('https://user@hls-live.bdstatic.com/live/live_$_roomId.flv'), isNull);
      expect(url('https://hls-live.bdstatic.com/live/live_$_roomId.flv#x'), isNull);
      expect(url('https://hls-live.bdstatic.com/movie/live_$_roomId.flv'), isNull);
      expect(url('https://hls-live.bdstatic.com/live/live_$_roomId.mp4'), isNull);
      expect(url('https://hls-live.bdstatic.com/live/live_$_roomId.m3u8'), isNull);
      expect(url('https://hls-live.bdstatic.com/live/live_$_roomId.m3u8', format: LiveStreamFormat.hls), isNotNull);
      expect(url('https://hls-live.bdstatic.com/live/live_9999.flv'), isNull);
      expect(url('https://hls-live.bdstatic.com/live/live_${_roomId}x.flv'), isNull);
      expect(url('https://hls-live.bdstatic.com/live/$_roomId.flv'), isNull);
      expect(url('https://hls-live.bdstatic.com/live/LIVE_$_roomId.flv'), isNotNull);
      expect(url(''), isNull);
      expect(
        BaidulivePlayParser.streamName(Uri.parse('https://h/a/live_$_roomId-720/playlist.m3u8')),
        'live_$_roomId-720',
      );
      expect(BaidulivePlayParser.streamName(Uri.parse('https://h/a/live_$_roomId.flv')), 'live_$_roomId');
      expect(BaidulivePlayParser.streamName(Uri.parse('https://h/a/playlist.m3u8')), 'a');
      expect(BaidulivePlayParser.streamName(Uri.parse('https://h/a/')), 'a');
    });

    test("a live room's tiers are read by their stream names", () {
      final variants = _full().variants;
      expect(variants.map((variant) => variant.id), ['source', 'source:hevc', '720p', '720p:hevc', '480p']);
      expect(variants.map((variant) => variant.name), ['原画', '原画 · H.265', '720p', '720p · H.265', '480p']);
      expect(variants.map((variant) => variant.sort), [1000002, 1000000, 7202, 7200, 4802]);
      expect(variants.map((variant) => variant.codec), [
        LiveStreamCodec.avc,
        LiveStreamCodec.hevc,
        LiveStreamCodec.avc,
        LiveStreamCodec.hevc,
        LiveStreamCodec.avc,
      ]);
      // FLV before HLS within a tier, and the source's two lines.
      expect(variants.first.sources.map((source) => '${source.url}'), [
        'https://hls-live.bdstatic.com/live/live_$_roomId.flv',
        'https://hls-live.bdstatic.com/live/live_$_roomId.m3u8',
      ]);
      expect(variants.first.sources.map((source) => source.format), [LiveStreamFormat.flv, LiveStreamFormat.hls]);
      // 3.x's hosts first, then the platform's current CDN as a backup.
      expect(variants.last.sources.map((source) => source.url.host), [
        'p2.liveshow.bdstatic.com',
        'b1.liveshow.lss-user.baidubce.com',
      ]);
      // A stream once per host: play_url repeats the 720p avc_flv address.
      expect(variants[2].sources.map((source) => '${source.url}'), [
        'https://p1.liveshow.bdstatic.com/live/live_$_roomId-720.flv',
        'https://p1.liveshow.bdstatic.com/live/live_$_roomId-720/playlist.m3u8',
      ]);
      expect(variants[3].sources.map((source) => '${source.url}'), [
        'https://p1.liveshow.bdstatic.com/live/live_$_roomId-720-hevc.flv',
      ]);
      // A card carries no tiers at all.
      expect(BaiduliveRoomParser.card(_card())!.variants, isEmpty);
    });

    test('a URL the gate refuses costs one line, not the room', () {
      final variants = BaidulivePlayParser.liveVariants({
        'live_flv_url': 'https://hls-live.bdstatic.com/live/live_$_roomId.flv',
        'live_hls_url': 'https://example.com/live/live_$_roomId.m3u8',
        'live_flv_url_origin': 'https://hls-live.bdstatic.com/live/live_9999.flv',
        'url_clarity_list': [
          {
            'resolution': 0,
            'urls': {'flv': 'https://p1.liveshow.bdstatic.com/live/live_$_roomId-720.flv'},
          },
          {
            'resolution': -2,
            'urls': {'flv': 'https://p1.liveshow.bdstatic.com/live/live_$_roomId-720.flv'},
          },
          {
            'urls': {'flv': 'https://p1.liveshow.bdstatic.com/live/live_$_roomId.flv'},
          },
          'not an object',
        ],
        'url_list': [
          {
            'resolution': 540,
            'urls': ['not an object'],
          },
          {
            'resolution': 'high',
            'urls': [
              {'flv': 'https://p1.liveshow.bdstatic.com/live/live_$_roomId-540.flv'},
            ],
          },
        ],
      }, _roomId);
      expect(variants.map((variant) => variant.id), ['source']);
      expect(variants.single.codec, LiveStreamCodec.avc);
      expect(variants.single.sources, hasLength(1));
      expect(BaidulivePlayParser.liveVariants(const <String, Object?>{}, _roomId), isEmpty);
    });

    test("the source's codec is inferred from the AVC fields", () {
      List<BaiduliveVariant> variants(Map<String, Object?> video) => BaidulivePlayParser.liveVariants(video, _roomId);
      // No clarity list and the AVC fields name a transcode: the original is
      // H.265 (the 2026-09-29 survey), so the source is the `source:hevc`
      // tier — the reference's S02-room-hevc case, where no plain `source`
      // quality exists at all.
      final transcode = {
        'url_list': [
          {
            'resolution': 720,
            'urls': [
              {'flv': 'https://p1.liveshow.bdstatic.com/live/live_$_roomId-720.flv'},
            ],
          },
        ],
        'live_flv_url': 'https://p1.liveshow.bdstatic.com/live/live_$_roomId-720.flv',
        'live_flv_url_origin': 'https://p1.liveshow.bdstatic.com/live/live_$_roomId.flv',
      };
      expect(variants(transcode).firstWhere((variant) => variant.id == 'source:hevc').codec, LiveStreamCodec.hevc);
      // The explicit hevc_url joins that same source tier (the reference's
      // S02-room-hevc: one `source:hevc`, its lines merged, no `source`).
      final both = {
        ...transcode,
        'hevc_url': 'https://flv.liveshow.lss-user.baidubce.com/live/live_${_roomId}_wz_hevc.flv',
      };
      final merged = variants(both).where((variant) => variant.id == 'source:hevc').single;
      expect(merged.sources, hasLength(2));
      expect(variants(both).where((variant) => variant.id == 'source'), isEmpty);
      // With a clarity list the same answer cannot tell.
      expect(
        variants({
          ...transcode,
          'url_clarity_list': [
            {
              'resolution': 720,
              'urls': {'flv': 'https://p1.liveshow.bdstatic.com/live/live_$_roomId-720.flv'},
            },
          ],
        }).firstWhere((variant) => variant.id == 'source').codec,
        isNull,
      );
      // live_hls_url naming the source is no transcode sign, and one AVC field
      // naming the source settles it as AVC.
      expect(
        variants({
          'live_hls_url': 'https://hls-live.bdstatic.com/live/live_$_roomId.m3u8',
          'live_flv_url_origin': 'https://hls-live.bdstatic.com/live/live_$_roomId.flv',
        }).single.codec,
        LiveStreamCodec.avc,
      );
      expect(
        variants({'live_flv_url_origin': 'https://hls-live.bdstatic.com/live/live_$_roomId.flv'}).single.codec,
        isNull,
      );
      // A stream no tier names is left out.
      expect(variants({'live_flv_url': 'https://p1.liveshow.bdstatic.com/live/other.flv'}), isEmpty);
    });

    test("an ended broadcast's recording becomes the qualities (30-4)", () {
      final room = BaiduliveRoomParser.room(
        _roomFixture({
          'error_code': 0,
          'status': 3,
          'host': {'uk': 'anchor-uk', 'nick_name': '主播甲'},
          'video': {'title': '已结束'},
          'replay_list': [
            {'video': 'https://example.com/2026_09_$_roomId/a.m3u8'},
            {
              'videoInfo': {
                'ext': {
                  'clarityUrl': [
                    {'key': 'OD', 'title': '超清', 'url': _replayUrl('od.m3u8')},
                    {'key': 'HD', 'url': _replayUrl('hd.m3u8')},
                    {'key': 'BAD KEY', 'url': _replayUrl('bad.m3u8')},
                    {'key': 'od', 'url': _replayUrl('again.m3u8')},
                    'not an object',
                  ],
                },
              },
              'video': _replayUrl('plain.m3u8'),
              'video_hevc': '{"OD":"${_replayUrl('od-hevc.m3u8')}","no key":"${_replayUrl('x.m3u8')}"}',
            },
          ],
        }),
        expectedRoomId: _roomId,
      );
      expect(room.state, BaiduliveState.replay);
      expect(room.variants.map((variant) => variant.id), ['replay:od', 'replay:hd', 'replay:od:hevc']);
      expect(room.variants.map((variant) => variant.name), ['超清', 'HD', 'OD · H.265']);
      expect(room.variants.map((variant) => variant.sort), [32, 22, 10]);
      expect(room.variants.map((variant) => variant.codec), [
        LiveStreamCodec.avc,
        LiveStreamCodec.avc,
        LiveStreamCodec.hevc,
      ]);
      expect(room.variants.first.sources.single.format, LiveStreamFormat.hls);
      expect(room.restriction, LiveRestriction.none);
      expect(room.unavailable, isNull);
      expect(room.danmaku, isNull);
      // Without a clarity list the entry's own video is the one quality.
      expect(
        BaidulivePlayParser.replayVariants([
          {'video': _replayUrl('plain.m3u8')},
        ], _roomId).map((variant) => [variant.id, variant.name, variant.sort]),
        [
          ['replay', '回放', 12],
        ],
      );
      // video_hevc may be an object already; a broken one is no qualities.
      expect(
        BaidulivePlayParser.replayVariants([
          {
            'video_hevc': {'OD': _replayUrl('od-hevc.m3u8')},
          },
        ], _roomId).map((variant) => variant.id),
        ['replay:od:hevc'],
      );
      expect(
        BaidulivePlayParser.replayVariants([
          {'video_hevc': '{broken'},
        ], _roomId),
        isEmpty,
      );
      expect(
        BaidulivePlayParser.replayVariants([
          {'video': 'https://replay.bdstatic.com/other/a.m3u8'},
        ], _roomId),
        isEmpty,
      );
      expect(BaidulivePlayParser.replayVariants(null, _roomId), isEmpty);
      expect(BaidulivePlayParser.replayVariants(['not an object'], _roomId), isEmpty);
      expect(BaidulivePlayParser.replayUrl('http://replay.bdstatic.com/a_$_roomId/x.m3u8', _roomId)!.scheme, 'https');
      expect(BaidulivePlayParser.replayUrl('https://replay.bdstatic.com/a.m3u8?x=1#f', _roomId), isNull);
      expect(BaidulivePlayParser.replayUrl('https://replay.bdstatic.com/a.m3u8', _roomId), isNull);
      expect(BaidulivePlayParser.replayUrl('https://replay.bdstatic.com:8443/a_$_roomId/x.m3u8', _roomId), isNull);
      expect(BaidulivePlayParser.replayUrl('https://other.com/a_$_roomId/x.m3u8', _roomId), isNull);
    });

    test('menu order follows "优先 H.264" (30-2)', () {
      final variants = _full().variants;
      expect(BaidulivePlayParser.ordered(variants).map((variant) => variant.id), [
        'source',
        '720p',
        '480p',
        'source:hevc',
        '720p:hevc',
      ]);
      expect(BaidulivePlayParser.ordered(variants, preferH264: false).map((variant) => variant.id), [
        'source',
        'source:hevc',
        '720p',
        '720p:hevc',
        '480p',
      ]);
      // A codec the platform never named sits between the two.
      final mixed = [
        ...variants,
        BaiduliveVariant(id: 'unknown', name: '未知', sort: 1000005, codec: null, sources: const []),
      ];
      expect(BaidulivePlayParser.ordered(mixed).map((variant) => variant.id), [
        'source',
        '720p',
        '480p',
        'unknown',
        'source:hevc',
        '720p:hevc',
      ]);
      expect(BaidulivePlayParser.ordered(const []), isEmpty);
      expect(BaidulivePlayParser.ordered(variants, preferH264: false), isNot(same(variants)));
    });

    test('3.x quality ids read through one migration step', () {
      expect(BaidulivePlayParser.qualityIdFromLegacy('flv:0:avc'), BaidulivePlayParser.sourceQualityId);
      expect(BaidulivePlayParser.qualityIdFromLegacy('HLS:1080:AVC'), '1080p');
      expect(BaidulivePlayParser.qualityIdFromLegacy(' 720p '), '720p');
      expect(BaidulivePlayParser.qualityIdFromLegacy('replay:od'), 'replay:od');
      expect(BaidulivePlayParser.qualityIdFromLegacy(BaidulivePlayParser.qualityIdFromLegacy('flv:540:avc')), '540p');
      for (final MapEntry(key: legacy, value: current) in BaidulivePlayParser.legacyQualityIds.entries) {
        expect(BaidulivePlayParser.qualityIdFromLegacy(legacy), current);
      }
      expect(BaidulivePlayParser.legacyQualityIds.values.toSet(), {'source', '1080p', '720p', '540p', '480p'});
    });

    test("the qualities name the platform's order and codec", () {
      final qualities = BaidulivePlayParser.qualities(_full());
      expect(qualities.map((quality) => quality.qualityId), ['source', '720p', '480p', 'source:hevc', '720p:hevc']);
      expect(qualities.map((quality) => quality.label), ['原画', '720p', '480p', '原画 · H.265', '720p · H.265']);
      expect(qualities.map((quality) => quality.codec), [
        LiveStreamCodec.avc,
        LiveStreamCodec.avc,
        LiveStreamCodec.avc,
        LiveStreamCodec.hevc,
        LiveStreamCodec.hevc,
      ]);
      expect(qualities.first.platformOrder, 1000002);
      expect(qualities.first.isPlaybackUnconfirmed, isFalse);
      expect(
        () => BaidulivePlayParser.qualities(
          BaiduliveRoomParser.room(_roomFixture(_liveCommand(status: 2)), expectedRoomId: _roomId),
        ),
        throwsA(isA<BaiduliveFailure>().having((failure) => failure.message, 'message', '$_roomId is offline')),
      );
      expect(() => BaidulivePlayParser.qualities(BaiduliveRoomParser.card(_card())!), throwsA(isA<BaiduliveFailure>()));
    });

    test('the lines carry the media headers, the format and the host labels', () {
      final lines = BaidulivePlayParser.lines(_full().variants[2], _roomId);
      expect(lines, hasLength(2));
      expect(lines.map((line) => line.lineLabel), ['p1.liveshow.bdstatic.com', 'p1.liveshow.bdstatic.com#2']);
      expect(lines.map((line) => line.format), [LiveStreamFormat.flv, LiveStreamFormat.hls]);
      expect(lines.every((line) => line.formatSource == LivePlayFormatSource.declared), isTrue);
      expect(lines.first.codec, LiveStreamCodec.avc);
      expect(lines.first.lease, isNull);
      expect(lines.first.singleUse, isFalse);
      expect(lines.first.headers, BaiduliveEndpoints.mediaHeaders(_roomId));
      expect(lines.first.headers['referer'], 'https://live.baidu.com/m/room/$_roomId');
      expect(lines.first.headers['user-agent'], BaiduliveEndpoints.userAgent);
      expect(lines.first.url, 'https://p1.liveshow.bdstatic.com/live/live_$_roomId-720.flv');
    });

    test('the lines of a quality, and one the room no longer offers', () {
      final room = _full();
      expect(BaidulivePlayParser.linesFor(room, const LivePlayQuality(label: '', qualityId: '720p')), hasLength(2));
      expect(
        BaidulivePlayParser.linesFor(room, const LivePlayQuality(label: '', qualityId: 'hls:720:avc')),
        hasLength(2),
      );
      expect(
        BaidulivePlayParser.linesFor(room, const LivePlayQuality(label: '', qualityId: '720p:hevc')),
        hasLength(1),
      );
      // null is the quality the menu puts first (原画, H.264).
      expect(
        BaidulivePlayParser.linesFor(room, null).first.url,
        'https://hls-live.bdstatic.com/live/live_$_roomId.flv',
      );
      expect(
        () => BaidulivePlayParser.linesFor(room, const LivePlayQuality(label: '', qualityId: '1080p')),
        throwsA(
          isA<BaiduliveFailure>().having((failure) => failure.message, 'message', 'quality 1080p is not offered'),
        ),
      );
      expect(
        () => BaidulivePlayParser.linesFor(room, const LivePlayQuality(label: '', qualityId: 'FLV:1080:AVC')),
        throwsA(
          isA<BaiduliveFailure>().having((failure) => failure.message, 'message', 'quality 1080p is not offered'),
        ),
      );
    });
  });
}
