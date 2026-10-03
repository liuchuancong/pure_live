import 'package:dio/dio.dart';
import 'package:pure_live/core/models/live_area.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/shared/platforms/empty_danmaku.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/shared/platforms/live_directory.dart';
import 'package:pure_live/shared/platforms/live_search.dart';
import 'package:pure_live/shared/platforms/live_site.dart';
import 'package:pure_live/core/models/live_category.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/core/utils/i18n.dart';
import 'package:pure_live/shared/platforms/live_external_room.dart';

import 'steam_broadcast_api.dart';
import 'steam_broadcast_link.dart';

final class SteamBroadcastSite extends LiveSite
    implements
        LiveSiteDirectoryPager,
        LiveDirectoryNotice,
        LiveCancellableSearch,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayUrlResolver,
        LivePlayRecoveryResolver,
        LiveSiteExternalRoomResolver {
  /// 该站点自己的官方房间地址（网页与可选的客户端 scheme）。
  @override
  RoomExternalTarget? externalRoomTarget(LiveRoom liveroom) {
    final id = sanitizedExternalRoomId(liveroom.roomId);
    if (id == null) return null;
    return officialExternalRoom(() => SteamBroadcastLink.watchUrl(id));
  }

  SteamBroadcastSite({SteamBroadcastApi? api}) : _api = api ?? SteamBroadcastApi();

  final SteamBroadcastApi _api;
  final Map<String, SteamBroadcastRoom> _known = {};

  @override
  String get id => 'steambroadcast';

  @override
  String get name => 'Steam Broadcasts';

  @override
  String get directoryNoticeKey => 'steambroadcast_directory_scope';

  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async => page == 1 && pageSize > 0
      ? [
          LiveCategory(
            id: id,
            name: name,
            children: [
              LiveArea(
                platform: id,
                areaType: 'community',
                areaId: 'trending',
                areaName: i18n('steambroadcast_category_trending'),
                typeName: name,
              ),
            ],
          ),
        ]
      : [];

  void _category(LiveArea? category) {
    if (category != null &&
        (category.platform != id || category.areaType != 'community' || category.areaId != 'trending')) {
      throw const SteamBroadcastException(SteamBroadcastFailure.identity);
    }
  }

  void _remember(Iterable<SteamBroadcastRoom> rooms) {
    for (final room in rooms) {
      _known[room.steamId] = room;
    }
  }

  static LiveRoom _room(SteamBroadcastRoom room, {required bool includeMedia}) {
    final viewers = room.currentViewers?.toString();
    final status = switch (room.state) {
      SteamBroadcastState.live => LiveStatus.live,
      SteamBroadcastState.replay => LiveStatus.replay,
      SteamBroadcastState.offline => LiveStatus.offline,
      // `user_restricted` 是主播账号被限制，按封禁；`unknown` 保持未知。
      SteamBroadcastState.restricted => LiveStatus.banned,
      SteamBroadcastState.unknown => LiveStatus.unknown,
    };
    return LiveRoom(
      platform: 'steambroadcast',
      roomId: room.steamId,
      userId: room.steamId,
      title: room.title,
      nick: room.broadcaster,
      avatar: room.avatar.isEmpty ? room.cover : room.avatar,
      cover: room.cover,
      area: room.game.isEmpty ? 'Steam Community' : room.game,
      link: SteamBroadcastLink.watchUrl(room.steamId),
      liveStatus: status,
      // `missing_subscription` 是在播 + 订阅者专属（上游 27-x）。
      restriction: room.state == SteamBroadcastState.live || room.state == SteamBroadcastState.replay
          ? room.restriction
          : null,
      watching: viewers ?? '',
      onlineViewers: viewers,
      audienceMetricType: viewers == null ? AudienceMetricType.unknown : AudienceMetricType.onlineViewers,
      notice: room.state == SteamBroadcastState.restricted
          ? i18n('steambroadcast_restricted_notice')
          : i18n('steambroadcast_chat_notice'),
      httpHeaders: SteamBroadcastApi.mediaHeaders(room.steamId),
      data: includeMedia ? room : null,
    );
  }

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    _category(category);
    if (page < 1) return LiveDirectoryPage(rooms: const [], page: page, hasMore: false);
    final result = await _api.directory(page: page, cancel: cancel);
    _remember(result.rooms);
    return LiveDirectoryPage(
      rooms: result.rooms.map((room) => _room(room, includeMedia: false)),
      page: page,
      hasMore: result.hasMore,
    );
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    if (page < 1 || pageSize < 1) return [];
    final result = await _api.directory(page: page);
    _remember(result.rooms);
    return result.rooms
        .take(pageSize.clamp(1, 60))
        .map((room) => _room(room, includeMedia: false))
        .toList(growable: false);
  }

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    _category(category);
    return getRecommendRooms(page: page, pageSize: pageSize);
  }

  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) =>
      searchRoomsCancellable(keyword, page: page, pageSize: pageSize);

  @override
  Future<List<LiveRoom>> searchRoomsCancellable(
    String keyword, {
    int page = 1,
    int pageSize = 30,
    CancelToken? cancel,
  }) async {
    final raw = keyword.trim();
    if (raw.isEmpty || page < 1 || pageSize < 1 || pageSize > 100) return [];
    final steamId = SteamBroadcastLink.parseSteamId(raw);
    if (steamId != null) {
      if (page != 1) return [];
      try {
        return [
          await _detail(
            LiveRoom(roomId: steamId, platform: id),
            includeMedia: false,
            cancel: cancel,
          ),
        ];
      } on SteamBroadcastException catch (error) {
        if (error.kind == SteamBroadcastFailure.missing) return [];
        rethrow;
      }
    }
    final query = raw.toLowerCase();
    final result = await _api.directory(page: page, cancel: cancel);
    _remember(result.rooms);
    return result.rooms
        .where(
          (room) =>
              room.steamId.contains(query) ||
              room.broadcaster.toLowerCase().contains(query) ||
              room.title.toLowerCase().contains(query) ||
              room.game.toLowerCase().contains(query),
        )
        .take(pageSize)
        .map((room) => _room(room, includeMedia: false))
        .toList(growable: false);
  }

  String _steamId(LiveRoom liveroom) {
    final roomId = liveroom.roomId ?? '';
    final platform = liveroom.platform ?? '';
    if (platform.trim().toLowerCase() != id) throw const SteamBroadcastException(SteamBroadcastFailure.identity);
    final value = SteamBroadcastLink.parseSteamId(roomId);
    if (value == null) throw const SteamBroadcastException(SteamBroadcastFailure.identity);
    return value;
  }

  Future<LiveRoom> _detail(LiveRoom liveroom, {required bool includeMedia, CancelToken? cancel}) async {
    final steamId = _steamId(liveroom);
    var room = await _api.room(steamId, includeMedia: includeMedia, cancel: cancel);
    final known = _known[steamId];
    if (known != null) room = room.enrich(known);
    _known[steamId] = room;
    return _room(room, includeMedia: includeMedia);
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return _detail(liveroom, includeMedia: true);
  }

  @override
  Future<LiveRoom> getRoomDetailForRecording(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return _detail(liveroom, includeMedia: true);
  }

  @override
  Future<LiveRoom> getRoomDetailForRefresh(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return _detail(liveroom, includeMedia: false);
  }

  SteamBroadcastRoom _snapshot(LiveRoom liveroom) {
    final steamId = _steamId(liveroom);
    final room = liveroom.data;
    if (room is! SteamBroadcastRoom || room.steamId != steamId || room.state != SteamBroadcastState.live) {
      throw const SteamBroadcastException(SteamBroadcastFailure.mediaUnavailable);
    }
    if (room.master == null) throw const SteamBroadcastException(SteamBroadcastFailure.mediaUnavailable);
    return room;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom liveroom}) async {
    if (liveroom.isExplicitlyOfflineNow) return const [];
    _snapshot(liveroom);
    return [LivePlayQuality(id: 'auto', quality: i18n('steambroadcast_quality_auto'))];
  }

  Future<LivePlayUrlResolution> _resolve(LiveRoom liveroom, LivePlayQuality quality, {required bool refresh}) async {
    var room = _snapshot(liveroom);
    if (quality.selectionId != 'auto') throw const SteamBroadcastException(SteamBroadcastFailure.schema);
    if (refresh) {
      room = _snapshot(await _detail(LiveRoom(roomId: room.steamId, platform: id), includeMedia: true));
    }
    return LivePlayUrlResolution(urls: [room.master!.toString()], appliedQualityData: 'auto');
  }

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsRaw({required LiveRoom liveroom, required LivePlayQuality quality}) =>
      _resolve(liveroom, quality, refresh: false);

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsForRecoveryRaw({
    required LiveRoom liveroom,
    required LivePlayQuality quality,
  }) => _resolve(liveroom, quality, refresh: true);

  @override
  Future<List<String>> getPlayUrls({required LiveRoom liveroom, required LivePlayQuality quality}) async =>
      (await _resolve(liveroom, quality, refresh: false)).urls;
}
