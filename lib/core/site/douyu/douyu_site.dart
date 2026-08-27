import 'dart:convert';

import 'package:pure_live/common/index.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/model/live_anchor_item.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/danmaku/douyu_danmaku.dart';
import 'package:pure_live/core/site/douyu/douyu_utils.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/utils/live_quality_label.dart';
import 'package:pure_live/modules/live_play/controllers/player_controller.dart';

class DouyuSite implements LiveSite, LiveSiteRoomRefresher, LiveSiteRecordRoomResolver {
  @override
  String id = Sites.douyuSite;

  @override
  String name = "斗鱼直播";

  @override
  LiveDanmaku getDanmaku() => DouyuDanmaku();

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    List<LiveCategory> categories = [];
    var result = await HttpClient.instance.getJson("https://m.douyu.com/api/cate/list");
    var subCateList = result["data"]["cate2Info"] as List;
    for (var item in result["data"]["cate1Info"]) {
      var cate1Id = item["cate1Id"];
      var cate1Name = item["cate1Name"];
      List<LiveArea> subCategories = [];
      subCateList.where((x) => x["cate1Id"] == cate1Id).forEach((element) {
        subCategories.add(
          LiveArea(
            areaPic: element["icon"].toString(),
            areaId: element["cate2Id"].toString(),
            typeName: cate1Name.toString(),
            areaType: cate1Id.toString(),
            platform: Sites.douyuSite,
            areaName: element["cate2Name"].toString(),
          ),
        );
      });
      categories.add(LiveCategory(id: cate1Id.toString(), name: cate1Name.toString(), children: subCategories));
    }
    categories.sort((a, b) => int.parse(a.id).compareTo(int.parse(b.id)));

    return categories;
  }

  Future<List<LiveArea>> getSubCategories(LiveCategory liveCategory) async {
    var result = await HttpClient.instance.getJson(
      "https://www.douyu.com/japi/weblist/apinc/getC2List",
      queryParameters: {"shortName": liveCategory.name, "customClassId": liveCategory.id, "offset": 0, "limit": 200},
    );

    List<LiveArea> subs = [];
    for (var item in result["data"]["list"]) {
      subs.add(
        LiveArea(
          areaPic: item["squareIconUrlW"].toString(),
          areaId: item["cid2"].toString(),
          typeName: liveCategory.name,
          areaType: liveCategory.id,
          platform: Sites.douyuSite,
          areaName: item["cname2"].toString(),
        ),
      );
    }

    return subs;
  }

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    var result = await HttpClient.instance.getJson(
      "https://www.douyu.com/gapi/rkc/directory/mixList/2_${category.areaId}/$page",
      queryParameters: {},
    );

    var items = <LiveRoom>[];
    for (var item in result['data']['rl']) {
      if (item["type"] != 1) {
        continue;
      }
      var roomItem = LiveRoom(
        cover: item['rs16'].toString(),
        watching: item['ol'].toString(),
        popularity: item['ol'].toString(),
        audienceMetricType: AudienceMetricType.popularity,
        roomId: item['rid'].toString(),
        title: item['rn'].toString(),
        nick: item['nn'].toString(),
        area: item['c2name'].toString(),
        liveStatus: LiveStatus.live,
        avatar: item['av'].toString().isNotEmpty ? 'https://apic.douyucdn.cn/upload/${item['av']}_middle.jpg' : '',
        status: true,
        platform: Sites.douyuSite,
      );
      items.add(roomItem);
    }
    return items;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    final roomId = detail.roomId ?? '';
    final playData = await _requestPlayData(roomId);
    final cdns = parseCdnCodes(playData);
    cdns.sort((a, b) {
      if (a.startsWith("scdn") && !b.startsWith("scdn")) {
        return 1;
      } else if (!a.startsWith("scdn") && b.startsWith("scdn")) {
        return -1;
      }
      return 0;
    });
    return parsePlayQualities(playData, cdns);
  }

  /// Keeps Douyu's advertised `multirates` order. The numeric `rate` is an
  /// opaque request code (source is commonly 0), not a bitrate; sorting it in
  /// descending numeric order reverses source and low-quality choices.
  @visibleForTesting
  static List<LivePlayQuality> parsePlayQualities(Map<String, dynamic> playData, List<String> cdns) {
    final qualities = <LivePlayQuality>[];
    final rates = playData['multirates'];
    if (rates is List) {
      final rateItems = rates.whereType<Map>().toList(growable: false);
      for (var index = 0; index < rateItems.length; index++) {
        final item = rateItems[index];
        final rate = _asInt(item['rate']);
        if (rate == null) continue;
        final name = item['name']?.toString().trim();
        if (qualities.any((quality) => quality.selectionId == rate)) continue;
        qualities.add(
          LivePlayQuality(
            quality: LiveQualityLabel.normalize(
              platform: Sites.douyuSite,
              rawLabel: name?.isNotEmpty == true ? name! : '',
              id: rate,
            ),
            id: rate,
            sort: rateItems.length - index,
            data: DouyuPlayData(rate, List<String>.unmodifiable(cdns)),
          ),
        );
      }
    }
    if (qualities.isEmpty) {
      final rate = _asInt(playData['rate']) ?? -1;
      qualities.add(
        LivePlayQuality(
          quality: LiveQualityLabel.normalize(platform: Sites.douyuSite, rawLabel: 'default', id: rate),
          id: rate,
          sort: 1,
          data: DouyuPlayData(rate, List.unmodifiable(cdns)),
        ),
      );
    }
    return qualities;
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    final rawData = quality.data;
    if (rawData is! DouyuPlayData) return const <String>[];
    final data = rawData;
    final urls = <String>[];
    Object? lastError;
    for (final cdn in data.cdns) {
      try {
        final url = await getPlayUrl(detail.roomId!, data.rate, cdn);
        if (url.isNotEmpty && !urls.contains(url)) urls.add(url);
      } catch (error) {
        lastError = error;
      }
    }
    if (urls.isEmpty && lastError != null) throw lastError;
    return urls;
  }

  Future<String> getPlayUrl(String roomId, int rate, String cdn) async {
    final playData = await _requestPlayData(roomId, rate: rate, cdn: cdn);
    return parsePlayUrl(playData);
  }

  Future<Map<String, dynamic>> _requestPlayData(String roomId, {int rate = -1, String cdn = ''}) async {
    if (roomId.trim().isEmpty) {
      throw const DouyuPlayApiException('room id is empty');
    }
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final sign = await DouyuUtils.sign(roomId, rate: rate, cdn: cdn, forceRefresh: attempt > 0);
        final result = await HttpClient.instance.postJson(
          'https://www.douyu.com/lapi/live/getH5PlayV1/$roomId',
          data: sign,
          formUrlEncoded: true,
          header: DouyuUtils.requestHeaders(roomId),
        );
        return parsePlayResponse(result);
      } catch (error) {
        lastError = error;
      }
    }
    throw DouyuPlayApiException('H5 play request failed after retry', cause: lastError);
  }

  @visibleForTesting
  static Map<String, dynamic> parsePlayResponse(dynamic response) {
    if (response is! Map) {
      throw const DouyuPlayApiException('H5 play response is not an object');
    }
    final errorCode = _asInt(response['error']) ?? _asInt(response['code']) ?? -1;
    if (errorCode != 0) {
      final message = response['msg']?.toString().trim();
      throw DouyuPlayApiException('H5 play API error $errorCode${message?.isNotEmpty == true ? ': $message' : ''}');
    }
    final rawData = response['data'];
    if (rawData is! Map) {
      throw const DouyuPlayApiException('H5 play response is missing data');
    }
    return Map<String, dynamic>.from(rawData);
  }

  @visibleForTesting
  static List<String> parseCdnCodes(Map<String, dynamic> data) {
    final result = <String>[];
    final rawCdns = data['cdnsWithName'];
    if (rawCdns is List) {
      for (final item in rawCdns.whereType<Map>()) {
        final code = item['cdn']?.toString().trim() ?? '';
        if (code.isNotEmpty && !result.contains(code)) result.add(code);
      }
    }
    final current = data['rtmp_cdn']?.toString().trim() ?? '';
    if (current.isNotEmpty && !result.contains(current)) result.insert(0, current);
    if (result.isEmpty) result.add('');
    return result;
  }

  @visibleForTesting
  static String parsePlayUrl(Map<String, dynamic> data) {
    final unescape = HtmlUnescape();
    for (final key in const <String>['flv_url', 'stream_url', 'url']) {
      final value = unescape.convert(data[key]?.toString().trim() ?? '');
      if (_isPlayableUrl(value)) return value;
    }

    final live = unescape.convert(data['rtmp_live']?.toString().trim() ?? '');
    if (_isPlayableUrl(live)) return live;
    final base = unescape.convert(data['rtmp_url']?.toString().trim() ?? '');
    if (base.isNotEmpty && live.isNotEmpty) {
      final combined = '${base.replaceFirst(RegExp(r'/+$'), '')}/${live.replaceFirst(RegExp(r'^/+'), '')}';
      if (_isPlayableUrl(combined)) return combined;
    }
    throw const DouyuPlayApiException('H5 play response has no playable URL');
  }

  static int? _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static bool _isPlayableUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.host.isNotEmpty && const {'http', 'https', 'rtmp'}.contains(uri.scheme);
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    try {
      var result = await HttpClient.instance.getJson(
        "https://www.douyu.com/japi/weblist/apinc/allpage/6/$page",
        queryParameters: {},
      );

      var items = <LiveRoom>[];
      for (var item in result['data']['rl']) {
        if (item["type"] != 1) {
          continue;
        }

        var roomItem = LiveRoom(
          cover: item['rs16'].toString(),
          watching: item['ol'].toString(),
          popularity: item['ol'].toString(),
          audienceMetricType: AudienceMetricType.popularity,
          roomId: item['rid'].toString(),
          title: item['rn'].toString(),
          nick: item['nn'].toString(),
          area: item['c2name'].toString(),
          avatar: item['av'] ?? '',
          platform: Sites.douyuSite,
          status: true,
          liveStatus: LiveStatus.live,
        );
        items.add(roomItem);
      }
      return items;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<LiveRoom> getRoomDetail({required String platform, required String roomId}) async {
    try {
      final roomInfo = await _fetchRoomInfo(roomId);

      return _buildRoom(roomInfo, roomId: roomId);
    } catch (e) {
      if (Get.isRegistered<PlayerController>()) {
        final PlayerController playerController = Get.find<PlayerController>();

        final currentRoom = playerController.currentRoom;
        if (currentRoom?.hasIdentity(platform: platform, roomId: roomId) == true) {
          return currentRoom!.getLiveRoomWithError();
        }
      }

      return LiveRoom(roomId: roomId, platform: platform).getLiveRoomWithError();
    }
  }

  @override
  Future<LiveRoom> getRoomDetailForRefresh({required String platform, required String roomId}) async {
    final roomInfo = await _fetchRoomInfo(roomId);

    return _buildRoom(roomInfo, roomId: roomId);
  }

  @override
  Future<LiveRoom> getRoomDetailForRecording({required String platform, required String roomId}) async {
    // Do not use getRoomDetail here: its UI fallback converts a failed betard
    // request into an offline room, which previously stopped recording before
    // Douyu signing/getH5PlayV1 was reached.
    final roomInfo = await _fetchRoomInfo(roomId);
    return _buildRoom(roomInfo, roomId: roomId);
  }

  Future<Map<dynamic, dynamic>> _fetchRoomInfo(String roomId) async {
    var result = await HttpClient.instance.getJson(
      "https://www.douyu.com/betard/$roomId",
      queryParameters: {},
      header: {
        'referer': 'https://www.douyu.com/$roomId',
        'user-agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.43',
      },
    );
    Map roomInfo;

    if (result is String) {
      roomInfo = json.decode(result)["room"];
    } else {
      roomInfo = result["room"];
    }
    return roomInfo;
  }

  LiveRoom _buildRoom(Map<dynamic, dynamic> roomInfo, {required String roomId}) {
    final live = isLiveRoomPayload(roomInfo);
    final replay = _asInt(roomInfo['videoLoop']) == 1;

    return LiveRoom(
      cover: roomInfo["room_pic"].toString(),
      watching: roomInfo["room_biz_all"]["hot"].toString(),
      popularity: roomInfo["room_biz_all"]["hot"].toString(),
      audienceMetricType: AudienceMetricType.popularity,
      roomId: roomInfo["room_id"].toString(),
      title: roomInfo["room_name"].toString(),
      nick: roomInfo["owner_name"].toString(),
      avatar: roomInfo["owner_avatar"].toString(),
      introduction: roomInfo["show_details"].toString(),
      area: roomInfo["second_lvl_name"]?.toString() ?? '',
      notice: "",
      liveStatus: live ? LiveStatus.live : LiveStatus.offline,
      status: live,
      danmakuData: roomInfo["room_id"].toString(),
      data: null,
      platform: Sites.douyuSite,
      link: "https://www.douyu.com/$roomId",
      isRecord: replay,
    );
  }

  @visibleForTesting
  static bool isLiveRoomPayload(Map<dynamic, dynamic> roomInfo) {
    return _asInt(roomInfo['show_status']) == 1 &&
        _asInt(roomInfo['videoLoop']) != 1 &&
        !roomInfo['room_name'].toString().startsWith('【回放】');
  }

  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) async {
    final effectivePageSize = pageSize.clamp(1, 50);
    final headers = DouyuUtils.requestHeaders()..['referer'] = 'https://www.douyu.com/search/';

    var result = await HttpClient.instance.getJson(
      "https://www.douyu.com/japi/search/api/searchShow",
      queryParameters: {"kw": keyword, "page": page, "pageSize": effectivePageSize},
      header: headers,
    );

    if (result['error'] != 0) {
      throw Exception(result['msg']);
    }

    var items = <LiveRoom>[];

    var queryList = result["data"]["relateShow"] ?? [];

    for (var item in queryList) {
      var liveStatus = (int.tryParse(item["isLive"].toString()) ?? 0) == 1;

      var roomType = int.tryParse(item["roomType"].toString()) ?? 0;

      var isLive = liveStatus && roomType == 0;

      var roomItem = LiveRoom(
        roomId: item["rid"].toString(),
        title: item["roomName"].toString(),
        cover: item["roomSrc"].toString(),
        area: item["cateName"].toString(),
        avatar: item["avatar"].toString(),
        liveStatus: isLive ? LiveStatus.live : LiveStatus.offline,
        status: isLive,
        nick: item["nickName"].toString(),
        platform: Sites.douyuSite,
        watching: item["hot"].toString(),
        popularity: item["hot"].toString(),
        audienceMetricType: AudienceMetricType.popularity,
      );

      items.add(roomItem);
    }

    return items;
  }

  @override
  Future<List<LiveAnchorItem>> searchAnchors(String keyword, {int page = 1, int pageSize = 30}) async {
    final effectivePageSize = pageSize.clamp(1, 50);
    final headers = DouyuUtils.requestHeaders()..['referer'] = 'https://www.douyu.com/search/';

    var result = await HttpClient.instance.getJson(
      "https://www.douyu.com/japi/search/api/searchUser",
      queryParameters: {"kw": keyword, "page": page, "pageSize": effectivePageSize, "filterType": 1},
      header: headers,
    );

    var items = <LiveAnchorItem>[];

    for (var item in result["data"]["relateUser"]) {
      var liveStatus = (int.tryParse(item["anchorInfo"]["isLive"].toString()) ?? 0) == 1;

      var roomType = int.tryParse(item["anchorInfo"]["roomType"].toString()) ?? 0;

      var roomItem = LiveAnchorItem(
        roomId: item["anchorInfo"]["rid"].toString(),
        avatar: item["anchorInfo"]["avatar"].toString(),
        userName: item["anchorInfo"]["nickName"].toString(),
        liveStatus: liveStatus && roomType == 0,
      );

      items.add(roomItem);
    }

    return items;
  }

  @override
  Future<bool> getLiveStatus({required String platform, required String roomId}) async {
    var roomInfo = await _fetchRoomInfo(roomId);
    return isLiveRoomPayload(roomInfo);
  }

  int parseHotNum(String hn) {
    try {
      var num = double.parse(hn.replaceAll("万", ""));

      if (hn.contains("万")) {
        num *= 10000;
      }

      return num.round();
    } catch (_) {
      return -999;
    }
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({required String roomId}) {
    return Future.value([]);
  }
}

class DouyuPlayData {
  final int rate;
  final List<String> cdns;

  DouyuPlayData(this.rate, this.cdns);
}

class DouyuPlayApiException implements Exception {
  const DouyuPlayApiException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null ? 'DouyuPlayApiException: $message' : 'DouyuPlayApiException: $message ($cause)';
}
