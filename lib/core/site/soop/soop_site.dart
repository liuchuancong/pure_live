import 'dart:convert';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/danmaku/soop_danmaku.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/modules/live_play/controllers/player_controller.dart';

class SoopSite extends LiveSite implements LiveSiteRoomRefresher {
  @override
  String get id => Sites.soopSite;

  @override
  String get name => "SOOP直播";

  List<String> imageExtensions = [
    'svgz',
    'pjp',
    'png',
    'ico',
    'avif',
    'tiff',
    'tif',
    'jfif',
    'svg',
    'xbm',
    'pjpeg',
    'webp',
    'jpg',
    'jpeg',
    'bmp',
    'gif',
  ];

  @override
  LiveDanmaku getDanmaku() => SoopDanmaku();

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    List<LiveCategory> categories = [LiveCategory(id: "1", name: "热门", children: [])];

    List<Future> futures = [];
    for (var item in categories) {
      futures.add(
        Future(() async {
          var items = await getAllSubCategores(item, 1, 120, []);
          item.children.addAll(items);
        }),
      );
    }
    await Future.wait(futures);
    return categories;
  }

  static dynamic decode(dynamic data) {
    if (data.runtimeType == String) {
      return json.decode(data);
    }
    return data;
  }

  /// SOOP splits viewers across PC and mobile in recommendation/search
  /// payloads. `current_view_cnt` is PC-only; `total_view_cnt` (or the sum of
  /// the explicit PC/mobile fields) is the actual concurrent audience.
  @visibleForTesting
  static String parseOnlineViewers(Map<dynamic, dynamic> room) {
    String? explicitZero;

    String positiveValue(dynamic value) {
      final text = value?.toString().trim() ?? '';
      if (text.isEmpty || text == 'null' || !RegExp(r'[0-9]').hasMatch(text)) return '';
      final parsed = int.tryParse(text.replaceAll(',', '').replaceAll('，', ''));
      if (parsed == null) return '';
      if (parsed == 0) explicitZero ??= '0';
      return parsed > 0 ? parsed.toString() : '';
    }

    for (final value in [room['total_view_cnt'], room['view_cnt'], room['VIEW_CNT']]) {
      final parsed = positiveValue(value);
      if (parsed.isNotEmpty) return parsed;
    }

    int? sumPair(dynamic left, dynamic right) {
      final leftText = left?.toString().trim().replaceAll(',', '') ?? '';
      final rightText = right?.toString().trim().replaceAll(',', '') ?? '';
      final leftValue = int.tryParse(leftText);
      final rightValue = int.tryParse(rightText);
      if (leftValue == null && rightValue == null) return null;
      return (leftValue ?? 0) + (rightValue ?? 0);
    }

    for (final pair in [
      (room['pc_view_cnt'], room['mobile_view_cnt']),
      (room['current_view_cnt'], room['m_current_view_cnt']),
    ]) {
      final total = sumPair(pair.$1, pair.$2);
      if (total == null) continue;
      if (total > 0) return total.toString();
      explicitZero ??= '0';
    }

    return explicitZero ?? '';
  }

  final Map<String, dynamic> headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 6.3; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/37.0.2049.0 Safari/537.36',
    'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3',
    'connection': 'keep-alive',
    'sec-ch-ua': 'Google Chrome;v=107, Chromium;v=107, Not=A?Brand;v=24',
    'sec-ch-ua-platform': 'macOS',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'same-origin',
    'Sec-Fetch-User': '?1',
  };

  Future<List<LiveArea>> getAllSubCategores(
    LiveCategory liveCategory,
    int page,
    int pageSize,
    List<LiveArea> allSubCategores,
  ) async {
    try {
      var subsArea = await getSubCategores(liveCategory, page, pageSize);
      CoreLog.d("getAllSubCategores: $subsArea");
      allSubCategores.addAll(subsArea);
      var hasMore = subsArea.length >= pageSize;
      if (hasMore) {
        page++;
        await getAllSubCategores(liveCategory, page, pageSize, allSubCategores);
      }
      return allSubCategores;
    } catch (e) {
      CoreLog.error(e);
      return allSubCategores;
    }
  }

  Future<List<LiveArea>> getSubCategores(LiveCategory liveCategory, int page, int pageSize) async {
    var resultText = await HttpClient.instance.getJson(
      "https://sch.sooplive.co.kr/api.php",
      queryParameters: {
        "m": "categoryList",
        "szKeyword": "",
        "szOrder": "view_cnt",
        "nPageNo": page,
        "nListCnt": pageSize,
        "nOffset": "0",
        "szPlatform": "pc",
      },
      header: getHeaders(),
    );
    var result = decode(resultText);

    List<LiveArea> subs = [];
    for (var item in result["data"]["list"] ?? []) {
      var subCategory = LiveArea(
        areaId: item["category_no"],
        areaName: item["category_name"],
        areaType: liveCategory.id,
        platform: Sites.soopSite,
        areaPic: item["cate_img"],
        typeName: liveCategory.name,
      );
      subs.add(subCategory);
    }

    return subs;
  }

  bool isImage(String url) {
    if (url.isEmpty) {
      return false;
    }
    var ext = url.split('.').last;
    return imageExtensions.contains(ext.toLowerCase());
  }

  Map<String, String> getHeaders() {
    return {
      'Accept': '*/*',
      'Origin': 'https://www.sooplive.co.kr',
      'Referer': 'https://www.sooplive.co.kr/',
      'Sec-Fetch-Dest': 'empty',
      'Sec-Fetch-Mode': 'cors',
      'Sec-Fetch-Site': 'same-site',
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
      "Cookie": SettingsService.to.cookieManager.soopCookie.value,
    };
  }

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 10}) async {
    final effectivePageSize = pageSize.clamp(1, 60);
    var result = await HttpClient.instance.getJson(
      "https://sch.sooplive.co.kr/api.php",
      queryParameters: {
        "m": "categoryContentsList",
        "szType": "live",
        "nPageNo": page,
        "nListCnt": effectivePageSize,
        "szPlatform": "pc",
        "szOrder": "view_cnt_desc",
        "szCateNo": category.areaId,
      },
      header: getHeaders(),
    );
    result = decode(result);
    var items = <LiveRoom>[];
    for (var item in result["data"]["list"]) {
      final viewerCount = parseOnlineViewers(Map<dynamic, dynamic>.from(item as Map));
      var roomItem = LiveRoom(
        roomId: item["user_id"] ?? '',
        title: item['broad_title'] ?? '',
        cover: validImgUrl(item['thumbnail'] ?? ''),
        nick: item["user_nick"].toString(),
        watching: viewerCount,
        onlineViewers: viewerCount,
        audienceMetricType: AudienceMetricType.onlineViewers,
        avatar: validImgUrl(item["user_profile_img"]),
        area: category.areaName,
        liveStatus: LiveStatus.live,
        status: true,
        platform: Sites.soopSite,
      );
      items.add(roomItem);
    }
    return items;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) {
    List<LivePlayQuality> qualities = <LivePlayQuality>[];
    final qualityMap = <String, LivePlayQuality>{};
    final data = detail.data;
    final presets = data is Map ? data["viewpreset"] : null;
    if (presets is! List) return Future.value(qualities);
    for (final quality in presets.whereType<Map>()) {
      var key = quality["name"];
      if (key == null || key == "auto") {
        continue;
      }
      qualityMap.putIfAbsent(key, () {
        return LivePlayQuality(
          quality: key.toString(),
          id: key.toString(),
          sort: int.tryParse(quality["bps"].toString()) ?? 0,
          data: <String>[],
        );
      });
    }
    qualities = qualityMap.values.toList();
    qualities.sort((a, b) => b.sort.compareTo(a.sort));
    return Future.value(qualities);
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    final data = detail.data;
    if (data is! Map) return const [];

    final bno = data["bno"] ?? "";
    final rmd = data["rmd"] ?? "";
    final cdn = data["cdn"] ?? "";
    if (bno.isEmpty || rmd.isEmpty) {
      return const [];
    }

    try {
      final cdnUrl = await getCdnUrl(rmd: rmd, cdn: cdn, bno: bno, quality: quality.quality);
      final aid = await getStreamAid(roomId: detail.roomId ?? "", bno: bno, quality: quality.quality);

      if (cdnUrl.isEmpty || aid.isEmpty) return const [];
      return ['$cdnUrl?aid=$aid'];
    } catch (e) {
      CoreLog.error(e);
      return const [];
    }
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    var result = await HttpClient.instance.getJson(
      "https://live.sooplive.co.kr/api/main_broad_list_api.php",
      queryParameters: {
        "selectType": "action",
        "selectValue": "all",
        "orderType": "view_cnt",
        "pageNo": page,
        "lang": "ko_KR",
      },
      header: getHeaders(),
    );
    var items = <LiveRoom>[];
    CoreLog.d("$result");
    result = decode(result);
    for (var item in result["broad"]) {
      var roomId = item["user_id"] ?? '';
      final viewerCount = parseOnlineViewers(Map<dynamic, dynamic>.from(item as Map));
      var roomItem = LiveRoom(
        roomId: roomId,
        title: item['broad_title'] ?? '',
        cover: validImgUrl(item['broad_thumb'] ?? ''),
        nick: item["user_nick"].toString(),
        watching: viewerCount,
        onlineViewers: viewerCount,
        audienceMetricType: AudienceMetricType.onlineViewers,
        avatar: getAvatarUrlByRoomId(roomId),
        area: item["category_name"],
        liveStatus: LiveStatus.live,
        status: true,
        platform: Sites.soopSite,
      );
      items.add(roomItem);
    }
    return items;
  }

  @override
  Future<LiveRoom> getRoomDetail({required String platform, required String roomId}) async {
    try {
      Map<dynamic, dynamic> playerLiveApiFuture = await getPlayerLiveApiData(roomId: roomId);
      var danmakuFuture = geDanmakuArgs(playerLiveApiFuture, roomId);
      final room = await getLiveRoomByApi(playerLiveApiFuture, danmakuFuture, roomId);
      if (Get.isRegistered<PlayerController>()) {
        final currentRoom = Get.find<PlayerController>().currentRoom;
        if (currentRoom?.hasIdentity(platform: Sites.soopSite, roomId: roomId) == true) {
          return room.withAudienceFallbackFrom(currentRoom!);
        }
      }
      return room;
    } catch (e) {
      CoreLog.error(e);
      if (Get.isRegistered<PlayerController>()) {
        final PlayerController playerController = Get.find<PlayerController>();
        final currentRoom = playerController.currentRoom;
        if (currentRoom?.hasIdentity(platform: Sites.soopSite, roomId: roomId) == true) {
          return currentRoom!.getLiveRoomWithError();
        }
      }
      return LiveRoom(roomId: roomId, platform: Sites.soopSite).getLiveRoomWithError();
    }
  }

  @override
  Future<LiveRoom> getRoomDetailForRefresh({required String platform, required String roomId}) async {
    final data = await getPlayerLiveApiData(roomId: roomId);
    final channel = data['CHANNEL'];
    if (channel is! Map) {
      throw const FormatException('SOOP channel metadata is missing');
    }
    final rawResultCode = channel['RESULT'];
    final resultCode = rawResultCode is num ? rawResultCode.toInt() : int.tryParse(rawResultCode?.toString() ?? '');
    if (resultCode == null) {
      throw const FormatException('SOOP channel result code is missing');
    }
    if (resultCode == 0) {
      // SOOP documents zero as an explicit no-live response.
      return LiveRoom(roomId: roomId, platform: Sites.soopSite, status: false, liveStatus: LiveStatus.offline);
    }
    if (resultCode == -2) {
      return LiveRoom(roomId: roomId, platform: Sites.soopSite, status: false, liveStatus: LiveStatus.banned);
    }
    if (resultCode != 1) {
      // Login/session and malformed business responses are not proof that the
      // channel ended. Let startup verification retain an unknown state.
      throw StateError('SOOP room metadata returned code $resultCode');
    }
    // Favourite cards do not need websocket credentials or playback signing.
    return getLiveRoomByApi(data, null, roomId);
  }

  Future<LiveRoom> getLiveRoomByApi(
    Map<dynamic, dynamic> playerLiveApiData,
    SoopDanmakuArgs? danmakuArgs,
    String roomId,
  ) async {
    var playerLiveApi = playerLiveApiData;
    var jsonObj = playerLiveApi["CHANNEL"];

    int resultCode = jsonObj['RESULT'] ?? 0;
    // 业务码：1成功，-6需要登录，0无直播，‑2屏蔽
    if (resultCode != 1) {
      CoreLog.w("soop channel result code=$resultCode");
      if (Get.isRegistered<PlayerController>()) {
        final PlayerController playerController = Get.find<PlayerController>();
        final currentRoom = playerController.currentRoom;
        if (currentRoom?.hasIdentity(platform: Sites.soopSite, roomId: roomId) == true) {
          return currentRoom!.getLiveRoomWithError();
        }
      }
      return LiveRoom(roomId: roomId, platform: Sites.soopSite).getLiveRoomWithError();
    }

    var bno = jsonObj["BNO"].toString();
    var nick = jsonObj["BJNICK"];
    var rmd = jsonObj["RMD"]?.toString() ?? "";
    var cdn = jsonObj["CDN"]?.toString() ?? "";

    var jsonObj2 = jsonObj["CATEGORY_TAGS"];
    var area = "";
    if (jsonObj2 != null) {
      var sList = (jsonObj2 as List);
      if (sList.isNotEmpty) {
        area = sList[0];
      }
    }
    var sRoomId = jsonObj["BJID"].toString();
    var millisecondsSinceEpoch2 = DateTime.now().millisecondsSinceEpoch;
    var cover = validImgUrl("https://liveimg.sooplive.co.kr/m/$bno?_t=$millisecondsSinceEpoch2");
    var avatar = validImgUrl("https://stimg.sooplive.co.kr/LOGO/${sRoomId.substring(0, 2)}/$sRoomId/$sRoomId.jpg");

    var isLiving = jsonObj["VIEWPRESET"] != null;
    final viewerCount = parseOnlineViewers(Map<dynamic, dynamic>.from(jsonObj as Map));

    var data = {"viewpreset": jsonObj["VIEWPRESET"], "bno": bno, "rmd": rmd, "cdn": cdn};
    return LiveRoom(
      cover: cover,
      watching: viewerCount,
      onlineViewers: viewerCount,
      audienceMetricType: AudienceMetricType.onlineViewers,
      roomId: jsonObj["BJID"].toString(),
      userId: bno,
      area: area,
      title: jsonObj["TITLE"].toString(),
      nick: nick,
      avatar: avatar,
      introduction: '',
      notice: '',
      status: isLiving,
      liveStatus: isLiving ? LiveStatus.live : LiveStatus.offline,
      platform: Sites.soopSite,
      data: data,
      danmakuData: danmakuArgs,
    );
  }

  Future<String> getCdnUrl({
    required String rmd,
    required String cdn,
    required String bno,
    required String quality,
  }) async {
    String returnType;
    if (cdn.contains("gs_cdn")) {
      returnType = "gs_cdn_pc_web";
    } else if (cdn.contains("lg_cdn")) {
      returnType = "lg_cdn_pc_web";
    } else {
      returnType = cdn;
    }

    final assignUrl = "${rmd.replaceAll(RegExp(r'/$'), '')}/broad_stream_assign.html";

    var resultText = await HttpClient.instance.getJson(
      assignUrl,
      queryParameters: {'return_type': returnType, 'broad_key': '$bno-common-$quality-hls'},
      header: getHeaders(),
    );
    resultText = decode(resultText);
    var viewUrl = resultText['view_url'] ?? '';
    return viewUrl.toString();
  }

  Future<String> getStreamAid({required String roomId, required String bno, required String quality}) async {
    var url = "https://live.sooplive.co.kr/afreeca/player_live_api.php";
    var resultText = await HttpClient.instance.postJson(
      url,
      formUrlEncoded: true,
      queryParameters: {'bjid': roomId},
      data: {
        "bid": roomId,
        "bno": bno,
        "type": "aid",
        "pwd": "",
        "player_type": "html5",
        "stream_type": "common",
        "quality": quality,
        "mode": "landing",
        "from_api": "0",
        "is_revive": "false",
      },
      header: getHeaders(),
    );
    resultText = decode(resultText);
    var jsonObj = resultText['CHANNEL'];
    var aid = jsonObj["AID"] ?? "";
    return aid;
  }

  Future<Map> getPlayerLiveApiData({required String roomId}) async {
    var url = "https://live.sooplive.co.kr/afreeca/player_live_api.php";
    var resultText = await HttpClient.instance.postJson(
      url,
      formUrlEncoded: true,
      queryParameters: {'bjid': roomId},
      data: {
        "bid": roomId,
        "bno": "",
        "type": "live",
        "pwd": "",
        "player_type": "html5",
        "stream_type": "common",
        "quality": "HD",
        "mode": "landing",
        "from_api": "0",
        "is_revive": "false",
      },
      header: getHeaders(),
    );
    resultText = decode(resultText);
    return resultText;
  }

  SoopDanmakuArgs? geDanmakuArgs(Map<dynamic, dynamic> resultTextFuture, String roomId) {
    try {
      var resultText = resultTextFuture;
      var jsonObj = resultText['CHANNEL'];
      var chatNo = jsonObj["CHATNO"];
      var chatDomain = jsonObj["CHDOMAIN"];
      var chpt = jsonObj["CHPT"];
      final wsUrl = 'wss://$chatDomain:$chpt/Websocket/$roomId';
      return SoopDanmakuArgs(url: wsUrl, chatNo: chatNo);
    } catch (e) {
      CoreLog.w("$e");
      return null;
    }
  }

  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) async {
    final effectivePageSize = pageSize.clamp(1, 50);
    var resultText = await HttpClient.instance.getJson(
      "https://sch.sooplive.co.kr/api.php",
      queryParameters: {
        "l": "DF",
        "m": "liveSearch",
        "c": "UTF-8",
        "w": "webk",
        "isMobile": "0",
        "onlyParent": "1",
        "szType": "json",
        "szOrder": "score",
        "szKeyword": keyword,
        "nPageNo": page,
        "nListCnt": effectivePageSize,
        "tab": "live",
        "location": "total_search",
        "isHashSearch": "0",
        "v": "2.0",
      },
      header: getHeaders(),
    );
    var result = decode(resultText);
    var items = <LiveRoom>[];
    var queryList = result["REAL_BROAD"] ?? [];
    for (var item in queryList) {
      var cover = item["broad_img"].toString();
      var userId = item["user_id"].toString();
      var title = item["broad_title"]?.toString() ?? "";
      var area = item["standard_broad_cate_name"]?.toString() ?? "";
      final viewerCount = parseOnlineViewers(Map<dynamic, dynamic>.from(item as Map));

      var roomItem = LiveRoom(
        roomId: userId,
        title: title,
        cover: validImgUrl(cover),
        nick: item["user_nick"].toString(),
        area: area,
        status: true,
        liveStatus: LiveStatus.live,
        avatar: getAvatarUrlByRoomId(userId),
        watching: viewerCount,
        onlineViewers: viewerCount,
        audienceMetricType: AudienceMetricType.onlineViewers,
        platform: Sites.soopSite,
      );
      items.add(roomItem);
    }
    return items;
  }

  String getAvatarUrlByRoomId(String roomId) {
    if (roomId.isEmpty || roomId.length < 2) {
      return "";
    }
    var part = roomId.substring(0, 2);
    return "https://stimg.sooplive.co.kr/LOGO/$part/$roomId/m/$roomId.webp";
  }

  String validImgUrl(String imgUrl) {
    if (imgUrl.isEmpty) {
      return "";
    }
    if (imgUrl.startsWith("//")) {
      return "https:$imgUrl";
    }
    return imgUrl;
  }
}
