import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:live_sites/src/platforms/baidulive/parsers/baidulive_room_parser.dart';

/// Baidu Live's (百度直播) endpoints, ids, links and request bodies (3.x's
/// `BaiduLiveApi` statics and `BaiduLiveLink`): the two hosts, the feed's
/// signed form, the room command's query, the room id and link rules, the
/// platform's limits, its channels and its notice texts.
abstract final class BaiduliveEndpoints {
  /// The website.
  static const String webOrigin = 'https://live.baidu.com';

  /// The PC feed (the directory's one endpoint).
  static final Uri feedUrl = Uri.https('tiebac.baidu.com', '/livefeed/feed');

  /// The host of the room command.
  static const String roomHost = 'mbd.baidu.com';

  /// The path of the room command.
  static const String roomPath = '/searchbox';

  /// The room command's URL of [query].
  static Uri roomUrlOf(Map<String, String> query) => Uri.https(roomHost, roomPath, query);

  /// 3.x's desktop Chrome UA.
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/140.0.0.0 Safari/537.36';

  /// 3.x's API request headers (`apiHeaders`).
  static const Map<String, String> apiHeaders = {
    'user-agent': userAgent,
    'accept': 'application/json, text/plain, */*',
    'origin': webOrigin,
    'referer': '$webOrigin/',
  };

  /// The headers of a feed POST: [apiHeaders] and the form's content type
  /// without a charset, as the website's client sent it.
  static const Map<String, String> feedHeaders = {...apiHeaders, 'content-type': 'application/x-www-form-urlencoded'};

  /// Media request headers of room [roomId] (3.x's `mediaHeaders`, which 3.x
  /// wrote into every room's `httpHeaders` where no player read them): the
  /// FLV hosts (`hls-live.bdstatic.com`) refuse a request without a
  /// `live.baidu.com` Referer (403). These travel on every play line.
  static Map<String, String> mediaHeaders(String roomId) => {
    'user-agent': userAgent,
    'origin': webOrigin,
    'referer': roomUrl(roomId),
  };

  /// The largest answer read (3.x's `responseLimit`, 4 MiB), counted in
  /// characters as 3.x counted it.
  static const int responseLimit = 4 * 1024 * 1024;

  /// 3.x's channels until the first feed page brings the platform's list
  /// (`fallbackCategories`).
  static const List<BaiduliveCategory> fallbackCategories = [
    BaiduliveCategory(id: 'rec', name: '推荐', channelId: 570),
    BaiduliveCategory(id: 'shopping', name: '购物', channelId: 574),
    BaiduliveCategory(id: 'finance', name: '财经', channelId: 611),
    BaiduliveCategory(id: 'health', name: '健康', channelId: 612),
    BaiduliveCategory(id: 'education', name: '教育', channelId: 613),
    BaiduliveCategory(id: 'news', name: '新闻', channelId: 575),
    BaiduliveCategory(id: 'leisure', name: '休闲', channelId: 616),
  ];

  /// Display name (3.x's zh.json `site_baidulive`), also the catalog's name
  /// and a room's area when it has none.
  static const String siteName = '百度直播';

  /// The directory notice's Chinese text (the key [directoryNoticeKey], 3.x's
  /// `baidulive_directory_scope`), written for users; the v2 contract has no
  /// directory-notice seam — the application shows this beside the directory.
  static const String directoryScope =
      '这里是百度直播官网的推荐和各个频道，往下翻会继续加载。搜索只能输入房间号，'
      '或粘贴百度直播的直播间、分享链接，还不能按主播名字搜索。';

  /// The key of the directory notice (3.x's zh.json key).
  static const String directoryNoticeKey = 'baidulive_directory_scope';

  /// The notice of every room (3.x's zh.json key `baidulive_chat_notice`),
  /// written for users: 30-10's text began with "这里暂时看不到百度直播间的
  /// 聊天。"; chat is shown since M5.26.
  static const String chatNotice = '人数是正在观看的人数，主播的粉丝数另外显示。';

  /// The first notice line of a paid, forbidden or banned room (3.x's zh.json
  /// key `baidulive_restricted_notice`): such a room is shown as its state
  /// with the restriction marked (30-5).
  static const String restrictedNotice = '这场直播需要付费观看或受到平台限制，暂时不能在这里播放。';

  /// The last feed page asked for (3.x).
  static const int maxPage = 10000;

  /// Items of a full feed page (3.x: fewer ends the directory).
  static const int fullPage = 10;

  /// The host of the chat's message lists (M5.26).
  static const String messageListHost = 'liveshowstatic.baidu.com';

  /// The wait between two polls of the message lists when the room command
  /// names none (`msg_hls_pull_internal_in_second` was 5 in every recorded
  /// answer).
  static const Duration defaultPullInterval = Duration(seconds: 5);

  // Links and ids -------------------------------------------------------------

  static final RegExp _roomId = RegExp(r'^[1-9]\d{5,19}$');
  static final RegExp _shareCode = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  /// The room page (3.x's `BaiduLiveLink.watchUrl`, the room's link).
  static String roomUrl(String roomId) => '$webOrigin/m/room/$roomId';

  /// [raw] trimmed as a room id (6 to 20 digits, not starting with 0), or
  /// null.
  static String? normalizeRoomId(String raw) {
    final value = raw.trim();
    return _roomId.hasMatch(value) ? value : null;
  }

  /// A room id or a room link (3.x's `BaiduLiveLink.parseRoomId`, which the
  /// search and every room call accepted); null for anything else.
  static String? parseRoomId(String raw) => normalizeRoomId(raw) ?? roomIdFromUrl(raw);

  /// Whether [value] is a room id as [normalizeRoomId] reads one.
  static bool isRoomId(String value) => _roomId.hasMatch(value);

  /// The room of a room link (3.x's `BaiduLiveLink.parseRoomId` for URLs):
  /// https or http (30-8; 3.x took https only) on `live.baidu.com` with the
  /// scheme's default port, without user info or fragment, and
  /// - `/m/room/<id>` (empty segments ignored), or
  /// - `room_id=<id>` on the PC player `/m/media/pclive/pchome/live.html` or
  ///   on a share page `/m/media/multipage/liveshow/index/<code>` (the room
  ///   command's `share_url`).
  ///
  /// Null for anything else, a link that does not decode included (3.x threw).
  static String? roomIdFromUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    final scheme = uri.scheme.toLowerCase();
    final defaultPort = switch (scheme) {
      'https' => 443,
      'http' => 80,
      _ => null,
    };
    if (defaultPort == null ||
        uri.userInfo.isNotEmpty ||
        uri.host.toLowerCase() != 'live.baidu.com' ||
        (uri.hasPort && uri.port != defaultPort) ||
        uri.fragment.isNotEmpty) {
      return null;
    }
    try {
      final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList(growable: false);
      if (segments.length == 3 && segments[0] == 'm' && segments[1] == 'room' && _roomId.hasMatch(segments[2])) {
        return segments[2];
      }
      final roomId = uri.queryParameters['room_id']?.trim();
      if (roomId == null || !_roomId.hasMatch(roomId)) return null;
      if ('/${segments.join('/')}' == '/m/media/pclive/pchome/live.html') return roomId;
      if (segments.length == 6 &&
          segments.take(5).join('/') == 'm/media/multipage/liveshow/index' &&
          _shareCode.hasMatch(segments.last)) {
        return roomId;
      }
      return null;
    } on FormatException {
      return null;
    }
  }

  // Requests ------------------------------------------------------------------

  /// The web constant of the feed signature (3.x's `_feedSecret`).
  static const String _feedSecret = 'CtmXzYPtdE58nCCcvqM0ectyqW3N5rfY';

  /// 3.x's feed signature: md5 of the fields other than `sign`, sorted by
  /// name and joined as `k=v&k=v`, followed by `&` and the web constant.
  static String signFeed(Map<String, String> fields) {
    final keys = fields.keys.where((key) => key != 'sign').toList(growable: false)..sort();
    final canonical = keys.map((key) => '$key=${fields[key]}').join('&');
    return md5.convert(utf8.encode('$canonical&$_feedSecret')).toString();
  }

  /// The signed feed form of [channel] (3.x's `directory`, in its field
  /// order): the first page asks for the banner, the tabs and the feed with a
  /// new session and `refresh_index` 1; a later page continues [sessionId] at
  /// [refreshIndex]. [deviceId] names this client, [now] the timestamp.
  static Map<String, String> feedForm({
    required BaiduliveCategory channel,
    required bool first,
    required String deviceId,
    required DateTime now,
    required String sessionId,
    required int refreshIndex,
  }) {
    final form = <String, String>{
      'appname': 'pclive',
      'sid': '',
      'ua': '320_480_pc_1.0_0',
      'uid': deviceId,
      'timestamp': '${now.millisecondsSinceEpoch ~/ 1000}',
      'source': 'pclive',
      'resource': first ? 'banner,tab,feed' : 'feed',
      'scene': 'pc_channel',
      'session_id': first ? '' : sessionId,
      'refresh_type': first ? '0' : '1',
      'refresh_index': '$refreshIndex',
      'tab': channel.id,
      'channel_id': '${channel.channelId}',
    };
    form['sign'] = signFeed(form);
    return form;
  }

  /// The body of a feed POST: [form] encoded as the website's client encoded
  /// it — empty fields bare (`sid&`), which `Uri(queryParameters:)` writes and
  /// a `key=` form does not.
  static String feedBody(Map<String, String> form) => Uri(queryParameters: form).query;

  /// The query of the room command 371 for [roomId] (3.x's `room`, in its
  /// order): its `data` is JSON naming the room and [deviceId]; [now] is the
  /// cache-busting `_`.
  static Map<String, String> roomQuery(String roomId, {required String deviceId, required DateTime now}) => {
    'cmd': '371',
    'action': 'star',
    'service': 'bdbox',
    'osname': 'pc',
    'data': jsonEncode({
      'data': {'room_id': roomId, 'device_id': deviceId, 'source_type': 0},
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
        'shareTaskInfo': jsonEncode({'room_id': roomId}),
        'share_from': '',
        'ext_params': '',
        'nid': '',
      },
    }),
    'ua': '360_740_ANDROID_0',
    'bd_vid': '',
    'uid': deviceId,
    '_': '${now.millisecondsSinceEpoch}',
  };

  /// The feed's client name (3.x): `pc-<clock>purelivedev`, the clock in base
  /// 36 microseconds; [deviceId] (a test's) replaces it.
  static String feedDevice(String? deviceId, DateTime Function() now) =>
      deviceId ?? 'pc-${now().microsecondsSinceEpoch.toRadixString(36)}purelivedev';

  /// A room command's client name (3.x made a new one per call):
  /// `pc-<clock>baidulive`; [deviceId] replaces it too.
  static String roomDevice(String? deviceId, DateTime Function() now) =>
      deviceId ?? 'pc-${now().microsecondsSinceEpoch.toRadixString(36)}baidulive';
}
