/// KilaKila's (克拉克拉) endpoints and constants (3.x's `KilakilaApi`
/// statics): the two hosts of the API, the media CDN, the two timelines, the
/// platform's limits and the one quality.
abstract final class KilakilaEndpoints {
  /// The website: the API host of the timeline, `getRoomInfo` and search.
  static const String origin = 'https://live.kilakila.cn';

  /// Hosts of broadcast pages and `/zhubo/` anchor pages.
  static const Set<String> roomHosts = {'live.kilakila.cn', 'www.hongdoufm.com'};

  /// Host of anchor pages and of the profile API.
  static const String ownerHost = 'live.hongrenshuo.com.cn';

  /// Host of the pull URLs.
  static const String mediaHost = 'pull.live.hongrenshuo.com.cn';

  /// The user agent sent to the API and the media CDN.
  static const String userAgent = 'Mozilla/5.0';

  /// Headers of every API request and of the media. No cookie: anonymous.
  static const Map<String, String> headers = {'referer': '$origin/', 'user-agent': userAgent};

  /// Largest answer accepted (1 MiB).
  static const int responseLimit = 1024 * 1024;

  /// Longest lead before a pull URL's expiry at which it is renewed; at most
  /// a quarter of its lifetime.
  static const Duration leaseLead = Duration(minutes: 10);

  /// Name of the one category.
  static const String categoryName = '克拉克拉';

  /// The two timelines, by `type`: 热门直播 (0) and 萌星推荐 (107, the
  /// rising stars).
  static const Map<String, String> timelines = {'0': '热门直播', '107': '萌星推荐'};

  /// Rows of a native directory page.
  static const int pageSize = 10;

  /// The last timeline page read: the timelines repeat their anchors page
  /// after page, so reading stops here.
  static const int maxPages = 100;

  /// Timeline pages in a row without a new anchor after which the timeline
  /// ends: the hot timeline lists its anchors within about ten pages, then
  /// repeats them for dozens of pages before `isLastPage`.
  static const int maxPagesWithoutNew = 3;

  /// Longest keyword sent to the user search, in UTF-16 code units (a longer
  /// one is cut there).
  static const int keywordLimit = 100;

  /// The one quality: the broadcast's own stream, as FLV and HLS lines that
  /// stand in for each other.
  static const String qualityId = 'original';

  /// See [qualityId].
  static const String qualityName = '原画';

  /// The quality ids as stored before the two transports became lines of one
  /// quality (case-insensitive) → the id of that quality.
  static const Map<String, String> legacyQualityIds = {'flv': qualityId, 'hls': qualityId};

  /// The quality id for [id] as stored before the merge (case-insensitive);
  /// any other id is kept.
  static String qualityIdFromLegacy(String id) => legacyQualityIds[id.trim().toLowerCase()] ?? id.trim();

  static final RegExp _idPattern = RegExp(r'^[1-9][0-9]{0,31}$');

  /// Whether [value] is a uid or broadcast id: 1–32 digits without a leading
  /// zero.
  static bool isId(String value) => _idPattern.hasMatch(value);

  /// The anchor's page, the room's link.
  static String ownerUrl(String uid) => 'https://$ownerHost/index/roomuser/uid/$uid';

  /// The profile API of the anchor [uid].
  static Uri profileUrl(String uid) => Uri.https(ownerHost, '/Tg/personalH5', {'uid': uid});

  /// The broadcast API of [broadcastId].
  static Uri roomInfoUrl(String broadcastId) =>
      Uri.https('live.kilakila.cn', '/LiveRoom/getRoomInfo', {'roomId': broadcastId});

  /// The timeline page [page] of [pageSize] rows of timeline [type].
  static Uri timelineUrl({required int type, required int page, required int pageSize}) => Uri.https(
    'live.kilakila.cn',
    '/pcLive/timeline',
    {'tag': '0', 'type': '$type', 'genderType': '0', 'pageNo': '$page', 'pageSize': '$pageSize'},
  );

  /// The website's user search page of [keyword]; `/p/<page>` after page 1.
  static Uri searchUrl(String keyword, int page) => Uri(
    scheme: 'https',
    host: 'live.kilakila.cn',
    pathSegments: [
      'aboutus',
      'serach',
      'kw',
      keyword,
      if (page > 1) ...['p', '$page'],
    ],
  );

  /// The timeline `type` of an area id: 0 for the recommendations, else a
  /// KilaKila `timeline` area. Null for anything else (a caller error).
  static int? timelineTypeOf(String? areaId) {
    if (areaId == null) return 0;
    final type = int.tryParse(areaId);
    return type != null && timelines.containsKey(areaId) ? type : null;
  }
}
