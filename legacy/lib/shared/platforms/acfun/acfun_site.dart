import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/core/models/live_area.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/shared/platforms/live_site.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/core/models/live_category.dart';
import 'package:pure_live/core/models/live_anchor_item.dart';
import 'package:pure_live/shared/platforms/live_external_room.dart';

import 'acfun_api.dart';
import 'acfun_danmaku.dart';
import 'acfun_directory.dart';
import 'acfun_link_danmaku.dart';
import 'acfun_search.dart';

/// Anonymous AcFun live directory, author search, playback and recording.
/// Remote chat is not integrated; the session UI reports this separately.
class AcfunSite extends LiveSite
    implements
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayRecoveryResolver,
        LiveSiteExternalRoomResolver {
  @override
  RoomExternalTarget? externalRoomTarget(LiveRoom liveroom) {
    final path = Uri.encodeComponent(id);
    return RoomExternalTarget(web: 'https://live.acfun.cn/live/$path');
  }

  AcfunSite({AcfunApi? api, AcfunDirectory? directory, AcfunSearchClient? search})
    : _api = api ?? _sharedApi,
      _directory = directory ?? (api == null ? _sharedDirectory : AcfunDirectory(api: api)),
      _search = search ?? _sharedSearch;
  static final _sharedApi = AcfunApi();
  static final _sharedDirectory = AcfunDirectory(api: _sharedApi);
  static final _sharedSearch = AcfunSearchClient();
  final AcfunApi _api;
  final AcfunDirectory _directory;
  final AcfunSearchClient _search;

  @override
  String get id => 'acfun';
  @override
  String get name => 'AcFun 直播';
  @override
  LiveDanmaku getDanmaku() => AcfunLinkDanmaku();

  static LiveRoom parseRoom(Map<String, dynamic> data, String roomId) {
    final live = AcfunApi.validateRoomInfo(data, roomId);
    final user = AcfunApi.object(data['user']);
    final covers = data['coverUrls'];
    final count = AcfunApi.integer(data['onlineCount']);
    return LiveRoom(
      platform: 'acfun',
      roomId: roomId,
      userId: roomId,
      link: '${AcfunApi.origin}/live/$roomId',
      nick: AcfunApi.text(user['name']),
      avatar: AcfunApi.imageUrl(user['headUrl']),
      title: AcfunApi.text(data['title']),
      cover: covers is List && covers.isNotEmpty ? AcfunApi.imageUrl(covers.first) : '',
      area: data['type'] is Map ? AcfunApi.text((data['type'] as Map)['name']) : '',
      onlineViewers: count != null && count >= 0 ? '$count' : '',
      watching: count != null && count >= 0 ? '$count' : '',
      audienceMetricType: AudienceMetricType.onlineViewers,
      followers: AcfunApi.text(user['fanCountValue']),
      status: live,
      liveStatus: live ? LiveStatus.live : LiveStatus.offline,
      restriction: live ? _restriction(data) : null,
      startedAt: live ? _startedAt(data['createTime']) : null,
    );
  }

  static DateTime? _startedAt(Object? value) {
    final raw = AcfunApi.integer(value);
    if (raw == null || raw < 1000000000000 || raw >= 10000000000000) return null;
    return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
  }

  static LiveRestriction? _restriction(Map<String, dynamic> data) {
    if (AcfunApi.text(data['paidShowUuid']).isNotEmpty) {
      return data['paidShowUserBuyStatus'] == true ? LiveRestriction.none : LiveRestriction.paid;
    }
    return data.containsKey('paidShowUserBuyStatus') ? LiveRestriction.none : null;
  }

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    if (page > 1) return [];
    // This metadata read must not reset an in-use directory pagination sequence.
    final data = await _api.directory(count: 1);
    if (data.categories.isEmpty) throw const AcfunApiException(AcfunFailureKind.schema);
    return [
      LiveCategory(
        id: id,
        name: name,
        children: [
          for (final category in data.categories)
            LiveArea(
              platform: id,
              areaType: '${category.type}',
              areaId: '${category.id}',
              typeName: name,
              areaName: category.name,
              areaPic: category.cover,
            ),
        ],
      ),
    ];
  }

  static List<LiveRoom> _rooms(AcfunDirectoryPage page) => [
    for (final item in page.rooms)
      // parseDirectory already validated the outer success envelope. The
      // website does not repeat `result` on each liveList item.
      parseRoom({...item, 'result': 0}, AcfunApi.normalizeAuthorId(AcfunApi.text(item['authorId']))),
  ];

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async =>
      _rooms(await _directory.page(page: page, count: pageSize));

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    final type = AcfunApi.integer(category.areaType);
    final categoryId = AcfunApi.integer(category.areaId);
    if (type == null || categoryId == null || (category.platform != null && category.platform != id)) {
      throw const AcfunApiException(AcfunFailureKind.schema);
    }
    final filters = categoryId == AcfunApi.allFilterId ? null : AcfunCategoryFilter.encode(type, categoryId);
    return _rooms(await _directory.page(page: page, count: pageSize, filters: filters));
  }

  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) =>
      _search.search(keyword, page: page, pageSize: pageSize);

  @override
  Future<List<LiveAnchorItem>> searchAnchors(String keyword, {int page = 1, int pageSize = 30}) async => [
    for (final room in await searchRooms(keyword, page: page, pageSize: pageSize))
      LiveAnchorItem(
        roomId: room.roomId!,
        avatar: room.avatar ?? '',
        userName: room.nick ?? '',
        liveStatus: room.liveStatus == LiveStatus.live,
      ),
  ];

  @override
  Future<LiveRoom> getRoomDetailForRefresh(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    final id = AcfunApi.normalizeAuthorId(liveroom.roomId!);
    return parseRoom(await _api.roomInfo(id), id);
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    final fresh = await getRoomDetailForRefresh(liveroom);
    if (fresh.liveStatus == LiveStatus.live) {
      final playback = await _api.playback(fresh.roomId!);
      fresh.data = playback;
      if (playback.tickets.isNotEmpty) {
        fresh.danmakuData = await _danmakuArgs(AcfunApi.normalizeAuthorId(fresh.roomId!), playback);
      }
    }
    return fresh;
  }

  Future<AcfunDanmakuArgs> _danmakuArgs(String authorId, AcfunPlayback playback) async {
    final visitor = await _api.visitorCredentials();
    return AcfunDanmakuArgs(
      authorId: authorId,
      liveId: playback.liveId,
      userId: visitor.userId,
      deviceId: visitor.did,
      visitorToken: visitor.token,
      security: visitor.security,
      tickets: playback.tickets,
      enterRoomAttach: playback.enterRoomAttach,
      refresh: () async => _danmakuArgs(authorId, await _api.playback(authorId)),
    );
  }

  @override
  Future<LiveRoom> getRoomDetailForRecording(LiveRoom liveroom) => getRoomDetail(liveroom);

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom liveroom}) async {
    if (liveroom.liveStatus != LiveStatus.live) return [];
    final data = liveroom.data;
    if (data is! AcfunPlayback) throw const AcfunApiException(AcfunFailureKind.schema);
    return [
      for (final quality in data.qualities)
        LivePlayQuality(id: quality.id, quality: quality.label, sort: quality.rank, data: quality.urls),
    ];
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom liveroom, required LivePlayQuality quality}) async {
    final data = liveroom.data;
    if (data is! AcfunPlayback) throw const AcfunApiException(AcfunFailureKind.schema);
    for (final current in data.qualities) {
      if (current.id == quality.selectionId) return current.urls;
    }
    throw const AcfunApiException(AcfunFailureKind.qualityUnavailable);
  }

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsForRecoveryRaw({
    required LiveRoom liveroom,
    required LivePlayQuality quality,
  }) async {
    final fresh = await getRoomDetail(liveroom);
    final urls = await getPlayUrls(liveroom: fresh, quality: quality);
    return LivePlayUrlResolution(urls: urls, appliedQualityData: quality.selectionId);
  }
}
