/// LiveMe's endpoints and constants (3.x's `LiveMeApi` statics): the three
/// hosts, the headers every request and the media carry, the platform's
/// limits, its two qualities and the app's default broadcast titles.
abstract final class LivemeEndpoints {
  /// The website: the referer and origin of every request, and the host of
  /// room, anchor and share pages.
  static const String origin = 'https://www.liveme.com';

  /// Host of the guest, search and broadcast APIs.
  static const String apiHost = 'live.liveme.com';

  /// Host of the featured list.
  static const String directoryHost = 'lvapi.liveme.com';

  /// The browser 3.x claimed to be, to the API and the media.
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

  /// Largest answer accepted (8 MiB).
  static const int responseLimit = 8 * 1024 * 1024;

  /// Rows of a native directory page (3.x's directory pager).
  static const int pageSize = 20;

  /// Largest recommendation page size sent; a larger one is cut to it.
  static const int maxRecommendSize = 50;

  /// Largest search page size sent; a larger one is cut to it (the site
  /// answers 20 a page whatever is asked).
  static const int maxSearchSize = 40;

  /// Longest search keyword; a longer one is refused, without a request.
  static const int keywordLimit = 256;

  /// The note on every LiveMe room (3.x's `liveme_chat_notice`): the chat is
  /// not connected, and the three viewer figures are heat, concurrent and
  /// cumulative viewers.
  static const String chatNotice = '这里暂时看不到 LiveMe 直播间的聊天。人数分别是热度、正在观看和累计观看。';

  /// The source quality (21-7): the broadcast's own stream, FLV lines
  /// (`videosource`, then `videosourcemore`) and the HLS line
  /// (`hlsvideosource`).
  static const String sourceQualityId = 'source';

  /// The smooth quality (21-7): FLV lines (`smallsource`, then
  /// `smallsourcemore`).
  static const String smoothQualityId = 'smooth';

  /// The qualities by id, best first.
  static const List<String> qualityIds = [sourceQualityId, smoothQualityId];

  /// The quality names by id.
  static const Map<String, String> qualityNames = {sourceQualityId: '原画', smoothQualityId: '流畅'};

  /// The quality ids as stored before the transports became lines of one
  /// quality (21-7; case-insensitive) → the id of that quality.
  static const Map<String, String> legacyQualityIds = {
    'source-flv': sourceQualityId,
    'hls': sourceQualityId,
    'smooth-flv': smoothQualityId,
  };

  /// The quality id for [id] as stored before the merge (case-insensitive);
  /// any other id is kept.
  static String qualityIdFromLegacy(String id) => legacyQualityIds[id.trim().toLowerCase()] ?? id.trim();

  /// The app's default broadcast titles, one per interface language seen
  /// (2026-09-28): a broadcast whose title is one of them has no title of
  /// its own, and is named by the anchor's name.
  static const Set<String> defaultTitles = {
    'Click for fun!',
    '¡Haz clic para divertirte!',
    'Clique e divirta-se!',
    'Нажмите и веселитесь!',
    'انقر للمتعة!',
  };

  /// The query of the signed `queryinfosimple` POST.
  static const Map<String, String> videoQuery = {'alias': 'liveme', 'tongdun_black_box': '1', 'os': 'web'};

  /// The signed `queryinfosimple` POST.
  static final Uri videoUrl = Uri.https(apiHost, '/live/queryinfosimple', videoQuery);

  static final RegExp _shortId = RegExp(r'^[1-9][0-9]{4,11}$');
  static final RegExp _longId = RegExp(r'^[1-9][0-9]{12,23}$');

  /// Whether [value] is a room id: 5–12 digits, no leading zero.
  static bool isShortId(String value) => _shortId.hasMatch(value);

  /// Whether [value] is a user or video id: 13–24 digits, no leading zero.
  static bool isLongId(String value) => _longId.hasMatch(value);

  /// [raw] when it is a short id (trimmed), else null.
  static String? normalizeShortId(String raw) {
    final value = raw.trim();
    return isShortId(value) ? value : null;
  }

  /// [raw] when it is a user or video id (trimmed), else null.
  static String? normalizeLongId(String raw) {
    final value = raw.trim();
    return isLongId(value) ? value : null;
  }

  /// The room page of [shortId], the room's link.
  static String roomUrl(String shortId) => '$origin/livehot/streaming/$shortId';

  /// Headers of every API request (3.x's `requestHeaders`): the referer is
  /// the room page of [shortId], else the hot list.
  static Map<String, String> headers({String? shortId}) => {
    'user-agent': userAgent,
    'accept': 'application/json, text/plain, */*',
    'accept-language': 'en-US,en;q=0.9',
    'origin': origin,
    'referer': shortId == null ? '$origin/livehot' : roomUrl(shortId),
  };

  /// Headers of the media of room [shortId] (3.x's `mediaHeaders`, which the
  /// play lines carry).
  static Map<String, String> mediaHeaders(String shortId) => {
    'user-agent': userAgent,
    'origin': origin,
    'referer': roomUrl(shortId),
  };

  /// The guest parameters of the API GETs at [now] (3.x's `_guestQuery`).
  static Map<String, String> guestQuery(DateTime now) => {
    'alias': 'liveme',
    'tongdun_black_box': '1',
    'os': 'web',
    '_time': '${now.millisecondsSinceEpoch}',
    'h5': '1',
    'thirdchannel': '6',
  };

  /// A guest API GET at [now]: [path] with [query] over the guest parameters.
  static Uri guest(String path, Map<String, String> query, {required DateTime now}) =>
      Uri.https(apiHost, path, {...guestQuery(now), ...query});

  /// `uid_vid_by_short_id` of [shortId] at [now]: the anchor's user id and
  /// the current broadcast's video id.
  static Uri mappingUrl(String shortId, {required DateTime now}) =>
      guest('/liveme_ent/v1/user/uid_vid_by_short_id', {'short_id': shortId}, now: now);

  /// `user/getinfo` of [userId] at [now].
  static Uri profileUrl(String userId, {required DateTime now}) => guest('/user/getinfo', {'userid': userId}, now: now);

  /// `searchKeyword` of [keyword] at [now]: anchors, live or not.
  static Uri searchUrl(String keyword, {required int page, required int pageSize, required DateTime now}) =>
      guest('/search/searchKeyword', {
        'type': '1',
        'page': '$page',
        'pageSize': '$pageSize',
        'keyword': keyword,
        'tuid': '',
        'uid': '',
        'token': '',
        'androidid': '',
      }, now: now);

  /// The featured list, page [page] of [pageSize] rooms.
  static Uri featuredUrl({required int page, required int pageSize}) => Uri.https(directoryHost, '/live/featurelist', {
    'countryCode': 'GLOBAL',
    'page_index': '$page',
    'page_size': '$pageSize',
    'pid': '3',
    'posid': '3002',
    'h5': '1',
  });
}
