import 'dart:math';
import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/tars/types.dart';
import 'package:pure_live/core/common/log.dart';
import 'package:pure_live/plugins/race_http.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/model/live_anchor_item.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/danmaku/huya_danmaku.dart';
import 'package:pure_live/common/utils/githup_mirror.dart';
import 'package:pure_live/pkg/tars/net/base_tars_http.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/tars/get_cdn_token_ex_req.dart';
import 'package:pure_live/core/tars/get_cdn_token_ex_resp.dart';
import 'package:pure_live/core/site/huya/huya_request_params.dart';
import 'package:pure_live/core/tars/get_game_event_message_board_req.dart';
import 'package:pure_live/core/tars/get_game_event_message_board_rsp.dart';
import 'package:pure_live/modules/live_play/controllers/player_controller.dart';
import 'package:pure_live/core/utils/live_quality_label.dart';

class HuyaSite
    implements
        LiveSite,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayUrlCursorResolver,
        LivePlayRecoveryResolver,
        LivePlayLeaseMetadata {
  @override
  String id = Sites.huyaSite;
  static const baseUrl = HuyaRequestParams.baseUrl;
  @override
  String name = "虎牙直播";
  @override
  LiveDanmaku getDanmaku() => HuyaDanmaku();

  /// Huya's web player treats playback as a viewer session, not as an anchor-
  /// signed static URL. Keep one anonymous identity for this site instance and
  /// deduplicate only requests concurrently acquiring the same token.
  final Map<String, Future<HuyaCdnTokenLease>> _inFlightTokenRequests = <String, Future<HuyaCdnTokenLease>>{};
  final Map<String, HuyaCdnTokenLease> _playbackTokenLeases = <String, HuyaCdnTokenLease>{};
  final Map<String, DateTime> _playbackTransportIssuedAt = <String, DateTime>{};
  HuyaViewerIdentity? _anonymousViewerIdentity;
  Future<HuyaViewerIdentity>? _anonymousViewerIdentityRequest;
  late final int _fallbackViewerUid = _createFallbackViewerUid();
  late final String _viewerGuid = _createViewerGuid();
  static String? playUserAgent;
  static const Duration _transportRefreshAge = Duration(seconds: 100);
  static const Duration _transportInvalidAge = Duration(seconds: 125);

  @override
  DateTime? getPlayUrlRefreshAt(String url, {DateTime? now}) {
    final current = (now ?? DateTime.now()).toUtc();
    final signedInvalidAt = _getSignedUrlInvalidAt(url);
    final tokenLease = _getPlaybackTokenLease(url);
    final transportIssuedAt = _isHuyaCdnUrl(url)
        ? getSignedSequenceIssuedAt(url) ?? _getRememberedTransportIssuedAt(url)
        : null;
    final transportInvalidAt = transportIssuedAt?.add(_transportInvalidAge);
    final invalidAt = _earlierDate(_earlierDate(signedInvalidAt, tokenLease?.invalidAt), transportInvalidAt);
    if (invalidAt == null) return null;
    final signatureRefreshAt = signedInvalidAt?.subtract(const Duration(seconds: 30));
    final transportRefreshAt = transportIssuedAt?.add(_transportRefreshAge);
    final refreshAt =
        _earlierDate(_earlierDate(signatureRefreshAt, tokenLease?.refreshAt), transportRefreshAt) ?? current;
    return refreshAt.isAfter(current) ? refreshAt : current;
  }

  @override
  DateTime? getPlayUrlInvalidAt(String url, {DateTime? now}) {
    final tokenLease = _getPlaybackTokenLease(url);
    final transportIssuedAt = _isHuyaCdnUrl(url)
        ? getSignedSequenceIssuedAt(url) ?? _getRememberedTransportIssuedAt(url)
        : null;
    return _earlierDate(
      _earlierDate(_getSignedUrlInvalidAt(url), tokenLease?.invalidAt),
      transportIssuedAt?.add(_transportInvalidAge),
    );
  }

  DateTime? _getSignedUrlInvalidAt(String url) {
    final query = Uri.tryParse(url)?.queryParameters;
    return query == null ? null : _signedUrlInvalidAtFromQuery(query);
  }

  static DateTime? _signedUrlInvalidAtFromQuery(Map<String, String> query) {
    final wsTime = int.tryParse(query['wsTime'] ?? '', radix: 16);
    if (wsTime == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(wsTime * 1000, isUtc: true).add(const Duration(minutes: 5));
  }

  static DateTime? _earlierDate(DateTime? first, DateTime? second) {
    if (first == null) return second;
    if (second == null) return first;
    return first.isBefore(second) ? first : second;
  }

  static bool _isHuyaCdnUrl(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host == 'huya.com' || host.endsWith('.huya.com');
  }

  /// Recovers the issue time encoded by the official web player's
  /// `seqid = viewerUid + Date.now()` contract. Huya's CDN can close a signed
  /// transport roughly two minutes after this point while `wsTime` is still
  /// valid, so the issue time is a stable transport-age anchor. It must not be
  /// recomputed from the time this metadata method happens to be called.
  @visibleForTesting
  static DateTime? getSignedSequenceIssuedAt(String url) {
    final query = Uri.tryParse(url)?.queryParameters;
    if (query == null) return null;
    final seqId = int.tryParse(query['seqid'] ?? '');
    final isWap = query['t'] == '103';
    final encodedUid = int.tryParse(query[isWap ? 'uid' : 'u'] ?? '');
    if (seqId == null || encodedUid == null) return null;
    final viewerUid = isWap ? encodedUid : unrotateViewerUid32(encodedUid);
    final issuedMillis = seqId - viewerUid;
    if (issuedMillis <= 0) return null;

    final issuedAt = DateTime.fromMillisecondsSinceEpoch(issuedMillis, isUtc: true);
    if (issuedAt.isBefore(DateTime.utc(2020)) || issuedAt.isAfter(DateTime.utc(2100))) return null;
    final signedInvalidAt = _signedUrlInvalidAtFromQuery(query);
    if (signedInvalidAt != null && issuedAt.isAfter(signedInvalidAt)) return null;
    return issuedAt;
  }

  // ignore: constant_identifier_names
  static const String HYSDK_UA = HuyaRequestParams.hysdkUa;
  // Frozen from the current official room bootstrap bundle. This is the TARS
  // identity passed to TafLink.getUserId(), not the browser HTTP User-Agent.
  static const String webPlaybackTarsUserAgent = 'webh5&0.1.0&websocket';
  static const int webPlaybackAppId = 66;
  static const int webPlaybackTokenLoopTime = 0;
  static const String fallbackPlayUserAgent = HuyaRequestParams.kUserAgent;
  static Map<String, String> requestHeaders = {'Origin': baseUrl, 'Referer': baseUrl, 'User-Agent': HYSDK_UA};

  /// Huya's public room detail currently returns `userCount` and
  /// `totalCount` as the same multi-million popularity value. Treating
  /// `userCount` as a concurrent head count relabels heat as people online.
  /// Current website captures show URI 8006 `iAttendeeCount` in the same
  /// multi-million range, so it is also kept as popularity rather than a
  /// concurrent-viewer head count.
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

  /// Exposes only rates returned by Huya. The old fallback invented a 2000
  /// kbps "高清" option when the room returned no rate list, so tapping it
  /// could only reopen the same source stream while the UI claimed a change.
  @visibleForTesting
  static List<LivePlayQuality> parsePlayQualities(HuyaUrlDataModel data) {
    final playbackLines = List<HuyaLineModel>.unmodifiable(data.lines);
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
            data: <String, Object>{'urls': playbackLines, 'bitRate': rate.bitRate},
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
    final lines = rawLines.whereType<HuyaLineModel>().toList(growable: false);
    // Each CDN token request is independent. Resolving them serially multiplied
    // startup time by the line count and made a normal quality switch look like
    // a player freeze. Keep the server priority order, but also isolate a bad
    // token/template to its own CDN. Huya can roll AntiCode material per line;
    // one malformed or already-expired line must not discard every healthy FLV
    // and HLS alternative returned in the same room snapshot.
    final resolved = await Future.wait<String>(
      lines.map((line) async {
        try {
          return await getPlayUrl(line, bitRate);
        } on Object catch (error) {
          CoreLog.error('Huya ${line.cdnType} ${line.lineType.name} URL resolve failed: ${error.runtimeType}');
          return '';
        }
      }),
    );
    final urls = <String>[];
    for (final url in resolved) {
      if (url.isNotEmpty && !urls.contains(url)) urls.add(url);
    }
    return urls;
  }

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsForRecoveryRaw({
    required LiveRoom detail,
    required LivePlayQuality quality,
  }) async {
    final roomId = detail.roomId?.trim() ?? '';
    final platform = detail.platform?.trim().isNotEmpty == true ? detail.platform! : Sites.huyaSite;
    if (roomId.isEmpty) return LivePlayUrlResolution(urls: const <String>[], appliedQualityData: quality.selectionId);

    // Reacquire the room template and build a fresh viewer signature. HLS
    // AntiCode material lives in the room snapshot, while FLV additionally
    // obtains a WUP token when that template is unusable or expired.
    final refreshedDetail = await getRoomDetailForRecording(platform: platform, roomId: roomId);
    if (refreshedDetail.isExplicitlyOfflineNow) {
      return LivePlayUrlResolution(urls: const <String>[], appliedQualityData: quality.selectionId);
    }
    final refreshedQualities = await getPlayQualites(detail: refreshedDetail);
    if (refreshedQualities.isEmpty) {
      return LivePlayUrlResolution(urls: const <String>[], appliedQualityData: quality.selectionId);
    }
    final requestedId = quality.selectionId.toString();
    final refreshedQuality = refreshedQualities.firstWhere(
      (item) => item.selectionId.toString() == requestedId,
      orElse: () => refreshedQualities.first,
    );
    return LivePlayUrlResolution(
      urls: await getPlayUrls(detail: refreshedDetail, quality: refreshedQuality),
      appliedQualityData: refreshedQuality.selectionId,
    );
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
    HuyaViewerIdentity? viewer;
    HuyaCdnTokenLease? tokenLease;
    // Select signing material by transport before any fallback. Starting every
    // line from HLS AntiCode made an FLV WUP failure accidentally reuse the HLS
    // token; both strings happen to match for many rooms, but Huya does not
    // promise that invariant.
    var antiCode = line.lineType == HuyaLineType.flv ? line.flvAntiCode.trim() : line.hlsAntiCode.trim();
    var signatureAlreadyBuilt = false;
    if (line.lineType == HuyaLineType.flv) {
      final roomFlvAntiCode = line.flvAntiCode.trim();
      final isLegacyStaticToken = !RegExp(r'(^|&)fm=').hasMatch(roomFlvAntiCode);
      // The official web player opens a fresh room with the room-provided FLV
      // template. It asks getCdnTokenInfoEx only after that lease expires.
      // Refreshing an already-valid room template on every open changes the
      // token family unnecessarily and was the first invalid state behind the
      // Windows FLV 403 -> HLS fallback -> visible black-screen delay.
      if (isLegacyStaticToken) {
        antiCode = roomFlvAntiCode;
      } else {
        viewer = await resolveViewerIdentity();
        try {
          antiCode = buildAntiCode(line.streamName, viewer.uid, roomFlvAntiCode);
          signatureAlreadyBuilt = true;
        } on Object catch (roomTokenError) {
          CoreLog.error('Huya room FLV token is unusable: ${roomTokenError.runtimeType}');
          try {
            tokenLease = await getCndTokenInfoEx(line, viewer);
            antiCode = tokenLease.antiCode.trim();
          } catch (refreshError) {
            CoreLog.error('Huya fresh FLV token request failed: ${refreshError.runtimeType}');
          }
        }
      }
      if (antiCode.isEmpty) antiCode = roomFlvAntiCode;
    }
    if (antiCode.isEmpty) {
      final protocol = line.lineType == HuyaLineType.hls ? 'HLS' : 'FLV';
      throw StateError('Huya $protocol token is unavailable');
    }
    // `viewer.uid`, rather than `line.presenterUid`, is the identity used by
    // Huya's current web player. Queries without `fm` are legacy fixtures and
    // remain as-is.
    if (!signatureAlreadyBuilt && RegExp(r'(^|&)fm=').hasMatch(antiCode)) {
      viewer ??= await resolveViewerIdentity();
      antiCode = buildAntiCode(line.streamName, viewer.uid, antiCode);
    }

    final extension = line.lineType == HuyaLineType.hls ? 'm3u8' : 'flv';
    final cdnBase = secureHuyaCdnBase(line.line);
    if (!RegExp(r'(^|&)codec=').hasMatch(antiCode)) antiCode = '$antiCode&codec=264';
    // Huya reuses one anti-leech query for every quality. `ratio`, when
    // already present, describes the URL captured from the page rather than
    // the user's new selection. Always replace it for a transcode and remove
    // it for source quality (bitRate=0), matching the current web extractor.
    antiCode = replaceQueryParameter(antiCode, 'ratio', bitRate > 0 ? '$bitRate' : null);
    final url = '$cdnBase/${line.streamName}.$extension?$antiCode';
    // Current AntiCode templates encode the issue instant through seqid. Some
    // legacy/static token families do not. The CDN transport can still end far
    // earlier than wsTime, so remember the connection issue instant for every
    // URL constructed by this site instance. This keeps legacy lines on the
    // same proactive hand-off path instead of waiting for a black-screen EOF.
    _rememberTransportIssuedAt(url, getSignedSequenceIssuedAt(url) ?? DateTime.now().toUtc());
    if (tokenLease != null) _rememberPlaybackTokenLease(url, tokenLease);
    return url;
  }

  void _rememberTransportIssuedAt(String url, DateTime issuedAt) {
    final key = _playbackTokenLeaseKey(url);
    if (_playbackTransportIssuedAt.length >= 64 && !_playbackTransportIssuedAt.containsKey(key)) {
      _playbackTransportIssuedAt.remove(_playbackTransportIssuedAt.keys.first);
    }
    _playbackTransportIssuedAt[key] = issuedAt.toUtc();
  }

  DateTime? _getRememberedTransportIssuedAt(String url) {
    // Keep a past deadline authoritative. Removing it exactly at expiry would
    // reveal the much later wsTime bound and incorrectly make a dead URL look
    // healthy again.
    return _playbackTransportIssuedAt[_playbackTokenLeaseKey(url)];
  }

  void _rememberPlaybackTokenLease(String url, HuyaCdnTokenLease lease) {
    final now = DateTime.now().toUtc();
    _playbackTokenLeases.removeWhere((_, value) => value.isExpired(now));
    final key = _playbackTokenLeaseKey(url);
    if (_playbackTokenLeases.length >= 32 && !_playbackTokenLeases.containsKey(key)) {
      final oldestKey = _playbackTokenLeases.keys.first;
      _playbackTokenLeases.remove(oldestKey);
    }
    _playbackTokenLeases[key] = lease;
  }

  HuyaCdnTokenLease? _getPlaybackTokenLease(String url) {
    // Keep an expired entry until the next URL is registered. Forgetting it at
    // the exact expiry instant would make the longer wsTime bound appear valid
    // again and postpone a recovery that is already due.
    return _playbackTokenLeases[_playbackTokenLeaseKey(url)];
  }

  static String _playbackTokenLeaseKey(String url) => sha256.convert(utf8.encode(url)).toString();

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
    var resultText = await HttpClient.instance.getText(
      'https://mp.huya.com/cache.php',
      queryParameters: <String, dynamic>{
        'm': 'Live',
        'do': 'profileRoom',
        'roomid': roomId,
        'showSecret': 1,
        // The endpoint advertises a 30-second public cache. Room entry and an
        // explicit refresh need an authoritative transition instead of a
        // previously cached ON response after the anchor has stopped.
        '_': DateTime.now().millisecondsSinceEpoch,
      },
      header: {
        'Accept': '*/*',
        'Origin': 'https://www.huya.com',
        'Referer': 'https://www.huya.com/',
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'same-site',
        "user-agent": kUserAgent,
        "Cookie": SettingsService.to.cookieManager.huyaCookie.v,
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    );
    final result = json.decode(resultText);
    final statusCode = result is Map ? int.tryParse(result['status']?.toString() ?? '') : null;
    final responseData = result is Map && result['data'] is Map ? result['data'] as Map : null;
    final normalizedLiveState = responseData?['liveStatus']?.toString().trim().toUpperCase() ?? '';
    if (statusCode == 200 && responseData != null && isExplicitOfflineState(responseData['liveStatus'])) {
      return _buildInactiveRoom(responseData, platform: platform, roomId: roomId);
    }
    if (statusCode == 200 && responseData != null && responseData['stream'] != null) {
      dynamic data = responseData;
      var topSid = 0;
      var subSid = 0;
      var huyaLines = <HuyaLineModel>[];
      var huyaBiterates = <HuyaBitRateModel>[];
      //读取可用线路

      var baseSteamInfoList = data['stream']['baseSteamInfoList'] as List<dynamic>;

      var flvLines = data['stream']['flv']['multiLine'];
      var hlsLines = data['stream']['hls']['multiLine'];
      if (flvLines != null) {
        for (var item in flvLines) {
          if ((item["url"]?.toString() ?? "").isNotEmpty) {
            var currentStream = baseSteamInfoList.firstWhere(
              (element) => element["sCdnType"] == item["cdnType"],
              orElse: () => null,
            );
            if (currentStream != null) {
              topSid = currentStream["lChannelId"].runtimeType == String
                  ? int.tryParse(currentStream["lChannelId"].toString()) ?? 0
                  : currentStream["lChannelId"];
              subSid = currentStream["lSubChannelId"].runtimeType == String
                  ? int.tryParse(currentStream["lSubChannelId"].toString()) ?? 0
                  : currentStream["lSubChannelId"];
              huyaLines.add(
                HuyaLineModel(
                  line: currentStream['sFlvUrl'],
                  lineType: HuyaLineType.flv,
                  flvAntiCode: currentStream["sFlvAntiCode"].toString(),
                  hlsAntiCode: currentStream["sHlsAntiCode"].toString(),
                  streamName: currentStream["sStreamName"].toString(),
                  cdnType: item["cdnType"].toString(),
                  presenterUid:
                      int.tryParse(currentStream['lPresenterUid']?.toString() ?? '') ??
                      int.tryParse(data['profileInfo']?['uid']?.toString() ?? '') ??
                      topSid,
                ),
              );
            }
          }
        }
      }

      if (hlsLines != null) {
        for (var item in hlsLines) {
          if ((item["url"]?.toString() ?? "").isNotEmpty) {
            var currentStream = baseSteamInfoList.firstWhere(
              (element) => element["sCdnType"] == item["cdnType"],
              orElse: () => null,
            );
            if (currentStream != null) {
              topSid = currentStream["lChannelId"].runtimeType == String
                  ? int.tryParse(currentStream["lChannelId"].toString()) ?? 0
                  : currentStream["lChannelId"];
              subSid = currentStream["lSubChannelId"].runtimeType == String
                  ? int.tryParse(currentStream["lSubChannelId"].toString()) ?? 0
                  : currentStream["lSubChannelId"];
              huyaLines.add(
                HuyaLineModel(
                  line: currentStream['sHlsUrl'],
                  lineType: HuyaLineType.hls,
                  flvAntiCode: currentStream["sFlvAntiCode"].toString(),
                  hlsAntiCode: currentStream["sHlsAntiCode"].toString(),
                  streamName: currentStream["sStreamName"].toString(),
                  cdnType: item["cdnType"].toString(),
                  presenterUid:
                      int.tryParse(currentStream['lPresenterUid']?.toString() ?? '') ??
                      int.tryParse(data['profileInfo']?['uid']?.toString() ?? '') ??
                      topSid,
                ),
              );
            }
          }
        }
      }
      //清晰度
      final encodedBitRates = data['liveData']['bitRateInfo'];
      dynamic rawBitRates;
      if (encodedBitRates is String && encodedBitRates.trim().isNotEmpty) {
        try {
          rawBitRates = jsonDecode(encodedBitRates);
        } catch (error) {
          CoreLog.error('Huya bitRateInfo decode failed: $error');
        }
      } else if (encodedBitRates is List) {
        rawBitRates = encodedBitRates;
      }
      rawBitRates ??= data['stream']['flv']['rateArray'];
      huyaBiterates.addAll(parseBitRates(rawBitRates));
      bool isXingxiu = data['liveData']['gid'] == 1663;
      final audience = parseRoomAudience(Map<String, dynamic>.from(data['liveData'] as Map));
      return LiveRoom(
        cover: data['liveData']?['screenshot'] ?? '',
        watching: audience.popularity,
        onlineViewers: audience.onlineViewers,
        popularity: audience.popularity,
        audienceMetricType: AudienceMetricType.popularity,
        roomId: roomId,
        area: data['liveData']?['gameFullName'] ?? '',
        title: data['liveData']?['introduction'] ?? '',
        nick: data['profileInfo']?['nick'] ?? '',
        avatar: data['profileInfo']?['avatar180'] ?? '',
        introduction: data['liveData']?['introduction'] ?? '',
        notice: data['welcomeText'] ?? '',
        isRecord: normalizedLiveState == 'REPLAY',
        status: normalizedLiveState == 'ON',
        liveStatus: parseHuyaLiveStatus(normalizedLiveState),
        platform: Sites.huyaSite,
        data: HuyaUrlDataModel(url: "", lines: huyaLines, bitRates: huyaBiterates, uid: "", isXingxiu: isXingxiu),
        danmakuData: HuyaDanmakuArgs(
          uid: int.tryParse(data["profileInfo"]?["uid"]?.toString() ?? "") ?? 0,
          topSid: topSid,
          subSid: subSid,
        ),
        link: "https://www.huya.com/$roomId",
      );
    } else {
      if (!allowUiFallback) {
        throw const FormatException('Huya room playback metadata is unavailable');
      }
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

  @visibleForTesting
  static bool isExplicitOfflineState(Object? value) {
    final normalized = value?.toString().trim().toUpperCase() ?? '';
    return const {'OFF', 'OFFLINE', 'CLOSED'}.contains(normalized);
  }

  @visibleForTesting
  static LiveStatus parseHuyaLiveStatus(Object? value) {
    return switch (value?.toString().trim().toUpperCase()) {
      'ON' => LiveStatus.live,
      'REPLAY' => LiveStatus.replay,
      'OFF' || 'OFFLINE' || 'CLOSED' => LiveStatus.offline,
      _ => LiveStatus.unknown,
    };
  }

  LiveRoom _buildInactiveRoom(Map<dynamic, dynamic> data, {required String platform, required String roomId}) {
    final liveData = data['liveData'] is Map
        ? Map<String, dynamic>.from(data['liveData'] as Map)
        : const <String, dynamic>{};
    final profile = data['profileInfo'] is Map ? data['profileInfo'] as Map : const <dynamic, dynamic>{};
    final audience = parseRoomAudience(liveData);
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
      isRecord: false,
      status: false,
      liveStatus: LiveStatus.offline,
      platform: platform,
      link: 'https://www.huya.com/$roomId',
    );
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
      'https://mp.huya.com/cache.php',
      queryParameters: <String, dynamic>{
        'm': 'Live',
        'do': 'profileRoom',
        'roomid': roomId,
        'showSecret': 1,
        '_': DateTime.now().millisecondsSinceEpoch,
      },
      header: {
        'Accept': '*/*',
        'Origin': 'https://www.huya.com',
        'Referer': 'https://www.huya.com/',
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'same-site',
        'user-agent': kUserAgent,
        'Cookie': SettingsService.to.cookieManager.huyaCookie.v,
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
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
    final liveStatus = parseHuyaLiveStatus(state);
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
      status: liveStatus == LiveStatus.live,
      liveStatus: liveStatus,
      platform: Sites.huyaSite,
      link: 'https://www.huya.com/$roomId',
    );
  }

  String? findRoomId(List list, int targetUid, int targetYyid) {
    try {
      final matchingObject = list.firstWhere(
        (item) => item['uid'] == targetUid && item['yyid'] == targetYyid,
        orElse: () => throw StateError("No matching object found"), // 当找不到匹配项时抛出错误
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
    final room = await getRoomDetailForRefresh(platform: platform, roomId: roomId);
    return room.isLiveNow;
  }

  /// 匿名登录获取uid
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

  /// Resolves the viewer identity used by Huya's current web signature.
  ///
  /// `lPresenterUid` identifies the anchor and must never be substituted for
  /// the viewer. The official web client uses `yyuid` for an account session
  /// and the UID returned by `anonymousLogin` otherwise.
  Future<HuyaViewerIdentity> resolveViewerIdentity({String? cookie}) async {
    final resolvedCookie = cookie ?? SettingsService.to.cookieManager.huyaCookie.v;
    final accountUid = parseViewerUidFromCookie(resolvedCookie);
    if (accountUid != null) {
      return HuyaViewerIdentity(uid: accountUid, guid: _viewerGuid, isAnonymous: false);
    }

    final cached = _anonymousViewerIdentity;
    if (cached != null) return cached;
    final pending = _anonymousViewerIdentityRequest;
    if (pending != null) return pending;

    final request = _loadAnonymousViewerIdentity();
    _anonymousViewerIdentityRequest = request;
    try {
      final identity = await request;
      // A locally generated fallback keeps one already-open recovery attempt
      // deterministic, but it is not an identity acknowledged by Huya's
      // anonymous-login service. Caching it for the whole process made a brief
      // endpoint outage turn into persistent 403s until the app restarted.
      // Keep the fallback UID stable, yet retry the official endpoint on the
      // next independent source acquisition.
      if (identity.uid != _fallbackViewerUid) {
        _anonymousViewerIdentity = identity;
      }
      return identity;
    } finally {
      if (identical(_anonymousViewerIdentityRequest, request)) {
        _anonymousViewerIdentityRequest = null;
      }
    }
  }

  Future<HuyaViewerIdentity> _loadAnonymousViewerIdentity() async {
    try {
      final uid = int.tryParse((await getAnonymousUid()).trim());
      if (uid != null && uid > 0) {
        return HuyaViewerIdentity(uid: uid, guid: _viewerGuid, isAnonymous: true);
      }
    } catch (error) {
      CoreLog.error('Huya anonymous viewer identity request failed: ${error.runtimeType}');
    }
    // The fallback remains a viewer-shaped UID and is stable for this process.
    // The next independent source acquisition on this site instance retries the
    // official anonymous session endpoint.
    return HuyaViewerIdentity(uid: _fallbackViewerUid, guid: _viewerGuid, isAnonymous: true);
  }

  @visibleForTesting
  static int? parseViewerUidFromCookie(String cookie) {
    final match = RegExp(r'(?:^|;\s*)yyuid=(\d+)(?:;|$)').firstMatch(cookie);
    final uid = int.tryParse(match?.group(1) ?? '');
    return uid != null && uid > 0 ? uid : null;
  }

  static String _createViewerGuid() {
    final random = Random.secure();
    const alphabet = '0123456789abcdef';
    return List<String>.generate(32, (_) => alphabet[random.nextInt(alphabet.length)]).join();
  }

  static int _createFallbackViewerUid() {
    final random = Random.secure();
    // Random.nextInt is limited to 2^32, so requesting a 100-billion range
    // throws exactly when anonymousLogin is unavailable and the fallback is
    // first evaluated. Compose two supported uniform ranges instead.
    final offset = random.nextInt(1000000) * 100000 + random.nextInt(100000);
    return 1400000000000 + offset;
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

  /// Builds the per-open AntiCode using the viewer UID and the server-issued
  /// expiry. The official player refreshes the WUP token before expiry; it
  /// never extends `wsTime` locally.
  String buildAntiCode(String stream, int viewerUid, String antiCode, {DateTime? now}) {
    final original = Uri(query: antiCode).queryParameters;
    final encodedFm = original['fm']?.trim() ?? '';
    if (encodedFm.isEmpty) {
      return antiCode;
    }

    final ctype = original['ctype']?.trim().isNotEmpty == true ? original['ctype']!.trim() : 'huya_webh5';
    final platformId = original['t']?.trim().isNotEmpty == true ? original['t']!.trim() : '100';
    final isWap = platformId == '103';
    final timestamp = now ?? DateTime.now();
    final currentMillis = timestamp.millisecondsSinceEpoch;
    final currentSeconds = currentMillis ~/ 1000;
    final uid = viewerUid > 0 ? viewerUid : _fallbackViewerUid;

    final wsTimeRaw = original['wsTime']?.trim() ?? '';
    final wsTimeSeconds = int.tryParse(wsTimeRaw, radix: 16);
    if (wsTimeSeconds == null) {
      throw const FormatException('Huya AntiCode has no valid wsTime');
    }
    if (currentSeconds > wsTimeSeconds + const Duration(minutes: 5).inSeconds) {
      throw StateError('Huya AntiCode lease expired');
    }
    final wsTime = wsTimeRaw.toLowerCase();
    final seqId = uid + currentMillis;
    final secretHash = md5.convert(utf8.encode('$seqId|$ctype|$platformId')).toString();

    final convertUid = rotateViewerUid32(uid);
    final calcUid = isWap ? uid : convertUid;
    // The official player treats `fm` as a server-owned template and replaces
    // its four placeholders in place.  Splitting on `_` and rebuilding a
    // presumed `prefix_$0_$1_$2_$3` layout happened to work for the current
    // token family, but would silently sign the wrong string as soon as Huya
    // adds a field, changes a separator or moves a placeholder.  Preserve the
    // complete decoded template instead.
    final secretTemplate = utf8.decode(base64.decode(base64.normalize(encodedFm)));
    if (!const <String>[r'$0', r'$1', r'$2', r'$3'].every(secretTemplate.contains)) {
      throw const FormatException('Huya AntiCode fm template is incomplete');
    }
    final secretStr = secretTemplate
        .replaceFirst(r'$0', calcUid.toString())
        .replaceFirst(r'$1', stream)
        .replaceFirst(r'$2', secretHash)
        .replaceFirst(r'$3', wsTime);
    final wsSecret = md5.convert(utf8.encode(secretStr)).toString();

    final rnd = Random();
    final ct = ((wsTimeSeconds + rnd.nextDouble()) * 1000).toInt();
    final uuid = (((ct % 1e10) + rnd.nextDouble()) * 1e3 % 0xffffffff).toInt().toString();
    final antiCodeRes = <String, String>{...original}
      ..remove('wsSecret')
      ..remove('seqid')
      ..remove('u')
      ..remove('uid')
      ..remove('uuid')
      // `fm` is signing material, not a media query field.  The official web
      // player consumes it locally and omits it from the emitted CDN URL.
      ..remove('fm')
      ..addAll(<String, String>{
        'wsSecret': wsSecret,
        'wsTime': wsTime,
        'seqid': seqId.toString(),
        'ctype': ctype,
        'ver': '1',
        'fs': original['fs'] ?? 'bgct',
        't': platformId,
      });
    if (isWap) {
      antiCodeRes.addAll({'uid': uid.toString(), 'uuid': uuid});
    } else {
      antiCodeRes['u'] = convertUid.toString();
    }

    return Uri(queryParameters: antiCodeRes).query;
  }

  Future<HuyaCdnTokenLease> getCndTokenInfoEx(HuyaLineModel line, HuyaViewerIdentity viewer) async {
    final key = '${viewer.uid}|${line.line}|${line.streamName}';
    final current = _inFlightTokenRequests[key];
    if (current != null) return current;

    final request = _fetchCdnTokenInfoEx(line, viewer);
    _inFlightTokenRequests[key] = request;
    try {
      return await request;
    } finally {
      if (identical(_inFlightTokenRequests[key], request)) {
        _inFlightTokenRequests.remove(key);
      }
    }
  }

  Future<HuyaCdnTokenLease> _fetchCdnTokenInfoEx(HuyaLineModel line, HuyaViewerIdentity viewer) async {
    final cookie = SettingsService.to.cookieManager.huyaCookie.v.trim();
    final request = buildPlaybackTokenRequest(line, viewer, cookie: cookie);
    final tokenClient = BaseTarsHttp(
      "https://wup.huya.com",
      "liveui",
      headers: <String, String>{
        'Origin': baseUrl,
        'Referer': '$baseUrl/',
        'User-Agent': fallbackPlayUserAgent,
        if (cookie.isNotEmpty) 'Cookie': cookie,
      },
    );
    final response = await tokenClient.tupRequest('getCdnTokenInfoEx', request, GetCdnTokenExResp());
    return HuyaCdnTokenLease.fromResponse(response);
  }

  @visibleForTesting
  static GetCdnTokenExReq buildPlaybackTokenRequest(
    HuyaLineModel line,
    HuyaViewerIdentity viewer, {
    String cookie = '',
  }) {
    return GetCdnTokenExReq()
      ..sFlvUrl = secureHuyaCdnBase(line.line)
      ..sStreamName = line.streamName
      ..iLoopTime = webPlaybackTokenLoopTime
      ..tId = buildPlaybackTokenUserId(viewer, cookie: cookie)
      ..iAppId = webPlaybackAppId;
  }

  @visibleForTesting
  static HuyaUserId buildPlaybackTokenUserId(HuyaViewerIdentity viewer, {String cookie = ''}) {
    // Huya's current web bundle passes TafLink.getUserId() to
    // getCdnTokenInfoEx. That identity is webh5 + the page cookie, rather than
    // the desktop HYSDK/pc_exe identity used by unrelated legacy WUP calls.
    return HuyaUserId()
      ..lUid = viewer.uid
      ..sGuid = viewer.guid
      ..sToken = ''
      ..sHuYaUA = webPlaybackTarsUserAgent
      ..sCookie = cookie
      ..iTokenType = 0;
  }

  @visibleForTesting
  static int rotateViewerUid32(int value) {
    // Huya's web player names this operation `rotl64`: only the low 32-bit
    // lane is rotated, while the upper 32-bit lane of the 64-bit viewer UID is
    // preserved. Returning only the rotated low lane happens to look valid for
    // small fixture UIDs, but truncates real anonymous UIDs (normally > 2^32).
    // The resulting `u` then no longer matches the WUP viewer identity and the
    // FLV CDN rejects the otherwise well-formed URL with HTTP 403.
    final low = value & 0xffffffff;
    final high = value - low;
    final rotatedLow = ((low << 8) | (low >> 24)) & 0xffffffff;
    return high | rotatedLow;
  }

  @visibleForTesting
  static int unrotateViewerUid32(int value) {
    final low = value & 0xffffffff;
    final high = value - low;
    final originalLow = ((low >> 8) | (low << 24)) & 0xffffffff;
    return high | originalLow;
  }

  Future<List<LiveSuperChatMessage>> getHuyaSuperChatMessageList({required int lPid, bool first = false}) async {
    final BaseTarsHttp messageBoardClient = BaseTarsHttp(
      "https://wup.huya.com",
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
      // start_time---cur--->end_time
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

@immutable
class HuyaViewerIdentity {
  const HuyaViewerIdentity({required this.uid, required this.guid, required this.isAnonymous});

  final int uid;
  final String guid;
  final bool isAnonymous;
}

@immutable
class HuyaCdnTokenLease {
  const HuyaCdnTokenLease({
    required this.antiCode,
    required this.invalidAt,
    required this.refreshAt,
    required this.serverExpireValue,
  });

  factory HuyaCdnTokenLease.fromResponse(GetCdnTokenExResp response, {DateTime? now}) {
    final antiCode = response.sFlvToken.trim();
    if (antiCode.isEmpty) throw const FormatException('Huya WUP returned an empty FLV token');
    final query = Uri(query: antiCode).queryParameters;
    final wsTime = int.tryParse(query['wsTime'] ?? '', radix: 16);
    if (wsTime == null) throw const FormatException('Huya WUP token has no valid wsTime');

    // This matches the current official player: wsTime receives a five-minute
    // validity allowance and the refresh is requested thirty seconds earlier.
    var invalidAt = DateTime.fromMillisecondsSinceEpoch(wsTime * 1000, isUtc: true).add(const Duration(minutes: 5));
    final current = (now ?? DateTime.now()).toUtc();
    final serverExpiry = response.iExpireTime;
    if (serverExpiry > 0) {
      final serverInvalidAt = serverExpiry > 1000000000000
          ? DateTime.fromMillisecondsSinceEpoch(serverExpiry, isUtc: true)
          : serverExpiry > 1000000000
          ? DateTime.fromMillisecondsSinceEpoch(serverExpiry * 1000, isUtc: true)
          : current.add(Duration(seconds: serverExpiry));
      if (serverInvalidAt.isBefore(invalidAt)) invalidAt = serverInvalidAt;
    }
    return HuyaCdnTokenLease(
      antiCode: antiCode,
      invalidAt: invalidAt,
      refreshAt: invalidAt.subtract(const Duration(seconds: 30)),
      serverExpireValue: serverExpiry,
    );
  }

  final String antiCode;
  final DateTime invalidAt;
  final DateTime refreshAt;
  final int serverExpireValue;

  bool needsRefresh(DateTime timestamp) => !timestamp.toUtc().isBefore(refreshAt);
  bool isExpired(DateTime timestamp) => !timestamp.toUtc().isBefore(invalidAt);
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
    final host = Uri.tryParse(line)?.host;
    return 'HuyaLineModel{host: ${host?.isNotEmpty == true ? host : 'unknown'}, lineType: $lineType, cdnType: $cdnType, bitRate: $bitRate}';
  }
}

class HuyaBitRateModel {
  final String name;
  final int bitRate;
  HuyaBitRateModel({required this.bitRate, required this.name});
}
