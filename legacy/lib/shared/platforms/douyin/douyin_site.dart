import 'dart:convert';
import 'dart:math' as math;

import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/models/live_category.dart';
import 'package:pure_live/core/logging/core_log.dart';
import 'package:pure_live/core/models/live_anchor_item.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/shared/platforms/live_site.dart';
import 'package:pure_live/core/utils/type_cast.dart';
import 'package:pure_live/shared/platforms/douyin/douyin_danmaku.dart';
import 'package:pure_live/shared/platforms/douyin/douyin_audience.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/shared/platforms/douyin/douyin_search.dart';
import 'package:pure_live/shared/platforms/douyin/douyin_utils.dart';
import 'package:pure_live/shared/platforms/douyin/douyin_request_params.dart';
import 'package:pure_live/core/utils/live_quality_label.dart';
import 'package:pure_live/core/config/cookie_settings_controller.dart';
import 'package:pure_live/core/consts/platform_ids.dart';
import 'package:pure_live/shared/platforms/live_danmaku_capability.dart';
import 'package:pure_live/shared/platforms/douyin/douyin_danmaku_capability.dart';
import 'package:pure_live/shared/platforms/live_external_room.dart';

class DouyinSite
    with LiveDanmakuCapabilityDefaults, DouyinDanmakuCapability
    implements LiveSite, LiveSiteRecordRoomResolver, LiveSiteExternalRoomResolver {
  @override
  RoomExternalTarget? externalRoomTarget(LiveRoom liveroom) {
    final id = sanitizedExternalRoomId(liveroom.roomId);
    if (id == null) return null;
    final args = liveroom.danmakuData;
    final webId = args is DouyinDanmakuArgs ? sanitizedExternalRoomId(args.webRid) ?? id : id;
    final nativeId = args is DouyinDanmakuArgs ? sanitizedExternalRoomId(args.roomId) : null;
    return RoomExternalTarget(
      web: 'https://live.douyin.com/${Uri.encodeComponent(webId)}',
      native: nativeId == null ? null : 'snssdk1128://webcast_room?room_id=${Uri.encodeComponent(nativeId)}',
    );
  }

  @override
  String id = PlatformIds.douyin;

  @override
  String name = "抖音直播";

  @override
  LiveDanmaku getDanmaku() => DouyinDanmaku();

  static const String kDefaultReferer = "https://live.douyin.com";

  static const String kDefaultAuthority = "live.douyin.com";

  static String cookie = "";
  static Future<String>? _anonymousCookieRequest;
  static final String _anonymousUserUniqueId = generateAnonymousUserUniqueId();

  Map<String, dynamic> headers = {
    "Authority": kDefaultAuthority,
    "Referer": kDefaultReferer,
    "User-Agent": DouyinRequestParams.kDefaultUserAgent,
  };

  Future<Map<String, dynamic>> getRequestHeaders() async {
    try {
      if (cookie.isNotEmpty) {
        return {...headers, "cookie": cookie};
      } else if (CookieSettingsController.to.douyinCookie.v.isNotEmpty) {
        cookie = CookieSettingsController.to.douyinCookie.v;
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
          platform: PlatformIds.douyin,
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
          platform: PlatformIds.douyin,
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
        platform: PlatformIds.douyin,
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
          platform: PlatformIds.douyin,
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
  Future<LiveRoom> getRoomDetail(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    final fresh = await _resolveDetail(liveroom.roomId!);
    // Pad whatever the profile endpoint left empty (avatar/cover/nick drift
    // between responses) with the fields the room already carries, so a
    // partial response never blanks the UI. fillFromDetail covers
    // nick/avatar/area; the cover is padded explicitly because a blank
    // cover is the most visible symptom of a partial profile response.
    final padded = fresh.fillFromDetail(liveroom);
    final existingCover = liveroom.cover ?? '';
    if ((padded.cover == null || padded.cover!.isEmpty) && existingCover.isNotEmpty) {
      return padded.copyWith(cover: existingCover);
    }
    return padded;
  }

  Future<LiveRoom> _resolveDetail(String roomId) async {
    if (roomId.length <= 16) {
      return await getRoomDetailByWebRid(roomId);
    }
    return await getRoomDetailByRoomId(roomId);
  }

  @override
  Future<LiveRoom> getRoomDetailForRecording(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    // Both the API and HTML paths propagate their final error and retain the
    // stream_url envelope required to resolve every advertised sdk_key.
    return _resolveDetail(liveroom.roomId!);
  }

  Future<LiveRoom> getRoomDetailByRoomId(String roomId) async {
    var roomData = await _getRoomDataByRoomId(roomId);

    var webRid = roomData["data"]["room"]["owner"]["web_rid"].toString();

    // Current web clients use a 19-digit anonymous visitor ID. Reuse one ID
    // for the process so switching rooms does not create a new viewer identity.
    var userUniqueId = _anonymousUserUniqueId;

    var room = roomData["data"]["room"];
    var owner = room["owner"];

    final status = int.tryParse(room['status']?.toString() ?? '') ?? 0;

    if (status == 4) {
      var result = await getRoomDetailByWebRid(webRid);
      return result;
    }

    var roomStatus = status == 2;
    final totalViewers = roomStatus ? douyinTotalViewers(room) : '';
    final onlineViewers = roomStatus ? douyinOnlineViewers(room) : '';
    final nativeAudience = totalViewers.isNotEmpty ? totalViewers : onlineViewers;
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
      platform: PlatformIds.douyin,
      area: _detailArea(room, null),
      liveStatus: roomStatus ? LiveStatus.live : LiveStatus.offline,
      startedAt: roomStatus ? _douyinStartedAt(room) : null,
      introduction: owner["signature"].toString(),
      notice: "",
      danmakuData: DouyinDanmakuArgs(
        webRid: webRid,
        roomId: roomId,
        userId: userUniqueId,
        cookie: headers["cookie"]?.toString() ?? "",
      ),
      data: room["stream_url"],
    );
  }

  static bool _douyinIsLive(dynamic room, dynamic envelope) {
    final status = int.tryParse(room is Map ? (room['status']?.toString() ?? '') : '');
    if (status != null) return status == 2;
    final roomStatus = int.tryParse(envelope is Map ? (envelope['room_status']?.toString() ?? '') : '');
    return roomStatus == 0;
  }

  static DateTime? _douyinStartedAt(dynamic room) {
    if (room is! Map) return null;
    for (final key in const ['start_time', 'create_time']) {
      final seconds = int.tryParse(room[key]?.toString() ?? '');
      if (seconds == null || seconds <= 0) continue;
      final time = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
      if (time.year >= 2000 && time.year <= 2100) return time;
    }
    return null;
  }

  static String _detailArea(dynamic room, dynamic roadMap) {
    String? title(dynamic node) {
      final partition = node is Map ? node['partition'] : null;
      final value = partition is Map ? partition['title']?.toString().trim() : null;
      return value == null || value.isEmpty ? null : value;
    }

    final gameData = room is Map ? room['game_data'] : null;
    final gameTagInfo = gameData is Map ? gameData['game_tag_info'] : null;
    final gameName = gameTagInfo is Map ? gameTagInfo['game_tag_name']?.toString().trim() : null;
    for (final candidate in [
      gameName,
      title(roadMap is Map ? roadMap['sub_partition'] : null),
      title(roadMap),
    ]) {
      if (candidate != null && candidate.isNotEmpty) return candidate;
    }
    return '';
  }

  Future<LiveRoom> getRoomDetailByWebRid(String webRid) async {
    try {
      var result = await _getRoomDetailByWebRidApi(webRid);
      return result;
    } catch (e) {
      CoreLog.error(e);
    }
    return await _getRoomDetailByWebRidHtml(webRid);
  }

  Future<LiveRoom> _getRoomDetailByWebRidApi(String webRid) async {
    var data = await _getRoomDataByApi(webRid);

    var roomData = data["data"][0];
    var userData = data["user"];
    var roomId = roomData["id_str"].toString();

    var userUniqueId = _anonymousUserUniqueId;

    var owner = roomData["owner"];

    final roomStatus = _douyinIsLive(roomData, data);
    final totalViewers = roomStatus ? douyinTotalViewers(roomData) : '';
    final onlineViewers = roomStatus ? douyinOnlineViewers(roomData) : '';
    final nativeAudience = totalViewers.isNotEmpty ? totalViewers : onlineViewers;

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
      platform: PlatformIds.douyin,
      area: _detailArea(roomData, data["partition_road_map"]),
      introduction: owner?["signature"]?.toString() ?? "",
      notice: "",
      danmakuData: DouyinDanmakuArgs(
        webRid: webRid,
        roomId: roomId,
        userId: userUniqueId,
        cookie: headers["cookie"]?.toString() ?? "",
      ),
      data: roomStatus ? roomData["stream_url"] : {},
    );
  }

  Future<LiveRoom> _getRoomDetailByWebRidHtml(String roomId) async {
    var detail = await _getRoomDataByHtml(roomId);
    var webRid = roomId;

    var realRoomId = detail["roomStore"]["roomInfo"]["room"]["id_str"].toString();
    final rawUserUniqueId = detail["userStore"]["odin"]["user_unique_id"].toString();
    var userUniqueId = RegExp(r'^\d{19}$').hasMatch(rawUserUniqueId) ? rawUserUniqueId : _anonymousUserUniqueId;
    var roomInfo = detail["roomStore"]["roomInfo"]["room"];
    var owner = roomInfo["owner"];
    var anchor = detail["roomStore"]["roomInfo"]["anchor"];
    final roomStatus = int.tryParse(roomInfo['status']?.toString() ?? '') == 2;
    final totalViewers = roomStatus ? douyinTotalViewers(roomInfo) : '';
    final onlineViewers = roomStatus ? douyinOnlineViewers(roomInfo) : '';
    final nativeAudience = totalViewers.isNotEmpty ? totalViewers : onlineViewers;

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
      platform: PlatformIds.douyin,
      introduction: roomInfo["title"].toString(),
      notice: "",
      danmakuData: DouyinDanmakuArgs(
        webRid: webRid,
        roomId: realRoomId,
        userId: userUniqueId,
        cookie: headers["cookie"]?.toString() ?? "",
      ),
      data: roomStatus ? roomInfo["stream_url"] : {},
    );
  }

  // ignore: unused_element
  Future<String> _getUserUniqueId(String webRid) async {
    try {
      var webInfo = await _getRoomDataByHtml(webRid);
      return webInfo["userStore"]["odin"]["user_unique_id"].toString();
    } catch (e) {
      return _anonymousUserUniqueId;
    }
  }

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
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom liveroom}) async {
    return parseStreamQualities(liveroom.data);
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
      // Douyin may publish an `ao` entry beside its video renditions. It is
      // an audio-only pull URL (`only_audio=1`), not a selectable video
      // quality. Exposing it in the quality menu produced a raw "ao" button
      // and could leave the player without a video track after selection.
      if (_isAudioOnlyVariant(key, urls)) continue;

      final configuredName = descriptor['name']?.toString().trim() ?? '';
      final resolutionName = _caseInsensitiveMapValue(resolutionNames, key)?.toString().trim() ?? '';
      final sdkParams = _decodeSdkParams(main is Map ? main['sdk_params'] : null);
      final bitRate =
          int.tryParse(descriptor['v_bit_rate']?.toString() ?? '') ??
          int.tryParse(sdkParams['vbitrate']?.toString() ?? '');
      final resolution = descriptor['resolution']?.toString().trim().isNotEmpty == true
          ? descriptor['resolution'].toString()
          : sdkParams['resolution']?.toString();
      final level = int.tryParse(descriptor['level']?.toString() ?? '') ?? 0;
      final knownRank = _douyinQualityRank(key);
      // `v_bit_rate` is a stream property, not the quality hierarchy. Source
      // can legitimately have a lower instantaneous bitrate than a transcoded
      // tier; SDK key/level therefore owns ordering and bitrate is metadata.
      final sort = knownRank > 0
          ? knownRank
          : level > 0
          ? level * 1000000
          : bitRate ?? 0;
      qualities.add(
        LivePlayQuality(
          quality: LiveQualityLabel.normalize(
            platform: PlatformIds.douyin,
            rawLabel: configuredName.isNotEmpty
                ? configuredName
                : resolutionName.isNotEmpty
                ? resolutionName
                : key,
            id: key,
            bitrate: bitRate,
            resolution: resolution,
          ),
          id: key.toLowerCase(),
          sort: sort,
          data: List<String>.unmodifiable(urls),
          declaredAspectRatio: _declaredAspectRatio(
            main: main is Map ? main : null,
            descriptor: descriptor,
            sdkParams: sdkParams,
          ),
        ),
      );
    }

    qualities.sort((left, right) {
      final rank = right.sort.compareTo(left.sort);
      return rank != 0 ? rank : left.selectionId.toString().compareTo(right.selectionId.toString());
    });

    // Platform aliases can expose the same actual URL under both legacy
    // (`FULL_HD1`) and modern (`uhd`) keys. Presenting both would claim a
    // quality change even though the player receives an identical source.
    final seenStreams = <String>{};
    return qualities
        .where((quality) {
          final urls = (quality.data as List).map((url) => url.toString()).toList()..sort();
          return seenStreams.add(urls.join('\u0000'));
        })
        .toList(growable: false);
  }

  static Map<dynamic, dynamic> _decodeSdkParams(dynamic raw) {
    if (raw is Map) return raw;
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return const <dynamic, dynamic>{};
    try {
      final decoded = jsonDecode(value);
      return decoded is Map ? decoded : const <dynamic, dynamic>{};
    } catch (_) {
      return const <dynamic, dynamic>{};
    }
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

  static bool _isAudioOnlyVariant(String key, List<String> urls) {
    final token = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    if (const {'ao', 'audio', 'audioonly'}.contains(token)) return true;
    if (urls.isEmpty) return false;
    return urls.every((url) {
      final uri = Uri.tryParse(url);
      final value = uri?.queryParameters['only_audio']?.toLowerCase();
      return value == '1' || value == 'true';
    });
  }

  static int _douyinQualityRank(String key) => switch (key.toUpperCase()) {
    'ORIGION' || 'ORIGIN' => 6000000,
    'FULL_HD1' || 'UHD' => 5000000,
    'HD1' || 'HD' => 4000000,
    'SD2' || 'SD' => 3000000,
    'SD1' || 'LD' => 2000000,
    'MD' => 1000000,
    _ => 0,
  };

  static double? _declaredAspectRatio({
    required Map<dynamic, dynamic>? main,
    required Map<dynamic, dynamic> descriptor,
    required Map<dynamic, dynamic> sdkParams,
  }) {
    ({int width, int height})? fromResolution(Object? value) {
      final match = RegExp(r'(\d{2,5})\s*[xX×*]\s*(\d{2,5})').firstMatch(value?.toString() ?? '');
      if (match == null) return null;
      return _plausibleSize(int.tryParse(match[1]!), int.tryParse(match[2]!));
    }

    final sdkResolution = sdkParams['resolution'];
    final descriptorResolution = descriptor['resolution'];
    final size =
        _plausibleSizeValues(main?['width'], main?['height']) ??
        _plausibleSizeValues(sdkParams['width'], sdkParams['height']) ??
        fromResolution(sdkResolution) ??
        fromResolution(descriptorResolution);
    return size == null ? null : size.width / size.height;
  }

  static ({int width, int height})? _plausibleSizeValues(Object? rawWidth, Object? rawHeight) =>
      _plausibleSize(int.tryParse(rawWidth?.toString() ?? ''), int.tryParse(rawHeight?.toString() ?? ''));

  static ({int width, int height})? _plausibleSize(int? width, int? height) {
    if (width == null || height == null || width < 120 || height < 120 || width > 16384 || height > 16384) {
      return null;
    }
    final ratio = width / height;
    return ratio < 0.30 || ratio > 3.50 ? null : (width: width, height: height);
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom liveroom, required LivePlayQuality quality}) async {
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
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({required LiveRoom liveroom}) {
    return Future.value(<LiveSuperChatMessage>[]);
  }

  String generateRandomString(int length) {
    var random = math.Random.secure();
    var values = List<int>.generate(length, (i) => random.nextInt(16));
    StringBuffer stringBuffer = StringBuffer();
    for (var item in values) {
      stringBuffer.write(item.toRadixString(16));
    }
    return stringBuffer.toString();
  }

  /// Mirrors the numeric visitor-ID range produced by Douyin's current web
  /// client: 7.3e18 (inclusive) through 8e18 (exclusive).
  @visibleForTesting
  static String generateAnonymousUserUniqueId({math.Random? random}) {
    final source = random ?? math.Random.secure();
    final value = StringBuffer('7')..write(3 + source.nextInt(7));
    for (var i = 0; i < 17; i++) {
      value.write(source.nextInt(10));
    }
    return value.toString();
  }

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
