import 'package:dio/dio.dart';
import 'package:pure_live/core/models/live_area.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/shared/platforms/live_directory.dart';
import 'package:pure_live/shared/platforms/live_search.dart';
import 'package:pure_live/shared/platforms/live_site.dart';
import 'six_room_danmaku.dart';
import 'package:pure_live/core/models/live_category.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/core/utils/i18n.dart';
import 'package:pure_live/shared/platforms/live_external_room.dart';

import 'sixroom_api.dart';
import 'sixroom_link.dart';

final class SixRoomSite extends LiveSite
    implements
        LiveSiteDirectoryPager,
        LiveDirectoryNotice,
        LiveCancellableSearch,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayUrlResolver,
        LivePlayRecoveryResolver,
        LiveSiteExternalRoomResolver {
  @override
  RoomExternalTarget? externalRoomTarget(LiveRoom liveroom) {
    final id = sanitizedExternalRoomId(liveroom.roomId);
    if (id == null) return null;
    return officialExternalRoom(() => SixRoomLink.watchUrl(id));
  }

  SixRoomSite({SixRoomApi? api}) : _api = api ?? SixRoomApi();

  final SixRoomApi _api;
  final Map<String, SixRoomRoom> _known = {};

  @override
  String get id => 'sixroom';

  @override
  String get name => i18n('site_sixroom');

  @override
  String get directoryNoticeKey => 'sixroom_directory_scope';

  @override
  LiveDanmaku getDanmaku() => SixRoomDanmaku();

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    if (page != 1 || pageSize < 1) return const [];
    return [
      LiveCategory(
        id: id,
        name: name,
        children: SixRoomApi.categories
            .take(pageSize)
            .map(
              (category) => LiveArea(
                platform: id,
                areaType: 'official',
                areaId: category.id,
                areaName: category.name,
                typeName: name,
              ),
            )
            .toList(growable: false),
      ),
    ];
  }

  String _categoryId(LiveArea? category) {
    if (category == null) return 'all';
    if (category.platform != id || category.areaType != 'official') {
      throw const SixRoomException(SixRoomFailure.identity);
    }
    final categoryId = category.areaId?.trim() ?? '';
    if (!SixRoomApi.categories.any((item) => item.id == categoryId)) {
      throw const SixRoomException(SixRoomFailure.identity);
    }
    return categoryId;
  }

  void _remember(Iterable<SixRoomRoom> rooms) {
    for (var room in rooms) {
      final known = _known[room.roomId];
      if (known != null) room = room.enrich(known);
      _known[room.roomId] = room;
    }
  }

  static LiveRoom _room(SixRoomRoom room, {required bool includeMedia}) {
    final popularity = room.popularity?.toString();
    final notices = <String>[
      if (room.state == SixRoomState.restricted) i18n('sixroom_restricted_notice'),
      i18n('sixroom_chat_notice'),
    ];
    return LiveRoom(
      platform: 'sixroom',
      roomId: room.roomId,
      userId: room.userId,
      title: room.title,
      nick: room.nick,
      avatar: room.avatar.isEmpty ? room.cover : room.avatar,
      cover: room.cover,
      area: room.category.isEmpty ? i18n('site_sixroom') : room.category,
      link: SixRoomLink.watchUrl(room.roomId),
      liveStatus: switch (room.state) {
        SixRoomState.live => LiveStatus.live,
        SixRoomState.offline => LiveStatus.offline,
        SixRoomState.restricted => LiveStatus.live,
        SixRoomState.unknown => LiveStatus.unknown,
      },
      restriction: room.state == SixRoomState.restricted ? room.restriction : null,
      watching: popularity ?? '',
      popularity: popularity,
      followers: room.followers?.toString(),
      audienceMetricType: popularity == null ? AudienceMetricType.unknown : AudienceMetricType.popularity,
      notice: notices.join('\n'),
      httpHeaders: SixRoomApi.mediaHeaders(room.roomId),
      danmakuData: room.userId.trim().isEmpty
          ? null
          : SixRoomDanmakuArgs(roomId: room.roomId, userId: room.userId.trim()),
      data: includeMedia ? room : null,
    );
  }

  Future<LiveDirectoryPage> _directoryPage({
    required int page,
    required int pageSize,
    LiveArea? category,
    CancelToken? cancel,
  }) async {
    if (page < 1 || pageSize < 1) return LiveDirectoryPage(rooms: const [], page: page, hasMore: false);
    final result = await _api.directory(
      page: page,
      pageSize: pageSize.clamp(1, 100),
      categoryId: _categoryId(category),
      cancel: cancel,
    );
    _remember(result.rooms);
    return LiveDirectoryPage(
      rooms: result.rooms.map((room) => _room(_known[room.roomId]!, includeMedia: false)).toList(growable: false),
      page: page,
      hasMore: result.hasMore,
    );
  }

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) =>
      _directoryPage(page: page, pageSize: 30, category: category, cancel: cancel);

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async =>
      (await _directoryPage(page: page, pageSize: pageSize)).rooms;

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async =>
      (await _directoryPage(page: page, pageSize: pageSize, category: category)).rooms;

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
    if (raw.isEmpty || page < 1 || pageSize < 1 || pageSize > 100) return const [];
    final roomId = SixRoomLink.parseRoomId(raw);
    if (roomId != null) {
      if (page != 1) return const [];
      try {
        return [
          await _detail(
            LiveRoom(roomId: roomId, platform: id),
            includeMedia: false,
            cancel: cancel,
          ),
        ];
      } on SixRoomException catch (error) {
        if (error.kind == SixRoomFailure.missing) return const [];
        rethrow;
      }
    }
    if (page != 1) return const [];
    final rooms = await _api.search(raw, cancel: cancel);
    _remember(rooms);
    return rooms.take(pageSize).map((room) => _room(_known[room.roomId]!, includeMedia: false)).toList(growable: false);
  }

  String _roomId(LiveRoom liveroom) {
    final roomId = liveroom.roomId ?? '';
    final platform = liveroom.platform ?? '';
    if (platform.trim().toLowerCase() != id) throw const SixRoomException(SixRoomFailure.identity);
    final value = SixRoomLink.parseRoomId(roomId);
    if (value == null) throw const SixRoomException(SixRoomFailure.identity);
    return value;
  }

  Future<LiveRoom> _detail(LiveRoom liveroom, {required bool includeMedia, CancelToken? cancel}) async {
    final normalized = _roomId(liveroom);
    final known = _known[normalized];
    var room = await _api.room(normalized, knownUserId: known?.userId, includeMedia: includeMedia, cancel: cancel);
    if (known != null) room = room.enrich(known);
    _known[normalized] = room;
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

  SixRoomRoom _snapshot(LiveRoom liveroom) {
    final roomId = _roomId(liveroom);
    final room = liveroom.data;
    if (room is! SixRoomRoom || room.roomId != roomId) throw const SixRoomException(SixRoomFailure.identity);
    if (room.state != SixRoomState.live || room.variants.isEmpty) {
      throw const SixRoomException(SixRoomFailure.mediaUnavailable);
    }
    return room;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom liveroom}) async {
    _roomId(liveroom);
    if (liveroom.isExplicitlyOfflineNow) return const [];
    final room = _snapshot(liveroom);
    return List.unmodifiable(
      room.variants.map((variant) {
        final metadata = <String>[
          if (variant.resolution.isNotEmpty) variant.resolution,
          if (variant.bitrate != null) '${variant.bitrate} kbps',
        ];
        return LivePlayQuality(
          id: variant.id,
          quality: metadata.isEmpty
              ? i18n('sixroom_quality_source')
              : i18n('sixroom_quality_source_detail', args: {'detail': metadata.join(' · ')}),
          sort: variant.bitrate ?? 1,
        );
      }),
    );
  }

  Future<LivePlayUrlResolution> _resolve(LiveRoom liveroom, LivePlayQuality quality, {required bool refresh}) async {
    var room = _snapshot(liveroom);
    if (refresh) room = _snapshot(await _detail(LiveRoom(roomId: room.roomId, platform: id), includeMedia: true));
    final selectionId = quality.selectionId.toString();
    for (final variant in room.variants) {
      if (variant.id != selectionId) continue;
      return LivePlayUrlResolution(
        urls: variant.urls.map((uri) => uri.toString()).toList(growable: false),
        appliedQualityData: variant.id,
      );
    }
    throw const SixRoomException(SixRoomFailure.mediaUnavailable);
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
