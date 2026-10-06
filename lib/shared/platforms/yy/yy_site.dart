import 'dart:convert';

import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/models/live_category.dart';
import 'package:pure_live/core/logging/core_log.dart';
import 'package:pure_live/core/models/live_anchor_item.dart';
import 'package:pure_live/shared/platforms/yy/yy_danmaku.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/shared/platforms/live_site.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/core/utils/live_quality_label.dart';
import 'package:pure_live/shared/platforms/current_live_room.dart';
import 'package:pure_live/core/config/cookie_settings_controller.dart';
import 'package:pure_live/core/consts/platform_ids.dart';
import 'package:pure_live/shared/platforms/live_external_room.dart';

class YYSite implements LiveSite, LiveSiteRoomRefresher, LiveSiteRecordRoomResolver, LiveSiteExternalRoomResolver {
  @override
  RoomExternalTarget? externalRoomTarget(LiveRoom liveroom) {
    final id = sanitizedExternalRoomId(liveroom.roomId);
    if (id == null) return null;
    final path = Uri.encodeComponent(id);
    if (!RegExp(r'^[0-9]+$').hasMatch(id)) return null;
    return RoomExternalTarget(web: 'https://www.yy.com/$path');
  }

  static const String _streamSdkVersion = '5.23.0-beta.2';
  static const String _mobileHlsPrefix = 'mobile-hls:';
  static const List<String> _mobileHlsRates = <String>['1200', '4000'];

  @override
  String id = PlatformIds.yy;

  @override
  String name = 'YY 直播';

  @override
  LiveDanmaku getDanmaku() => YyDanmaku();

  /// ============================================================
  /// Headers
  /// ============================================================

  Map<String, String> getHeaders() {
    final cookie = CookieSettingsController.to.yyCookie.v.trim();
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
        platform: PlatformIds.yy,
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
          title: _title(item['desc']),
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
          platform: PlatformIds.yy,
        ),
      );
    }

    return items;
  }

  /// ============================================================
  /// ============================================================

  ({String cid, String sid}) _channelIds(LiveRoom liveroom) {
    final danmakuArgs = liveroom.danmakuData;
    if (danmakuArgs is YyDanmakuArgs && danmakuArgs.topSid > 0) {
      return (cid: danmakuArgs.topSid.toString(), sid: danmakuArgs.subSid.toString());
    }
    final roomId = liveroom.roomId?.trim() ?? '';
    return (cid: roomId, sid: roomId);
  }

  Future<Map<String, dynamic>> getLiveStreamObj({required LiveRoom liveroom, required String qn}) async {
    final sequence = DateTime.now().millisecondsSinceEpoch;
    final channel = _channelIds(liveroom);
    final cid = channel.sid;
    final sid = channel.sid;
    final body = jsonEncode({
      'head': {
        'seq': sequence,
        'appidstr': '0',
        'bidstr': '121',
        'cidstr': cid,
        'sidstr': sid,
        'uid64': 0,
        'client_type': 108,
        'client_ver': _streamSdkVersion,
        'stream_sys_ver': 1,
        'app': 'yylive_web',
        'playersdk_ver': _streamSdkVersion,
        'thundersdk_ver': '0',
        'streamsdk_ver': _streamSdkVersion,
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
        'send_time': sequence ~/ 1000,
        'line_seq': -1,
        'gear': int.parse(qn),
        'ssl': 1,
        'stream_format': 0,
      },
    });

    final query = {'uid': '0', 'cid': cid, 'sid': sid, 'appid': '0', 'sequence': sequence.toString(), 'encode': 'json'};

    final result = await HttpClient.instance.postJson(
      'https://stream-manager.yy.com/v3/channel/streams',
      queryParameters: query,
      data: utf8.encode(body),
      header: {
        ...getHeaders(),
        // YY's current web SDK sends this JSON-shaped body as text/plain.
        // Some protected channels reject application/json before evaluating
        // the otherwise identical request.
        'Content-Type': 'text/plain;charset=UTF-8',
        'Referer': 'https://www.yy.com/${channel.cid}/${channel.sid}',
      },
    );

    return decode(result);
  }

  @visibleForTesting
  static Map<String, dynamic>? parseMobileHlsPayload(String payload) {
    final source = payload.trim();
    final jsonStart = source.indexOf('{');
    final jsonEnd = source.lastIndexOf('}');
    if (jsonStart < 0 || jsonEnd < jsonStart) return null;
    try {
      final value = json.decode(source.substring(jsonStart, jsonEnd + 1));
      if (value is! Map || _asInt(value['code']) != 0) return null;
      final url = value['hls']?.toString().trim() ?? '';
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme || !const {'http', 'https'}.contains(uri.scheme)) return null;
      return Map<String, dynamic>.from(value);
    } catch (error) {
      CoreLog.w('YY mobile HLS payload is invalid: $error');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getMobileHlsStream({required LiveRoom liveroom, required String rate}) async {
    final channel = _channelIds(liveroom);
    final response = await HttpClient.instance.getText(
      'https://interface.yy.com/hls/new/get/${channel.cid}/${channel.sid}/$rate',
      queryParameters: const {'source': 'wapyy', 'callback': ''},
      header: {
        ...getHeaders(),
        'Referer': 'https://wap.yy.com/mobileweb/${channel.cid}/${channel.sid}',
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
            'AppleWebKit/605.1.15 Version/17.0 Mobile/15E148 Safari/604.1',
      },
    );
    return parseMobileHlsPayload(response);
  }

  Future<List<LivePlayQuality>> _getMobileHlsQualities({required LiveRoom liveroom}) async {
    final responses = await Future.wait(
      _mobileHlsRates.map((rate) async {
        try {
          return (rate: rate, payload: await _getMobileHlsStream(liveroom: liveroom, rate: rate));
        } catch (error) {
          CoreLog.w('YY mobile HLS quality $rate failed: $error');
          return (rate: rate, payload: null);
        }
      }),
    );

    final byStream = <String, LivePlayQuality>{};
    for (final response in responses) {
      final payload = response.payload;
      if (payload == null) continue;
      final width = _asInt(payload['width']) ?? 0;
      final height = _asInt(payload['height']) ?? 0;
      final shortEdge = width > 0 && height > 0 ? (width < height ? width : height) : 0;
      final streamKey = payload['video']?.toString().trim();
      final identity = streamKey?.isNotEmpty == true ? streamKey! : '${width}x$height';
      final rate = int.tryParse(response.rate) ?? 0;
      final tier = response.rate == _mobileHlsRates.first ? '流畅' : '高清';
      final resolution = shortEdge > 0 ? ' · ${shortEdge}p' : '';
      // The endpoint may map several requested rates to the same actual
      // source. Keep only the highest request for that source so the picker
      // never shows duplicate buttons that play identical content.
      byStream[identity] = LivePlayQuality(
        quality: '$tier$resolution',
        id: '$_mobileHlsPrefix${response.rate}',
        sort: rate,
        data: '$_mobileHlsPrefix${response.rate}',
      );
    }
    final qualities = byStream.values.toList(growable: false);
    qualities.sort((left, right) => right.sort.compareTo(left.sort));
    return qualities;
  }

  /// ============================================================
  /// ============================================================

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom liveroom}) async {
    try {
      final qualities = parsePlayQualities(await getLiveStreamObj(liveroom: liveroom, qn: '1'));
      if (qualities.isNotEmpty) return qualities;
      CoreLog.w('YY stream manager returned no qualities; using the mobile HLS source.');
    } catch (error) {
      // Certain official YY channels reject the HTTP StreamManager route with
      // ErrAuthNotPass while the anonymous mobile HLS route remains playable.
      CoreLog.w('YY stream manager failed; using the mobile HLS source: $error');
    }
    return _getMobileHlsQualities(liveroom: liveroom);
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
            quality: LiveQualityLabel.normalize(
              platform: PlatformIds.yy,
              rawLabel: nameCounts[record.name] == 1 ? record.name : '${record.name} · ${record.gear}',
              id: record.gear,
              bitrate: record.rate > 0 ? record.rate * 1000 : null,
            ),
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
  /// ============================================================

  @override
  Future<List<String>> getPlayUrls({required LiveRoom liveroom, required LivePlayQuality quality}) async {
    final qn = quality.data?.toString() ?? '';

    if (qn.isEmpty) {
      return [];
    }

    if (qn.startsWith(_mobileHlsPrefix)) {
      final rate = qn.substring(_mobileHlsPrefix.length);
      final payload = await _getMobileHlsStream(liveroom: liveroom, rate: rate);
      final url = payload?['hls']?.toString().trim() ?? '';
      return url.isEmpty ? const <String>[] : <String>[url];
    }

    try {
      final urls = parsePlayUrls(await getLiveStreamObj(liveroom: liveroom, qn: qn));
      if (urls.isNotEmpty) return urls;
    } catch (error) {
      CoreLog.w('YY stream URL request failed; retrying through mobile HLS: $error');
    }
    final fallbackRate = quality.sort >= 2000 ? _mobileHlsRates.last : _mobileHlsRates.first;
    final payload = await _getMobileHlsStream(liveroom: liveroom, rate: fallbackRate);
    final url = payload?['hls']?.toString().trim() ?? '';
    return url.isEmpty ? const <String>[] : <String>[url];
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
      final area = areaNameForBiz(biz);
      items.add(
        LiveRoom(
          roomId: item['sid']?.toString() ?? '',
          title: _title(item['desc']),
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
          platform: PlatformIds.yy,
        ),
      );
    }

    return items;
  }

  /// ============================================================
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

    return map[biz] ?? presetBizAreaNames[biz] ?? '';
  }

  static const Map<String, String> presetBizAreaNames = {
    'sing': '音乐',
    'talk': '脱口秀',
    'dance': '舞蹈',
    'red': '户外',
    'pretty': '颜值',
    'mc': '喊麦',
    'sport': '体育',
    'car': '二次元',
    'game': '王者荣耀',
    'zonghe': '综合',
  };

  static String _title(Object? value) {
    final text = value?.toString() ?? '';
    if (!text.endsWith(_liveTitleSuffix)) return text;
    return text.substring(0, text.length - _liveTitleSuffix.length).trim();
  }

  static const String _liveTitleSuffix = '正在直播';

  String areaNameForBiz(String biz) => bizAreaNameMap[biz] ?? presetBizAreaNames[biz] ?? biz;

  /// ============================================================
  /// ============================================================

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    final fresh = await _resolveDetail(liveroom);
    // Pad response gaps from the room the caller already holds. fillFromDetail
    // covers nick/avatar/area; the cover is padded explicitly because a blank
    // cover is the most visible symptom of a partial profile response.
    final padded = fresh.fillFromDetail(liveroom);
    final existingCover = liveroom.cover ?? '';
    if ((padded.cover == null || padded.cover!.isEmpty) && existingCover.isNotEmpty) {
      return padded.copyWith(cover: existingCover);
    }
    return padded;
  }

  Future<LiveRoom> _resolveDetail(LiveRoom liveroom) async {
    final roomId = liveroom.roomId ?? '';
    final platform = liveroom.platform ?? '';
    try {
      return await _fetchRoomDetail(
        liveroom: LiveRoom(roomId: roomId, platform: platform),
      );
    } catch (e) {
      CoreLog.error(e);
      final currentRoom = CurrentLiveRoom.value;
      if (currentRoom?.hasSameIdentity(LiveRoom(roomId: roomId, platform: platform)) == true) {
        return currentRoom!.getLiveRoomWithError();
      }
      return LiveRoom(roomId: roomId, platform: platform).getLiveRoomWithError();
    }
  }

  /// ============================================================
  /// ============================================================

  @override
  Future<LiveRoom> getRoomDetailForRefresh(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return _fetchRoomDetail(liveroom: liveroom);
  }

  @override
  Future<LiveRoom> getRoomDetailForRecording(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return _fetchRoomDetail(liveroom: liveroom);
  }

  Future<LiveRoom> _fetchRoomDetail({required LiveRoom liveroom}) async {
    final roomId = liveroom.roomId ?? '';
    final platform = liveroom.platform ?? '';
    final response = decode(
      await HttpClient.instance.getJson(
        'https://www.yy.com/api/liveInfoDetail/$roomId/$roomId/0',
        header: getHeaders(),
      ),
    );
    final resultCode = response is Map ? int.tryParse(response['resultCode']?.toString() ?? '') : null;
    if (response is! Map || resultCode != 0) {
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
      title: _title(item['desc']),
      cover: validImgUrl(item['thumb2']?.toString() ?? ''),
      nick: item['name']?.toString() ?? '',
      userId: item['uid']?.toString() ?? '',
      watching: item['users']?.toString() ?? '',
      popularity: item['users']?.toString() ?? '',
      audienceMetricType: AudienceMetricType.popularity,
      avatar: validImgUrl(item['avatar']?.toString() ?? ''),
      area: areaNameForBiz(biz),
      liveStatus: LiveStatus.live,
      status: true,
      platform: PlatformIds.yy,
      danmakuData: YyDanmakuArgs(topSid: topSid, subSid: subSid),
      link: 'https://www.yy.com/$roomId',
    );
  }

  /// ============================================================
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
          title: _title(item['channelName']),
          cover: validImgUrl(item['posterurl']?.toString() ?? ''),
          nick: item['name']?.toString() ?? '',
          userId: item['uid']?.toString() ?? '',
          watching: users,
          popularity: users,
          audienceMetricType: AudienceMetricType.popularity,
          avatar: validImgUrl(item['headurl']?.toString() ?? ''),
          area: areaNameForBiz(item['biz']?.toString() ?? ''),
          liveStatus: isLive ? LiveStatus.live : LiveStatus.offline,
          status: isLive,
          platform: PlatformIds.yy,
          link: 'https://www.yy.com/$roomId',
        ),
      );
    }

    return items;
  }

  /// ============================================================
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
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({required LiveRoom liveroom}) {
    return Future.value([]);
  }
}
