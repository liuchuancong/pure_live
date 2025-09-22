import 'dart:collection';
import 'dart:convert';

import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/model/live_category_result.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/model/live_play_quality_play_url_info.dart';
import 'package:pure_live/model/live_search_result.dart';

import '../../../modules/util/json_util.dart';
import 'soop_danmaku.dart';
import 'soop_site_mixin.dart';

class SoopSite extends LiveSite with SoopSiteMixin {
  @override
  String get id => "soop";

  @override
  String get name => "SOOP直播";

  String cookie = '';
  Map<String, String> cookieObj = {};
  List<String> imageExtensions = ['svgz', 'pjp', 'png', 'ico', 'avif', 'tiff', 'tif', 'jfif', 'svg', 'xbm', 'pjpeg', 'webp', 'jpg', 'jpeg', 'bmp', 'gif'];

  @override
  LiveDanmaku getDanmaku() => SoopDanmaku();

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    List<LiveCategory> categories = [
      LiveCategory(id: "1", name: "热门", children: []),
    ];

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
    var result = JsonUtil.decode(resultText);

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
      "Cookie": SettingsService.instance.siteCookies[id] ?? "",
    };
  }

  @override
  Future<LiveCategoryResult> getCategoryRooms(LiveArea category, {int page = 1}) async {
    var pageSize = 60;
    var result = await HttpClient.instance.getJson(
      "https://sch.sooplive.co.kr/api.php",
      queryParameters: {"m": "categoryContentsList", "szType": "live", "nPageNo": page, "nListCnt": pageSize, "szPlatform": "pc", "szOrder": "view_cnt_desc", "szCateNo": category.areaId},
      header: getHeaders(),
    );
    result = JsonUtil.decode(result);
    var items = <LiveRoom>[];
    for (var item in result["data"]["list"]) {
      var roomItem = LiveRoom(
        roomId: item["user_id"] ?? '',
        title: item['broad_title'] ?? '',
        cover: validImgUrl(item['thumbnail'] ?? ''),
        nick: item["user_nick"].toString(),
        watching: item["view_cnt"].toString(),
        avatar: validImgUrl(item["user_profile_img"]),
        area: category.areaName,
        liveStatus: LiveStatus.live,
        status: true,
        platform: Sites.soopSite,
      );
      items.add(roomItem);
    }
    var hasMore = items.length >= pageSize;
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) {
    List<LivePlayQuality> qualities = <LivePlayQuality>[];
    Map<String, LivePlayQuality> qualityMap = HashMap();
    CoreLog.d("detail.data: ${jsonEncode(detail.data)}");
    var data = (detail.data as Map);
    for (var quality in data["viewpreset"]) {
      var key = quality["name"];
      if (key == "auto") {
        continue;
      }
      qualityMap.putIfAbsent(key, () {
        return LivePlayQuality(
          quality: quality["name"],
          sort: quality["bps"],
          data: <String>[],
          bitRate: quality["bps"] ?? 0,
        );
      });
    }
    qualities = qualityMap.values.toList();
    qualities.sort((a, b) => b.sort.compareTo(a.sort));
    return Future.value(qualities);
  }

  @override
  Future<List<LivePlayQualityPlayUrlInfo>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    var cdnUrl = getCdnUrl(bno: detail.userId ?? "", quality: quality.quality);
    var streamAid = getStreamAid(roomId: detail.roomId ?? "", quality: quality.quality);
    var m3u8Url = '${await cdnUrl}?aid=${await streamAid}';
    quality.playUrlList.add(LivePlayQualityPlayUrlInfo(playUrl: m3u8Url, info: ""));
    return quality.playUrlList;
  }

  @override
  Future<LiveCategoryResult> getRecommendRooms({int page = 1, required String nick}) async {
    var pageSize = 60;
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
    result = JsonUtil.decode(result);
    for (var item in result["broad"]) {
      var roomId = item["user_id"] ?? '';
      var roomItem = LiveRoom(
        roomId: roomId,
        title: item['broad_title'] ?? '',
        cover: validImgUrl(item['broad_thumb'] ?? ''),
        nick: item["user_nick"].toString(),
        watching: item["current_view_cnt"].toString(),
        avatar: getAvatarUrlByRoomId(roomId),
        area: item["category_name"],
        liveStatus: LiveStatus.live,
        status: true,
        platform: Sites.soopSite,
      );
      items.add(roomItem);
    }
    var hasMore = items.length >= pageSize;
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<LiveRoom> getRoomDetail({required LiveRoom detail}) async {
    var roomId = detail.roomId ?? "";
    var url = "http://api.m.sooplive.co.kr/broad/a/watch";
    var danmakuArgs = geDanmakuArgs(roomId: roomId);
    var resultText = await HttpClient.instance.postJson(
      url,
      formUrlEncoded: true,
      data: {
        'bj_id': roomId,
        'bid': roomId,
        'broad_no': '',
        'agent': 'web',
        'confirm_adult': 'true',
        'player_type': 'webm',
        'mode': 'live',
      },
      header: getHeaders(),
    );
    try {
      resultText = JsonUtil.decode(resultText);
      if (resultText['result'] != 1) {
        // 离线状态
        return getLiveRoomWithError(detail);
      }
      var jsonObj = resultText['data'];
      var bno = jsonObj["broad_no"].toString();
      var nick = jsonObj["user_nick"];
      //CoreLog.d(jsonEncode(jsonObj));

      var jsonObj2 = jsonObj["category_tags"];
      var area = "";
      if (jsonObj2 != null) {
        var sList = (jsonObj2 as List);
        if (sList.isNotEmpty) {
          area = sList[0];
        }
      }
      var millisecondsSinceEpoch2 = DateTime.now().millisecondsSinceEpoch;
      var cover = validImgUrl("${jsonObj['thumbnail']}?_t=$millisecondsSinceEpoch2");
      var avatar = validImgUrl("${jsonObj['profile_thumbnail']}");
      var data = {
        "hls_authentication_key": jsonObj["hls_authentication_key"],
        "broad_bps": jsonObj["broad_bps"],
        "viewpreset": jsonObj["viewpreset"],
      };
      var isLiving = true;
      CoreLog.d("$jsonObj");
      return LiveRoom(
        cover: cover,
        watching: jsonObj["view_cnt"].toString(),
        roomId: jsonObj["bj_id"].toString(),
        userId: bno,
        area: area,
        title: jsonObj["broad_title"].toString(),
        nick: nick,
        avatar: avatar,
        introduction: '',
        notice: '',
        status: isLiving,
        liveStatus: isLiving ? LiveStatus.live : LiveStatus.offline,
        platform: Sites.soopSite,
        link: jsonObj["share"]["url"],
        data: data,
        danmakuData: await danmakuArgs,
      );
    } catch (e) {
      CoreLog.error(e);
      return getLiveRoomWithError(detail);
    }
  }

  Future<String> getCdnUrl({required String bno, String quality = "master"}) async {
    var url = "http://livestream-manager.sooplive.co.kr/broad_stream_assign.html";
    var resultText = await HttpClient.instance.getJson(
      url,
      queryParameters: {
        'return_type': 'gcp_cdn',
        'use_cors': 'false',
        'cors_origin_url': 'play.sooplive.co.kr',
        'broad_key': '$bno-common-$quality-hls',
        'time': '8361.086329376785',
      },
      header: getHeaders(),
    );
    resultText = JsonUtil.decode(resultText);
    var viewUrl = resultText['view_url'];
    return viewUrl;
  }

  Future<String> getStreamAid({required String roomId, required String quality}) async {
    var url = "https://live.sooplive.co.kr/afreeca/player_live_api.php";
    var resultText = await HttpClient.instance.postJson(
      url,
      formUrlEncoded: true,
      queryParameters: {
        'bjid': roomId,
      },
      data: {
        "bid": roomId,
        "bno": "286770866",
        "type": "aid",
        "pwd": "",
        "player_type": "html5",
        "stream_type": "common",
        "quality": quality,
        "mode": "landing",
        "from_api": "0",
        "is_revive": "false"
      },
      header: getHeaders(),
    );
    resultText = JsonUtil.decode(resultText);
    var jsonObj = resultText['CHANNEL'];
    var aid = jsonObj["AID"] ?? "";
    return aid;
  }

  Future<DanmakuArgs?> geDanmakuArgs({required String roomId}) async {
    try {
      var url = "https://live.sooplive.co.kr/afreeca/player_live_api.php";
      var resultText = await HttpClient.instance.postJson(
        url,
        formUrlEncoded: true,
        queryParameters: {
          'bjid': roomId,
        },
        data: {"bid": roomId, "bno": "", "type": "live", "pwd": "", "player_type": "html5", "stream_type": "common", "quality": "HD", "mode": "landing", "from_api": "0", "is_revive": "false"},
        header: getHeaders(),
      );
      resultText = JsonUtil.decode(resultText);
      var jsonObj = resultText['CHANNEL'];
      var chatNo = jsonObj["CHATNO"];
      var chatDomain = jsonObj["CHDOMAIN"];
      var chpt = jsonObj["CHPT"];
      chpt = 9001;
      final wsUrl = 'wss://$chatDomain:$chpt/Websocket/$roomId';
      return DanmakuArgs(url: wsUrl, chatNo: chatNo);
    } catch (e) {
      CoreLog.w("$e");
      return null;
    }
  }

  @override
  Future<LiveSearchRoomResult> searchRooms(String keyword, {int page = 1}) async {
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
        "nListCnt": "40",
        "tab": "live",
        "location": "total_search",
        "isHashSearch": "0",
        "v": "2.0",
      },
      header: getHeaders(),
    );
    var result = JsonUtil.decode(resultText);
    var items = <LiveRoom>[];
    var queryList = result["REAL_BROAD"] ?? [];
    for (var item in queryList) {
      var cover = item["broad_img"].toString();
      var userId = item["user_id"].toString();
      var title = item["broad_title"]?.toString() ?? "";
      var area = item["standard_broad_cate_name"]?.toString() ?? "";

      var roomItem = LiveRoom(
        roomId: userId,
        title: title,
        cover: validImgUrl(cover),
        nick: item["user_nick"].toString(),
        area: area,
        status: true,
        liveStatus: LiveStatus.live,
        avatar: getAvatarUrlByRoomId(userId),
        watching: item["current_view_cnt"].toString(),
        platform: Sites.soopSite,
      );
      items.add(roomItem);
    }
    return LiveSearchRoomResult(hasMore: queryList.length > 0, items: items);
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
