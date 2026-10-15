/// Kugou Live's (酷狗直播, 繁星) endpoints and constants: the hosts, the
/// request headers, the platform's limits, the area rules and the quality
/// naming.
abstract final class KugouliveEndpoints {
  /// The website, Origin of every request.
  static const String webOrigin = 'https://fanxing.kugou.com';

  /// The host of the room lists, the search and the stream answer.
  static const String apiHost = 'fx1.service.kugou.com';

  /// The host of the room info.
  static const String roomHost = 'service2.fanxing.kugou.com';

  /// The desktop Chrome UA of every request.
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

  /// The request headers, for every request, the home page included.
  static const Map<String, String> apiHeaders = {
    'user-agent': userAgent,
    'accept': 'application/json, text/plain, */*',
    'origin': webOrigin,
    'referer': '$webOrigin/',
  };

  /// Media request headers of room [roomId]. The CDN serves the FLV with and
  /// without them.
  static Map<String, String> mediaHeaders(String roomId) => {
    'user-agent': userAgent,
    'origin': webOrigin,
    'referer': roomUrl(roomId),
  };

  /// The largest answer read (4 MiB).
  static const int responseLimit = 4 * 1024 * 1024;

  /// Display name, also the category, the areas' type and every room's area.
  static const String siteName = '酷狗直播';

  /// The last notice line of every room: the numbers explained.
  static const String chatNotice = '人数是正在观看的人数，没有时显示热度；粉丝数单独显示。';

  /// The first notice line of a room whose stream answer asks for a login.
  static const String restrictedNotice = '这个直播间要登录酷狗才能观看，本应用暂时无法播放。';

  /// The stream answer's `code` for "log in to watch".
  static const int loginRequiredCode = -1;

  /// The area of the recommendations (推荐), listed by the home page too.
  static const String recommendAreaId = '8000';

  /// The area type of the home page's areas.
  static const String areaType = 'official';

  /// The last page asked for.
  static const int maxPage = 10000;

  /// Streamers one search asks for; they are paged locally.
  static const int searchSize = 200;

  /// The largest page of a search.
  static const int maxSearchPageSize = 100;

  /// The longest keyword searched.
  static const int maxKeywordLength = 100;

  /// How long before `txTime` a media URL is renewed.
  static const Duration leaseLead = Duration(minutes: 5);

  /// The areas when the home page lists none.
  static const List<({String id, String name})> fallbackAreas = [
    (id: '8000', name: '推荐'),
    (id: '100001', name: '一起玩'),
    (id: '100002', name: '音乐'),
    (id: '31050', name: '高清'),
    (id: '7024', name: '舞蹈'),
    (id: '1009', name: '颜值'),
    (id: '1001', name: '新秀'),
    (id: '3007', name: '酷次元'),
    (id: '7041', name: '搞笑'),
    (id: '31', name: '国风'),
    (id: '6201', name: '游戏女神'),
    (id: '6007', name: '王者荣耀'),
    (id: '6004', name: '和平精英'),
    (id: '6003', name: '网游竞技'),
  ];

  /// The home page's personal routes: 关注, 我看过的, 我管理的, 我守护的.
  static const Set<String> personalRoutes = {'3001', '3009', '3014', '3015'};

  /// A room number: 3 to 11 digits without a leading zero.
  static final RegExp roomId = RegExp(r'^[1-9]\d{2,10}$');

  /// An area id: 1 to 8 digits.
  static final RegExp areaId = RegExp(r'^\d{1,8}$');

  /// A JSONP callback name.
  static final RegExp callbackName = RegExp(r'^[A-Za-z_$][A-Za-z0-9_$.]*$');

  static const Set<String> _hosts = {'fanxing.kugou.com', 'mfanxing.kugou.com'};

  /// The home page's area links: `/pcindex/category/<id>` with a `title`.
  static final RegExp areaLink = RegExp(
    r'''href=["'](?:https://fanxing\.kugou\.com)?/pcindex/category/(\d{1,8})[^"']*["'][^>]*title=["']([^"']+)["']''',
    caseSensitive: false,
  );

  /// [raw] as a room: a trimmed room number, or a room link; null for
  /// anything else.
  static String? parseRoomId(String raw) {
    final value = raw.trim();
    if (roomId.hasMatch(value)) return value;
    return roomIdFromUrl(value);
  }

  /// The room of a room link: http(s) on the platform's hosts, the default
  /// port, no user info or fragment; the path is one room number, or any
  /// path with a `roomId` query. Null for anything else, a room number alone
  /// included.
  static String? roomIdFromUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        !_hosts.contains(uri.host.toLowerCase()) ||
        (uri.hasPort && uri.port != 80 && uri.port != 443) ||
        uri.fragment.isNotEmpty) {
      return null;
    }
    try {
      final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList(growable: false);
      if (segments.length == 1 && roomId.hasMatch(segments.single)) return segments.single;
      final queryId = uri.queryParameters['roomId']?.trim();
      return queryId != null && roomId.hasMatch(queryId) ? queryId : null;
    } on FormatException {
      // Undecodable escapes (`/%FF`): not a room link.
      return null;
    }
  }

  /// The room page of [roomId].
  static String roomUrl(String roomId) => '$webOrigin/$roomId';

  /// The home page.
  static Uri homeUrl() => Uri.parse('$webOrigin/');

  /// A page of [areaId] (推荐 is `index/list`, another area `index/list_v4`
  /// with its `cid`), the page's parameters in the reference's order.
  static Uri directoryUrl(int page, String areaId) {
    final recommend = areaId == recommendAreaId;
    return Uri.https(
      apiHost,
      recommend ? '/mfanxing-home/h5/cdn/room/index/list' : '/mfanxing-home/h5/cdn/room/index/list_v4',
      {
        'pid': '0',
        'kugouId': '0',
        'doubleLiveFirst': '1',
        'sysVersion': '0',
        'platform': '7',
        'device': 'PureLive-Web',
        'channel': '0',
        'version': '99999',
        'longitude': '0',
        'latitude': '0',
        'appid': '1010',
        'liveTypeFilter': '0',
        'isNew': '0',
        'entranceType': '0',
        'uiMode': '0',
        'page': '$page',
        if (!recommend) 'cid': areaId,
      },
    );
  }

  /// The search of [keyword]: [searchSize] streamers, live or not, answered
  /// as JSONP to [callback].
  static Uri searchUrl(String keyword, String callback) => Uri.https(apiHost, '/pt_search/pcsearch/v1/type_all.jsonp', {
    'keywords': keyword,
    'nums': '$searchSize,0,0,0',
    'callback': callback,
  });

  /// The room info of [roomId].
  static Uri roomInfoUrl(String roomId) =>
      Uri.https(roomHost, '/roomcen/room/web/cdn/getEnterRoomInfo', {'roomId': roomId});

  /// The stream answer of [roomId] (`_` the time in milliseconds).
  static Uri streamUrl(String roomId, {required int millis}) =>
      Uri.https(apiHost, '/video/pc/live/pull/mutiline/streamaddr', {
        'std_rid': roomId,
        'std_plat': '7',
        'std_kid': '0',
        'streamType': '1-2-4-5-8',
        'ua': 'fx-flash',
        'targetLiveTypes': '1-5-6',
        'version': '1000',
        'supportEncryptMode': '1',
        'appid': '1010',
        '_': '$millis',
      });
}
