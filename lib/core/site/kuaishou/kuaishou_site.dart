import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
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
import 'package:pure_live/modules/live_play/controllers/player_controller.dart';
import 'package:pure_live/core/utils/live_quality_label.dart';

class KuaishowSite implements LiveSite, LiveSiteRoomRefresher, LiveSiteRecordRoomResolver {
  @override
  String id = Sites.kuaishouSite;

  @override
  String name = "快手直播";

  String cookie = '';
  Map<String, String> cookieObj = {};
  Future<void>? _sessionBootstrap;
  DateTime? _sessionUpdatedAt;
  static const Duration _sessionLifetime = Duration(minutes: 30);
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
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36',
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
        onlineViewers: item["watchingCount"].toString(),
        audienceMetricType: AudienceMetricType.onlineViewers,
        avatar: item["author"]["avatar"],
        area: item["gameInfo"]["name"].toString(),
        liveStatus: LiveStatus.live,
        status: true,
        platform: Sites.kuaishouSite,
        data: item["playUrls"],
      );
      items.add(roomItem);
    }
    return items;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    final qualities = parsePlayQualities(detail.data);
    if (qualities.isEmpty) {
      throw StateError('Kuaishou room has no playable live or replay stream');
    }
    return qualities;
  }

  /// Parses both current Kuaishou room-page and recommendation payloads.
  ///
  /// Room pages expose `{h264: ..., hevc: ...}` while list/replay entries are
  /// usually `[<direct adaptationSet descriptor>]`. Multiple descriptors can
  /// represent CDN lines, so URLs of the same quality are merged and deduped.
  static List<LivePlayQuality> parsePlayQualities(dynamic raw) {
    final descriptors = raw is List ? raw : <dynamic>[raw];
    final merged = <String, ({String name, int sort, List<String> urls})>{};

    for (final rawDescriptor in descriptors) {
      if (rawDescriptor is! Map) continue;
      dynamic descriptor = rawDescriptor;

      // Prefer AVC for broad hardware compatibility. HEVC is a fallback when
      // the platform omits AVC rather than an additional duplicate quality set.
      for (final codec in const ['h264', 'avc', 'hevc', 'h265']) {
        final candidate = rawDescriptor[codec];
        if (_representationsOf(candidate).isNotEmpty) {
          descriptor = candidate;
          break;
        }
      }

      for (final item in _representationsOf(descriptor)) {
        if (item is! Map) continue;
        final url = item['url']?.toString().trim() ?? '';
        if (Uri.tryParse(url)?.isAbsolute != true || (!url.startsWith('http://') && !url.startsWith('https://'))) {
          continue;
        }
        final sort = _asInt(item['level']) ?? _asInt(item['bitrate']) ?? 0;
        final name = item['name']?.toString().trim().isNotEmpty == true
            ? item['name'].toString().trim()
            : item['shortName']?.toString().trim().isNotEmpty == true
            ? item['shortName'].toString().trim()
            : item['qualityType']?.toString().trim().isNotEmpty == true
            ? item['qualityType'].toString().trim()
            : '清晰度 $sort';
        final key = '$name\u0000$sort';
        final existing = merged[key];
        if (existing == null) {
          merged[key] = (name: name, sort: sort, urls: <String>[url]);
        } else if (!existing.urls.contains(url)) {
          existing.urls.add(url);
        }
      }
    }

    final qualities = merged.values
        .map(
          (entry) => LivePlayQuality(
            quality: LiveQualityLabel.normalize(
              platform: Sites.kuaishouSite,
              rawLabel: entry.name,
              id: '${entry.name}\u0000${entry.sort}',
            ),
            id: '${entry.name}\u0000${entry.sort}',
            sort: entry.sort,
            data: List<String>.unmodifiable(entry.urls),
          ),
        )
        .toList(growable: false);
    qualities.sort((a, b) => b.sort.compareTo(a.sort));
    return qualities;
  }

  static List<dynamic> _representationsOf(dynamic descriptor) {
    if (descriptor is! Map) return const [];
    final adaptationSet = descriptor['adaptationSet'];
    final representations = adaptationSet is Map ? adaptationSet['representation'] : descriptor['representation'];
    if (representations is List) return representations;
    return const [];
  }

  static int? _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    final data = quality.data;
    if (data is String && data.isNotEmpty) return <String>[data];
    if (data is List) {
      return data.map((item) => item.toString()).where((url) => url.isNotEmpty).toList(growable: false);
    }
    return const <String>[];
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
              onlineViewers: titem["watchingCount"].toString(),
              audienceMetricType: AudienceMetricType.onlineViewers,
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

  Future registerDid({Map<String, dynamic>? requestHeaders}) async {
    final did = cookieObj['did'];
    if (did == null || did.isEmpty) return null;
    var res = await HttpClient.instance.postJson(
      'https://log-sdk.ksapisrv.com/rest/wd/common/log/collect/misc2?v=3.9.49&kpn=KS_GAME_LIVE_PC',
      header: requestHeaders ?? headers,
      data: misc2dic(did),
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
          'ua': 'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.198 Safari/537.36',
        },
        'need_encrypt': 'false',
        'network_package': {'type': 3},
        'h5_extra_attr': '{"sdk_name":"webLogger","sdk_version":"3.9.49","sdk_bundle":"log.common.js","app_version_name":"","host_product":"","resolution":"1600x900","screen_with":1600,"screen_height":900,"device_pixel_ratio":1,"domain":"https://live.kuaishou.com"}',
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
    cookieObj.clear();
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
    try {
      final loaded = await _loadRoom(roomId, includePlaybackData: true, ensureSession: true);
      if (loaded.isLiveNow) return loaded;

      // The public recommendation feed intentionally includes replay cards.
      // Their room page reports offline but the selected card carries signed
      // replay URLs. Preserve that matching card as an explicit recording.
      final current = _matchingCurrentRoom(platform: platform, roomId: roomId);
      if (current != null && parsePlayQualities(current.data).isNotEmpty) {
        return current.copyWith(status: true, liveStatus: LiveStatus.live, isRecord: true);
      }
      return loaded;
    } catch (e) {
      final currentRoom = _matchingCurrentRoom(platform: platform, roomId: roomId);
      if (currentRoom != null) return currentRoom.getLiveRoomWithError();
      return LiveRoom(roomId: roomId, platform: platform).getLiveRoomWithError();
    }
  }

  LiveRoom? _matchingCurrentRoom({required String platform, required String roomId}) {
    if (!Get.isRegistered<PlayerController>()) return null;
    final current = Get.find<PlayerController>().currentRoom;
    if (current?.hasIdentity(platform: platform, roomId: roomId) == true) return current;
    return null;
  }

  @override
  Future<LiveRoom> getRoomDetailForRefresh({required String platform, required String roomId}) async {
    try {
      // The room page is normally available anonymously. Start with that one
      // request; bootstrap/register a device once and retry only when the site
      // actually requires a session for this network.
      return await _loadRoom(roomId, includePlaybackData: false, ensureSession: false);
    } catch (_) {
      return _loadRoom(roomId, includePlaybackData: false, ensureSession: true);
    }
  }

  @override
  Future<LiveRoom> getRoomDetailForRecording({required String platform, required String roomId}) async {
    final loaded = await _loadRoom(roomId, includePlaybackData: true, ensureSession: true);
    if (loaded.isLiveNow) return loaded;

    // Recommendation cards can represent a replay whose room page reports
    // offline. Preserve only a matching card with an actual playable stream;
    // transport/shape failures above still propagate to the recorder retry
    // policy instead of masquerading as offline.
    final current = _matchingCurrentRoom(platform: platform, roomId: roomId);
    if (current != null && parsePlayQualities(current.data).isNotEmpty) {
      return current.copyWith(status: true, liveStatus: LiveStatus.live, isRecord: true);
    }
    return loaded;
  }

  Future<LiveRoom> _loadRoom(String roomId, {required bool includePlaybackData, required bool ensureSession}) async {
    final url = "https://live.kuaishou.com/u/$roomId";
    if (ensureSession) await _ensureSession(url);
    final resultText = await HttpClient.instance.getText(url, queryParameters: const {}, header: _roomHeaders());
    final text = RegExp(r"window\.__INITIAL_STATE__=(.*?);", multiLine: false).firstMatch(resultText)?.group(1);
    if (text == null || text.isEmpty) throw const FormatException('Kuaishou initial state is missing');
    final jsonObj = jsonDecode(text.replaceAll("undefined", "null"));
    final playList = jsonObj["liveroom"]?["playList"];
    if (playList is! List || playList.isEmpty) throw const FormatException('Kuaishou room metadata is missing');
    final room = playList.first;
    if (room is! Map) throw const FormatException('Kuaishou room metadata has an invalid shape');
    final liveStream = room["liveStream"] is Map ? room["liveStream"] as Map : const <dynamic, dynamic>{};
    final author = room["author"] is Map ? room["author"] as Map : const <dynamic, dynamic>{};
    final gameInfo = room["gameInfo"] is Map ? room["gameInfo"] as Map : const <dynamic, dynamic>{};
    final rawLiveState = room['isLiving'];
    final live = rawLiveState == true || rawLiveState == 1 || rawLiveState?.toString().toLowerCase() == 'true';
    final description = author["description"]?.toString() ?? '';
    return LiveRoom(
      cover: isImage(liveStream['poster']) ? liveStream['poster'].toString() : '${liveStream['poster'].toString()}.jpg',
      watching: live ? gameInfo["watchingCount"].toString() : '0',
      onlineViewers: live ? gameInfo["watchingCount"].toString() : '0',
      audienceMetricType: AudienceMetricType.onlineViewers,
      roomId: author["id"]?.toString() ?? roomId,
      area: gameInfo["name"]?.toString() ?? '',
      title: description.replaceAll("\n", " "),
      nick: author["name"]?.toString() ?? '',
      avatar: author["avatar"]?.toString() ?? '',
      introduction: description,
      notice: description,
      status: live,
      liveStatus: live ? LiveStatus.live : LiveStatus.offline,
      platform: Sites.kuaishouSite,
      link: liveStream["id"]?.toString() ?? '',
      data: includePlaybackData ? liveStream["playUrls"] : null,
    );
  }

  Map<String, dynamic> _roomHeaders() {
    final result = Map<String, dynamic>.from(headers);
    final fakeUseragent = FakeUserAgent.getRandomUserAgent();
    result['User-Agent'] = fakeUseragent['userAgent'];
    result['sec-ch-ua'] = 'Google Chrome;v=${fakeUseragent['v']}, Chromium;v=${fakeUseragent['v']}, Not=A?Brand;v=24';
    result['sec-ch-ua-platform'] = fakeUseragent['device'];
    result['sec-fetch-dest'] = 'document';
    result['sec-fetch-mode'] = 'navigate';
    result['sec-fetch-site'] = 'same-origin';
    result['sec-fetch-user'] = '?1';
    result['accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9';
    final configuredCookie = SettingsService.to.cookieManager.kuaishouCookie.v.trim();
    final effectiveCookie = configuredCookie.isNotEmpty ? configuredCookie : cookie;
    if (effectiveCookie.isNotEmpty) result['cookie'] = effectiveCookie;
    return result;
  }

  Future<void> _ensureSession(String url) async {
    if (SettingsService.to.cookieManager.kuaishouCookie.v.trim().isNotEmpty) return;
    final updatedAt = _sessionUpdatedAt;
    if (cookie.isNotEmpty && updatedAt != null && DateTime.now().difference(updatedAt) < _sessionLifetime) return;
    final pending = _sessionBootstrap;
    if (pending != null) return pending;

    late final Future<void> operation;
    operation =
        (() async {
          await getCookie(url);
          _sessionUpdatedAt = DateTime.now();
          try {
            await registerDid(requestHeaders: _roomHeaders());
          } catch (_) {
            // Device telemetry is best-effort and must not hold up room metadata.
          }
        })().whenComplete(() {
          if (identical(_sessionBootstrap, operation)) _sessionBootstrap = null;
        });
    _sessionBootstrap = operation;
    return operation;
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
    final room = await getRoomDetailForRefresh(platform: platform, roomId: roomId);
    return room.isLiveNow;
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({required String roomId}) {
    //尚不支持
    return Future.value([]);
  }
}
