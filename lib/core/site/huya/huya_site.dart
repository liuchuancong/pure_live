import 'dart:math';
import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:pure_live/common/index.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:pure_live/core/tars/types.dart';
import 'package:pure_live/core/common/log.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:pure_live/plugins/race_http.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/model/live_anchor_item.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:pure_live/core/danmaku/huya_danmaku.dart';
import 'package:pure_live/common/utils/githup_mirror.dart';
import 'package:pure_live/pkg/tars/net/base_tars_http.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
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
  final Map<String, Future<String>> _tokenCache = {};
  static String? playUserAgent;

  // ignore: constant_identifier_names
  static const String HYSDK_UA = HuyaRequestParams.hysdkUa;
  static const String fallbackPlayUserAgent = HuyaRequestParams.kUserAgent;
  static Map<String, String> requestHeaders = {'Origin': baseUrl, 'Referer': baseUrl, 'User-Agent': HYSDK_UA};
  final BaseTarsHttp tupClient = BaseTarsHttp("http://wup.huya.com", "liveui", headers: requestHeaders);

  static ({String popularity, String onlineViewers}) parseRoomAudience(Map<String, dynamic>? liveData) {
    final totalCount = liveData?['totalCount']?.toString().trim() ?? '';
    final userCount = liveData?['userCount']?.toString().trim() ?? '';
    return (popularity: totalCount.isNotEmpty ? totalCount : userCount, onlineViewers: '');
  }

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    List<LiveCategory> categories = [
      LiveCategory(id: "1", name: "网游", children: []),
      LiveCategory(id: "2", name: "单机", children: []),
      LiveCategory(id: "8", name: "娱乐", children: []),
      LiveCategory(id: "3", name: "手游", children: []),
    ];
    for (var item in categories) {
      var items = await getSubCategores(item);
      item.children.addAll(items);
    }
    return categories;
  }

  final String kUserAgent =
      "Mozilla/5.0 (Linux; Android 11; Pixel 5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.91 Mobile Safari/537.36 Edg/117.0.0.0";

  Future<List<LiveArea>> getSubCategores(LiveCategory liveCategory) async {
    var result = await HttpClient.instance.getJson(
      "https://live.cdn.huya.com/liveconfig/game/bussLive",
      queryParameters: {"bussType": liveCategory.id},
    );
    List<LiveArea> subs = [];
    for (var item in result["data"]) {
      var gid = (item["gid"])?.toInt().toString();
      var subCategory = LiveArea(
        areaId: gid!,
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
    var resultText = await HttpClient.instance.getJson(
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
    var result = json.decode(resultText);
    var items = <LiveRoom>[];
    for (var item in result["data"]["datas"]) {
      var cover = item["screenshot"].toString();
      if (!cover.contains("?")) {
        cover += "?x-oss-process=style/w338_h190&";
      }
      var title = item["introduction"]?.toString() ?? "";
      if (title.isEmpty) {
        title = item["roomName"]?.toString() ?? "";
      }
      var roomItem = LiveRoom(
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
    if (data is! HuyaUrlDataModel) return Future.value(const <LivePlayQuality>[]);
    return Future.value(parsePlayQualities(data));
  }

  @visibleForTesting
  static List<LivePlayQuality> parsePlayQualities(HuyaUrlDataModel data) {
    final rates = data.bitRates.isEmpty ? <HuyaBitRateModel>[HuyaBitRateModel(name: '原画', bitRate: 0)] : data.bitRates;
    final unique = <int, HuyaBitRateModel>{};
    for (final rate in rates) {
      if (rate.bitRate < 0 || rate.name.trim().isEmpty) continue;
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
    if (data is! Map) return const <String>[];
    final bitRate = int.tryParse(data['bitRate']?.toString() ?? '');
    final rawLines = data['urls'];
    if (bitRate == null || rawLines is! List) return const <String>[];
    final urls = <String>[];
    for (final line in rawLines.whereType<HuyaLineModel>()) {
      final url = await getPlayUrl(line, bitRate);
      if (url.isNotEmpty && !urls.contains(url)) urls.add(url);
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
    final url = await getPlayUrl(line, bitRate);
    return LivePlayUrlResolution(
      urls: url.isEmpty ? const <String>[] : <String>[url],
      appliedQualityData: quality.selectionId,
    );
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
    var antiCode = line.lineType == HuyaLineType.hls ? line.hlsAntiCode.trim() : line.flvAntiCode.trim();
    if (antiCode.isEmpty && line.lineType == HuyaLineType.flv) {
      antiCode = await getCndTokenInfoEx(line.streamName);
    }
    if (antiCode.isEmpty) {
      final protocol = line.lineType == HuyaLineType.hls ? 'HLS' : 'FLV';
      throw StateError('Huya $protocol token is unavailable');
    }
    antiCode = buildAntiCode(line.streamName, line.presenterUid, antiCode);
    final extension = line.lineType == HuyaLineType.hls ? 'm3u8' : 'flv';
    final cdnBase = secureHuyaCdnBase(line.line);
    if (!RegExp(r'(^|&)codec=').hasMatch(antiCode)) antiCode = '$antiCode&codec=264';
    antiCode = replaceQueryParameter(antiCode, 'ratio', bitRate > 0 ? '$bitRate' : null);
    return '$cdnBase/${line.streamName}.$extension?$antiCode';
  }

  @visibleForTesting
  static String replaceQueryParameter(String query, String key, String? value) {
    final output = <String>[];
    var replaced = false;
    for (final segment in query.split('&')) {
      if (segment.isEmpty) continue;
      final separator = segment.indexOf('=');
      final segmentKey = separator < 0 ? segment : segment.substring(0, separator);
      if (segmentKey != key) {
        output.add(segment);
        continue;
      }
      if (!replaced && value != null) output.add('$key=$value');
      replaced = true;
    }
    if (!replaced && value != null) output.add('$key=$value');
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
      var resultText = await HttpClient.instance.getJson(
        "https://www.huya.com/cache.php",
        queryParameters: {"m": "LiveList", "do": "getLiveListByPage", "tagAll": 0, "page": page},
        header: {
          "user-agent": kUserAgent,
          "Cookie": SettingsService.to.cookieManager.huyaCookie.v,
          "Origin": "https://www.huya.com",
          "Referer": "https://www.huya.com/",
        },
      );
      var result = json.decode(resultText);
      var items = <LiveRoom>[];
      for (var item in result["data"]["datas"]) {
        var cover = item["screenshot"].toString();
        if (!cover.contains("?")) {
          cover += "?x-oss-process=style/w338_h190&";
        }
        var title = item["introduction"]?.toString() ?? "";
        if (title.isEmpty) {
          title = item["roomName"]?.toString() ?? "";
        }
        var roomItem = LiveRoom(
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
      final roomData = RegExp(
        r'var\s+TT_ROOM_DATA\s*=\s*(\{[\s\S]*?\})',
        multiLine: false,
      ).firstMatch(resultText)?.group(1);
      final streamData = RegExp(r'stream:\s*(\{[\s\S]*?\n\s*\})', multiLine: false).firstMatch(resultText)?.group(1);
      if (roomData == null || streamData == null) {
        throw const FormatException('Huya room page does not contain room/stream data');
      }
      final roomDataJson = json.decode(roomData) as Map<String, dynamic>;
      final streamJson = json.decode(streamData) as Map<String, dynamic>;
      final streamDataJson = streamJson['data'][0];
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
          danmakuData: HuyaDanmakuArgs(ayyuid: uid, topSid: 0, subSid: 0),
        );
      }
      final streamDataGameStreamInfo = streamDataJson['gameStreamInfoList'][0];
      if (streamDataGameStreamInfo is! Map) {
        throw const FormatException('Huya gameStreamInfoList is unavailable');
      }
      final topSid = int.tryParse(streamDataGameStreamInfo['lChannelId'].toString()) ?? 0;
      final subSid = int.tryParse(streamDataGameStreamInfo['lSubChannelId'].toString()) ?? 0;
      final huyaLines = <HuyaLineModel>[];
      const lineTypes = {'sFlvUrl': HuyaLineType.flv, 'sHlsUrl': HuyaLineType.hls};
      final lines = streamDataJson['gameStreamInfoList'];
      if (lines is! List) {
        throw const FormatException('Huya gameStreamInfoList is unavailable');
      }
      for (final item in lines) {
        if (item is! Map) continue;
        lineTypes.forEach((key, type) {
          final url = item[key]?.toString() ?? '';
          if (url.isNotEmpty) {
            huyaLines.add(
              HuyaLineModel(
                line: url,
                lineType: type,
                flvAntiCode: item['sFlvAntiCode']?.toString() ?? '',
                hlsAntiCode: item['sHlsAntiCode']?.toString() ?? '',
                streamName: item['sStreamName']?.toString() ?? '',
                cdnType: item['sCdnType']?.toString() ?? '',
                presenterUid: topSid,
              ),
            );
          }
        });
      }
      final huyaBitRates = <HuyaBitRateModel>[];
      final biterates = streamJson['vMultiStreamInfo'];
      if (biterates is List) {
        for (final item in biterates) {
          if (item is! Map) continue;
          final name = item['sDisplayName']?.toString() ?? '';
          if (name.contains('HDR')) continue;
          final bitRate = int.tryParse(item['iBitRate']?.toString() ?? '');
          if (bitRate == null || name.isEmpty) continue;
          huyaBitRates.add(HuyaBitRateModel(bitRate: bitRate, name: name));
        }
      }
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
          uid: uid.toString(),
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
    if (raw is! List) return const <HuyaBitRateModel>[];
    final result = <HuyaBitRateModel>[];
    final seen = <int>{};
    for (final item in raw.whereType<Map>()) {
      final name = item['sDisplayName']?.toString().trim() ?? '';
      final bitRate = int.tryParse(item['iBitRate']?.toString() ?? '');
      if (name.isEmpty || bitRate == null || bitRate < 0 || !seen.add(bitRate)) continue;
      result.add(HuyaBitRateModel(bitRate: bitRate, name: name));
    }
    return result;
  }

  @override
  Future<LiveRoom> getRoomDetailForRefresh({required String platform, required String roomId}) async {
    final resultText = await HttpClient.instance.getText(
      'https://mp.huya.com/cache.php?m=Live&do=profileRoom&roomid=$roomId&showSecret=1',
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
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) async {
    final effectivePageSize = pageSize.clamp(1, 50);
    var resultText = await HttpClient.instance.getJson(
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
    var result = json.decode(resultText);
    var items = <LiveRoom>[];
    var queryList = result["response"]["3"]["docs"] ?? [];
    var responseList = result["response"]["1"]["docs"] ?? [];
    for (var item in queryList) {
      var cover = item["game_screenshot"].toString();
      if (!cover.contains("?")) {
        cover += "?x-oss-process=style/w338_h190&";
      }
      var title = item["game_introduction"]?.toString() ?? "";
      if (title.isEmpty) {
        title = item["game_roomName"]?.toString() ?? "";
      }
      var roomId = findRoomId(responseList, item['uid'], item['yyid']);
      var roomItem = LiveRoom(
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
    var resultText = await HttpClient.instance.getJson(
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
    var result = json.decode(resultText);
    var items = <LiveAnchorItem>[];
    for (var item in result["response"]["1"]["docs"]) {
      var anchorItem = LiveAnchorItem(
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
      final jsonString = RegExp(
        r'var\s+TT_ROOM_DATA\s*=\s*(\{[\s\S]*?\})',
        multiLine: false,
      ).firstMatch(resultText)?.group(1);
      if (jsonString == null) {
        return false;
      }
      final roomData = json.decode(jsonString) as Map<String, dynamic>;
      return roomData['state'] == 'ON' && roomData['isReplay'] == false;
    } catch (e) {
      CoreLog.error('Huya getLiveStatus failed: $e');
      return false;
    }
  }

  Future<String> getAnonymousUid() async {
    var result = await HttpClient.instance.postJson(
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

  String getUUid(String cookie, String streamName) {
    return getUid(cookie, streamName).toString();
  }

  int getUid(String cookie, String streamName) {
    try {
      if (cookie.contains('yyuid=')) {
        final match = RegExp(r'yyuid=(\d+)').firstMatch(cookie);
        if (match != null && match.groupCount >= 1) {
          return int.parse(match.group(1)!);
        }
      }
      final parts = streamName.split('-');
      if (parts.isNotEmpty) {
        final anchorUid = int.tryParse(parts[0]);
        if (anchorUid != null && anchorUid > 0) {
          return anchorUid;
        }
      }
    } catch (e) {
      debugPrint('An error occurred: $e');
    }
    final random = Random();
    return 1400000000000 + random.nextInt(100000000000);
  }

  String processAnticode(String anticode, String streamName) {
    var query = Uri.splitQueryString(anticode);
    final uid = int.parse(getUUid(SettingsService.to.cookieManager.huyaCookie.v, streamName));
    query["ctype"] = "huya_live";
    query["t"] = "100";
    final convertUid = (uid << 8 | uid >> 24) & 0xFFFFFFFF;
    final wsTime = query["wsTime"]!;
    final seqId = (DateTime.now().millisecondsSinceEpoch + uid).toString();
    int ct = ((int.parse(wsTime, radix: 16) + Random().nextDouble()) * 1000).toInt();
    final fm = utf8.decode(base64.decode(Uri.decodeComponent(query['fm']!)));
    final wsSecretPrefix = fm.split('_').first;
    final wsSecretHash = md5.convert(utf8.encode('$seqId|${query["ctype"]}|${query["t"]}')).toString();
    final wsSecret = md5
        .convert(utf8.encode('${wsSecretPrefix}_${convertUid}_${streamName}_${wsSecretHash}_$wsTime'))
        .toString();
    tz.initializeTimeZones();
    final location = tz.getLocation('Asia/Shanghai');
    final now = tz.TZDateTime.now(location);
    final formatter = DateFormat('yyyyMMddHH');
    final formatted = formatter.format(now);
    DateFormat timeStampFormat = DateFormat("yyyy-MM-dd_HH:mm:ss.SSS");
    String formattedDate = timeStampFormat.format(now);
    return Uri(
      queryParameters: {
        "wsSecret": wsSecret,
        "wsTime": wsTime,
        "seqid": seqId,
        "ctype": query["ctype"]!,
        "ver": "1",
        "fs": query["fs"]!,
        "t": query["t"]!,
        "u": convertUid.toString(),
        "uuid": (((ct % 1e10 + Random().nextDouble()) * 1e3).toInt() & 0xFFFFFFFF).toString(),
        "sdk_sid": DateTime.now().millisecondsSinceEpoch.toString(),
        "codec": "264",
        "sv": formatted,
        "dMod": "mseh-0",
        "sdkPcdn": "1_1",
        "a_block": "0",
        "timeStamp": formattedDate,
      },
    ).query;
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({required String roomId}) async {
    List<LiveSuperChatMessage> ls = [];
    LiveRoom detail = await getRoomDetail(roomId: roomId, platform: Sites.huyaSite);
    HuyaDanmakuArgs args = detail.danmakuData as HuyaDanmakuArgs;
    if (args.topSid != 0) {
      ls = await getHuyaSuperChatMessageList(lPid: args.topSid, first: true);
    }
    return ls;
  }

  String buildAntiCode(String stream, int presenterUid, String antiCode, {DateTime? now}) {
    final mapAnti = Uri(query: antiCode).queryParametersAll;
    final encodedFm = mapAnti['fm']?.firstOrNull?.trim() ?? '';
    if (encodedFm.isEmpty) {
      return antiCode;
    }
    final ctype = mapAnti['ctype']?.firstOrNull?.trim().isNotEmpty == true
        ? mapAnti['ctype']!.first.trim()
        : 'huya_live';
    final platformId = mapAnti['t']?.firstOrNull?.trim().isNotEmpty == true ? mapAnti['t']!.first.trim() : '100';
    final isWap = platformId == '103';
    final timestamp = now ?? DateTime.now();
    final currentMillis = timestamp.millisecondsSinceEpoch;
    final currentSeconds = currentMillis ~/ 1000;
    final uid = presenterUid > 0 ? presenterUid : getUid(SettingsService.to.cookieManager.huyaCookie.v, stream);
    var wsTimeSeconds = int.tryParse(mapAnti['wsTime']?.firstOrNull ?? '', radix: 16);
    if (wsTimeSeconds == null || wsTimeSeconds < currentSeconds + const Duration(minutes: 20).inSeconds) {
      wsTimeSeconds = currentSeconds + const Duration(days: 1).inSeconds;
    }
    final wsTime = wsTimeSeconds.toRadixString(16);
    final seqId = uid + currentMillis;
    final secretHash = md5.convert(utf8.encode('$seqId|$ctype|$platformId')).toString();
    final convertUid = rotl64(uid);
    final calcUid = isWap ? uid : convertUid;
    final secretPrefix = utf8.decode(base64.decode(base64.normalize(Uri.decodeComponent(encodedFm)))).split('_').first;
    final secretStr = '${secretPrefix}_${calcUid}_${stream}_${secretHash}_$wsTime';
    final wsSecret = md5.convert(utf8.encode(secretStr)).toString();
    final rnd = Random();
    final ct = ((wsTimeSeconds + rnd.nextDouble()) * 1000).toInt();
    final uuid = (((ct % 1e10) + rnd.nextDouble()) * 1e3 % 0xffffffff).toInt().toString();
    final antiCodeRes = <String, String>{
      'wsSecret': wsSecret,
      'wsTime': wsTime,
      'seqid': seqId.toString(),
      'ctype': ctype,
      'ver': '1',
      'fs': mapAnti['fs']?.firstOrNull ?? 'bgct',
      'fm': Uri.encodeComponent(encodedFm),
      't': platformId,
    };
    if (isWap) {
      antiCodeRes.addAll({'uid': uid.toString(), 'uuid': uuid});
    } else {
      antiCodeRes['u'] = convertUid.toString();
    }
    return antiCodeRes.entries.map((e) => '${e.key}=${e.value}').join('&');
  }

  Future<String> getCndTokenInfoEx(String stream) {
    return _tokenCache.putIfAbsent(stream, () async {
      var func = "getCdnTokenInfoEx";
      var tid = HuyaUserId();
      tid.sHuYaUA = "pc_exe&7060000&official";
      var tReq = GetCdnTokenExReq();
      tReq.tId = tid;
      tReq.sStreamName = stream;
      var resp = await tupClient.tupRequest(func, tReq, GetCdnTokenExResp());
      return resp.sFlvToken;
    });
  }

  int rotl64(int t) {
    final low = t & 0xFFFFFFFF;
    final rotatedLow = ((low << 8) | (low >> 24)) & 0xFFFFFFFF;
    final high = t & ~0xFFFFFFFF;
    return high | rotatedLow;
  }

  Future<List<LiveSuperChatMessage>> getHuyaSuperChatMessageList({required int lPid, bool first = false}) async {
    final BaseTarsHttp messageBoardClient = BaseTarsHttp(
      "http://wup.huya.com",
      "wupui",
      headers: HuyaRequestParams.requestHeaders,
    );
    var userId = HuyaUserId()..sHuYaUA = HuyaRequestParams.hysdkUa;
    var req = GetGameEventMessageBoardReq()
      ..lPid = lPid
      ..tId = userId
      ..iMessageBoardScope = 0
      ..iPageSize = 10;
    var rsp = await messageBoardClient.tupRequest("getHeadLineMessageBoard", req, GetGameEventMessageBoardRsp());
    final now = DateTime.now();
    final List<LiveSuperChatMessage> messages = [];
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
    } else {
      return [messages.last];
    }
  }
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
    return 'HuyaLineModel{line: $line, flvAntiCode: $flvAntiCode, hlsAntiCode: $hlsAntiCode, streamName: $streamName, lineType: $lineType, presenterUid: $presenterUid}';
  }
}

class HuyaBitRateModel {
  final String name;
  final int bitRate;

  HuyaBitRateModel({required this.bitRate, required this.name});
}
