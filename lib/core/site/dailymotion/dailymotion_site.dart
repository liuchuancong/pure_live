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

import 'dailymotion_api.dart';
import 'dailymotion_browser.dart';
import 'dailymotion_link.dart';

final class DailymotionSite extends LiveSite
    implements
        LiveSiteDirectoryPager,
        LiveDirectoryNotice,
        LiveCancellableSearch,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayUrlResolver,
        LivePlayRecoveryResolver {
  DailymotionSite({DailymotionApi? api, DailymotionMediaResolver? mediaResolver})
    : _api = api ?? DailymotionApi(),
      _mediaResolver = mediaResolver ?? DailymotionBrowserMediaResolver();

  final DailymotionApi _api;
  final DailymotionMediaResolver _mediaResolver;

  @override
  String get id => 'dailymotion';

  @override
  String get name => 'Dailymotion';

  @override
  String get directoryNoticeKey => 'dailymotion_directory_scope';

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
                areaType: 'live',
                areaId: 'onair',
                areaName: i18n('dailymotion_category_live'),
                typeName: name,
              ),
            ],
          ),
        ]
      : [];

  void _category(LiveArea? category) {
    if (category != null && (category.platform != id || category.areaType != 'live' || category.areaId != 'onair')) {
      throw const DailymotionException(DailymotionFailure.identity);
    }
  }

  static LiveRoom _room(DailymotionRoom room, {required bool includeMedia}) => LiveRoom(
    platform: 'dailymotion',
    roomId: room.videoId,
    userId: room.ownerId,
    title: room.title,
    nick: room.screenName,
    avatar: room.thumbnail,
    cover: room.thumbnail,
    area: 'Dailymotion Live',
    introduction: room.description,
    link: DailymotionLink.videoUrl(room.videoId),
    liveStatus: room.state == DailymotionState.live ? LiveStatus.live : LiveStatus.offline,
    audienceMetricType: AudienceMetricType.unknown,
    notice: i18n('dailymotion_chat_notice'),
    httpHeaders: DailymotionApi.mediaHeaders,
    data: includeMedia ? room : null,
  );

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    _category(category);
    if (page < 1) return LiveDirectoryPage(rooms: const [], page: page, hasMore: false);
    final result = await _api.directory(page: page, limit: 30, cancel: cancel);
    return LiveDirectoryPage(
      rooms: result.items.map((room) => _room(room, includeMedia: false)),
      page: page,
      hasMore: result.hasMore,
    );
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    if (page < 1 || pageSize < 1) return [];
    final result = await _api.directory(page: page, limit: pageSize.clamp(1, 100));
    return result.items.map((room) => _room(room, includeMedia: false)).toList(growable: false);
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
    if (raw.isEmpty || page < 1 || pageSize < 1) return [];
    final videoId = DailymotionLink.parseVideoId(raw);
    if (videoId != null) {
      if (page != 1) return [];
      try {
        return [_room(await _api.room(videoId, cancel: cancel), includeMedia: false)];
      } on DailymotionException catch (error) {
        if (error.kind == DailymotionFailure.missing || error.kind == DailymotionFailure.notLive) return [];
        rethrow;
      }
    }
    final username = DailymotionLink.parseUsername(raw);
    if (username != null) {
      try {
        final user = await _api.userLive(username, page: page, limit: pageSize.clamp(1, 100), cancel: cancel);
        if (user.items.isNotEmpty || user.hasMore) {
          return user.items.map((room) => _room(room, includeMedia: false)).toList(growable: false);
        }
      } on DailymotionException catch (error) {
        if (error.kind != DailymotionFailure.missing) rethrow;
      }
    }
    final result = await _api.search(raw, page: page, limit: pageSize.clamp(1, 100), cancel: cancel);
    return result.items.map((room) => _room(room, includeMedia: false)).toList(growable: false);
  }

  String _videoId(String roomId, String platform) {
    if (platform.trim().toLowerCase() != id) throw const DailymotionException(DailymotionFailure.identity);
    final videoId = DailymotionLink.parseVideoId(roomId);
    if (videoId == null) throw const DailymotionException(DailymotionFailure.identity);
    return videoId;
  }

  Future<LiveRoom> _detail(
    String roomId,
    String platform, {
    required bool includeMedia,
    bool refreshMedia = false,
  }) async {
    var room = await _api.room(_videoId(roomId, platform));
    if (includeMedia && room.state == DailymotionState.live) {
      room = room.withQualities(await _mediaResolver.resolve(room.videoId, refresh: refreshMedia));
    }
    return _room(room, includeMedia: includeMedia);
  }

  @override
  Future<LiveRoom> getRoomDetail({required String roomId, required String platform}) =>
      _detail(roomId, platform, includeMedia: true);

  @override
  Future<LiveRoom> getRoomDetailForRecording({required String roomId, required String platform}) =>
      _detail(roomId, platform, includeMedia: true, refreshMedia: true);

  @override
  Future<LiveRoom> getRoomDetailForRefresh({required String roomId, required String platform}) =>
      _detail(roomId, platform, includeMedia: false);

  @override
  Future<bool> getLiveStatus({required String platform, required String roomId}) async =>
      (await getRoomDetailForRefresh(roomId: roomId, platform: platform)).isLiveNow;

  DailymotionRoom _snapshot(LiveRoom detail) {
    final videoId = _videoId(detail.roomId ?? '', detail.platform ?? '');
    final room = detail.data;
    if (room is! DailymotionRoom || room.videoId != videoId) {
      throw const DailymotionException(DailymotionFailure.identity);
    }
    if (room.state != DailymotionState.live || room.qualities.isEmpty) {
      throw const DailymotionException(DailymotionFailure.mediaUnavailable);
    }
    return room;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    if (detail.isExplicitlyOfflineNow) return [];
    final room = _snapshot(detail);
    return room.qualities
        .map((quality) => LivePlayQuality(id: quality.id, quality: quality.label, sort: quality.sort))
        .toList(growable: false);
  }

  Future<LivePlayUrlResolution> _resolve(LiveRoom detail, LivePlayQuality quality, {required bool refresh}) async {
    var room = _snapshot(detail);
    if (refresh) {
      room = _snapshot(await _detail(room.videoId, id, includeMedia: true, refreshMedia: true));
    }
    final selectionId = quality.selectionId.toString();
    for (final stream in room.qualities) {
      if (stream.id == selectionId) {
        return LivePlayUrlResolution(urls: [stream.url.toString()], appliedQualityData: selectionId);
      }
    }
    throw const DailymotionException(DailymotionFailure.mediaUnavailable);
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
