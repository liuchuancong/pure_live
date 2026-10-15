/// Steam Broadcast's endpoints and constants (the reference's
/// `SteamBroadcastApi` statics): Steam Community, its headers, the address
/// rules of a room id and of a custom address, and the platform's limits.
abstract final class SteambroadcastEndpoints {
  /// Steam Community.
  static const String origin = 'https://steamcommunity.com';

  /// The browser user agent of every request.
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

  /// The largest answer read, in UTF-8 bytes.
  static const int responseLimit = 4 * 1024 * 1024;

  /// The largest HLS master checked, in characters.
  static const int masterLimit = 1024 * 1024;

  /// The platform's name: the category and the area's parent name.
  static const String siteName = 'Steam Broadcasts';

  /// The one area's type.
  static const String areaType = 'community';

  /// The one area's id: the trending broadcasts.
  static const String areaId = 'trending';

  /// The one area's name.
  static const String areaName = '热门社区直播';

  /// The notice of a room: the audience figure is the concurrent viewers.
  static const String chatNotice = '人数是正在观看的人数。';

  /// The notice of a broadcaster whose account may not broadcast.
  static const String restrictedNotice = '这位主播的 Steam 账号目前被限制直播，暂时不能观看。';

  /// The id of the adaptive quality.
  static const String qualityId = 'auto';

  /// The adaptive quality's label.
  static const String qualityLabel = '自适应 HLS';

  /// The one line's id: the CDN host changes between answers
  /// (`cache6-lax1`, `cache7-lax1`), so it is not the line's identity.
  static const String lineId = 'steamcontent';

  /// Broadcasts per directory page (`numperpage`).
  static const int pageSize = 10;

  /// The last directory page asked for.
  static const int maxPage = 10000;

  /// The largest page size of the recommendations.
  static const int maxRecommendSize = 60;

  /// The largest page size of the search; a larger one gives nothing.
  static const int maxSearchSize = 100;

  /// The first 64-bit Steam id of an individual account; a Steam id minus
  /// it is the account id of the mini profile.
  static final BigInt _accountBase = BigInt.parse('76561197960265728');

  static final RegExp _steamId = RegExp(r'^7656119\d{10}$');

  /// Whether [value] is a 64-bit Steam id of an individual account.
  static bool isSteamId(String value) => _steamId.hasMatch(value);

  /// The watch page of [steamId], also the room's link.
  static String link(String steamId) => '$origin/broadcast/watch/$steamId';

  /// The path segments of [raw] when it is an http(s) link of
  /// `steamcommunity.com` (exactly that host, no user info, no fragment,
  /// the default ports; a query allowed), empty segments left out; null for
  /// anything else.
  static List<String>? _communityPath(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        uri.host.toLowerCase() != 'steamcommunity.com' ||
        uri.hasFragment ||
        (uri.hasPort && uri.port != 80 && uri.port != 443)) {
      return null;
    }
    try {
      return uri.pathSegments.where((segment) => segment.isNotEmpty).toList(growable: false);
    } on FormatException {
      return null;
    }
  }

  /// The Steam id of [raw]: a bare id, a watch link
  /// `steamcommunity.com/broadcast/watch/<id>` or a profile link
  /// `steamcommunity.com/profiles/<id>`, without a request; null for
  /// anything else (a custom address `/id/<name>` needs one, see
  /// [vanityOf]).
  static String? steamIdOf(String raw) {
    final value = raw.trim();
    if (isSteamId(value)) return value;
    return switch (_communityPath(value)) {
      ['broadcast', 'watch', final id] || ['profiles', final id] when isSteamId(id) => id,
      _ => null,
    };
  }

  static final RegExp _vanity = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  /// The custom address of a profile link `steamcommunity.com/id/<name>`
  /// (letters, digits, `_` and `-`), or null.
  static String? vanityOf(String raw) => switch (_communityPath(raw)) {
    ['id', final name] when _vanity.hasMatch(name) => name,
    _ => null,
  };

  /// The Steam id of a card's watch link
  /// `steamcommunity.com/broadcast/watch/<id>`, or null.
  static String? watchIdOf(String raw) => switch (_communityPath(raw)) {
    ['broadcast', 'watch', final id] when isSteamId(id) => id,
    _ => null,
  };

  // Requests ------------------------------------------------------------------

  /// The trending broadcasts, page [page] (an HTML fragment).
  static Uri directoryUrl(int page) => Uri.https('steamcommunity.com', '/apps/allcontenthome', {
    'l': 'english',
    'browsefilter': 'trend',
    'appHubSubSection': '13',
    'forceanon': '1',
    'p': '$page',
    'broadcastsoffset': '${(page - 1) * pageSize}',
    'numperpage': '$pageSize',
  });

  /// The watch page of [steamId].
  static Uri watchUrl(String steamId) => Uri.parse(link(steamId));

  /// `getbroadcastmpd` of [steamId]'s current broadcast.
  static Uri mpdUrl(String steamId) => Uri.https('steamcommunity.com', '/broadcast/getbroadcastmpd/', {
    'broadcastid': '0',
    'steamid': steamId,
    'viewertoken': '0',
    'sessionid': '',
  });

  /// `getbroadcastinfo` of [steamId]'s current broadcast (the watch page
  /// asks it for the title, game and viewers).
  static Uri infoUrl(String steamId) => Uri.https('steamcommunity.com', '/broadcast/getbroadcastinfo/', {
    'steamid': steamId,
    'broadcastid': '0',
    'location': '5',
  });

  /// The mini profile of [steamId]: its name and avatar.
  static Uri profileUrl(String steamId) =>
      Uri.https('steamcommunity.com', '/miniprofile/${BigInt.parse(steamId) - _accountBase}/json');

  /// The XML of the profile at the custom address [vanity].
  static Uri vanityUrl(String vanity) => Uri.https('steamcommunity.com', '/id/$vanity/', {'xml': '1'});

  // Headers -------------------------------------------------------------------

  /// The headers of the directory.
  static const Map<String, String> directoryHeaders = {
    'user-agent': userAgent,
    'accept': 'text/html, */*; q=0.8',
    'accept-language': 'en-US,en;q=0.9',
    'referer': '$origin/?subsection=broadcasts',
    'x-requested-with': 'XMLHttpRequest',
  };

  /// The headers of the watch page, or with [json] of `getbroadcastmpd`,
  /// `getbroadcastinfo` and the mini profile.
  static Map<String, String> roomHeaders(String steamId, {bool json = false}) => {
    'user-agent': userAgent,
    'accept': json ? 'application/json, text/javascript, */*; q=0.8' : 'text/html,application/xhtml+xml,*/*;q=0.8',
    'accept-language': 'en-US,en;q=0.9',
    'referer': link(steamId),
    if (json) 'x-requested-with': 'XMLHttpRequest',
  };

  /// The headers of a profile's XML (a custom address's Steam id).
  static const Map<String, String> xmlHeaders = {
    'user-agent': userAgent,
    'accept': 'text/xml, application/xml, */*; q=0.8',
    'accept-language': 'en-US,en;q=0.9',
  };

  /// What is sent for the HLS master checked on room entry; the player sends
  /// none of them, so play lines carry none either.
  static Map<String, String> mediaHeaders(String steamId) => {
    'user-agent': userAgent,
    'origin': origin,
    'referer': link(steamId),
  };
}
