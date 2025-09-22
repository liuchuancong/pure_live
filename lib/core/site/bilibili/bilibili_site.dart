import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/common/convert_helper.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/site/bilibili/bilibili_danmaku.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/model/live_anchor_item.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/model/live_category_result.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/model/live_play_quality_play_url_info.dart';
import 'package:pure_live/model/live_search_result.dart';

import 'bilibili_site_mixin.dart';

class BiliBiliSite extends LiveSite with BilibiliSiteMixin {
  @override
  String get id => "bilibili";

  @override
  String get name => "哔哩哔哩直播";
  String cookie = "";
  int userId = 0;

  @override
  LiveDanmaku getDanmaku() => BiliBiliDanmaku();

  static const String kDefaultUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 Edg/126.0.0.0";
  static const String kDefaultReferer = "https://live.bilibili.com/";

  String buvid3 = "";
  String buvid4 = "";

  Future<Map<String, String>> getHeader() async {
    if (buvid3.isEmpty) {
      var buvidInfo = await getBuvid();
      buvid3 = buvidInfo["b_3"] ?? "";
      buvid4 = buvidInfo["b_4"] ?? "";
    }
    return cookie.isEmpty
        ? {
            "user-agent": kDefaultUserAgent,
            "referer": kDefaultReferer,
            "cookie": 'buvid3=$buvid3;buvid4=$buvid4;',
          }
        : {
            "cookie": cookie.contains("buvid3") ? cookie : "$cookie;buvid3=$buvid3;buvid4=$buvid4;",
            "user-agent": kDefaultUserAgent,
            "referer": kDefaultReferer,
          };
  }

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    List<LiveCategory> categories = [];
    var result = await HttpClient.instance.getJson(
      "https://api.live.bilibili.com/room/v1/Area/getList",
      queryParameters: {
        "need_entrance": 1,
        "parent_id": 0,
      },
      header: await getHeader(),
    );
    for (var item in result["data"]) {
      List<LiveArea> subs = [];
      for (var subItem in item["list"]) {
        var subCategory = LiveArea(
          areaId: subItem["id"].toString(),
          areaName: asT<String?>(subItem["name"]) ?? "",
          areaType: asT<String?>(subItem["parent_id"]) ?? "",
          typeName: asT<String?>(subItem["parent_name"]) ?? "",
          areaPic: "${asT<String?>(subItem["pic"]) ?? ""}@100w.png",
          platform: Sites.bilibiliSite,
        );
        subs.add(subCategory);
      }
      var category = LiveCategory(children: subs, id: item["id"].toString(), name: asT<String?>(item["name"]) ?? "");
      categories.add(category);
    }
    return categories;
  }

  @override
  Future<LiveCategoryResult> getCategoryRooms(LiveArea category, {int page = 1}) async {
    const baseUrl = "https://api.live.bilibili.com/xlive/web-interface/v1/second/getList";
    var url = "$baseUrl?platform=web&parent_area_id=${category.areaType}&area_id=${category.areaId}&sort_type=&page=$page";
    var queryParams = await getWbiSign(url);
    var result = await HttpClient.instance.getJson(
      baseUrl,
      queryParameters: queryParams,
      header: await getHeader(),
    );

    var queryParams = await getWbiSign(url);
    var result = await HttpClient.instance.getJson(baseUrl, queryParameters: queryParams, header: await getHeader());
    developer.log(result.toString(), name: "result");
    var hasMore = result["data"]["has_more"] == 1;
    var items = <LiveRoom>[];
    for (var item in result["data"]["list"]) {
      var roomItem = LiveRoom(
          roomId: item["roomid"].toString(),
          userId: item["uid"].toString(),
          title: item["title"].toString(),
          cover: "${item["cover"]}@400w.jpg",
          nick: item["uname"].toString(),
          avatar: item["face"].toString(),
          watching: item["online"].toString(),
          liveStatus: LiveStatus.live,
          area: item["area_name"].toString(),
          status: true,
          platform: Sites.bilibiliSite);
      items.add(roomItem);
    }
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    List<LivePlayQuality> qualities = [];
    var result = await HttpClient.instance.getJson(
      "https://api.live.bilibili.com/xlive/web-room/v2/index/getRoomPlayInfo",
      queryParameters: {
        "room_id": detail.roomId,
        "protocol": "0,1",
        "format": "0,1,2",
        "codec": "0,1",
        "platform": "html5",
        "dolby": "5",
      },
      header: await getHeader(),
    );
    var qualitiesMap = <int, String>{};
    for (var item in result["data"]["playurl_info"]["playurl"]["g_qn_desc"]) {
      qualitiesMap[int.tryParse(item["qn"].toString()) ?? 0] = item["desc"].toString();
    }
    for (var item in result["data"]["playurl_info"]["playurl"]["stream"][0]["format"][0]["codec"][0]["accept_qn"]) {
      int bitRate = 0;
      switch (item) {
        /// 流畅
        case 80:
          bitRate = 500;
          break;

        /// 高清
        case 150:
          bitRate = 1000;
          break;

        /// 超清
        case 250:
          bitRate = 2000;
          break;

        /// 蓝光
        case 400:
          bitRate = 4000;
          break;

        /// 原画
        case 10000:
          bitRate = 10000;
          break;

        /// 4K
        case 20000:
          bitRate = 20000;
          break;

        /// 杜比
        case 30000:
          bitRate = 30000;
          break;
        default:
          bitRate = item;
          break;
      }
      var qualityItem = LivePlayQuality(
        quality: qualitiesMap[item] ?? "未知清晰度",
        data: item,
        bitRate: bitRate,
      );
      qualities.add(qualityItem);
    }
    return qualities;
  }

  @override
  Future<List<LivePlayQualityPlayUrlInfo>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    List<LivePlayQualityPlayUrlInfo> urls = [];
    var result = await HttpClient.instance.getJson(
      "https://api.live.bilibili.com/xlive/web-room/v2/index/getRoomPlayInfo",
      queryParameters: {
        "room_id": detail.roomId,
        "protocol": "0,1,",
        "format": "0,1,2",
        "codec": "0,1,2,3",
        "platform": "html5",
        "dolby": "5",
        "qn": quality.data,
      },
      header: await getHeader(),
    );

    CoreLog.d("result ${jsonEncode(result)}");
    var streamList = result["data"]["playurl_info"]["playurl"]["stream"];
    // CoreLog.d("streamList ${jsonEncode(result["data"]["playurl_info"])}");
    for (var streamItem in streamList) {
      var formatList = streamItem["format"];
      for (var formatItem in formatList) {
        var formatName = formatItem["format_name"];
        var codecList = formatItem["codec"];
        // if (formatName != 'flv') {
        for (var codecItem in codecList) {
          var urlList = codecItem["url_info"];
          var baseUrl = codecItem["base_url"].toString();
          var codecName = codecItem["codec_name"].toString();
          for (var urlItem in urlList) {
            urls.add(LivePlayQualityPlayUrlInfo(playUrl: "${urlItem["host"]}$baseUrl${urlItem["extra"]}", info: "($formatName-$codecName)"));
          }
        }
        // }
      }
    }
    // 对链接进行排序，包含mcdn的在后
    urls.sort((a, b) {
      if (a.playUrl.contains("mcdn")) {
        return 1;
      } else {
        return -1;
      }
    });
    return urls;
  }

  @override
  Future<LiveCategoryResult> getRecommendRooms({int page = 1, required String nick}) async {
    const baseUrl = "https://api.live.bilibili.com/xlive/web-interface/v1/second/getListByArea";
    var url = "$baseUrl?platform=web&sort=online&page_size=30&page=$page";
    var queryParams = await getWbiSign(url);
    var result = await HttpClient.instance.getJson(
      baseUrl,
      queryParameters: queryParams,
      header: await getHeader(),
    );

    var hasMore = (result["data"]["list"] as List).isNotEmpty;
    var items = <LiveRoom>[];
    for (var item in result["data"]["list"]) {
      var roomItem = LiveRoom(
        roomId: item["roomid"].toString(),
        userId: item["uid"].toString(),
        title: item["title"].toString(),
        cover: "${item["cover"]}@400w.jpg",
        area: item["area_name"].toString(),
        nick: item["uname"].toString(),
        avatar: item["face"].toString(),
        watching: item["online"].toString(),
        liveStatus: LiveStatus.live,
        platform: Sites.bilibiliSite,
      );
      items.add(roomItem);
    }
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  Future<Map<String, dynamic>> getRoomInfo({required String roomId}) async {
    var url = "https://api.live.bilibili.com/xlive/web-room/v1/index/getInfoByRoom?room_id=$roomId";
    var queryParams = await getWbiSign(url);
    var result = await HttpClient.instance.getJson(
      "https://api.live.bilibili.com/xlive/web-room/v1/index/getInfoByRoom",
      queryParameters: queryParams,
      header: await getHeader(),
    );
    return result["data"];
  }

  static String kImgKey = '';
  static String kSubKey = '';
  static const List<int> mixinKeyEncTab = [
    46,
    47,
    18,
    2,
    53,
    8,
    23,
    32,
    15,
    50,
    10,
    31,
    58,
    3,
    45,
    35,
    27,
    43,
    5,
    49,
    33,
    9,
    42,
    19,
    29,
    28,
    14,
    39,
    12,
    38,
    41,
    13,
    37,
    48,
    7,
    16,
    24,
    55,
    40,
    61,
    26,
    17,
    0,
    1,
    60,
    51,
    30,
    4,
    22,
    25,
    54,
    21,
    56,
    59,
    6,
    63,
    57,
    62,
    11,
    36,
    20,
    34,
    44,
    52,
  ];

  Future<(String, String)> getWbiKeys() async {
    if (kImgKey.isNotEmpty && kSubKey.isNotEmpty) {
      return (kImgKey, kSubKey);
    }
    // 获取最新的 img_key 和 sub_key
    var resp = await HttpClient.instance.getJson(
      'https://api.bilibili.com/x/web-interface/nav',
      header: await getHeader(),
    );

    var imgUrl = resp["data"]["wbi_img"]["img_url"].toString();
    var subUrl = resp["data"]["wbi_img"]["sub_url"].toString();
    var imgKey = imgUrl.substring(imgUrl.lastIndexOf('/') + 1).split('.').first;
    var subKey = subUrl.substring(subUrl.lastIndexOf('/') + 1).split('.').first;

    kImgKey = imgKey;
    kSubKey = subKey;

    return (imgKey, subKey);
  }

  String getMixinKey(String origin) {
    // 对 imgKey 和 subKey 进行字符顺序打乱编码
    return mixinKeyEncTab.fold("", (s, i) => s + origin[i]).substring(0, 32);
  }

  Future<Map<String, String>> getWbiSign(String url) async {
    var (imgKey, subKey) = await getWbiKeys();

    // 为请求参数进行 wbi 签名
    var mixinKey = getMixinKey(imgKey + subKey);
    var currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    var queryParams = Map<String, String>.from(Uri.parse(url).queryParameters);

    queryParams["wts"] = currentTime.toString(); // 添加 wts 字段

    //按照 key 重排参数
    Map<String, String> map = {};
    var sortedKeys = queryParams.keys.toList()..sort();
    for (var key in sortedKeys) {
      var value = queryParams[key]!;
      // 过滤 value 中的 "!'()*" 字符
      map[key] = value.toString().split('').where((c) => "!'()*".contains(c) == false).join('');
    }

    var query = map.keys.map((key) => "$key=${Uri.encodeQueryComponent(map[key]!)}").join("&");
    var wbiSign = md5.convert(utf8.encode("$query$mixinKey")).toString();
    queryParams["w_rid"] = wbiSign;
    return queryParams;
  }

  @override
  Future<LiveRoom> getRoomDetail({required LiveRoom detail}) async {
    var roomId = detail.roomId ?? "";
    try {
      var roomInfo = await getRoomInfo(roomId: roomId);
      var realRoomId = roomInfo["room_info"]["room_id"].toString();

      const danmuInfoBaseUrl = "https://api.live.bilibili.com/xlive/web-room/v1/index/getDanmuInfo";
      var danmuInfoUrl = "$danmuInfoBaseUrl?id=$realRoomId";
      var queryParams = await getWbiSign(danmuInfoUrl);
      var roomDanmakuResult = await HttpClient.instance.getJson(
        danmuInfoBaseUrl,
        queryParameters: queryParams,
        header: await getHeader(),
      );

      var buvid = buvid3;
      List<String> serverHosts = (roomDanmakuResult["data"]["host_list"] as List).map<String>((e) => e["host"].toString()).toList();
      return LiveRoom(
        roomId: roomId,
        title: roomInfo["room_info"]["title"].toString(),
        cover: roomInfo["room_info"]["cover"].toString(),
        userId: roomInfo["room_info"]["uid"].toString(),
        nick: roomInfo["anchor_info"]["base_info"]["uname"].toString(),
        avatar: "${roomInfo["anchor_info"]["base_info"]["face"]}@100w.jpg",
        watching: roomInfo["room_info"]["online"].toString(),
        area: roomInfo['room_info']?['area_name'] ?? '',
        status: (asT<int?>(roomInfo["room_info"]["live_status"]) ?? 0) != 0,
        liveStatus: (asT<int?>(roomInfo["room_info"]["live_status"]) ?? 0) == 1
            ? LiveStatus.live
            : (asT<int?>(roomInfo["room_info"]["live_status"]) ?? 0) == 2
                ? LiveStatus.replay
                : LiveStatus.offline,
        link: "https://live.bilibili.com/$roomId",
        introduction: roomInfo["room_info"]["description"].toString(),
        notice: "",
        platform: Sites.bilibiliSite,
        danmakuData: BiliBiliDanmakuArgs(
          roomId: int.tryParse(realRoomId) ?? 0,
          uid: userId,
          token: roomDanmakuResult["data"]["token"].toString(),
          serverHost: serverHosts.isNotEmpty ? serverHosts.first : "broadcastlv.chat.bilibili.com",
          buvid: buvid3,
          cookie: cookie,
        ),
      );
    } catch (e) {
      CoreLog.error(e);
      return getLiveRoomWithError(detail);
    }
  }

  @override
  Future<LiveSearchRoomResult> searchRooms(String keyword, {int page = 1}) async {
    var result = await HttpClient.instance.getJson(
      "https://api.bilibili.com/x/web-interface/search/type?context=&search_type=live&cover_type=user_cover",
      queryParameters: {"order": "", "keyword": keyword, "category_id": "", "__refresh__": "", "_extra": "", "highlight": 0, "single_column": 0, "page": page},
      header: await getHeader(),
    );

    var items = <LiveRoom>[];
    var queryList = result["data"]["result"]["live_room"] ?? [];
    for (var item in queryList ?? []) {
      var title = item["title"].toString();
      //移除title中的<em></em>标签
      title = title.replaceAll(RegExp(r"<.*?em.*?>"), "");
      var roomItem = LiveRoom(
        roomId: item["roomid"].toString(),
        userId: item["uid"].toString(),
        title: title,
        cover: "https:${item["cover"]}@400w.jpg",
        nick: item["uname"].toString(),
        watching: item["online"].toString(),
        liveStatus: (asT<int?>(item["live_status"]) ?? 0) == 1 ? LiveStatus.live : LiveStatus.offline,
        area: item["cate_name"].toString(),
        status: (asT<int?>(item["live_status"]) ?? 0) == 1,
        avatar: "https:${item["uface"]}@400w.jpg",
        platform: Sites.bilibiliSite,
      );
      items.add(roomItem);
    }
    return LiveSearchRoomResult(hasMore: queryList.length > 0, items: items);
  }

  @override
  Future<LiveSearchAnchorResult> searchAnchors(String keyword, {int page = 1}) async {
    var result = await HttpClient.instance.getJson(
      "https://api.bilibili.com/x/web-interface/search/type?context=&search_type=live_user&cover_type=user_cover",
      queryParameters: {"order": "", "keyword": keyword, "category_id": "", "__refresh__": "", "_extra": "", "highlight": 0, "single_column": 0, "page": page},
      header: await getHeader(),
    );

    var items = <LiveAnchorItem>[];
    for (var item in result["data"]["result"] ?? []) {
      var uname = item["uname"].toString();
      //移除title中的<em></em>标签
      uname = uname.replaceAll(RegExp(r"<.*?em.*?>"), "");
      var anchorItem = LiveAnchorItem(
        roomId: item["roomid"].toString(),
        avatar: "https:${item["uface"]}@400w.jpg",
        userName: uname,
        liveStatus: item["is_live"],
      );
      items.add(anchorItem);
    }
    return LiveSearchAnchorResult(hasMore: items.length >= 40, items: items);
  }

  @override
  Future<bool> getLiveStatus({required LiveRoom detail}) async {
    var roomId = detail.roomId ?? "";
    var result = await HttpClient.instance.getJson(
      "https://api.live.bilibili.com/room/v1/Room/get_info",
      queryParameters: {
        "room_id": roomId,
      },
      header: await getHeader(),
    );
    return (asT<int?>(result["data"]["live_status"]) ?? 0) == 1;
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({required String roomId}) async {
    var result = await HttpClient.instance.getJson(
      "https://api.live.bilibili.com/av/v1/SuperChat/getMessageList",
      queryParameters: {
        "room_id": roomId,
      },
      header: await getHeader(),
    );
    List<LiveSuperChatMessage> ls = [];
    for (var item in result["data"]?["list"] ?? []) {
      var message = LiveSuperChatMessage(
        backgroundBottomColor: item["background_bottom_color"].toString(),
        backgroundColor: item["background_color"].toString(),
        endTime: DateTime.fromMillisecondsSinceEpoch(item["end_time"] * 1000),
        face: "${item["user_info"]["face"]}@200w.jpg",
        message: item["message"].toString(),
        price: item["price"],
        startTime: DateTime.fromMillisecondsSinceEpoch(item["start_time"] * 1000),
        userName: item["user_info"]["uname"].toString(),
      );
      ls.add(message);
    }
    return ls;
  }

  Future<Map> getBuvid() async {
    try {
      if (cookie.contains("buvid3")) {
        return {
          "b_3": RegExp(r"buvid3=(.*?);").firstMatch(cookie)?.group(1) ?? "",
          "b_4": RegExp(r"buvid4=(.*?);").firstMatch(cookie)?.group(1) ?? "",
        };
      }

      var result = await HttpClient.instance.getJson(
        "https://api.bilibili.com/x/frontend/finger/spi",
        queryParameters: {},
        header: {
          "user-agent": kDefaultUserAgent,
          "referer": kDefaultReferer,
          "cookie": cookie,
        },
      );
      return result["data"];
    } catch (e) {
      return {
        "b_3": "",
        "b_4": "",
      };
    }
  }

  @override
  bool isSupportBatchUpdateLiveStatus() {
    return true;
  }

  @override
  Future<List<LiveRoom>> getLiveRoomDetailList({required List<LiveRoom> list}) async {
    if (list.isEmpty) {
      return List.empty();
    }
    var urlPart = list.map((e) => (e.userId!)).toList();
    var result = await HttpClient.instance.postJson(
      "https://api.live.bilibili.com/room/v1/Room/get_status_info_by_uids",
      data: {"uids": urlPart},
      header: await getHeader(),
    );

    var items = <LiveRoom>[];
    Map data = result["data"] ?? {};
    var values = data.values;
    for (var roomInfo in values) {
      var uname = roomInfo["uname"].toString();
      //移除title中的<em></em>标签
      uname = uname.replaceAll(RegExp(r"<.*?em.*?>"), "");
      var cover = roomInfo["keyframe"].toString();
      if (cover == "") {
        cover = roomInfo["cover_from_user"].toString();
      }
      if (cover == "") {
        cover = roomInfo["cover"].toString();
      }
      if (cover == "") {
        cover = roomInfo["background"].toString();
      }
      var liveStatus = (asT<int?>(roomInfo["live_status"]) ?? 0);
      var flag = LiveStatus.offline;
      if (liveStatus == 1) {
        flag = LiveStatus.live;
      } else if (liveStatus == 2) {
        flag = LiveStatus.replay;
      }
      var room = LiveRoom(
        roomId: roomInfo["room_id"].toString(),
        title: roomInfo["title"].toString(),
        cover: cover,
        userId: roomInfo["uid"].toString(),
        nick: roomInfo["uname"].toString(),
        avatar: "${roomInfo["face"]}@100w.jpg",
        watching: roomInfo["online"].toString(),
        area: roomInfo['area_name'] ?? '',
        status: liveStatus != 0,
        liveStatus: flag,
        link: "https://live.bilibili.com/${roomInfo["room_id"].toString()}",
        // introduction: ["description"].toString(),
        notice: "",
        platform: Sites.bilibiliSite,
        // danmakuData: ,
      );
      items.add(room);
    }
    return items;
  }
}
