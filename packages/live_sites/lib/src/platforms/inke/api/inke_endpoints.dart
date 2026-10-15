/// Inke's (映客) endpoints and constants (3.x's `InkeApi` statics): the
/// website and the two API hosts, the headers every request and the media
/// carry, the platform's limits, its showcases, the two qualities and the
/// room links.
abstract final class InkeEndpoints {
  /// The website: the `Origin` of every request, and with a slash its
  /// `Referer`.
  static const String origin = 'https://www.inke.cn';

  /// Host of the website API (the showcases).
  static const String webApiHost = 'webapi.busi.inke.cn';

  /// Host of the app API (the hot list and the current broadcast).
  static const String appApiHost = 'service.inke.cn';

  /// The user agent sent to the API and the media CDN.
  static const String userAgent = 'Mozilla/5.0';

  /// Headers of the API requests and of the media. No cookie: anonymous,
  /// like the reference site.
  static const Map<String, String> headers = {'referer': '$origin/', 'origin': origin, 'user-agent': userAgent};

  /// Largest answer accepted, in bytes (1 MiB).
  static const int responseLimit = 1024 * 1024;

  /// `live_share_pc`'s "当前用户无直播" (also for a uid that does not
  /// exist): offline, on that endpoint only.
  static const int noLiveCode = 1099999920;

  /// The one category the areas sit under.
  static const String categoryId = 'inke';

  /// See [categoryId].
  static const String categoryName = '映客';

  /// The website's top list (`Live_top_pc`, 8 slots), the first area: the
  /// recommendations are the app's hot list. Its id is the endpoint's name,
  /// which no channel key can be (they are alphanumeric).
  static const String topAreaId = 'Live_top_pc';

  /// See [topAreaId].
  static const String topAreaName = '官网推荐';

  /// The title the platform gives a broadcast its anchor did not name
  /// ("正在直播中"; seen in `live_share_pc`'s `live_name` and the app's
  /// `name`). A stand-in, so it reads as no title: the nickname stands in
  /// for any untitled broadcast.
  static const String placeholderTitle = '正在直播中';

  /// The showcases searched for a pull URL, in order (the reference's
  /// fallback of the H.264 line).
  static const List<String> showcasePaths = ['Live_top_pc', 'Live_hot_pc', 'Live_channel_pc'];

  /// Host of the Wangsu pull URLs (`live-pull-ws`), the H.264 transcode.
  static const String pullHostWs = 'live-pull-ws.ikstatic.cn';

  /// Host of the Zego pull URLs (`live-pull-zego`), the original stream.
  static const String pullHostZego = 'live-pull-zego.ikstatic.cn';

  /// The one quality every live broadcast plays: the Wangsu FLV, an H.264
  /// transcode.
  static const String flvQualityId = 'flv';

  /// See [flvQualityId].
  static const String flvQualityLabel = 'FLV';

  /// The anchor's original stream, the Zego FLV (HEVC), when the app gives
  /// it. Ranked above the FLV only when "prefer H.264" is off.
  static const String originQualityId = 'origin';

  /// See [originQualityId].
  static const String originQualityLabel = '原画';

  /// Line label of the Wangsu CDN (`live-pull-ws`).
  static const String lineLabel = 'ws';

  /// Line label of the Zego CDN (`live-pull-zego`).
  static const String zegoLineLabel = 'zego';

  /// How long before a pull URL expires it is renewed, at most a quarter of
  /// its lifetime.
  static const Duration leaseLead = Duration(minutes: 10);

  /// Last search page asked for (a larger one is refused).
  static const int maxSearchPage = 10000;

  /// Largest search page size served; a larger one is refused.
  static const int maxSearchSize = 60;

  /// Longest keyword searched (a longer one is refused).
  static const int maxKeywordLength = 100;

  /// Most channels of `Live_channel_pc` (and groups of `Live_hot_pc`) read.
  static const int maxChannels = 100;

  /// Most rows of a showcase list read.
  static const int maxRows = 1000;

  static final RegExp _idPattern = RegExp(r'^[1-9][0-9]{0,17}$');

  static final RegExp _tabKey = RegExp(r'^[a-zA-Z0-9]{1,64}$');

  static final RegExp _shareHost = RegExp(r'^mlive[0-9]*\.inke\.cn$');

  static final RegExp _broadcastId = RegExp(r'^[0-9]{1,32}$');

  /// Whether [value] is a uid (the room) or a broadcast id: 1-18 digits
  /// without a leading zero.
  static bool isId(String value) => _idPattern.hasMatch(value);

  /// Whether [value] is a channel `tab_key`: 1-64 alphanumeric characters.
  static bool isChannelKey(String value) => _tabKey.hasMatch(value);

  /// The website API's `<path>` with [query].
  static Uri webUrl(String path, [Map<String, String>? query]) => Uri.https(webApiHost, '/web/$path', query);

  /// The app API's `<path>` with [query].
  static Uri appUrl(String path, [Map<String, String>? query]) => Uri.https(appApiHost, '/api/live/$path', query);

  /// The website's top list (`Live_top_pc`).
  static final Uri topUrl = webUrl(topAreaId);

  /// The website's hot showcases (`Live_hot_pc`), the fallback's second
  /// stop.
  static final Uri hotPcUrl = webUrl('Live_hot_pc');

  /// The website's channels (`Live_channel_pc`), the catalog and the
  /// fallback's last stop.
  static final Uri channelsUrl = webUrl('Live_channel_pc');

  /// The app's hot list (`simpleall`), the recommendations.
  static final Uri hotUrl = appUrl('simpleall');

  /// The showcase [path] of the fallback lookup ([showcasePaths]), as a URL.
  static Uri showcaseUrl(String path) => webUrl(path);

  /// The website's room of [uid] (`live_share_pc`).
  static Uri shareUrl(String uid) => webUrl('live_share_pc', {'uid': uid});

  /// The app's current broadcast of [uid] (`now_publish`).
  static Uri publishUrl(String uid) => appUrl('now_publish', {'id': uid});

  /// The room's web page; with [liveId] the broadcast's.
  static String roomUrl(String uid, {String? liveId}) =>
      '$origin/liveroom/index.html?uid=$uid${liveId == null ? '' : '&id=$liveId'}';

  /// The uid of an Inke room link, without any request:
  ///
  /// - a web room page `https://www.inke.cn/liveroom/index.html?uid=…`
  ///   (hosts `inke.cn`, `www.inke.cn`, `inke.com`, `www.inke.com`);
  /// - an app share page `https://mlive2.inke.cn/app/…?uid=…` (an
  ///   `mlive<n>.inke.cn` host and an `/app/` path).
  ///
  /// Both need http(s), the default port, no user info and exactly one `uid`
  /// that is a uid. Null for anything else.
  static String? roomIdFromUri(Uri? uri) {
    if (uri == null) return null;
    return _webRoomUid(uri) ?? (_isShareHost(uri) && uri.path.startsWith('/app/') ? _uidOf(uri) : null);
  }

  /// Whether [host] belongs to Inke: a room or share host, or a subdomain of
  /// either domain.
  static bool isOurHost(String host) =>
      _isRoomHost(host) || _isShareHostOf(host) || host.endsWith('.inke.cn') || host.endsWith('.inke.com');

  /// The canonical room page of the room link [uri] for the uid [uid] it
  /// names: the web page, keeping the page's single numeric broadcast id
  /// when the link carries one (an app share page never keeps one).
  static Uri canonicalRoomUrl(Uri uri, String uid) {
    String? liveId;
    if (_isRoomHost(uri.host) && uri.path == '/liveroom/index.html') {
      try {
        final ids = uri.queryParametersAll['id'];
        if (ids != null && ids.length == 1 && _broadcastId.hasMatch(ids.single)) liveId = ids.single;
      } on FormatException {
        // A malformed link canonicalizes to the room page alone.
      }
    }
    return Uri.parse(roomUrl(uid, liveId: liveId));
  }

  static String? _webRoomUid(Uri uri) =>
      _isRoomHost(uri.host) && uri.path == '/liveroom/index.html' ? _uidOf(uri) : null;

  static bool _isRoomHost(String host) => const {'inke.cn', 'www.inke.cn', 'inke.com', 'www.inke.com'}.contains(host);

  static bool _isShareHost(Uri uri) => _isShareHostOf(uri.host);

  static bool _isShareHostOf(String host) => _shareHost.hasMatch(host);

  static String? _uidOf(Uri uri) {
    if ((uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80))) {
      return null;
    }
    try {
      final values = uri.queryParametersAll['uid'];
      if (values == null || values.length != 1) return null;
      final uid = values.single.trim();
      return isId(uid) ? uid : null;
    } on FormatException {
      return null;
    }
  }
}
