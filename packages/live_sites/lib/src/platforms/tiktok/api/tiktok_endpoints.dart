import 'package:live_sites/src/platforms/tiktok/parsers/tiktok_link.dart';

/// TikTok's endpoints, headers and wire constants (ARCHITECTURE.md §7.2:
/// endpoint shapes live here; parsing lives in the `parsers/`).
abstract final class TiktokEndpoints {
  /// Website origin.
  static const String origin = 'https://www.tiktok.com';

  /// Origin of `room/info`, the owner lookup of a `share/live` link.
  static const String webcastOrigin = 'https://webcast.tiktok.com';

  /// Desktop Chrome 140, the UA of every TikTok request and stream request.
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/140.0.0.0 Safari/537.36';

  /// The largest answer accepted (12 MiB).
  static const int responseLimit = 12 * 1024 * 1024;

  /// `statusCode` of a user that does not exist (`user_not_found`).
  static const int missingUserCode = 19881007;

  /// The display name, also every room's area: TikTok has no categories.
  static const String siteName = 'TikTok LIVE';

  /// The notice on every room: a TikTok LIVE has no chat here (the reference
  /// adapter ships no danmaku for it), so viewers and entries are what is
  /// shown.
  static const String chatNotice = 'TikTok 直播的评论暂时不能在这里显示。在线人数是正在看的人数，累计是进过直播间的人数。';

  /// The name of the source tier `origin` (the unified rule on quality
  /// names; the site itself calls it `Original`).
  static const String originName = '原画';

  /// Added to the name of an H.265 quality (`720p · H.265`), which is only
  /// picked by hand while "prefer H.264" is on; it also keeps a stored
  /// preference such as 原画 from matching the H.265 twin of a tier.
  static const String h265Suffix = ' · H.265';

  /// Quality names by `stream_data` key, the last resort of the quality name
  /// for a tier the site neither names nor gives a resolution; other keys are
  /// shown upper case.
  static const Map<String, String> qualityNames = {
    'origin': '原始画质',
    'uhd_60': '超清 60 帧',
    'hd_60': '高清 60 帧',
    'uhd': '超清',
    'hd': '高清',
    'sd': '标清',
    'ld': '流畅',
    'auto': '自动',
  };

  /// The most requests a short link typed into search is read with, one per
  /// redirect, each to a TikTok short link. The transport follows the chain
  /// itself; the bound here is what a single answer may carry.
  static const int maxShortLinkHops = 3;

  /// How long before `expire` a pull URL is renewed (at most a quarter of
  /// its lifetime; the site signs them for about 14 days).
  static const Duration leaseLead = Duration(hours: 1);

  /// The largest `stream_data` JSON string read (a container over it is
  /// passed over whole).
  static const int streamDataLimit = 4 * 1024 * 1024;

  /// The room's web page, also where "open in browser" goes and the media
  /// Referer.
  static String roomUrl(String username) => '$origin/@$username/live';

  /// Where "open in browser" goes for room [roomId]: its web page, or null
  /// for a room id that is no username (a stored link is not trusted).
  static String? externalRoomUrl(String roomId) {
    final username = TiktokLink.normalizeUsername(roomId);
    return username == null ? null : roomUrl(username);
  }

  /// The LIVE of [username] (normalized), spelled as the site sends it.
  static Uri userRoomUrl(String username) =>
      Uri.parse('$origin/api-live/user/room/')
          .replace(queryParameters: {'aid': '1988', 'sourceType': '54', 'staleTime': '600000', 'uniqueId': username});

  /// The owner of LIVE room [liveRoomId], spelled as the site sends it.
  static Uri roomInfoUrl(String liveRoomId) =>
      Uri.parse('$webcastOrigin/webcast/room/info/').replace(queryParameters: {'aid': '1988', 'room_id': liveRoomId});

  /// Headers of the API requests: the Referer is the room of [username],
  /// else the LIVE landing page.
  static Map<String, String> requestHeaders({String? username}) => {
    'user-agent': userAgent,
    'accept': 'application/json, text/plain, */*',
    'accept-language': 'en-US,en;q=0.9',
    'origin': origin,
    'referer': username == null ? '$origin/live' : roomUrl(username),
  };

  /// Headers of the media requests, sent with every play line.
  static Map<String, String> mediaHeaders(String username) => {
    'user-agent': userAgent,
    'origin': origin,
    'referer': roomUrl(username),
  };

  /// Whether [host] may serve TikTok pictures and streams: the CDNs the
  /// site's own players accept, each with its subdomains.
  static bool isTrustedHost(String host) {
    final value = host.toLowerCase();
    return _trustedRoots.any((root) => value == root || value.endsWith('.$root'));
  }

  static const List<String> _trustedRoots = [
    'tiktokcdn.com',
    'tiktokcdn-us.com',
    'tiktokcdn-eu.com',
    'tiktokv.com',
    'byteoversea.com',
  ];
}
