import 'dart:convert';

import 'package:live_sites/src/platforms/yy/parsers/yy_json.dart';

/// YY's (欢聚时代) endpoints and constants (3.x's `YyApi` statics): the web
/// origin, the user agents of the three request families, the stream SDK
/// version, the mobile HLS route, the FLV lease and the preset area names.
abstract final class YyEndpoints {
  /// Web origin; also the `Origin` of API and media requests.
  static const String origin = 'https://www.yy.com';

  /// Host of the API, the pages and the search.
  static const String host = 'www.yy.com';

  /// Desktop Chrome 128, the UA 3.x sent with every API request.
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/128.0.0.0 Safari/537.36';

  /// Desktop Chrome 140, the UA sent to the media CDN.
  static const String mediaUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/140.0.0.0 Safari/537.36';

  /// The iPhone Safari UA of the mobile HLS route.
  static const String mobileUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 Version/17.0 Mobile/15E148 Safari/604.1';

  /// The web player's stream SDK version stream-manager is asked with.
  static const String sdkVersion = '5.23.0-beta.2';

  /// The two rates the mobile HLS route is asked for, lowest first.
  static const List<String> mobileHlsRates = ['1200', '4000'];

  /// Prefix of the quality ids of the mobile HLS route.
  static const String mobileHlsPrefix = 'mobile-hls:';

  /// How long before its expiry a FLV URL is renewed (at most a quarter of
  /// its lifetime).
  static const Duration leaseLead = Duration(minutes: 1);

  /// The `biz` of the recommendations, and of most live details: no area.
  static const String otherBiz = 'other';

  /// Area names by `biz`, preset from the catalog: each area page's
  /// `pageBar`. A room's own `biz` is its area's, so a room entered
  /// directly is named without reading an area page. Left out: `chicken`
  /// (its areas tell each other apart by `subBiz`, which details lack) and
  /// [otherBiz] (no area).
  static const Map<String, String> bizAreaNames = {
    'sing': '音乐',
    'talk': '脱口秀',
    'dance': '舞蹈',
    'red': '户外',
    'pretty': '颜值',
    'mc': '喊麦',
    'sport': '体育',
    'car': '二次元',
    'game': '王者荣耀',
    'zonghe': '综合',
  };

  /// The words YY appends to the default title of a room without one
  /// (`<nickname> 正在直播`).
  static const String liveSuffix = '正在直播';

  /// The name YY shows for a user without one: a room that names its
  /// streamer so names nobody.
  static const String placeholderName = 'YY用户';

  /// A channel number: 1–16 digits without a leading zero.
  static final RegExp channelPattern = RegExp(r'^[1-9]\d{0,15}$');

  /// Whether [value] is a channel number.
  static bool isChannel(String value) => channelPattern.hasMatch(value);

  /// The room page, 3.x's `link`.
  static String roomUrl(String roomId) => '$origin/${roomId.trim()}';

  /// The canonical link of a room, what the link resolver answers.
  static Uri roomLink(String roomId) => Uri.parse(roomUrl(roomId));

  /// 3.x's API headers, with the user's cookie when set.
  static Map<String, String> apiHeaders({String cookie = ''}) => {
    'accept': '*/*',
    'origin': origin,
    'referer': '$origin/',
    'sec-fetch-dest': 'empty',
    'sec-fetch-mode': 'cors',
    'sec-fetch-site': 'same-site',
    'user-agent': userAgent,
    if (cookie.trim().isNotEmpty) 'cookie': cookie.trim(),
  };

  /// stream-manager: the API headers with the channel page as Referer and
  /// the JSON body declared `text/plain`, as the web SDK sends it (some
  /// channels refuse `application/json`).
  static Map<String, String> streamManagerHeaders(String sid, String ssid, {String cookie = ''}) => {
    ...apiHeaders(cookie: cookie),
    'content-type': 'text/plain;charset=UTF-8',
    'referer': '$origin/$sid/$ssid',
  };

  /// The mobile HLS route: the API headers as the mobile page on an iPhone.
  static Map<String, String> mobileHlsHeaders(String sid, String ssid, {String cookie = ''}) => {
    ...apiHeaders(cookie: cookie),
    'referer': 'https://wap.yy.com/mobileweb/$sid/$ssid',
    'user-agent': mobileUserAgent,
  };

  /// Media request headers: Origin, the site root as Referer, desktop
  /// Chrome, and the user's cookie when set.
  static Map<String, String> mediaHeaders({String cookie = ''}) => {
    'origin': origin,
    'referer': '$origin/',
    'user-agent': mediaUserAgent,
    if (cookie.trim().isNotEmpty) 'cookie': cookie.trim(),
  };

  /// `yyweb/module/data/header`: the top-level categories.
  static Uri header() => Uri.https(host, '/yyweb/module/data/header');

  /// `category/getCategory.action`: the areas of one category.
  static Uri category(String parentId) =>
      Uri.https(host, '/c/yycom/category/getCategory.action', {'parentId': parentId});

  /// `more/page.action` page [page] of [pageSize] rows of the module
  /// [moduleId]/[biz]/[subBiz].
  static Uri pageAction({
    required int page,
    required int pageSize,
    required int moduleId,
    required String biz,
    required String subBiz,
  }) => Uri.https(host, '/more/page.action', {
    'page': '${page < 1 ? 1 : page}',
    'pageSize': '$pageSize',
    'moduleId': '$moduleId',
    'biz': biz,
    'subBiz': subBiz,
  });

  /// The home listing (`biz` [YyEndpoints.otherBiz]).
  static Uri recommendAction({required int page, required int pageSize}) =>
      pageAction(page: page, pageSize: pageSize, moduleId: -1, biz: otherBiz, subBiz: 'idx');

  /// `apiSearch/doSearch.json`, tab [tab] (`120` rooms, `1` anchors), page
  /// [page].
  static Uri search(String keyword, {required String tab, required int page}) =>
      Uri.https(host, '/apiSearch/doSearch.json', {'q': keyword, 't': tab, 'n': '${page < 1 ? 1 : page}'});

  /// `api/liveInfoDetail/<sid>/<sid>/0`: the live room of a channel.
  static Uri liveInfoDetail(String sid) => Uri.https(host, '/api/liveInfoDetail/$sid/$sid/0');

  /// The room page of [id] (a channel number or a short number).
  static Uri roomPage(String id) => Uri.parse(roomUrl(id));

  /// The stream-manager answer for channel [sid]/[ssid] (`sequence` the
  /// time in milliseconds, `encode` json).
  static Uri streamManager({required String sid, required String ssid, required int sequence}) => Uri.https(
    'stream-manager.yy.com',
    '/v3/channel/streams',
    {'uid': '0', 'cid': sid, 'sid': ssid, 'appid': '0', 'sequence': '$sequence', 'encode': 'json'},
  );

  /// The stream-manager request body for [gear] (3.x's, sent as JSON text:
  /// Dio form-encoded the map, which the server answers with HTTP 500).
  /// [line] is the CDN line (`line_seq`) asked for; -1 lets the server
  /// choose, as 3.x did.
  static Map<String, Object> streamManagerBody({
    required String sid,
    required String ssid,
    required int gear,
    required int sequence,
    int line = -1,
  }) => {
    'head': {
      'seq': sequence,
      'appidstr': '0',
      'bidstr': '121',
      'cidstr': sid,
      'sidstr': ssid,
      'uid64': 0,
      'client_type': 108,
      'client_ver': sdkVersion,
      'stream_sys_ver': 1,
      'app': 'yylive_web',
      'playersdk_ver': sdkVersion,
      'thundersdk_ver': '0',
      'streamsdk_ver': sdkVersion,
    },
    'client_attribute': {
      'client': 'web',
      'model': 'web0',
      'cpu': '',
      'graphics_card': '',
      'os': 'chrome',
      'osversion': '128.0.0.0',
      'vsdk_version': '',
      'app_identify': '',
      'app_version': '',
      'business': '',
      'width': '1366',
      'height': '768',
      'scale': '',
      'client_type': 8,
      'h265': 0,
    },
    'avp_parameter': {
      'version': 1,
      'client_type': 8,
      'service_type': 0,
      'imsi': 0,
      'send_time': sequence ~/ 1000,
      'line_seq': line,
      'gear': gear,
      'ssl': 1,
      'stream_format': 0,
    },
  };

  /// The stream-manager body of [gear] as the `text/plain` JSON the web SDK
  /// sends.
  static String streamManagerJson({
    required String sid,
    required String ssid,
    required int gear,
    required int sequence,
    int line = -1,
  }) => jsonEncode(streamManagerBody(sid: sid, ssid: ssid, gear: gear, sequence: sequence, line: line));

  /// The mobile HLS answer at [rate]. Built by hand: 3.x sent `callback=`
  /// with its empty value.
  static Uri mobileHls({required String sid, required String ssid, required String rate}) =>
      Uri.parse('https://interface.yy.com/hls/new/get/$sid/$ssid/$rate?source=wapyy&callback=');

  /// The area named by [biz], learnt from an area page ([areaNames]), else
  /// preset ([bizAreaNames]), else empty: the raw key is no name, and
  /// [otherBiz], the key of every recommendation, is no area.
  static String areaOf(Object? biz, Map<String, String> areaNames) {
    final key = YyJson.text(biz);
    if (key == otherBiz) return '';
    return areaNames[key] ?? bizAreaNames[key] ?? '';
  }
}
