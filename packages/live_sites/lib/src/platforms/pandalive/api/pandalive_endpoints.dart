/// PandaTV's (팬더티비, Pandalive) endpoints and constants: the API host,
/// the website origin, the request headers, the four API forms, the chat
/// socket, the platform's limits, the two directory areas, the category
/// names and the room notices.
abstract final class PandaliveEndpoints {
  /// The API host.
  static const String apiHost = 'api.pandalive.co.kr';

  /// The website.
  static const String origin = 'https://www.pandalive.co.kr';

  /// Hosts of room links.
  static const Set<String> roomHosts = {'pandalive.co.kr', 'www.pandalive.co.kr', 'm.pandalive.co.kr'};

  /// The API paths.
  /// The path of `live/index`: the directory and the LIVE search.
  static const String directoryPath = '/v1/live/index';

  /// The path of `live/bj_list`: the BJ search.
  static const String broadcasterSearchPath = '/v1/live/bj_list';

  /// The path of `member/bj`: the broadcaster and its broadcast.
  static const String memberPath = '/v1/member/bj';

  /// The path of `live/play`: room entry's playback answer.
  static const String playPath = '/v1/live/play';

  /// The desktop Chrome user agent of every request (3.x's).
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

  /// Request headers standing for [referer]: what the API and the IVS
  /// master alike carry. Amazon IVS refuses playlists and segments without
  /// the website's origin.
  static Map<String, String> headers(String referer) => {
    'user-agent': userAgent,
    'accept': 'application/json, text/plain, */*',
    'accept-language': 'ko-KR,ko;q=0.9,en;q=0.8',
    'origin': origin,
    'referer': referer,
  };

  /// Media headers for broadcaster [userId]: Amazon IVS refuses its
  /// playlists without the website's origin and the live page as referer.
  static Map<String, String> mediaHeaders(String userId) => {
    'user-agent': userAgent,
    'origin': origin,
    'referer': roomUrl(userId),
  };

  /// Largest API answer read (3.x's `responseLimit`, 4 MiB).
  static const int responseLimit = 4 * 1024 * 1024;

  /// Largest master playlist read (3.x's `manifestLimit`, 1 MiB).
  static const int manifestLimit = 1024 * 1024;

  /// Stable platform identity.
  static const String siteId = 'pandalive';

  /// Display name.
  static const String siteName = 'PandaTV';

  /// The id of the public directory (the default).
  static const String publicAreaId = 'public';

  /// The public directory's name.
  static const String publicAreaName = '公开直播';

  /// The id of the new-broadcaster directory (`onlyNewBj=Y`).
  static const String newBroadcasterAreaId = 'newbj';

  /// The new-broadcaster directory's name.
  static const String newBroadcasterAreaName = '新人主播';

  /// The two directory areas, by id.
  static const Map<String, String> areas = {publicAreaId: publicAreaName, newBroadcasterAreaId: newBroadcasterAreaName};

  /// Names of the platform's category codes. PandaTV has no name service,
  /// so the codes themselves are translated; an unknown code is shown as
  /// sent.
  static const Map<String, String> areaNames = {
    'ind': '个人直播',
    'talk': '聊天',
    'music': '音乐',
    'game': '游戏',
    'sports': '体育',
    'etc': '其他',
  };

  /// The name of category code [code] ([areaNames], case-insensitive; an
  /// unknown code as sent, trimmed; empty for none).
  static String areaNameOf(Object? code) {
    final text = code is String ? code.trim() : '';
    return areaNames[text.toLowerCase()] ?? text;
  }

  /// The notice of a public room (key `pandalive_chat_notice`): the two
  /// audience figures are the viewers now and this broadcast's cumulative
  /// viewers.
  static const String chatNotice = '人数分别是正在观看和本场累计观看。';

  /// The notice of an adult room (`pandalive_adult_notice`).
  static const String adultNotice = '成人直播需要登录 PandaTV 并通过本人认证，本应用暂时无法播放。';

  /// The notice of a password room (`pandalive_password_notice`).
  static const String passwordNotice = '这个直播间设了密码，本应用暂时无法播放。';

  /// The notice of a fans-only room (`type` `fan`).
  static const String fansNotice = '这个直播间只对粉丝开放，本应用暂时无法播放。';

  /// The notice of a room with other access conditions
  /// (`pandalive_restricted_notice`).
  static const String restrictedNotice = '这个直播间有观看限制（例如需要登录），本应用暂时无法播放。';

  /// The name of the source rendition (`VIDEO="chunked"`), the unified
  /// quality naming.
  static const String originalQualityName = '原画';

  /// The line label of the IVS variant playlists.
  static const String lineLabel = 'ivs';

  /// How long after `live/play` a variant playlist is renewed: IVS variant
  /// URLs were still served 34 minutes after issue and refused (403) after
  /// 87, and an expired one stops the playlist.
  static const Duration variantRefresh = Duration(minutes: 30);

  /// Rows of a directory page.
  static const int pageSize = 30;

  /// The last page asked for.
  static const int maxPage = 1000;

  /// Rows asked of one search source at most.
  static const int maxSourceSize = 50;

  /// Rows of one answer at most.
  static const int maxRows = 64;

  /// The shortest keyword searched.
  static const int minKeywordLength = 2;

  /// The longest keyword searched.
  static const int maxKeywordLength = 100;

  /// The chat socket (the website's `newChat.node`): a Centrifugo 3 server.
  static const String chatUrl = 'wss://chat-ws.neolive.kr/connection/websocket';

  static final RegExp _userId = RegExp(r'^[A-Za-z0-9_]{1,64}(?:@[A-Za-z0-9_]{2,16})?$');

  /// [value] as a broadcaster id: trimmed, letters, digits and `_`, with an
  /// optional social-login suffix (`@ka`); null for anything else.
  static String? normalizeUserId(Object? value) {
    if (value is! String) return null;
    final id = value.trim();
    return _userId.hasMatch(id) ? id : null;
  }

  /// Whether [value] is a broadcaster id.
  static bool isUserId(String value) => _userId.hasMatch(value.trim());

  /// The live page of [userId]: the room's link and the referer its
  /// requests stand for (`/play/<id>`, the website's current page).
  static String roomUrl(String userId) => Uri.https('www.pandalive.co.kr', '/play/$userId').toString();

  /// The website's search page of source [source] (`bj` or `live`) for
  /// [keyword] (the search requests' referer).
  static String searchReferer(String source, String keyword) =>
      '$origin/search/$source?text=${Uri.encodeQueryComponent(keyword)}';

  /// The form of `live/index` for directory page [page] of [size] rows:
  /// [pageSize] rows by popularity; the new broadcasters add `onlyNewBj=Y`.
  static Map<String, String> directoryForm(int page, int size, {String areaId = publicAreaId}) => {
    'offset': '${(page - 1) * size}',
    'limit': '$size',
    'orderBy': 'hot',
    if (areaId == newBroadcasterAreaId) 'onlyNewBj': 'Y',
  };

  /// The form of the LIVE search (`live/index` by viewers).
  static Map<String, String> liveSearchForm(String keyword, {required int page, required int size}) => {
    'offset': '${(page - 1) * size}',
    'limit': '$size',
    'orderBy': 'user',
    'searchVal': keyword,
  };

  /// The form of the BJ search (`live/bj_list`).
  static Map<String, String> broadcasterSearchForm(String keyword, {required int page, required int size}) => {
    'offset': '${(page - 1) * size}',
    'limit': '$size',
    'searchVal': keyword,
  };

  /// The form of `member/bj`: the broadcaster and its broadcast.
  static Map<String, String> memberForm(String userId) => {'userId': userId, 'info': 'media'};

  /// The form of `live/play` (the website sends it on each visit, which
  /// counts as a view).
  static Map<String, String> playForm(String userId) => {
    'action': 'watch',
    'userId': userId,
    'password': '',
    'shareLinkType': '',
  };
}
