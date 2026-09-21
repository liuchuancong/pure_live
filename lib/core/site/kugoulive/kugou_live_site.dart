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

import 'kugou_live_api.dart';
import 'kugou_live_link.dart';

final class KugouLiveSite extends LiveSite
    implements
        LiveSiteDirectoryPager,
        LiveDirectoryNotice,
        LiveCancellableSearch,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayUrlResolver,
        LivePlayRecoveryResolver,
        LivePlayLeaseMetadata {
  KugouLiveSite({KugouLiveApi? api}) : _api = api ?? KugouLiveApi();

  final KugouLiveApi _api;
  final Map<String, KugouLiveRoom> _known = {};
  List<KugouLiveCategory>? _categories;

  @override
  String get id => 'kugoulive';

  @override
  String get name => i18n('site_kugoulive');

  @override
  String get directoryNoticeKey => 'kugoulive_directory_scope';

  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    if (page != 1 || pageSize < 1) return const [];
    _categories ??= await _api.categories();
    return [
      LiveCategory(
        id: id,
        name: name,
        children: _categories!
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
    if (category == null) return '8000';
    if (category.platform != id || category.areaType != 'official') {
      throw const KugouLiveException(KugouLiveFailure.identity);
    }
    final categoryId = category.areaId?.trim() ?? '';
    final known = _categories ?? KugouLiveApi.fallbackCategories;
    if (!known.any((item) => item.id == categoryId)) {
      throw const KugouLiveException(KugouLiveFailure.identity);
    }
    return categoryId;
  }

  void _remember(Iterable<KugouLiveRoom> rooms) {
    for (final room in rooms) {
      _known[room.roomId] = room;
    }
  }

  static LiveRoom _room(KugouLiveRoom room, {required bool includeMedia}) {
    final online = room.currentViewers?.toString();
    final popularity = room.popularity?.toString();
    final primary = online ?? popularity;
    final notice = <String>[
      if (room.state == KugouLiveState.restricted) i18n('kugoulive_restricted_notice'),
      i18n('kugoulive_chat_notice'),
    ];
    return LiveRoom(
      platform: 'kugoulive',
      roomId: room.roomId,
      userId: room.userId.isEmpty ? room.kugouId : room.userId,
      title: room.title,
      nick: room.nick,
      avatar: room.avatar.isEmpty ? room.cover : room.avatar,
      cover: room.cover,
      area: i18n('site_kugoulive'),
      link: KugouLiveLink.watchUrl(room.roomId),
      liveStatus: switch (room.state) {
        KugouLiveState.live => LiveStatus.live,
        KugouLiveState.offline => LiveStatus.offline,
        KugouLiveState.restricted || KugouLiveState.unknown => LiveStatus.unknown,
      },
      watching: primary ?? '',
      onlineViewers: online,
      popularity: popularity,
      followers: room.followers?.toString(),
      audienceMetricType: online != null
          ? AudienceMetricType.onlineViewers
          : popularity != null
          ? AudienceMetricType.popularity
          : AudienceMetricType.unknown,
      notice: notice.join('\n'),
      httpHeaders: KugouLiveApi.mediaHeaders(room.roomId),
      data: includeMedia ? room : null,
    );
  }

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    if (page < 1) return LiveDirectoryPage(rooms: const [], page: page, hasMore: false);
    final result = await _api.directory(page: page, categoryId: _categoryId(category), cancel: cancel);
    _remember(result.rooms);
    return LiveDirectoryPage(
      rooms: result.rooms.map((room) => _room(room, includeMedia: false)),
      page: page,
      hasMore: result.hasMore,
    );
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    if (page < 1 || pageSize < 1) return const [];
    final result = await getDirectoryPage(page: page);
    return result.rooms.take(pageSize).toList(growable: false);
  }

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    if (page < 1 || pageSize < 1) return const [];
    final result = await getDirectoryPage(page: page, category: category);
    return result.rooms.take(pageSize).toList(growable: false);
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
    if (raw.isEmpty || page < 1 || pageSize < 1 || pageSize > 100) return const [];
    final roomId = KugouLiveLink.parseRoomId(raw);
    if (roomId != null) {
      if (page != 1) return const [];
      try {
        return [await _detail(roomId, id, includeMedia: false, cancel: cancel)];
      } on KugouLiveException catch (error) {
        if (error.kind == KugouLiveFailure.missing) return const [];
        rethrow;
      }
    }
    final rooms = await _api.search(raw, cancel: cancel);
    _remember(rooms);
    final start = (page - 1) * pageSize;
    if (start >= rooms.length) return const [];
    return rooms.skip(start).take(pageSize).map((room) => _room(room, includeMedia: false)).toList(growable: false);
  }

  String _roomId(String roomId, String platform) {
    if (platform.trim().toLowerCase() != id) {
      throw const KugouLiveException(KugouLiveFailure.identity);
    }
    final value = KugouLiveLink.parseRoomId(roomId);
    if (value == null) throw const KugouLiveException(KugouLiveFailure.identity);
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
    final room = await getRoomDetailForRefresh(roomId: roomId, platform: platform);
    if (room.effectiveLiveStatus == LiveStatus.unknown) {
      throw const KugouLiveException(KugouLiveFailure.access);
    }
    return room.isLiveNow;
  }

  KugouLiveRoom _snapshot(LiveRoom detail) {
    final roomId = _roomId(detail.roomId ?? '', detail.platform ?? '');
    final room = detail.data;
    if (room is! KugouLiveRoom || room.roomId != roomId) {
      throw const KugouLiveException(KugouLiveFailure.identity);
    }
    if (room.state != KugouLiveState.live || room.variants.isEmpty) {
      throw const KugouLiveException(KugouLiveFailure.mediaUnavailable);
    }
    return room;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    _roomId(detail.roomId ?? '', detail.platform ?? '');
    if (detail.isExplicitlyOfflineNow) return const [];
    final room = _snapshot(detail);
    return List.unmodifiable(
      room.variants.map(
        (variant) => LivePlayQuality(
          id: variant.id,
          quality: i18n(
            'kugoulive_quality_rate',
            args: {'protocol': variant.protocol.toUpperCase(), 'rate': '${variant.rate}'},
          ),
          sort: variant.rate * 10 + (variant.protocol == 'hls' ? 1 : 2),
        ),
      ),
    );
  }

  Future<LivePlayUrlResolution> _resolve(LiveRoom detail, LivePlayQuality quality, {required bool refresh}) async {
    var room = _snapshot(detail);
    if (refresh) room = _snapshot(await _detail(room.roomId, id, includeMedia: true));
    final selectionId = quality.selectionId.toString();
    for (final variant in room.variants) {
      if (variant.id != selectionId) continue;
      return LivePlayUrlResolution(
        urls: variant.urls.map((uri) => uri.toString()).toList(growable: false),
        appliedQualityData: variant.id,
      );
    }
    throw const KugouLiveException(KugouLiveFailure.mediaUnavailable);
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

  @override
  DateTime? getPlayUrlRefreshAt(String url, {DateTime? now}) => KugouLiveApi.mediaRefreshAt(url, now: now);

  @override
  DateTime? getPlayUrlInvalidAt(String url, {DateTime? now}) => KugouLiveApi.mediaInvalidAt(url);
}
