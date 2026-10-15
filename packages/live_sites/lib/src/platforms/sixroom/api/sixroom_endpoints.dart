/// Six Rooms' (六间房, 6.cn) endpoints and constants (the reference's
/// `SixRoomApi` statics): the web origin, the app's mobile API, the areas,
/// the platform's limits, the one quality, and the room's id and link forms.
abstract final class SixroomEndpoints {
  /// The web origin: the homepage, the search and room pages, the web
  /// subarea list and the room page's chat servers.
  static const String origin = 'https://v.6.cn';

  /// The desktop user agent of the homepage, search and room pages.
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

  /// The iOS client user agent of the inroom request and the mobile lists.
  static const String mobileUserAgent = 'ios/7.830 (ios 17.0; ; iPhone 15 (A2846/A3089/A3090/A3092))';

  /// The headers of the homepage, search and room pages.
  static const Map<String, String> webHeaders = {
    'user-agent': userAgent,
    'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'accept-language': 'zh-CN,zh;q=0.9,en;q=0.7',
    'referer': '$origin/',
  };

  /// The headers of the mobile lists: the mobile user agent without a body.
  static const Map<String, String> listHeaders = {
    'user-agent': mobileUserAgent,
    'accept': 'application/json,text/plain,*/*',
    'accept-language': 'zh-CN,zh;q=0.9,en;q=0.7',
    'referer': 'https://ios.6.cn/?ver=8.0.3&build=4',
  };

  /// The headers of the inroom form POST.
  static const Map<String, String> mobileHeaders = {
    ...listHeaders,
    'content-type': 'application/x-www-form-urlencoded',
  };

  /// The headers of the chat servers' request, as the room page's script
  /// sends it (jQuery's JSON call).
  static Map<String, String> chatHeaders(String roomId) => {
    'user-agent': userAgent,
    'accept': 'application/json, text/javascript, */*; q=0.01',
    'accept-language': 'zh-CN,zh;q=0.9,en;q=0.7',
    'referer': link(roomId),
    'x-requested-with': 'XMLHttpRequest',
  };

  /// Largest answer accepted, in UTF-8 bytes (the homepage passes 1 MB).
  static const int responseLimit = 8 * 1024 * 1024;

  /// How long a list read whole (the homepage, a web subarea) serves its
  /// later pages.
  static const Duration directoryCacheLifetime = Duration(seconds: 90);

  /// The platform's name: the one category's name and the areas' parent.
  static const String siteName = '六间房直播';

  /// Rooms per directory page, also asked of the mobile lists.
  static const int pageSize = 30;

  /// The mobile list type of the recommendations: the live rooms of every
  /// area by popularity.
  static const String recommendType = 'special';

  /// The last directory page asked for.
  static const int maxPage = 10000;

  /// The largest page size of the lists and search.
  static const int maxPageSize = 100;

  /// The longest keyword sent; 6.cn itself takes 15 characters.
  static const int maxKeywordLength = 80;

  /// The notice of every room: the audience number is the platform's heat,
  /// not a head count.
  static const String chatNotice = '人数是平台的热度，不是正在观看的人数。';

  /// The notice of a private or black-screen room, before [chatNotice].
  static const String restrictedNotice = '这个六间房直播间是私密房或暂时黑屏，现在不能在这里观看。';

  /// Id of the one quality.
  static const String qualityId = 'flv:source';

  /// The one quality's name; with the resolution and bitrate the label reads
  /// `FLV 原始线路 · 1024x768 · 2652 kbps`.
  static const String qualityName = 'FLV 原始线路';

  /// The one line's label: the FLV host.
  static const String lineLabel = 'wlive';

  /// Host of the one FLV stream.
  static const String mediaHost = 'wlive.6rooms.com';

  /// One of the six areas: its id and name, and where its rooms come from —
  /// a mobile list type, a web subarea, or neither for all rooms (the
  /// homepage).
  static const ({String id, String name, String? mobileType, int? subarea}) _allArea = (
    id: 'all',
    name: '全部',
    mobileType: null,
    subarea: null,
  );

  /// The six areas and their sources. The mobile list has no "all" and
  /// answers `content: []` for 星颜 (`u10`), so 全部 stays the homepage and
  /// 星颜 is the web's subarea 10.
  static const List<({String id, String name, String? mobileType, int? subarea})> areas = [
    _allArea,
    (id: 'song', name: '歌区', mobileType: 'u0', subarea: null),
    (id: 'dance', name: '舞区', mobileType: 'u1', subarea: null),
    (id: 'talk', name: '脱口秀', mobileType: 'u2', subarea: null),
    (id: 'face', name: '星颜', mobileType: null, subarea: 10),
    (id: 'party', name: '派对', mobileType: 'u8', subarea: null),
  ];

  static final RegExp _roomId = RegExp(r'^[1-9]\d{1,11}$');
  static final RegExp _userId = RegExp(r'^[1-9]\d{1,12}$');

  /// Whether [value] is a broadcaster's user id.
  static bool isUserId(String? value) => value != null && _userId.hasMatch(value.trim());

  /// The room of [raw]: a room number (2–12 digits, not starting with 0), or
  /// an http(s) link on `v.6.cn` or `m.6.cn` (no user info, no fragment, the
  /// default ports) whose path is `/<number>` or `/profile/<number>`; null
  /// for anything else.
  static String? roomIdOf(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (_roomId.hasMatch(value)) return value;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        !const {'v.6.cn', 'm.6.cn'}.contains(uri.host.toLowerCase()) ||
        (uri.hasPort && uri.port != 80 && uri.port != 443) ||
        uri.fragment.isNotEmpty) {
      return null;
    }
    final List<String> segments;
    try {
      segments = uri.pathSegments.where((part) => part.isNotEmpty).toList(growable: false);
    } on FormatException {
      // `%FF` decodes to no text.
      return null;
    }
    return switch (segments) {
      [final id] when _roomId.hasMatch(id) => id,
      [final profile, final id] when profile.toLowerCase() == 'profile' && _roomId.hasMatch(id) => id,
      _ => null,
    };
  }

  /// The room page of [roomId], also the room's link.
  static String link(String roomId) => '$origin/$roomId';

  /// The homepage: every live room, in `window.__SMARTY_ALL_VARIABLES__`.
  static final Uri homeUrl = Uri.parse('$origin/');

  /// Page [page] of [size] rooms of the mobile list [type] (`u0`,
  /// `special`; the app's `coop-mobile-getlivelistnew.php`).
  static Uri listUrl(String type, {required int page, required int size}) => Uri.parse('$origin/coop/mobile/index.php')
      .replace(
        queryParameters: {
          'padapi': 'coop-mobile-getlivelistnew.php',
          'av': '3.1',
          'encpass': '',
          'logiuid': '',
          'isnew': '1',
          'size': '$size',
          'p': '$page',
          'type': type,
        },
      );

  /// The web's list of subarea [subarea] (10 is 星颜): every live room of it
  /// in one answer.
  static Uri subareaUrl(int subarea) =>
      Uri.parse('$origin/subareaIndex/getSubareaIndexNew.php').replace(queryParameters: {'subarea': '$subarea'});

  /// The search page for [keyword].
  static Uri searchUrl(String keyword) =>
      Uri.parse('$origin/search.php').replace(queryParameters: {'type': 'use', 'key': keyword});

  /// The room page of [roomId] (for its broadcaster's user id).
  static Uri roomUrl(String roomId) => Uri.parse(link(roomId));

  /// The mobile inroom request (a form POST).
  static final Uri inroomUrl = Uri.parse('$origin/coop/mobile/index.php?padapi=coop-mobile-inroom.php');

  /// The inroom form of [userId]'s room, in the app's field order.
  static Map<String, String> inroomForm(String userId) => {
    'av': '3.1',
    'encpass': '',
    'logiuid': '',
    'project': 'v6iphone',
    'rate': '1',
    'rid': '',
    'ruid': userId,
  };

  /// Where a room's chat servers are asked for, by the broadcaster's user id.
  static Uri chatServersUrl(String userId) =>
      Uri.parse('$origin/room/getChat.php').replace(queryParameters: {'rid': userId});

  /// The FLV stream of a room: `https://wlive.6rooms.com/httpflv/<name>.flv`
  /// when [userId] and [liveId] are ids and [flvTitle] is
  /// `v<userId>-<liveId>`, optionally with `-many`; null otherwise. The URL
  /// is not signed and has no expiry.
  static Uri? mediaUri({required String userId, required String liveId, required String flvTitle}) {
    if (!isUserId(userId) || !isUserId(liveId)) return null;
    if (!RegExp('^v${RegExp.escape(userId)}-${RegExp.escape(liveId)}(?:-many)?\$').hasMatch(flvTitle)) {
      return null;
    }
    return Uri.parse('https://$mediaHost/httpflv/$flvTitle.flv');
  }

  /// The mobile list type of area [areaId] (`song` is `u0`), or null for all
  /// rooms (the homepage) and 星颜 (the web's subarea). An area the platform
  /// does not have is a caller error before this is asked.
  static String? mobileTypeOf(String areaId) => _area(areaId).mobileType;

  /// The web subarea of area [areaId] (星颜 is 10), or null.
  static int? subareaOf(String areaId) => _area(areaId).subarea;

  /// The area record of [areaId], or null when it is not one of the six.
  static ({String id, String name, String? mobileType, int? subarea})? areaOf(String? areaId) {
    if (areaId == null) return null;
    for (final area in areas) {
      if (area.id == areaId.trim()) return area;
    }
    return null;
  }

  static ({String id, String name, String? mobileType, int? subarea}) _area(String areaId) =>
      areaOf(areaId) ?? (throw ArgumentError.value(areaId, 'areaId', 'not a Six Rooms area'));
}
