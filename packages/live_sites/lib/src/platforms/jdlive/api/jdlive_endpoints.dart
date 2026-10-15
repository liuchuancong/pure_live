import 'dart:convert';

import 'package:live_sites/src/models/enums/live_stream_format.dart';

/// JD Live's endpoints and constants (3.x's `JdLiveApi` statics): the two
/// anonymous API calls, the headers they and the media requests carry, the
/// platform's limits, its one area and its quality ids.
abstract final class JdliveEndpoints {
  /// The website.
  static const String webOrigin = 'https://lives.jd.com';

  /// The API host.
  static const String apiHost = 'api.m.jd.com';

  /// 3.x's user agent (iOS Safari) of every request.
  static const String userAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148';

  /// The headers of the API requests (3.x's `apiHeaders`).
  static const Map<String, String> apiHeaders = {
    'accept': 'application/json, text/plain, */*',
    'origin': webOrigin,
    'referer': '$webOrigin/',
    'user-agent': userAgent,
  };

  /// The headers of the media requests of [liveId] (3.x's `mediaHeaders`):
  /// what a room entry sends for the playlist check, and the headers of
  /// every play line.
  static Map<String, String> mediaHeaders(String liveId) => {
    'origin': webOrigin,
    'referer': link(liveId),
    'user-agent': userAgent,
  };

  /// The largest API answer read, in UTF-8 bytes.
  static const int responseLimit = 4 * 1024 * 1024;

  /// The largest playlist checked, in characters.
  static const int playlistLimit = 1024 * 1024;

  /// The platform name: the area's type and the rooms' area name.
  static const String siteName = 'JD Live';

  /// `areaType` of the one area.
  static const String areaType = 'official';

  /// `areaId` of the one area: the featured list (`tabId` 1).
  static const String areaId = 'featured';

  /// The one area's name.
  static const String areaName = '精选直播购物';

  /// Largest recommendation slice (a larger page size is cut to it).
  static const int maxRecommendSize = 30;

  /// Largest search page size served; a larger one gives nothing.
  static const int maxSearchSize = 100;

  /// Last page asked for.
  static const int maxPage = 10000;

  /// The notice of a room (text key `jdlive_chat_notice`): cards and details
  /// carry cumulative viewers, the chat connection concurrent ones.
  static const String chatNotice = '列表里的人数是累计观看；直播中连上弹幕后，显示的是正在观看的人数。';

  /// The notice of an app-only room (`jdlive_restricted_notice`).
  static const String restrictedNotice = '这场京东直播只能在京东 App 里观看。';

  /// Id of the HLS quality.
  static const String hlsId = 'hls';

  /// Id of the FLV quality.
  static const String flvId = 'flv';

  /// Id of a replay's one quality.
  static const String replayId = 'replay';

  /// The qualities of a live broadcast, in the order they are offered.
  static const List<(String, String)> liveQualities = [('HLS（推荐）', hlsId), ('FLV 原始线路', flvId)];

  /// The one quality of a replay.
  static const String replayLabel = '原画';

  static final RegExp _liveId = RegExp(r'^[1-9]\d{4,17}$');
  static final RegExp _route = RegExp(r'^/?([1-9]\d{4,17})(?:/(?:live|notice|closed|replay))?(?:\?.*)?$');

  /// Whether [value] is a broadcast id: 5–18 digits, not starting with 0.
  static bool isLiveId(String value) => _liveId.hasMatch(value);

  /// The room page of [liveId].
  static String link(String liveId) => '$webOrigin/#/$liveId';

  /// The broadcast of [raw]: an id (trimmed), or a room link
  /// ([liveIdFromUrl]); null otherwise.
  static String? liveIdOf(String raw) {
    final value = raw.trim();
    return isLiveId(value) ? value : liveIdFromUrl(value);
  }

  /// The broadcast of a room link: http(s) on `lives.jd.com` (any case),
  /// default port, no user info, the page routing by fragment: `#/<id>`,
  /// optionally followed by `/live`, `/notice`, `/closed` or `/replay` and a
  /// query. A path or query before the fragment is ignored. Null for
  /// anything else.
  static String? liveIdFromUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        (!uri.isScheme('http') && !uri.isScheme('https')) ||
        uri.userInfo.isNotEmpty ||
        uri.host.toLowerCase() != 'lives.jd.com' ||
        (uri.hasPort && uri.port != 80 && uri.port != 443)) {
      return null;
    }
    return _route.firstMatch(uri.fragment)?.group(1);
  }

  /// The `liveListWithTabToM` page [page] after [count] entries, of the list
  /// first asked at [timestamp] (`v` is the clock [now]).
  static Uri listUrl({required int page, required int count, required int timestamp, required DateTime now}) =>
      Uri.https(apiHost, '/api', {
        'appid': 'h5-live',
        'functionId': 'liveListWithTabToM',
        'v': '${now.millisecondsSinceEpoch}',
        'body': jsonEncode({'tabId': 1, 'currentCount': '$count', 'page': page, 'timestamp': timestamp}),
      });

  /// The `getImmediatePlayToM` of [liveId] (`t` is the clock [now]).
  static Uri playUrl(String liveId, {required DateTime now}) => Uri.https(apiHost, '/api', {
    'appid': 'h5-live',
    'functionId': 'getImmediatePlayToM',
    't': '${now.millisecondsSinceEpoch}',
    'body': jsonEncode({'liveId': liveId}),
  });

  /// The stream format of a quality: the replay's recording is HLS, as is
  /// the HLS quality; FLV is FLV.
  static LiveStreamFormat formatOf(String qualityId) =>
      qualityId == flvId ? LiveStreamFormat.flv : LiveStreamFormat.hls;
}
