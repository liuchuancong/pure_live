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

import 'baidu_live_api.dart';
import 'baidu_live_link.dart';

final class BaiduLiveSite extends LiveSite
    implements
        LiveSiteDirectoryPager,
        LiveDirectoryNotice,
        LiveCancellableSearch,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayUrlResolver,
        LivePlayRecoveryResolver {
  BaiduLiveSite({BaiduLiveApi? api})
    : _api = api ?? BaiduLiveApi(),
      _deviceId = 'pc-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}purelivedev';

  final BaiduLiveApi _api;
  final String _deviceId;
  final Map<String, BaiduLiveRoom> _known = {};
  final Map<String, _BaiduDirectorySequence> _sequences = {};
  List<BaiduLiveCategory>? _categories;

  @override
  String get id => 'baidulive';

  @override
  String get name => i18n('site_baidulive');

  @override
  String get directoryNoticeKey => 'baidulive_directory_scope';

  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    if (page != 1 || pageSize < 1) return const [];
    final categories = _categories ?? BaiduLiveApi.fallbackCategories;
    return [
      LiveCategory(
        id: id,
        name: name,
        children: categories
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

  BaiduLiveCategory _category(LiveArea? category) {
    final categories = _categories ?? BaiduLiveApi.fallbackCategories;
    if (category == null) return categories.first;
    if (category.platform != id || category.areaType != 'official') {
      throw const BaiduLiveException(BaiduLiveFailure.identity);
    }
    final categoryId = category.areaId?.trim() ?? '';
    return categories.firstWhere(
      (item) => item.id == categoryId,
      orElse: () => throw const BaiduLiveException(BaiduLiveFailure.identity),
    );
  }

  Future<BaiduLivePage> _directory(BaiduLiveCategory category, int page, CancelToken? cancel) async {
    final key = category.id;
    if (page < 1) {
      return BaiduLivePage(rooms: const [], categories: const [], sessionId: '', refreshIndex: 0, hasMore: false);
    }
    if (page == 1) _sequences[key] = _BaiduDirectorySequence();
    final sequence = _sequences[key];
    if (sequence == null || page != sequence.nextPage) {
      return BaiduLivePage(
        rooms: const [],
        categories: const [],
        sessionId: sequence?.sessionId ?? '',
        refreshIndex: sequence?.refreshIndex ?? 0,
        hasMore: false,
      );
    }
    final previousRefreshIndex = sequence.refreshIndex;
    final result = await _api.directory(
      page: page,
      tab: category.id,
      channelId: category.channelId,
      sessionId: sequence.sessionId,
      refreshIndex: page == 1 ? 1 : sequence.refreshIndex + 1,
      deviceId: _deviceId,
      cancel: cancel,
    );
    if (result.categories.isNotEmpty) _categories = result.categories;
    final fresh = result.rooms.where((room) => sequence.seen.add(room.roomId)).toList(growable: false);
    final advanced = page == 1 || result.refreshIndex > previousRefreshIndex;
    final hasMore = result.hasMore && fresh.isNotEmpty && advanced;
    sequence
      ..sessionId = result.sessionId
      ..refreshIndex = result.refreshIndex
      ..nextPage = hasMore ? page + 1 : page;
    _remember(fresh);
    return BaiduLivePage(
      rooms: fresh,
      categories: result.categories,
      sessionId: result.sessionId,
      refreshIndex: result.refreshIndex,
      hasMore: hasMore,
    );
  }

  void _remember(Iterable<BaiduLiveRoom> rooms) {
    for (final room in rooms) {
      _known[room.roomId] = room;
    }
  }

  static LiveRoom _room(BaiduLiveRoom room, {required bool includeMedia}) {
    final online = room.currentViewers?.toString();
    final notice = <String>[
      if (room.state == BaiduLiveState.restricted) i18n('baidulive_restricted_notice'),
      i18n('baidulive_chat_notice'),
    ];
    return LiveRoom(
      platform: 'baidulive',
      roomId: room.roomId,
      userId: room.userId.isEmpty ? room.roomId : room.userId,
      title: room.title,
      nick: room.nick,
      avatar: room.avatar.isEmpty ? room.cover : room.avatar,
      cover: room.cover,
      area: room.category.isEmpty ? i18n('site_baidulive') : room.category,
      link: BaiduLiveLink.watchUrl(room.roomId),
      liveStatus: switch (room.state) {
        BaiduLiveState.live => LiveStatus.live,
        BaiduLiveState.preview || BaiduLiveState.offline || BaiduLiveState.replay => LiveStatus.offline,
        BaiduLiveState.restricted || BaiduLiveState.unknown => LiveStatus.unknown,
      },
      watching: online ?? '',
      onlineViewers: online,
      followers: room.followers?.toString(),
      audienceMetricType: online == null ? AudienceMetricType.unknown : AudienceMetricType.onlineViewers,
      notice: notice.join('\n'),
      httpHeaders: BaiduLiveApi.mediaHeaders(room.roomId),
      data: includeMedia ? room : null,
    );
  }

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    if (page < 1) return LiveDirectoryPage(rooms: const [], page: page, hasMore: false);
    final result = await _directory(_category(category), page, cancel);
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
    final roomId = BaiduLiveLink.parseRoomId(keyword.trim());
    if (roomId == null || page != 1 || pageSize < 1) return const [];
    try {
      return [await _detail(roomId, id, includeMedia: false, cancel: cancel)];
    } on BaiduLiveException catch (error) {
      if (error.kind == BaiduLiveFailure.missing) return const [];
      rethrow;
    }
  }

  String _roomId(String roomId, String platform) {
    if (platform.trim().toLowerCase() != id) throw const BaiduLiveException(BaiduLiveFailure.identity);
    final value = BaiduLiveLink.parseRoomId(roomId);
    if (value == null) throw const BaiduLiveException(BaiduLiveFailure.identity);
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
    if (detail.effectiveLiveStatus == LiveStatus.unknown) {
      throw const BaiduLiveException(BaiduLiveFailure.access);
    }
    return detail.isLiveNow;
  }

  BaiduLiveRoom _snapshot(LiveRoom detail) {
    final roomId = _roomId(detail.roomId ?? '', detail.platform ?? '');
    final room = detail.data;
    if (room is! BaiduLiveRoom || room.roomId != roomId) {
      throw const BaiduLiveException(BaiduLiveFailure.identity);
    }
    if (room.state != BaiduLiveState.live || room.variants.isEmpty) {
      throw const BaiduLiveException(BaiduLiveFailure.mediaUnavailable);
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
          quality: variant.resolution > 0
              ? i18n(
                  'baidulive_quality_resolution',
                  args: {
                    'protocol': variant.protocol.toUpperCase(),
                    'resolution': '${variant.resolution}',
                    'codec': variant.codec.toUpperCase(),
                  },
                )
              : i18n(
                  'baidulive_quality_source',
                  args: {'protocol': variant.protocol.toUpperCase(), 'codec': variant.codec.toUpperCase()},
                ),
          sort: variant.resolution * 10 + (variant.protocol == 'hls' ? 1 : 2),
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
    throw const BaiduLiveException(BaiduLiveFailure.mediaUnavailable);
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

final class _BaiduDirectorySequence {
  String sessionId = '';
  int refreshIndex = 0;
  int nextPage = 1;
  final Set<String> seen = {};
}
