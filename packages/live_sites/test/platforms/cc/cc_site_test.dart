// Test fakes re-create the platform's constructor shapes, whose naming rules
// the public surface's lints govern.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/capabilities/live_status_check.dart';
import 'package:live_sites/src/core/live_site_context.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/core/live_site_runtime_info.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_broadcast/room_broadcast.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/cc/api/cc_endpoints.dart';
import 'package:live_sites/src/platforms/cc/api/cc_http.dart';
import 'package:live_sites/src/platforms/cc/cc_manifest.dart';
import 'package:live_sites/src/platforms/cc/cc_site.dart';
import 'package:test/test.dart';

/// The clock every fixed-time assertion reads: 2026-09-27 16:33:06 UTC, the
/// minute the play fixtures were captured.
final DateTime _at = DateTime.parse('2026-09-27T16:33:06.000Z');

const String _roomId = '341438909';
const String _offlineId = '376267758';
const String _unknownId = '88888888888';
const String _channel = '5728999';

// Answers ---------------------------------------------------------------------

String _categoryTypes() => jsonEncode({
  'code': 0,
  'data': {
    'category_info': {
      'cate_list': [
        {'cate_type': 0, 'name': '全部'},
        {'cate_type': 1, 'name': '网游'},
        {'cate_type': 2, 'name': '手游'},
      ],
    },
  },
});

String _categoryAreas(String parent, String name) => jsonEncode({
  'code': 0,
  'data': {
    'category_info': {
      'game_list': [
        {'gametype': '9141', 'name': name, 'cover': 'https://cotton.res.netease.com/egg.png'},
        {'gametype': '65005', 'name': '$parent的其他', 'cover': ''},
      ],
    },
  },
});

String _areaPage({int rows = 1}) => jsonEncode({
  'videos': <Object?>[],
  'gametype': 9141,
  'lives': [
    for (var index = 0; index < rows; index++)
      {
        'cuteid': 341438909 + index,
        'title': index == 0 ? '《蛋仔派对》抖音巅峰杯' : '【重播】第二十届蛋仔冲冲冲巅峰对决',
        'nickname': '巅峰杯',
        'status': 1,
        'startat': '2026-09-14 14:53:45',
        'webcc_visitor': 298945,
        'vision_visitor': 716,
        'game_name': '蛋仔派对',
        'gamename': '蛋仔派对',
        'purl': 'http://cc.fp.ps.netease.com/a.png',
        'cover': 'http://cc.fp.ps.netease.com/b.png',
        'poster': null,
        'stream_list': {
          'high': {
            'vbr': 2000,
            'CDN_FMT': {'fws': 'wsSecret=x'},
          },
        },
      },
  ],
});

String _recommendPage(int rows) => jsonEncode({
  'lives': [
    for (var index = 0; index < rows; index++)
      {'cuteid': 341438909 + index, 'title': '直播 $index', 'nickname': '主播', 'gamename': '蛋仔派对'},
  ],
});

String _searchPage(int rows) => jsonEncode({
  'webcc_anchor': {
    'count': rows,
    'result': [
      for (var index = 0; index < rows; index++)
        {
          'cuteid': 700700 + index,
          'title': '梦幻 $index',
          'nickname': '主播 $index',
          'status': 1,
          'hot_score': 222646,
          'follower_num': 2929971,
          'portrait': 'http://cc.res.netease.com/p.png',
          'game_name': '《梦幻西游》电脑版',
        },
    ],
  },
});

String _lives(String ccid, {Object? channel}) => jsonEncode({
  'code': 'OK',
  'data': {
    ccid: {'is_black': 0, 'channel_id': ?channel, 'ccid': ccid},
  },
});

String _channelPage() => jsonEncode({
  'now_time': 1790526551,
  'data': [
    {
      'ccid': 341438909,
      'cuteid': 341438909,
      'cid': 5728999,
      'uid': 260267129,
      'status': 1,
      'title': '《蛋仔派对》抖音巅峰杯',
      'nickname': '巅峰杯',
      'gamename': '蛋仔派对',
      'personal_label': '',
      'follower_num': 303,
      'startat': '2026-09-14 14:53:45',
      'webcc_visitor': 293325,
      'vision_visitor': 654,
      'purl': 'http://cc.fp.ps.netease.com/a.png',
      'cover': 'http://cc.fp.ps.netease.com/b.png',
      'm3u8': 'http://cgi.v.cc.163.com/redirect/video/341438909.m3u8?secret=bac6536f08',
      'stream_list': {
        'original': {
          'vbr': 7999,
          'CDN_FMT': {'ali': 'auth_key=1790612944-key', 'fws': 'wsSecret=x'},
        },
      },
    },
  ],
});

String _roomPage({bool missing = false}) =>
    '<html><script id="__NEXT_DATA__" type="application/json">${jsonEncode({
      'props': {
        'pageProps': {
          'roomInfoInitData': missing ? {'code': 404, 'reason': 'no ccid'} : {
                  'announcement': '',
                  'gamename': '其他游戏',
                  'purl': 'http://cc.res.netease.com/p.png',
                  'ccid': 376267758,
                  'follower_num': 39802,
                  'uid': 297533520,
                  'nickname': '路人7758',
                  'live_title': '路人7758的直播',
                  'micfirst': {'ccid': 376267758, 'nickname': '路人7758', 'purl': 'http://cc.res.netease.com/p.png'},
                  'live': {'ccid': 376267758},
                },
        },
      },
    })}</script></html>';

String _exists(bool exists) =>
    jsonEncode({if (exists) 'code': 0 else 'code': 4, 'msg': exists ? '' : '没有对应的ccid', 'data': <String, Object?>{}});

/// The `video_play_url` answer the fake serves for [seen]: the tier of the
/// `vbrname` asked, on hs with ali as backup — or, when [dropBackup], only
/// the hs line so `cdn_list` names an uncovered CDN.
String _play(_Seen seen, {bool dropBackup = false}) {
  final cdn = seen.url.queryParameters['cdn'];
  final tier = seen.url.queryParameters['vbrname'] ?? 'original';
  return jsonEncode({
    'vbrname_sel': tier,
    'vbrname_list': ['original', 'ultra', 'high', 'standard'],
    'vbrname_mapping': {'original': '原画', 'ultra': '超清', 'high': '高清', 'standard': '标清'},
    'cdn_list': ['hs', 'ali'],
    'cdn_sel': cdn ?? 'hs',
    'bakcdn_sel': cdn ?? 'ali',
    'videourl': switch (cdn) {
      'ali' => 'https://alirtspull.cc.netease.com/pushstationsave/x.flv?auth_key=1790526920-ali',
      _ => 'https://hsrelayhdl.cc.netease.com/pushstation/544d36afcaffd8355a34260267129.flv?auth_key=1790526920-hs',
    },
    if (!dropBackup || cdn != null)
      'bakvideourl': switch (cdn) {
        'ali' => 'https://alirtspull.cc.netease.com/pushstationsave/x2.flv?auth_key=1790526920-ali2',
        _ => 'https://alirtspull.cc.netease.com/pushstationsave/x.flv?auth_key=1790526920-ali',
      },
  });
}

// Transport and helpers --------------------------------------------------------

final class _Seen {
  _Seen(LiveRequest request)
    : method = request.method,
      url = request.url,
      headers = request.headers,
      body = request.body,
      timeout = request.timeout;

  final String method;
  final Uri url;
  final Map<String, String> headers;
  final String? body;
  final Duration? timeout;

  String get hostPath => '${url.host}${url.path}';
}

final class _FakeHttp implements LiveHttp {
  _FakeHttp(this.onSend);

  final FutureOr<LiveResponse> Function(_Seen request) onSend;
  final List<_Seen> sent = [];

  int get requestCount => sent.length;

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

LiveResponse _resp(int status, Object body) =>
    LiveResponse(statusCode: status, headers: const {}, bodyBytes: Uint8List.fromList(utf8.encode('$body')));

/// The site under test with its fake transport, so a test reads the requests
/// through the same handle the site sends through.
typedef _Harness = ({CcSite site, _FakeHttp http});

_Harness _site(LiveResponse Function(_Seen seen) onSend, {DateTime Function()? now}) {
  final http = _FakeHttp(onSend);
  return (site: CcSite(http: CcHttp(http), now: now ?? () => _at), http: http);
}

T _right<T>(Either<LiveSiteError, T> either) => either.match((left) => throw StateError('$left'), (right) => right);

LiveSiteError _leftOf<T>(Either<LiveSiteError, T> either) =>
    either.match((left) => left, (right) => throw StateError('not a left: $either'));

/// The website's answers the default fake serves.
LiveResponse Function(_Seen) _api({
  int areaRows = 2,
  int recommendRows = 2,
  int searchRows = 2,
  bool channelLive = true,
  bool anchorExists = true,
  bool dropBackup = false,
}) =>
    (seen) => switch (seen.hostPath) {
      'api.cc.163.com/v1/wapcc/gamecategory' when seen.url.queryParameters['catetype'] == '0' => _resp(
        200,
        _categoryTypes(),
      ),
      'api.cc.163.com/v1/wapcc/gamecategory' => _resp(200, _categoryAreas('网游', '蛋仔派对')),
      'cc.163.com/api/category/9141/' => _resp(200, _areaPage(rows: areaRows)),
      'cc.163.com/api/category/live/' => _resp(200, _recommendPage(recommendRows)),
      'cc.163.com/search/anchor/' => _resp(200, _searchPage(searchRows)),
      'api.cc.163.com/v1/activitylives/anchor/lives' => _resp(
        200,
        _lives(seen.url.queryParameters['anchor_ccid']!, channel: channelLive ? _channel : null),
      ),
      'cc.163.com/live/channel/' => _resp(200, _channelPage()),
      _ when seen.hostPath.startsWith('cc.163.com/$_roomId') => _resp(200, _roomPage()),
      _ when seen.hostPath.startsWith('cc.163.com/$_offlineId') => _resp(200, _roomPage()),
      _ when seen.hostPath.startsWith('cc.163.com/$_unknownId') => _resp(200, _roomPage(missing: true)),
      'api.cc.163.com/v1/wapcc/recommendbyccid' => _resp(200, _exists(anchorExists)),
      _ when seen.hostPath.startsWith('vapi.cc.163.com/video_play_url') => _resp(
        200,
        _play(seen, dropBackup: dropBackup),
      ),
      _ => _resp(404, 'nothing here'),
    };

LiveArea get _area => LiveArea.normalized(platform: 'cc', areaId: '9141', areaName: '蛋仔派对');

LiveRoom get _bareRoom => LiveRoom.normalized(platform: 'cc', roomId: _roomId);

LivePlayQuality get _original => LivePlayQuality.of(label: '原画', qualityId: 'original');

void main() {
  group('identity and lifecycle', () {
    test('the manifest carries the stable id and the name', () async {
      final (:site, :http) = _site(_api());
      expect(site.manifest.id, ccSiteId);
      expect(site.manifest.localizedName('zh-CN', 'en-US'), '网易CC直播');
      expect(site.manifest.localizedName('en-GB', 'en-US'), 'NetEase CC');
      expect(site.runtimeInfo.status, LiveSiteStatus.ready);
      await site.initialize(
        const LiveSiteContext(platform: LiveTargetPlatform.windows, locale: 'zh', defaultLocale: 'en'),
      );
      expect(site.capability<LiveRoomProvider>(), isNotNull);
      expect(site.capability<LiveAreaProvider>(), isNotNull);
      expect(site.capability<LiveDiscoveryProvider>(), isNotNull);
      expect(site.capability<LiveSearchProvider>(), isNotNull);
      expect(site.capability<LivePlaybackProvider>(), isNotNull);
      expect(site.capability<LiveLinkResolver>(), isNotNull);
      expect(site.capability<LiveRoomRefresh>(), isNotNull);
      expect(site.capability<LiveStatusCheck>(), isNotNull);
      // CC has no danmaku (3.x neither) and no gifts.
      expect(site.capability<LiveDanmakuProvider>(), isNull);
      expect(site.capability<LiveRoomProvider>(), same(site.capability<LiveRoomProvider>()));
      expect(http.requestCount, 0);
      await site.dispose();
    });
  });

  group('catalog', () {
    test('the mobile categories with their areas, and the official entries beside them', () async {
      final (:site, :http) = _site(
        (seen) => switch (seen.hostPath) {
          'api.cc.163.com/v1/wapcc/gamecategory' when seen.url.queryParameters['catetype'] == '0' => _resp(
            200,
            _categoryTypes(),
          ),
          // 手游 lists no areas: the category is left out.
          'api.cc.163.com/v1/wapcc/gamecategory' when seen.url.queryParameters['catetype'] == '2' => _resp(
            200,
            '{"code":0,"data":{"category_info":{"game_list":[]}}}',
          ),
          'api.cc.163.com/v1/wapcc/gamecategory' => _resp(200, _categoryAreas('网游', '蛋仔派对')),
          'inf.ds.163.com/v1/web/game-center/basic/base-info-list/by-type' => _resp(
            200,
            jsonEncode({
              'code': 200,
              'result': [
                {'appKey': 'd90', 'name': '炉石传说', 'icon': 'https://ok.166.net/hs.png'},
              ],
            }),
          ),
          'inf-act.ds.163.com/v1/act-web/pageConf/commonAppConfig' => _resp(
            200,
            jsonEncode({
              'code': 200,
              'result': {
                'id': CcEndpoints.catalogConfigurationId,
                'hidden': false,
                'itemList': [
                  {
                    'name': '直播入口列表',
                    'itemList': [
                      {'name': 'd90', 'content': 'https://cc.163.com/249133/'},
                    ],
                  },
                ],
              },
            }),
          ),
          _ => _resp(404, 'nothing'),
        },
      );
      final areas = _right(await site.capability<LiveAreaProvider>()!.getAreas());
      expect(areas.map((area) => area.areaId), ['9141', '65005', 'official:249133']);
      expect(areas[0].parentAreaId, '1');
      expect(areas[0].parentAreaName, '网游');
      expect(areas[2].parentAreaName, '官方房间/专题');
      // 1 (types) + 2 (one per category) + 2 (Dashen).
      expect(http.requestCount, 5);
      // The Dashen configuration goes as a JSON POST of the configuration id.
      final post = http.sent.where((seen) => seen.method == 'POST').single;
      expect(post.url.host, 'inf-act.ds.163.com');
      expect(jsonDecode(post.body!), {'id': CcEndpoints.catalogConfigurationId});
      await site.dispose();
    });

    test('failing Dashen requests leave the catalog intact (9-4)', () async {
      final (:site, http: _) = _site(
        (seen) => switch (seen.hostPath) {
          'api.cc.163.com/v1/wapcc/gamecategory' when seen.url.queryParameters['catetype'] == '0' => _resp(
            200,
            _categoryTypes(),
          ),
          'api.cc.163.com/v1/wapcc/gamecategory' when seen.url.queryParameters['catetype'] == '2' => _resp(
            200,
            '{"code":0,"data":{"category_info":{"game_list":[]}}}',
          ),
          'api.cc.163.com/v1/wapcc/gamecategory' => _resp(200, _categoryAreas('网游', '蛋仔派对')),
          _ => _resp(500, 'dashen down'),
        },
      );
      final areas = _right(await site.capability<LiveAreaProvider>()!.getAreas());
      expect(areas, hasLength(2));
      await site.dispose();
    });

    test('a category whose areas cannot be read fails the catalog (3.x all-or-nothing)', () async {
      final (:site, http: _) = _site(
        (seen) => switch (seen.hostPath) {
          'api.cc.163.com/v1/wapcc/gamecategory' when seen.url.queryParameters['catetype'] == '0' => _resp(
            200,
            _categoryTypes(),
          ),
          'api.cc.163.com/v1/wapcc/gamecategory' when seen.url.queryParameters['catetype'] == '2' => _resp(
            200,
            '{"code":0}',
          ),
          _ => _resp(200, _categoryAreas('网游', '蛋仔派对')),
        },
      );
      expect(_leftOf(await site.capability<LiveAreaProvider>()!.getAreas()).runtimeType, LiveSiteParseError);
      await site.dispose();
    });

    test('categories without areas are left out', () async {
      final (:site, http: _) = _site(
        (seen) => switch (seen.hostPath) {
          'api.cc.163.com/v1/wapcc/gamecategory' when seen.url.queryParameters['catetype'] == '0' => _resp(
            200,
            _categoryTypes(),
          ),
          _ => _resp(200, '{"code":0,"data":{"category_info":{"game_list":[]}}}'),
        },
      );
      final areas = _right(await site.capability<LiveAreaProvider>()!.getAreas());
      expect(areas, isEmpty);
      await site.dispose();
    });
  });

  group('area rooms', () {
    test('the rooms of an area, offset-paged, a full page meaning more', () async {
      final (:site, :http) = _site(_api());
      final provider = site.capability<LiveAreaProvider>()!;
      final full = _right(await provider.getAreaRooms(area: _area, request: LivePageRequest.of(pageSize: 2)));
      expect(full.items, hasLength(2));
      expect(full.hasMore, isTrue);
      expect(full.items.first.broadcast.liveStatus, LiveStatus.live);
      expect(full.items.last.broadcast.liveStatus, LiveStatus.replay);
      final seen = http.sent.singleWhere((seen) => seen.hostPath == 'cc.163.com/api/category/9141/');
      expect(seen.url.queryParameters['start'], '0');
      expect(seen.url.queryParameters['size'], '2');
      final short = _right(
        await provider.getAreaRooms(area: _area, request: LivePageRequest.of(page: 3, pageSize: 30)),
      );
      final next = http.sent.lastWhere((seen) => seen.hostPath == 'cc.163.com/api/category/9141/');
      expect(next.url.queryParameters['start'], '60');
      expect(next.url.queryParameters['size'], '30');
      expect(short.hasMore, isFalse);
      await site.dispose();
    });

    test('an official entry, another platform area or a bad page is a caller error, without a request', () async {
      final (:site, :http) = _site(_api());
      final provider = site.capability<LiveAreaProvider>()!;
      final official = LiveArea.normalized(platform: 'cc', areaId: 'official:249133', areaName: '炉石传说');
      expect(_leftOf(await provider.getAreaRooms(area: official)).runtimeType, LiveSiteInvalidArgument);
      expect(
        _leftOf(
          await provider.getAreaRooms(
            area: LiveArea.normalized(platform: 'douyu', areaId: '1'),
          ),
        ).runtimeType,
        LiveSiteInvalidArgument,
      );
      expect(
        _leftOf(await provider.getAreaRooms(area: _area, request: LivePageRequest.of(page: 100001))).runtimeType,
        LiveSiteInvalidArgument,
      );
      expect(
        _leftOf(await provider.getAreaRooms(area: _area, request: LivePageRequest.of(pageSize: 1001))).runtimeType,
        LiveSiteInvalidArgument,
      );
      expect(http.requestCount, 0);
      await site.dispose();
    });
  });

  group('recommendations', () {
    test('every live room, offset-paged, a page below 1 asked as 1', () async {
      final (:site, :http) = _site(_api());
      final discovery = site.capability<LiveDiscoveryProvider>()!;
      final page = _right(await discovery.getRecommendedRooms(request: LivePageRequest.of(page: 2, pageSize: 30)));
      expect(page.items, hasLength(2));
      // The feed rows carry no audience figures; the metric stays unknown.
      expect(page.items.first.audience.primaryMetric, LiveAudienceMetricType.unknown);
      expect(page.items.first.broadcast.liveStatus, LiveStatus.live);
      final seen = http.sent.single;
      expect('${seen.url.host}${seen.url.path}', 'cc.163.com/api/category/live/');
      expect(seen.url.queryParameters['start'], '30');
      expect(seen.url.queryParameters['size'], '30');
      final clamped = _right(await discovery.getRecommendedRooms(request: LivePageRequest.of(page: 0, pageSize: 0)));
      expect(clamped.items, hasLength(2));
      expect(http.sent.last.url.queryParameters['start'], '0');
      expect(http.sent.last.url.queryParameters['size'], '1');
      await site.dispose();
    });
  });

  group('search', () {
    test('the streamers matching a keyword, live or not, size limited to 1–50', () async {
      final (:site, :http) = _site(_api());
      final rooms = _right(
        await site.capability<LiveSearchProvider>()!.search(
          LiveSearchRequest.of(query: '梦幻', target: LiveSearchTarget.rooms, pageSize: 99),
        ),
      );
      expect(rooms.items, hasLength(2));
      final seen = http.sent.single;
      expect(seen.url.path, '/search/anchor/');
      expect(seen.url.queryParameters['size'], '50');
      expect(seen.url.queryParameters['query'], '梦幻');
      await site.dispose();
    });

    test('the anchors of the same results; areas unsupported', () async {
      final (:site, http: _) = _site(_api(searchRows: 1));
      final provider = site.capability<LiveSearchProvider>()!;
      expect(provider.supportedTargets, {LiveSearchTarget.rooms, LiveSearchTarget.anchors});
      final anchors = _right(
        await provider.search(LiveSearchRequest.of(query: '梦幻', target: LiveSearchTarget.anchors)),
      );
      final anchor = anchors.items.single;
      expect(anchor, isA<AnchorSearchResult>());
      expect((anchor as AnchorSearchResult).anchor.anchorId, '700700');
      expect(anchor.roomId, '700700');
      expect(
        _leftOf(await provider.search(LiveSearchRequest.of(query: '梦幻', target: LiveSearchTarget.areas))).runtimeType,
        LiveSiteUnsupported,
      );
      await site.dispose();
    });

    test('a blank keyword gives nothing without a request', () async {
      final (:site, :http) = _site(_api());
      final page = _right(
        await site.capability<LiveSearchProvider>()!.search(
          LiveSearchRequest.of(query: '  ', target: LiveSearchTarget.rooms),
        ),
      );
      expect(page.items, isEmpty);
      expect(http.requestCount, 0);
      await site.dispose();
    });
  });

  group('room detail', () {
    test('the two-request chain for a broadcasting anchor', () async {
      final (:site, :http) = _site(_api());
      final room = _right(await site.capability<LiveRoomProvider>()!.getRoom(_roomId));
      expect(room.roomId, _roomId);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.restriction, LiveRestriction.none);
      expect(room.runtime.streamHandle, isNotNull);
      expect(http.requestCount, 2);
      expect(http.sent[0].hostPath, 'api.cc.163.com/v1/activitylives/anchor/lives');
      expect(http.sent[1].hostPath, 'cc.163.com/live/channel/');
      await site.dispose();
    });

    test('room entry of an offline anchor reads its room page and fills the room', () async {
      final (:site, :http) = _site(_api(channelLive: false));
      final room = _right(await site.capability<LiveRoomProvider>()!.getRoom(_offlineId));
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.anchor?.name, '路人7758');
      expect(room.audience.popularity, 39802);
      expect(http.requestCount, 2);
      expect(http.sent[1].hostPath, 'cc.163.com/$_offlineId/');
      await site.dispose();
    });

    test('room entry of an unknown id is not-found (the room page says no ccid)', () async {
      final (:site, http: _) = _site(_api(channelLive: false));
      expect(_leftOf(await site.capability<LiveRoomProvider>()!.getRoom(_unknownId)).runtimeType, LiveSiteNotFound);
      await site.dispose();
    });

    test('a non-numeric id is not-found without a request', () async {
      final (:site, :http) = _site(_api());
      expect(
        _leftOf(await site.capability<LiveRoomProvider>()!.getRoom('n/ds_category')).runtimeType,
        LiveSiteNotFound,
      );
      expect(http.requestCount, 0);
      await site.dispose();
    });

    test('a follow refresh of an offline anchor asks the existence check (9-7)', () async {
      final (:site, :http) = _site(_api(channelLive: false));
      final room = _right(await site.capability<LiveRoomRefresh>()!.getRoomForRefresh(roomId: _offlineId));
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.content.title, isEmpty);
      expect(http.requestCount, 2);
      final probe = http.sent[1];
      expect(probe.hostPath, 'api.cc.163.com/v1/wapcc/recommendbyccid');
      expect(probe.timeout, const Duration(seconds: 8));
      await site.dispose();
    });

    test('CC saying the id is no account is not-found; a failed check stays offline', () async {
      final (site: missingSite, http: missingHttp) = _site(_api(channelLive: false, anchorExists: false));
      expect(
        _leftOf(await missingSite.capability<LiveRoomRefresh>()!.getRoomForRefresh(roomId: _unknownId)).runtimeType,
        LiveSiteNotFound,
      );
      expect(missingHttp.requestCount, 2);
      await missingSite.dispose();

      final (site: brokenSite, http: _) = _site(
        (seen) => seen.hostPath == 'api.cc.163.com/v1/wapcc/recommendbyccid'
            ? _resp(500, 'down')
            : _api(channelLive: false)(seen),
      );
      final room = _right(await brokenSite.capability<LiveRoomRefresh>()!.getRoomForRefresh(roomId: _offlineId));
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      await brokenSite.dispose();
    });

    test('the recording read marks a channel-less anchor offline with no further requests', () async {
      final (:site, :http) = _site(_api(channelLive: false));
      final room = _right(await site.capability<LiveRoomRefresh>()!.getRoomForRecording(roomId: _offlineId));
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(http.requestCount, 1);
      await site.dispose();
    });

    test('the status check reads the recording depth: on air true, no probe', () async {
      final (:site, :http) = _site(_api());
      final live = _right(await site.capability<LiveRoomProvider>()!.getRoom(_roomId));
      expect(_right(await site.capability<LiveStatusCheck>()!.getLiveStatus(room: live)), isTrue);
      expect(http.requestCount, 4); // 2 (entry) + 2 (the status read's chain).
      await site.dispose();
    });

    test('the sparse offline room merges into a stored card without erasing it', () async {
      final (:site, http: _) = _site(_api());
      final provider = site.capability<LiveRoomProvider>()!;
      final stored = _right(await provider.getRoom(_roomId));
      final fresh = stored.rebuild((b) => b..broadcast.replace(RoomBroadcast.of(liveStatus: LiveStatus.offline)));
      final merged = stored.mergedWith(fresh);
      expect(merged.broadcast.liveStatus, LiveStatus.offline);
      expect(merged.content.title, stored.content.title);
      await site.dispose();
    });
  });

  group('playback', () {
    test('the qualities in the server order with their labels', () async {
      final (:site, :http) = _site(_api());
      final qualities = _right(await site.capability<LivePlaybackProvider>()!.getQualities(room: _bareRoom));
      expect(qualities.map((quality) => quality.qualityId), ['original', 'ultra', 'high', 'standard']);
      expect(qualities.map((quality) => quality.label), ['原画', '超清', '高清', '标清']);
      expect(qualities.map((quality) => quality.platformOrder), [4, 3, 2, 1]);
      expect(http.requestCount, 1);
      final seen = http.sent.single;
      expect(seen.url.host, 'vapi.cc.163.com');
      expect(seen.url.path, '/video_play_url/$_roomId');
      expect(seen.url.queryParameters['src'], 'webcc_h5');
      expect(seen.url.queryParameters['vbrmode'], '1');
      expect(seen.url.queryParameters['use_new_vbrmap'], '1');
      expect(seen.url.queryParameters['secure'], '1');
      expect(seen.url.queryParameters.containsKey('vbrname'), isFalse);
      await site.dispose();
    });

    test('the first play of the selected tier reuses the qualities answer, once', () async {
      final (:site, :http) = _site(_api());
      final playback = site.capability<LivePlaybackProvider>()!;
      await playback.getQualities(room: _bareRoom);
      final lines = _right(await playback.getLines(room: _bareRoom, quality: _original));
      expect(lines.map((line) => line.lineLabel), ['hs', 'ali']);
      expect(http.requestCount, 1);
      // A second play asks anew (the answer was taken), and covers both CDNs.
      _right(await playback.getLines(room: _bareRoom, quality: _original));
      expect(http.requestCount, 2);
      await site.dispose();
    });

    test('an answer older than the reuse window is asked again', () async {
      var clock = _at;
      final (:site, :http) = _site(_api(), now: () => clock);
      final playback = site.capability<LivePlaybackProvider>()!;
      await playback.getQualities(room: _bareRoom);
      clock = _at.add(const Duration(seconds: 31));
      _right(await playback.getLines(room: _bareRoom, quality: _original));
      expect(http.requestCount, 2);
      await site.dispose();
    });

    test('a tier answer whose lines leave a CDN out is expanded by one request', () async {
      final (:site, :http) = _site(_api(dropBackup: true));
      final lines = _right(
        await site.capability<LivePlaybackProvider>()!.getLines(
          room: _bareRoom,
          quality: LivePlayQuality.of(label: '高清', qualityId: 'high'),
        ),
      );
      expect(http.sent.first.url.queryParameters['vbrname'], 'high');
      final expansion = http.sent.last;
      expect(expansion.url.queryParameters['cdn'], 'ali');
      expect(expansion.url.queryParameters['vbrname'], 'high');
      // The hs line of the first answer, ali from the expansion.
      expect(lines.map((line) => line.lineLabel), ['hs', 'ali']);
      expect(http.requestCount, 2);
      await site.dispose();
    });

    test('a failing per-CDN request leaves the other lines', () async {
      final (:site, :http) = _site(
        (seen) =>
            seen.url.queryParameters['cdn'] != null ? _resp(500, 'down') : _resp(200, _play(seen, dropBackup: true)),
      );
      final lines = _right(
        await site.capability<LivePlaybackProvider>()!.getLines(
          room: _bareRoom,
          quality: LivePlayQuality.of(label: '高清', qualityId: 'high'),
        ),
      );
      expect(lines.map((line) => line.lineLabel), ['hs']);
      expect(http.requestCount, 2);
      await site.dispose();
    });

    test('the lines carry the lease of their auth_key and the media headers', () async {
      final (:site, http: _) = _site(_api());
      final playback = site.capability<LivePlaybackProvider>()!;
      await playback.getQualities(room: _bareRoom);
      final lines = _right(await playback.getLines(room: _bareRoom, quality: _original));
      final lease = lines.first.lease!;
      expect(lease.expiresAt, DateTime.parse('2026-09-27T16:35:20.000Z'));
      // A 134 s lifetime: a quarter (33.5 s) is below the 60 s lead.
      expect(lease.refreshAt, DateTime.parse('2026-09-27T16:34:46.500Z'));
      expect(lines.first.headers['referer'], 'https://cc.163.com/$_roomId/');
      expect(lines.first.headers['origin'], 'https://cc.163.com');
      await site.dispose();
    });

    test('an offline anchor is content-unavailable (HTTP 410), a 429 throttled', () async {
      final (site: gone, http: _) = _site((seen) => _resp(410, '{"code":"Gone","data":"no live"}'));
      expect(
        _leftOf(await gone.capability<LivePlaybackProvider>()!.getQualities(room: _bareRoom)).runtimeType,
        LiveSiteContentUnavailable,
      );
      await gone.dispose();
      final (site: throttled, http: _) = _site((seen) => _resp(429, 'slow down'));
      expect(
        _leftOf(await throttled.capability<LivePlaybackProvider>()!.getQualities(room: _bareRoom)).runtimeType,
        LiveSiteRateLimitError,
      );
      await throttled.dispose();
    });

    test('a read failure falls back to the room tier list when it carries one (3.x)', () async {
      // Room entry first, on a working transport, so the room carries the
      // channel's tier list.
      final (site: entrySite, http: _) = _site(_api());
      final room = _right(await entrySite.capability<LiveRoomProvider>()!.getRoom(_roomId));
      await entrySite.dispose();
      // Then a broken transport: the play answer fails, the tier list plays.
      final (:site, :http) = _site((seen) => _resp(500, 'down'));
      final qualities = _right(await site.capability<LivePlaybackProvider>()!.getQualities(room: room));
      expect(qualities.map((quality) => quality.qualityId), ['original']);
      expect(qualities.single.label, '原画');
      final lines = _right(await site.capability<LivePlaybackProvider>()!.getLines(room: room, quality: _original));
      // The legacy tier plays its signed redirect playlist, no request, the
      // preferred CDN (ali) first.
      expect(lines, hasLength(2));
      expect(lines[0].url, contains('redirect/video/341438909.m3u8?secret=bac6536f08&auth_key=1790612944-key'));
      expect(lines[0].lease, isNull);
      expect(lines[0].headers['referer'], 'https://cc.163.com/$_roomId/');
      expect(http.requestCount, 1); // the one failed play request.
      await site.dispose();
    });

    test('a read failure without a room tier list rethrows', () async {
      final (:site, http: _) = _site((seen) => _resp(500, 'down'));
      expect(
        _leftOf(await site.capability<LivePlaybackProvider>()!.getQualities(room: _bareRoom)).runtimeType,
        LiveSiteNetworkError,
      );
      await site.dispose();
    });
  });

  group('links', () {
    test('the three room forms canonicalize to the room page', () async {
      final (:site, http: _) = _site(_api());
      final resolver = site.capability<LiveLinkResolver>()!;
      expect(
        _right(
          await resolver.resolve(Uri.parse('https://cc.163.com/341438909/?open=blizzardtv&from=8382&platform=ds')),
        ),
        Uri.parse('https://cc.163.com/341438909/'),
      );
      expect(
        _right(await resolver.resolve(Uri.parse('https://h5.cc.163.com/cc/720953'))),
        Uri.parse('https://cc.163.com/720953/'),
      );
      expect(
        _right(await resolver.resolve(Uri.parse('https://ds.163.com/glive/?ccid=720953'))),
        Uri.parse('https://cc.163.com/720953/'),
      );
      await site.dispose();
    });

    test('a word path of this site is not-found, another site unsupported', () async {
      final (:site, :http) = _site(_api());
      final resolver = site.capability<LiveLinkResolver>()!;
      expect(
        _leftOf(await resolver.resolve(Uri.parse('https://cc.163.com/n/ds_category/mhxy/'))).runtimeType,
        LiveSiteNotFound,
      );
      expect(
        _leftOf(await resolver.resolve(Uri.parse('https://example.com/341438909'))).runtimeType,
        LiveSiteUnsupported,
      );
      expect(http.requestCount, 0);
      await site.dispose();
    });
  });
}
