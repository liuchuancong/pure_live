import 'dart:math';
import 'dart:convert';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/model/live_anchor_item.dart';
import 'package:pure_live/core/common/android_native_http.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/danmaku/twitch_danmaku.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/utils/twitch/twitch_models.dart';
import 'package:pure_live/core/utils/twitch/twitch_web_integrity.dart';
import 'package:pure_live/core/utils/live_quality_label.dart';

class TwitchSite implements LiveSite, LiveSiteRoomRefresher, LiveSiteRecordRoomResolver {
  @override
  String id = Sites.twitchSite;

  @override
  String name = 'Twitch';

  static const defaultUa =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36";
  static const gplApiUrl = "https://gql.twitch.tv/gql";

  static const integrityApiUrl = "https://gql.twitch.tv/integrity";

  static const baseUrl = "https://www.twitch.tv";

  Map<String, String> cursorMap = {};
  late final String _deviceId = generateDeviceId();
  String? _integrityToken;
  DateTime? _integrityExpiresAt;
  Future<void>? _integrityRefresh;
  bool _bypassStoredSessionForIntegrity = false;

  Map<String, String> headers = {
    'User-Agent': defaultUa,
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept': 'application/vnd.twitchtv.v5+json',
    'Accept-Encoding': 'gzip, deflate',
    'Client-ID': 'kimne78kx3ncx6brgo4mv6wki5h1ko',
    'Origin': baseUrl,
    'Referer': '$baseUrl/',
  };

  final playSessionIds = ["bdd22331a986c7f1073628f2fc5b19da", "064bc3ff1722b6f53b0b5b8c01e46ca5"];

  void getRequestHeaders() {
    // Twitch binds a Client-Integrity token to `Device-Id` on GraphQL
    // requests. `X-Device-Id` is used only while minting the token at the
    // /integrity endpoint (matching Twitch's web flow and Streamlink).
    headers['Device-Id'] = _deviceId;
    headers.remove('X-Device-Id');
    final cookie = SettingsService.to.cookieManager.twitchCookie.v.trim();
    if (cookie.isNotEmpty && !_bypassStoredSessionForIntegrity) {
      headers['Cookie'] = cookie;
      final authToken = extractAuthToken(cookie);
      if (authToken != null) {
        headers['Authorization'] = 'OAuth $authToken';
      } else {
        headers.remove('Authorization');
      }
    } else {
      headers.remove('Cookie');
      headers.remove('Authorization');
    }
  }

  @visibleForTesting
  static String? extractAuthToken(String cookie) {
    for (final part in cookie.split(';')) {
      final separator = part.indexOf('=');
      if (separator <= 0) continue;
      if (part.substring(0, separator).trim().toLowerCase() != 'auth-token') continue;
      final value = part.substring(separator + 1).trim();
      return value.isEmpty ? null : value;
    }
    return null;
  }

  @visibleForTesting
  static String generateDeviceId([Random? source]) {
    final random = source ?? Random.secure();
    const hex = '0123456789abcdef';
    return List<String>.generate(32, (_) => hex[random.nextInt(hex.length)]).join();
  }

  String buildPersistedRequest(String operationName, String sha265Hash, Map<String, dynamic> variables) {
    return jsonEncode({
      'operationName': operationName,
      'extensions': {
        'persistedQuery': {'version': 1, 'sha256Hash': sha265Hash},
      },
      'variables': variables,
    });
  }

  Future<dynamic> getGplResponse(String liveGpl) async {
    getRequestHeaders();
    dynamic response;
    Object? nativeError;
    StackTrace? nativeStackTrace;

    // Twitch's web player tries the public request without Client-Integrity
    // first. This is both faster in regions where the token is optional and
    // avoids needlessly binding the request to a short-lived identity.
    try {
      response = await _postGql(liveGpl);
      if (!hasIntegrityError(response)) return response;

      _invalidateIntegrityToken();
    } catch (error, stackTrace) {
      nativeError = error;
      nativeStackTrace = stackTrace;
      CoreLog.e('Twitch native GraphQL transport failed: $error', stackTrace);
    }

    // Some Android proxy paths accept CONNECT and then reset dart:io's TLS
    // socket. Retry the exact request through Android's platform TLS stack
    // before involving Chromium/KPSDK. The native channel is host-allowlisted
    // to gql.twitch.tv and is intentionally unavailable on other platforms.
    if (AndroidNativeHttp.isSupported) {
      try {
        response = await _postAndroidSystemGql(liveGpl);
        if (!hasIntegrityError(response)) return response;

        _invalidateIntegrityToken();
        await _ensureIntegrityToken();
        response = await _postAndroidSystemGql(liveGpl);
        if (!hasIntegrityError(response)) return response;
      } catch (error, stackTrace) {
        nativeError = error;
        nativeStackTrace = stackTrace;
        CoreLog.e('Twitch Android-system GraphQL transport failed: $error', stackTrace);
      }
    }

    if (headers.containsKey('Cookie') || headers.containsKey('Authorization')) {
      // Preserve the saved account setting, but do not let a stale account
      // cookie poison public browsing. The bypass is local to this site
      // instance and never mutates the user's stored cookie.
      _bypassStoredSessionForIntegrity = true;
      getRequestHeaders();
      _invalidateIntegrityToken();
      try {
        response = await _postGql(liveGpl);
        if (!hasIntegrityError(response)) return response;
      } catch (error, stackTrace) {
        nativeError = error;
        nativeStackTrace = stackTrace;
      }
      if (AndroidNativeHttp.isSupported) {
        try {
          response = await _postAndroidSystemGql(liveGpl);
          if (!hasIntegrityError(response)) return response;

          _invalidateIntegrityToken();
          await _ensureIntegrityToken();
          response = await _postAndroidSystemGql(liveGpl);
          if (!hasIntegrityError(response)) return response;
        } catch (error, stackTrace) {
          nativeError = error;
          nativeStackTrace = stackTrace;
        }
      }
      CoreLog.w('Twitch stored session failed validation; public requests switched to an anonymous session');
    }

    // Android's dart:io TLS fingerprint is sometimes reset after CONNECT even
    // though the same proxy works in Chrome. Execute the public request inside
    // Chromium as the final transport, rather than minting a browser token and
    // replaying it through the already-rejected native socket stack.
    if (TwitchWebIntegrityProvider.isSupported) {
      final proxy = SettingsService.to.proxy;
      Object? browserError;
      StackTrace? browserStackTrace;
      try {
        final browserResponse = await TwitchWebIntegrityProvider.postGraphQl(
          body: liveGpl,
          clientId: headers['Client-ID']!,
          deviceId: _deviceId,
          userAgent: headers['User-Agent']!,
          integrityToken: _usableIntegrityToken,
          onIntegrityToken: _applyBrowserIntegrityToken,
          proxyHost: proxy.enableAppProxy.v ? proxy.appProxyHost.v : null,
          proxyPort: proxy.enableAppProxy.v ? proxy.appProxyPort.v : null,
        );
        if (browserResponse != null && !hasIntegrityError(browserResponse)) {
          return browserResponse;
        }
        if (browserResponse != null) {
          throw StateError('Twitch Chromium GraphQL response still failed integrity validation');
        }
      } catch (error, stackTrace) {
        CoreLog.e('Twitch Chromium GraphQL transport failed: $error', stackTrace);
        browserError = error;
        browserStackTrace = stackTrace;
      }
      // The browser fallback is the last and most capable transport. Surface
      // its diagnostic rather than an earlier Dart socket error so production
      // logs identify CORS/KPSDK/GraphQL failures precisely.
      if (browserError != null && browserStackTrace != null) {
        Error.throwWithStackTrace(browserError, browserStackTrace);
      }
    }

    if (nativeError != null && nativeStackTrace != null) {
      Error.throwWithStackTrace(nativeError, nativeStackTrace);
    }
    return response;
  }

  Future<dynamic> _postGql(String liveGpl) {
    final requestHeaders = _gqlRequestHeaders();
    return HttpClient.instance.postJson(gplApiUrl, header: requestHeaders, data: liveGpl);
  }

  Future<dynamic> _postAndroidSystemGql(String liveGpl) {
    final proxy = SettingsService.to.proxy;
    return AndroidNativeHttp.postTwitchJson(
      url: gplApiUrl,
      headers: _gqlRequestHeaders(),
      body: liveGpl,
      proxyHost: proxy.enableAppProxy.v ? proxy.appProxyHost.v : null,
      proxyPort: proxy.enableAppProxy.v ? proxy.appProxyPort.v : null,
    );
  }

  Map<String, String> _gqlRequestHeaders() {
    final requestHeaders = Map<String, String>.from(headers);
    final token = _integrityToken;
    if (token != null && token.isNotEmpty) {
      requestHeaders['Client-Integrity'] = token;
    }
    return requestHeaders;
  }

  Future<void> _ensureIntegrityToken() async {
    final token = _integrityToken;
    final expiry = _integrityExpiresAt;
    final now = DateTime.now();
    if (token != null && token.isNotEmpty && expiry != null && expiry.isAfter(now.add(const Duration(minutes: 5)))) {
      return;
    }

    final inFlight = _integrityRefresh;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final refresh = _refreshIntegrityToken();
    _integrityRefresh = refresh;
    try {
      await refresh;
    } finally {
      if (identical(_integrityRefresh, refresh)) {
        _integrityRefresh = null;
      }
    }
  }

  Future<void> _refreshIntegrityToken() async {
    if (TwitchWebIntegrityProvider.isSupported) {
      final proxy = SettingsService.to.proxy;
      try {
        final browserToken = await TwitchWebIntegrityProvider.acquire(
          clientId: headers['Client-ID']!,
          deviceId: _deviceId,
          userAgent: headers['User-Agent']!,
          proxyHost: proxy.enableAppProxy.v ? proxy.appProxyHost.v : null,
          proxyPort: proxy.enableAppProxy.v ? proxy.appProxyPort.v : null,
        );
        if (browserToken != null) {
          _applyBrowserIntegrityToken(browserToken);
          return;
        }
      } catch (error, stackTrace) {
        CoreLog.e('Twitch Chromium integrity acquisition failed: $error', stackTrace);
      }
    }

    final integrityHeaders = buildIntegrityHeaders(headers, _deviceId);
    final response = await HttpClient.instance.postJson(integrityApiUrl, header: integrityHeaders);
    final data = _stringMap(response);
    final token = data?['token']?.toString().trim() ?? '';
    final expiration = normalizeIntegrityExpirationMilliseconds(data?['expiration']);
    if (token.isEmpty || expiration == null) {
      throw StateError('Twitch integrity endpoint returned an incomplete token');
    }
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(expiration);
    if (!expiresAt.isAfter(DateTime.now())) {
      throw StateError('Twitch integrity endpoint returned an expired token');
    }
    _integrityToken = token;
    _integrityExpiresAt = expiresAt;
  }

  String? get _usableIntegrityToken {
    final token = _integrityToken;
    final expiresAt = _integrityExpiresAt;
    if (token == null || token.isEmpty || expiresAt == null) return null;
    return expiresAt.isAfter(DateTime.now().add(const Duration(seconds: 30))) ? token : null;
  }

  void _applyBrowserIntegrityToken(TwitchWebIntegrityToken browserToken) {
    final expiration = normalizeIntegrityExpirationMilliseconds(browserToken.expiration);
    if (expiration == null) {
      throw StateError('Twitch browser integrity token has an invalid expiration');
    }
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(expiration);
    if (!expiresAt.isAfter(DateTime.now())) {
      throw StateError('Twitch browser integrity token is already expired');
    }
    _integrityToken = browserToken.token;
    _integrityExpiresAt = expiresAt;
  }

  @visibleForTesting
  static Map<String, String> buildIntegrityHeaders(Map<String, String> requestHeaders, String deviceId) {
    return Map<String, String>.from(requestHeaders)
      ..remove('Client-Integrity')
      ..remove('Device-Id')
      ..['X-Device-Id'] = deviceId;
  }

  void _invalidateIntegrityToken() {
    _integrityToken = null;
    _integrityExpiresAt = null;
  }

  @visibleForTesting
  static int? normalizeIntegrityExpirationMilliseconds(dynamic value) {
    final parsed = switch (value) {
      int number => number,
      num number => number.toInt(),
      _ => int.tryParse(value?.toString() ?? ''),
    };
    if (parsed == null || parsed <= 0) return null;
    // Twitch/Streamlink expose this field as Unix seconds, while older API
    // captures used milliseconds. Accept both without treating a valid
    // seconds timestamp as a date in January 1970.
    return parsed < 100000000000 ? parsed * 1000 : parsed;
  }

  @visibleForTesting
  static bool hasIntegrityError(dynamic response) {
    if (response is List) return response.any(hasIntegrityError);
    final map = _stringMap(response);
    if (map == null) return false;
    final errors = map['errors'];
    if (errors is! List) return false;
    return errors.map(_stringMap).whereType<Map<String, dynamic>>().any((error) {
      final message = error['message']?.toString().toLowerCase() ?? '';
      return message.contains('failed integrity check') || message.contains('integrity token');
    });
  }

  String buildCursorKey(String type, String id, int page) {
    return "${type}_${id}_$page";
  }

  void saveCursor(String type, String id, int page, String value) {
    var key = buildCursorKey(type, id, page + 1);
    cursorMap[key] = value;
  }

  String getCursor(String type, String id, int page) {
    var key = buildCursorKey(type, id, page);
    return cursorMap[key] ?? "";
  }

  /// Reads a Twitch GraphQL connection without assuming that the optional
  /// `pageInfo` object is present.
  ///
  /// Twitch occasionally returns a usable first page of `edges` while
  /// omitting `pageInfo` (for example during partial directory responses).
  /// Treating the missing object as a dynamic map caused the whole visible
  /// page to fail with `NoSuchMethodError`. The first page is still valid; the
  /// only safe pagination decision in that case is to stop at that page.
  @visibleForTesting
  static ({List<Map<String, dynamic>> edges, bool hasNextPage}) parseConnection(dynamic rawConnection) {
    final connection = _stringMap(rawConnection);
    if (connection == null) return (edges: const <Map<String, dynamic>>[], hasNextPage: false);

    final rawEdges = connection['edges'];
    final edges = rawEdges is List
        ? rawEdges.map(_stringMap).whereType<Map<String, dynamic>>().toList(growable: false)
        : const <Map<String, dynamic>>[];
    final pageInfo = _stringMap(connection['pageInfo']);
    return (edges: edges, hasNextPage: pageInfo?['hasNextPage'] == true);
  }

  static Map<String, dynamic>? _stringMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, item) => MapEntry(key.toString(), item));
    return null;
  }

  static String _graphQlErrorSummary(Map<String, dynamic> envelope) {
    final errors = envelope['errors'];
    if (errors is! List || errors.isEmpty) return '';
    return errors
        .map(_stringMap)
        .whereType<Map<String, dynamic>>()
        .map((error) => error['message']?.toString().trim() ?? '')
        .where((message) => message.isNotEmpty)
        .join('; ');
  }

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    try {
      var liveGpl = buildPersistedRequest(
        "SearchCategoryTags",
        "b4cb189d8d17aadf29c61e9d7c7e7dcfc932e93b77b3209af5661bffb484195f",
        {"userQuery": "", "limit": 100},
      );

      var response = await getGplResponse(liveGpl);

      List<LiveCategory> categories = [];
      var data = response['data'];
      var searchCategoryTags = data['searchCategoryTags'];
      for (var item in searchCategoryTags) {
        categories.add(LiveCategory(id: item["id"], name: item["tagName"], children: []));
      }

      List<Future> futures = [];
      for (var item in categories) {
        futures.add(
          Future(() async {
            var items = await getAllSubCategores(item, 1, 30, []);
            item.children.addAll(items);
          }),
        );
      }
      await Future.wait(futures);
      return categories;
    } catch (error, stackTrace) {
      // A blocked/reset GraphQL connection is not the same as a successful
      // empty directory. Propagate it so the shared page controller can show
      // its retryable network-error state instead of the misleading
      // "no live rooms" empty state.
      CoreLog.e('Twitch directory request failed: $error', stackTrace);
      rethrow;
    }
  }

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
      CoreLog.error(e);
      return allSubCategores;
    }
  }

  Future<List<LiveArea>> getSubCategores(LiveCategory liveCategory, int page, int pageSize) async {
    var cursorType = "getSubCategores";
    var cursorId = liveCategory.id;
    String cursor = getCursor(cursorType, cursorId, page);
    if (cursor.isEmpty && page > 1) {
      return <LiveArea>[];
    }
    var liveGpl = buildPersistedRequest(
      "BrowsePage_AllDirectories",
      "2f67f71ba89f3c0ed26a141ec00da1defecb2303595f5cda4298169549783d9e",
      {
        "limit": pageSize.clamp(1, 100),
        "options": {
          "recommendationsContext": {"platform": "web"},
          "requestID": "JIRA-VXP-2397",
          "sort": "VIEWER_COUNT",
          "tags": [liveCategory.id],
        },
        if (cursor.isNotEmpty) "cursor": cursor,
      },
    );
    var response = await getGplResponse(liveGpl);

    final responseMap = _stringMap(response);
    final data = _stringMap(responseMap?['data']);
    final connection = parseConnection(data?['directoriesWithTags']);
    final edges = connection.edges;
    cursor = edges.isEmpty ? "" : (edges.last["cursor"]?.toString() ?? "");
    if (!connection.hasNextPage) cursor = "";
    saveCursor(cursorType, cursorId, page, cursor);
    List<LiveArea> subs = [];
    for (var item in edges) {
      var node = item['node'];
      var subCategory = LiveArea(
        areaId: node["id"],
        areaName: node["displayName"],
        shortName: node["slug"],
        areaType: liveCategory.id,
        platform: id,
        areaPic: (node["avatarURL"] ?? "").toString().replaceFirst("https://", "https://i2.wp.com/"),
        typeName: liveCategory.name,
      );
      subs.add(subCategory);
    }
    return subs;
  }

  @override
  LiveDanmaku getDanmaku() => TwitchDanmaku();

  @override
  Future<bool> getLiveStatus({required String platform, required String roomId}) async {
    try {
      var detail = await getRoomDetail(platform: platform, roomId: roomId);
      return detail.isLiveNow;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    List<LivePlayQuality> qualities = <LivePlayQuality>[];
    if (!detail.isLiveNow) return qualities;

    var liveGpl = buildPersistedRequest(
      "PlaybackAccessToken",
      "ed230aa1e33e07eebb8928504583da78a5173989fadfb1ac94be06a04f3cdbe9",
      {
        "isLive": true,
        "login": detail.roomId,
        "isVod": false,
        "vodID": "",
        "playerType": "site",
        "isClip": false,
        "clipID": "",
        "platform": "site",
      },
    );
    getRequestHeaders();
    var response = await getGplResponse(liveGpl);
    var token = response['data']['streamPlaybackAccessToken']['value'];
    var sign = response['data']['streamPlaybackAccessToken']['signature'];

    var random = Random.secure();
    var playSessionId = playSessionIds[random.nextInt(playSessionIds.length)];
    var params = {
      "acmb": "e30=",
      "allow_source": "true",
      "cdm": "wv",
      "fast_bread": "true",
      "p": random.nextInt(10000000).toString(),
      "platform": "web",
      "play_session_id": playSessionId,
      "player_backend": "mediaplayer",
      "player_version": "1.28.0-rc.1",
      "playlist_include_framerate": "true",
      "reassignments_supported": "true",
      "sig": sign,
      "token": token,
      "transcode_mode": "cbr_v1",
    };
    var m3u8Url = "https://usher.ttvnw.net/api/channel/hls/${detail.roomId}.m3u8";
    var content = await HttpClient.instance.getText(m3u8Url, queryParameters: params, header: headers);

    return parseMasterPlaylist(content, masterUri: Uri.parse(m3u8Url));
  }

  /// Parses each `#EXT-X-STREAM-INF` together with its following URI.
  ///
  /// The previous implementation collected every URL and every BANDWIDTH in
  /// separate arrays. Any extra URI/comment or relative variant shifted those
  /// arrays and attached the wrong label to the stream. Keeping parser state
  /// local also prevents simultaneous multi-view requests from clearing one
  /// another's shared URL list.
  @visibleForTesting
  static List<LivePlayQuality> parseMasterPlaylist(String content, {required Uri masterUri}) {
    final grouped = <String, ({String label, int bandwidth, int sort, List<String> urls})>{};
    Map<String, String>? pendingAttributes;
    for (final rawLine in content.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        pendingAttributes = _parsePlaylistAttributes(line.substring('#EXT-X-STREAM-INF:'.length));
        continue;
      }
      if (line.isEmpty || line.startsWith('#') || pendingAttributes == null) continue;

      final uri = masterUri.resolve(line);
      if (!uri.hasScheme || !const {'http', 'https'}.contains(uri.scheme)) {
        pendingAttributes = null;
        continue;
      }
      final attributes = pendingAttributes;
      pendingAttributes = null;
      final bandwidth = int.tryParse(attributes['BANDWIDTH'] ?? '') ?? 0;
      final resolution = RegExp(r'^(\d+)x(\d+)$').firstMatch(attributes['RESOLUTION'] ?? '');
      final height = int.tryParse(resolution?.group(2) ?? '') ?? 0;
      final frameRate = double.tryParse(attributes['FRAME-RATE'] ?? '') ?? 0;
      final videoGroup = attributes['VIDEO'] ?? '';
      final source = videoGroup.toLowerCase() == 'chunked';
      final label = _qualityName(bandwidth, height: height, frameRate: frameRate, source: source);
      final id = '$height:${frameRate.round()}:$bandwidth:${videoGroup.toLowerCase()}';
      final existing = grouped[id];
      if (existing == null) {
        grouped[id] = (
          label: label,
          bandwidth: bandwidth,
          // Twitch calls the broadcaster's untouched stream `chunked`. Its
          // reported average BANDWIDTH can temporarily be below a transcode,
          // so semantic source priority is more reliable than raw bitrate.
          sort: source ? 1 << 30 : bandwidth,
          urls: <String>[uri.toString()],
        );
      } else if (!existing.urls.contains(uri.toString())) {
        existing.urls.add(uri.toString());
      }
    }

    final qualities = grouped.entries
        .map(
          (entry) => LivePlayQuality(
            quality: entry.value.label,
            id: entry.key,
            sort: entry.value.sort,
            data: List<String>.unmodifiable(entry.value.urls),
          ),
        )
        .toList(growable: false);
    qualities.sort((left, right) => right.sort.compareTo(left.sort));
    return qualities;
  }

  static Map<String, String> _parsePlaylistAttributes(String value) {
    final attributes = <String, String>{};
    for (final match in RegExp(r'([A-Z0-9-]+)=("[^"]*"|[^,]*)').allMatches(value)) {
      final raw = match.group(2) ?? '';
      attributes[match.group(1)!] = raw.length >= 2 && raw.startsWith('"') && raw.endsWith('"')
          ? raw.substring(1, raw.length - 1)
          : raw;
    }
    return attributes;
  }

  static String _qualityName(int bandwidth, {int height = 0, double frameRate = 0, bool source = false}) {
    if (height > 0) {
      final fps = frameRate >= 45 ? frameRate.round().toString() : '';
      return LiveQualityLabel.normalize(
        platform: Sites.twitchSite,
        rawLabel: '${height}p$fps${source ? ' (Source)' : ''}',
        bitrate: bandwidth,
        resolution: '${height * 16 ~/ 9}x$height',
      );
    }
    if (source) return '原画';
    if (bandwidth > 5000000) return '1080P';
    if (bandwidth > 2500000) return '720P';
    if (bandwidth > 1000000) return '480P';
    if (bandwidth > 500000) return '360P';
    return '自动';
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    final data = quality.data;
    if (data is! List) return const <String>[];
    return data.map((item) => item.toString().trim()).where((url) => url.isNotEmpty).toList(growable: false);
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    var items = <LiveRoom>[];
    var liveArea = LiveArea(platform: id, shortName: "just-chatting", areaName: "Just Chatting");
    var liveCategoryResult = await getCategoryRooms(liveArea, page: page, pageSize: pageSize);
    items.addAll(liveCategoryResult);
    return items;
  }

  @override
  // A failed lookup is not an offline channel: reporting it as offline showed
  // "not live" for live channels whenever Twitch or the proxy failed, with no
  // retry. Let the room page present the load error like other platforms.
  Future<LiveRoom> getRoomDetail({required String platform, required String roomId}) => _loadRoomDetail(roomId);

  @override
  Future<LiveRoom> getRoomDetailForRefresh({required String platform, required String roomId}) {
    return _loadRoomDetail(roomId);
  }

  @override
  Future<LiveRoom> getRoomDetailForRecording({required String platform, required String roomId}) {
    return _loadRoomDetail(roomId);
  }

  Future<LiveRoom> _loadRoomDetail(String roomId) async {
    final roomInfo = await _getRoomInfo(roomId);
    if (roomInfo.length < 2) {
      throw StateError('Twitch room metadata response is incomplete');
    }
    final channelShell = roomInfo.first;
    final streamMetaData = roomInfo[1];

    final userOrError = channelShell.data.userOrError;
    if (userOrError == null) {
      throw StateError('Twitch channel metadata is missing');
    }
    final user = streamMetaData.data.user;
    if (user == null) {
      throw StateError('Twitch stream metadata is missing');
    }

    final online = switch (user.stream) {
      Stream stream when stream.streamType == 'live' => true,
      _ => false,
    };
    // StreamMetadata stopped returning viewersCount (it parses as 0); the
    // ChannelShell stream in the same batch still carries the live count.
    final shellViewers = userOrError.stream?.viewersCount ?? 0;
    final viewers = shellViewers > 0 ? shellViewers : (user.stream?.viewersCount ?? 0);
    final title = user.lastBroadcast?.title ?? "";
    return LiveRoom(
      roomId: roomId,
      title: title,
      cover: user.profileImageUrl,
      nick: userOrError.displayName,
      avatar: user.profileImageUrl,
      watching: online ? viewers.toString() : "0",
      onlineViewers: online ? viewers.toString() : "0",
      audienceMetricType: AudienceMetricType.onlineViewers,
      area: user.stream?.game?.name ?? user.stream?.game?.displayName,
      status: online,
      liveStatus: online ? LiveStatus.live : LiveStatus.offline,
      platform: Sites.twitchSite,
      link: "$baseUrl/$roomId",
      danmakuData: roomId,
      introduction: "",
      notice: "",
      userId: roomId,
      data: roomId,
    );
  }

  Future<List<TwitchResponse>> _getRoomInfo(String roomId) async {
    var queries = [
      buildPersistedRequest("ChannelShell", "fea4573a7bf2644f5b3f2cbbdcbee0d17312e48d2e55f080589d053aad353f11", {
        "login": roomId,
      }),
      buildPersistedRequest("StreamMetadata", "b57f9b910f8cd1a4659d894fe7550ccc81ec9052c01e438b290fd66a040b9b93", {
        "channelLogin": roomId,
        "includeIsDJ": true,
      }),
    ];
    String requestQuery = "[${queries.map((q) => q.toString()).join(',')}]";
    var response = await getGplResponse(requestQuery);

    final decoded = response is List ? response : const <dynamic>[];
    final responses = decoded.map((item) => TwitchResponse.fromJson(item as Map<String, dynamic>)).toList();
    if (responses.length < 2) {
      throw StateError('Invalid response from Twitch API');
    }
    return responses;
  }

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    try {
      var cursorType = "getCategoryRooms";
      var cursorId = category.shortName!;
      String cursor = getCursor(cursorType, cursorId, page);
      if (cursor.isEmpty && page > 1) {
        return <LiveRoom>[];
      }
      var params = [
        {
          "operationName": "DirectoryPage_Game",
          "variables": {
            "imageWidth": 50,
            "slug": category.shortName,
            "options": {
              "sort": "VIEWER_COUNT",
              "recommendationsContext": {"platform": "web"},
              "requestID": "JIRA-VXP-2397",
              "freeformTags": null,
              "tags": [],
              "broadcasterLanguages": ["ZH", "KO"],
              "systemFilters": [],
            },
            "sortTypeIsRecency": false,
            "limit": pageSize.clamp(1, 100),
            "includeCostreaming": true,
            if (cursor.isNotEmpty) "cursor": cursor,
          },
          "extensions": {
            "persistedQuery": {
              "version": 1,
              "sha256Hash": "76cb069d835b8a02914c08dc42c421d0dafda8af5b113a3f19141824b901402f",
            },
          },
        },
      ];
      var liveGpl = jsonEncode(params);
      var response = await getGplResponse(liveGpl);

      final envelopes = response is List ? response : const <dynamic>[];
      final envelope = envelopes.isEmpty ? null : _stringMap(envelopes.first);
      if (envelope == null) {
        throw StateError('Twitch stream directory returned an invalid response envelope');
      }
      final data = _stringMap(envelope['data']);
      final game = _stringMap(data?['game']);
      final streams = game == null ? null : _stringMap(game['streams']);
      if (streams == null) {
        final graphQlError = _graphQlErrorSummary(envelope);
        if (graphQlError.isNotEmpty) {
          throw StateError('Twitch GraphQL error: $graphQlError');
        }
        return <LiveRoom>[];
      }
      final connection = parseConnection(streams);
      final edges = connection.edges;
      if (edges.isEmpty) {
        return <LiveRoom>[];
      }
      cursor = edges.last["cursor"]?.toString() ?? "";
      if (!connection.hasNextPage) cursor = "";
      saveCursor(cursorType, cursorId, page, cursor);
      List<LiveRoom> subs = [];
      for (var item in edges) {
        final node = _stringMap(item['node']);
        final broadcaster = _stringMap(node?['broadcaster']);
        if (node == null || broadcaster == null) continue;
        final login = broadcaster['login']?.toString().trim() ?? '';
        if (login.isEmpty) continue;
        final game = _stringMap(node['game']);
        var subItem = LiveRoom(
          roomId: login,
          title: node["title"]?.toString() ?? '',
          cover: (node["previewImageURL"] ?? "")
              .toString()
              .replaceFirst("https://", "https://i2.wp.com/")
              .appendTxt("?&t=${DateTime.now().millisecondsSinceEpoch ~/ 1000}"),
          nick: broadcaster["displayName"]?.toString() ?? login,
          avatar: (broadcaster["profileImageURL"] ?? "").toString().replaceFirst("https://", "https://i2.wp.com/"),
          watching: (node["viewersCount"] ?? 0).toString(),
          onlineViewers: (node["viewersCount"] ?? 0).toString(),
          audienceMetricType: AudienceMetricType.onlineViewers,
          status: true,
          introduction: "",
          notice: "",
          danmakuData: broadcaster["id"]?.toString() ?? login,
          platform: id,
          liveStatus: LiveStatus.live,
          area: game?["displayName"]?.toString() ?? game?["name"]?.toString() ?? '',
          data: null,
        );
        subs.add(subItem);
      }
      return subs;
    } catch (error, stackTrace) {
      CoreLog.e('Twitch stream directory request failed: $error', stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) async {
    var cursorType = "searchRooms";
    var cursorId = keyword;
    String cursor = getCursor(cursorType, cursorId, page);
    if (cursor.isEmpty && page > 1) {
      return <LiveRoom>[];
    }
    var liveGpl = buildPersistedRequest(
      "SearchResultsPage_SearchResults",
      "7f3580f6ac6cd8aa1424cff7c974a07143827d6fa36bba1b54318fe7f0b68dc5",
      {
        "platform": "web",
        "query": keyword,
        "options": {"targets": null, "shouldSkipDiscoveryControl": false},
        "requestID": "808c9f2e-f52e-431c-8dc7-d2e3c1831d77",
        "includeIsDJ": true,
        if (cursor.isNotEmpty) "cursor": cursor,
      },
    );
    var response = await getGplResponse(liveGpl);

    var directoriesWithTags = response['data']['searchFor']['channels'] ?? {};
    cursor = directoriesWithTags["cursor"] ?? "";
    saveCursor(cursorType, cursorId, page, cursor);
    var edges = (directoriesWithTags['edges'] ?? []) as List;
    List<LiveRoom> subs = [];
    for (var item in edges) {
      var node = item['item'];
      var stream = node["stream"];
      var status = stream != null;
      var subItem = LiveRoom(
        roomId: node["login"],
        title: node["broadcastSettings"]["title"],
        cover: (node["stream"]?["previewImageURL"] ?? "")
            .toString()
            .replaceFirst("https://", "https://i2.wp.com/")
            .appendTxt("?&t=${DateTime.now().millisecondsSinceEpoch ~/ 1000}"),
        nick: node["displayName"],
        avatar: node["profileImageURL"].replaceFirst("https://", "https://i2.wp.com/"),
        watching: (node["stream"]?["viewersCount"] ?? 0).toString(),
        onlineViewers: (node["stream"]?["viewersCount"] ?? 0).toString(),
        audienceMetricType: AudienceMetricType.onlineViewers,
        status: status,
        introduction: "",
        notice: "",
        danmakuData: node["login"],
        platform: id,
        liveStatus: status ? LiveStatus.live : LiveStatus.offline,
        area: node["stream"]?["game"]?["displayName"] ?? "",
        data: null,
      );
      subs.add(subItem);
    }
    return subs;
  }

  @override
  Future<List<LiveAnchorItem>> searchAnchors(String keyword, {int page = 1, int pageSize = 30}) async {
    return [];
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({required String roomId}) {
    return Future.value([]);
  }

  Future<List<LiveRoom>> getLiveRoomDetailList({required List<LiveRoom> list}) async {
    if (list.isEmpty) {
      return list;
    }
    var size = 20;
    var futureList = <Future<List<LiveRoom>>>[];
    for (var i = 0; i < list.length; i += size) {
      var end = min(i + size, list.length);
      var subList = list.sublist(i, end);
      var future = getLiveRoomDetailListPart(list: subList);
      futureList.add(future);
    }
    final rooms = await Future.wait(futureList);
    return rooms.expand((e) => e).toList();
  }

  Future<List<LiveRoom>> getLiveRoomDetailListPart({required List<LiveRoom> list}) async {
    if (list.isEmpty) {
      return list;
    }
    var allPersistedRequestList = <String>[];
    for (var room in list) {
      allPersistedRequestList.addAll([
        buildPersistedRequest("ChannelShell", "fea4573a7bf2644f5b3f2cbbdcbee0d17312e48d2e55f080589d053aad353f11", {
          "login": room.roomId!,
        }),
        buildPersistedRequest("StreamMetadata", "b57f9b910f8cd1a4659d894fe7550ccc81ec9052c01e438b290fd66a040b9b93", {
          "channelLogin": room.roomId!,
          "includeIsDJ": true,
        }),
      ]);
    }

    String requestQuery = "[${allPersistedRequestList.join(',')}]";
    var response = await getGplResponse(requestQuery);
    List<dynamic> decoded = response;
    const itemLen = 2;
    List<List<dynamic>> subList = [];
    for (int i = 0; i < decoded.length; i += itemLen) {
      var end = min(i + itemLen, decoded.length);
      subList.add(decoded.sublist(i, end));
    }
    var index = 0;
    List<LiveRoom> roomList = [];
    for (var itemList in subList) {
      try {
        final responses = itemList.map((item) => TwitchResponse.fromJson(item as Map<String, dynamic>)).toList();
        var channelShell = responses.first;
        var streamMetaData = responses[1];
        final userOrError = channelShell.data.userOrError;
        var user = streamMetaData.data.user;
        bool online = switch (user?.stream) {
          Stream stream when stream.streamType == 'live' => true,
          _ => false,
        };
        var title = user?.lastBroadcast?.title ?? "";
        var liveRoom = LiveRoom(
          roomId: list[index].roomId,
          title: title,
          cover: user?.profileImageUrl ?? "",
          nick: userOrError?.displayName ?? "",
          avatar: user?.profileImageUrl ?? "",
          watching: online ? user!.stream!.viewersCount.toString() : "0",
          onlineViewers: online ? user!.stream!.viewersCount.toString() : "0",
          audienceMetricType: AudienceMetricType.onlineViewers,
          area: "",
          status: online,
          liveStatus: online ? LiveStatus.live : LiveStatus.offline,
          platform: Sites.twitchSite,
          link: "$baseUrl/${list[index].roomId}",
          danmakuData: list[index].roomId,
          introduction: "",
          notice: "",
          userId: list[index].roomId,
          data: list[index].roomId,
        );
        roomList.add(liveRoom);
      } catch (e) {
        CoreLog.w("$e");
      }
      index++;
    }
    return roomList;
  }
}
