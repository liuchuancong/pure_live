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

import 'look_live_api.dart';
import 'look_live_link.dart';

final class LookLiveSite extends LiveSite
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
    return officialExternalRoom(() => LookLiveLink.watchUrl(id));
  }

  LookLiveSite({LookLiveApi? api}) : _api = api ?? LookLiveApi();

  final LookLiveApi _api;
  final Map<String, LookLiveRoom> _known = {};

  @override
  String get id => 'looklive';

  @override
  String get name => i18n('site_looklive');

  @override
  String get directoryNoticeKey => 'looklive_directory_scope';

  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    if (page != 1 || pageSize < 1) return const [];
    return [
      LiveCategory(
        id: id,
        name: name,
        children: [
          LiveArea(
            platform: id,
            areaType: 'official',
            areaId: 'video',
            areaName: i18n('looklive_category_video'),
            typeName: name,
          ),
          LiveArea(
            platform: id,
            areaType: 'official',
            areaId: 'audio',
            areaName: i18n('looklive_category_audio'),
            typeName: name,
          ),
        ].take(pageSize).toList(growable: false),
      ),
    ];
  }

  LookLiveKind? _category(LiveArea? category) {
    if (category == null) return null;
    if (category.platform != id || category.areaType != 'official') {
      throw const LookLiveException(LookLiveFailure.identity);
    }
    return switch (category.areaId) {
      'video' => LookLiveKind.video,
      'audio' => LookLiveKind.audio,
      _ => throw const LookLiveException(LookLiveFailure.identity),
    };
  }

  void _remember(Iterable<LookLiveRoom> rooms) {
    for (var room in rooms) {
      final known = _known[room.roomId];
      if (known != null) room = room.enrich(known);
      _known[room.roomId] = room;
    }
  }

  static LiveRoom _room(LookLiveRoom room, {required bool includeMedia}) {
    final online = room.currentViewers?.toString();
    final popularity = room.popularity?.toString();
    final notices = <String>[
      if (room.state == LookLiveState.banned) i18n('looklive_restricted_notice'),
      if (room.isAppOnly) i18n('looklive_app_only_notice'),
      i18n('looklive_chat_notice'),
    ];
    return LiveRoom(
      platform: 'looklive',
      roomId: room.roomId,
      userId: room.userId,
      title: room.title,
      nick: room.nick,
      avatar: room.avatar.isEmpty ? room.cover : room.avatar,
      cover: room.cover,
      area: i18n(room.kind == LookLiveKind.audio ? 'looklive_category_audio' : 'looklive_category_video'),
      link: LookLiveLink.watchUrl(room.roomId),
      liveStatus: switch (room.state) {
        LookLiveState.live => LiveStatus.live,
        LookLiveState.offline => LiveStatus.offline,
        LookLiveState.banned => LiveStatus.banned,
        LookLiveState.unknown => LiveStatus.unknown,
      },
      watching: online ?? popularity ?? '',
      onlineViewers: online,
      popularity: popularity,
      audienceMetricType: online != null
          ? AudienceMetricType.onlineViewers
          : (popularity != null ? AudienceMetricType.popularity : AudienceMetricType.unknown),
      notice: notices.join('\n'),
      httpHeaders: LookLiveApi.mediaHeaders(room.roomId),
      data: includeMedia ? room : null,
    );
  }

  Future<LookLivePage> _directory(int page, LookLiveKind? kind, CancelToken? cancel) async {
    if (page < 1) return LookLivePage(rooms: const [], hasMore: false);
    if (kind != null) return _api.directory(kind: kind, page: page, cancel: cancel);
    final results = await Future.wait([
      _api.directory(kind: LookLiveKind.video, page: page, cancel: cancel),
      _api.directory(kind: LookLiveKind.audio, page: page, cancel: cancel),
    ]);
    final rooms = <String, LookLiveRoom>{};
    for (final result in results) {
      for (final room in result.rooms) {
        rooms.putIfAbsent(room.roomId, () => room);
      }
    }
    return LookLivePage(rooms: rooms.values, hasMore: results.any((result) => result.hasMore));
  }

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    final result = await _directory(page, _category(category), cancel);
    _remember(result.rooms);
    return LiveDirectoryPage(
      rooms: result.rooms.map((room) => _room(_known[room.roomId]!, includeMedia: false)),
      page: page,
      hasMore: result.hasMore,
    );
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    if (page < 1 || pageSize < 1) return const [];
    return (await getDirectoryPage(page: page)).rooms.take(pageSize).toList(growable: false);
  }

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    if (page < 1 || pageSize < 1) return const [];
    return (await getDirectoryPage(page: page, category: category)).rooms.take(pageSize).toList(growable: false);
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
    if (raw.isEmpty || page != 1 || pageSize < 1 || pageSize > 100) return const [];
    final roomId = LookLiveLink.parseRoomId(raw);
    if (roomId != null) {
      try {
        return [
          await _detail(
            LiveRoom(roomId: roomId, platform: id),
            includeMedia: false,
            cancel: cancel,
          ),
        ];
      } on LookLiveException catch (error) {
        if (error.kind == LookLiveFailure.missing) return const [];
        rethrow;
      }
    }
    final query = raw.toLowerCase();
    final result = await _directory(1, null, cancel);
    _remember(result.rooms);
    return result.rooms
        .where(
          (room) =>
              room.roomId.contains(query) ||
              room.nick.toLowerCase().contains(query) ||
              room.title.toLowerCase().contains(query),
        )
        .take(pageSize)
        .map((room) => _room(_known[room.roomId]!, includeMedia: false))
        .toList(growable: false);
  }

  String _roomId(LiveRoom liveroom) {
    final roomId = liveroom.roomId ?? '';
    final platform = liveroom.platform ?? '';
    if (platform.trim().toLowerCase() != id) throw const LookLiveException(LookLiveFailure.identity);
    final value = LookLiveLink.parseRoomId(roomId);
    if (value == null) throw const LookLiveException(LookLiveFailure.identity);
    return value;
  }

  Future<LiveRoom> _detail(LiveRoom liveroom, {required bool includeMedia, CancelToken? cancel}) async {
    final normalized = _roomId(liveroom);
    var room = await _api.room(normalized, includeMedia: includeMedia, cancel: cancel);
    final known = _known[normalized];
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

  LookLiveRoom _snapshot(LiveRoom liveroom) {
    final roomId = _roomId(liveroom);
    final room = liveroom.data;
    if (room is! LookLiveRoom || room.roomId != roomId) {
      throw const LookLiveException(LookLiveFailure.identity);
    }
    if (room.state != LookLiveState.live || room.variants.isEmpty) {
      throw const LookLiveException(LookLiveFailure.mediaUnavailable);
    }
    return room;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom liveroom}) async {
    if (liveroom.isExplicitlyOfflineNow) return const [];
    final room = _snapshot(liveroom);
    return room.variants
        .map(
          (variant) => LivePlayQuality(
            id: variant.id,
            quality: i18n(variant.protocol == 'hls' ? 'looklive_quality_hls' : 'looklive_quality_flv'),
            sort: variant.protocol == 'hls' ? 2 : 1,
          ),
        )
        .toList(growable: false);
  }

  Future<LivePlayUrlResolution> _resolve(LiveRoom liveroom, LivePlayQuality quality, {required bool refresh}) async {
    var room = _snapshot(liveroom);
    if (refresh) room = _snapshot(await _detail(LiveRoom(roomId: room.roomId, platform: id), includeMedia: true));
    final selectionId = quality.selectionId.toString();
    for (final variant in room.variants) {
      if (variant.id != selectionId) continue;
      return LivePlayUrlResolution(urls: [variant.uri.toString()], appliedQualityData: variant.id);
    }
    throw const LookLiveException(LookLiveFailure.mediaUnavailable);
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
