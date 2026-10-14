/// Huya endpoints, user agents and protocol constants (ARCHITECTURE.md §7.2:
/// endpoint shapes live here; signing lives in the play parser).
abstract final class HuyaEndpoints {
  /// Mobile Chrome/Edge UA (3.x `kUserAgent`): the web API and search
  /// requests. A search without any UA answers 403 `Not allowed`.
  static const String userAgent =
      'Mozilla/5.0 (Linux; Android 11; Pixel 5) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/90.0.4430.91 Mobile Safari/537.36 Edg/117.0.0.0';

  /// Huya's PC client UA: the media requests' default (`hysdkUserAgent`).
  static const String hysdkUserAgent = 'HYSDK(Windows,30000002)_APP(pc_exe&7100004&official)_SDK(trans&2.40.0.6448)';

  /// A desktop Chrome UA for room pages (the alias lookup).
  static const String desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/140.0.0.0 Safari/537.36';

  /// The web origin every API and media request sends.
  static const String origin = 'https://www.huya.com';

  /// The only danmaku endpoint.
  static const String danmakuServer = 'wss://wsapi.huya.com';

  /// The WUP RPC endpoint (`wupui.getHeadLineMessageBoard` and the play-token
  /// calls are POSTed here as raw `application/x-wup` packets).
  static Uri wup() => Uri.https('wup.huya.com', '/');

  /// The area icon of a game id.
  static Uri areaPicture(String areaId) => Uri.https('huyaimg.msstatic.com', '/cdnimage/game/$areaId-MS.jpg');

  /// Room detail / live status (`profileRoom`), [stamp] a millisecond
  /// timestamp past the ~30 s public cache.
  static Uri profileRoom(String roomId, int stamp) => Uri.https('mp.huya.com', '/cache.php', {
    'm': 'Live',
    'do': 'profileRoom',
    'roomid': roomId,
    'showSecret': '1',
    '_': '$stamp',
  });

  /// The areas of one top-level category: `bussType` is `1` (网游), `2`
  /// (单机), `8` (娱乐) or `3` (手游).
  static Uri areaList(String bussType) =>
      Uri.https('live.cdn.huya.com', '/liveconfig/game/bussLive', {'bussType': bussType});

  /// A page of rooms (~120); [gameId] selects an area, its absence is the
  /// recommendation feed.
  static Uri liveList(int page, {String? gameId}) => Uri.https('www.huya.com', '/cache.php', {
    'm': 'LiveList',
    'do': 'getLiveListByPage',
    'tagAll': '0',
    'page': '$page',
    if (gameId != null && gameId.isNotEmpty) 'gameId': gameId,
  });

  /// Rooms (`v=4`) and anchors (`v=1`); [rows] is clamped 1–50, [start] the
  /// offset. A request without a UA is answered 403.
  static Uri search(String keyword, {required int version, required int rows, required int start}) =>
      Uri.https('search.cdn.huya.com', '/', {
        'm': 'Search',
        'do': 'getSearchContent',
        'q': keyword,
        'uid': '0',
        'v': '$version',
        'typ': '-5',
        'livestate': '0',
        'rows': '$rows',
        'start': '$start',
      });

  /// The anonymous viewer login (the source of a signing uid).
  static Uri anonymousLogin() => Uri.https('udblgn.huya.com', '/web/anonymousLogin');

  /// A room page by numeric id or alias.
  static Uri roomPage(String address) => Uri.https('www.huya.com', '/$address');
}
