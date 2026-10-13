/// Douyin endpoints, user agents and protocol constants (ARCHITECTURE.md
/// §7.2: endpoint shapes live here; signing lives in `douyin_sign.dart`).
abstract final class DouyinEndpoints {
  /// Desktop Chrome 134, the UA of the API requests, the one `a_bogus`
  /// encodes and the danmaku handshake's.
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/134.0.0.0 Safari/537.36';

  /// A plain desktop UA for short links (the share page needs no signing).
  static const String shareUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0';

  /// Douyin's web app id.
  static const String aid = '6383';

  /// `version_code` of the danmaku connection.
  static const String versionCode = '180800';

  /// `webcast_sdk_version` of the danmaku connection.
  static const String sdkVersion = '1.0.15';

  /// The app id of a short link's reflow request (the share client's).
  static const String shareAppId = '1128';

  /// Origin of the web player and of every `live.douyin.com` request.
  static const String origin = 'https://live.douyin.com';

  /// Host of the web live pages and the signed webcast API.
  static const String liveHost = 'live.douyin.com';

  /// Host of the www search API and the search pages.
  static const String webHost = 'www.douyin.com';

  /// Host of the unsigned fallbacks (reflow, the captcha-free partition).
  static const String amemvHost = 'webcast.amemv.com';

  /// The two web IM edges, tried in this order.
  static const List<String> danmakuHosts = ['webcast100-ws-web-lq.douyin.com', 'webcast100-ws-web-hl.douyin.com'];

  /// Path of the push socket.
  static const String danmakuPath = '/webcast/im/push/v2/';

  /// Path of the enter (room detail) request.
  static const String enterPath = '/webcast/room/web/enter/';

  /// Path of the per-area room list.
  static const String partitionPath = '/webcast/web/partition/detail/room/v2/';

  /// Path of the reflow request (a broadcast's status and start).
  static const String reflowPath = '/webcast/room/reflow/info/';

  /// Rooms per area page (the platform's own page size).
  static const int areaPageSize = 15;

  /// The home page, whose RSC payload holds the categories and whose
  /// `Set-Cookie` starts an anonymous session.
  static Uri home() => Uri.https(liveHost, '/', {'from_nav': '1'});

  /// The room page of [webRid] (the fallback when enter fails).
  static Uri roomPage(String webRid) => Uri.https(liveHost, '/${Uri.encodeComponent(webRid)}');

  /// The enter (room detail) base; its parameters go through the signer.
  static Uri enter() => Uri.https(liveHost, enterPath);

  /// Enter's parameters for the room [webRid].
  static Map<String, String> enterParams(String webRid) => {
    'app_name': 'douyin_web',
    'enter_from': 'web_live',
    'live_id': '1',
    'web_rid': webRid,
    'is_need_double_stream': 'false',
  };

  /// The signed per-area list base (on [liveHost]).
  static Uri partitionRooms() => Uri.https(liveHost, partitionPath);

  /// The unsigned captcha fallback of the same list, on [amemvHost].
  static Uri amemvPartitionRooms(Map<String, String> params) => Uri.https(amemvHost, partitionPath, params);

  /// Parameters of the per-area list for [area] at [offset], [count] rooms.
  /// [browserName] and [browserVersion] differ between the signed host (the
  /// signer's Edge 125) and the unsigned fallback (Chrome 120).
  static Map<String, String> partitionParams(
    ({String partition, String type}) area, {
    required int count,
    required int offset,
    String enterFrom = 'link_share',
    String browserName = 'Edge',
    String browserVersion = '125.0.0.0',
    int screenWidth = 1980,
  }) => {
    'aid': aid,
    'app_name': 'douyin_web',
    'live_id': '1',
    'device_platform': 'web',
    'language': 'zh-CN',
    'enter_from': enterFrom,
    'cookie_enabled': 'true',
    'screen_width': '$screenWidth',
    'screen_height': '1080',
    'browser_language': 'zh-CN',
    'browser_platform': 'Win32',
    'browser_name': browserName,
    'browser_version': browserVersion,
    'browser_online': 'true',
    'count': '$count',
    'offset': '$offset',
    'partition': area.partition,
    'partition_type': area.type,
    'req_from': '2',
  };

  /// The recommendation feed (unsigned; every request is a new draw).
  static Uri feed() => Uri.https(liveHost, '/webcast/feed/', {
    'aid': aid,
    'app_name': 'douyin_web',
    'need_map': '1',
    'is_draw': '1',
    'inner_from_drawer': '0',
    'enter_source': 'web_homepage_hot_web_live_card',
    'source_key': 'web_homepage_hot_web_live_card',
  });

  /// The broadcast [roomId]'s reflow answer ([appId] 6383 for the API path,
  /// [shareAppId] for a short link's).
  static Uri reflow(String roomId, {String appId = aid, bool verifyFp = false}) => Uri.https(amemvHost, reflowPath, {
    'type_id': '0',
    'live_id': '1',
    'room_id': roomId,
    'sec_user_id': '',
    if (verifyFp) 'verifyFp': '',
    if (appId == aid) 'version_code': '99.99.99',
    'app_id': appId,
  });

  /// Live search (needs a login; anonymous requests answer 2483).
  static Uri liveSearch(String keyword, {required int count, required int offset}) =>
      Uri.https(webHost, '/aweme/v1/web/live/search/', {
        ...searchParams(keyword, count: count, offset: offset),
        'search_source': 'switch_tab',
        'query_correct_type': '1',
        'need_filter_settings': '1',
        'list_type': 'single',
      });

  /// General search, whose body is hex-length framed JSON documents (needs
  /// a login too).
  static Uri generalSearch(String keyword, {required int count, required int offset}) =>
      Uri.https(webHost, '/aweme/v1/web/general/search/stream/', searchParams(keyword, count: count, offset: offset));

  /// The parameters both search endpoints share.
  static Map<String, String> searchParams(String keyword, {required int count, required int offset}) => {
    'device_platform': 'webapp',
    'aid': aid,
    'channel': 'channel_pc_web',
    'search_channel': 'aweme_live',
    'keyword': keyword,
    'offset': '$offset',
    'count': '$count',
    'os_version': '10',
  };

  /// The partitions whose name matches [keyword] (anonymous).
  static Uri partitionSearch(String keyword) =>
      Uri.https(liveHost, '/webcast/web/partition/search/', {'keyword': keyword, 'aid': aid});

  /// The signed-in account (`webcast/user/me/`).
  static Uri account() => Uri.https(liveHost, '/webcast/user/me/', {'aid': aid});

  /// The push socket of broadcast [roomId] as [userId] on [host]. The
  /// [signature] (`DouyinSigner.danmakuSignature`) carries `+` and `/`, so it
  /// goes through the query as a percent-encoded value; [cursor] is the
  /// millisecond the connection asks to start from.
  static Uri danmakuPush(
    String host, {
    required String roomId,
    required String userId,
    required String signature,
    required int cursor,
  }) => Uri(
    scheme: 'wss',
    host: host,
    path: danmakuPath,
    queryParameters: {
      'app_name': 'douyin_web',
      'version_code': versionCode,
      'webcast_sdk_version': sdkVersion,
      'update_version_code': sdkVersion,
      'compress': 'gzip',
      'cursor': 'h-1_t-${cursor}_r-1_d-1_u-1',
      'host': origin,
      'aid': aid,
      'live_id': '1',
      'did_rule': '3',
      'debug': 'false',
      'maxCacheMessageNumber': '20',
      'endpoint': 'live_pc',
      'support_wrds': '1',
      'im_path': '/webcast/im/fetch/',
      'user_unique_id': userId,
      'device_platform': 'web',
      'cookie_enabled': 'true',
      'screen_width': '1920',
      'screen_height': '1080',
      'browser_language': 'zh-CN',
      'browser_platform': 'Win32',
      'browser_name': 'Mozilla',
      'browser_version': userAgent.substring('Mozilla/'.length),
      'browser_online': 'true',
      'tz_name': 'Asia/Shanghai',
      'identity': 'audience',
      'room_id': roomId,
      'need_persist_msg_count': '15',
      'heartbeatDuration': '0',
      'signature': signature,
    },
  );
}
