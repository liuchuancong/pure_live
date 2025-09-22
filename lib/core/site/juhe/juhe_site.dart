import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/danmaku/empty_danmaku.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/model/live_category_result.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/model/live_play_quality_play_url_info.dart';
import 'package:pure_live/model/live_search_result.dart';
import 'package:pure_live/plugins/extension/string_extension.dart';

import '../../../common/utils/js_engine.dart';
import '../../../modules/areas/areas_list_controller.dart';
import '../../../modules/util/json_util.dart';
import '../../common/core_log.dart';
import '../../common/http_client.dart';
import 'juhe_site_mixin.dart';

class JuheSite extends LiveSite with JuheSiteMixin {
  @override
  String get id => 'juhe';

  @override
  String get name => "聚合";

  Map<String, String> getHeaders() {
    return {
      'Accept': '*/*',
      'Sec-Fetch-Dest': 'empty',
      'Sec-Fetch-Mode': 'cors',
      'Sec-Fetch-Site': 'same-site',
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
      "Cookie": SettingsService.instance.siteCookies[id] ?? "",
    };
  }

  String cookie = '';
  Map<String, String> cookieObj = {};

  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    var resultText = await HttpClient.instance.getJson(
      "http://api.vipmisss.com:81/xcdsw/json.txt",
      queryParameters: {},
      header: getHeaders(),
    );
    var result = JsonUtil.decode(resultText);
    List<LiveCategory> categories = [];
    List<LiveArea> list = [];
    var categoryTabs = result["pingtai"] ?? [];
    var typeName = "平台";
    for (var item in categoryTabs) {
      list.add(LiveArea(
          platform: id,
          areaId: item["address"].toString(),
        areaName: item["title"].toString(),
        areaPic: item["xinimg"].toString(),
        typeName: typeName,
      ),
      );
    }
    categories.add(LiveCategory(id: id, name: typeName, children: list));
    return categories;
  }

  final Map<String, dynamic> headers = {
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36',
    'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3',
    'connection': 'keep-alive',
    'sec-ch-ua': 'Google Chrome;v=107, Chromium;v=107, Not=A?Brand;v=24',
    'sec-ch-ua-platform': 'macOS',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'same-origin',
    'Sec-Fetch-User': '?1'
  };

  @override
  Future<LiveCategoryResult> getCategoryRooms(LiveArea category, {int page = 1}) async {
    CoreLog.d("getCategoryRooms: ${json.encode(category)}");
    if(page > 1) {
      return LiveCategoryResult(hasMore: false, items: []);
    }
    var resultText = await HttpClient.instance.getJson(
      "http://api.vipmisss.com:81/xcdsw/${category.areaId}",
      queryParameters: {},
      header: getHeaders(),
    );
    var result = JsonUtil.decode(resultText);
    var items = <LiveRoom>[];
    for (var item in result["zhubo"]) {
      var roomItem = LiveRoom(
        roomId: item["title"]?.toString() ?? '',
        title: item['title'] ?? '',
        cover: validImgUrl(item['img'] ?? ''),
        nick: item["title"].toString(),
        avatar: validImgUrl(item["img"]),
        link: item["address"].toString(),
        area: category.areaName,
        liveStatus: LiveStatus.live,
        status: true,
        platform: id,
      );
      items.add(roomItem);
    }
    return LiveCategoryResult(hasMore: false, items: items);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    List<LivePlayQuality> qualities = [];
    var livePlayQuality = LivePlayQuality(quality: "高清", data: "", bitRate: 1000);
    livePlayQuality.playUrlList.add(LivePlayQualityPlayUrlInfo(playUrl: detail.link??""));
    qualities.add(livePlayQuality);
    // 排序清晰度
    return Future.value(qualities);
  }

  @override
  Future<List<LivePlayQualityPlayUrlInfo>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    return quality.playUrlList;
  }

  @override
  Future<LiveCategoryResult> getRecommendRooms({int page = 1, required String nick}) async {
    if(page > 1) {
      return LiveCategoryResult(hasMore: false, items: []);
    }
    var roomAreaName = "卡哇伊";
    var map = await getAreaNameMap();
    var tmpLiveArea = map[roomAreaName];
    if(tmpLiveArea == null) {
      return LiveCategoryResult(hasMore: false, items: [],);
    }
    return await getCategoryRooms(tmpLiveArea);
  }

  @override
  Future<LiveRoom> getRoomDetail({required LiveRoom detail}) async {
    if(detail.link.isNotNullOrEmpty) {
      return detail;
    }
    var roomAreaName = detail.area ?? "";
    var map = await getAreaNameMap();
    var tmpLiveArea = map[roomAreaName];
    if(tmpLiveArea == null) {
      return getLiveRoomWithError(detail);
    }
    var liveCategoryResult = await getCategoryRooms(tmpLiveArea);
    var items = liveCategoryResult.items;
    for (var item in items) {
      if(item.roomId == detail.roomId) {
        return item;
      }
    }
    return getLiveRoomWithError(detail);
  }

  var areaNameMap = <String, LiveArea>{};

  Future<Map<String, LiveArea>> getAreaNameMap() async {
    if (areaNameMap.isEmpty) {
      var find = Get.find<AreasListController>(tag: id);
      List<LiveCategory> data = await find.getData(1, 100);
      for (var liveCategory in data) {
        for (var liveArea in liveCategory.children) {
          var areaName = liveArea.areaName ?? "";
          areaNameMap[areaName] = liveArea;
        }
      }
    }
    return areaNameMap;
  }

  @override
  Future<LiveSearchRoomResult> searchRooms(String keyword, {int page = 1}) async {
    if(page > 1) {
      return LiveSearchRoomResult(hasMore: false, items: []);
    }
    var liveCategoryResult = await getRecommendRooms(nick: "");
    var items = liveCategoryResult.items;
    var list = <LiveRoom>[];
    for (var item in items) {
      var title = item.title ?? "";
      if(title.contains(keyword)) {
        list.add(item);
      }
    }
    return Future.value(LiveSearchRoomResult(hasMore: false, items: list));
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
