import 'package:dio/dio.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/core/consts/platform_ids.dart';
import 'package:pure_live/core/models/live_category.dart';
import 'package:pure_live/shared/platforms/live_site.dart';
import 'package:pure_live/core/models/live_anchor_item.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/core/utils/live_quality_label.dart';
import 'package:pure_live/shared/platforms/cc/cc_catalog.dart';
import 'package:pure_live/shared/platforms/empty_danmaku.dart';
import 'package:pure_live/shared/platforms/live_directory.dart';
import 'package:pure_live/shared/platforms/current_live_room.dart';
import 'package:pure_live/shared/platforms/live_external_room.dart';
import 'package:pure_live/shared/platforms/live_danmaku_capability.dart';
import 'package:pure_live/shared/platforms/cc/cc_danmaku_capability.dart';

class CCSite
    with LiveDanmakuCapabilityDefaults, CcDanmakuCapability
    implements
        LiveSite,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LiveSiteCategoryDirectoryProvider,
        LiveSiteExternalRoomResolver {
  @override
  RoomExternalTarget? externalRoomTarget(LiveRoom liveroom) {
    final id = sanitizedExternalRoomId(liveroom.roomId);
    if (id == null) return null;
    final path = Uri.encodeComponent(id);
    final user = sanitizedExternalRoomId(liveroom.userId);
    return RoomExternalTarget(
      web: 'https://cc.163.com/$path',
      native: user == null ? null : 'cc://join-room/$path/${Uri.encodeComponent(user)}/',
    );
  }

  @override
  late final LiveSiteDirectoryPager categoryDirectory = _CCCategoryDirectory(this);

  @override
  String id = PlatformIds.cc;

  @override
  String name = "网易CC直播";

  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();
  final String kUserAgent =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36";

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    // The legacy category endpoint now serves the Dashen HTML application.
    // Fetch its public metadata and live-entry configuration, not an HTML
    // fallback or a guessed static list of games.
    final headers = {'user-agent': kUserAgent, 'referer': 'https://ds.163.com/glive/', 'origin': 'https://ds.163.com'};
    final games = await HttpClient.instance.getJson(
      'https://inf.ds.163.com/v1/web/game-center/basic/base-info-list/by-type',
      queryParameters: {'gameType': 'NETEASE'},
      header: headers,
    );
    final configuration = await HttpClient.instance.postJson(
      'https://inf-act.ds.163.com/v1/act-web/pageConf/commonAppConfig',
      data: {'id': CCCatalog.configurationId},
      header: headers,
    );
    return CCCatalog.parse(
      games,
      configuration,
      categoryLabel: i18n('cc_live_categories'),
      officialLabel: i18n('cc_official_entries'),
    );
  }

  @override
  Future<List<LiveRoom>> getCategoryRooms(
    LiveArea category, {
    int page = 1,
    int pageSize = 30,
    CancelToken? cancel,
  }) async {
    final game = category.areaId?.trim() ?? '';
    final platform = category.platform?.trim().toLowerCase() ?? '';
    if (!RegExp(r'^[1-9][0-9]{0,15}$').hasMatch(game) ||
        (platform.isNotEmpty && platform != PlatformIds.cc) ||
        page < 1 ||
        page > 100000 ||
        pageSize < 1 ||
        pageSize > 1000) {
      throw ArgumentError('Invalid CC category or pagination');
    }
    // The Next.js page contains only the initial showcase. The current CC
    // category component requests this feed for every offset, including after
    // the official site moved its main navigation into Dashen.
    final result = await HttpClient.instance.getJson(
      'https://cc.163.com/api/category/$game/',
      queryParameters: {'format': 'json', 'tag_id': 0, 'start': (page - 1) * pageSize, 'size': pageSize},
      header: {'user-agent': kUserAgent},
      cancel: cancel,
    );
    if (result is! Map || result['gametype']?.toString() != game || result['lives'] is! List) {
      throw const FormatException('Invalid CC category response');
    }
    final rows = result['lives'] as List;
    if (rows.length > 1000) throw const FormatException('CC category response exceeds row limit');
    final items = <LiveRoom>[];
    for (final item in rows) {
      if (item is! Map) throw const FormatException('Invalid CC category room');
      final rawId = item['cuteid'];
      if ((rawId is! String && rawId is! int) ||
          (rawId is int && rawId > 9007199254740991) ||
          !RegExp(r'^[1-9][0-9]{0,31}$').hasMatch(rawId.toString())) {
        throw const FormatException('Invalid CC category room identity');
      }
      String text(Object? value) => value is String ? value : '';
      final audience = parseRoomAudience(Map<String, dynamic>.from(item));
      final status = int.tryParse(item['status']?.toString() ?? '');
      items.add(
        LiveRoom(
          roomId: rawId.toString(),
          title: text(item['title']),
          cover: text(item['cover']),
          nick: text(item['nickname']),
          watching: audience.popularity.isNotEmpty ? audience.popularity : audience.onlineViewers,
          popularity: audience.popularity,
          onlineViewers: audience.onlineViewers,
          audienceMetricType: audience.popularity.isNotEmpty
              ? AudienceMetricType.popularity
              : AudienceMetricType.onlineViewers,
          avatar: text(item['purl']),
          area: text(item['game_name']).isNotEmpty ? text(item['game_name']) : text(item['gamename']),
          liveStatus: _onAirStatus(
            status == 1
                ? LiveStatus.live
                : status == 0
                ? LiveStatus.offline
                : LiveStatus.unknown,
            item['title'],
          ),
          status: status == 1,
          platform: PlatformIds.cc,
        ),
      );
    }
    // Only the API's lives collection is consumed. Its videos fallback is not
    // a live room, and malformed responses must not commit an empty page.
    return items;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom liveroom}) {
    final rawData = liveroom.data;
    if (rawData is! Map) return Future.value(const <LivePlayQuality>[]);
    final qualities = <LivePlayQuality>[];
    var reflect = {
      'blueray': '原画',
      'original': '原画',
      'high': '高清',
      'medium': '标准',
      'standard': '标准',
      'low': '低清',
      'ultra': '蓝光',
    };

    const priority = ['hs', 'ks', 'ali', 'fws', 'wy'];
    final isLiveStream = rawData['resolution'] == null;
    final qualityData = isLiveStream ? rawData : rawData['resolution'];
    if (qualityData is! Map) return Future.value(const <LivePlayQuality>[]);
    final qulityList = qualityData;
    qulityList.forEach((key, value) {
      if (value is! Map) return;
      final cdn = isLiveStream ? value['CDN_FMT'] : value['cdn'];
      if (cdn is! Map) return;
      final preferredLines = <String>[];
      final otherLines = <String>[];
      cdn.forEach((line, lineValue) {
        final baseUrl = liveroom.link?.trim() ?? '';
        final url = isLiveStream && baseUrl.isNotEmpty
            ? _resolveLiveCdnUrl(baseUrl, lineValue)
            : _normalizeDirectUrl(lineValue);
        if (Uri.tryParse(url)?.hasScheme != true) return;
        final target = priority.contains(line.toString().toLowerCase()) ? preferredLines : otherLines;
        if (!target.contains(url)) target.add(url);
      });
      final lines = <String>[...preferredLines, ...otherLines];
      if (lines.isEmpty) return;
      final bitrateKbps = int.tryParse(value['vbr']?.toString() ?? '') ?? 0;
      final sort = _qualitySort(key.toString(), bitrateKbps);
      qualities.add(
        LivePlayQuality(
          quality: LiveQualityLabel.normalize(
            platform: PlatformIds.cc,
            rawLabel: reflect[key] ?? key.toString(),
            id: key,
            bitrate: bitrateKbps > 0 ? bitrateKbps * 1000 : null,
          ),
          id: key.toString(),
          sort: sort,
          data: List<String>.unmodifiable(lines),
        ),
      );
    });
    qualities.sort((a, b) => b.sort.compareTo(a.sort));

    return Future.value(qualities);
  }

  /// CC may omit `vbr` for the untouched stream. Prefer the documented tier
  /// the bottom because its metadata happens to be absent.
  static int _qualitySort(String rawKey, int bitrateKbps) {
    final key = rawKey.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    final rank = switch (key) {
      'blueray' || 'original' || 'origin' || 'source' => 6,
      'ultra' => 5,
      'high' || 'hd' => 4,
      'medium' || 'standard' || 'sd' => 3,
      'low' || 'ld' => 2,
      _ => 0,
    };
    return rank == 0 ? bitrateKbps : rank * 1000000 + bitrateKbps.clamp(0, 999999);
  }

  static String _resolveLiveCdnUrl(String baseUrl, dynamic lineValue) {
    final value = lineValue?.toString().trim() ?? '';
    if (value.startsWith('//')) return 'https:$value';
    final direct = Uri.tryParse(value);
    if (direct?.hasScheme == true) {
      return const {'http', 'https'}.contains(direct!.scheme.toLowerCase()) ? value : '';
    }
    if (value.isEmpty) return baseUrl;
    final suffix = value.replaceFirst(RegExp(r'^[?&]+'), '');
    return '$baseUrl${baseUrl.contains('?') ? '&' : '?'}$suffix';
  }

  static String _normalizeDirectUrl(dynamic lineValue) {
    final value = lineValue?.toString().trim() ?? '';
    return value.startsWith('//') ? 'https:$value' : value;
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom liveroom, required LivePlayQuality quality}) async {
    final data = quality.data;
    if (data is! List) return const <String>[];
    return data.map((item) => item.toString().trim()).where((url) => url.isNotEmpty).toList(growable: false);
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    try {
      var result = await HttpClient.instance.getJson(
        "https://cc.163.com/api/category/live/",
        queryParameters: {"format": "json", "start": (page - 1) * pageSize, "size": pageSize},
      );

      var items = <LiveRoom>[];
      for (var item in result["lives"]) {
        final audience = parseRoomAudience(Map<String, dynamic>.from(item as Map));
        var roomItem = LiveRoom(
          roomId: item["cuteid"].toString(),
          title: item["title"].toString(),
          cover: item["cover"].toString(),
          nick: item["nickname"].toString(),
          watching: audience.popularity.isNotEmpty ? audience.popularity : audience.onlineViewers,
          popularity: audience.popularity,
          onlineViewers: audience.onlineViewers,
          audienceMetricType: audience.popularity.isNotEmpty
              ? AudienceMetricType.popularity
              : AudienceMetricType.onlineViewers,
          avatar: item["purl"],
          area: item["gamename"] ?? item["game_name"] ?? '',
          liveStatus: _onAirStatus(LiveStatus.live, item["title"]),
          status: true,
          platform: PlatformIds.cc,
          startedAt: _startedAt(_onAirStatus(LiveStatus.live, item['title']), item),
          restriction: _restriction(_onAirStatus(LiveStatus.live, item['title']), item),
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
      return await _loadRoomDetail(roomId);
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
    // Propagate transport/shape errors to the favourite verifier. Treating a
    // failed request as an authoritative offline response corrupts the card
    // state and hides the failure from the retry policy.
    return _loadRoomDetail(liveroom.roomId!);
  }

  @override
  Future<LiveRoom> getRoomDetailForRecording(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return _loadRoomDetail(liveroom.roomId!);
  }

  Future<LiveRoom> _loadRoomDetail(String roomId) async {
    const url = "https://api.cc.163.com/v1/activitylives/anchor/lives";
    final result = await HttpClient.instance.getJson(
      url,
      queryParameters: {'anchor_ccid': roomId},
      header: {"user-agent": kUserAgent},
    );
    final channelId = result['data'][roomId]['channel_id'];
    final urlToGetReal = "https://cc.163.com/live/channel/?channelids=$channelId";
    final resultReal = await HttpClient.instance.getJson(urlToGetReal, queryParameters: {'anchor_ccid': roomId});
    final roomInfo = resultReal["data"][0];
    final audience = parseRoomAudience(Map<String, dynamic>.from(roomInfo as Map));
    final nativeMetric = audience.popularity.isNotEmpty ? audience.popularity : audience.onlineViewers;
    final live = int.tryParse(roomInfo['status']?.toString() ?? '') == 1;
    return LiveRoom(
      cover: roomInfo["cover"],
      watching: nativeMetric.isNotEmpty ? nativeMetric : roomInfo["follower_num"].toString(),
      popularity: audience.popularity,
      onlineViewers: audience.onlineViewers,
      audienceMetricType: audience.popularity.isNotEmpty
          ? AudienceMetricType.popularity
          : audience.onlineViewers.isNotEmpty
          ? AudienceMetricType.onlineViewers
          : AudienceMetricType.followers,
      roomId: roomInfo["ccid"].toString(),
      area: roomInfo["gamename"],
      title: roomInfo["title"],
      nick: roomInfo["nickname"].toString(),
      avatar: roomInfo["purl"].toString(),
      introduction: roomInfo["personal_label"],
      notice: roomInfo["personal_label"],
      status: live,
      liveStatus: _onAirStatus(live ? LiveStatus.live : LiveStatus.offline, roomInfo["title"]),
      platform: PlatformIds.cc,
      link: roomInfo['m3u8'],
      userId: roomInfo['cid'].toString(),
      data: roomInfo["quickplay"] ?? roomInfo["stream_list"],
      startedAt: _startedAt(_onAirStatus(live ? LiveStatus.live : LiveStatus.offline, roomInfo['title']), roomInfo),
      restriction: _restriction(
        _onAirStatus(live ? LiveStatus.live : LiveStatus.offline, roomInfo['title']),
        roomInfo,
      ),
    );
  }

  static LiveRestriction? _restriction(LiveStatus status, Map room) {
    if (status != LiveStatus.live && status != LiveStatus.replay) return null;
    final streamList = room['stream_list'];
    final quickplay = room['quickplay'];
    final hasTiers = (streamList is List && streamList.isNotEmpty) || quickplay != null;
    return hasTiers ? LiveRestriction.none : null;
  }

  static DateTime? _startedAt(LiveStatus status, Map room) {
    if (status != LiveStatus.live && status != LiveStatus.replay) return null;
    final raw = room['startat']?.toString().trim() ?? '';
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$').firstMatch(raw);
    if (match == null) return null;
    final parts = [for (var index = 1; index <= 6; index++) int.tryParse(match.group(index) ?? '')];
    if (parts.any((value) => value == null)) return null;
    final year = parts[0]!;
    if (year < 2000) return null;
    return DateTime.utc(year, parts[1]!, parts[2]!, parts[3]!, parts[4]!, parts[5]!).subtract(const Duration(hours: 8));
  }

  static LiveStatus _onAirStatus(LiveStatus status, Object? title) =>
      status == LiveStatus.live && (title?.toString() ?? '').trimLeft().startsWith('【重播】') ? LiveStatus.replay : status;

  /// CC exposes two different audience scales in the same payload:
  /// `webcc_visitor`/`hot_score`/`visitor` are aliases for the large platform
  /// heat value, while `vision_visitor`/`online_num` are the current viewers. Keeping both avoids
  /// presenting values such as 500,000 heat as 500,000 people online.
  static ({String popularity, String onlineViewers}) parseRoomAudience(Map<String, dynamic> room) {
    final popularity = _firstAudienceValue([
      room['webcc_visitor'],
      room['hot_score'],
      room['visitor'],
      room['total_visitor'],
    ]);
    final onlineViewers = _firstAudienceValue([room['vision_visitor'], room['online_num']]);
    return (popularity: popularity, onlineViewers: onlineViewers);
  }

  static String _firstAudienceValue(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null' && RegExp(r'[0-9]').hasMatch(text)) return text;
    }
    return '';
  }

  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) async {
    final effectivePageSize = pageSize.clamp(1, 50);
    var result = await HttpClient.instance.getJson(
      "https://cc.163.com/search/anchor",
      queryParameters: {"query": keyword, "size": effectivePageSize, "page": page},
    );
    var items = <LiveRoom>[];
    var queryList = result["webcc_anchor"]["result"] ?? [];
    for (var item in queryList) {
      var roomItem = LiveRoom(
        roomId: item["cuteid"].toString(),
        title: item["title"],
        cover: item["portrait"],
        nick: item["nickname"].toString(),
        area: item["gamename"] ?? item["game_name"] ?? '',
        status: item['status'] == 1,
        liveStatus: _onAirStatus(
          item['status'] != null && item['status'] == 1 ? LiveStatus.live : LiveStatus.offline,
          item["title"],
        ),
        avatar: item["portrait"].toString(),
        watching: item["follower_num"].toString(),
        followers: item["follower_num"].toString(),
        audienceMetricType: AudienceMetricType.followers,
        platform: PlatformIds.cc,
      );
      items.add(roomItem);
    }
    return items;
  }

  @override
  Future<List<LiveAnchorItem>> searchAnchors(String keyword, {int page = 1, int pageSize = 30}) async {
    final rooms = await searchRooms(keyword, page: page, pageSize: pageSize);
    return rooms
        .map(
          (room) => LiveAnchorItem(
            roomId: room.roomId ?? '',
            avatar: room.avatar ?? '',
            userName: room.nick ?? '',
            liveStatus: room.isLiveNow,
          ),
        )
        .toList();
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({required LiveRoom liveroom}) {
    return Future.value([]);
  }
}

class _CCCategoryDirectory implements LiveSiteDirectoryPager {
  _CCCategoryDirectory(this.site);
  final CCSite site;
  static const _nativePageSize = 30;

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    if (category == null) throw ArgumentError('CC category is required');
    final rooms = await site.getCategoryRooms(category, page: page, pageSize: _nativePageSize, cancel: cancel);
    // A stable request width keeps offsets independent of visible page size,
    // exclusions and cached UI tails. The raw lives list is not filtered; a
    // short page ends this snapshot, while malformed data remains retryable.
    if (rooms.length > _nativePageSize) throw const FormatException('CC category exceeded requested page size');
    return LiveDirectoryPage(rooms: rooms, page: page, hasMore: rooms.length == _nativePageSize);
  }
}
