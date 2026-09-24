import 'package:dio/dio.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/danmaku/goodgame_danmaku.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/interface/live_directory.dart';
import 'package:pure_live/core/interface/live_search.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/plugins/locale_helper.dart';

import 'goodgame_api.dart';
import 'goodgame_link.dart';

final class GoodGameSite extends LiveSite
    implements
        LiveSiteDirectoryPager,
        LiveDirectoryNotice,
        LiveCancellableSearch,
        LiveSearchPaginationPolicy,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayUrlResolver,
        LivePlayRecoveryResolver {
  GoodGameSite({GoodGameApi? api}) : _api = api ?? GoodGameApi();

  final GoodGameApi _api;
  static const int maxSearchDirectoryPages = 10;
  static const Duration searchDirectoryCacheAge = Duration(seconds: 30);
  List<GoodGameRoom>? _searchDirectorySnapshot;
  DateTime? _searchDirectoryFetchedAt;

  @override
  String get id => 'goodgame';

  @override
  String get name => 'GoodGame';

  @override
  String get directoryNoticeKey => 'goodgame_directory_scope';

  @override
  LiveDanmaku getDanmaku() => GoodGameDanmaku();

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
                areaId: 'goodgame',
                areaName: i18n('goodgame_category_live'),
                typeName: name,
              ),
            ],
          ),
        ]
      : [];

  void _category(LiveArea? category) {
    if (category != null && (category.platform != id || category.areaType != 'live' || category.areaId != 'goodgame')) {
      throw const GoodGameException(GoodGameFailure.identity);
    }
  }

  static LiveRoom _room(GoodGameRoom room, {required bool includeMedia}) => LiveRoom(
    platform: 'goodgame',
    roomId: room.channel,
    userId: room.channel,
    title: room.title,
    nick: room.channelName,
    avatar: room.avatar,
    cover: room.cover,
    area: room.category.isEmpty ? 'GoodGame Live' : room.category,
    link: GoodGameLink.channelUrl(room.channel),
    danmakuData: room.streamId.toString(),
    liveStatus: switch (room.state) {
      GoodGameState.live => LiveStatus.live,
      GoodGameState.offline => LiveStatus.offline,
      GoodGameState.banned => LiveStatus.banned,
    },
    onlineViewers: room.viewers?.toString(),
    followers: room.followers?.toString(),
    audienceMetricType: room.viewers == null ? AudienceMetricType.unknown : AudienceMetricType.onlineViewers,
    notice: room.adult ? i18n('goodgame_adult_notice') : i18n('goodgame_audience_notice'),
    httpHeaders: GoodGameApi.mediaHeaders(room.channel),
    data: includeMedia ? room : null,
  );

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
    return result.items.take(pageSize.clamp(1, 50)).map((room) => _room(room, includeMedia: false)).toList();
  }

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    _category(category);
    return getRecommendRooms(page: page, pageSize: pageSize);
  }

  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) =>
      searchRoomsCancellable(keyword, page: page, pageSize: pageSize);

  static bool _isExactOnly(String input) =>
      GoodGameLink.parse(input) != null || GoodGameLink.parseReference(input)?.kind == GoodGameLinkKind.player;

  @override
  bool supportsSearchPaginationFor(String keyword) {
    final input = keyword.trim();
    return input.isNotEmpty && !_isExactOnly(input);
  }

  Future<List<GoodGameRoom>> _searchDirectory(CancelToken? cancel) async {
    final snapshot = _searchDirectorySnapshot;
    final fetchedAt = _searchDirectoryFetchedAt;
    if (snapshot != null && fetchedAt != null && DateTime.now().difference(fetchedAt) < searchDirectoryCacheAge) {
      if (cancel?.isCancelled == true) throw cancel!.cancelError!;
      return snapshot;
    }
    final rooms = <GoodGameRoom>[];
    final seen = <String>{};
    for (var directoryPage = 1; directoryPage <= maxSearchDirectoryPages; directoryPage++) {
      final result = await _api.directory(page: directoryPage, cancel: cancel);
      for (final room in result.items) {
        if (seen.add(room.channel)) rooms.add(room);
      }
      if (!result.hasMore) break;
    }
    if (cancel?.isCancelled == true) throw cancel!.cancelError!;
    _searchDirectorySnapshot = List.unmodifiable(rooms);
    _searchDirectoryFetchedAt = DateTime.now();
    return _searchDirectorySnapshot!;
  }

  @override
  Future<List<LiveRoom>> searchRoomsCancellable(
    String keyword, {
    int page = 1,
    int pageSize = 30,
    CancelToken? cancel,
  }) async {
    final raw = keyword.trim();
    if (raw.isEmpty || page < 1 || pageSize < 1) return [];
    final exactOnly = _isExactOnly(raw);
    if (exactOnly && page != 1) return [];
    final reference = GoodGameLink.parseReference(raw);
    if (page == 1 && reference != null && (!raw.contains(' ') || raw.contains('://'))) {
      try {
        return [_room(await _api.room(reference.storageKey, cancel: cancel), includeMedia: false)];
      } on GoodGameException catch (error) {
        if (error.kind != GoodGameFailure.missing && error.kind != GoodGameFailure.schema) rethrow;
        if (exactOnly) return [];
      }
    }
    if (exactOnly) return [];
    final query = raw.toLowerCase();
    final rooms = await _searchDirectory(cancel);
    return rooms
        .where(
          (room) =>
              room.channel.contains(query) ||
              room.channelName.toLowerCase().contains(query) ||
              room.title.toLowerCase().contains(query) ||
              room.category.toLowerCase().contains(query),
        )
        .skip((page - 1) * pageSize)
        .take(pageSize)
        .map((room) => _room(room, includeMedia: false))
        .toList(growable: false);
  }

  GoodGameReference _identity(String roomId, String platform) {
    if (platform.trim().toLowerCase() != id) throw const GoodGameException(GoodGameFailure.identity);
    final reference = GoodGameLink.parseReference(roomId);
    if (reference == null) throw const GoodGameException(GoodGameFailure.identity);
    return reference;
  }

  Future<LiveRoom> _detail(String roomId, String platform, {required bool includeMedia}) async {
    final room = await _api.room(_identity(roomId, platform).storageKey);
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
  Future<bool> getLiveStatus({required String platform, required String roomId}) async =>
      (await getRoomDetailForRefresh(roomId: roomId, platform: platform)).isLiveNow;

  GoodGameRoom _snapshot(LiveRoom detail) {
    final identity = _identity(detail.roomId ?? '', detail.platform ?? '');
    final room = detail.data;
    if (room is! GoodGameRoom ||
        (identity.kind == GoodGameLinkKind.channel && room.channel != identity.value) ||
        (identity.kind == GoodGameLinkKind.player && room.streamId.toString() != identity.value)) {
      throw const GoodGameException(GoodGameFailure.identity);
    }
    if (room.state != GoodGameState.live || room.qualities.isEmpty) {
      throw const GoodGameException(GoodGameFailure.mediaUnavailable);
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
    if (refresh) room = _snapshot(await _detail(room.channel, id, includeMedia: true));
    final selected = quality.selectionId.toString();
    for (final stream in room.qualities) {
      if (stream.id == selected) {
        return LivePlayUrlResolution(urls: [stream.url.toString()], appliedQualityData: selected);
      }
    }
    throw const GoodGameException(GoodGameFailure.mediaUnavailable);
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
