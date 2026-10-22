import 'package:live_sites/src/models/area/live_area/live_area.dart';

const _site = '17live';

/// 17LIVE (イチナナ) endpoints, headers and protocol constants
/// (ARCHITECTURE.md §7.2: endpoint shapes live here; parsing lives in
/// `parsers/`).
///
/// The platform is anonymous and public: no cookie, no signature, no account.
/// A room is the broadcaster's fixed `liveStreamID` (the owner's
/// `userInfo.roomID`), kept as asked for; the broadcaster's `userID` is a UUID
/// and names the pull streams, which carry no signature and do not expire.
/// Requests follow no redirect — `live_net` has no redirect switch, so a 3xx
/// arrives as an answer and the status gate in `parsers/seventeenlive_json.dart`
/// counts it a network failure, exactly as the reference refused to follow one.
abstract final class SeventeenLiveEndpoints {
  /// The JSON API host.
  static const String apiHost = 'api-dsa.17app.co';

  /// The website; the `Origin` of every request and the host of a room link.
  static const String origin = 'https://17.live';

  /// The desktop Chrome user agent of every request and of the chat handshake.
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/140.0.0.0 Safari/537.36';

  /// The platform's display name.
  static const String displayName = '17LIVE';

  /// The largest answer read (4 MiB, counted as the reference counted it:
  /// characters of the body text).
  static const int responseLimit = 4 * 1024 * 1024;

  /// The notice every room carries (the platform demands an adult viewer).
  static const String ageNotice = '17LIVE 要求观看者年满 18 周岁。';

  /// The area name of an audio-only broadcast.
  static const String audioRoom = '音频直播';

  /// What the directory and the search cover, in words a viewer understands;
  /// it is the manifest's description, because this contract has no directory
  /// notice of its own (the reference's `directoryNoticeKey`).
  static const String directoryScope =
      '推荐和分区里是 17LIVE 官网日本、台湾、香港区首页推荐的直播，不是全部直播。搜索只能找到正在直播的主播；也可以输入房间号，或粘贴 17LIVE 的直播间或主页链接。';

  /// The region of the recommendations: the reference asked for Japan only.
  static const String region = 'JP';

  /// The id of the one category (the reference had no deeper catalog).
  static const String categoryId = 'region';

  /// The name of the one category.
  static const String categoryName = '地区';

  /// The regions of the website's recommendation sections, by `region` code, in
  /// the order shown (the archived v4 measured these three: `US` only mixes
  /// Japan and Hong Kong).
  static const Map<String, String> regions = <String, String>{'JP': '日本', 'TW': '台湾', 'HK': '香港'};

  /// The catalog: the one category's three regions, flat, each carrying
  /// [categoryId] as its parent; no request builds them.
  static const List<LiveArea> areas = [
    LiveArea(platform: _site, areaId: 'JP', areaName: '日本', parentAreaId: categoryId, parentAreaName: categoryName),
    LiveArea(platform: _site, areaId: 'TW', areaName: '台湾', parentAreaId: categoryId, parentAreaName: categoryName),
    LiveArea(platform: _site, areaId: 'HK', areaName: '香港', parentAreaId: categoryId, parentAreaName: categoryName),
  ];

  /// Rows the website asks each section for (`count`).
  static const int sectionCount = 20;

  /// The last page number a replay by page number goes to.
  static const int maxDirectoryPage = 20;

  /// The longest directory cursor sent or accepted.
  static const int maxCursorLength = 512;

  /// The longest keyword sent, in UTF-16 code units; a longer one is cut, never
  /// refused.
  static const int maxKeywordLength = 100;

  /// Sections without current broadcasts, which the website's own home page
  /// does not fill from.
  static const Set<String> skippedSections = {'TopBanner', 'ArchiveVideo', 'Vod'};

  /// The largest number of providers read; more than this are dropped and
  /// noted.
  static const int maxProviders = 16;

  /// CDNs (line labels) that serve no H.264 transcode: on 2026-10-08 every room
  /// served by Wansu (AVC sources) answered its `url264` with 404 or no data,
  /// while Tencent's served.
  static const Set<String> untranscodedCdns = {'wansu'};

  /// The id of 原画: the broadcaster's own stream (what the reference called
  /// `standard`).
  static const String sourceQualityId = 'source';

  /// The id of the H.264 transcode, the one quality that is always AVC.
  static const String h264QualityId = 'h264';

  /// The quality names, best first. Each is shown as `<name> · FLV`.
  static const Map<String, String> qualityNames = {
    sourceQualityId: '原画',
    'enhanced': '增强高清',
    'hd': '高清',
    h264QualityId: 'H.264',
  };

  /// The platform rank of each quality: 原画 highest (the reference's 标准,
  /// which was its lowest). A bigger value is the better quality, as on
  /// bilibili, and it is what the quality's platform order carries;
  /// `SeventeenLivePlayParser.playQualities` does the "优先 H.264" reordering.
  static const Map<String, int> qualitySorts = {
    sourceQualityId: 500,
    'enhanced': 400,
    'hd': 300,
    h264QualityId: 200,
  };

  /// The pull URL fields of each quality, best first: every field of every
  /// provider is a line. The source fields are the broadcaster's stream as
  /// pushed (no suffix).
  static const Map<String, List<String>> qualityFields = {
    sourceQualityId: ['urlLowQuality', 'webUrlLowQuality', 'urlHighQuality'],
    'enhanced': ['urlQualityEnhancedHD'],
    'hd': ['urlLowBitrateHD', 'webUrl', 'url'],
    h264QualityId: ['url264'],
  };

  /// The quality ids whose quality gained a new id, for a stored quality to
  /// migrate once: `standard` (标准 · FLV) is [sourceQualityId] (原画 · FLV).
  static const Map<String, String> legacyQualityIds = {'standard': sourceQualityId};

  /// The hosts of the website: `www.17.live` redirects to `17.live`.
  static const Set<String> webHosts = {'17.live', 'www.17.live'};

  /// The headers of the sections and the search (the website asks its catalog in
  /// Japanese).
  static const Map<String, String> catalogHeaders = {
    'user-agent': userAgent,
    'accept': 'application/json, text/plain, */*',
    'accept-language': 'ja-JP,ja;q=0.9,en;q=0.8',
    'origin': origin,
    'referer': '$origin/',
  };

  /// The headers of the token request: the catalog headers and a JSON body.
  static const Map<String, String> authHeaders = {
    ...catalogHeaders,
    'content-type': 'application/json',
  };

  /// The token source; the website's ably-js asks it in its `authCallback`.
  static final Uri authUrl = Uri.https(apiHost, '/api/v1/messenger/auth');

  /// The API answer of [path] with [query].
  static Uri api(String path, [Map<String, String>? query]) => Uri.https(apiHost, path, query);

  /// `lives/<roomId>`: the room, its state and its pull URLs.
  static Uri lives(String roomId) => api('/api/v1/lives/$roomId');

  /// The recommendation sections of [regionCode] after [cursor] (an empty
  /// cursor asks the first page, as the website does).
  static Uri sections({String? cursor, String regionCode = region}) =>
      api('/api/v1/sections', sectionsQuery(cursor, regionCode: regionCode));

  /// The live broadcasters matching [keyword].
  static Uri search(String keyword) => api('/api/v1/liveStreams/search', {'query': keyword});

  /// The web page of [roomId]: the room's own link and the `Referer` of its
  /// requests.
  static String roomUrl(String roomId) => '$origin/en/live/$roomId';

  /// The headers of the room answer (`lives/<id>`).
  static Map<String, String> requestHeaders(String roomId) => {
    'user-agent': userAgent,
    'accept': 'application/json, text/plain, */*',
    'accept-language': 'en-US,en;q=0.9',
    'origin': origin,
    'referer': roomUrl(roomId),
  };

  /// The pull streams' request headers: the pull hosts refuse a request without
  /// a Referer (REG-17LIVE-003).
  static Map<String, String> mediaHeaders(String roomId) => {
    'user-agent': userAgent,
    'origin': origin,
    'referer': roomUrl(roomId),
  };

  /// The query of the sections page after [cursor] of [regionCode].
  static Map<String, String> sectionsQuery(String? cursor, {String regionCode = region}) => {
    'count': '$sectionCount',
    'typeTab': '2',
    'region': regionCode,
    'cursor': cursor ?? '',
  };

  /// The `region` code of [areaId]: [region] for null or blank (the
  /// recommendations), else the code itself (any case) when it is one of
  /// [regions]. Null for an id of another platform or of no region at all — the
  /// caller's error, never a guessed region.
  static String? regionFor(String? areaId) {
    final code = areaId?.trim().toUpperCase();
    if (code == null || code.isEmpty) return region;
    return regions.containsKey(code) ? code : null;
  }
}
