import 'package:dio/dio.dart';
import 'package:pure_live/core/models/live_area.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/shared/platforms/empty_danmaku.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/shared/platforms/live_directory.dart';
import 'package:pure_live/shared/platforms/live_search.dart';
import 'package:pure_live/shared/platforms/live_site.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/core/utils/i18n.dart';
import 'package:pure_live/shared/platforms/live_external_room.dart';

import 'liveme_api.dart';
import 'liveme_link.dart';

class LiveMeSite extends LiveSite
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
    try {
      return RoomExternalTarget(web: LiveMeLink.url(id));
    } on FormatException {
      return null;
    }
  }

  LiveMeSite({LiveMeApi? api}) : _api = api ?? LiveMeApi();

  final LiveMeApi _api;

  @override
  String get id => 'liveme';

  @override
  String get name => 'LiveMe';

  @override
  String get directoryNoticeKey => 'liveme_directory_scope';

  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    if (category != null) throw const LiveMeException(LiveMeFailure.schema);
    final result = await _api.directory(page: page, cancel: cancel);
    return LiveDirectoryPage(
      page: page,
      hasMore: result.hasMore,
      rooms: result.rooms.map((room) => _card(room, includeMedia: false)),
    );
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    final result = await _api.directory(page: page, pageSize: pageSize.clamp(1, 50));
    return result.rooms.map((room) => _card(room, includeMedia: false)).toList(growable: false);
  }

  LiveRoom _card(LiveMeRoom room, {required bool includeMedia}) {
    final heat = room.heat?.toString();
    return LiveRoom(
      platform: id,
      roomId: room.shortId,
      userId: room.userId,
      nick: room.nickname,
      title: room.title,
      avatar: room.avatar,
      cover: room.cover,
      area: room.countryCode,
      followers: room.followers?.toString(),
      introduction: room.bio,
      link: LiveMeLink.url(room.shortId),
      liveStatus: switch (room.state) {
        LiveMeState.live => LiveStatus.live,
        LiveMeState.offline => LiveStatus.offline,
        LiveMeState.unknown => LiveStatus.unknown,
      },
      // 受限的直播仍然是"在播"（上游 21-5），播放时才说明原因。
      restriction: room.state == LiveMeState.live ? room.restriction : null,
      startedAt: room.startedAt,
      watching: heat ?? '',
      popularity: heat ?? '',
      onlineViewers: room.currentViewers?.toString(),
      totalViewers: room.totalViewers?.toString(),
      audienceMetricType: heat == null ? AudienceMetricType.onlineViewers : AudienceMetricType.popularity,
      notice: i18n('liveme_chat_notice'),
      httpHeaders: LiveMeApi.mediaHeaders(room.shortId),
      data: includeMedia ? room : null,
    );
  }

  String _roomId(LiveRoom liveroom) {
    final roomId = liveroom.roomId ?? '';
    final platform = liveroom.platform ?? '';
    if (platform.trim().toLowerCase() != id) throw const LiveMeException(LiveMeFailure.identity);
    final normalized = LiveMeLink.normalizeShortId(roomId);
    if (normalized == null) throw const LiveMeException(LiveMeFailure.identity);
    return normalized;
  }

  Future<LiveRoom> _detail(LiveRoom liveroom, {required bool includeMedia}) async {
    final data = await _api.room(_roomId(liveroom), includeMedia: includeMedia);
    if (includeMedia && data.state == LiveMeState.live && data.streams.isEmpty) {
      throw const LiveMeException(LiveMeFailure.mediaUnavailable);
    }
    return _card(data, includeMedia: includeMedia);
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
    final reference = LiveMeLink.parseOrShortId(keyword);
    if (reference != null) {
      if (page != 1) return [];
      try {
        final shortId = await _api.resolveReference(reference, cancel: cancel);
        return [_card(await _api.room(shortId, includeMedia: false, cancel: cancel), includeMedia: false)];
      } on LiveMeException catch (error) {
        if (error.kind == LiveMeFailure.missing) return [];
        rethrow;
      }
    }
    if (keyword.trim().isEmpty || page < 1 || pageSize < 1) return [];
    final result = await _api.search(keyword, page: page, pageSize: pageSize.clamp(1, 40), cancel: cancel);
    return result.rooms.map((room) => _card(room, includeMedia: false)).toList(growable: false);
  }

  LiveMeRoom _snapshot(LiveRoom liveroom) {
    final roomId = _roomId(liveroom);
    final data = liveroom.data;
    if (data is! LiveMeRoom || data.shortId != roomId || data.userId != liveroom.userId) {
      throw const LiveMeException(LiveMeFailure.identity);
    }
    if (data.state == LiveMeState.unknown) throw const LiveMeException(LiveMeFailure.unknownState);
    if (data.state != LiveMeState.live || liveroom.isExplicitlyOfflineNow || data.streams.isEmpty) {
      throw const LiveMeException(LiveMeFailure.mediaUnavailable);
    }
    return data;
  }

  static String _qualityName(LiveMeStream stream) => switch (stream.qualityId) {
    'source-flv' => i18n('liveme_quality_source'),
    'smooth-flv' => i18n('liveme_quality_smooth'),
    'hls' => i18n('liveme_quality_hls'),
    _ => throw const LiveMeException(LiveMeFailure.schema),
  };

  static int _qualitySort(String qualityId) => switch (qualityId) {
    'source-flv' => 300,
    'smooth-flv' => 200,
    'hls' => 100,
    _ => 0,
  };

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom liveroom}) async {
    if (liveroom.isExplicitlyOfflineNow) return [];
    final room = _snapshot(liveroom);
    return List.unmodifiable(
      room.streams.map(
        (stream) => LivePlayQuality(
          id: stream.qualityId,
          quality: '${_qualityName(stream)} · ${stream.protocol.toUpperCase()}',
          sort: _qualitySort(stream.qualityId),
        ),
      ),
    );
  }

  Future<LivePlayUrlResolution> _resolve(LiveRoom liveroom, LivePlayQuality quality, {required bool refresh}) async {
    var room = _snapshot(liveroom);
    if (refresh) {
      room = _snapshot(await getRoomDetail(LiveRoom(roomId: room.shortId, platform: id)));
    }
    final qualityId = quality.selectionId.toString();
    for (final stream in room.streams) {
      if (stream.qualityId == qualityId) {
        return LivePlayUrlResolution(
          urls: List.unmodifiable(stream.urls.map((uri) => uri.toString())),
          appliedQualityData: qualityId,
        );
      }
    }
    throw const LiveMeException(LiveMeFailure.mediaUnavailable);
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
