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

import '../../../common/utils/js_engine.dart';
import '../../../modules/areas/areas_list_controller.dart';
import '../../../modules/util/json_util.dart';
import '../../common/core_log.dart';
import '../../common/http_client.dart';
import 'yy_site_mixin.dart';

class YYSite extends LiveSite with YYSiteMixin {
  @override
  String get id => 'yy';

  @override
  String get name => "YY";

  Map<String, String> getHeaders() {
    return {
      'Accept': '*/*',
      'Origin': 'https://www.yy.com',
      'Referer': 'https://www.yy.com/',
      'Sec-Fetch-Dest': 'empty',
      'Sec-Fetch-Mode': 'cors',
      'Sec-Fetch-Site': 'same-site',
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
      "Cookie": SettingsService.instance.siteCookies[id] ?? "",
    };
  }

  String cookie = '';
  Map<String, String> cookieObj = {};
  List<String> imageExtensions = ['svgz', 'pjp', 'png', 'ico', 'avif', 'tiff', 'tif', 'jfif', 'svg', 'xbm', 'pjpeg', 'webp', 'jpg', 'jpeg', 'bmp', 'gif'];

  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    var resultText = await HttpClient.instance.getJson(
      "https://www.yy.com/yyweb/module/data/header",
      queryParameters: {},
      header: getHeaders(),
    );
    var result = JsonUtil.decode(resultText);
    List<LiveCategory> categories = [];
    var categoryTabs = result["categoryTabs"] ?? [];
    for (var item in categoryTabs) {
      var title = item["title"].toString();
      var id = item["id"].toString();
      categories.add(LiveCategory(id: id, name: title, children: []));
    }

    List<Future> futures = [];
    for (var item in categories) {
      futures.add(Future(() async {
        var items = await getAllSubCategores(item, 1, 120, []);
        item.children.addAll(items);
      }));
    }
    await Future.wait(futures);
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

  Future<List<LiveArea>> getAllSubCategores(LiveCategory liveCategory, int page, int pageSize, List<LiveArea> allSubCategores) async {
    try {
      var subsArea = await getSubCategores(liveCategory, page, pageSize);
      CoreLog.d("getAllSubCategores: ${subsArea}");
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
      "https://www.yy.com/c/yycom/category/getCategory.action",
      queryParameters: {
        "parentId": liveCategory.id,
      },
      header: getHeaders(),
    );
    var result = JsonUtil.decode(resultText);

    List<LiveArea> subs = [];
    for (var item in result["data"] ?? []) {
      var subCategory = LiveArea(
        areaId: item["id"].toString(),
        areaName: item["title"],
        areaType: liveCategory.id,
        platform: id,
        areaPic: item["cover"],
        typeName: liveCategory.name,
      );
      var url = item["url"];
      var resultText = await HttpClient.instance.getText(
        url,
        queryParameters: {},
        header: getHeaders(),
      );
      // pageInfo = {
      //   pageBar: {totalPages:7, totalCount:156, pageSize:24, moduleId:313, biz:'dance', subBiz:'idx', showImpress:0},
      //   position: 'secondary',
      //   tmpl: 'secondaryPagerTpl'
      // };
      var jsonText = RegExp(r"pageInfo[^{]+([^;]+);", multiLine: true).firstMatch(resultText)?.group(1) ?? "";
      await JsEngine.init();
      var params = JsEngine.evaluate("pageInfo =" + jsonText);
      var pageInfo = params.rawResult;
      // var pageInfo = json.decode(jsonText);
      CoreLog.d("pageInfo: $pageInfo");
      var moduleId = pageInfo["pageBar"]["moduleId"];
      var biz = pageInfo["pageBar"]["biz"];
      var subBiz = pageInfo["pageBar"]["subBiz"];
      var map = {
        "moduleId": moduleId,
        "biz": biz,
        "subBiz": subBiz,
      };
      var encode = json.encode(map);

      /// 在 shortName 存放数据
      subCategory.shortName = encode;

      subs.add(subCategory);
    }

    return subs;
  }

  @override
  Future<LiveCategoryResult> getCategoryRooms(LiveArea category, {int page = 1}) async {
    CoreLog.d("getCategoryRooms: ${json.encode(category)}");
    var pageSize = 60;
    var shortName = category.shortName ?? "{}";
    var decode = json.decode(shortName) as Map;
    Map<String, dynamic> queryParameters = {
      "page": page,
      "pageSize": pageSize,
    };
    for (var key in decode.keys) {
      queryParameters[key] = decode[key];
    }
    var result = await HttpClient.instance.getJson(
      "https://www.yy.com/more/page.action",
      queryParameters: queryParameters,
      header: getHeaders(),
    );
    result = JsonUtil.decode(result);
    var items = <LiveRoom>[];
    for (var item in result["data"]["data"]) {
      var roomItem = LiveRoom(
        roomId: item["sid"]?.toString() ?? '',
        title: item['desc'] ?? '',
        cover: validImgUrl(item['thumb2'] ?? ''),
        nick: item["name"].toString(),
        userId: item["uid"].toString(),
        watching: item["users"].toString(),
        avatar: validImgUrl(item["avatar"]),
        area: category.areaName,
        liveStatus: LiveStatus.live,
        status: true,
        platform: id,
      );
      items.add(roomItem);
    }
    var hasMore = items.length >= pageSize;
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  getLiveStreamObj({required LiveRoom detail, required String qn}) async {
    var result = await HttpClient.instance.postJson(
      "https://stream-manager.yy.com/v3/channel/streams",
      queryParameters: {"uid": "0", "cid": detail.roomId, "sid": detail.roomId, "appid": "0", "sequence": "1755858374681", "encode": "json"},
      data: {
        "head": {
          "seq": 1755858374681,
          "appidstr": "0",
          "bidstr": "123",
          "cidstr": detail.roomId,
          "sidstr": detail.roomId,
          "uid64": 0,
          "client_type": 108,
          "client_ver": "5.19.4",
          "stream_sys_ver": 1,
          "app": "yylive_web",
          "playersdk_ver": "5.19.4",
          "thundersdk_ver": "0",
          "streamsdk_ver": "5.19.4"
        },
        "client_attribute": {
          "client": "web",
          "model": "web0",
          "cpu": "",
          "graphics_card": "",
          "os": "chrome",
          "osversion": "128.0.0.0",
          "vsdk_version": "",
          "app_identify": "",
          "app_version": "",
          "business": "",
          "width": "1366",
          "height": "768",
          "scale": "",
          "client_type": 8,
          "h265": 0
        },
        "avp_parameter": {"version": 1, "client_type": 8, "service_type": 0, "imsi": 0, "send_time": 1755858374, "line_seq": -1, "gear": int.parse(qn), "ssl": 1, "stream_format": 0}
      },
      header: getHeaders(),
    );
    var jsonObj = JsonUtil.decode(result);
    return jsonObj;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    var jsonObj = await getLiveStreamObj(detail: detail, qn: "1");
    var streamLineAddr = jsonObj['avp_info_res']['stream_line_addr'];
    var streamLineList = jsonObj['avp_info_res']['stream_line_list'];
    final channelStreamInfo = jsonObj['channel_stream_info'] as Map<String, dynamic>;
    final streams = channelStreamInfo['streams'] as List<dynamic>;
    List<LivePlayQuality> qualities = <LivePlayQuality>[];
    Map<String, LivePlayQuality> qualityMap = HashMap();
    for (var stream in streams) {
      final obj = stream as Map<String, dynamic>;
      if (!obj.containsKey('stream_key')) continue;

      final jsonStr = obj['json']?.toString() ?? '';
      if (jsonStr.isEmpty) continue;

      final info = json.decode(jsonStr) as Map<String, dynamic>;
      final gearInfo = info['gear_info'] as Map<String, dynamic>?;
      if (gearInfo == null) continue;

      final desc = gearInfo['name']?.toString() ?? '';
      final qn = gearInfo['gear']?.toString() ?? '';
      final rate = info['rate'] as int? ?? 0;

      if (qn.isNotEmpty && desc.isNotEmpty) {
        qualityMap.putIfAbsent(desc, () {
          return LivePlayQuality(
            quality: desc,
            sort: rate,
            data: qn,
            bitRate: rate,
          );
        });
      }
    }

    // 排序清晰度
    qualities = qualityMap.values.toList();
    qualities.sort((a, b) => b.sort.compareTo(a.sort));
    return Future.value(qualities);
  }

  @override
  Future<List<LivePlayQualityPlayUrlInfo>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    var qn = quality.data?.toString() ?? '';
    // return quality.playUrlList;
    // 获取直播数据
    final liveData = await getLiveStreamObj(detail: detail,qn: qn);

    // 解析直播地址
    final avpInfoRes = liveData['avp_info_res'] as Map<String, dynamic>;
    final streamLineAddr = avpInfoRes['stream_line_addr'] as Map<String, dynamic>;

    final name = streamLineAddr.keys.first;
    final cdnInfo = streamLineAddr[name]['cdn_info'] as Map<String, dynamic>;
    final url = cdnInfo['url'] ?? "";

    quality.playUrlList.add(LivePlayQualityPlayUrlInfo(playUrl: url, info: ""));
    return quality.playUrlList;
  }

  @override
  Future<LiveCategoryResult> getRecommendRooms({int page = 1, required String nick}) async {
    var pageSize = 60;
    Map<String, dynamic> queryParameters = {
      "page": page,
      "pageSize": pageSize,
      "biz": "other",
      "subBiz": "idx",
      "moduleId": "-1",
    };
    var result = await HttpClient.instance.getJson(
      "https://www.yy.com/more/page.action",
      queryParameters: queryParameters,
      header: getHeaders(),
    );
    result = JsonUtil.decode(result);
    var items = <LiveRoom>[];
    for (var item in result["data"]["data"]) {
      var roomItem = LiveRoom(
        roomId: item["sid"]?.toString() ?? '',
        title: item['desc'] ?? '',
        cover: validImgUrl(item['thumb2'] ?? ''),
        nick: item["name"].toString(),
        userId: item["uid"].toString(),
        watching: item["users"].toString(),
        avatar: validImgUrl(item["avatar"]),
        area: await getAreaNameByBiz(item["biz"] ?? ""),
        liveStatus: LiveStatus.live,
        status: true,
        platform: id,
      );
      items.add(roomItem);
    }
    var hasMore = items.length >= pageSize;
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  var bizAreaNameMap = <String, String>{};

  Future<Map<String, String>> getBizAreaNameMap() async {
    if (bizAreaNameMap.isEmpty) {
      var find = Get.find<AreasListController>(tag: id);
      List<LiveCategory> data = await find.getData(1, 100);
      for (var liveCategory in data) {
        for (var liveArea in liveCategory.children) {
          var shortName = liveArea.shortName ?? "{}";
          var areaName = liveArea.areaName ?? "";
          var decode = json.decode(shortName);
          var curBiz = decode["biz"] ?? "";
          if (curBiz.isNotEmpty) {
            bizAreaNameMap[curBiz] = areaName;
          }
        }
      }
    }
    return bizAreaNameMap;
  }

  Future<String> getAreaNameByBiz(String biz) async {
    var bizAreaNameMap = await getBizAreaNameMap();
    String areaName = bizAreaNameMap[biz] ?? "";
    return areaName;
  }

  @override
  Future<LiveRoom> getRoomDetail({required LiveRoom detail}) async {
    var roomId = detail.roomId ?? "";
    var userId = detail.userId ?? "";
    if (userId.isEmpty) {
      var url = "https://www.yy.com/$roomId";
      var resultText = await HttpClient.instance.getText(
        url,
        header: getHeaders(),
      );

      // var anchorName = RegExp(r'nick: "(.*?)",\n\\s+logo', multiLine: true).firstMatch(resultText)?.group(1) ?? "";
      // var cid = RegExp(r'sid : "(.*?)",\n\\s+ssid', multiLine: true).firstMatch(resultText)?.group(1) ?? "";
      var userId = RegExp(r'sid : "(.*?)",\n\\s+ssid', multiLine: true).firstMatch(resultText)?.group(1) ?? "";
      detail.userId = userId;
    }

    var url = "https://www.yy.com/api/liveInfoDetail/$roomId/$roomId/$userId";
    var newResultText = await HttpClient.instance.getJson(
      url,
      header: getHeaders(),
    );
    try {
      var resultJson = JsonUtil.decode(newResultText);
      if (resultJson["resultCode"] != 0) {
        // 离线状态
        return getLiveRoomWithError(detail);
      }
      var item = resultJson["data"];
      var roomItem = LiveRoom(
        roomId: item["sid"]?.toString() ?? '',
        title: item['desc'] ?? '',
        cover: validImgUrl(item['thumb2'] ?? ''),
        nick: item["name"].toString(),
        userId: item["uid"].toString(),
        watching: item["users"].toString(),
        avatar: validImgUrl(item["avatar"]),
        area: await getAreaNameByBiz(item["biz"] ?? ''),
        liveStatus: LiveStatus.live,
        status: true,
        platform: id,
      );
      return roomItem;
    } catch (e) {
      CoreLog.error(e);
      return getLiveRoomWithError(detail);
    }
  }

  @override
  Future<LiveSearchRoomResult> searchRooms(String keyword, {int page = 1}) async {
    var pageSize = 60;
    var result = await HttpClient.instance.getJson(
      "https://www.yy.com/apiSearch/doSearch.json",
      queryParameters: {
        "q": keyword,
        "t": "120",
        "n": page,
      },
      header: getHeaders(),
    );
    result = JsonUtil.decode(result);
    var items = <LiveRoom>[];
    for (var item in result["data"]["searchResult"]["response"]["120"]["docs"]) {
      var roomItem = LiveRoom(
        roomId: item["sid"]?.toString() ?? '',
        title: item['channelName'] ?? '',
        cover: validImgUrl(item['posterurl'] ?? ''),
        nick: item["name"].toString(),
        userId: item["uid"].toString(),
        watching: item["users"].toString(),
        avatar: validImgUrl(item["headurl"]),
        area: await getAreaNameByBiz(item["biz"] ?? ""),
        liveStatus: LiveStatus.live,
        status: true,
        platform: id,
      );
      items.add(roomItem);
    }
    var hasMore = items.length >= pageSize;
    return LiveSearchRoomResult(hasMore: hasMore, items: items);
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
