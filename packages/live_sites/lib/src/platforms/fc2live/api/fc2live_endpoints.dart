/// Where FC2 Live answers, and the limits its answers have to fit.
///
/// Everything is a form POST to `live.fc2.com` with the browser's own XHR
/// headers: the platform has no signature, no key and no cookie to make —
/// the only cookie anywhere is the session token of a control socket's
/// handshake ([Fc2LiveEndpoints.orzCookie]).
abstract final class Fc2LiveEndpoints {
  /// The API host of every request.
  static const String host = 'live.fc2.com';

  /// The site's origin, sent with every request and every socket.
  static const String origin = 'https://live.fc2.com';

  /// Desktop Chrome 140: the user agent the site's own player page sends, and
  /// what the captures of 2026-09-27 were taken with.
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/140.0.0.0 Safari/537.36';

  /// The headers of every API request: the XHR the page makes, with the
  /// platform's Japanese-first language.
  static const Map<String, String> headers = {
    'user-agent': userAgent,
    'accept': 'application/json, text/javascript, */*; q=0.01',
    'accept-language': 'ja,en-US;q=0.9,en;q=0.8',
    'origin': origin,
    'referer': '$origin/',
    'x-requested-with': 'XMLHttpRequest',
  };

  /// The form content type the page sends (the transport's own default lacks
  /// the charset, which the answer does not care about but the captures show).
  static const String formContentType = 'application/x-www-form-urlencoded; charset=UTF-8';

  /// The headers of a media request for a channel's playlist: the same agent
  /// and origin, and the channel's own page as the referer (what 3.x's relay
  /// sent — the capture of `S05-master` names the site root instead, and a
  /// refused playlist there is not evidence of this being wrong).
  static Map<String, String> mediaHeaders(String channelId) => {
    'user-agent': userAgent,
    'origin': origin,
    'referer': channelUrl(channelId),
  };

  /// The largest answer accepted, in characters as in bytes: the directory of
  /// every channel on air was 44 KB on 2026-09-27, so this is a guard against
  /// a page of HTML, not a size a real answer comes near.
  static const int responseLimit = 4 * 1024 * 1024;

  /// The longest name, title or description one field may hold.
  static const int textLimit = 65536;

  /// Rooms per directory page (3.x's native page size).
  static const int directoryPageSize = 20;

  /// The largest slice a caller may ask for; a bigger page size is a caller
  /// error rather than a bigger request, as in 3.x.
  static const int maxPageSize = 100;

  /// The most rows the directory answer may hold; more is a changed API.
  static const int maxDirectoryRows = 1000;

  /// How long a channel's `version` may be (it is sent back in the grant).
  static const int versionLimit = 256;

  /// Longest wait for an answer, and for a control's handshake and HLS answer
  /// together (3.x's `defaultRequestTimeout` and `controlStartupTimeout`).
  static const Duration requestTimeout = Duration(seconds: 20);

  /// How long a control's close may take.
  static const Duration closeTimeout = Duration(seconds: 2);

  /// Longest wait for a socket's handshake.
  static const Duration connectTimeout = Duration(seconds: 10);

  /// The path of `allchannellist.php`: every public channel on air.
  static const String directoryPath = '/contents/allchannellist.php';

  /// The path of `memberApi.php`: one channel's state, names, audience and the
  /// `version` a grant needs.
  static const String memberPath = '/api/memberApi.php';

  /// The path of `getControlServer.php`: the control socket of one channel's
  /// session.
  static const String controlPath = '/api/getControlServer.php';

  /// The fields of a channel read (3.x sent these four, all as `1`).
  static Map<String, String> memberFields(String channelId) => {
    'channel': '1',
    'profile': '1',
    'user': '1',
    'streamid': channelId,
  };

  /// The fields of an anonymous grant of [channelId] at [version].
  ///
  /// [clientVersion] is the player's own two-line version string, sent
  /// byte-for-byte as the page sends it (`2.1.0`, a newline, ` [1]`); the
  /// `orz` and `ipv6` fields are the empty strings the page leaves them as.
  static Map<String, String> controlFields({required String channelId, required String version}) => {
    'channel_id': channelId,
    'mode': 'play',
    'orz': '',
    'channel_version': version,
    'client_version': clientVersion,
    'client_type': 'pc',
    'client_app': 'browser_hls',
    'ipv6': '',
  };

  /// The page's client version string, newlines and all.
  static const String clientVersion = '2.1.0\n [1]';

  /// The name of the session cookie a control handshake sends.
  static const String orzCookie = 'l_ortkn';

  /// The channel page of a checked channel number: the room's link, and the
  /// referer of its media requests.
  static String channelUrl(String channelId) => '$origin/$channelId/';

  /// The address a chat connection is nominally given: the grant request of
  /// [channelId] (a fresh grant names the real socket at every handshake).
  static Uri grantAddress(String channelId) => Uri.https(host, controlPath, {'channel_id': channelId});

  /// The channel of a [grantAddress], or null for any other address.
  static String? channelOfGrant(Uri address) {
    if (address.scheme != 'https' ||
        address.host != host ||
        address.path != controlPath ||
        address.queryParameters.keys.length != 1) {
      return null;
    }
    final channel = address.queryParameters['channel_id'] ?? '';
    return isChannelId(channel) ? channel : null;
  }

  /// The longest `url`, `control_token` and `orz_raw` of a grant.
  static const int grantUrlLimit = 2048;

  /// The longest `control_token` of a grant.
  static const int grantTokenLimit = 4096;

  /// The longest `orz_raw` of a grant (and of a cookie value).
  static const int grantOrzLimit = 256;

  /// The largest frame a control socket may send.
  static const int messageLimit = 2 * 1024 * 1024;

  /// The longest playlist address the HLS answer may name.
  static const int playlistLimit = 65536;

  /// The most rows of one playlist family.
  static const int playlistFamilyRows = 32;

  /// The most `targets` of a master playlist, and the longest their list.
  static const int maxTargets = 16;

  /// The longest `targets` list.
  static const int targetsLimit = 128;

  /// The longest of the two media tokens (`c`, `d`) of a playlist.
  static const int mediaTokenLimit = 1024;

  /// How long a grant authorizes its control: about a minute (the site names
  /// no expiry, and ends the socket itself with `control_disconnection 4500`),
  /// so this is when a line is re-resolved rather than a promise the platform
  /// makes.
  static const Duration controlLife = Duration(minutes: 1);

  /// How long a snapshot of every channel on air is reused, measured from when
  /// it arrived: pages after the first come from the same snapshot as the
  /// first, so a room neither repeats between pages nor drops out of them.
  static const Duration snapshotLifetime = Duration(seconds: 20);

  /// The channel number's own shape: 1–12 digits, no leading zero.
  static final RegExp _channelId = RegExp(r'^[1-9]\d{0,11}$');

  /// Whether [value] is a channel number.
  static bool isChannelId(String value) => _channelId.hasMatch(value);

  /// The language prefixes a channel link may carry (`/ja/<channel>/`).
  static const Set<String> locales = {'en', 'es', 'de', 'fr', 'id', 'ja', 'ko', 'pt', 'ru', 'th', 'tw', 'vi', 'zh'};

  /// The one category of the platform, which its areas hang under: FC2 has no
  /// category list, only the site's own channel categories.
  static const String categoryId = 'fc2live';

  /// The name of that category, and the type name of its areas (3.x's site
  /// name).
  static const String categoryName = 'FC2 Live';

  /// The platform's channel categories, by their number, in 3.x's order with
  /// 3.x's names; `all` is the whole directory. `2` also holds category `3`.
  static const Map<String, String> areaNames = {
    'all': '全部公开直播',
    '1': '闲聊',
    '2': '游戏 / 作业',
    '4': '视频',
    '9': '音频',
    '5': '其他',
  };

  /// The category numbers the areas select.
  static const Set<int> areaCategories = {1, 2, 4, 5, 9};

  /// The English names 3.x gave directory cards. The keyword search still
  /// matches them, so a search made under 3.x finds the same rooms.
  static String legacyAreaName(int category) => switch (category) {
    1 => 'Idle Chat',
    2 || 3 => 'Game / Work',
    4 => 'Video',
    5 => 'Other',
    9 => 'Audio',
    _ => categoryName,
  };

  /// The name of the area a channel of [category] belongs to: the catalog name
  /// of the area that holds it, the same for a card and a detail. Categories
  /// outside the catalog (0 and 8 are the site's "unknown", 6 premium, 7
  /// official) have no name.
  static String areaName(int category) => switch (category) {
    1 || 4 || 5 || 9 => areaNames['$category']!,
    2 || 3 => areaNames['2']!,
    _ => '',
  };

  /// The id of [Fc2LiveEndpoints.areaNames]'s "everything on air" area.
  static const String allAreasId = 'all';
}
