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
        LivePlayRecoveryResolver {
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
      if (room.state == LookLiveState.restricted) i18n('looklive_restricted_notice'),
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
        LookLiveState.restricted || LookLiveState.unknown => LiveStatus.unknown,
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
        return [await _detail(roomId, id, includeMedia: false, cancel: cancel)];
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

  String _roomId(String roomId, String platform) {
    if (platform.trim().toLowerCase() != id) throw const LookLiveException(LookLiveFailure.identity);
    final value = LookLiveLink.parseRoomId(roomId);
    if (value == null) throw const LookLiveException(LookLiveFailure.identity);
    return value;
  }

  Future<LiveRoom> _detail(String roomId, String platform, {required bool includeMedia, CancelToken? cancel}) async {
    final normalized = _roomId(roomId, platform);
    var room = await _api.room(normalized, includeMedia: includeMedia, cancel: cancel);
    final known = _known[normalized];
    if (known != null) room = room.enrich(known);
    _known[normalized] = room;
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
    if (detail.effectiveLiveStatus == LiveStatus.unknown) throw const LookLiveException(LookLiveFailure.access);
    return detail.isLiveNow;
  }

  LookLiveRoom _snapshot(LiveRoom detail) {
    final roomId = _roomId(detail.roomId ?? '', detail.platform ?? '');
    final room = detail.data;
    if (room is! LookLiveRoom || room.roomId != roomId) {
      throw const LookLiveException(LookLiveFailure.identity);
    }
    if (room.state != LookLiveState.live || room.variants.isEmpty) {
      throw const LookLiveException(LookLiveFailure.mediaUnavailable);
    }
    return room;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    if (detail.isExplicitlyOfflineNow) return const [];
    final room = _snapshot(detail);
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

  Future<LivePlayUrlResolution> _resolve(LiveRoom detail, LivePlayQuality quality, {required bool refresh}) async {
    var room = _snapshot(detail);
    if (refresh) room = _snapshot(await _detail(room.roomId, id, includeMedia: true));
    final selectionId = quality.selectionId.toString();
    for (final variant in room.variants) {
      if (variant.id != selectionId) continue;
      return LivePlayUrlResolution(urls: [variant.uri.toString()], appliedQualityData: variant.id);
    }
    throw const LookLiveException(LookLiveFailure.mediaUnavailable);
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
