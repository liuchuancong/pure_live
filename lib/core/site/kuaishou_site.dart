import 'dart:convert';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'dart:developer' as developer;
import 'package:cookie_jar/cookie_jar.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/model/live_anchor_item.dart';
import 'package:pure_live/plugins/fake_useragent.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/danmaku/empty_danmaku.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';

class KuaishowSite implements LiveSite {
  @override
  String id = "kuaishou";

  @override
  String name = "快手直播";

  String cookie = '';
  Map<String, String> cookieObj = {};
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
  LiveDanmaku getDanmaku() => EmptyDanmaku();

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

    for (var item in categories) {
      var items = await getAllSubCategores(item, 1, 30, []);
      item.children.addAll(items);
    }
    return categories;
  }

  final Map<String, dynamic> headers = {
    'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36',
    'accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3',
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
      allSubCategores.addAll(subsArea);
      var hasMore = subsArea.length >= pageSize;
      if (hasMore) {
        page++;
        await getAllSubCategores(liveCategory, page, pageSize, allSubCategores);
      }
      return allSubCategores;
    } catch (e) {
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
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    var api = category.areaId!.length < 7
        ? "https://live.kuaishou.com/live_api/gameboard/list"
        : "https://live.kuaishou.com/live_api/non-gameboard/list";
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
    return items;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) {
    List<LivePlayQuality> qualities = <LivePlayQuality>[];
    developer.log(detail.data.toString(), name: 'detail.data');
    var qulityList = detail.data["h264"]["adaptationSet"]["representation"];

    for (var quality in qulityList) {
      var qualityItem = LivePlayQuality(
        quality: quality["name"],
        sort: quality["level"],
        data: <String>[quality["url"]],
      );
      qualities.add(qualityItem);
    }
    qualities.sort((a, b) => b.sort.compareTo(a.sort));
    return Future.value(qualities);
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    return quality.data as List<String>;
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    try {
      var resultText = await HttpClient.instance.getJson(
        "https://live.kuaishou.com/live_api/home/list",
        header: headers,
      );

      var result = resultText['data']['list'] ?? [];
      var items = <LiveRoom>[];
      for (var item in result) {
        for (var sitem in item["gameLiveInfo"]) {
          for (var titem in sitem["liveInfo"]) {
            var author = titem["author"];
            var gameInfo = titem["gameInfo"];
            var roomItems = LiveRoom(
              cover: gameInfo['poster'].toString(),
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
        }
      }
      return items;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future registerDid() async {
    var res = await HttpClient.instance.postJson(
      'https://log-sdk.ksapisrv.com/rest/wd/common/log/collect/misc2?v=3.9.49&kpn=KS_GAME_LIVE_PC',
      header: headers,
      data: misc2dic(cookieObj['did']!),
    );
    return res;
  }

  Map<String, Object> misc2dic(String did) {
    var map = {
      'common': {
        'identity_package': {'device_id': did, 'global_id': ''},
        'app_package': {'language': 'zh-CN', 'platform': 10, 'container': 'WEB', 'product_name': 'KS_GAME_LIVE_PC'},
        'device_package': {
          'os_version': 'NT 6.1',
          'model': 'Windows',
          'ua':
              'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.198 Safari/537.36',
        },
        'need_encrypt': 'false',
        'network_package': {'type': 3},
        'h5_extra_attr':
            '{"sdk_name":"webLogger","sdk_version":"3.9.49","sdk_bundle":"log.common.js","app_version_name":"","host_product":"","resolution":"1600x900","screen_with":1600,"screen_height":900,"device_pixel_ratio":1,"domain":"https://live.kuaishou.com"}',
        'global_attr': '{}',
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
              'url_package': {
                'page': 'GAME_DETAL_PAGE',
                'identity': '5316c78e-f0b6-4be2-a076-c8f9d11ebc0a',
                'page_type': 2,
                'params': '{"game_id":1001,"game_name":"王者荣耀"}',
              },
              'element_package': {},
            },
          },
        },
      ],
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

  Future getWebsocketUrl(String liveRoomId) async {
    var variables = {'liveStreamId': liveRoomId};
    var query =
        r'query WebSocketInfoQuery($liveStreamId: String) {\n  webSocketInfo(liveStreamId: $liveStreamId) {\n    token\n    webSocketUrls\n    __typename\n  }\n}\n';
    var res = await HttpClient.instance.postJson(
      'https://live.kuaishou.com/live_graphql',
      header: headers,
      data: {"operationName": 'WebSocketInfoQuery', "variables": variables, "query": query},
    );
    return res;
  }

  @override
  Future<LiveRoom> getRoomDetail({required String platform, required String roomId}) async {
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
    if (SettingsService.to.cookieManager.kuaishouCookie.v.isNotEmpty) {
      mHeaders['cookie'] = SettingsService.to.cookieManager.kuaishouCookie.v;
    }

    mHeaders['accept'] =
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9';
    await getCookie(url);
    await registerDid();
    var resultText = await HttpClient.instance.getText(url, queryParameters: {}, header: mHeaders);

    try {
      var text = RegExp(r"window\.__INITIAL_STATE__=(.*?);", multiLine: false).firstMatch(resultText)?.group(1);

      var transferData = text!.replaceAll("undefined", "null");

      var jsonObj = jsonDecode(transferData);
      var liveStream = jsonObj["liveroom"]["playList"][0]["liveStream"];
      var author = jsonObj["liveroom"]["playList"][0]["author"];
      var gameInfo = jsonObj["liveroom"]["playList"][0]["gameInfo"];
      var liveStreamId = liveStream["id"];
      return LiveRoom(
        cover: isImage(liveStream['poster'])
            ? liveStream['poster'].toString()
            : '${liveStream['poster'].toString()}.jpg',
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
      );
    } catch (e) {
      LiveRoom liveRoom =
          SettingsService.to.fav.favoriteRooms.v.firstWhereOrNull(
            (r) => r.roomId == roomId && r.platform == platform,
          ) ??
          LiveRoom(roomId: roomId, platform: platform);

      liveRoom.liveStatus = LiveStatus.offline;
      liveRoom.status = false;
      return liveRoom;
    }
  }

  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) async {
    // 快手无法搜索主播，只能搜索游戏分类这里不做展示
    return [];
  }

  @override
  Future<List<LiveAnchorItem>> searchAnchors(String keyword, {int page = 1, int pageSize = 30}) async {
    return [];
  }

  @override
  Future<bool> getLiveStatus({required String platform, required String roomId}) async {
    return false;
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({required String roomId}) {
    //尚不支持
    return Future.value([]);
  }
}
