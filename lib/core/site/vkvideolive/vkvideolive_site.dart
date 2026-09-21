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

import 'vkvideolive_api.dart';
import 'vkvideolive_link.dart';

class VkVideoLiveSite extends LiveSite
    implements
        LiveSiteDirectoryPager,
        LiveDirectoryNotice,
        LiveCancellableSearch,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayUrlResolver,
        LivePlayRecoveryResolver,
        LivePlayLeaseMetadata {
  VkVideoLiveSite({VkVideoLiveApi? api}) : _api = api ?? VkVideoLiveApi();

  final VkVideoLiveApi _api;
  final Map<String, int> _directoryOffsets = {'all:1': 0};
  final Map<String, String?> _searchCursors = {};

  @override
  String get id => 'vkvideolive';

  @override
  String get name => 'VK Video Live';

  @override
  String get directoryNoticeKey => 'vkvideolive_directory_scope';

  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    if (page < 1 || pageSize < 1) return [];
    final result = await _api.categories(offset: (page - 1) * pageSize, limit: pageSize.clamp(1, 100));
    if (result.items.isEmpty) return [];
    return [
      LiveCategory(
        id: id,
        name: name,
        children: result.items
            .map(
              (category) => LiveArea(
                platform: id,
                areaType: category.type,
                areaId: category.id,
                areaName: category.title,
                typeName: name,
              ),
            )
            .toList(growable: false),
      ),
    ];
  }

  String? _categoryId(LiveArea? category) {
    if (category == null) return null;
    final categoryId = category.areaId;
    if (category.platform != id || categoryId == null || categoryId.isEmpty) {
      throw const VkVideoLiveException(VkVideoLiveFailure.identity);
    }
    return categoryId;
  }

  static LiveRoom _room(VkVideoLiveRoom room, {required bool includeMedia}) => LiveRoom(
    platform: 'vkvideolive',
    roomId: room.channel,
    userId: room.userId,
    title: room.title,
    nick: room.nickname,
    avatar: room.avatar,
    cover: room.cover,
    area: room.category,
    link: VkVideoLiveLink.url(room.channel),
    liveStatus: switch (room.state) {
      VkVideoLiveState.live => LiveStatus.live,
      VkVideoLiveState.offline => LiveStatus.offline,
      VkVideoLiveState.unknown => LiveStatus.unknown,
    },
    onlineViewers: room.viewerCount?.toString(),
    totalViewers: room.totalViews?.toString(),
    followers: room.followers?.toString(),
    audienceMetricType: AudienceMetricType.onlineViewers,
    notice: i18n(room.hasAccess ? 'vkvideolive_chat_notice' : 'vkvideolive_restricted_notice'),
    httpHeaders: VkVideoLiveApi.mediaHeaders(room.channel),
    data: includeMedia ? room : null,
  );

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    if (page < 1) return LiveDirectoryPage(page: page, hasMore: false, rooms: const []);
    final categoryId = _categoryId(category);
    final scope = categoryId ?? 'all';
    final offsetKey = '$scope:$page';
    final offset = page == 1 ? 0 : _directoryOffsets[offsetKey];
    if (offset == null) return LiveDirectoryPage(page: page, hasMore: false, rooms: const []);
    final result = await _api.directory(categoryId: categoryId, offset: offset, cancel: cancel);
    if (result.hasMore && result.nextOffset != null) {
      _directoryOffsets['$scope:${page + 1}'] = result.nextOffset!;
    } else {
      _directoryOffsets.remove('$scope:${page + 1}');
    }
    final seen = <String>{};
    return LiveDirectoryPage(
      page: page,
      hasMore: result.hasMore && result.nextOffset != null,
      rooms: result.items.where((room) => seen.add(room.channel)).map((room) => _room(room, includeMedia: false)),
    );
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async =>
      (await getDirectoryPage(page: page)).rooms.take(pageSize).toList(growable: false);

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async =>
      (await getDirectoryPage(page: page, category: category)).rooms.take(pageSize).toList(growable: false);

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
    if (page < 1 || pageSize < 1) return [];
    final raw = keyword.trim();
    final link = VkVideoLiveLink.parse(raw);
    if (link != null) {
      try {
        return [_room(await _api.room(link.channel, resolveMedia: false, cancel: cancel), includeMedia: false)];
      } on VkVideoLiveException catch (error) {
        if (error.kind == VkVideoLiveFailure.missing) return [];
        rethrow;
      }
    }
    final searchKey = raw.toLowerCase();
    final cursorKey = '$searchKey:$page';
    final cursor = page == 1 ? null : _searchCursors[cursorKey];
    if (page > 1 && cursor == null) return [];
    final result = await _api.search(raw, after: cursor, limit: pageSize.clamp(1, 100), cancel: cancel);
    if (result.hasMore && result.nextCursor != null) {
      _searchCursors['$searchKey:${page + 1}'] = result.nextCursor;
    } else {
      _searchCursors.remove('$searchKey:${page + 1}');
    }
    return List.unmodifiable(result.items.map((room) => _room(room, includeMedia: false)));
  }

  String _channel(String roomId, String platform) {
    if (platform.trim().toLowerCase() != id) throw const VkVideoLiveException(VkVideoLiveFailure.identity);
    final key = VkVideoLiveLink.parseKey(roomId);
    if (key == null) throw const VkVideoLiveException(VkVideoLiveFailure.identity);
    return key.storageKey;
  }

  Future<LiveRoom> _detail(String roomId, String platform, {required bool includeMedia}) async {
    final room = await _api.room(_channel(roomId, platform), resolveMedia: includeMedia);
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
      throw const VkVideoLiveException(VkVideoLiveFailure.unknownState);
    }
    return room.isLiveNow;
  }

  VkVideoLiveRoom _snapshot(LiveRoom detail) {
    final expected = _channel(detail.roomId ?? '', detail.platform ?? '');
    final data = detail.data;
    if (data is! VkVideoLiveRoom || data.channel != expected) {
      throw const VkVideoLiveException(VkVideoLiveFailure.identity);
    }
    if (data.state != VkVideoLiveState.live || !data.hasAccess || data.qualities.isEmpty) {
      throw const VkVideoLiveException(VkVideoLiveFailure.mediaUnavailable);
    }
    return data;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    if (detail.isExplicitlyOfflineNow) return [];
    final room = _snapshot(detail);
    return List.unmodifiable(
      room.qualities.map(
        (quality) => LivePlayQuality(
          id: quality.id,
          quality: quality.label,
          sort: quality.height * 10000000 + quality.bandwidth,
        ),
      ),
    );
  }

  Future<LivePlayUrlResolution> _resolve(LiveRoom detail, LivePlayQuality quality, {required bool refresh}) async {
    var room = _snapshot(detail);
    if (refresh) {
      final refreshed = await getRoomDetail(roomId: room.channel, platform: id);
      room = _snapshot(refreshed);
    }
    final selectionId = quality.selectionId.toString();
    for (final stream in room.qualities) {
      if (stream.id == selectionId) {
        return LivePlayUrlResolution(
          urls: stream.urls.map((uri) => uri.toString()).toList(growable: false),
          appliedQualityData: selectionId,
        );
      }
    }
    throw const VkVideoLiveException(VkVideoLiveFailure.mediaUnavailable);
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
  DateTime? getPlayUrlRefreshAt(String url, {DateTime? now}) => VkVideoLiveApi.mediaRefreshAt(url);

  @override
  DateTime? getPlayUrlInvalidAt(String url, {DateTime? now}) => VkVideoLiveApi.mediaInvalidAt(url);
}
