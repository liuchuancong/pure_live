import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/weibo/weibo_manifest.dart';

/// Weibo Live's (微博直播) endpoints and constants (the reference's `WeiboApi`
/// statics): the two anonymous API paths under `weibo.com/l/!/2/wblive/`, the
/// headers their requests and the media carry, the platform's codes, the
/// broadcast-id rule, the one area, the two qualities and the room links.
///
/// A room is one broadcast (`1022:2321325347923495092258`), not an anchor: the
/// next broadcast of the same anchor is another room.
abstract final class WeiboEndpoints {
  /// Website origin.
  static const String origin = 'https://weibo.com';

  /// The recommendation snapshot (`pc_recommend/list.json`): no paging, no
  /// audience, only broadcasts on air.
  static const String recommendPath = '/l/!/2/wblive/pc_recommend/list.json';

  /// The broadcast detail (`room/show_pc_live.json`), the envelope
  /// `{code: 100000, error_code: 0, data}`.
  static const String detailPath = '/l/!/2/wblive/room/show_pc_live.json';

  /// Rows asked of the snapshot (upgrade 18-1): the site answers about 51.
  static const int recommendCount = 100;

  /// The snapshot request (`?count=100&uid=`).
  static final Uri recommendUrl = Uri.parse('$origin$recommendPath?count=$recommendCount&uid=');

  /// The detail request of broadcast [liveId], spelled as the reference sent
  /// it (the id query-encoded: `live_id=1022%3A…`).
  static Uri detailUrl(String liveId) => Uri.parse('$origin$detailPath?live_id=${Uri.encodeQueryComponent(liveId)}');

  /// Headers of the API requests, also of the `t.cn` short link requests.
  static const Map<String, String> headers = {'referer': '$origin/l/wblive/', 'user-agent': 'Mozilla/5.0'};

  /// Headers of the media requests: none. The reference's header resolver had
  /// no Weibo branch, so the player and the recorder sent their own defaults;
  /// the CDN answers the FLV without any (checked 2026-09-28 with no user
  /// agent, `Mozilla/5.0` and `libmpv`, no referer), and so does the replay
  /// CDN (checked 2026-09-28).
  static const Map<String, String> mediaHeaders = {};

  /// Largest answer accepted, in bytes (1 MiB).
  static const int responseLimit = 1024 * 1024;

  /// `error_code` of the detail for a broadcast that does not exist
  /// ("LiveRoom does not exists!").
  static const int missingCode = 27401;

  /// The envelope's business `code` of a good answer.
  static const int okCode = 100000;

  /// `status` of a live broadcast.
  static const int liveStatusCode = 1;

  /// `status` of an ended broadcast with a replay, shown as a replay.
  static const int replayStatusCode = 3;

  /// `status` of an ended broadcast without a replay: offline (upgrade 18-3).
  /// `status` 0 is an announced broadcast (its page counts down); anything
  /// else is not known.
  static const int endedStatusCode = 5;

  /// `watch_limit` of a broadcast only the Weibo app plays (the web player
  /// sends the viewer to the app).
  static const int appOnlyLimit = 8;

  /// `watch_limit` of a broadcast for the anchor's friends only (本场直播只有
  /// 主播的好友可观看).
  static const int friendsOnlyLimit = 10;

  /// `watch_limit` of a broadcast only the anchor may watch (本场直播只有主播
  /// 自己可观看).
  static const int selfOnlyLimit = 11;

  /// `watch_limit` of a paid broadcast (the web player offers a top-up).
  static const int paidLimit = 12;

  /// Most rows of the snapshot list (more is a changed API).
  static const int maxRecommendRows = 500;

  /// Lowest page size a caller may ask for (the reference's bound, which it
  /// checked before any request).
  static const int minPageSize = 1;

  /// Highest page size a caller may ask for.
  static const int maxPageSize = 1000;

  /// A broadcast id: 3–8 digits, a colon and 16–48 letters or digits. The
  /// site answers an unknown id with [missingCode].
  static final RegExp liveIdPattern = RegExp(r'^[0-9]{3,8}:[0-9A-Za-z]{16,48}$');

  /// The platform's display name, also the area's parent name.
  static const String siteName = '微博直播';

  /// `areaId` of the one area, the recommendation snapshot.
  static const String areaId = 'live';

  /// Name of the one area.
  static const String areaName = '公开推荐';

  /// The area listing, and the [areaId] filter agree on: the one static area,
  /// 公开推荐 under the platform itself (no request; the reference's
  /// `areaType` "recommendation" has no v2 field and is dropped).
  static final LiveArea area = LiveArea.normalized(
    platform: weiboSiteId,
    areaId: areaId,
    areaName: areaName,
    parentAreaId: weiboSiteId,
    parentAreaName: siteName,
  );

  /// The notice on every room: a follow tracks this broadcast, not the
  /// anchor. (The reference's separate directory scope note has no v2 field;
  /// only this per-room notice rides along.)
  static const String roomScopeNotice = '微博每场直播都有单独的链接，这里关注的是这一场。主播下次开播时，请重新导入新的直播链接。';

  /// The line put before [roomScopeNotice] on a restricted broadcast; the
  /// card's restriction mark shows the kind.
  static const String restrictedNotice = '这场直播设置了观看限制（仅好友、仅主播本人、付费或仅限微博 App），这里无法播放。';

  /// The line put before [roomScopeNotice] on a broadcast whose playback is
  /// switched off.
  static const String disabledNotice = '这场直播已关闭播放，这里无法播放。';

  /// [original]'s quality id: what a line request sends back for a live
  /// broadcast.
  static const String originalQualityId = 'original';

  /// [replay]'s quality id: what a line request sends back for a recording.
  static const String replayQualityId = 'replay';

  /// The quality of a live broadcast (the reference's 原始流).
  static const LivePlayQuality original = LivePlayQuality(label: '原始流', qualityId: originalQualityId);

  /// The quality of a replay's recording (upgrade 18-5; one stream,
  /// `…_wb1080avc_index.m3u8`).
  static const LivePlayQuality replay = LivePlayQuality(label: '原画', qualityId: replayQualityId);

  /// Redirect statuses a `t.cn` answer is read as a hop (the reference's
  /// `ShortLinkSession.redirectStatuses`).
  static const Set<int> redirectStatuses = {301, 302, 303, 307, 308};

  /// The room's web page, also where "open in browser" goes.
  static String roomUrl(String liveId) => '$origin/l/wblive/p/show/$liveId';

  /// Whether [value] is a broadcast id (see [liveIdPattern]).
  static bool isLiveId(String value) => liveIdPattern.hasMatch(value);

  /// The room [input] names exactly: a broadcast id, or a room link (see
  /// [liveIdFromUrl]); null for anything with a space or backslash inside,
  /// and for anything else.
  static String? exactRoom(String input) {
    final value = input.trim();
    if (_noSpaces.hasMatch(value)) return null;
    return isLiveId(value) ? value : liveIdFromUrl(value);
  }

  /// The broadcast of a Weibo room link, without any request:
  /// - the watch page `https://weibo.com/l/wblive/p/show/<id>` or
  ///   `/m/show/<id>` (hosts `weibo.com`, `www.weibo.com`): the path is read
  ///   as written, before `Uri` removes dot segments, with a trailing slash
  ///   at most; only the id's colon may be escaped (`%3A`), nothing is
  ///   decoded twice;
  /// - the media centre's `https://live.media.weibo.com/live/show?id=<id>`
  ///   (older links; the site redirects it to the watch page), with exactly
  ///   one `id`.
  ///
  /// Both need http(s), the default port, no user info and no space or
  /// backslash. A profile (`/u/<uid>`) or a post is no room; a `t.cn` short
  /// link needs a request ([shortLink]).
  static String? liveIdFromUrl(String raw) {
    final value = raw.trim();
    if (_noSpaces.hasMatch(value)) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || !_plainHttp(uri)) return null;
    if (uri.host == 'live.media.weibo.com') return _mediaCentreId(uri);
    if (uri.host != 'weibo.com' && uri.host != 'www.weibo.com') return null;
    final authorityAndPath = value.substring(value.indexOf('://') + 3).split(RegExp('[?#]')).first;
    final slash = authorityAndPath.indexOf('/');
    if (slash < 0) return null;
    final match = RegExp(r'^/l/wblive/[pm]/show/([^/]+)/?$').firstMatch(authorityAndPath.substring(slash));
    if (match == null) return null;
    final id = match[1]!.replaceAll(RegExp('%3a', caseSensitive: false), ':');
    return isLiveId(id) ? id : null;
  }

  /// The request of a `t.cn` short link (Weibo's link shortener; a live post
  /// links its broadcast so, upgrade 18-9): http(s) on `t.cn` with the default
  /// port, no user info, no space or backslash, and one path segment of 4–16
  /// letters or digits, with a trailing slash at most. The query and fragment
  /// are dropped and the request is made over https (the site answers both
  /// alike). Null for anything else. `t.cn` answers a 302 to the target, or to
  /// `http://weibo.com/sorry` for an unknown code.
  static Uri? shortLink(String raw) {
    final value = raw.trim();
    if (_noSpaces.hasMatch(value)) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || !_plainHttp(uri) || uri.host != 't.cn') return null;
    final match = RegExp(r'^/([0-9A-Za-z]{4,16})/?$').firstMatch(uri.path);
    return match == null ? null : Uri.https('t.cn', '/${match[1]}');
  }

  /// The target of a redirect answer: [headers] (lower-cased keys) name one
  /// non-empty `location` that resolves against [current] to an http(s) URL;
  /// null when the answer is no such redirect target.
  static Uri? redirectTarget(Uri current, Map<String, String> headers) {
    final location = headers['location'];
    if (location == null || location.trim().isEmpty) return null;
    try {
      final target = current.resolve(location.trim());
      return _isHttp(target) ? target : null;
    } on FormatException {
      return null;
    }
  }

  /// Whether [host] names one of the platform's hosts: the watch pages, the
  /// media centre or the link shortener.
  static bool isOurHost(String host) {
    final lower = host.toLowerCase();
    return lower == 'weibo.com' || lower.endsWith('.weibo.com') || lower == 't.cn' || lower.endsWith('.t.cn');
  }

  static final RegExp _noSpaces = RegExp(r'[\\\s]');

  /// Whether [uri] is http(s) with the default port and no user info.
  static bool _plainHttp(Uri uri) =>
      _isHttp(uri) && uri.userInfo.isEmpty && (!uri.hasPort || uri.port == (uri.scheme == 'https' ? 443 : 80));

  static bool _isHttp(Uri uri) => uri.scheme == 'http' || uri.scheme == 'https';

  static String? _mediaCentreId(Uri uri) {
    if (uri.path != '/live/show') return null;
    try {
      final ids = uri.queryParametersAll['id'];
      if (ids == null || ids.length != 1) return null;
      return isLiveId(ids.single) ? ids.single : null;
    } on FormatException {
      return null;
    }
  }
}
