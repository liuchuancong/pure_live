import 'dart:convert';

import 'package:pure_live/core/index.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:pure_live/core/models/live_category.dart';
import 'package:pure_live/core/models/live_anchor_item.dart';
import 'package:pure_live/core/logging/core_log.dart';
import 'package:pure_live/core/network/core_error.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/shared/platforms/live_site.dart';
import 'package:pure_live/shared/platforms/douyu/douyu_danmaku.dart';
import 'package:pure_live/core/network/douyu_utils.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/core/utils/live_quality_label.dart';
import 'package:pure_live/shared/platforms/current_live_room.dart';
import 'package:pure_live/core/consts/platform_ids.dart';
import 'package:pure_live/shared/platforms/live_danmaku_capability.dart';
import 'package:pure_live/shared/platforms/douyu/douyu_danmaku_capability.dart';
import 'package:pure_live/shared/platforms/live_external_room.dart';

class DouyuSite
    with LiveDanmakuCapabilityDefaults, DouyuDanmakuCapability
    implements
        LiveSite,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayUrlResolver,
        LivePlayRecoveryResolver,
        LivePlayUrlCursorResolver,
        LivePlayLeaseMetadata,
        LiveSiteExternalRoomResolver {
  @override
  RoomExternalTarget? externalRoomTarget(LiveRoom liveroom) {
    final id = sanitizedExternalRoomId(liveroom.roomId);
    if (id == null) return null;
    final path = Uri.encodeComponent(id);
    return RoomExternalTarget(
      web: 'https://www.douyu.com/$path',
      native: 'douyulink://?type=90001&schemeUrl=douyuapp%3A%2F%2Froom%3FliveType%3D0%26rid%3D$path',
    );
  }

  @override
  String id = PlatformIds.douyu;

  /// Anonymous original-quality URLs carry `expire=300`: the CDN closes the
  /// stream 300 s after the URL was issued. The URL has no absolute time, so
  /// the issue time is remembered when it is resolved.
  static final Map<String, DateTime> _issuedAt = {};
  static const Duration _leaseRefreshLead = Duration(seconds: 45);

  static int? _expireSeconds(String url) {
    final value = int.tryParse(Uri.tryParse(url)?.queryParameters['expire'] ?? '');
    return value != null && value > 0 ? value : null;
  }

  static void _rememberIssued(String url, DateTime at) {
    if (_expireSeconds(url) == null) return;
    _issuedAt.remove(url);
    _issuedAt[url] = at;
    while (_issuedAt.length > 64) {
      _issuedAt.remove(_issuedAt.keys.first);
    }
  }

  @override
  DateTime? getPlayUrlInvalidAt(String url, {DateTime? now}) {
    final expire = _expireSeconds(url);
    if (expire == null) return null;
    return (_issuedAt[url] ?? now ?? DateTime.now()).toUtc().add(Duration(seconds: expire));
  }

  @override
  DateTime? getPlayUrlRefreshAt(String url, {DateTime? now}) {
    final invalidAt = getPlayUrlInvalidAt(url, now: now);
    if (invalidAt == null) return null;
    // Short leases keep three quarters of their lifetime.
    final quarter = Duration(seconds: _expireSeconds(url)! ~/ 4);
    return invalidAt.subtract(quarter < _leaseRefreshLead ? quarter : _leaseRefreshLead);
  }

  @override
  String name = "斗鱼直播";

  @override
  LiveDanmaku getDanmaku() => DouyuDanmaku(
    filterSuspectedAutomatedMessages: () => SettingsService.to.danmaku.filterDouyuSuspectedAutomatedMessages.v,
  );

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    List<LiveCategory> categories = [];
    var result = await HttpClient.instance.getJson("https://m.douyu.com/api/cate/list");
    var subCateList = result["data"]["cate2Info"] as List;
    for (var item in result["data"]["cate1Info"]) {
      var cate1Id = item["cate1Id"];
      var cate1Name = item["cate1Name"];
      List<LiveArea> subCategories = [];
      subCateList.where((x) => x["cate1Id"] == cate1Id).forEach((element) {
        subCategories.add(
          LiveArea(
            areaPic: _areaPicture(element),
            areaId: element["cate2Id"].toString(),
            typeName: cate1Name.toString(),
            areaType: cate1Id.toString(),
            platform: PlatformIds.douyu,
            areaName: element["cate2Name"].toString(),
          ),
        );
      });
      categories.add(LiveCategory(id: cate1Id.toString(), name: cate1Name.toString(), children: subCategories));
    }
    categories.sort((a, b) => int.parse(a.id).compareTo(int.parse(b.id)));

    return categories;
  }

  static String _areaPicture(dynamic area) {
    if (area is! Map) return '';
    for (final key in const ['icon', 'smallIcon', 'pic']) {
      final url = normalizeNetworkImageUrl(area[key]?.toString());
      if (url.isNotEmpty) return url;
    }
    return '';
  }

  Future<List<LiveArea>> getSubCategories(LiveCategory liveCategory) async {
    var result = await HttpClient.instance.getJson(
      "https://www.douyu.com/japi/weblist/apinc/getC2List",
      queryParameters: {"shortName": liveCategory.name, "customClassId": liveCategory.id, "offset": 0, "limit": 200},
    );

    List<LiveArea> subs = [];
    for (var item in result["data"]["list"]) {
      subs.add(
        LiveArea(
          areaPic: item["squareIconUrlW"].toString(),
          areaId: item["cid2"].toString(),
          typeName: liveCategory.name,
          areaType: liveCategory.id,
          platform: PlatformIds.douyu,
          areaName: item["cname2"].toString(),
        ),
      );
    }

    return subs;
  }

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    var result = await HttpClient.instance.getJson(
      "https://www.douyu.com/gapi/rkc/directory/mixList/2_${category.areaId}/$page",
      queryParameters: {},
    );

    var items = <LiveRoom>[];
    for (var item in result['data']['rl']) {
      if (item["type"] != 1) {
        continue;
      }
      var roomItem = LiveRoom(
        cover: item['rs16'].toString(),
        watching: item['ol'].toString(),
        popularity: item['ol'].toString(),
        audienceMetricType: AudienceMetricType.popularity,
        roomId: item['rid'].toString(),
        title: item['rn'].toString(),
        nick: item['nn'].toString(),
        area: item['c2name'].toString(),
        liveStatus: LiveStatus.live,
        avatar: item['av'].toString().isNotEmpty ? 'https://apic.douyucdn.cn/upload/${item['av']}_middle.jpg' : '',
        status: true,
        platform: PlatformIds.douyu,
      );
      items.add(roomItem);
    }
    return items;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom liveroom}) async {
    final roomId = liveroom.roomId ?? '';
    final playData = await _requestPlayData(roomId);
    final cdns = parseCdnCodes(playData);
    cdns.sort((a, b) {
      if (a.startsWith("scdn") && !b.startsWith("scdn")) {
        return 1;
      } else if (!a.startsWith("scdn") && b.startsWith("scdn")) {
        return -1;
      }
      return 0;
    });
    return parsePlayQualities(playData, cdns);
  }

  /// Keeps Douyu's advertised `multirates` order. The numeric `rate` is an
  /// opaque request code (source is commonly 0), not a bitrate; sorting it in
  /// descending numeric order reverses source and low-quality choices.
  @visibleForTesting
  static List<LivePlayQuality> parsePlayQualities(Map<String, dynamic> playData, List<String> cdns) {
    final qualities = <LivePlayQuality>[];
    final rates = playData['multirates'];
    if (rates is List) {
      final rateItems = rates.whereType<Map>().toList(growable: false);
      for (var index = 0; index < rateItems.length; index++) {
        final item = rateItems[index];
        final rate = _asInt(item['rate']);
        if (rate == null) continue;
        final name = item['name']?.toString().trim();
        if (qualities.any((quality) => quality.selectionId == rate)) continue;
        qualities.add(
          LivePlayQuality(
            quality: LiveQualityLabel.normalize(
              platform: PlatformIds.douyu,
              rawLabel: name?.isNotEmpty == true ? name! : '',
              id: rate,
            ),
            id: rate,
            sort: rateItems.length - index,
            data: DouyuPlayData(rate, List<String>.unmodifiable(cdns)),
          ),
        );
      }
    }
    if (qualities.isEmpty) {
      final rate = _asInt(playData['rate']) ?? -1;
      qualities.add(
        LivePlayQuality(
          quality: LiveQualityLabel.normalize(platform: PlatformIds.douyu, rawLabel: 'default', id: rate),
          id: rate,
          sort: 1,
          data: DouyuPlayData(rate, List.unmodifiable(cdns)),
        ),
      );
    }
    return qualities;
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom liveroom, required LivePlayQuality quality}) async {
    return (await resolvePlayUrlsRaw(liveroom: liveroom, quality: quality)).urls;
  }

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsForRecoveryRaw({
    required LiveRoom liveroom,
    required LivePlayQuality quality,
  }) async {
    // Both the signed URL and advertised CDN set can change while a live
    // connection is paused. Refresh the metadata, then ask for the committed
    // rate with those current CDNs rather than reopening the old URL cohort.
    final qualities = await getPlayQualites(liveroom: liveroom);
    if (qualities.isEmpty) return const LivePlayUrlResolution(urls: <String>[]);
    final requestedId = quality.selectionId.toString();
    final matching = qualities.where((item) => item.selectionId.toString() == requestedId).firstOrNull;
    final freshData = qualities.first.data;
    final requestedData = quality.data;
    final request =
        matching ??
        (freshData is DouyuPlayData && requestedData is DouyuPlayData
            ? LivePlayQuality(
                quality: quality.quality,
                id: quality.selectionId,
                data: DouyuPlayData(requestedData.rate, freshData.cdns),
              )
            : qualities.first);
    // A no-longer-advertised rate can still be accepted or downgraded by the
    // server. Preserve that acknowledgement for the successful-source commit;
    // never label a fallback using only the requested rate.
    return resolvePlayUrlsRaw(liveroom: liveroom, quality: request);
  }

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsRaw({
    required LiveRoom liveroom,
    required LivePlayQuality quality,
  }) async {
    final rawData = quality.data;
    final roomId = liveroom.roomId?.trim() ?? '';
    if (rawData is! DouyuPlayData || roomId.isEmpty) return const LivePlayUrlResolution(urls: []);
    final data = rawData;
    // Each CDN may acknowledge a different rate. A single UI quality label
    // must not cover a mixture of source and downgraded streams. Prefer an
    // acknowledged requested rate, otherwise the first acknowledged cohort
    // in platform order. Unknown acknowledgements remain a separate cohort.
    final urlsByRate = <Object?, List<String>>{};
    Object? lastError;
    for (final cdn in data.cdns) {
      try {
        final resolution = await resolvePlayUrl(roomId, data.rate, cdn);
        if (resolution.urls.isEmpty) continue;
        final urls = urlsByRate.putIfAbsent(resolution.appliedQualityData, () => <String>[]);
        for (final url in resolution.urls) {
          if (!urls.contains(url)) urls.add(url);
        }
      } catch (error) {
        lastError = error;
      }
    }
    if (urlsByRate.isEmpty) {
      if (lastError != null) throw lastError;
      return const LivePlayUrlResolution(urls: []);
    }
    final acknowledgedRates = urlsByRate.keys.whereType<int>();
    final appliedRate = urlsByRate.containsKey(data.rate) ? data.rate : acknowledgedRates.firstOrNull;
    return LivePlayUrlResolution(
      urls: List<String>.unmodifiable(urlsByRate[appliedRate]!),
      appliedQualityData: appliedRate,
      qualityUnconfirmed: appliedRate == null,
    );
  }

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlAtRaw({
    required LiveRoom liveroom,
    required LivePlayQuality quality,
    required int lineIndex,
  }) async {
    final data = quality.data;
    if (data is! DouyuPlayData || lineIndex < 0 || lineIndex >= data.cdns.length) {
      return const LivePlayUrlResolution(urls: <String>[]);
    }
    final roomId = liveroom.roomId?.trim() ?? '';
    if (roomId.isEmpty) {
      return const LivePlayUrlResolution(urls: <String>[]);
    }
    return resolvePlayUrl(roomId, data.rate, data.cdns[lineIndex]);
  }

  Future<String> getPlayUrl(String roomId, int rate, String cdn) async {
    return (await resolvePlayUrl(roomId, rate, cdn)).urls.single;
  }

  Future<LivePlayUrlResolution> resolvePlayUrl(String roomId, int rate, String cdn) async {
    final issuedAt = DateTime.now().toUtc();
    final playData = await _requestPlayData(roomId, rate: rate, cdn: cdn);
    final rawRate = playData['rate'];
    // Unlike a bitrate, rate is an opaque integer identifier. Do not truncate
    // malformed fractions (e.g. 0.5) into a false source-quality acknowledgement.
    final appliedRate = rawRate is num && rawRate.isFinite && rawRate == rawRate.roundToDouble()
        ? rawRate.toInt()
        : int.tryParse(rawRate?.toString().trim() ?? '');
    var url = parsePlayUrl(playData);
    // 海外/部分匿名会话会拿到 5 分钟即失效的 ws CDN 线（expire=300&fcdn=ws）；
    // 附加 expire=0 让 CDN 按默认时长签发（simple_live 同款补丁）。
    if (url.contains('expire=300') && url.contains('fcdn=ws')) {
      url = '$url&expire=0';
    }
    _rememberIssued(url, issuedAt);
    return LivePlayUrlResolution(
      urls: List<String>.unmodifiable([url]),
      appliedQualityData: appliedRate != null && appliedRate >= 0 ? appliedRate : null,
      qualityUnconfirmed: appliedRate == null || appliedRate < 0,
    );
  }

  Future<Map<String, dynamic>> _requestPlayData(String roomId, {int rate = -1, String cdn = ''}) async {
    if (roomId.trim().isEmpty) {
      throw const DouyuPlayApiException('room id is empty');
    }
    // A pasted cookie is good for seven days and then stops being a login:
    // renew it here, on the path that actually needs one, instead of failing the
    // room as a guest because the token aged out.
    await DouyuUtils.ensureFreshSession();

    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final sign = await DouyuUtils.sign(roomId, rate: rate, cdn: cdn, forceRefresh: attempt > 0);
        final result = await HttpClient.instance.postJson(
          'https://www.douyu.com/lapi/live/getH5PlayV1/$roomId',
          data: sign,
          formUrlEncoded: true,
          header: DouyuUtils.requestHeaders(roomId),
        );
        return parsePlayResponse(result);
      } catch (error) {
        lastError = error;
        CoreLog.w(
          'Douyu play request failed (attempt ${attempt + 1}): $error'
          '${error is HttpError && error.statusCode != 0 ? ' status=${error.statusCode}' : ''}'
          '${error is HttpError && error.responseBody != null ? ' body=${error.responseBody}' : ''}'
          '${error is HttpError && error.responseHeaders['x-request-id'] != null ? ' requestId=${error.responseHeaders['x-request-id']}' : ''}'
          ' | ${DouyuUtils.requestShape(roomId)}',
        );
        // The first attempt is also the cheapest way to learn the cookie is
        // stale: renew it (the long-term key is the only thing that can) and let
        // the retry use the fresh one.
        await DouyuUtils.ensureFreshSession(force: true);
      }
    }
    throw DouyuPlayApiException('H5 play request failed after retry', cause: lastError);
  }

  @visibleForTesting
  static Map<String, dynamic> parsePlayResponse(dynamic response) {
    if (response is! Map) {
      throw const DouyuPlayApiException('H5 play response is not an object');
    }
    final errorCode = _asInt(response['error']) ?? _asInt(response['code']) ?? -1;
    if (errorCode != 0) {
      final message = response['msg']?.toString().trim();
      throw DouyuPlayApiException('H5 play API error $errorCode${message?.isNotEmpty == true ? ': $message' : ''}');
    }
    final rawData = response['data'];
    if (rawData is! Map) {
      throw const DouyuPlayApiException('H5 play response is missing data');
    }
    return Map<String, dynamic>.from(rawData);
  }

  @visibleForTesting
  static List<String> parseCdnCodes(Map<String, dynamic> data) {
    final result = <String>[];
    final rawCdns = data['cdnsWithName'];
    if (rawCdns is List) {
      for (final item in rawCdns.whereType<Map>()) {
        final code = item['cdn']?.toString().trim() ?? '';
        if (code.isNotEmpty && !result.contains(code)) result.add(code);
      }
    }
    final current = data['rtmp_cdn']?.toString().trim() ?? '';
    if (current.isNotEmpty && !result.contains(current)) result.insert(0, current);
    if (result.isEmpty) result.add('');
    return result;
  }

  @visibleForTesting
  static String parsePlayUrl(Map<String, dynamic> data) {
    final unescape = HtmlUnescape();
    final live = unescape.convert(data['rtmp_live']?.toString().trim() ?? '');
    // Some current H5 responses return a complete signed FLV address in
    // rtmp_live. It must win over the separate CDN base fields; prefixing a
    // second absolute URL produces a syntactically valid but unopenable input
    // such as `https://cdn/live/https://other/live.flv`.
    if (_isPlayableUrl(live)) return live;
    // getH5PlayV1 normally separates the CDN base (`rtmp_url`, and on
    // variants `flv_url`) from the signed media path (`rtmp_live`). A base URL
    // is syntactically valid HTTP but is not an FFmpeg input. Returning it
    // early was the direct cause of "input stream address format" failures.
    for (final baseKey in const <String>['rtmp_url', 'flv_url']) {
      final base = unescape.convert(data[baseKey]?.toString().trim() ?? '');
      if (base.isEmpty || live.isEmpty) continue;
      final combined = '${base.replaceFirst(RegExp(r'/+$'), '')}/${live.replaceFirst(RegExp(r'^/+'), '')}';
      if (_isPlayableUrl(combined)) return combined;
    }

    for (final key in const <String>['player_1', 'stream_url', 'url']) {
      final value = unescape.convert(data[key]?.toString().trim() ?? '');
      if (_isPlayableUrl(value)) return value;
    }

    // Compatibility with payloads that expose a complete FLV address without
    // rtmp_live. Require a media-looking path so a bare CDN directory is never
    // handed to the recorder again.
    final flvUrl = unescape.convert(data['flv_url']?.toString().trim() ?? '');
    if (_isDirectMediaUrl(flvUrl)) return flvUrl;
    throw const DouyuPlayApiException('H5 play response has no playable URL');
  }

  static int? _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static bool _isPlayableUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.host.isNotEmpty && const {'http', 'https', 'rtmp'}.contains(uri.scheme);
  }

  static bool _isDirectMediaUrl(String value) {
    if (!_isPlayableUrl(value)) return false;
    final path = Uri.parse(value).path.toLowerCase();
    return path.endsWith('.flv') || path.endsWith('.m3u8') || path.endsWith('.mp4');
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    try {
      var result = await HttpClient.instance.getJson(
        "https://www.douyu.com/japi/weblist/apinc/allpage/6/$page",
        queryParameters: {},
      );

      var items = <LiveRoom>[];
      for (var item in result['data']['rl']) {
        if (item["type"] != 1) {
          continue;
        }

        var roomItem = LiveRoom(
          cover: item['rs16'].toString(),
          watching: item['ol'].toString(),
          popularity: item['ol'].toString(),
          audienceMetricType: AudienceMetricType.popularity,
          roomId: item['rid'].toString(),
          title: item['rn'].toString(),
          nick: item['nn'].toString(),
          area: item['c2name'].toString(),
          avatar: item['av'] ?? '',
          platform: PlatformIds.douyu,
          status: true,
          liveStatus: LiveStatus.live,
        );
        items.add(roomItem);
      }
      return items;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    final fresh = await _resolveDetail(liveroom);
    // Pad whatever the profile endpoint left empty (avatar/cover/nick drift
    // between responses) with the fields the room already carries, so a
    // partial response never blanks the UI. fillFromDetail covers
    // nick/avatar/area; the cover is padded explicitly because a blank
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
      final roomInfo = await _fetchRoomInfo(roomId);

      return _buildRoom(roomInfo, roomId: roomId);
    } catch (e) {
      final currentRoom = CurrentLiveRoom.value;
      if (currentRoom?.hasSameIdentity(LiveRoom(roomId: roomId, platform: platform)) == true) {
        return currentRoom!.getLiveRoomWithError();
      }

      return LiveRoom(roomId: roomId, platform: platform).getLiveRoomWithError();
    }
  }

  @override
  Future<LiveRoom> getRoomDetailForRefresh(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    final roomInfo = await _fetchRoomInfo(liveroom.roomId!);
    return _buildRoom(roomInfo, roomId: liveroom.roomId!);
  }

  @override
  Future<LiveRoom> getRoomDetailForRecording(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    // Do not use getRoomDetail here: its UI fallback converts a failed betard
    // request into an offline room, which previously stopped recording before
    // Douyu signing/getH5PlayV1 was reached.
    final roomInfo = await _fetchRoomInfo(liveroom.roomId!);
    return _buildRoom(roomInfo, roomId: liveroom.roomId!);
  }

  Future<Map<dynamic, dynamic>> _fetchRoomInfo(String roomId) async {
    var result = await HttpClient.instance.getJson(
      "https://www.douyu.com/betard/$roomId",
      queryParameters: {},
      header: {
        'referer': 'https://www.douyu.com/$roomId',
        'user-agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.43',
      },
    );
    Map roomInfo;

    if (result is String) {
      roomInfo = json.decode(result)["room"];
    } else {
      roomInfo = result["room"];
    }
    return roomInfo;
  }

  LiveRoom _buildRoom(Map<dynamic, dynamic> roomInfo, {required String roomId}) {
    final live = isLiveRoomPayload(roomInfo);
    final replay = _asInt(roomInfo['videoLoop']) == 1;

    return LiveRoom(
      cover: roomInfo["room_pic"].toString(),
      watching: roomInfo["room_biz_all"]["hot"].toString(),
      popularity: roomInfo["room_biz_all"]["hot"].toString(),
      audienceMetricType: AudienceMetricType.popularity,
      roomId: roomInfo["room_id"].toString(),
      title: roomInfo["room_name"].toString(),
      nick: roomInfo["owner_name"].toString(),
      avatar: roomInfo["owner_avatar"].toString(),
      introduction: roomInfo["show_details"].toString(),
      area: roomInfo["second_lvl_name"]?.toString() ?? '',
      notice: "",
      liveStatus: live ? LiveStatus.live : LiveStatus.offline,
      status: live,
      danmakuData: roomInfo["room_id"].toString(),
      data: null,
      platform: PlatformIds.douyu,
      link: "https://www.douyu.com/$roomId",
      isRecord: replay,
      startedAt: live ? _startedAt(roomInfo['show_time']) : null,
    );
  }

  static DateTime? _startedAt(Object? value) {
    final seconds = _asInt(value);
    if (seconds == null || seconds <= 0) return null;
    final time = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    return time.year >= 2000 && time.year <= 2100 ? time : null;
  }

  @visibleForTesting
  static bool isLiveRoomPayload(Map<dynamic, dynamic> roomInfo) {
    return _asInt(roomInfo['show_status']) == 1 &&
        _asInt(roomInfo['videoLoop']) != 1 &&
        !roomInfo['room_name'].toString().startsWith('【回放】');
  }

  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) async {
    final effectivePageSize = pageSize.clamp(1, 50);
    final headers = DouyuUtils.requestHeaders()..['referer'] = 'https://www.douyu.com/search/';

    var result = await HttpClient.instance.getJson(
      "https://www.douyu.com/japi/search/api/searchShow",
      queryParameters: {"kw": keyword, "page": page, "pageSize": effectivePageSize},
      header: headers,
    );

    if (result['error'] != 0) {
      throw Exception(result['msg']);
    }

    var items = <LiveRoom>[];

    var queryList = result["data"]["relateShow"] ?? [];

    for (var item in queryList) {
      var liveStatus = (int.tryParse(item["isLive"].toString()) ?? 0) == 1;

      var roomType = int.tryParse(item["roomType"].toString()) ?? 0;

      var isLive = liveStatus && roomType == 0;

      var roomItem = LiveRoom(
        roomId: item["rid"].toString(),
        title: item["roomName"].toString(),
        cover: item["roomSrc"].toString(),
        area: item["cateName"].toString(),
        avatar: item["avatar"].toString(),
        liveStatus: isLive ? LiveStatus.live : LiveStatus.offline,
        status: isLive,
        nick: item["nickName"].toString(),
        platform: PlatformIds.douyu,
        watching: item["hot"].toString(),
        popularity: item["hot"].toString(),
        audienceMetricType: AudienceMetricType.popularity,
      );

      items.add(roomItem);
    }

    return items;
  }

  @override
  Future<List<LiveAnchorItem>> searchAnchors(String keyword, {int page = 1, int pageSize = 30}) async {
    final effectivePageSize = pageSize.clamp(1, 50);
    final headers = DouyuUtils.requestHeaders()..['referer'] = 'https://www.douyu.com/search/';

    var result = await HttpClient.instance.getJson(
      "https://www.douyu.com/japi/search/api/searchUser",
      queryParameters: {"kw": keyword, "page": page, "pageSize": effectivePageSize, "filterType": 1},
      header: headers,
    );

    var items = <LiveAnchorItem>[];

    for (var item in result["data"]["relateUser"]) {
      var liveStatus = (int.tryParse(item["anchorInfo"]["isLive"].toString()) ?? 0) == 1;

      var roomType = int.tryParse(item["anchorInfo"]["roomType"].toString()) ?? 0;

      var roomItem = LiveAnchorItem(
        roomId: item["anchorInfo"]["rid"].toString(),
        avatar: item["anchorInfo"]["avatar"].toString(),
        userName: item["anchorInfo"]["nickName"].toString(),
        liveStatus: liveStatus && roomType == 0,
      );

      items.add(roomItem);
    }

    return items;
  }

  int parseHotNum(String hn) {
    try {
      var num = double.parse(hn.replaceAll("万", ""));

      if (hn.contains("万")) {
        num *= 10000;
      }

      return num.round();
    } catch (_) {
      return -999;
    }
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({required LiveRoom liveroom}) {
    return Future.value([]);
  }
}

class DouyuPlayData {
  final int rate;
  final List<String> cdns;

  DouyuPlayData(this.rate, this.cdns);
}

class DouyuPlayApiException implements Exception {
  const DouyuPlayApiException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null ? 'DouyuPlayApiException: $message' : 'DouyuPlayApiException: $message ($cause)';
}
