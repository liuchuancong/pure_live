import 'dart:convert';
import 'dart:math';

// Constructors spell their class name by convention here; the `.new`
// shorthand hurts readability more than the lint helps.
// ignore_for_file: unnecessary_type_name_in_constructor

/// AcFun's request surface: the three hosts the web live page uses, the fixed
/// query parameters of the Kuaishou-backed APIs, and the visitor session's
/// shape.
///
/// `live.acfun.cn` answers the catalog, the room and the search pages;
/// `api.kuaishouzt.com` answers the playback and gift calls with the Kuaishou
/// live middle platform's fixed `subBiz`/`kpn`/`kpf` triple;
/// `id.app.acfun.cn` logs in the anonymous visitor. A visitor device id is
/// `web_` and 16 letters or digits — the format the site issues, which the
/// adapter draws at random for a new session.
abstract final class AcfunEndpoints {
  /// Desktop Chrome 140 — the UA sent with every API, search and media request
  /// (search answers 403 without a browser UA).
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/140.0.0.0 Safari/537.36';

  /// The live site: `Origin` of media requests and the danmaku handshake.
  static const String origin = 'https://live.acfun.cn';

  /// `Referer` of API and media requests.
  static const String referer = '$origin/';

  /// Product name (`kpn`).
  static const String kpn = 'ACFUN_APP';

  /// Product flavour (`kpf`).
  static const String kpf = 'PC_WEB';

  /// Business line (`subBiz`).
  static const String subBiz = 'mainApp';

  /// The visitor login's `sid` field.
  static const String visitorSid = 'acfun.api.visitor';

  /// Authors one search page holds (the server's own page size).
  static const int searchPageSize = 30;

  /// Rooms one directory page asks for, and the site's own page size.
  static const int directoryPageSize = 30;

  /// `startPlay`'s answer for a broadcast that has ended (`直播已关播`).
  static const int closedResult = 129004;

  /// `startPlay`'s answer for a paid show the viewer has no ticket for (the
  /// web player's `liveNotPaid`; the anonymous visitor never has one).
  static const int paidShowResult = 380205;

  /// The filter id of `全部`, which lists every live room: the recommendations,
  /// not an area.
  static const int allFilterId = 0;

  /// Author ids: a positive decimal number of at most 20 digits, no leading
  /// zero.
  static final RegExp authorIdPattern = RegExp(r'^[1-9][0-9]{0,19}$');

  /// The letters and digits a visitor device id is drawn from.
  static const String deviceAlphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  /// `api/channel/list`: one page of the catalog. [count] rooms (1–60) after
  /// the opaque [cursor], kept to the rooms of [filters] (null: every live
  /// room, the recommendation shelf).
  static Uri channelList({required int count, String cursor = '', String? filters}) =>
      Uri.https('live.acfun.cn', '/api/channel/list', {
        'count': '$count',
        // Always sent, even when empty: the server treats the two differently.
        'pcursor': cursor,
        'filters': ?filters,
      });

  /// `api/live/info?authorId=`: one room.
  static Uri roomInfo(String authorId) => Uri.https('live.acfun.cn', '/api/live/info', {'authorId': authorId});

  /// `id.app.acfun.cn/rest/app/visitor/login`: the anonymous session.
  static Uri visitorLogin() => Uri.https('id.app.acfun.cn', '/rest/app/visitor/login');

  /// `api.kuaishouzt.com/rest/zt/live/web/startPlay`: the broadcast of
  /// [visitor] (its session parameters ride in the query).
  static Uri startPlay(AcfunVisitor visitor) => _kuaishou('/rest/zt/live/web/startPlay', visitor);

  /// `api.kuaishouzt.com/rest/zt/live/web/gift/list`: the room's gift table.
  static Uri giftList(AcfunVisitor visitor) => _kuaishou('/rest/zt/live/web/gift/list', visitor);

  static Uri _kuaishou(String path, AcfunVisitor visitor) => Uri.https('api.kuaishouzt.com', path, {
    'subBiz': subBiz,
    'kpn': kpn,
    'kpf': kpf,
    'userId': visitor.userId,
    'did': visitor.deviceId,
    'acfun.api.visitor_st': visitor.token,
  });

  /// `www.acfun.cn/search?type=user`: one page of the author search. The
  /// BigPipe endpoint answers with JSON wrapping an HTML fragment; `reqID` is
  /// the page number the site itself counts.
  static Uri search(String keyword, int page) => Uri.https('www.acfun.cn', '/search', {
    'keyword': keyword,
    'type': 'user',
    'pCursor': '$page',
    'quickViewId': 'up-list',
    'reqID': '1',
    'ajaxpipe': '1',
  });

  /// The `filters` query value of one area: its filter type and id.
  static String filterQuery({required int type, required int id}) => jsonEncode([
    {'filterType': type, 'filterId': id},
  ]);

  /// The live page of author [authorId].
  static String roomPageUrl(String authorId) => '$origin/live/${authorId.trim()}';

  /// A new visitor device id: `web_` and 16 letters or digits.
  static String deviceId(Random random) =>
      'web_${List.generate(16, (_) => deviceAlphabet[random.nextInt(deviceAlphabet.length)]).join()}';

  /// Whether [value] is an author id.
  static bool isAuthorId(String value) => authorIdPattern.hasMatch(value);
}

/// The anonymous visitor session of `visitor/login`: what `startPlay` and the
/// gift table are asked with, and what the danmaku link registers with.
final class AcfunVisitor {
  /// Creates a session.
  const AcfunVisitor({required this.userId, required this.deviceId, required this.token, this.security});

  /// The visitor's user id (`userId`).
  final String userId;

  /// The `_did` cookie the visitor logged in with (`web_` + 16 letters or
  /// digits), sent again as `did`.
  final String deviceId;

  /// The service token (`acfun.api.visitor_st`).
  final String token;

  /// `acSecurity`, the base64 key of the danmaku link's register exchange;
  /// null when the answer has none. Streams never need it.
  final String? security;

  /// Diagnostics without the token and the key.
  @override
  String toString() => 'AcfunVisitor($userId, security: ${security == null ? 'none' : '<redacted>'})';
}
