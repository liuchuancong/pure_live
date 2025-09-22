import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:get/get.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/site/kuaishou/kuaishow_danmaku.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/model/live_category_result.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/model/live_play_quality_play_url_info.dart';
import 'package:pure_live/model/live_search_result.dart';
import 'package:pure_live/plugins/fake_useragent.dart';

import 'kuaishou_site_mixin.dart';

class KuaishowSite extends LiveSite with KuaishouSiteMixin {
  @override
  String get id => "kuaishou";

  @override
  String get name => "快手直播";

  String cookie = '';
  Map<String, String> cookieObj = {};
  List<String> imageExtensions = ['svgz', 'pjp', 'png', 'ico', 'avif', 'tiff', 'tif', 'jfif', 'svg', 'xbm', 'pjpeg', 'webp', 'jpg', 'jpeg', 'bmp', 'gif'];

  @override
  LiveDanmaku getDanmaku() => KuaishowDanmaku();

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    List<LiveCategory> categories = [
      LiveCategory(id: "1", name: "热门", children: []),
      LiveCategory(id: "2", name: "网游", children: []),
      LiveCategory(id: "3", name: "单机", children: []),
      LiveCategory(id: "4", name: "手游", children: []),
      LiveCategory(id: "5", name: "棋牌", children: []),
      LiveCategory(id: "6", name: "娱乐", children: []),
      LiveCategory(id: "7", name: "综合", children: []),
      LiveCategory(id: "8", name: "文化", children: []),
    ];

    List<Future> futures = [];
    for (var item in categories) {
      futures.add(Future(() async {
        var items = await getAllSubCategores(item, 1, 30, []);
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
    var result = await HttpClient.instance.getJson(
      "https://live.kuaishou.com/live_api/category/data",
      queryParameters: {"type": liveCategory.id, "page": page, "size": pageSize},
      header: headers,
    );

    List<LiveArea> subs = [];
    for (var item in result["data"]["list"] ?? []) {
      var subCategory = LiveArea(
        areaId: item["id"],
        areaName: item["name"],
        areaType: liveCategory.id,
        platform: Sites.kuaishouSite,
        areaPic: item["poster"],
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

  @override
  Future<LiveCategoryResult> getCategoryRooms(LiveArea category, {int page = 1}) async {
    var api = category.areaId!.length < 7 ? "https://live.kuaishou.com/live_api/gameboard/list" : "https://live.kuaishou.com/live_api/non-gameboard/list";
    var result = await HttpClient.instance.getJson(
      api,
      queryParameters: {"filterType": 0, "pageSize": 20, "gameId": category.areaId, "page": page},
      header: headers,
    );
    var items = <LiveRoom>[];
    for (var item in result["data"]["list"]) {
      var roomItem = LiveRoom(
        roomId: item["author"]["id"] ?? '',
        title: item['caption'] ?? '',
        cover: isImage(item['poster']) ? item['poster'].toString() : '${item['poster'].toString()}.jpg',
        nick: item["author"]["name"].toString(),
        watching: item["watchingCount"].toString(),
        avatar: item["author"]["avatar"],
        area: item["gameInfo"]["name"].toString(),
        liveStatus: LiveStatus.live,
        status: true,
        platform: Sites.kuaishouSite,
      );
      items.add(roomItem);
    }
    var hasMore = result["data"]["list"].length >= 20;
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) {
    List<LivePlayQuality> qualities = <LivePlayQuality>[];
    Map<String, LivePlayQuality> qualityMap = HashMap();
    CoreLog.d("detail.data: ${jsonEncode(detail.data)}");
    var data = (detail.data as Map);
    for (var codeKey in data.keys) {
      var obj = data[codeKey];
      var qualityList = obj["adaptationSet"]["representation"];
      for (var quality in qualityList) {
        var key = quality["name"];
        qualityMap.putIfAbsent(key, () {
          return LivePlayQuality(
            quality: quality["name"],
            sort: quality["level"],
            data: <String>[],
            bitRate: quality["bitrate"] ?? 0,
          );
        });

        var livePlayQuality = qualityMap[key]!;
        var playUrlList = livePlayQuality.data as List<String>;
        playUrlList.add(quality["url"]);
        livePlayQuality.playUrlList.add(LivePlayQualityPlayUrlInfo(playUrl: quality["url"], info: "($codeKey)"));
      }
    }
    qualities = qualityMap.values.toList();
    qualities.sort((a, b) => b.sort.compareTo(a.sort));
    return Future.value(qualities);
  }

  @override
  Future<List<LivePlayQualityPlayUrlInfo>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    return quality.playUrlList;
  }

  @override
  Future<LiveCategoryResult> getRecommendRooms({int page = 1, required String nick}) async {
    var resultText = await HttpClient.instance.getJson("https://live.kuaishou.com/live_api/hot/list",
        queryParameters: {
          'type': 'HOT',
          'filterType': 0,
          'page': page,
          'pageSize': 20,
          'cursor': '',
        },
        header: headers);

    var result = resultText['data']['list'] ?? [];
    var items = <LiveRoom>[];
    for (var item in result) {
      var titem = item;
      var author = titem["author"];
      var gameInfo = titem["gameInfo"];
      var roomItems = LiveRoom(
        cover: isImage(item['poster']) ? item['poster'].toString() : '${item['poster'].toString()}.jpg',
        watching: titem["watchingCount"].toString(),
        roomId: author["id"],
        area: gameInfo["name"],
        title: author["description"] != null ? author["description"].replaceAll("\n", " ") : '',
        nick: author["name"].toString(),
        avatar: author["avatar"].toString(),
        introduction: author["description"] != null ? author["description"].replaceAll("\n", " ") : '',
        notice: author["description"],
        status: true,
        liveStatus: LiveStatus.live,
        platform: Sites.kuaishouSite,
        data: titem["playUrls"],
      );
      items.add(roomItems);
    }
    var hasMore = items.length >= 20;
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  Future registerDid() async {
    var res = await HttpClient.instance.postJson('https://log-sdk.ksapisrv.com/rest/wd/common/log/collect/misc2?v=3.9.49&kpn=KS_GAME_LIVE_PC', header: headers, data: misc2dic(cookieObj['did'] ?? ""));
    return res;
  }

  Map<String, Object> misc2dic(String did) {
    var map = {
      'common': {
        'identity_package': {'device_id': did, 'global_id': ''},
        'app_package': {'language': 'zh-CN', 'platform': 10, 'container': 'WEB', 'product_name': 'KS_GAME_LIVE_PC'},
        'device_package': {'os_version': 'NT 6.1', 'model': 'Windows', 'ua': 'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.198 Safari/537.36'},
        'need_encrypt': 'false',
        'network_package': {'type': 3},
        'h5_extra_attr':
            '{"sdk_name":"webLogger","sdk_version":"3.9.49","sdk_bundle":"log.common.js","app_version_name":"","host_product":"","resolution":"1600x900","screen_with":1600,"screen_height":900,"device_pixel_ratio":1,"domain":"https://live.kuaishou.com"}',
        'global_attr': '{}'
      },
      'logs': [
        {
          'client_timestamp': DateTime.now().millisecondsSinceEpoch,
          'client_increment_id': math.Random().nextInt(8999) + 1000,
          'session_id': '1eb20f88-51ac-4ecf-8dc3-ace5aefcae4f',
          'time_zone': 'GMT+08:00',
          'event_package': {
            'task_event': {
              'type': 1,
              'status': 0,
              'operation_type': 1,
              'operation_direction': 0,
              'session_id': '1eb20f88-51ac-4ecf-8dc3-ace5aefcae4f',
              'url_package': {'page': 'GAME_DETAL_PAGE', 'identity': '5316c78e-f0b6-4be2-a076-c8f9d11ebc0a', 'page_type': 2, 'params': '{"game_id":1001,"game_name":"王者荣耀"}'},
              'element_package': {}
            }
          }
        }
      ]
    };
    return map;
  }

  // 获取pageId
  String getPageId() {
    var pageId = '';
    const charset = 'bjectSymhasOwnProp-0123456789ABCDEFGHIJKLMNQRTUVWXYZ_dfgiklquvxz';
    for (var i = 0; i < 16; i++) {
      pageId += charset[math.Random().nextInt(63)];
    }
    var currentTime = DateTime.now().millisecondsSinceEpoch;
    return pageId += '_$currentTime';
  }

  Future getCookie(String url) async {
    if (userCookie.isNotEmpty) {
      cookie = userCookie.value;
      var splits = cookie.split(";");
      for (var i = 0; i < splits.length; i++) {
        try {
          var vSplit = splits[i];
          var indexOf = vSplit.indexOf("=");
          var key = vSplit.substring(0, indexOf);
          var value = vSplit.substring(indexOf + 1);
          cookieObj[key.trim()] = value.trim();
        } catch (e) {
          CoreLog.error(e);
        }
      }
      return;
    }
    final dio = Dio();
    final cookieJar = CookieJar();
    dio.interceptors.add(CookieManager(cookieJar));
    await dio.get(url);
    List<Cookie> cookies = await cookieJar.loadForRequest(Uri.parse(url));
    cookie = '';
    for (var i = 0; i < cookies.length; i++) {
      if (i != cookies.length - 1) {
        cookie += "${cookies[i].name}=${cookies[i].value};";
      } else {
        cookie += "${cookies[i].name}=${cookies[i].value}";
      }
      cookieObj[cookies[i].name] = cookies[i].value;
    }
  }

  Future<Map?> getWebsocketInfo(Object roomId, String? liveStreamId) async {
    if (liveStreamId == null) {
      return null;
    }
    headers['cookie'] = cookie;
    // var url = "https://live.kuaishou.com/u/$roomId";
    var mHeaders = headers;
    mHeaders["Referer"] = "https://live.kuaishou.com/u/$roomId";
    mHeaders["Kww"] = cookieObj["kwfv1"];
    // CoreLog.d("getWebsocketInfo : $mHeaders");
    // CoreLog.d("getWebsocketInfo : $userCookie");
    // CoreLog.d("getWebsocketInfo : $cookie");
    // CoreLog.d("getWebsocketInfo : $cookieObj");
    var resultText = await HttpClient.instance.getText(
      "https://live.kuaishou.com/live_api/liveroom/websocketinfo",
      queryParameters: {
        "liveStreamId": liveStreamId,
      },
      header: mHeaders,
    );
    CoreLog.d("mHeaders: ${jsonEncode(mHeaders)}");
    return jsonDecode(resultText);
  }

  @override
  Future<LiveRoom> getRoomDetail({required LiveRoom detail}) async{
    return getRoomDetailByWeb(detail: detail);
  }
  Future<LiveRoom> getRoomDetailByWeb({required LiveRoom detail}) async {
    var roomId = detail.roomId ?? "";
    headers['cookie'] = cookie;
    var url = "https://live.kuaishou.com/u/$roomId";
    var mHeaders = headers;
    var fakeUseragent = FakeUserAgent.getRandomUserAgent();
    mHeaders['User-Agent'] = fakeUseragent['userAgent'];
    mHeaders['sec-ch-ua'] = 'Google Chrome;v=${fakeUseragent['v']}, Chromium;v=${fakeUseragent['v']}, Not=A?Brand;v=24';
    mHeaders['sec-ch-ua-platform'] = fakeUseragent['device'];
    mHeaders['sec-fetch-dest'] = 'document';
    mHeaders['sec-fetch-mode'] = 'navigate';
    mHeaders['sec-fetch-site'] = 'same-origin';
    mHeaders['sec-fetch-user'] = '?1';
    mHeaders['accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9';
    await getCookie(url);
    var kww = cookieObj["kwfv1"];
    if(kww == null || kww.isEmpty) {
      await registerDid();
    }
    headers['Kww'] = kww;
    mHeaders["Kww"] = kww;
    var resultText = await HttpClient.instance.getText(
      url,
      queryParameters: {},
      header: mHeaders,
    );
    try {
      var text = RegExp(r"window\.__INITIAL_STATE__=(.*?);", multiLine: false).firstMatch(resultText)?.group(1);
      var transferData = text!.replaceAll("undefined", "null");
      var jsonObj = jsonDecode(transferData);
      var liveStream = jsonObj["liveroom"]["playList"][0]["liveStream"];
      var author = jsonObj["liveroom"]["playList"][0]["author"];
      var gameInfo = jsonObj["liveroom"]["playList"][0]["gameInfo"];
      var liveStreamId = liveStream["id"];
      CoreLog.d(jsonEncode(jsonObj));
      KuaishowDanmakuArgs? tmpArgs = await () async {
        var expTag = liveStream["expTag"] ?? "";
        var defaultDanmakuArgs = KuaishowDanmakuArgs(
            url: "wss://live-ws-group4.kuaishou.com/websocket",
            token: "tcv4u8PpI34PDJQTe39jatCeZ0yRpsqECaReAkXttFeGkL7M66BIwQGpjiKrsWcv15cWPRAEjbNKkqh+ua/jWGbQqLrDDRYEYPbAvZX0JdMMCuBj4dnaYRaci0rSeWng7l2C+5y4lhLWp0QpHswvQkt5gZfydzCwGgyV+Zftey+F24NcyIejkftzWNcgGc4m3cKqW8d0C4xgdfjF+bXJlA==",
            liveStreamId: liveStreamId ?? "",
            expTag: liveStream["expTag"] ?? "");
        try {
          // var websocketInfo = jsonObj["liveroom"]["playList"][0]["websocketInfo"];
          var websocketInfo = await getWebsocketInfo(roomId, liveStreamId);
          CoreLog.d("websocketInfo: ${jsonEncode(websocketInfo)}");
          if (websocketInfo == null) return defaultDanmakuArgs;
          var websocketInfo2 = websocketInfo["webSocketAddresses"];
          if (websocketInfo2 == null) return defaultDanmakuArgs;
          var webSocketAddresses = websocketInfo["webSocketAddresses"][0];
          var webSocketToken = websocketInfo["token"];
          return KuaishowDanmakuArgs(url: webSocketAddresses, token: webSocketToken, liveStreamId: liveStreamId, expTag: expTag);
        } catch (e) {
          // log(e.toString());
          CoreLog.error(e);
        }
      //   {
      //     "data": {
      //   "result": 1,
      //   "token": "tcv4u8PpI34PDJQTe39jatCeZ0yRpsqECaReAkXttFeGkL7M66BIwQGpjiKrsWcv15cWPRAEjbNKkqh+ua/jWGbQqLrDDRYEYPbAvZX0JdMMCuBj4dnaYRaci0rSeWng7l2C+5y4lhLWp0QpHswvQkt5gZfydzCwGgyV+Zftey+F24NcyIejkftzWNcgGc4m3cKqW8d0C4xgdfjF+bXJlA==",
      //   "websocketUrls": [
      //   "wss://livejs-ws-group4.gifshow.com/websocket",
      //   "wss://live-ws-group4.kuaishou.com/websocket"
      //   ]
      // }
      // }
        return defaultDanmakuArgs;
      }();
      // CoreLog.d(jsonEncode(tmpArgs));
      // CoreLog.d("${jsonEncode(jsonObj)}");
      return LiveRoom(
        cover: liveStream['poster'] != null
            ? isImage(liveStream['poster'])
                ? liveStream['poster'].toString()
                : '${liveStream['poster'].toString()}.jpg'
            : "",
        watching: jsonObj["liveroom"]["playList"][0]["isLiving"] ? gameInfo["watchingCount"].toString() : '0',
        roomId: author["id"],
        area: gameInfo["name"] ?? '',
        title: author["description"] != null ? author["description"].replaceAll("\n", " ") : '',
        nick: author["name"].toString(),
        avatar: author["avatar"].toString(),
        introduction: author["description"].toString(),
        notice: author["description"].toString(),
        status: jsonObj["liveroom"]["playList"][0]["isLiving"],
        liveStatus: jsonObj["liveroom"]["playList"][0]["isLiving"] ? LiveStatus.live : LiveStatus.offline,
        platform: Sites.kuaishouSite,
        link: liveStreamId,
        data: liveStream["playUrls"],
        danmakuData: tmpArgs,
      );
    } catch (e) {
      CoreLog.error(e);
      return getLiveRoomWithError(detail);
    }
  }

  Future<LiveRoom> getRoomDetailByMobile({required LiveRoom detail}) async {
    var roomId = detail.roomId ?? "";
    headers['cookie'] = cookie;
    var url = "https://live.kuaishou.com/u/$roomId";
    var timestamp = DateTime.timestamp().millisecondsSinceEpoch;
    url = "https://livev.m.chenzhongtech.com/fw/live/$roomId?cc=share_wxms&followRefer=151&shareMethod=CARD&kpn=GAME_ZONE&subBiz=LIVE_STEARM_OUTSIDE&shareId=18525828579338&shareToken=X-9BsYHSLmysC15S&shareMode=APP&efid=0&originShareId=18525828579338&shareObjectId=Fbb0tbOTWfQ&shareUrlOpened=0&timestamp=$timestamp";
    var mHeaders = headers;
    var fakeUseragent = FakeUserAgent.getRandomUserAgent();
    mHeaders['User-Agent'] = "Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1 Edg/118.0.0.0";
    mHeaders['sec-ch-ua'] = 'Google Chrome;v=107, Chromium;v=107, Not=A?Brand;v=24';
    mHeaders['sec-ch-ua-platform'] = fakeUseragent['device'];
    mHeaders['sec-fetch-dest'] = 'document';
    mHeaders['sec-fetch-mode'] = 'navigate';
    mHeaders['sec-fetch-site'] = 'same-origin';
    mHeaders['sec-fetch-user'] = '?1';
    mHeaders['accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9';
    mHeaders['cookie'] = cookie + "livePageServiceNameNew=usergrowth-kfx-service; kuaishou.live.bfb1s=ac5f27b3b62895859c4c1622f49856a4; ";
    await getCookie(url);
    var kww = cookieObj["kwfv1"];
    if(kww == null || kww.isEmpty) {
      await registerDid();
    }
    headers['Kww'] = kww;
    mHeaders["Kww"] = kww;
    var resultText = await HttpClient.instance.getText(
      url,
      queryParameters: {},
      header: mHeaders,
    );
    try {
      CoreLog.d("resultText: $resultText");
      var text = RegExp(r"window\.__INITIAL_STATE__=(.*?);?\s*</script>", multiLine: false).firstMatch(resultText)?.group(1);
      var transferData = text!.replaceAll("undefined", "null");
      var jsonObj = jsonDecode(transferData) as Map;
      var dataObj = {};
      for(var key in jsonObj.keys) {
        var jsonObj2 = jsonObj[key];
        if( jsonObj2["webSocketAddresses"] != null) {
          dataObj = jsonObj2;
          break;
        }
      }

      jsonObj = dataObj;
      var token = jsonObj["token"];

      var liveStream = jsonObj["liveStream"];
      var user = liveStream["user"];
      var author = user["user_name"];
      var gameInfo = liveStream["gameInfo"];
      var liveStreamId = liveStream["liveStreamId"];
      CoreLog.d(jsonEncode(jsonObj));
      KuaishowDanmakuArgs? tmpArgs = await () async {
        try {
          var expTag = liveStream["exp_tag"];
          var websocketInfo = jsonObj["webSocketAddresses"];
          CoreLog.d("websocketInfo: ${jsonEncode(websocketInfo)}");
          if (websocketInfo == null) return null;
          var webSocketAddresses = websocketInfo[0];
          var webSocketToken = token;
          return KuaishowDanmakuArgs(url: webSocketAddresses, token: webSocketToken, liveStreamId: liveStreamId, expTag: expTag);
        } catch (e) {
          // log(e.toString());
          CoreLog.error(e);
        }
        return null;
      }();
      // CoreLog.d(jsonEncode(tmpArgs));
      // CoreLog.d("${jsonEncode(jsonObj)}");
      return LiveRoom(
        cover: liveStream['poster'] != null
            ? isImage(liveStream['poster'])
            ? liveStream['poster'].toString()
            : '${liveStream['poster'].toString()}.jpg'
            : "",
        watching: jsonObj["liveroom"]["playList"][0]["isLiving"] ? gameInfo["watchingCount"].toString() : '0',
        roomId: author["id"],
        area: gameInfo["name"] ?? '',
        title: author["description"] != null ? author["description"].replaceAll("\n", " ") : '',
        nick: author["name"].toString(),
        avatar: author["avatar"].toString(),
        introduction: author["description"].toString(),
        notice: author["description"].toString(),
        status: jsonObj["liveroom"]["playList"][0]["isLiving"],
        liveStatus: jsonObj["liveroom"]["playList"][0]["isLiving"] ? LiveStatus.live : LiveStatus.offline,
        platform: Sites.kuaishouSite,
        link: liveStreamId,
        data: liveStream,
        danmakuData: tmpArgs,
      );
    } catch (e) {
      CoreLog.error(e);
      return getLiveRoomWithError(detail);
    }
  }


  @override
  Future<LiveSearchRoomResult> searchRooms(String keyword, {int page = 1}) async {
    // 快手无法搜索主播，只能搜索游戏分类这里不做展示
    return LiveSearchRoomResult(hasMore: false, items: []);
  }

  @override
  Future<LiveSearchAnchorResult> searchAnchors(String keyword, {int page = 1}) async {
    return LiveSearchAnchorResult(hasMore: false, items: []);
  }

}
