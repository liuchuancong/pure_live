import 'package:dio/dio.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/danmaku/empty_danmaku.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/interface/live_directory.dart';
import 'package:pure_live/core/interface/live_search.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/plugins/locale_helper.dart';

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
        LivePlayRecoveryResolver {
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
      SteamBroadcastState.offline => LiveStatus.offline,
      SteamBroadcastState.restricted || SteamBroadcastState.unknown => LiveStatus.unknown,
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
        return [await _detail(steamId, id, includeMedia: false, cancel: cancel)];
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

  String _steamId(String roomId, String platform) {
    if (platform.trim().toLowerCase() != id) throw const SteamBroadcastException(SteamBroadcastFailure.identity);
    final value = SteamBroadcastLink.parseSteamId(roomId);
    if (value == null) throw const SteamBroadcastException(SteamBroadcastFailure.identity);
    return value;
  }

  Future<LiveRoom> _detail(String roomId, String platform, {required bool includeMedia, CancelToken? cancel}) async {
    final steamId = _steamId(roomId, platform);
    var room = await _api.room(steamId, includeMedia: includeMedia, cancel: cancel);
    final known = _known[steamId];
    if (known != null) room = room.enrich(known);
    _known[steamId] = room;
    return _room(room, includeMedia: includeMedia);
  }

  @override
  Future<LiveRoom> getRoomDetail({required String roomId, required String platform}) =>
      _detail(roomId, platform, includeMedia: true);

  @override
  Future<LiveRoom> getRoomDetailForRecording({required String roomId, required String platform}) =>
      _detail(roomId, platform, includeMedia: true);

  @override
  Future<LiveRoom> getRoomDetailForRefresh({required String roomId, required String platform}) =>
      _detail(roomId, platform, includeMedia: false);

  @override
  Future<bool> getLiveStatus({required String platform, required String roomId}) async {
    final detail = await getRoomDetailForRefresh(roomId: roomId, platform: platform);
    if (detail.effectiveLiveStatus == LiveStatus.unknown) {
      throw const SteamBroadcastException(SteamBroadcastFailure.access);
    }
    return detail.isLiveNow;
  }

  SteamBroadcastRoom _snapshot(LiveRoom detail) {
    final steamId = _steamId(detail.roomId ?? '', detail.platform ?? '');
    final room = detail.data;
    if (room is! SteamBroadcastRoom || room.steamId != steamId || room.state != SteamBroadcastState.live) {
      throw const SteamBroadcastException(SteamBroadcastFailure.mediaUnavailable);
    }
    if (room.master == null) throw const SteamBroadcastException(SteamBroadcastFailure.mediaUnavailable);
    return room;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    if (detail.isExplicitlyOfflineNow) return const [];
    _snapshot(detail);
    return [LivePlayQuality(id: 'auto', quality: i18n('steambroadcast_quality_auto'))];
  }

  Future<LivePlayUrlResolution> _resolve(LiveRoom detail, LivePlayQuality quality, {required bool refresh}) async {
    var room = _snapshot(detail);
    if (quality.selectionId != 'auto') throw const SteamBroadcastException(SteamBroadcastFailure.schema);
    if (refresh) {
      room = _snapshot(await _detail(room.steamId, id, includeMedia: true));
    }
    return LivePlayUrlResolution(urls: [room.master!.toString()], appliedQualityData: 'auto');
  }

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsRaw({required LiveRoom detail, required LivePlayQuality quality}) =>
      _resolve(detail, quality, refresh: false);

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsForRecoveryRaw({
    required LiveRoom detail,
    required LivePlayQuality quality,
  }) => _resolve(detail, quality, refresh: true);

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async =>
      (await _resolve(detail, quality, refresh: false)).urls;
}
