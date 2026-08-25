import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/model/live_anchor_item.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/common/convert_helper.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/danmaku/bilibili_danmaku.dart';
import 'package:pure_live/modules/live_play/controllers/player_controller.dart';

class BiliBiliSite implements LiveSite, LiveSiteRoomRefresher, LivePlayUrlResolver {
  @override
  String id = Sites.bilibiliSite;

  @override
  String name = "哔哩哔哩直播";
  String get cookie => SettingsService.to.cookieManager.bilibiliCookie.v;
  int get userId => SettingsService.to.cookieManager.bilibiliUid.v;
  @override
  LiveDanmaku getDanmaku() => BiliBiliDanmaku();

  static const String kDefaultUserAgent =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36";
  static const String kDefaultReferer = "https://live.bilibili.com/";

  static String buvid3 = "";
  static String buvid4 = "";
  static Future<Map>? _buvidRequest;
  String accessId = "";

  Future<Map<String, String>> getHeader() async {
    final storedCookie = cookie;
    final cookieBuvid3 = RegExp(r'(?:^|;)\s*buvid3=([^;]+)').firstMatch(storedCookie)?.group(1) ?? '';
    final cookieBuvid4 = RegExp(r'(?:^|;)\s*buvid4=([^;]+)').firstMatch(storedCookie)?.group(1) ?? '';
    if (cookieBuvid3.isNotEmpty) {
      buvid3 = cookieBuvid3;
      buvid4 = cookieBuvid4;
    }
    if (buvid3.isEmpty) {
      final request = _buvidRequest ??= getBuvid();
      try {
        final buvidInfo = await request;
        buvid3 = buvidInfo["b_3"]?.toString() ?? "";
        buvid4 = buvidInfo["b_4"]?.toString() ?? "";
      } finally {
        if (identical(_buvidRequest, request)) _buvidRequest = null;
      }
    }
    return storedCookie.isEmpty
        ? {"user-agent": kDefaultUserAgent, "referer": kDefaultReferer, "cookie": 'buvid3=$buvid3;buvid4=$buvid4;'}
        : {
            "cookie": storedCookie.contains("buvid3") ? storedCookie : "$storedCookie;buvid3=$buvid3;buvid4=$buvid4;",
            "user-agent": kDefaultUserAgent,
            "referer": kDefaultReferer,
          };
  }

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    try {
      List<LiveCategory> categories = [];
      var result = await HttpClient.instance.getJson(
        "https://api.live.bilibili.com/room/v1/Area/getList",
        queryParameters: {"need_entrance": 1, "parent_id": 0},
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
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    try {
      const baseUrl = "https://api.live.bilibili.com/xlive/web-interface/v1/second/getList";
      var url =
          "$baseUrl?platform=web&parent_area_id=${category.areaType}&area_id=${category.areaId}&sort_type=online&page=$page&w_webid=${await getAccessId()}";

      var queryParams = await getWbiSign(url);
      var result = await HttpClient.instance.getJson(baseUrl, queryParameters: queryParams, header: await getHeader());
      if (result["code"] == -352) {
        throw Exception(result);
      }
      var items = <LiveRoom>[];
      for (var item in result["data"]["list"]) {
        var roomItem = LiveRoom(
          roomId: item["roomid"].toString(),
          title: item["title"].toString(),
          cover: "${item["cover"]}@400w.jpg",
          nick: item["uname"].toString(),
          avatar: item["face"].toString(),
          watching: item["online"].toString(),
          popularity: item["online"].toString(),
          audienceMetricType: AudienceMetricType.popularity,
          liveStatus: LiveStatus.live,
          area: item["area_name"].toString(),
          status: true,
          platform: Sites.bilibiliSite,
        );
        items.add(roomItem);
      }
      return sortRoomsByPopularity(items);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    final result = await _requestPlayInfo(detail: detail, qualityData: 0);
    return parsePlayQualities(result);
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    return (await resolvePlayUrlsRaw(detail: detail, quality: quality)).urls;
  }

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsRaw({required LiveRoom detail, required LivePlayQuality quality}) async {
    try {
      final result = await _requestPlayInfo(detail: detail, qualityData: quality.data);

      return parsePlayUrlResolution(result, requestedQualityData: quality.data);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<dynamic> _requestPlayInfo({required LiveRoom detail, required Object? qualityData}) async {
    return HttpClient.instance.getJson(
      "https://api.live.bilibili.com/xlive/web-room/v2/index/getRoomPlayInfo",
      queryParameters: {
        "room_id": detail.roomId,
        "protocol": "0,1",
        "format": "0,1,2",
        "codec": "0",
        "qn": qualityData ?? 0,
        "platform": "web",
        "ptype": "8",
        "dolby": "5",
        "panorama": "1",
        "mask": "0",
        "no_playurl": "0",
      },
      header: await getHeader(),
    );
  }

  /// Extracts only qualities accepted by at least one returned codec. The
  /// global descriptor list also contains unavailable tiers and previously
  /// produced buttons which could never resolve to a stream.
  static List<LivePlayQuality> parsePlayQualities(dynamic response) {
    final playUrl = _playUrlPayload(response);
    final descriptions = <int, String>{};
    for (final raw in (playUrl['g_qn_desc'] as List?) ?? const []) {
      if (raw is! Map) continue;
      final qn = int.tryParse(raw['qn']?.toString() ?? '');
      if (qn == null || qn <= 0) continue;
      final description = raw['desc']?.toString().trim() ?? '';
      descriptions[qn] = description.isEmpty ? '未知清晰度' : description;
    }

    final accepted = <int>{};
    for (final payload in _codecPayloads(playUrl)) {
      for (final rawQn in (payload.codec['accept_qn'] as List?) ?? const []) {
        final qn = int.tryParse(rawQn.toString());
        if (qn != null && qn > 0) accepted.add(qn);
      }
      final current = int.tryParse(payload.codec['current_qn']?.toString() ?? '');
      if (current != null && current > 0) accepted.add(current);
    }

    final ordered = accepted.toList()..sort((a, b) => b.compareTo(a));
    return ordered
        .map((qn) => LivePlayQuality(quality: descriptions[qn] ?? '清晰度 $qn', id: qn, data: qn, sort: qn))
        .toList(growable: false);
  }

  /// Keeps the server-acknowledged `current_qn` with the URLs. Bilibili can
  /// advertise 10000/400 to a guest and still return qn=250 for every request;
  /// the caller must then keep the UI on 250 instead of pretending the tap was
  /// applied.
  static LivePlayUrlResolution parsePlayUrlResolution(dynamic response, {required Object? requestedQualityData}) {
    final playUrl = _playUrlPayload(response);
    final requestedQn = int.tryParse(requestedQualityData?.toString() ?? '');
    final candidates = <_BilibiliStreamCandidate>[];

    for (final payload in _codecPayloads(playUrl)) {
      final codec = payload.codec;
      final currentQn = int.tryParse(codec['current_qn']?.toString() ?? '');
      final baseUrl = codec['base_url']?.toString() ?? '';
      if (currentQn == null || currentQn <= 0 || baseUrl.isEmpty) continue;
      for (final rawUrl in (codec['url_info'] as List?) ?? const []) {
        if (rawUrl is! Map) continue;
        final url = '${rawUrl['host'] ?? ''}$baseUrl${rawUrl['extra'] ?? ''}'.trim();
        if (!url.startsWith('http')) continue;
        candidates.add(
          _BilibiliStreamCandidate(
            url: url,
            currentQn: currentQn,
            protocol: payload.protocol,
            format: payload.format,
            codec: codec['codec_name']?.toString() ?? '',
          ),
        );
      }
    }

    candidates.sort((a, b) {
      final requestedOrder = (b.currentQn == requestedQn ? 1 : 0).compareTo(a.currentQn == requestedQn ? 1 : 0);
      if (requestedOrder != 0) return requestedOrder;
      final protocolOrder = _protocolRank(a.protocol).compareTo(_protocolRank(b.protocol));
      if (protocolOrder != 0) return protocolOrder;
      final formatOrder = _formatRank(a.format).compareTo(_formatRank(b.format));
      if (formatOrder != 0) return formatOrder;
      final codecOrder = _codecRank(a.codec).compareTo(_codecRank(b.codec));
      if (codecOrder != 0) return codecOrder;
      final cdnOrder = (a.url.contains('mcdn') ? 1 : 0).compareTo(b.url.contains('mcdn') ? 1 : 0);
      if (cdnOrder != 0) return cdnOrder;
      return a.url.compareTo(b.url);
    });

    if (candidates.isEmpty) {
      return LivePlayUrlResolution(urls: const [], appliedQualityData: requestedQualityData);
    }
    final appliedQn = candidates.first.currentQn;
    final seen = <String>{};
    final urls = <String>[];
    for (final candidate in candidates) {
      if (candidate.currentQn != appliedQn || !seen.add(candidate.url)) continue;
      urls.add(candidate.url);
    }
    return LivePlayUrlResolution(urls: List.unmodifiable(urls), appliedQualityData: appliedQn);
  }

  static Map<dynamic, dynamic> _playUrlPayload(dynamic response) {
    if (response is! Map) throw const FormatException('Bilibili play response is not an object');
    if (response['code'] != 0) {
      throw StateError('Bilibili play API code=${response['code']}: ${response['message']}');
    }
    final data = response['data'];
    final playUrlInfo = data is Map ? data['playurl_info'] : null;
    final playUrl = playUrlInfo is Map ? playUrlInfo['playurl'] : null;
    if (playUrl is! Map) throw const FormatException('Bilibili playurl payload is missing');
    return playUrl;
  }

  static Iterable<({Map<dynamic, dynamic> codec, String format, String protocol})> _codecPayloads(
    Map<dynamic, dynamic> playUrl,
  ) sync* {
    for (final rawStream in (playUrl['stream'] as List?) ?? const []) {
      if (rawStream is! Map) continue;
      final protocol = rawStream['protocol_name']?.toString() ?? '';
      for (final rawFormat in (rawStream['format'] as List?) ?? const []) {
        if (rawFormat is! Map) continue;
        final format = rawFormat['format_name']?.toString() ?? '';
        for (final rawCodec in (rawFormat['codec'] as List?) ?? const []) {
          if (rawCodec is Map) yield (codec: rawCodec, format: format, protocol: protocol);
        }
      }
    }
  }

  static int _protocolRank(String value) => value == 'http_stream' ? 0 : 1;
  static int _formatRank(String value) => switch (value) {
    'flv' => 0,
    'ts' => 1,
    'fmp4' => 2,
    _ => 3,
  };
  static int _codecRank(String value) => value == 'avc' ? 0 : 1;

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    const rankedUrl = 'https://api.live.bilibili.com/room/v1/Area/getListByAreaID';
    Object? rankedError;

    // `webMain/getMoreRecList` is a recommendation feed: its `online` values
    // are deliberately not ordered. The Popular page promises a heat ranking,
    // so prefer the anonymous endpoint whose contract includes sort=online.
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final result = await HttpClient.instance.getJson(
          rankedUrl,
          queryParameters: {
            'areaId': 0,
            'parent_area_id': 0,
            'sort': 'online',
            'pageSize': pageSize.clamp(1, 30),
            'page': page,
          },
          header: await getHeader(),
        );
        return parseRecommendRooms(result);
      } catch (error) {
        rankedError = error;
        if (attempt == 0) await Future<void>.delayed(const Duration(milliseconds: 180));
      }
    }

    // Keep the recommendation feed only as a bounded availability fallback.
    // Local sorting still makes its displayed heat order truthful.
    try {
      final result = await HttpClient.instance.getJson(
        'https://api.live.bilibili.com/xlive/web-interface/v1/webMain/getMoreRecList',
        queryParameters: {'platform': 'web', 'page': page},
        header: await getHeader(),
      );
      return parseRecommendRooms(result);
    } catch (fallbackError) {
      throw Exception('Bilibili recommend failed: ranked=$rankedError; fallback=$fallbackError');
    }
  }

  /// Parses both the current webMain response and the legacy anonymous
  /// fallback. Kept pure so response-shape regressions can be unit tested.
  static List<LiveRoom> parseRecommendRooms(dynamic response) {
    if (response is! Map) throw const FormatException('Bilibili response is not an object');
    if (response['code'] != 0) {
      throw StateError('Bilibili API code=${response['code']}: ${response['message']}');
    }

    final data = response['data'];
    final dynamic rawList = data is Map ? data['recommend_room_list'] : data;
    if (rawList is! List) throw const FormatException('Bilibili recommendation list is missing');

    final rooms = rawList
        .whereType<Map>()
        .map((raw) {
          final item = Map<String, dynamic>.from(raw);
          final roomId = (item['roomid'] ?? item['room_id'])?.toString() ?? '';
          final cover = normalizeNetworkImageUrl((item['cover'] ?? item['user_cover'])?.toString());
          return LiveRoom(
            roomId: roomId,
            title: item['title']?.toString() ?? '',
            cover: cover.isEmpty ? '' : '$cover@400w.jpg',
            area: (item['area_v2_name'] ?? item['area_name'] ?? item['areaName'])?.toString() ?? '',
            nick: item['uname']?.toString() ?? '',
            avatar: normalizeNetworkImageUrl(item['face']?.toString()),
            watching: item['online']?.toString() ?? '',
            popularity: item['online']?.toString() ?? '',
            audienceMetricType: AudienceMetricType.popularity,
            liveStatus: LiveStatus.live,
            status: true,
            platform: Sites.bilibiliSite,
          );
        })
        .where((room) => room.roomId?.isNotEmpty == true)
        .toList(growable: false);
    return sortRoomsByPopularity(rooms);
  }

  /// Bilibili's list payload can be a recommendation snapshot, and even the
  /// ranked endpoint can contain small adjacent inversions while heat changes.
  /// Re-sort the values shown on the cards and use room identity for stable
  /// ties so the visible ranking is always strictly deterministic.
  static List<LiveRoom> sortRoomsByPopularity(Iterable<LiveRoom> rooms) {
    final result = rooms.toList(growable: false);
    result.sort(
      (left, right) =>
          LiveRoom.compareAudienceRanking(left, right, preferRealOnline: false, platformEnabled: (_) => false),
    );
    return result;
  }

  Future<Map<String, dynamic>> getRoomInfo({required String roomId}) async {
    const baseUrl = "https://api.live.bilibili.com/xlive/web-room/v1/index/getInfoByRoom";
    final url = "$baseUrl?room_id=$roomId";
    // WBI key discovery and anonymous-device cookie discovery are independent.
    // Starting both before the first await removes one full network round trip
    // from the first Bilibili card refresh after a cold launch.
    final headerFuture = getHeader();
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final (queryParams, header) = await (
          getWbiSign(url, forceRefresh: attempt > 0),
          attempt == 0 ? headerFuture : getHeader(),
        ).wait;
        final result = await HttpClient.instance.getJson(baseUrl, queryParameters: queryParams, header: header);
        return parseRoomInfoResponse(result);
      } catch (error) {
        lastError = error;
        if (attempt == 0) await Future<void>.delayed(const Duration(milliseconds: 180));
      }
    }
    throw StateError('Bilibili room info failed after WBI refresh: $lastError');
  }

  @visibleForTesting
  static Map<String, dynamic> parseRoomInfoResponse(dynamic response) {
    if (response is! Map) throw const FormatException('Bilibili room response is not an object');
    final code = int.tryParse(response['code']?.toString() ?? '');
    if (code != 0) throw StateError('Bilibili room request rejected: code=$code');
    final data = response['data'];
    if (data is! Map || data['room_info'] is! Map || data['anchor_info'] is! Map) {
      throw const FormatException('Bilibili room metadata is incomplete');
    }
    return Map<String, dynamic>.from(data);
  }

  static String kImgKey = '';
  static String kSubKey = '';
  static DateTime? _wbiKeysUpdatedAt;
  static Future<(String, String)>? _wbiKeysRequest;
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
  Future<(String, String)> getWbiKeys({bool forceRefresh = false}) async {
    final cacheAge = _wbiKeysUpdatedAt == null ? null : DateTime.now().difference(_wbiKeysUpdatedAt!);
    if (!forceRefresh &&
        kImgKey.isNotEmpty &&
        kSubKey.isNotEmpty &&
        cacheAge != null &&
        cacheAge < const Duration(hours: 6)) {
      return (kImgKey, kSubKey);
    }

    final pending = _wbiKeysRequest;
    if (pending != null) return pending;

    late final Future<(String, String)> operation;
    operation = _fetchWbiKeys().whenComplete(() {
      if (identical(_wbiKeysRequest, operation)) _wbiKeysRequest = null;
    });
    _wbiKeysRequest = operation;
    return operation;
  }

  Future<(String, String)> _fetchWbiKeys() async {
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
    _wbiKeysUpdatedAt = DateTime.now();

    return (imgKey, subKey);
  }

  String getMixinKey(String origin) {
    // 对 imgKey 和 subKey 进行字符顺序打乱编码
    return mixinKeyEncTab.fold("", (s, i) => s + origin[i]).substring(0, 32);
  }

  Future<Map<String, String>> getWbiSign(String url, {bool forceRefresh = false}) async {
    var (imgKey, subKey) = await getWbiKeys(forceRefresh: forceRefresh);

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

  Future<BiliBiliDanmakuArgs> _discoverDanmaku(int realRoomId, {int maxAttempts = 4}) async {
    const baseUrl = "https://api.live.bilibili.com/xlive/web-room/v1/index/getDanmuInfo";
    final headers = await getHeader();
    Map<String, dynamic>? data;
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final signed = await getWbiSign('$baseUrl?id=$realRoomId&type=0', forceRefresh: attempt == 1 || attempt == 3);
        final response = await HttpClient.instance.getJson(baseUrl, queryParameters: signed, header: headers);
        final candidate = response['data'];
        if (response['code'] == 0 && candidate is Map && candidate['token']?.toString().isNotEmpty == true) {
          data = Map<String, dynamic>.from(candidate);
          break;
        }
        lastError = StateError('getDanmuInfo code=${response['code']}');
      } catch (error) {
        lastError = error;
      }
      if (attempt + 1 < maxAttempts) {
        await Future<void>.delayed(Duration(milliseconds: 180 * (attempt + 1)));
      }
    }
    if (data == null) throw StateError('Bilibili danmaku discovery failed: $lastError');

    // The generic gateway has stable public DNS while some ISP/mobile DNS
    // resolvers intermittently omit the regional comet records returned by
    // host_list. Try it first and retain the regional nodes as failovers.
    const officialFallback = 'wss://broadcastlv.chat.bilibili.com/sub';
    final serverUrls = <String>[officialFallback];
    for (final item in (data['host_list'] as List?) ?? const []) {
      final host = item?['host']?.toString().trim() ?? '';
      if (host.isEmpty) continue;
      final port = int.tryParse(item?['wss_port']?.toString() ?? '') ?? 443;
      final endpoint = 'wss://$host${port == 443 ? '' : ':$port'}/sub';
      if (!serverUrls.contains(endpoint)) serverUrls.add(endpoint);
    }
    return BiliBiliDanmakuArgs(
      roomId: realRoomId,
      // A remembered uid without its login cookie is not an authenticated
      // identity. Sending it in a guest auth packet makes the gateway close
      // the socket on some rooms; anonymous danmaku uses uid=0.
      uid: cookie.trim().isEmpty ? 0 : userId,
      token: data['token']?.toString() ?? '',
      serverUrls: serverUrls,
      buvid: buvid3,
      cookie: headers['cookie'] ?? cookie,
      headers: {
        'user-agent': headers['user-agent'] ?? kDefaultUserAgent,
        'origin': 'https://live.bilibili.com',
        'referer': 'https://live.bilibili.com/$realRoomId',
        if ((headers['cookie'] ?? '').isNotEmpty) 'cookie': headers['cookie'],
      },
      refresh: () => _discoverDanmaku(realRoomId),
    );
  }

  @override
  Future<LiveRoom> getRoomDetail({required String platform, required String roomId}) async {
    try {
      var roomInfo = await getRoomInfo(roomId: roomId);
      var realRoomId = roomInfo["room_info"]["room_id"].toString();
      BiliBiliDanmakuArgs danmakuArgs;
      try {
        // Room entry must not wait through the whole chat retry chain.  A
        // single quick discovery gives playback priority; the websocket layer
        // then refreshes credentials with the full retry policy when needed.
        danmakuArgs = await _discoverDanmaku(int.tryParse(realRoomId) ?? 0, maxAttempts: 1);
      } catch (error) {
        debugPrint('Bilibili danmaku discovery failed: $error');
        final headers = await getHeader();
        danmakuArgs = BiliBiliDanmakuArgs(
          roomId: int.tryParse(realRoomId) ?? 0,
          uid: cookie.trim().isEmpty ? 0 : userId,
          token: '',
          serverUrls: const ['wss://broadcastlv.chat.bilibili.com/sub'],
          buvid: buvid3,
          cookie: headers['cookie'] ?? cookie,
          headers: {
            'user-agent': headers['user-agent'] ?? kDefaultUserAgent,
            'origin': 'https://live.bilibili.com',
            'referer': 'https://live.bilibili.com/$realRoomId',
            if ((headers['cookie'] ?? '').isNotEmpty) 'cookie': headers['cookie'],
          },
          refresh: () => _discoverDanmaku(int.tryParse(realRoomId) ?? 0),
        );
      }
      return _buildRoom(roomInfo, roomId: roomId, danmakuData: danmakuArgs);
    } catch (e) {
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

  @override
  Future<LiveRoom> getRoomDetailForRefresh({required String platform, required String roomId}) async {
    final roomInfo = await getRoomInfo(roomId: roomId);
    // Card verification deliberately skips getDanmuInfo. Chat credentials are
    // short-lived and useful only after the user enters this room.
    return _buildRoom(roomInfo, roomId: roomId);
  }

  LiveRoom _buildRoom(Map<String, dynamic> roomInfo, {required String roomId, Object? danmakuData}) {
    final live = (asT<int?>(roomInfo["room_info"]["live_status"]) ?? 0) == 1;
    return LiveRoom(
      roomId: roomId,
      title: roomInfo["room_info"]["title"].toString(),
      cover: roomInfo["room_info"]["cover"].toString(),
      nick: roomInfo["anchor_info"]["base_info"]["uname"].toString(),
      avatar: "${roomInfo["anchor_info"]["base_info"]["face"]}@100w.jpg",
      watching: roomInfo["room_info"]["online"].toString(),
      popularity: roomInfo["room_info"]["online"].toString(),
      audienceMetricType: AudienceMetricType.popularity,
      area: roomInfo['room_info']?['area_name'] ?? '',
      status: live,
      liveStatus: live ? LiveStatus.live : LiveStatus.offline,
      link: "https://live.bilibili.com/$roomId",
      introduction: roomInfo["room_info"]["description"].toString(),
      notice: "",
      platform: Sites.bilibiliSite,
      danmakuData: danmakuData,
    );
  }

  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) async {
    final effectivePageSize = pageSize.clamp(1, 50);
    var result = await HttpClient.instance.getJson(
      "https://api.bilibili.com/x/web-interface/search/type?context=&search_type=live&cover_type=user_cover",
      queryParameters: {
        "order": "",
        "keyword": keyword,
        "category_id": "",
        "__refresh__": "",
        "_extra": "",
        "highlight": 0,
        "single_column": 0,
        "page": page,
        "page_size": effectivePageSize,
      },
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
        title: title,
        cover: "https:${item["cover"]}@400w.jpg",
        nick: item["uname"].toString(),
        watching: item["online"].toString(),
        popularity: item["online"].toString(),
        followers: item["attentions"]?.toString() ?? '',
        audienceMetricType: AudienceMetricType.popularity,
        liveStatus: (asT<int?>(item["live_status"]) ?? 0) == 1 ? LiveStatus.live : LiveStatus.offline,
        area: item["cate_name"].toString(),
        status: (asT<int?>(item["live_status"]) ?? 0) == 1,
        avatar: "https:${item["uface"]}@400w.jpg",
        platform: Sites.bilibiliSite,
      );
      items.add(roomItem);
    }
    return items;
  }

  @override
  Future<List<LiveAnchorItem>> searchAnchors(String keyword, {int page = 1, int pageSize = 30}) async {
    var result = await HttpClient.instance.getJson(
      "https://api.bilibili.com/x/web-interface/search/type?context=&search_type=live_user&cover_type=user_cover",
      queryParameters: {
        "order": "",
        "keyword": keyword,
        "category_id": "",
        "__refresh__": "",
        "_extra": "",
        "highlight": 0,
        "single_column": 0,
        "page": page,
      },
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
    return items;
  }

  @override
  Future<bool> getLiveStatus({required String platform, required String roomId}) async {
    var result = await HttpClient.instance.getJson(
      "https://api.live.bilibili.com/room/v1/Room/get_info",
      queryParameters: {"room_id": roomId},
      header: await getHeader(),
    );
    return (asT<int?>(result["data"]["live_status"]) ?? 0) == 1;
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({required String roomId}) async {
    var result = await HttpClient.instance.getJson(
      "https://api.live.bilibili.com/av/v1/SuperChat/getMessageList",
      queryParameters: {"room_id": roomId},
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
        header: {"user-agent": kDefaultUserAgent, "referer": kDefaultReferer, "cookie": cookie},
      );
      return result["data"];
    } catch (e) {
      return {"b_3": "", "b_4": ""};
    }
  }

  Future<String> getAccessId() async {
    if (accessId.isNotEmpty) {
      return accessId;
    }

    // 获取 access_id
    var resp = await HttpClient.instance.getText(
      "https://live.bilibili.com/lol",
      queryParameters: {},
      header: await getHeader(),
    );
    var id = RegExp(r'"access_id":"(.*?)"').firstMatch(resp)?.group(1)?.replaceAll("\\", "");
    accessId = id ?? "";
    return accessId;
  }
}

class _BilibiliStreamCandidate {
  const _BilibiliStreamCandidate({
    required this.url,
    required this.currentQn,
    required this.protocol,
    required this.format,
    required this.codec,
  });

  final String url;
  final int currentQn;
  final String protocol;
  final String format;
  final String codec;
}
