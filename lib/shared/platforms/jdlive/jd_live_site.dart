import 'package:dio/dio.dart';
import 'package:pure_live/core/models/live_area.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/shared/platforms/live_directory.dart';
import 'package:pure_live/shared/platforms/live_search.dart';
import 'package:pure_live/shared/platforms/live_site.dart';
import 'package:pure_live/core/models/live_category.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/core/utils/i18n.dart';
import 'package:pure_live/shared/platforms/live_external_room.dart';

import 'jd_live_api.dart';
import 'jd_live_danmaku.dart';
import 'jd_live_link.dart';

final class JdLiveSite extends LiveSite
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
    return officialExternalRoom(() => JdLiveLink.watchUrl(id));
  }

  JdLiveSite({JdLiveApi? api}) : _api = api ?? JdLiveApi();

  final JdLiveApi _api;
  final Map<String, JdLiveRoom> _known = {};
  final Map<String, _JdDirectorySequence> _sequences = {};

  @override
  String get id => 'jdlive';

  @override
  String get name => 'JD Live';

  @override
  String get directoryNoticeKey => 'jdlive_directory_scope';

  @override
  LiveDanmaku getDanmaku() => JdLiveDanmaku();

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async => page == 1 && pageSize > 0
      ? [
          LiveCategory(
            id: id,
            name: name,
            children: [
              LiveArea(
                platform: id,
                areaType: 'official',
                areaId: 'featured',
                areaName: i18n('jdlive_category_featured'),
                typeName: name,
              ),
            ],
          ),
        ]
      : [];

  void _category(LiveArea? category) {
    if (category != null &&
        (category.platform != id || category.areaType != 'official' || category.areaId != 'featured')) {
      throw const JdLiveException(JdLiveFailure.identity);
    }
  }

  void _remember(Iterable<JdLiveRoom> rooms) {
    for (final room in rooms) {
      _known[room.liveId] = room;
    }
  }

  static LiveRoom _room(JdLiveRoom room, {required bool includeMedia}) {
    final total = room.totalViews?.toString();
    final status = switch (room.state) {
      JdLiveState.live => LiveStatus.live,
      JdLiveState.preview || JdLiveState.offline || JdLiveState.replay => LiveStatus.offline,
      JdLiveState.paused || JdLiveState.unknown => LiveStatus.unknown,
    };
    return LiveRoom(
      platform: 'jdlive',
      roomId: room.liveId,
      userId: room.authorId.isEmpty ? room.liveId : room.authorId,
      title: room.title,
      nick: room.nick,
      avatar: room.avatar.isEmpty ? room.cover : room.avatar,
      cover: room.cover,
      area: 'JD Live',
      link: JdLiveLink.watchUrl(room.liveId),
      liveStatus: status,
      restriction: status == LiveStatus.live ? room.restriction : null,
      totalViewers: total,
      audienceMetricType: total == null ? AudienceMetricType.unknown : AudienceMetricType.totalViewers,
      notice: room.appOnly ? i18n('jdlive_restricted_notice') : i18n('jdlive_chat_notice'),
      httpHeaders: JdLiveApi.mediaHeaders(room.liveId),
      danmakuData: status == LiveStatus.live ? JdLiveDanmakuArgs(liveId: room.liveId) : null,
      data: includeMedia ? room : null,
    );
  }

  Future<JdLivePage> _directory(String key, int page, CancelToken? cancel) async {
    if (page < 1) return JdLivePage(rooms: const [], nextCount: 0, hasMore: false);
    if (page == 1) {
      _sequences[key] = _JdDirectorySequence(DateTime.now().millisecondsSinceEpoch);
    }
    final sequence = _sequences[key];
    final count = sequence?.counts[page];
    if (sequence == null || count == null) {
      return JdLivePage(rooms: const [], nextCount: 0, hasMore: false);
    }
    final result = await _api.directory(page: page, currentCount: count, timestamp: sequence.timestamp, cancel: cancel);
    _remember(result.rooms);
    if (result.hasMore) {
      sequence.counts[page + 1] = result.nextCount;
    } else {
      sequence.counts.remove(page + 1);
    }
    return result;
  }

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    _category(category);
    final result = await _directory('directory', page, cancel);
    return LiveDirectoryPage(
      rooms: result.rooms.map((room) => _room(room, includeMedia: false)),
      page: page,
      hasMore: result.hasMore,
    );
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    if (page < 1 || pageSize < 1) return [];
    final result = await _directory('recommend', page, null);
    return result.rooms
        .take(pageSize.clamp(1, 30))
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
    final liveId = JdLiveLink.parseLiveId(raw);
    if (liveId != null) {
      if (page != 1) return [];
      try {
        return [
          await _detail(
            LiveRoom(roomId: liveId, platform: id),
            includeMedia: false,
            cancel: cancel,
          ),
        ];
      } on JdLiveException catch (error) {
        if (error.kind == JdLiveFailure.missing) return [];
        rethrow;
      }
    }
    final query = raw.toLowerCase();
    final result = await _directory('search:$query', page, cancel);
    return result.rooms
        .where(
          (room) =>
              room.liveId.contains(query) ||
              room.authorId.contains(query) ||
              room.nick.toLowerCase().contains(query) ||
              room.title.toLowerCase().contains(query),
        )
        .take(pageSize)
        .map((room) => _room(room, includeMedia: false))
        .toList(growable: false);
  }

  String _liveId(LiveRoom liveroom) {
    final roomId = liveroom.roomId ?? '';
    final platform = liveroom.platform ?? '';
    if (platform.trim().toLowerCase() != id) throw const JdLiveException(JdLiveFailure.identity);
    final value = JdLiveLink.parseLiveId(roomId);
    if (value == null) throw const JdLiveException(JdLiveFailure.identity);
    return value;
  }

  Future<LiveRoom> _detail(LiveRoom liveroom, {required bool includeMedia, CancelToken? cancel}) async {
    final liveId = _liveId(liveroom);
    var room = await _api.room(liveId, includeMedia: includeMedia, cancel: cancel);
    final known = _known[liveId];
    if (known != null) room = room.enrich(known);
    _known[liveId] = room;
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

  JdLiveRoom _snapshot(LiveRoom liveroom) {
    final liveId = _liveId(liveroom);
    final room = liveroom.data;
    if (room is! JdLiveRoom || room.liveId != liveId || room.state != JdLiveState.live || room.hls == null) {
      throw const JdLiveException(JdLiveFailure.mediaUnavailable);
    }
    return room;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom liveroom}) async {
    if (liveroom.isExplicitlyOfflineNow) return const [];
    final room = _snapshot(liveroom);
    return [
      LivePlayQuality(id: 'hls', quality: i18n('jdlive_quality_hls'), sort: 2),
      if (room.flv != null) LivePlayQuality(id: 'flv', quality: i18n('jdlive_quality_flv'), sort: 1),
    ];
  }

  Future<LivePlayUrlResolution> _resolve(LiveRoom liveroom, LivePlayQuality quality, {required bool refresh}) async {
    var room = _snapshot(liveroom);
    if (refresh) room = _snapshot(await _detail(LiveRoom(roomId: room.liveId, platform: id), includeMedia: true));
    return switch (quality.selectionId) {
      'hls' => LivePlayUrlResolution(urls: [room.hls!.toString()], appliedQualityData: 'hls'),
      'flv' when room.flv != null => LivePlayUrlResolution(urls: [room.flv!.toString()], appliedQualityData: 'flv'),
      _ => throw const JdLiveException(JdLiveFailure.mediaUnavailable),
    };
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

final class _JdDirectorySequence {
  _JdDirectorySequence(this.timestamp);

  final int timestamp;
  final Map<int, int> counts = {1: 0};
}
