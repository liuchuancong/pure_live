import 'dart:convert';

import 'package:pure_live/common/index.dart';
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
    final cookie = SettingsService.to.cookieManager.yyCookie.v.trim();
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
      if (cookie.isNotEmpty) 'Cookie': cookie,
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

    if (imgUrl.startsWith('http://')) {
      return 'https://${imgUrl.substring(7)}';
    }

    return imgUrl;
  }

  static dynamic decode(dynamic data) {
    if (data is String) {
      return json.decode(data);
    }
    return data;
  }

  static int? _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  @visibleForTesting
  static bool isLiveValue(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == '1' || normalized == 'true' || normalized == 'live';
  }

  /// Reads the three values YY embeds in a JavaScript object without starting
  /// a native JavaScript runtime. The values are simple literals and are used
  /// only as query parameters for the category endpoint.
  @visibleForTesting
  static Map<String, dynamic>? parseCategoryPageInfo(String html) {
    final source = RegExp(r'pageInfo\s*=\s*(\{[\s\S]*?\})\s*;', multiLine: true).firstMatch(html)?.group(1);
    if (source == null) return null;

    final moduleId = int.tryParse(RegExp(r'''moduleId\s*:\s*['"]?(-?\d+)''').firstMatch(source)?.group(1) ?? '');
    final biz = RegExp(r'''biz\s*:\s*['"]([^'"]+)''').firstMatch(source)?.group(1)?.trim() ?? '';
    final subBiz = RegExp(r'''subBiz\s*:\s*['"]([^'"]+)''').firstMatch(source)?.group(1)?.trim() ?? '';
    if (moduleId == null || biz.isEmpty || subBiz.isEmpty) return null;
    return <String, dynamic>{'moduleId': moduleId, 'biz': biz, 'subBiz': subBiz};
  }

  @visibleForTesting
  static String normalizeWebUrl(String value) {
    final url = value.trim();
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('http://')) return 'https://${url.substring(7)}';
    return url;
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
      final url = normalizeWebUrl(item['url']?.toString() ?? '');
      if (url.isEmpty) {
        subs.add(subCategory);
        continue;
      }
      final resultText = await HttpClient.instance.getText(url, queryParameters: {}, header: getHeaders());
      final pageInfo = parseCategoryPageInfo(resultText);
      if (pageInfo != null) {
        subCategory.shortName = json.encode(pageInfo);
        final biz = pageInfo['biz']?.toString() ?? '';
        if (biz.isNotEmpty) bizAreaNameMap.putIfAbsent(biz, () => subCategory.areaName ?? biz);
      }

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
    return parsePlayQualities(await getLiveStreamObj(detail: detail, qn: '1'));
  }

  @visibleForTesting
  static List<LivePlayQuality> parsePlayQualities(dynamic payload) {
    final channelStreamInfo = payload is Map ? payload['channel_stream_info'] : null;
    final streams = channelStreamInfo is Map ? channelStreamInfo['streams'] : null;
    if (streams is! List) return const <LivePlayQuality>[];

    final records = <({String name, String gear, int rate})>[];
    final seenGears = <String>{};
    for (final stream in streams.whereType<Map>()) {
      final jsonText = stream['json']?.toString().trim() ?? '';
      if (jsonText.isEmpty) continue;
      try {
        final decoded = json.decode(jsonText);
        final gearInfo = decoded is Map ? decoded['gear_info'] : null;
        if (gearInfo is! Map) continue;
        final name = gearInfo['name']?.toString().trim() ?? '';
        final gear = gearInfo['gear']?.toString().trim() ?? '';
        final rate = int.tryParse(decoded['rate']?.toString() ?? '') ?? 0;
        if (name.isEmpty || gear.isEmpty || !seenGears.add(gear)) continue;
        records.add((name: name, gear: gear, rate: rate));
      } catch (error) {
        CoreLog.error('YY parse quality error: $error');
      }
    }

    final nameCounts = <String, int>{};
    for (final record in records) {
      nameCounts.update(record.name, (count) => count + 1, ifAbsent: () => 1);
    }
    final qualities = records
        .map(
          (record) => LivePlayQuality(
            quality: nameCounts[record.name] == 1 ? record.name : '${record.name} · ${record.gear}',
            id: record.gear,
            sort: record.rate,
            data: record.gear,
          ),
        )
        .toList(growable: false);
    qualities.sort((left, right) => right.sort.compareTo(left.sort));
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

    return parsePlayUrls(liveData);
  }

  @visibleForTesting
  static List<String> parsePlayUrls(dynamic payload) {
    final avpInfoRes = payload is Map ? payload['avp_info_res'] : null;
    final streamLineAddr = avpInfoRes is Map ? avpInfoRes['stream_line_addr'] : null;
    if (streamLineAddr is! Map) return const <String>[];

    final urls = <String>[];
    for (final value in streamLineAddr.values.whereType<Map>()) {
      final cdnInfo = value['cdn_info'];
      if (cdnInfo is! Map) continue;
      var url = cdnInfo['url']?.toString().trim() ?? '';
      if (url.startsWith('//')) url = 'https:$url';
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme || !const {'http', 'https'}.contains(uri.scheme) || urls.contains(url)) {
        continue;
      }
      urls.add(url);
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
      final biz = item['biz']?.toString() ?? '';
      final area = bizAreaNameMap[biz] ?? biz;
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
      return await _fetchRoomDetail(platform: platform, roomId: roomId);
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
    return _fetchRoomDetail(platform: platform, roomId: roomId);
  }

  Future<LiveRoom> _fetchRoomDetail({required String platform, required String roomId}) async {
    final response = decode(
      await HttpClient.instance.getJson(
        'https://www.yy.com/api/liveInfoDetail/$roomId/$roomId/0',
        header: getHeaders(),
      ),
    );
    if (response is! Map || response['resultCode'] != 0) {
      throw const FormatException('YY room detail response is invalid');
    }
    final rawItem = response['data'];
    if (rawItem is! Map) {
      return LiveRoom(roomId: roomId, platform: platform, status: false, liveStatus: LiveStatus.offline);
    }
    final item = Map<String, dynamic>.from(rawItem);
    final topSid = _asInt(item['sid']) ?? _asInt(roomId) ?? 0;
    final subSid = _asInt(item['ssid']) ?? topSid;
    final biz = item['biz']?.toString() ?? '';
    return LiveRoom(
      roomId: item['sid']?.toString() ?? roomId,
      title: item['desc']?.toString() ?? '',
      cover: validImgUrl(item['thumb2']?.toString() ?? ''),
      nick: item['name']?.toString() ?? '',
      userId: item['uid']?.toString() ?? '',
      watching: item['users']?.toString() ?? '',
      popularity: item['users']?.toString() ?? '',
      audienceMetricType: AudienceMetricType.popularity,
      avatar: validImgUrl(item['avatar']?.toString() ?? ''),
      area: bizAreaNameMap[biz] ?? biz,
      liveStatus: LiveStatus.live,
      status: true,
      platform: Sites.yySite,
      danmakuData: YyDanmakuArgs(topSid: topSid, subSid: subSid),
      link: 'https://www.yy.com/$roomId',
    );
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
      final isLive = isLiveValue(item['liveOn']);

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
          area: bizAreaNameMap[item['biz']?.toString() ?? ''] ?? item['biz']?.toString() ?? '',
          liveStatus: isLive ? LiveStatus.live : LiveStatus.offline,
          status: isLive,
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
      queryParameters: {'q': keyword, 't': '1', 'n': page},
      header: getHeaders(),
    );

    final result = decode(resultText);

    final List<LiveAnchorItem> items = [];

    final docs = result['data']?['searchResult']?['response']?['1']?['docs'] ?? [];

    for (final item in docs) {
      items.add(
        LiveAnchorItem(
          roomId: item['sid']?.toString() ?? item['ssid']?.toString() ?? '',
          avatar: validImgUrl(item['headurl']?.toString() ?? ''),
          userName: item['name']?.toString() ?? item['stageName']?.toString() ?? '',
          liveStatus: isLiveValue(item['liveOn']),
        ),
      );
    }

    return items;
  }

  @override
  Future<bool> getLiveStatus({required String platform, required String roomId}) async {
    final room = await _fetchRoomDetail(platform: platform, roomId: roomId);
    return room.status == true && room.liveStatus == LiveStatus.live;
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({required String roomId}) {
    //尚不支持
    return Future.value([]);
  }
}
