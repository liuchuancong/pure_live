import 'dart:math';
import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/log.dart';
import 'package:pure_live/core/tars/types.dart';
import 'package:pure_live/plugins/race_http.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/model/live_anchor_item.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/danmaku/huya_danmaku.dart';
import 'package:pure_live/common/utils/githup_mirror.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/pkg/tars/net/base_tars_http.dart';
import 'package:pure_live/core/utils/live_quality_label.dart';
import 'package:pure_live/core/tars/get_cdn_token_ex_req.dart';
import 'package:pure_live/core/tars/get_cdn_token_ex_resp.dart';
import 'package:pure_live/core/site/huya/huya_request_params.dart';
import 'package:pure_live/core/tars/get_game_event_message_board_req.dart';
import 'package:pure_live/core/tars/get_game_event_message_board_rsp.dart';
import 'package:pure_live/modules/live_play/controllers/player_controller.dart';

class HuyaSite implements LiveSite, LiveSiteRoomRefresher, LiveSiteRecordRoomResolver, LivePlayUrlCursorResolver {
  @override
  String id = Sites.huyaSite;

  static const baseUrl = HuyaRequestParams.baseUrl;

  @override
  String name = "虎牙直播";

  @override
  LiveDanmaku getDanmaku() => HuyaDanmaku();

  final Map<String, _HuyaTokenCacheEntry> _tokenCache = {};

  final Map<String, Future<String>> _tokenRequests = {};

  static const Duration _tokenCacheDuration = Duration(minutes: 2);

  static String? playUserAgent;

  static const String huyaSdkUa = HuyaRequestParams.hysdkUa;

  static const String fallbackPlayUserAgent = HuyaRequestParams.kUserAgent;

  static Map<String, String> requestHeaders = {'Origin': baseUrl, 'Referer': baseUrl, 'User-Agent': huyaSdkUa};

  final BaseTarsHttp tupClient = BaseTarsHttp("http://wup.huya.com", "liveui", headers: requestHeaders);

  static ({String popularity, String onlineViewers}) parseRoomAudience(Map<String, dynamic>? liveData) {
    final totalCount = liveData?['totalCount']?.toString().trim() ?? '';
    final userCount = liveData?['userCount']?.toString().trim() ?? '';

    return (popularity: totalCount.isNotEmpty ? totalCount : userCount, onlineViewers: '');
  }

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    final categories = <LiveCategory>[
      LiveCategory(id: "1", name: "网游", children: []),
      LiveCategory(id: "2", name: "单机", children: []),
      LiveCategory(id: "8", name: "娱乐", children: []),
      LiveCategory(id: "3", name: "手游", children: []),
    ];

    for (final item in categories) {
      final items = await getSubCategores(item);
      item.children.addAll(items);
    }

    return categories;
  }

  final String kUserAgent =
      "Mozilla/5.0 (Linux; Android 11; Pixel 5) "
      "AppleWebKit/537.36 (KHTML, like Gecko) "
      "Chrome/90.0.4430.91 "
      "Mobile Safari/537.36 "
      "Edg/117.0.0.0";

  Future<List<LiveArea>> getSubCategores(LiveCategory liveCategory) async {
    final result = await HttpClient.instance.getJson(
      "https://live.cdn.huya.com/liveconfig/game/bussLive",
      queryParameters: {"bussType": liveCategory.id},
    );

    final subs = <LiveArea>[];

    for (final item in result["data"]) {
      var gid = "";

      if (item["gid"] is Map) {
        gid = item["gid"]["value"].toString().split(",").first;
      } else if (item["gid"] is double) {
        gid = item["gid"].toInt().toString();
      } else if (item["gid"] is int) {
        gid = item["gid"].toString();
      } else {
        gid = item["gid"].toString();
      }

      final subCategory = LiveArea(
        areaId: gid,
        areaName: item["gameFullName"].toString(),
        areaType: liveCategory.id,
        platform: Sites.huyaSite,
        areaPic: "https://huyaimg.msstatic.com/cdnimage/game/$gid-MS.jpg",
        typeName: liveCategory.name,
      );

      subs.add(subCategory);
    }

    return subs;
  }

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    final resultText = await HttpClient.instance.getJson(
      "https://www.huya.com/cache.php",
      queryParameters: {
        "m": "LiveList",
        "do": "getLiveListByPage",
        "tagAll": 0,
        "gameId": category.areaId,
        "page": page,
      },
      header: {"user-agent": kUserAgent, "Cookie": SettingsService.to.cookieManager.huyaCookie.v},
    );

    final result = json.decode(resultText);

    final items = <LiveRoom>[];

    for (final item in result["data"]["datas"]) {
      var cover = item["screenshot"].toString();

      if (!cover.contains("?")) {
        cover += "?x-oss-process=style/w338_h190&";
      }

      var title = item["introduction"]?.toString() ?? "";

      if (title.isEmpty) {
        title = item["roomName"]?.toString() ?? "";
      }

      final roomItem = LiveRoom(
        roomId: item["profileRoom"].toString(),
        title: title,
        cover: cover,
        nick: item["nick"].toString(),
        watching: item["totalCount"].toString(),
        popularity: item["totalCount"].toString(),
        audienceMetricType: AudienceMetricType.popularity,
        avatar: item["avatar180"],
        area: item["gameFullName"].toString(),
        liveStatus: LiveStatus.live,
        status: true,
        platform: Sites.huyaSite,
      );

      items.add(roomItem);
    }

    return items;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) {
    final data = detail.data;

    if (data is! HuyaUrlDataModel) {
      return Future.value(const <LivePlayQuality>[]);
    }

    return Future.value(parsePlayQualities(data));
  }

  @visibleForTesting
  static List<LivePlayQuality> parsePlayQualities(HuyaUrlDataModel data) {
    final rates = data.bitRates.isEmpty ? <HuyaBitRateModel>[HuyaBitRateModel(name: '原画', bitRate: 0)] : data.bitRates;

    final unique = <int, HuyaBitRateModel>{};

    for (final rate in rates) {
      if (rate.bitRate < 0 || rate.name.trim().isEmpty) {
        continue;
      }

      unique.putIfAbsent(rate.bitRate, () => rate);
    }

    final qualities = unique.values
        .map(
          (rate) => LivePlayQuality(
            quality: LiveQualityLabel.normalize(
              platform: Sites.huyaSite,
              rawLabel: rate.name,
              id: rate.bitRate,
              bitrate: rate.bitRate > 0 ? rate.bitRate * 1000 : null,
            ),
            id: rate.bitRate,
            sort: rate.bitRate == 0 ? 1 << 30 : rate.bitRate,
            data: <String, Object>{'urls': List<HuyaLineModel>.unmodifiable(data.lines), 'bitRate': rate.bitRate},
          ),
        )
        .toList(growable: false);

    qualities.sort((left, right) => right.sort.compareTo(left.sort));

    return qualities;
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    final data = quality.data;

    if (data is! Map) {
      return const <String>[];
    }

    final bitRate = int.tryParse(data['bitRate']?.toString() ?? '');

    final rawLines = data['urls'];

    if (bitRate == null || rawLines is! List) {
      return const <String>[];
    }

    final urls = <String>[];

    for (final line in rawLines.whereType<HuyaLineModel>()) {
      try {
        final url = await getPlayUrl(line, bitRate);

        if (url.isNotEmpty && !urls.contains(url)) {
          urls.add(url);
        }
      } catch (e, stackTrace) {
        CoreLog.error('Huya getPlayUrl failed: $e');
        CoreLog.error(stackTrace.toString());
      }
    }

    return urls;
  }

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlAtRaw({
    required LiveRoom detail,
    required LivePlayQuality quality,
    required int lineIndex,
  }) async {
    final data = quality.data;

    final bitRate = data is Map ? int.tryParse(data['bitRate']?.toString() ?? '') : null;

    final rawLines = data is Map ? data['urls'] : null;

    if (bitRate == null || rawLines is! List || lineIndex < 0 || lineIndex >= rawLines.length) {
      return LivePlayUrlResolution(urls: const <String>[], appliedQualityData: quality.selectionId);
    }

    final line = rawLines[lineIndex];

    if (line is! HuyaLineModel) {
      return LivePlayUrlResolution(urls: const <String>[], appliedQualityData: quality.selectionId);
    }

    try {
      final url = await getPlayUrl(line, bitRate);

      return LivePlayUrlResolution(
        urls: url.isEmpty ? const <String>[] : <String>[url],
        appliedQualityData: quality.selectionId,
      );
    } catch (e, stackTrace) {
      CoreLog.error('Huya resolvePlayUrlAtRaw failed: $e');
      CoreLog.error(stackTrace.toString());

      return LivePlayUrlResolution(urls: const <String>[], appliedQualityData: quality.selectionId);
    }
  }

  Future<String> getHuYaUA() async {
    if (playUserAgent != null) {
      return playUserAgent!;
    }

    final mirror = GitHubMirror(owner: 'liuchuancong', repo: 'pure_live', branch: 'master');

    final urls = mirror.mirrors('assets/play_config.json');

    final data = await RaceHttp.fetchJson(urls);

    final ua = data?['huya']?['user_agent']?.toString().trim();

    playUserAgent = ua == null || ua.isEmpty ? fallbackPlayUserAgent : ua;

    Log.d("HuyaSite: getHuYaUA: $playUserAgent");

    return playUserAgent!;
  }

  Future<String> getPlayUrl(HuyaLineModel line, int bitRate) async {
    final suffix = line.lineType == HuyaLineType.hls ? "m3u8" : "flv";

    var antiCode = await getCndTokenInfoEx(line.streamName);

    antiCode = buildAntiCode(line.streamName, line.presenterUid, antiCode);

    var url =
        '${line.line}/${line.streamName}.$suffix'
        '?$antiCode'
        '&codec=264';

    if (bitRate > 0) {
      url += '&ratio=$bitRate';
    }

    return url;
  }

  @visibleForTesting
  static String replaceQueryParameter(String query, String key, String? value) {
    final output = <String>[];
    var replaced = false;

    for (final segment in query.split('&')) {
      if (segment.isEmpty) {
        continue;
      }

      final separator = segment.indexOf('=');

      final segmentKey = separator < 0 ? segment : segment.substring(0, separator);

      if (segmentKey != key) {
        output.add(segment);
        continue;
      }

      if (!replaced && value != null) {
        output.add('$key=$value');
      }

      replaced = true;
    }

    if (!replaced && value != null) {
      output.add('$key=$value');
    }

    return output.join('&');
  }

  static String secureHuyaCdnBase(String base) {
    final uri = Uri.tryParse(base);

    if (uri == null || uri.scheme != 'http' || !(uri.host == 'huya.com' || uri.host.endsWith('.huya.com'))) {
      return base;
    }

    return uri.replace(scheme: 'https').toString();
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    try {
      final resultText = await HttpClient.instance.getJson(
        "https://www.huya.com/cache.php",
        queryParameters: {"m": "LiveList", "do": "getLiveListByPage", "tagAll": 0, "page": page},
        header: {
          "user-agent": kUserAgent,
          "Cookie": SettingsService.to.cookieManager.huyaCookie.v,
          "Origin": "https://www.huya.com",
          "Referer": "https://www.huya.com/",
        },
      );

      final result = json.decode(resultText);

      final items = <LiveRoom>[];

      for (final item in result["data"]["datas"]) {
        var cover = item["screenshot"].toString();

        if (!cover.contains("?")) {
          cover += "?x-oss-process=style/w338_h190&";
        }

        var title = item["introduction"]?.toString() ?? "";

        if (title.isEmpty) {
          title = item["roomName"]?.toString() ?? "";
        }

        final roomItem = LiveRoom(
          roomId: item["profileRoom"].toString(),
          title: title,
          cover: cover,
          area: item["gameFullName"].toString(),
          nick: item["nick"].toString(),
          avatar: item["avatar180"],
          watching: item["totalCount"].toString(),
          popularity: item["totalCount"].toString(),
          audienceMetricType: AudienceMetricType.popularity,
          platform: Sites.huyaSite,
          liveStatus: LiveStatus.live,
          status: true,
        );

        items.add(roomItem);
      }

      return items;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<LiveRoom> getRoomDetail({required String platform, required String roomId}) {
    return _loadRoomDetail(platform: platform, roomId: roomId, allowUiFallback: true);
  }

  @override
  Future<LiveRoom> getRoomDetailForRecording({required String platform, required String roomId}) {
    return _loadRoomDetail(platform: platform, roomId: roomId, allowUiFallback: false);
  }

  Future<LiveRoom> _loadRoomDetail({
    required String platform,
    required String roomId,
    required bool allowUiFallback,
  }) async {
    try {
      final resultText = await HttpClient.instance.getText(
        '$baseUrl/$roomId',
        queryParameters: const {},
        header: {
          'Accept': '*/*',
          'Origin': 'https://www.huya.com',
          'Referer': 'https://www.huya.com/',
          'Sec-Fetch-Dest': 'empty',
          'Sec-Fetch-Mode': 'cors',
          'Sec-Fetch-Site': 'same-origin',
          'user-agent': kUserAgent,
          'Cookie': SettingsService.to.cookieManager.huyaCookie.v,
        },
      );

      final roomData = _extractJsonObject(resultText, 'var TT_ROOM_DATA');

      final streamData = _extractJsonObject(resultText, 'stream:');

      if (roomData == null || streamData == null) {
        throw const FormatException('Huya room page does not contain room/stream data');
      }

      final roomDataJson = json.decode(roomData) as Map<String, dynamic>;

      final streamJson = json.decode(streamData) as Map<String, dynamic>;

      final streamDataList = streamJson['data'];

      if (streamDataList is! List || streamDataList.isEmpty) {
        throw const FormatException('Huya stream data is unavailable');
      }

      final streamDataJson = streamDataList[0];

      if (streamDataJson is! Map) {
        throw const FormatException('Huya stream data format is invalid');
      }

      final streamDataGameLiveInfo = streamDataJson['gameLiveInfo'];

      if (streamDataGameLiveInfo is! Map) {
        throw const FormatException('Huya gameLiveInfo is unavailable');
      }

      final state = roomDataJson['state']?.toString().trim().toUpperCase() ?? '';

      final isReplay = roomDataJson['isReplay'] == true;

      final isLive = state == 'ON' && !isReplay;

      final title = streamDataGameLiveInfo['introduction']?.toString() ?? '';

      final cover = streamDataGameLiveInfo['screenshot']?.toString() ?? '';

      final nick = streamDataGameLiveInfo['nick']?.toString() ?? '';

      final avatar = streamDataGameLiveInfo['avatar180']?.toString() ?? '';

      final popularity = streamDataGameLiveInfo['totalCount']?.toString() ?? '';

      final uid = int.tryParse(streamDataGameLiveInfo['uid']?.toString() ?? '') ?? 0;

      final streamList = streamDataJson['gameStreamInfoList'];

      if (streamList is! List || streamList.isEmpty) {
        throw const FormatException('Huya gameStreamInfoList is unavailable');
      }

      final firstStream = streamList.first;

      if (firstStream is! Map) {
        throw const FormatException('Huya gameStreamInfoList is invalid');
      }

      final topSid = int.tryParse(firstStream['lChannelId']?.toString() ?? '') ?? 0;

      final subSid = int.tryParse(firstStream['lSubChannelId']?.toString() ?? '') ?? 0;

      if (!isLive) {
        return LiveRoom(
          cover: cover,
          watching: popularity,
          onlineViewers: '',
          popularity: popularity,
          audienceMetricType: AudienceMetricType.popularity,
          roomId: roomId,
          area: streamDataGameLiveInfo['gameName']?.toString() ?? '',
          title: title,
          nick: nick,
          avatar: avatar,
          introduction: title,
          notice: streamDataGameLiveInfo['introduction']?.toString() ?? '',
          isRecord: isReplay,
          status: false,
          liveStatus: LiveStatus.offline,
          platform: platform,
          link: 'https://www.huya.com/$roomId',
          danmakuData: HuyaDanmakuArgs(ayyuid: uid, topSid: topSid, subSid: subSid),
        );
      }

      final huyaLines = <HuyaLineModel>[];

      const lineTypes = {'sFlvUrl': HuyaLineType.flv, 'sHlsUrl': HuyaLineType.hls};

      final lines = streamDataJson['gameStreamInfoList'];

      for (final item in lines) {
        lineTypes.forEach((key, type) {
          final url = item[key]?.toString() ?? '';

          if (url.isNotEmpty) {
            huyaLines.add(
              HuyaLineModel(
                line: url,
                lineType: type,
                flvAntiCode: item['sFlvAntiCode'].toString(),
                hlsAntiCode: item['sHlsAntiCode'].toString(),
                streamName: item['sStreamName'].toString(),
                cdnType: item['sCdnType'].toString(),
                presenterUid: topSid,
              ),
            );
          }
        });
      }

      final huyaBitRates = parseBitRates(streamJson['vMultiStreamInfo']);

      final liveData = <String, dynamic>{
        'gid': streamDataGameLiveInfo['gid'],
        'gameFullName': streamDataGameLiveInfo['gameFullName'],
        'screenshot': cover,
        'introduction': title,
        'totalCount': popularity,
        'userCount': streamDataGameLiveInfo['userCount'],
      };

      final audience = parseRoomAudience(liveData);

      final isXingxiu = streamDataGameLiveInfo['gid']?.toString() == '1663';

      return LiveRoom(
        cover: cover,
        watching: audience.popularity,
        onlineViewers: audience.onlineViewers,
        popularity: audience.popularity,
        audienceMetricType: AudienceMetricType.popularity,
        roomId: roomId,
        area: streamDataGameLiveInfo['gameFullName']?.toString() ?? '',
        title: title,
        nick: nick,
        avatar: avatar,
        introduction: title,
        notice: streamDataGameLiveInfo['introduction']?.toString() ?? '',
        isRecord: false,
        status: true,
        liveStatus: LiveStatus.live,
        platform: platform,
        data: HuyaUrlDataModel(
          url: '',
          lines: huyaLines,
          bitRates: huyaBitRates,
          uid: getUidString(t: 13, e: 10),
          isXingxiu: isXingxiu,
        ),
        danmakuData: HuyaDanmakuArgs(ayyuid: uid, topSid: topSid, subSid: subSid),
        link: 'https://www.huya.com/$roomId',
      );
    } catch (e, stackTrace) {
      CoreLog.error('Huya room detail failed: $e');

      CoreLog.error(stackTrace.toString());

      if (!allowUiFallback) {
        throw const FormatException('Huya room playback metadata is unavailable');
      }

      if (Get.isRegistered<PlayerController>()) {
        final playerController = Get.find<PlayerController>();

        final currentRoom = playerController.currentRoom;

        if (currentRoom?.hasIdentity(platform: platform, roomId: roomId) == true) {
          return currentRoom!.getLiveRoomWithError();
        }
      }

      return LiveRoom(roomId: roomId, platform: platform).getLiveRoomWithError();
    }
  }

  @visibleForTesting
  static bool isExplicitOfflineState(Object? value) {
    final normalized = value?.toString().trim().toUpperCase() ?? '';

    return const {'OFF', 'OFFLINE', 'CLOSED'}.contains(normalized);
  }

  @visibleForTesting
  static List<HuyaBitRateModel> parseBitRates(dynamic raw) {
    if (raw is! List) {
      return const <HuyaBitRateModel>[];
    }

    final result = <HuyaBitRateModel>[];

    final seen = <int>{};

    for (final item in raw.whereType<Map>()) {
      final name = item['sDisplayName']?.toString().trim() ?? '';

      final bitRate = int.tryParse(item['iBitRate']?.toString() ?? '');

      if (name.isEmpty || bitRate == null || bitRate < 0 || name.contains('HDR') || !seen.add(bitRate)) {
        continue;
      }

      result.add(HuyaBitRateModel(bitRate: bitRate, name: name));
    }

    return result;
  }

  @override
  Future<LiveRoom> getRoomDetailForRefresh({required String platform, required String roomId}) async {
    final resultText = await HttpClient.instance.getText(
      'https://mp.huya.com/cache.php?'
      'm=Live&do=profileRoom'
      '&roomid=$roomId'
      '&showSecret=1',
      header: {
        'Accept': '*/*',
        'Origin': 'https://www.huya.com',
        'Referer': 'https://www.huya.com/',
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'same-site',
        'user-agent': kUserAgent,
        'Cookie': SettingsService.to.cookieManager.huyaCookie.v,
      },
    );

    final decoded = json.decode(resultText);

    final statusCode = decoded is Map ? int.tryParse(decoded['status']?.toString() ?? '') : null;

    if (decoded is! Map || statusCode != 200 || decoded['data'] is! Map) {
      throw const FormatException('Huya room metadata is unavailable');
    }

    final data = decoded['data'] as Map;

    final liveData = data['liveData'] is Map ? Map<String, dynamic>.from(data['liveData'] as Map) : <String, dynamic>{};

    final profile = data['profileInfo'] is Map ? data['profileInfo'] as Map : const <dynamic, dynamic>{};

    final audience = parseRoomAudience(liveData);

    final state = data['liveStatus']?.toString().trim().toUpperCase() ?? '';

    final live = state == 'ON' || state == 'REPLAY';

    return LiveRoom(
      cover: liveData['screenshot']?.toString() ?? '',
      watching: audience.popularity,
      popularity: audience.popularity,
      onlineViewers: audience.onlineViewers,
      audienceMetricType: AudienceMetricType.popularity,
      roomId: roomId,
      area: liveData['gameFullName']?.toString() ?? '',
      title: liveData['introduction']?.toString() ?? '',
      nick: profile['nick']?.toString() ?? '',
      avatar: profile['avatar180']?.toString() ?? '',
      introduction: liveData['introduction']?.toString() ?? '',
      notice: data['welcomeText']?.toString() ?? '',
      isRecord: state == 'REPLAY',
      status: live,
      liveStatus: live ? LiveStatus.live : LiveStatus.offline,
      platform: Sites.huyaSite,
      link: 'https://www.huya.com/$roomId',
    );
  }

  String? findRoomId(List list, int targetUid, int targetYyid) {
    try {
      final matchingObject = list.firstWhere(
        (item) => item['uid'] == targetUid && item['yyid'] == targetYyid,
        orElse: () => throw StateError("No matching object found"),
      );

      return matchingObject["room_id"].toString();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) async {
    final effectivePageSize = pageSize.clamp(1, 50);

    final resultText = await HttpClient.instance.getJson(
      "https://search.cdn.huya.com/",
      queryParameters: {
        "m": "Search",
        "do": "getSearchContent",
        "q": keyword,
        "uid": 0,
        "v": 4,
        "typ": -5,
        "livestate": 0,
        "rows": effectivePageSize,
        "start": (page - 1) * effectivePageSize,
      },
    );

    final result = json.decode(resultText);

    final items = <LiveRoom>[];

    final queryList = result["response"]["3"]["docs"] ?? [];

    final responseList = result["response"]["1"]["docs"] ?? [];

    for (final item in queryList) {
      var cover = item["game_screenshot"].toString();

      if (!cover.contains("?")) {
        cover += "?x-oss-process=style/w338_h190&";
      }

      var title = item["game_introduction"]?.toString() ?? "";

      if (title.isEmpty) {
        title = item["game_roomName"]?.toString() ?? "";
      }

      final roomId = findRoomId(responseList, item['uid'], item['yyid']);

      final roomItem = LiveRoom(
        roomId: roomId ?? item["room_id"].toString(),
        title: title,
        cover: cover,
        userId: item["yyid"].toString(),
        nick: item["game_nick"].toString(),
        area: item["gameName"].toString(),
        status: true,
        liveStatus: LiveStatus.live,
        avatar: item["game_imgUrl"].toString(),
        watching: item["game_total_count"].toString(),
        popularity: item["game_total_count"].toString(),
        audienceMetricType: AudienceMetricType.popularity,
        platform: Sites.huyaSite,
      );

      items.add(roomItem);
    }

    return items;
  }

  @override
  Future<List<LiveAnchorItem>> searchAnchors(String keyword, {int page = 1, int pageSize = 30}) async {
    final resultText = await HttpClient.instance.getJson(
      "https://search.cdn.huya.com/",
      queryParameters: {
        "m": "Search",
        "do": "getSearchContent",
        "q": keyword,
        "uid": 0,
        "v": 1,
        "typ": -5,
        "livestate": 0,
        "rows": pageSize,
        "start": (page - 1) * pageSize,
      },
    );

    final result = json.decode(resultText);

    final items = <LiveAnchorItem>[];

    for (final item in result["response"]["1"]["docs"]) {
      final anchorItem = LiveAnchorItem(
        roomId: item["room_id"].toString(),
        avatar: item["game_avatarUrl180"].toString(),
        userName: item["game_nick"].toString(),
        liveStatus: item["gameLiveOn"],
      );

      items.add(anchorItem);
    }

    return items;
  }

  @override
  Future<bool> getLiveStatus({required String platform, required String roomId}) async {
    try {
      final resultText = await HttpClient.instance.getText(
        '$baseUrl/$roomId',
        queryParameters: const {},
        header: {
          'Accept': '*/*',
          'Origin': 'https://www.huya.com',
          'Referer': 'https://www.huya.com/',
          'user-agent': kUserAgent,
          'Cookie': SettingsService.to.cookieManager.huyaCookie.v,
        },
      );

      final jsonString = _extractJsonObject(resultText, 'var TT_ROOM_DATA');

      if (jsonString == null) {
        return false;
      }

      final roomData = json.decode(jsonString) as Map<String, dynamic>;

      final state = roomData['state']?.toString().trim().toUpperCase() ?? '';

      final isReplay = roomData['isReplay'] == true;

      return state == 'ON' && !isReplay;
    } catch (e) {
      CoreLog.error('Huya getLiveStatus failed: $e');

      return false;
    }
  }

  Future<String> getAnonymousUid() async {
    final result = await HttpClient.instance.postJson(
      "https://udblgn.huya.com/web/anonymousLogin",
      data: {"appId": 5002, "byPass": 3, "context": "", "version": "2.4", "data": {}},
      header: {
        "user-agent": kUserAgent,
        'Accept': '*/*',
        'Origin': 'https://www.huya.com',
        'Referer': 'https://www.huya.com/',
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'same-site',
      },
    );

    return result["data"]["uid"].toString();
  }

  String getUidString({int? t, int? e}) {
    final n = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz".split("");

    final o = List.filled(36, '');

    if (t != null) {
      for (var i = 0; i < t; i++) {
        o[i] = n[Random().nextInt(e ?? n.length)];
      }
    } else {
      o[8] = o[13] = o[18] = o[23] = "-";
      o[14] = "4";

      for (var i = 0; i < 36; i++) {
        if (o[i].isEmpty) {
          final r = Random().nextInt(16);

          o[i] = n[19 == i ? 3 & r | 8 : r];
        }
      }
    }

    return o.join("");
  }

  String buildAntiCode(String stream, int presenterUid, String antiCode) {
    final mapAnti = Uri(query: antiCode).queryParametersAll;

    if (!mapAnti.containsKey('fm')) {
      return antiCode;
    }

    final ctype = mapAnti['ctype']?.first ?? 'huya_pc_exe';

    final platformId = int.tryParse(mapAnti['t']?.first ?? '0') ?? 0;

    final isWap = platformId == 103;

    final calcStartTime = DateTime.now().millisecondsSinceEpoch;

    final seqId = presenterUid + calcStartTime;

    final secretHash = md5.convert(utf8.encode('$seqId|$ctype|$platformId')).toString();

    final convertUid = rotl64(presenterUid);

    final calcUid = isWap ? presenterUid : convertUid;

    final fm = Uri.decodeComponent(mapAnti['fm']!.first);

    final secretPrefix = utf8.decode(base64.decode(fm)).split('_').first;

    final wsTime = mapAnti['wsTime']!.first;

    final secretStr = '${secretPrefix}_${calcUid}_${stream}_${secretHash}_$wsTime';

    final wsSecret = md5.convert(utf8.encode(secretStr)).toString();

    final rnd = Random();

    final ct = ((int.parse(wsTime, radix: 16) + rnd.nextDouble()) * 1000).toInt();

    final uuid = (((ct % 1e10) + rnd.nextDouble()) * 1e3 % 0xffffffff).toInt().toString();

    final antiCodeRes = <String, dynamic>{
      'wsSecret': wsSecret,
      'wsTime': wsTime,
      'seqid': seqId,
      'ctype': ctype,
      'ver': '1',
      'fs': mapAnti['fs']!.first,
      'fm': fm,
      't': platformId,
    };

    if (isWap) {
      antiCodeRes.addAll({'uid': presenterUid, 'uuid': uuid});
    } else {
      antiCodeRes['u'] = convertUid;
    }

    return antiCodeRes.entries.map((e) => '${e.key}=${e.value}').join('&');
  }

  Future<String> getCndTokenInfoEx(String stream) async {
    final cached = _tokenCache[stream];

    if (cached != null && !cached.isExpired) {
      return cached.token;
    }

    final pending = _tokenRequests[stream];

    if (pending != null) {
      return pending;
    }

    final request = _requestHuyaToken(stream);

    _tokenRequests[stream] = request;

    try {
      return await request;
    } finally {
      if (identical(_tokenRequests[stream], request)) {
        _tokenRequests.remove(stream);
      }
    }
  }

  Future<String> _requestHuyaToken(String stream) async {
    final func = "getCdnTokenInfoEx";

    final tid = HuyaUserId()..sHuYaUA = "pc_exe&7060000&official";

    final req = GetCdnTokenExReq()
      ..tId = tid
      ..sStreamName = stream;

    final resp = await tupClient.tupRequest(func, req, GetCdnTokenExResp());

    final token = resp.sFlvToken;

    if (token.isEmpty) {
      throw StateError('Huya CDN token is empty');
    }

    _tokenCache[stream] = _HuyaTokenCacheEntry(token: token, expiresAt: DateTime.now().add(_tokenCacheDuration));

    return token;
  }

  void clearTokenCache([String? stream]) {
    if (stream == null) {
      _tokenCache.clear();
      return;
    }

    _tokenCache.remove(stream);
  }

  void clearAllTokenCache() {
    _tokenCache.clear();
    _tokenRequests.clear();
  }

  int rotl64(int t) {
    final low = t & 0xFFFFFFFF;

    final rotatedLow = ((low << 8) | (low >> 24)) & 0xFFFFFFFF;

    final high = t & ~0xFFFFFFFF;

    return high | rotatedLow;
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({required String roomId}) async {
    var ls = <LiveSuperChatMessage>[];

    final detail = await getRoomDetail(roomId: roomId, platform: Sites.huyaSite);

    final args = detail.danmakuData as HuyaDanmakuArgs;

    if (args.topSid != 0) {
      ls = await getHuyaSuperChatMessageList(lPid: args.topSid, first: true);
    }

    return ls;
  }

  Future<List<LiveSuperChatMessage>> getHuyaSuperChatMessageList({required int lPid, bool first = false}) async {
    final messageBoardClient = BaseTarsHttp("http://wup.huya.com", "wupui", headers: HuyaRequestParams.requestHeaders);

    final userId = HuyaUserId()..sHuYaUA = HuyaRequestParams.hysdkUa;

    final req = GetGameEventMessageBoardReq()
      ..lPid = lPid
      ..tId = userId
      ..iMessageBoardScope = 0
      ..iPageSize = 10;

    final rsp = await messageBoardClient.tupRequest("getHeadLineMessageBoard", req, GetGameEventMessageBoardRsp());

    final now = DateTime.now();

    final messages = <LiveSuperChatMessage>[];

    for (final item in rsp.tMessageBoardPanel.vGameEventMessageBoardInfo) {
      final content = item.sContent.trim();

      if (content.isEmpty) {
        continue;
      }

      final remainSec = item.iCountDown > 0 ? item.iCountDown : item.iTotalSec;

      if (remainSec <= 0) {
        continue;
      }

      final totalSeconds = item.iTotalSec > 0 ? item.iTotalSec : remainSec;

      var price = item.iCost;

      if (price <= 0 && item.iCostPay > 0) {
        price = max(1, (item.iCostPay / 100).round());
      }

      final endTime = now.add(Duration(seconds: remainSec));

      final startTime = endTime.subtract(Duration(seconds: totalSeconds));

      final message = LiveSuperChatMessage(
        backgroundBottomColor: "#246488",
        backgroundColor: "#ffffff",
        endTime: endTime,
        face: item.tMessageUser.sAvatar,
        message: content,
        price: price,
        startTime: startTime,
        userName: item.tMessageUser.sNick.trim(),
      );

      messages.add(message);
    }

    if (first) {
      return messages;
    }

    if (messages.isEmpty) {
      return const [];
    }

    return [messages.last];
  }

  String? _extractJsonObject(String text, String marker) {
    final markerIndex = text.indexOf(marker);

    if (markerIndex == -1) {
      return null;
    }

    final start = text.indexOf('{', markerIndex);

    if (start == -1) {
      return null;
    }

    var depth = 0;
    var inString = false;
    var escaped = false;

    for (var i = start; i < text.length; i++) {
      final char = text[i];

      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char == r'\') {
          escaped = true;
        } else if (char == '"') {
          inString = false;
        }

        continue;
      }

      if (char == '"') {
        inString = true;
        continue;
      }

      if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;

        if (depth == 0) {
          return text.substring(start, i + 1);
        }
      }
    }

    return null;
  }
}

class _HuyaTokenCacheEntry {
  final String token;
  final DateTime expiresAt;

  const _HuyaTokenCacheEntry({required this.token, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class HuyaUrlDataModel {
  final String url;
  final String uid;

  List<HuyaLineModel> lines;
  List<HuyaBitRateModel> bitRates;

  final bool isXingxiu;

  HuyaUrlDataModel({
    required this.bitRates,
    required this.lines,
    required this.url,
    required this.uid,
    required this.isXingxiu,
  });
}

enum HuyaLineType { flv, hls }

class HuyaLineModel {
  final String line;
  final String cdnType;
  final String flvAntiCode;
  final String hlsAntiCode;
  final String streamName;
  final HuyaLineType lineType;
  final int presenterUid;

  int bitRate;

  HuyaLineModel({
    required this.line,
    required this.lineType,
    required this.flvAntiCode,
    required this.hlsAntiCode,
    required this.streamName,
    required this.cdnType,
    required this.presenterUid,
    this.bitRate = 0,
  });

  @override
  String toString() {
    return 'HuyaLineModel{'
        'line: $line, '
        'flvAntiCode: $flvAntiCode, '
        'hlsAntiCode: $hlsAntiCode, '
        'streamName: $streamName, '
        'lineType: $lineType, '
        'presenterUid: $presenterUid'
        '}';
  }
}

class HuyaBitRateModel {
  final String name;
  final int bitRate;

  HuyaBitRateModel({required this.bitRate, required this.name});
}
