import 'dart:async';

import 'package:dio/dio.dart';
import 'package:pure_live/common/index.dart' show i18n;
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/danmaku/empty_danmaku.dart';
import 'package:pure_live/core/common/request_scope.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/interface/live_directory.dart';
import 'package:pure_live/core/interface/live_search.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/model/live_play_quality.dart';

import 'huajiao_api.dart';
import 'huajiao_link.dart';

class HuajiaoSite extends LiveSite
    implements
        LiveSiteCursorDirectoryPager,
        LiveDirectoryNotice,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayRecoveryResolver,
        LiveCancellableSearch,
        LiveSearchPaginationPolicy {
  HuajiaoSite({HuajiaoApi? api}) : _api = api ?? HuajiaoApi();
  final HuajiaoApi _api;
  @override
  String get id => 'huajiao';
  @override
  String get name => i18n('site_huajiao');
  @override
  String get directoryNoticeKey => 'huajiao_directory_scope';
  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  static LiveRoom _card(HuajiaoFeed feed) => LiveRoom(
    platform: 'huajiao',
    roomId: feed.userId,
    userId: feed.userId,
    nick: feed.name,
    title: feed.title,
    avatar: feed.avatar,
    cover: feed.cover,
    link: HuajiaoLink.ownerUrl(feed.userId),
    liveStatus: LiveStatus.live,
    popularity: feed.heat?.toString(),
    audienceMetricType: AudienceMetricType.popularity,
  );

  @override
  Future<LiveDirectoryPage> getDirectoryPageAtCursor({
    required int page,
    String? cursor,
    LiveArea? category,
    CancelToken? cancel,
  }) async {
    if (page < 1 ||
        (page == 1 && cursor != null) ||
        (page > 1 && cursor == null) ||
        (category != null && (category.platform != id || category.areaType != 'h5' || category.areaId != 'live5'))) {
      throw const HuajiaoException(HuajiaoFailure.schema);
    }
    final offset = cursor == null ? 0 : int.tryParse(cursor);
    if (offset == null || (cursor != null && !RegExp(r'^[0-9]{1,7}$').hasMatch(cursor))) {
      throw const HuajiaoException(HuajiaoFailure.schema);
    }
    final response = await _api.directory(offset: offset, cancel: cancel);
    final seen = <String>{};
    return LiveDirectoryPage(
      page: page,
      nextCursor: '${response.nextOffset}',
      hasMore: response.hasMore,
      rooms: response.feeds.where((feed) => seen.add(feed.userId)).map(_card),
    );
  }

  /// Compatibility callers have no cursor parameter. Replay a bounded prefix;
  /// the actual mobile/desktop catalogue uses the cursor contract above and
  /// retains its complete pages independently, without this replay cost.
  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    if (page < 1 || page > 20) throw const HuajiaoException(HuajiaoFailure.schema);
    return withRequestCancellation(cancel, (owned) async {
      Future<LiveDirectoryPage> replay() async {
        String? cursor;
        for (var current = 1; current <= page; current++) {
          final result = await getDirectoryPageAtCursor(
            page: current,
            cursor: cursor,
            category: category,
            cancel: owned,
          );
          if (current == page) return result;
          if (!result.hasMore) return LiveDirectoryPage(page: page, hasMore: false, rooms: const []);
          cursor = result.nextCursor;
        }
        throw const HuajiaoException(HuajiaoFailure.schema);
      }

      try {
        return await replay().timeout(const Duration(seconds: 20));
      } on TimeoutException {
        throw const HuajiaoException(HuajiaoFailure.transport);
      }
    });
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async =>
      (await getDirectoryPage(page: page)).rooms;
  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async =>
      (await getDirectoryPage(page: page, category: category)).rooms;
  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async => page == 1
      ? [
          LiveCategory(
            id: id,
            name: name,
            children: [
              LiveArea(platform: id, areaType: 'h5', areaId: 'live5', areaName: i18n('huajiao_hot'), typeName: name),
            ],
          ),
        ]
      : [];

  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) =>
      searchRoomsCancellable(keyword, page: page, pageSize: pageSize);

  static const int searchRecommendationPages = 3;

  @override
  bool supportsSearchPaginationFor(String keyword) {
    final input = keyword.trim();
    return input.isNotEmpty &&
        input.length <= 100 &&
        !HuajiaoLink.validId(input) &&
        !RegExp(r'^[0-9]+$').hasMatch(input) &&
        HuajiaoLink.parse(input) == null &&
        Uri.tryParse(input)?.hasScheme != true;
  }

  @override
  Future<List<LiveRoom>> searchRoomsCancellable(
    String keyword, {
    int page = 1,
    int pageSize = 30,
    CancelToken? cancel,
  }) async {
    if (page < 1 || pageSize < 1 || pageSize > 50) throw const HuajiaoException(HuajiaoFailure.schema);
    final input = keyword.trim();
    String? uid;
    if (HuajiaoLink.validId(input)) {
      uid = input;
    } else {
      final link = HuajiaoLink.parse(input);
      if (link?.kind == HuajiaoLinkKind.owner) uid = link!.id;
    }
    if (uid == null) {
      if (!supportsSearchPaginationFor(input) || RegExp(r'[\x00-\x1f]').hasMatch(input)) return const [];
      final start = (page - 1) * pageSize;
      if (start >= searchRecommendationPages * 30) return const [];
      final query = input.toLowerCase();
      final matches = <String, LiveRoom>{};
      var offset = 0;
      // This is a bounded filter of the official public recommendation feed,
      // not a platform-wide broadcaster index or a fabricated search API.
      for (var index = 0; index < searchRecommendationPages; index++) {
        if (cancel?.isCancelled == true) throw const HuajiaoException(HuajiaoFailure.cancelled);
        final result = await _api.directory(offset: offset, cancel: cancel);
        if (cancel?.isCancelled == true) throw const HuajiaoException(HuajiaoFailure.cancelled);
        for (final feed in result.feeds) {
          if (feed.name.toLowerCase().contains(query) || feed.title.toLowerCase().contains(query)) {
            matches.putIfAbsent(feed.userId, () => _card(feed));
          }
        }
        if (!result.hasMore || matches.length >= start + pageSize) break;
        offset = result.nextOffset;
      }
      return List.unmodifiable(matches.values.skip(start).take(pageSize));
    }
    if (page > 1) return const [];
    try {
      return [_owner(await _api.owner(uid, cancel: cancel))];
    } on HuajiaoException catch (error) {
      if (error.kind == HuajiaoFailure.notFound) return const [];
      rethrow;
    }
  }

  LiveRoom _owner(HuajiaoOwner owner) => LiveRoom(
    platform: id,
    roomId: owner.userId,
    userId: owner.userId,
    nick: owner.name,
    title: owner.name,
    avatar: owner.avatar,
    cover: owner.avatar,
    link: HuajiaoLink.ownerUrl(owner.userId),
    watching: '',
    audienceMetricType: AudienceMetricType.unknown,
    status: owner.isLive,
    liveStatus: owner.isLive ? LiveStatus.live : LiveStatus.offline,
  );

  Future<LiveRoom> _detail(String uid, String platform, {required bool playback}) async {
    if (platform != id) throw const HuajiaoException(HuajiaoFailure.identity);
    if (!playback) return _owner(await _api.owner(uid));
    final room = await _api.room(uid);
    final broadcast = room.broadcast;
    if (broadcast == null) return _owner(room.owner);
    final result = _card(broadcast.feed);
    final media = <String, List<String>>{};
    for (final stream in broadcast.media) {
      media.putIfAbsent(stream.format, () => []).add(stream.url);
    }
    result.data = [
      for (final group in media.entries)
        LivePlayQuality(
          id: group.key,
          quality: group.key == 'unknown' ? i18n('huajiao_original_stream') : group.key.toUpperCase(),
          data: List<String>.unmodifiable(group.value),
        ),
    ];
    return result;
  }

  @override
  Future<LiveRoom> getRoomDetail({required String roomId, required String platform}) =>
      _detail(roomId, platform, playback: true);
  @override
  Future<LiveRoom> getRoomDetailForRecording({required String roomId, required String platform}) =>
      _detail(roomId, platform, playback: true);
  @override
  Future<LiveRoom> getRoomDetailForRefresh({required String roomId, required String platform}) =>
      _detail(roomId, platform, playback: false);
  @override
  Future<bool> getLiveStatus({required String platform, required String roomId}) async =>
      (await getRoomDetailForRefresh(roomId: roomId, platform: platform)).isLiveNow;
  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    if (detail.platform != id) throw const HuajiaoException(HuajiaoFailure.identity);
    if (detail.isExplicitlyOfflineNow) return [];
    if (!detail.isLiveNow || detail.data is! List<LivePlayQuality> || (detail.data as List).isEmpty) {
      throw const HuajiaoException(HuajiaoFailure.mediaUnavailable);
    }
    return List.unmodifiable(detail.data as List<LivePlayQuality>);
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    for (final current in await getPlayQualites(detail: detail)) {
      if (current.selectionId == quality.selectionId) return List.unmodifiable(current.data as List<String>);
    }
    throw const HuajiaoException(HuajiaoFailure.mediaUnavailable);
  }

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsForRecoveryRaw({
    required LiveRoom detail,
    required LivePlayQuality quality,
  }) async {
    final fresh = await getRoomDetail(roomId: detail.roomId ?? '', platform: detail.platform ?? '');
    return LivePlayUrlResolution(
      urls: await getPlayUrls(detail: fresh, quality: quality),
      appliedQualityData: quality.selectionId,
    );
  }
}
