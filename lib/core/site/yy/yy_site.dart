import 'dart:convert';
import 'dart:collection';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/fjs_engine.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/model/live_anchor_item.dart';
import 'package:pure_live/core/danmaku/yy_danmaku.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/modules/live_play/controllers/player_controller.dart';

class YYSite implements LiveSite, LiveSiteRoomRefresher {
  @override
  String id = Sites.yySite;

  @override
  String name = 'YY 直播';

  @override
  LiveDanmaku getDanmaku() => YyDanmaku();

  /// ============================================================
  /// Headers
  /// ============================================================

  Map<String, String> getHeaders() {
    return {
      'Accept': '*/*',
      'Origin': 'https://www.yy.com',
      'Referer': 'https://www.yy.com/',
      'Sec-Fetch-Dest': 'empty',
      'Sec-Fetch-Mode': 'cors',
      'Sec-Fetch-Site': 'same-site',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/128.0.0.0 Safari/537.36',
      'Cookie': SettingsService.to.cookieManager.yyCookie.v,
    };
  }

  final Map<String, dynamic> headers = {
    'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/107.0.0.0 Safari/537.36',
    'accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,'
        'image/webp,image/apng,*/*;q=0.8,'
        'application/signed-exchange;v=b3',
    'connection': 'keep-alive',
    'sec-ch-ua': 'Google Chrome;v=107, Chromium;v=107, Not=A?Brand;v=24',
    'sec-ch-ua-platform': 'macOS',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'same-origin',
    'Sec-Fetch-User': '?1',
  };

  /// ============================================================
  /// 图片
  /// ============================================================

  String validImgUrl(String imgUrl) {
    if (imgUrl.isEmpty) {
      return '';
    }

    if (imgUrl.startsWith('//')) {
      return 'https:$imgUrl';
    }

    return imgUrl;
  }

  static dynamic decode(dynamic data) {
    if (data.runtimeType == String) {
      return json.decode(data);
    }
    return data;
  }

  /// ============================================================
  /// 分类
  /// ============================================================

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    final resultText = await HttpClient.instance.getJson(
      'https://www.yy.com/yyweb/module/data/header',
      queryParameters: {},
      header: getHeaders(),
    );
    final result = decode(resultText);
    final List<LiveCategory> categories = [];
    final categoryTabs = result['categoryTabs'] ?? [];
    for (final item in categoryTabs) {
      categories.add(LiveCategory(id: item['id'].toString(), name: item['title'].toString(), children: []));
    }
    final futures = <Future>[];
    for (final category in categories) {
      futures.add(
        Future(() async {
          final items = await getAllSubCategores(category, 1, 120, []);
          category.children.addAll(items);
        }),
      );
    }
    await Future.wait(futures);
    return categories;
  }

  Future<List<LiveArea>> getAllSubCategores(
    LiveCategory liveCategory,
    int page,
    int pageSize,
    List<LiveArea> allSubCategores,
  ) async {
    try {
      final subsArea = await getSubCategores(liveCategory, page, pageSize);
      allSubCategores.addAll(subsArea);
      final hasMore = subsArea.length >= pageSize;
      if (hasMore) {
        await getAllSubCategores(liveCategory, page + 1, pageSize, allSubCategores);
      }
      return allSubCategores;
    } catch (e) {
      CoreLog.error(e);
      return allSubCategores;
    }
  }

  Future<List<LiveArea>> getSubCategores(LiveCategory liveCategory, int page, int pageSize) async {
    final resultText = await HttpClient.instance.getJson(
      'https://www.yy.com/c/yycom/category/getCategory.action',
      queryParameters: {'parentId': liveCategory.id},
      header: getHeaders(),
    );
    final result = decode(resultText);
    final List<LiveArea> subs = [];
    for (final item in result['data'] ?? []) {
      final subCategory = LiveArea(
        areaId: item['id'].toString(),
        areaName: item['title']?.toString() ?? '',
        areaType: liveCategory.id,
        platform: Sites.yySite,
        areaPic: item['cover']?.toString() ?? '',
        typeName: liveCategory.name,
      );
      final url = item['url']?.toString() ?? '';
      if (url.isEmpty) {
        subs.add(subCategory);
        continue;
      }
      final resultText = await HttpClient.instance.getText(url, queryParameters: {}, header: getHeaders());
      final jsonText = RegExp(r'pageInfo[^{]+([^;]+);', multiLine: true).firstMatch(resultText)?.group(1) ?? '';
      if (jsonText.isEmpty) {
        subs.add(subCategory);
        continue;
      }
      await FlutterJsEngine.instance.init();
      var params = await FlutterJsEngine.instance.eval("pageInfo =$jsonText");

      final pageInfo = params.rawResult;
      CoreLog.d('pageInfo: $pageInfo');

      final moduleId = pageInfo['pageBar']['moduleId'];

      final biz = pageInfo['pageBar']['biz'];

      final subBiz = pageInfo['pageBar']['subBiz'];

      final map = {'moduleId': moduleId, 'biz': biz, 'subBiz': subBiz};

      subCategory.shortName = json.encode(map);

      subs.add(subCategory);
    }

    return subs;
  }

  /// ============================================================
  /// 分类直播间
  /// ============================================================

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    CoreLog.d('getCategoryRooms: ${json.encode(category)}');

    final requestPageSize = pageSize;

    final shortName = category.shortName ?? '{}';

    final decodeShortName = decode(shortName) as Map;

    final Map<String, dynamic> queryParameters = {'page': page, 'pageSize': requestPageSize};

    for (final key in decodeShortName.keys) {
      queryParameters[key.toString()] = decodeShortName[key];
    }

    final resultText = await HttpClient.instance.getJson(
      'https://www.yy.com/more/page.action',
      queryParameters: queryParameters,
      header: getHeaders(),
    );

    final result = decode(resultText);

    final List<LiveRoom> items = [];

    final data = result['data']?['data'] ?? [];

    for (final item in data) {
      final users = item['users']?.toString() ?? '';

      items.add(
        LiveRoom(
          roomId: item['sid']?.toString() ?? '',
          title: item['desc']?.toString() ?? '',
          cover: validImgUrl(item['thumb2']?.toString() ?? ''),
          nick: item['name']?.toString() ?? '',
          userId: item['uid']?.toString() ?? '',
          watching: users,
          popularity: users,
          audienceMetricType: AudienceMetricType.popularity,
          avatar: validImgUrl(item['avatar']?.toString() ?? ''),
          area: category.areaName,
          liveStatus: LiveStatus.live,
          status: true,
          platform: Sites.yySite,
        ),
      );
    }

    return items;
  }

  /// ============================================================
  /// 获取直播流
  /// ============================================================

  Future<Map<String, dynamic>> getLiveStreamObj({required LiveRoom detail, required String qn}) async {
    final sequence = DateTime.now().millisecondsSinceEpoch;

    final result = await HttpClient.instance.postJson(
      'https://stream-manager.yy.com/v3/channel/streams',
      queryParameters: {
        'uid': '0',
        'cid': detail.roomId,
        'sid': detail.roomId,
        'appid': '0',
        'sequence': sequence.toString(),
        'encode': 'json',
      },
      data: {
        'head': {
          'seq': sequence,
          'appidstr': '0',
          'bidstr': '123',
          'cidstr': detail.roomId,
          'sidstr': detail.roomId,
          'uid64': 0,
          'client_type': 108,
          'client_ver': '5.19.4',
          'stream_sys_ver': 1,
          'app': 'yylive_web',
          'playersdk_ver': '5.19.4',
          'thundersdk_ver': '0',
          'streamsdk_ver': '5.19.4',
        },
        'client_attribute': {
          'client': 'web',
          'model': 'web0',
          'cpu': '',
          'graphics_card': '',
          'os': 'chrome',
          'osversion': '128.0.0.0',
          'vsdk_version': '',
          'app_identify': '',
          'app_version': '',
          'business': '',
          'width': '1366',
          'height': '768',
          'scale': '',
          'client_type': 8,
          'h265': 0,
        },
        'avp_parameter': {
          'version': 1,
          'client_type': 8,
          'service_type': 0,
          'imsi': 0,
          'send_time': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'line_seq': -1,
          'gear': int.parse(qn),
          'ssl': 1,
          'stream_format': 0,
        },
      },
      header: getHeaders(),
    );

    return decode(result);
  }

  /// ============================================================
  /// 清晰度
  /// ============================================================

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    final jsonObj = await getLiveStreamObj(detail: detail, qn: '1');

    final channelStreamInfo = jsonObj['channel_stream_info'] as Map<String, dynamic>?;

    if (channelStreamInfo == null) {
      return [];
    }

    final streams = channelStreamInfo['streams'] as List<dynamic>? ?? [];

    final Map<String, LivePlayQuality> qualityMap = HashMap();

    for (final stream in streams) {
      if (stream is! Map) {
        continue;
      }

      final streamMap = Map<String, dynamic>.from(stream);

      if (!streamMap.containsKey('stream_key')) {
        continue;
      }

      final jsonStr = streamMap['json']?.toString() ?? '';

      if (jsonStr.isEmpty) {
        continue;
      }

      try {
        final info = json.decode(jsonStr) as Map<String, dynamic>;

        final gearInfo = info['gear_info'] as Map<String, dynamic>?;

        if (gearInfo == null) {
          continue;
        }

        final desc = gearInfo['name']?.toString() ?? '';

        final qn = gearInfo['gear']?.toString() ?? '';

        final rate = int.tryParse(info['rate']?.toString() ?? '') ?? 0;

        if (qn.isEmpty || desc.isEmpty) {
          continue;
        }

        qualityMap.putIfAbsent(desc, () => LivePlayQuality(quality: desc, sort: rate, data: qn));
      } catch (e) {
        CoreLog.error('YY parse quality error: $e');
      }
    }

    final qualities = qualityMap.values.toList();

    qualities.sort((a, b) => b.sort.compareTo(a.sort));

    return qualities;
  }

  /// ============================================================
  /// 播放地址
  /// ============================================================

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    final qn = quality.data?.toString() ?? '';

    if (qn.isEmpty) {
      return [];
    }

    final liveData = await getLiveStreamObj(detail: detail, qn: qn);

    final avpInfoRes = liveData['avp_info_res'] as Map<String, dynamic>?;

    if (avpInfoRes == null) {
      return [];
    }

    final streamLineAddr = avpInfoRes['stream_line_addr'] as Map<String, dynamic>?;

    if (streamLineAddr == null || streamLineAddr.isEmpty) {
      return [];
    }

    final List<String> urls = [];

    for (final entry in streamLineAddr.entries) {
      final value = entry.value;

      if (value is! Map) {
        continue;
      }

      final cdnInfo = value['cdn_info'] as Map?;

      if (cdnInfo == null) {
        continue;
      }

      final url = cdnInfo['url']?.toString() ?? '';

      if (url.isNotEmpty && !urls.contains(url)) {
        urls.add(url);
      }
    }

    return urls;
  }

  /// ============================================================
  /// 推荐
  /// ============================================================

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    final resultText = await HttpClient.instance.getJson(
      'https://www.yy.com/more/page.action',
      queryParameters: {'page': page, 'pageSize': pageSize, 'biz': 'other', 'subBiz': 'idx', 'moduleId': '-1'},
      header: getHeaders(),
    );

    final result = decode(resultText);

    final List<LiveRoom> items = [];

    final data = result['data']?['data'] ?? [];
    for (final item in data) {
      final users = item['users']?.toString() ?? '';
      String area = await getAreaNameByBiz(item['biz']?.toString() ?? '');
      items.add(
        LiveRoom(
          roomId: item['sid']?.toString() ?? '',
          title: item['desc']?.toString() ?? '',
          cover: validImgUrl(item['thumb2']?.toString() ?? ''),
          nick: item['name']?.toString() ?? '',
          userId: item['uid']?.toString() ?? '',
          watching: users,
          popularity: users,
          audienceMetricType: AudienceMetricType.popularity,
          avatar: validImgUrl(item['avatar']?.toString() ?? ''),
          area: area,
          liveStatus: LiveStatus.live,
          status: true,
          platform: Sites.yySite,
        ),
      );
    }

    return items;
  }

  /// ============================================================
  /// 分类名称
  /// ============================================================

  final Map<String, String> bizAreaNameMap = {};

  Future<Map<String, String>> getBizAreaNameMap() async {
    if (bizAreaNameMap.isNotEmpty) {
      return bizAreaNameMap;
    }

    final List<LiveCategory> data = await getCategores(1, 100);
    for (final liveCategory in data) {
      for (final liveArea in liveCategory.children) {
        final shortName = liveArea.shortName ?? '{}';
        final areaName = liveArea.areaName ?? '';
        try {
          final shortNameDecode = decode(shortName);
          final biz = shortNameDecode['biz']?.toString() ?? '';
          if (biz.isNotEmpty) {
            bizAreaNameMap[biz] = areaName;
          }
        } catch (e) {
          CoreLog.error(e);
        }
      }
    }

    return bizAreaNameMap;
  }

  Future<String> getAreaNameByBiz(String biz) async {
    final map = await getBizAreaNameMap();

    return map[biz] ?? '';
  }

  /// ============================================================
  /// 房间详情
  /// ============================================================

  @override
  Future<LiveRoom> getRoomDetail({required String platform, required String roomId}) async {
    try {
      var liveRoomUrl = "https://www.yy.com/$roomId";
      var resultText = await HttpClient.instance.getText(liveRoomUrl, header: getHeaders());
      var userId = RegExp(r'uid\s*:\s*"(.*?)",\s*owUid', multiLine: true).firstMatch(resultText)?.group(1) ?? '';
      var url = "https://www.yy.com/api/liveInfoDetail/$roomId/$roomId/$userId";
      var newResultText = await HttpClient.instance.getJson(url, header: getHeaders());
      var resultJson = decode(newResultText);
      if (resultJson["resultCode"] != 0) {
        return LiveRoom(roomId: roomId, platform: platform).getLiveRoomWithError();
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
        platform: Sites.yySite,
        danmakuData: YyDanmakuArgs(topSid: item["sid"] ?? 0, subSid: item["ssid"] ?? 0),
      );
      return roomItem;
    } catch (e) {
      CoreLog.error(e);
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

  /// ============================================================
  /// 房间刷新
  /// ============================================================

  @override
  Future<LiveRoom> getRoomDetailForRefresh({required String platform, required String roomId}) async {
    try {
      var liveRoomUrl = "https://www.yy.com/$roomId";
      var resultText = await HttpClient.instance.getText(liveRoomUrl, header: getHeaders());
      var userId = RegExp(r'uid\s*:\s*"(.*?)",\s*owUid', multiLine: true).firstMatch(resultText)?.group(1) ?? '';
      var url = "https://www.yy.com/api/liveInfoDetail/$roomId/$roomId/$userId";
      var newResultText = await HttpClient.instance.getJson(url, header: getHeaders());
      var resultJson = decode(newResultText);
      if (resultJson["resultCode"] != 0) {
        return LiveRoom(roomId: roomId, platform: platform).getLiveRoomWithError();
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
        platform: Sites.yySite,
        danmakuData: YyDanmakuArgs(topSid: item["sid"] ?? 0, subSid: item["ssid"] ?? 0),
      );
      return roomItem;
    } catch (e) {
      CoreLog.error(e);
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

  /// ============================================================
  /// 搜索直播间
  /// ============================================================

  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) async {
    final resultText = await HttpClient.instance.getJson(
      'https://www.yy.com/apiSearch/doSearch.json',
      queryParameters: {'q': keyword, 't': '120', 'n': page},
      header: getHeaders(),
    );

    final result = decode(resultText);
    final List<LiveRoom> items = [];

    final docs = result['data']?['searchResult']?['response']?['120']?['docs'] ?? [];

    for (final item in docs) {
      final users = item['users']?.toString() ?? '';

      final roomId = item['sid']?.toString() ?? '';

      items.add(
        LiveRoom(
          roomId: roomId,
          title: item['channelName']?.toString() ?? '',
          cover: validImgUrl(item['posterurl']?.toString() ?? ''),
          nick: item['name']?.toString() ?? '',
          userId: item['uid']?.toString() ?? '',
          watching: users,
          popularity: users,
          audienceMetricType: AudienceMetricType.popularity,
          avatar: validImgUrl(item['headurl']?.toString() ?? ''),
          area: await getAreaNameByBiz(item['biz']?.toString() ?? ''),
          liveStatus: LiveStatus.live,
          status: true,
          platform: Sites.yySite,
          link: 'https://www.yy.com/$roomId',
        ),
      );
    }

    return items;
  }

  /// ============================================================
  /// 搜索主播
  /// ============================================================

  @override
  Future<List<LiveAnchorItem>> searchAnchors(String keyword, {int page = 1, int pageSize = 30}) async {
    final resultText = await HttpClient.instance.getJson(
      'https://www.yy.com/apiSearch/doSearch.json',
      queryParameters: {'q': keyword, 't': '120', 'n': page},
      header: getHeaders(),
    );

    final result = json.decode(resultText);

    final List<LiveAnchorItem> items = [];

    final docs = result['data']?['searchResult']?['response']?['1']?['docs'] ?? [];

    for (final item in docs) {
      items.add(
        LiveAnchorItem(
          roomId: item['room_id']?.toString() ?? '',
          avatar: validImgUrl(item['game_avatarUrl180']?.toString() ?? ''),
          userName: item['game_nick']?.toString() ?? '',
          liveStatus: item['gameLiveOn'],
        ),
      );
    }

    return items;
  }

  @override
  Future<bool> getLiveStatus({required String platform, required String roomId}) async {
    return Future.value(true);
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({required String roomId}) {
    //尚不支持
    return Future.value([]);
  }
}
