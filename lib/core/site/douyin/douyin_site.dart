import 'dart:convert';
import 'dart:math' as math;

import 'package:pure_live/common/index.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/model/live_anchor_item.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/common/convert_helper.dart';
import 'package:pure_live/core/danmaku/douyin_danmaku.dart';
import 'package:pure_live/core/site/douyin/douyin_audience.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/site/douyin/douyin_search.dart';
import 'package:pure_live/core/utils/douyin/douyin_utils.dart';
import 'package:pure_live/core/utils/douyin/douyin_request_params.dart';

class DouyinSite implements LiveSite {
  @override
  String id = Sites.douyinSite;

  @override
  String name = "抖音直播";

  @override
  LiveDanmaku getDanmaku() => DouyinDanmaku();

  static const String kDefaultReferer = "https://live.douyin.com";

  static const String kDefaultAuthority = "live.douyin.com";

  /// 用户设置的 cookie
  static String cookie = "";
  static Future<String>? _anonymousCookieRequest;

  Map<String, dynamic> headers = {
    "Authority": kDefaultAuthority,
    "Referer": kDefaultReferer,
    "User-Agent": DouyinRequestParams.kDefaultUserAgent,
  };

  Future<Map<String, dynamic>> getRequestHeaders() async {
    try {
      if (cookie.isNotEmpty) {
        return {...headers, "cookie": cookie};
      } else if (SettingsService.to.cookieManager.douyinCookie.v.isNotEmpty) {
        cookie = SettingsService.to.cookieManager.douyinCookie.v;
        return {...headers, "cookie": cookie};
      }

      final anonymousCookie = await (_anonymousCookieRequest ??= _fetchAnonymousCookie());
      _anonymousCookieRequest = null;
      if (anonymousCookie.isNotEmpty) {
        cookie = anonymousCookie;
        return {...headers, "cookie": cookie};
      }
      return Map<String, dynamic>.from(headers);
    } catch (e) {
      _anonymousCookieRequest = null;
      CoreLog.error(e);
      return Map<String, dynamic>.from(headers);
    }
  }

  Future<String> _fetchAnonymousCookie() async {
    final response = await HttpClient.instance.get(
      'https://live.douyin.com/',
      queryParameters: const {'from_nav': '1'},
      header: headers,
    );
    final setCookieValues = response.headers.map['set-cookie'] ?? const <String>[];
    final pairs = <String>[];
    for (final value in setCookieValues) {
      final pair = value.split(';').first.trim();
      if (pair.startsWith('ttwid=') || pair.startsWith('UIFID_TEMP=')) {
        pairs.add(pair);
      }
    }
    return pairs.join('; ');
  }

  Future<Map<String, dynamic>> getUserInfoByCookie(String cookie) async {
    try {
      final url = "https://live.douyin.com/webcast/user/me/";
      final result = await HttpClient.instance.getJson(
        url,
        queryParameters: {"aid": DouyinRequestParams.aidValue},
        header: {
          "user-agent": DouyinRequestParams.kDefaultUserAgent,
          'accept': 'application/json, text/plain, */*',
          'accept-language': 'zh-CN,zh;q=0.9,en;q=0.8',
          "Cookie": cookie,
        },
      );
      if (result is Map<String, dynamic>) {
        final data = result["data"];
        if (data is Map<String, dynamic>) {
          return data;
        }
      }
      return {};
    } catch (e) {
      CoreLog.error(e);
    }
    return {};
  }

  String extractCategoryDataJson(String source) {
    final startPattern = r'{\"pathname\":\"/\",\"categoryData\":';
    int startIndex = source.indexOf(startPattern);
    if (startIndex == -1) return '';
    int openBraces = 0;
    bool foundFirstBrace = false;
    for (int i = startIndex; i < source.length; i++) {
      if (source[i] == '{') {
        openBraces++;
        foundFirstBrace = true;
      } else if (source[i] == '}') {
        openBraces--;
      }
      if (foundFirstBrace && openBraces == 0) {
        String rawData = source.substring(startIndex, i + 1);
        return rawData.replaceAll('\\"', '"').replaceAll(r'\\', r'\');
      }
    }
    return '';
  }

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    List<LiveCategory> categories = [];
    var result = await HttpClient.instance.getText(
      "https://live.douyin.com/",
      queryParameters: {"from_nav": "1"},
      header: await getRequestHeaders(),
    );

    String extracted = extractCategoryDataJson(result);
    var renderDataJson = json.decode(extracted);
    var data = renderDataJson["categoryData"];
    for (var item in data) {
      List<LiveArea> subs = [];
      var id = '${item["partition"]["id_str"]},${item["partition"]["type"]}';
      for (var subItem in item["sub_partition"]) {
        var subCategory = LiveArea(
          areaId: '${subItem["partition"]["id_str"]},${subItem["partition"]["type"]}',
          typeName: item["partition"]["title"] ?? '',
          areaType: id,
          areaName: subItem["partition"]["title"] ?? '',
          areaPic: "",
          platform: Sites.douyinSite,
        );
        subs.add(subCategory);
      }

      var category = LiveCategory(children: subs, id: id, name: asT<String?>(item["partition"]["title"]) ?? "");
      subs.insert(
        0,
        LiveArea(
          areaId: category.id,
          typeName: category.name,
          areaType: category.id,
          areaPic: "",
          areaName: category.name,
          platform: Sites.douyinSite,
        ),
      );
      categories.add(category);
    }
    return categories;
  }

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    var ids = category.areaId?.split(',');
    var partitionId = ids?[0];
    var partitionType = ids?[1];

    var queryParameters = {
      "aid": '6383',
      "app_name": "douyin_web",
      "live_id": '1',
      "device_platform": "web",
      "language": "zh-CN",
      "enter_from": "link_share",
      "cookie_enabled": "true",
      "screen_width": "1980",
      "screen_height": "1080",
      "browser_language": "zh-CN",
      "browser_platform": "Win32",
      "browser_name": "Edge",
      "browser_version": "125.0.0.0",
      "browser_online": "true",
      "count": '15',
      "offset": ((page - 1) * 15).toString(),
      "partition": partitionId,
      "partition_type": partitionType,
      "req_from": '2',
    };
    var categoryRoomUrl = "https://live.douyin.com/webcast/web/partition/detail/room/v2/";
    var targetUrl = DouyinUtils.buildRequestUrl(categoryRoomUrl, queryParameters);
    var result = await HttpClient.instance.getJson(targetUrl, header: await getRequestHeaders());
    var items = <LiveRoom>[];
    for (var item in result["data"]["data"]) {
      final room = item["room"];
      final totalViewers = douyinTotalViewers(room);
      final onlineViewers = douyinOnlineViewers(room);
      final nativeAudience = totalViewers.isNotEmpty ? totalViewers : onlineViewers;
      var roomItem = LiveRoom(
        roomId: item["web_rid"],
        title: room["title"].toString(),
        cover: room["cover"]["url_list"][0].toString(),
        nick: room["owner"]["nickname"].toString(),
        liveStatus: LiveStatus.live,
        avatar: room["owner"]["avatar_thumb"]["url_list"][0].toString(),
        status: true,
        platform: Sites.douyinSite,
        area: item['tag_name'].toString(),
        watching: nativeAudience,
        totalViewers: totalViewers,
        onlineViewers: onlineViewers,
        audienceMetricType: totalViewers.isNotEmpty
            ? AudienceMetricType.totalViewers
            : AudienceMetricType.onlineViewers,
      );
      items.add(roomItem);
    }
    return items;
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    try {
      final result = await HttpClient.instance.getJson(
        "https://live.douyin.com/webcast/feed/",
        queryParameters: {
          "aid": "6383",
          "app_name": "douyin_web",
          "need_map": "1",
          "is_draw": "1",
          "inner_from_drawer": "0",
          "enter_source": "web_homepage_hot_web_live_card",
          "source_key": "web_homepage_hot_web_live_card",
        },
        header: await getRequestHeaders(),
      );
      return parseRecommendRooms(result);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  /// Parses both generations of Douyin's anonymous feed response.
  ///
  /// The legacy response stored rooms at `data.data`. Since August 2026 the
  /// endpoint returns `data` as a list of feed envelopes and puts the room in
  /// each envelope's `data` field. Indexing that list with the string `data`
  /// produced `type 'String' is not a subtype of type 'int' of 'index'` before
  /// any card could be rendered.
  @visibleForTesting
  static List<LiveRoom> parseRecommendRooms(dynamic payload) {
    final root = _asStringMap(payload);
    if (root == null) throw const FormatException('Douyin feed response is not an object');

    final statusCode = int.tryParse(root['status_code']?.toString() ?? '');
    if (statusCode != null && statusCode != 0) {
      throw StateError('Douyin feed rejected request: code=$statusCode');
    }

    dynamic rawRooms = root['data'];
    if (rawRooms is Map) rawRooms = rawRooms['data'];
    if (rawRooms is! List) throw const FormatException('Douyin feed room list is missing');

    final rooms = <LiveRoom>[];
    final seenRoomIds = <String>{};
    for (final rawItem in rawRooms) {
      final envelope = _asStringMap(rawItem);
      if (envelope == null) continue;

      final embedded = _decodeEmbeddedMap(envelope['data']);
      final nestedRoom = _asStringMap(envelope['room']);
      final room = <Map<String, dynamic>?>[
        embedded,
        nestedRoom,
        envelope,
      ].firstWhere((candidate) => candidate != null && _looksLikeRoom(candidate), orElse: () => null);
      if (room == null) continue;

      final owner = _asStringMap(room['owner']) ?? _asStringMap(envelope['owner']) ?? const <String, dynamic>{};
      final roomId = _firstText([envelope['web_rid'], owner['web_rid'], room['web_rid'], room['id_str'], room['id']]);
      if (roomId.isEmpty || !seenRoomIds.add(roomId)) continue;

      final title = _firstText([room['title'], envelope['title'], owner['nickname']]);
      final nick = _firstText([owner['nickname'], envelope['nickname']]);
      final cover = _firstImageUrl([room['cover'], envelope['cover']]);
      final avatar = _firstImageUrl([owner['avatar_thumb'], owner['avatar_large'], envelope['avatar_thumb']]);
      final totalViewers = douyinTotalViewers(room);
      final onlineViewers = douyinOnlineViewers(room);
      final nativeAudience = totalViewers.isNotEmpty ? totalViewers : onlineViewers;

      rooms.add(
        LiveRoom(
          roomId: roomId,
          title: title,
          cover: cover,
          nick: nick,
          platform: Sites.douyinSite,
          area: _douyinFeedArea(envelope, room),
          avatar: avatar,
          watching: nativeAudience,
          totalViewers: totalViewers,
          onlineViewers: onlineViewers,
          audienceMetricType: totalViewers.isNotEmpty
              ? AudienceMetricType.totalViewers
              : AudienceMetricType.onlineViewers,
          status: true,
          liveStatus: LiveStatus.live,
          link: 'https://live.douyin.com/$roomId',
        ),
      );
    }
    return rooms;
  }

  static Map<String, dynamic>? _asStringMap(dynamic value) {
    if (value is! Map) return null;
    return value.map((key, entryValue) => MapEntry(key.toString(), entryValue));
  }

  static Map<String, dynamic>? _decodeEmbeddedMap(dynamic value) {
    final direct = _asStringMap(value);
    if (direct != null) return direct;
    if (value is! String || !value.trimLeft().startsWith('{')) return null;
    try {
      return _asStringMap(json.decode(value));
    } catch (_) {
      return null;
    }
  }

  static bool _looksLikeRoom(Map<String, dynamic> value) {
    return value['owner'] is Map || value['title'] != null || value['id_str'] != null || value['stream_url'] is Map;
  }

  static String _firstText(Iterable<dynamic> candidates) {
    for (final value in candidates) {
      if (value == null || value is Map || value is Iterable && value is! String) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    return '';
  }

  static String _firstImageUrl(Iterable<dynamic> candidates) {
    for (final value in candidates) {
      final image = _asStringMap(value);
      final urlList = image?['url_list'];
      if (urlList is List) {
        final url = _firstText(urlList);
        if (url.isNotEmpty) return url;
      }
      final direct = _firstText([value]);
      if (direct.startsWith('http://') || direct.startsWith('https://')) return direct;
    }
    return '';
  }

  static String _douyinFeedArea(Map<String, dynamic> envelope, Map<String, dynamic> room) {
    final direct = _firstText([room['tag_name'], envelope['tag_name']]);
    if (direct.isNotEmpty) return direct;

    for (final source in [room['partition_road_map'], envelope['tags']]) {
      if (source is! List) continue;
      for (final rawTag in source) {
        final tag = _asStringMap(rawTag);
        if (tag == null) continue;
        final text = _firstText([tag['title'], tag['name'], tag['tag_name']]);
        if (text.isNotEmpty) return text;
      }
    }
    return '热门推荐';
  }

  @override
  Future<LiveRoom> getRoomDetail({required String platform, required String roomId}) async {
    if (roomId.length <= 16) {
      return await getRoomDetailByWebRid(roomId);
    }
    return await getRoomDetailByRoomId(roomId);
  }

  Future<LiveRoom> getRoomDetailByRoomId(String roomId) async {
    // 读取房间信息
    var roomData = await _getRoomDataByRoomId(roomId);

    // 通过房间信息获取WebRid
    var webRid = roomData["data"]["room"]["owner"]["web_rid"].toString();

    // 读取用户唯一ID，用于弹幕连接
    // 似乎这个参数不是必须的，先随机生成一个
    //var userUniqueId = await _getUserUniqueId(webRid);
    var userUniqueId = generateRandomNumber(12).toString();

    var room = roomData["data"]["room"];
    var owner = room["owner"];

    var status = asT<int?>(room["status"]) ?? 0;

    // roomId是一次性的，用户每次重新开播都会生成一个新的roomId
    // 所以如果roomId对应的直播间状态不是直播中，就通过webRid获取直播间信息
    if (status == 4) {
      var result = await getRoomDetailByWebRid(webRid);
      return result;
    }

    var roomStatus = status == 2;
    final totalViewers = roomStatus ? douyinTotalViewers(room) : '';
    final onlineViewers = roomStatus ? douyinOnlineViewers(room) : '';
    final nativeAudience = totalViewers.isNotEmpty ? totalViewers : onlineViewers;
    // 主要是为了获取cookie,用于弹幕websocket连接
    var headers = await getRequestHeaders();

    return LiveRoom(
      roomId: webRid,
      title: room["title"].toString(),
      cover: roomStatus ? room["cover"]["url_list"][0].toString() : "",
      nick: owner["nickname"].toString(),
      avatar: owner["avatar_thumb"]["url_list"][0].toString(),
      watching: nativeAudience,
      totalViewers: totalViewers,
      onlineViewers: onlineViewers,
      audienceMetricType: totalViewers.isNotEmpty ? AudienceMetricType.totalViewers : AudienceMetricType.onlineViewers,
      status: roomStatus,
      link: "https://live.douyin.com/$webRid",
      platform: Sites.douyinSite,
      area: '',
      liveStatus: roomStatus ? LiveStatus.live : LiveStatus.offline,
      introduction: owner["signature"].toString(),
      notice: "",
      danmakuData: DouyinDanmakuArgs(webRid: webRid, roomId: roomId, userId: userUniqueId, cookie: headers["cookie"]),
      data: room["stream_url"],
    );
  }

  /// 通过WebRid获取直播间信息
  /// - [webRid] 直播间RID
  /// - 返回直播间信息
  Future<LiveRoom> getRoomDetailByWebRid(String webRid) async {
    try {
      var result = await _getRoomDetailByWebRidApi(webRid);
      return result;
    } catch (e) {
      CoreLog.error(e);
    }
    return await _getRoomDetailByWebRidHtml(webRid);
  }

  /// 通过WebRid访问直播间API，从API中获取直播间信息
  /// - [webRid] 直播间RID
  /// - 返回直播间信息
  Future<LiveRoom> _getRoomDetailByWebRidApi(String webRid) async {
    // 读取房间信息
    var data = await _getRoomDataByApi(webRid);

    var roomData = data["data"][0];
    var userData = data["user"];
    var roomId = roomData["id_str"].toString();

    // 读取用户唯一ID，用于弹幕连接
    // 似乎这个参数不是必须的，先随机生成一个
    //var userUniqueId = await _getUserUniqueId(webRid);
    var userUniqueId = generateRandomNumber(12).toString();

    var owner = roomData["owner"];

    var roomStatus = (asT<int?>(roomData["status"]) ?? 0) == 2;
    final totalViewers = roomStatus ? douyinTotalViewers(roomData) : '';
    final onlineViewers = roomStatus ? douyinOnlineViewers(roomData) : '';
    final nativeAudience = totalViewers.isNotEmpty ? totalViewers : onlineViewers;

    // 主要是为了获取cookie,用于弹幕websocket连接
    var headers = await getRequestHeaders();
    return LiveRoom(
      roomId: webRid,
      title: roomData["title"].toString(),
      cover: roomStatus ? roomData["cover"]["url_list"][0].toString() : "",
      nick: roomStatus ? owner["nickname"].toString() : userData["nickname"].toString(),
      avatar: roomStatus
          ? owner["avatar_thumb"]["url_list"][0].toString()
          : userData["avatar_thumb"]["url_list"][0].toString(),
      watching: nativeAudience,
      totalViewers: totalViewers,
      onlineViewers: onlineViewers,
      audienceMetricType: totalViewers.isNotEmpty ? AudienceMetricType.totalViewers : AudienceMetricType.onlineViewers,
      status: roomStatus,
      liveStatus: roomStatus ? LiveStatus.live : LiveStatus.offline,
      link: "https://live.douyin.com/$webRid",
      platform: Sites.douyinSite,
      area: '',
      introduction: owner?["signature"]?.toString() ?? "",
      notice: "",
      danmakuData: DouyinDanmakuArgs(webRid: webRid, roomId: roomId, userId: userUniqueId, cookie: headers["cookie"]),
      data: roomStatus ? roomData["stream_url"] : {},
    );
  }

  /// 通过WebRid访问直播间网页，从网页HTML中获取直播间信息
  /// - [webRid] 直播间RID
  /// - 返回直播间信息
  Future<LiveRoom> _getRoomDetailByWebRidHtml(String roomId) async {
    var detail = await _getRoomDataByHtml(roomId);
    var webRid = roomId;

    var realRoomId = detail["roomStore"]["roomInfo"]["room"]["id_str"].toString();
    var userUniqueId = detail["userStore"]["odin"]["user_unique_id"].toString();
    var roomInfo = detail["roomStore"]["roomInfo"]["room"];
    var owner = roomInfo["owner"];
    var anchor = detail["roomStore"]["roomInfo"]["anchor"];
    var roomStatus = (asT<int?>(roomInfo["status"]) ?? 0) == 2;
    final totalViewers = roomStatus ? douyinTotalViewers(roomInfo) : '';
    final onlineViewers = roomStatus ? douyinOnlineViewers(roomInfo) : '';
    final nativeAudience = totalViewers.isNotEmpty ? totalViewers : onlineViewers;

    // 主要是为了获取cookie,用于弹幕websocket连接
    var headers = await getRequestHeaders();

    return LiveRoom(
      roomId: roomId,
      title: roomInfo["title"].toString(),
      cover: roomStatus ? roomInfo["cover"]["url_list"][0].toString() : "",
      nick: roomStatus ? owner["nickname"].toString() : anchor["nickname"].toString(),
      avatar: roomStatus
          ? owner["avatar_thumb"]["url_list"][0].toString()
          : anchor["avatar_thumb"]["url_list"][0].toString(),
      watching: nativeAudience,
      totalViewers: totalViewers,
      onlineViewers: onlineViewers,
      audienceMetricType: totalViewers.isNotEmpty ? AudienceMetricType.totalViewers : AudienceMetricType.onlineViewers,
      liveStatus: roomStatus ? LiveStatus.live : LiveStatus.offline,
      link: "https://live.douyin.com/$webRid",
      area: '',
      status: roomStatus,
      platform: Sites.douyinSite,
      introduction: roomInfo["title"].toString(),
      notice: "",
      danmakuData: DouyinDanmakuArgs(
        webRid: webRid,
        roomId: realRoomId,
        userId: userUniqueId,
        cookie: headers["cookie"],
      ),
      data: roomStatus ? roomInfo["stream_url"] : {},
    );
  }

  /// 读取用户的唯一ID
  /// - [webRid] 直播间RID
  // ignore: unused_element
  Future<String> _getUserUniqueId(String webRid) async {
    try {
      var webInfo = await _getRoomDataByHtml(webRid);
      return webInfo["userStore"]["odin"]["user_unique_id"].toString();
    } catch (e) {
      return generateRandomNumber(12).toString();
    }
  }

  /// 进入直播间前需要先获取cookie
  /// - [webRid] 直播间RID
  Future<String> _getWebCookie(String webRid) async {
    var headResp = await HttpClient.instance.head("https://live.douyin.com/$webRid", header: headers);
    var dyCookie = "";
    headResp.headers["set-cookie"]?.forEach((element) {
      var cookie = element.split(";")[0];
      if (cookie.contains("ttwid")) {
        dyCookie += "$cookie;";
      }
      if (cookie.contains("__ac_nonce")) {
        dyCookie += "$cookie;";
      }
      if (cookie.contains("msToken")) {
        dyCookie += "$cookie;";
      }
    });
    return dyCookie;
  }

  /// 通过webRid获取直播间Web信息
  /// - [webRid] 直播间RID
  Future<Map> _getRoomDataByHtml(String webRid) async {
    var dyCookie = await _getWebCookie(webRid);
    var result = await HttpClient.instance.getText(
      "https://live.douyin.com/$webRid",
      queryParameters: {},
      header: {
        "Authority": kDefaultAuthority,
        "Referer": kDefaultReferer,
        "Cookie": dyCookie,
        "User-Agent": DouyinRequestParams.kDefaultUserAgent,
      },
    );

    var renderData = RegExp(r'\{\\"state\\":\{\\"appStore.*?\]\\n').firstMatch(result)?.group(0) ?? "";
    var str = renderData.trim().replaceAll('\\"', '"').replaceAll(r"\\", r"\").replaceAll(']\\n', "");

    var renderDataJson = json.decode(str);
    return renderDataJson["state"];
  }

  /// 通过webRid获取直播间Web信息
  /// - [webRid] 直播间RID
  Future<Map> _getRoomDataByApi(String webRid) async {
    var requestHeader = await getRequestHeaders();
    var queryParams = {
      'app_name': 'douyin_web',
      'enter_from': 'web_live',
      'live_id': '1',
      'web_rid': webRid,
      'is_need_double_stream': "false",
    };
    var targetUrl = DouyinUtils.buildRequestUrl("https://live.douyin.com/webcast/room/web/enter/", queryParams);
    CoreLog.d("targetUrl: $targetUrl");
    var result = await HttpClient.instance.getJson(targetUrl, header: requestHeader);

    return result["data"];
  }

  /// 通过roomId获取直播间信息
  /// - [roomId] 直播间ID
  Future<Map> _getRoomDataByRoomId(String roomId) async {
    var result = await HttpClient.instance.getJson(
      'https://webcast.amemv.com/webcast/room/reflow/info/',
      queryParameters: {
        "type_id": 0,
        "live_id": 1,
        "room_id": roomId,
        "sec_user_id": "",
        "version_code": "99.99.99",
        "app_id": 6383,
      },
      header: await getRequestHeaders(),
    );
    return result;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    return parseStreamQualities(detail.data);
  }

  /// Resolves Douyin qualities by their stable `sdk_key`.
  ///
  /// The former fallback converted URL maps to positional lists and paired
  /// them using `length - level`. JSON map order is not a quality contract, so
  /// multiple buttons could point at the same or the wrong stream. Both the
  /// modern `stream_data.data` payload and legacy pull-url maps are now joined
  /// by key, never by position.
  @visibleForTesting
  static List<LivePlayQuality> parseStreamQualities(dynamic rawStreamUrl) {
    if (rawStreamUrl is! Map) return const <LivePlayQuality>[];
    final liveCore = rawStreamUrl['live_core_sdk_data'];
    final pullData = liveCore is Map ? liveCore['pull_data'] : null;
    final options = pullData is Map ? pullData['options'] : null;
    final optionQualities = options is Map && options['qualities'] is List
        ? (options['qualities'] as List).whereType<Map>().toList(growable: false)
        : const <Map>[];

    Map<dynamic, dynamic> decodedStreams = const {};
    final streamDataText = pullData is Map ? pullData['stream_data']?.toString().trim() ?? '' : '';
    if (streamDataText.startsWith('{')) {
      try {
        final decoded = json.decode(streamDataText);
        if (decoded is Map && decoded['data'] is Map) decodedStreams = decoded['data'] as Map;
      } catch (error) {
        CoreLog.error('Douyin stream_data decode failed: $error');
      }
    }

    final flvMap = rawStreamUrl['flv_pull_url'] is Map
        ? rawStreamUrl['flv_pull_url'] as Map
        : const <dynamic, dynamic>{};
    final hlsMap = rawStreamUrl['hls_pull_url_map'] is Map
        ? rawStreamUrl['hls_pull_url_map'] as Map
        : const <dynamic, dynamic>{};
    final resolutionNames = rawStreamUrl['resolution_name'] is Map
        ? rawStreamUrl['resolution_name'] as Map
        : const <dynamic, dynamic>{};

    final descriptors = <String, Map<dynamic, dynamic>>{};
    for (final option in optionQualities) {
      final key = option['sdk_key']?.toString().trim() ?? '';
      if (key.isNotEmpty) descriptors.putIfAbsent(key.toLowerCase(), () => option);
    }
    for (final key in <dynamic>{...decodedStreams.keys, ...flvMap.keys, ...hlsMap.keys}) {
      final text = key?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        descriptors.putIfAbsent(text.toLowerCase(), () => <dynamic, dynamic>{'sdk_key': text});
      }
    }

    final qualities = <LivePlayQuality>[];
    for (final entry in descriptors.entries) {
      final key = entry.key;
      final descriptor = entry.value;
      final urls = <String>[];
      final stream = _caseInsensitiveMapValue(decodedStreams, key);
      final main = stream is Map ? stream['main'] : null;
      if (main is Map) {
        _addPlayableUrl(urls, main['flv']);
        _addPlayableUrl(urls, main['hls']);
      }
      _addPlayableUrl(urls, _caseInsensitiveMapValue(flvMap, key));
      _addPlayableUrl(urls, _caseInsensitiveMapValue(hlsMap, key));
      if (urls.isEmpty) continue;

      final configuredName = descriptor['name']?.toString().trim() ?? '';
      final resolutionName = _caseInsensitiveMapValue(resolutionNames, key)?.toString().trim() ?? '';
      final bitRate = int.tryParse(descriptor['v_bit_rate']?.toString() ?? '');
      final sort = bitRate ?? _douyinQualityRank(key);
      qualities.add(
        LivePlayQuality(
          quality: configuredName.isNotEmpty
              ? configuredName
              : resolutionName.isNotEmpty
              ? resolutionName
              : key,
          id: key.toLowerCase(),
          sort: sort,
          data: List<String>.unmodifiable(urls),
        ),
      );
    }

    qualities.sort((left, right) => right.sort.compareTo(left.sort));
    return qualities;
  }

  static dynamic _caseInsensitiveMapValue(Map<dynamic, dynamic> map, String key) {
    final direct = map[key];
    if (direct != null) return direct;
    final normalized = key.toLowerCase();
    for (final entry in map.entries) {
      if (entry.key?.toString().toLowerCase() == normalized) return entry.value;
    }
    return null;
  }

  static void _addPlayableUrl(List<String> urls, dynamic value) {
    final url = value?.toString().trim() ?? '';
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !const {'http', 'https'}.contains(uri.scheme) || urls.contains(url)) return;
    urls.add(url);
  }

  static int _douyinQualityRank(String key) => switch (key.toUpperCase()) {
    'ORIGION' || 'ORIGIN' => 10000000,
    'FULL_HD1' || 'UHD' => 4000000,
    'HD1' || 'HD' => 2000000,
    'SD1' || 'SD' => 1000000,
    'SD2' || 'LD' => 500000,
    _ => 0,
  };

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    final data = quality.data;
    return data is List ? data.map((url) => url.toString()).where((url) => url.isNotEmpty).toList(growable: false) : [];
  }

  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) async {
    return await DouyinSearch.search(keyword, page: page, pageSize: pageSize);
  }

  @override
  Future<List<LiveAnchorItem>> searchAnchors(String keyword, {int page = 1, int pageSize = 30}) async {
    throw Exception("抖音暂不支持搜索主播，请直接搜索直播间");
  }

  @override
  Future<bool> getLiveStatus({required String platform, required String roomId}) async {
    var result = await getRoomDetail(roomId: roomId, platform: platform);
    return result.status!;
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({required String roomId}) {
    return Future.value(<LiveSuperChatMessage>[]);
  }

  //生成指定长度的16进制随机字符串
  String generateRandomString(int length) {
    var random = math.Random.secure();
    var values = List<int>.generate(length, (i) => random.nextInt(16));
    StringBuffer stringBuffer = StringBuffer();
    for (var item in values) {
      stringBuffer.write(item.toRadixString(16));
    }
    return stringBuffer.toString();
  }

  // 生成随机的数字
  int generateRandomNumber(int length) {
    var random = math.Random.secure();
    var values = List<int>.generate(length, (i) => random.nextInt(10));
    StringBuffer stringBuffer = StringBuffer();
    for (var item in values) {
      stringBuffer.write(item);
    }
    return int.tryParse(stringBuffer.toString()) ?? math.Random().nextInt(1000000000);
  }
}
