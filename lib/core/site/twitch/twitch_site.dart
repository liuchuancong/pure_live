import 'dart:math';
import 'dart:convert';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/model/live_anchor_item.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/danmaku/twitch_danmaku.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/utils/twitch/twitch_models.dart';

class TwitchSite implements LiveSite, LiveSiteRoomRefresher {
  @override
  String id = Sites.twitchSite;

  @override
  String name = 'Twitch';

  static const defaultUa =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36";
  static const gplApiUrl = "https://gql.twitch.tv/gql";

  static const baseUrl = "https://www.twitch.tv";

  Map<String, String> cursorMap = {};
  late final String _deviceId = getDeviceId();

  Map<String, String> headers = {
    'user-agent': defaultUa,
    'accept-language': 'en-US,en;q=0.9',
    'accept': 'application/vnd.twitchtv.v5+json',
    'accept-encoding': 'gzip, deflate',
    'client-id': 'kimne78kx3ncx6brgo4mv6wki5h1ko',
  };

  final playSessionIds = ["bdd22331a986c7f1073628f2fc5b19da", "064bc3ff1722b6f53b0b5b8c01e46ca5"];

  void getRequestHeaders() {
    headers['device-id'] = _deviceId;
    if (SettingsService.to.cookieManager.twitchCookie.v.isNotEmpty) {
      headers["Cookie"] = SettingsService.to.cookieManager.twitchCookie.v;
    }
  }

  String getDeviceId() {
    final random = Random();
    final deviceId = 1000000000000000 + random.nextInt(1 << 32);
    return deviceId.toString();
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
    return await HttpClient.instance.postJson(gplApiUrl, header: headers, data: liveGpl);
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
    } catch (e) {
      CoreLog.error(e);
      return [];
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

    var directoriesWithTags = response['data']['directoriesWithTags'] ?? {};
    var edges = (directoriesWithTags['edges'] ?? []) as List;
    var pageInfo = directoriesWithTags['pageInfo'];
    var hasNextPage = pageInfo['hasNextPage'];
    cursor = edges.isEmpty ? "" : (edges.last["cursor"] ?? "");
    if (!hasNextPage) cursor = "";
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
      return detail.status ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    List<LivePlayQuality> qualities = <LivePlayQuality>[];
    if (detail.status != true) return qualities;

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
    final grouped = <String, ({String label, int bandwidth, List<String> urls})>{};
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
      final label = _qualityName(
        bandwidth,
        height: height,
        frameRate: frameRate,
        source: videoGroup.toLowerCase() == 'chunked',
      );
      final id = '$height:${frameRate.round()}:$bandwidth:${videoGroup.toLowerCase()}';
      final existing = grouped[id];
      if (existing == null) {
        grouped[id] = (label: label, bandwidth: bandwidth, urls: <String>[uri.toString()]);
      } else if (!existing.urls.contains(uri.toString())) {
        existing.urls.add(uri.toString());
      }
    }

    final qualities = grouped.entries
        .map(
          (entry) => LivePlayQuality(
            quality: entry.value.label,
            id: entry.key,
            sort: entry.value.bandwidth,
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
      return '${height}p$fps${source ? ' (Source)' : ''}';
    }
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
  Future<LiveRoom> getRoomDetail({required String platform, required String roomId}) async {
    try {
      return await _loadRoomDetail(roomId);
    } catch (e) {
      final liveRoom =
          SettingsService.to.fav.favoriteRooms.v.firstWhereOrNull(
            (r) => r.roomId == roomId && r.platform == platform,
          ) ??
          LiveRoom(roomId: roomId, platform: Sites.twitchSite);
      return liveRoom.copyWith(liveStatus: LiveStatus.offline, status: false, isRecord: false);
    }
  }

  @override
  Future<LiveRoom> getRoomDetailForRefresh({required String platform, required String roomId}) {
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
    final title = user.lastBroadcast?.title ?? "";
    return LiveRoom(
      roomId: roomId,
      title: title,
      cover: user.profileImageUrl,
      nick: userOrError.displayName,
      avatar: user.profileImageUrl,
      watching: online ? user.stream!.viewersCount.toString() : "0",
      onlineViewers: online ? user.stream!.viewersCount.toString() : "0",
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
    getRequestHeaders();
    var response = await HttpClient.instance.postJson(gplApiUrl, header: headers, data: requestQuery);

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

      var directoriesWithTags = response[0]['data']['game']['streams'] ?? {};
      var edges = (directoriesWithTags['edges'] ?? []) as List;
      var pageInfo = directoriesWithTags['pageInfo'];
      var hasNextPage = pageInfo['hasNextPage'];
      if (edges.isEmpty) {
        return <LiveRoom>[];
      }
      cursor = edges.last["cursor"] ?? "";
      if (!hasNextPage) cursor = "";
      saveCursor(cursorType, cursorId, page, cursor);
      List<LiveRoom> subs = [];
      for (var item in edges) {
        var node = item['node'];
        var subItem = LiveRoom(
          roomId: node["broadcaster"]["login"],
          title: node["title"],
          cover: (node["previewImageURL"] ?? "")
              .toString()
              .replaceFirst("https://", "https://i2.wp.com/")
              .appendTxt("?&t=${DateTime.now().millisecondsSinceEpoch ~/ 1000}"),
          nick: node["broadcaster"]["displayName"],
          avatar: node["broadcaster"]["profileImageURL"].replaceFirst("https://", "https://i2.wp.com/"),
          watching: (node["viewersCount"] ?? 0).toString(),
          onlineViewers: (node["viewersCount"] ?? 0).toString(),
          audienceMetricType: AudienceMetricType.onlineViewers,
          status: true,
          introduction: "",
          notice: "",
          danmakuData: node["broadcaster"]["id"],
          platform: id,
          liveStatus: LiveStatus.live,
          area: node["game"]["displayName"],
          data: null,
        );
        subs.add(subItem);
      }
      return subs;
    } catch (e) {
      CoreLog.error(e);
      return [];
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
