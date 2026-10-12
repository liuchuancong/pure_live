import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/douyin/danmaku/douyin_danmaku.dart';
import 'package:live_sites/src/platforms/douyin/danmaku/douyin_session.dart';
import 'package:live_sites/src/platforms/douyin/danmaku/douyin_sign.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_catalog.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_parser.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_sign.dart';

/// The Douyin adapter: the webcast enter flow, the recommendation feed, the
/// partition directory and live/general search, with `a_bogus` signing.
///
/// Requests carry an anonymous `ttwid` cookie, fetched once from the home page
/// and kept for the adapter's life; the partition directory signs with
/// [signer] (the `a_bogus` web cipher), the feed and the search do not. The
/// room-page React fallback, the reflow-by-room-id deep link and the captcha's
/// `webcast.amemv.com` fallback are not ported.
final class DouyinSite with SiteRoomGuard implements LiveSite, LiveAreaCatalog, LiveDanmakuCapability {
  /// A site over [http]; [signer] signs query parameters (default: the full
  /// `a_bogus` signer for [DouyinParser]'s UA).
  new({required this.http, DouyinSigner? signer})
    : signer = signer ?? DouyinWebSigner(userAgent: DouyinParser.apiHeaders['user-agent']!).signedUrl;

  /// The HTTP transport.
  final LiveHttp http;

  /// The request signer seam.
  final DouyinSigner signer;

  static const String _live = 'live.douyin.com';
  static final Uri _homeUrl = Uri.https(_live, '/', {'from_nav': '1'});

  /// The anonymous `ttwid` cookie, fetched once.
  String? _anonCookie;

  /// Rooms the recommendation draws already delivered since page 1.
  final Set<String> _recommended = {};

  @override
  String get siteId => SiteIds.douyin;

  @override
  String get id => SiteIds.douyin;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.douyin, displayName: '抖音直播', homeUrl: 'https://live.douyin.com');

  /// The areas of the home page's React payload (ids are `id_str,type`). The
  /// home page is also where the anonymous `ttwid` is kept, so it is fetched
  /// once here.
  @override
  Future<List<LiveArea>> getAreas() async {
    final response = await http.send(LiveRequest.get(_homeUrl, headers: _apiHeaders(_anonCookie ?? ''), site: id));
    _keepCookie(response);
    return DouyinCatalog.areas(response.text, status: response.statusCode, headers: response.headers);
  }

  /// A page of the recommendation feed: every request is a fresh draw; a later
  /// page keeps drawing (at most three) until it holds fifteen rooms not
  /// already delivered, and an empty draw ends the list.
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    if (page <= 1) _recommended.clear();
    final rooms = <LiveRoom>[];
    for (var draws = 0; draws < 3 && rooms.length < 15; draws++) {
      final List<LiveRoom> fresh;
      try {
        fresh = await _draw();
      } on SiteError {
        if (rooms.isEmpty) rethrow;
        break;
      }
      if (fresh.isEmpty) break;
      rooms.addAll(fresh);
    }
    return LivePage(items: rooms, hasMore: rooms.isNotEmpty, nextPage: rooms.isEmpty ? null : page + 1);
  }

  /// An area's rooms: fifteen from `(page - 1) × 15`, signed with `a_bogus`.
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    final partition = DouyinCatalog.partition(area.id);
    final number = page < 1 ? 1 : page;
    final offset = (number - 1) * 15;
    final cookie = await _cookie();
    final response = await http.send(
      LiveRequest.get(
        signer(Uri.https(_live, '/webcast/web/partition/detail/room/v2/'), {
          'aid': DouyinParser.aid,
          'app_name': 'douyin_web',
          'live_id': '1',
          'device_platform': 'web',
          'language': 'zh-CN',
          'enter_from': 'link_share',
          'cookie_enabled': 'true',
          'screen_width': '1980',
          'screen_height': '1080',
          'browser_language': 'zh-CN',
          'browser_platform': 'Win32',
          'browser_name': 'Edge',
          'browser_version': '125.0.0.0',
          'browser_online': 'true',
          'count': '15',
          'offset': '$offset',
          'partition': partition.partition,
          'partition_type': partition.type,
          'req_from': '2',
        }),
        headers: _apiHeaders(cookie),
        site: id,
      ),
    );
    final result = DouyinCatalog.partitionRooms(
      response.text,
      offset: offset,
      areaName: area.name,
      status: response.statusCode,
      headers: response.headers,
    );
    return LivePage(items: result.rooms, hasMore: result.hasMore, nextPage: result.hasMore ? number + 1 : null);
  }

  /// A live search of [keyword]: the live search, then the general search
  /// (whose body is chunked); the first that answers wins. The tree's room
  /// identity is the web rid, so a keyword is searched, not resolved to a room.
  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    final text = keyword.trim();
    if (text.isEmpty) return const LivePage<LiveRoom>(items: []);
    final number = page < 1 ? 1 : page;
    final offset = (number - 1) * 30;
    final cookie = await _cookie();
    final headers = _searchHeaders(cookie);
    for (final (path, extra) in [
      (
        '/aweme/v1/web/live/search/',
        const {
          'search_source': 'switch_tab',
          'query_correct_type': '1',
          'need_filter_settings': '1',
          'list_type': 'single',
        },
      ),
      ('/aweme/v1/web/general/search/stream/', const <String, String>{}),
    ]) {
      try {
        final response = await http.send(
          LiveRequest.get(
            Uri.https('www.douyin.com', path, {
              'device_platform': 'webapp',
              'aid': DouyinParser.aid,
              'channel': 'channel_pc_web',
              'search_channel': 'aweme_live',
              ...extra,
              'keyword': text,
              'offset': '$offset',
              'count': '30',
              'os_version': '10',
            }),
            headers: headers,
            site: id,
          ),
        );
        final rooms = DouyinCatalog.searchRooms(response.text, status: response.statusCode, headers: response.headers);
        if (rooms.isNotEmpty) {
          return LivePage(items: rooms, hasMore: true, nextPage: number + 1);
        }
      } on SiteError {
        continue;
      }
    }
    return const LivePage<LiveRoom>(items: []);
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _enter(room.roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    return DouyinParser.qualities(room.data);
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    return DouyinParser.playLines(room.data, qualityId: quality.quality?.toString(), webRid: room.roomId);
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _enter(room.roomId);
    return room.mergeFrom(fresh);
  }

  Future<List<LiveRoom>> _draw() async {
    final cookie = await _cookie();
    final response = await http.send(
      LiveRequest.get(
        Uri.https(_live, '/webcast/feed/', {
          'aid': DouyinParser.aid,
          'app_name': 'douyin_web',
          'need_map': '1',
          'is_draw': '1',
          'inner_from_drawer': '0',
          'enter_source': 'web_homepage_hot_web_live_card',
          'source_key': 'web_homepage_hot_web_live_card',
        }),
        headers: _apiHeaders(cookie),
        site: id,
      ),
    );
    final rooms = DouyinCatalog.feed(response.text, status: response.statusCode, headers: response.headers);
    return [
      for (final room in rooms)
        if (_recommended.add(room.roomId)) room,
    ];
  }

  /// The API headers for [cookie]: the adapter's, with the cookie when there is
  /// one.
  Map<String, String> _apiHeaders(String cookie) => {
    ...DouyinParser.apiHeaders,
    'referer': DouyinCatalog.origin,
    if (cookie.isNotEmpty) 'cookie': cookie,
  };

  /// The headers of the web client's search requests.
  Map<String, String> _searchHeaders(String cookie) => {
    'user-agent': DouyinParser.apiHeaders['user-agent']!,
    'accept': 'application/json, text/plain, */*',
    'accept-language': 'zh-CN,zh;q=0.9',
    'referer': 'https://www.douyin.com/',
    'origin': 'https://www.douyin.com',
    if (cookie.isNotEmpty) 'cookie': cookie,
  };

  /// The anonymous `ttwid` cookie, fetched from the home page once and kept.
  Future<String> _cookie() async => _anonCookie ??= await _bootstrap();

  Future<String> _bootstrap() async {
    final response = await http.send(LiveRequest.get(_homeUrl, headers: DouyinParser.apiHeaders, site: id));
    return _anonymousCookie(response.headers) ?? '';
  }

  static String? _anonymousCookie(Map<String, String> headers) {
    final value = headers['set-cookie'] ?? '';
    final ttwid = RegExp(r'ttwid=([^;,\s]+)').firstMatch(value)?.group(1);
    if (ttwid == null) return null;
    final uifid = RegExp(r'UIFID_TEMP=([^;,\s]+)').firstMatch(value)?.group(1);
    return uifid == null ? 'ttwid=$ttwid' : 'ttwid=$ttwid; UIFID_TEMP=$uifid';
  }

  /// Keeps a home page's anonymous cookie when none was fetched yet.
  void _keepCookie(LiveResponse response) => _anonCookie ??= _anonymousCookie(response.headers) ?? '';

  Future<LiveRoom> _enter(String webRid) async {
    final cookie = await _cookie();
    final url = signer(Uri.https(_live, '/webcast/room/web/enter/'), {
      'app_name': 'douyin_web',
      'enter_from': 'web_live',
      'live_id': '1',
      'web_rid': webRid,
      'is_need_double_stream': 'false',
    });
    final response = await http.send(LiveRequest.get(url, headers: _apiHeaders(cookie), site: id));
    return DouyinParser.enter(response.text, webRid: webRid, status: response.statusCode);
  }

  /// The room's chat: a fresh enter brings this broadcast's numeric room id (the
  /// web IM channel's name) in [LiveRoom.danmakuData]; the visitor id is generated
  /// per connect ([DouyinSign.visitorId]) and the socket is signed and opened by
  /// [DouyinDanmakuSession.connect].
  @override
  Future<LiveDanmakuSession> connect(LiveRoom room) async {
    guardRoom(room);
    final detail = await _enter(room.roomId);
    final numeric = detail.danmakuData;
    if (numeric is! String || numeric.isEmpty) {
      throw SiteNotFoundError('douyin ${room.roomId}: no broadcast room id');
    }
    final args = DouyinDanmakuArgs(webRid: room.roomId, roomId: numeric, userId: DouyinSign.visitorId());
    return await DouyinDanmakuSession.connect(args);
  }
}
