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

import 'rumble_api.dart';
import 'rumble_browser.dart';
import 'rumble_link.dart';

final class RumbleSite extends LiveSite
    implements
        LiveSiteDirectoryPager,
        LiveDirectoryNotice,
        LiveCancellableSearch,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayUrlResolver,
        LivePlayRecoveryResolver {
  RumbleSite({RumbleApi? api, RumblePageResolver? pageResolver})
    : _api = api ?? RumbleApi(),
      _pageResolver = pageResolver ?? RumbleBrowserPageResolver();

  final RumbleApi _api;
  final RumblePageResolver _pageResolver;

  @override
  String get id => 'rumble';

  @override
  String get name => 'Rumble';

  @override
  String get directoryNoticeKey => 'rumble_directory_scope';

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
                areaId: 'public',
                areaName: i18n('rumble_category_live'),
                typeName: name,
              ),
            ],
          ),
        ]
      : [];

  void _category(LiveArea? category) {
    if (category != null && (category.platform != id || category.areaType != 'live' || category.areaId != 'public')) {
      throw const RumbleException(RumbleFailure.identity);
    }
  }

  static LiveRoom _room(RumbleRoom room, {required bool includeMedia}) {
    final current = room.currentViewers?.toString();
    final total = room.totalViews?.toString();
    return LiveRoom(
      platform: 'rumble',
      roomId: room.videoKey,
      userId: room.channel,
      title: room.title,
      nick: room.channelName,
      avatar: room.avatar,
      cover: room.cover,
      area: room.category.isEmpty ? 'Rumble Live' : room.category,
      introduction: room.description,
      link: RumbleLink.videoUrl(room.videoKey),
      liveStatus: room.state == RumbleState.live ? LiveStatus.live : LiveStatus.offline,
      onlineViewers: current,
      totalViewers: total,
      followers: room.followers?.toString(),
      audienceMetricType: current != null
          ? AudienceMetricType.onlineViewers
          : total != null
          ? AudienceMetricType.totalViewers
          : AudienceMetricType.unknown,
      notice: i18n('rumble_chat_notice'),
      httpHeaders: RumbleApi.mediaHeaders(room.videoKey),
      data: includeMedia ? room : null,
    );
  }

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    _category(category);
    if (page < 1) return LiveDirectoryPage(rooms: const [], page: page, hasMore: false);
    final result = await _api.directory(page: page, cancel: cancel);
    return LiveDirectoryPage(
      rooms: result.items.map((room) => _room(room, includeMedia: false)),
      page: page,
      hasMore: result.hasMore,
    );
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    if (page < 1 || pageSize < 1) return [];
    final result = await _api.directory(page: page);
    return result.items.take(pageSize.clamp(1, 60)).map((room) => _room(room, includeMedia: false)).toList();
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
    final videoKey = RumbleLink.parseVideoKey(raw);
    if (videoKey != null) {
      if (page != 1) return [];
      try {
        return [await _detail(videoKey, id, includeMedia: false)];
      } on RumbleException catch (error) {
        if (error.kind == RumbleFailure.missing) return [];
        rethrow;
      }
    }

    final reference = RumbleLink.parse(raw);
    final channel = reference?.kind == RumbleLinkKind.channel ? reference!.id.toLowerCase() : null;
    final query = raw.toLowerCase();
    final result = await _api.directory(page: page, cancel: cancel);
    final matches = result.items.where((room) {
      if (channel != null) return room.channel.toLowerCase() == channel;
      return room.title.toLowerCase().contains(query) ||
          room.channelName.toLowerCase().contains(query) ||
          room.channel.toLowerCase().contains(query) ||
          room.category.toLowerCase().contains(query);
    });
    return matches.take(pageSize.clamp(1, 60)).map((room) => _room(room, includeMedia: false)).toList(growable: false);
  }

  String _videoKey(String roomId, String platform) {
    if (platform.trim().toLowerCase() != id) throw const RumbleException(RumbleFailure.identity);
    final videoKey = RumbleLink.parseVideoKey(roomId);
    if (videoKey == null) throw const RumbleException(RumbleFailure.identity);
    return videoKey;
  }

  Future<RumbleRoom> _metadata(String videoKey) async {
    try {
      return await _api.room(videoKey);
    } on RumbleException catch (error) {
      if (error.kind != RumbleFailure.access &&
          error.kind != RumbleFailure.transport &&
          error.kind != RumbleFailure.service &&
          error.kind != RumbleFailure.rateLimited) {
        rethrow;
      }
      return _pageResolver.resolve(videoKey, includeMedia: false, refresh: true);
    }
  }

  Future<LiveRoom> _detail(
    String roomId,
    String platform, {
    required bool includeMedia,
    bool refreshMedia = false,
  }) async {
    final videoKey = _videoKey(roomId, platform);
    var room = await _metadata(videoKey);
    if (includeMedia && room.state == RumbleState.live) {
      room = await _pageResolver.resolve(videoKey, includeMedia: true, refresh: refreshMedia);
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

  RumbleRoom _snapshot(LiveRoom detail) {
    final videoKey = _videoKey(detail.roomId ?? '', detail.platform ?? '');
    final room = detail.data;
    if (room is! RumbleRoom || room.videoKey != videoKey) throw const RumbleException(RumbleFailure.identity);
    if (room.state != RumbleState.live || room.qualities.isEmpty) {
      throw const RumbleException(RumbleFailure.mediaUnavailable);
    }
    return room;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    if (detail.isExplicitlyOfflineNow) return [];
    return _snapshot(detail).qualities
        .map((quality) => LivePlayQuality(id: quality.id, quality: quality.label, sort: quality.sort))
        .toList();
  }

  Future<LivePlayUrlResolution> _resolve(LiveRoom detail, LivePlayQuality quality, {required bool refresh}) async {
    var room = _snapshot(detail);
    if (refresh) {
      room = _snapshot(await _detail(room.videoKey, id, includeMedia: true, refreshMedia: true));
    }
    final selected = quality.selectionId.toString();
    for (final stream in room.qualities) {
      if (stream.id == selected) {
        return LivePlayUrlResolution(urls: [stream.url.toString()], appliedQualityData: selected);
      }
    }
    throw const RumbleException(RumbleFailure.mediaUnavailable);
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
