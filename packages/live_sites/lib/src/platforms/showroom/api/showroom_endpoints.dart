/// SHOWROOM's endpoints and constants (3.x's `ShowroomApi` statics): the web
/// and API origin, the request and media headers, the room key grammar, the
/// reserved first path segments, and the local page sizes.
abstract final class ShowroomEndpoints {
  /// Web and API origin.
  static const String origin = 'https://www.showroom-live.com';

  /// The API host every request goes to.
  static const String host = 'www.showroom-live.com';

  /// Desktop Chrome 140, the UA the reference sent with every request.
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/140.0.0.0 Safari/537.36';

  /// The API request headers.
  static const Map<String, String> headers = {
    'user-agent': userAgent,
    'accept': 'application/json, text/plain, */*',
    'referer': '$origin/',
  };

  /// The media request headers, set on every room and on every play line.
  static const Map<String, String> mediaHeaders = {'user-agent': userAgent, 'referer': '$origin/'};

  /// `areaType` of the genres.
  static const String areaType = 'genre';

  /// Name of the one category (and `parentAreaName` of its genres).
  static const String categoryName = 'SHOWROOM';

  /// Rooms per directory page (the reference's `getDirectoryPage`): the
  /// directory and the area pages are slices of the snapshot of this size.
  static const int directoryPageSize = 30;

  /// Largest slice served of the recommendations and of the search; a larger
  /// page size gives nothing.
  static const int maxPageSize = 100;

  /// The `live/onlives` snapshot is reused this long after it arrived.
  static const Duration snapshotLifetime = Duration(seconds: 30);

  /// A room's gift table (`live/gift_list`) is reused this long.
  static const Duration giftListLifetime = Duration(minutes: 30);

  /// How long a failed gift table is not asked for again.
  static const Duration giftRetryAfter = Duration(minutes: 5);

  /// Rooms whose gift tables are kept; the least recent goes first.
  static const int giftListRooms = 16;

  /// A public room key (`room_url_key`).
  static final RegExp keyPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

  /// A room id as links write it.
  static final RegExp linkRoomIdPattern = RegExp(r'^[1-9][0-9]{0,18}$');

  /// First path segments that are site pages, not room keys: the reference's
  /// list, plus the pages it took for keys and failed on.
  static const Set<String> reservedPaths = {
    'api',
    'room',
    'event',
    'ranking',
    'search',
    'login',
    'register',
    'mypage',
    'premium_live',
    'r',
    'onlive',
    'campaign',
    'about',
    'lottery',
  };

  /// `sort` of 自动, the adaptive master: below every `hls` tier, so it is
  /// listed last.
  static const int autoSort = -1;

  /// Whether [host] is the site itself or a subdomain (links).
  static bool isSiteHost(String host) => host == 'showroom-live.com' || host.endsWith('.showroom-live.com');

  /// Whether [host] may serve media: the site's hosts and the TX live CDN's.
  static bool isTrustedHost(String host) =>
      isSiteHost(host) || host == 'showroom-txlive.com' || host.endsWith('.showroom-txlive.com');

  /// The `live/onlives` snapshot.
  static Uri onlivesUrl() => Uri.https(host, '/api/live/onlives');

  /// The room id of the room key [key] (`room/status`).
  static Uri roomStatusUrl(String key) => Uri.https(host, '/api/room/status', {'room_url_key': key});

  /// The profile of room [roomId] (`room/profile`).
  static Uri roomProfileUrl(String roomId) => Uri.https(host, '/api/room/profile', {'room_id': roomId});

  /// Whether room [roomId] is live, and its comment arguments (`live/live_info`).
  static Uri liveInfoUrl(String roomId) => Uri.https(host, '/api/live/live_info', {'room_id': roomId});

  /// The stream rows of room [roomId] (`live/streaming_url`).
  static Uri streamingUrlUrl(String roomId) =>
      Uri.https(host, '/api/live/streaming_url', {'room_id': roomId, 'abr_available': '1'});

  /// The gift table of room [roomId] (`live/gift_list`).
  static Uri giftListUrl(String roomId) => Uri.https(host, '/api/live/gift_list', {'room_id': roomId});

  /// The profile page of room [roomId]; null when [roomId] is not a room id
  /// as links write it (the reference's "open in browser" address).
  static String? roomUrl(String roomId) {
    final id = roomId.trim();
    return linkRoomIdPattern.hasMatch(id) ? '$origin/room/profile?room_id=$id' : null;
  }

  /// The public page of the room key [key].
  static String roomKeyUrl(String key) => '$origin/r/$key';
}
