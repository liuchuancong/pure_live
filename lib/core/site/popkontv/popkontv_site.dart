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

import 'popkontv_api.dart';
import 'popkontv_link.dart';

class PopkonSite extends LiveSite
    implements
        LiveSiteDirectoryPager,
        LiveDirectoryNotice,
        LiveCancellableSearch,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayUrlResolver,
        LivePlayRecoveryResolver {
  PopkonSite({PopkonApi? api}) : _api = api ?? PopkonApi();

  final PopkonApi _api;

  @override
  String get id => 'popkontv';

  @override
  String get name => 'PopkonTV';

  @override
  String get directoryNoticeKey => 'popkontv_directory_scope';

  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async => page == 1
      ? [
          LiveCategory(
            id: id,
            name: name,
            children: [
              LiveArea(
                platform: id,
                areaType: 'sort',
                areaId: 'popular',
                areaName: i18n('popkontv_sort_popular'),
                typeName: name,
              ),
              LiveArea(
                platform: id,
                areaType: 'sort',
                areaId: 'latest',
                areaName: i18n('popkontv_sort_latest'),
                typeName: name,
              ),
              LiveArea(
                platform: id,
                areaType: 'sort',
                areaId: 'rookie',
                areaName: i18n('popkontv_sort_rookie'),
                typeName: name,
              ),
              LiveArea(
                platform: id,
                areaType: 'sort',
                areaId: 'hot',
                areaName: i18n('popkontv_sort_hot'),
                typeName: name,
              ),
            ],
          ),
        ]
      : [];

  int _sortType(LiveArea? category) {
    if (category == null) return 2;
    if (category.platform != id || category.areaType != 'sort') {
      throw const PopkonException(PopkonFailure.identity);
    }
    return switch (category.areaId) {
      'popular' => 2,
      'latest' => 0,
      'rookie' => 3,
      'hot' => 4,
      _ => throw const PopkonException(PopkonFailure.identity),
    };
  }

  static String _notice(PopkonAccess access) => switch (access) {
    PopkonAccess.public => i18n('popkontv_chat_notice'),
    PopkonAccess.password => i18n('popkontv_password_notice'),
    PopkonAccess.adult => i18n('popkontv_adult_notice'),
    PopkonAccess.restricted => i18n('popkontv_restricted_notice'),
  };

  static LiveRoom _directoryCard(PopkonCard room) {
    final access = room.isPrivate
        ? PopkonAccess.password
        : room.isAdult
        ? PopkonAccess.adult
        : PopkonAccess.public;
    return LiveRoom(
      platform: 'popkontv',
      roomId: room.roomId,
      userId: room.signId,
      title: room.title,
      nick: room.nickname,
      avatar: room.avatar,
      cover: room.cover,
      area: room.category,
      link: PopkonLink.url(room.roomId),
      liveStatus: LiveStatus.live,
      onlineViewers: room.onlineViewers?.toString(),
      totalViewers: room.totalViewers?.toString(),
      followers: room.followers?.toString(),
      audienceMetricType: AudienceMetricType.onlineViewers,
      notice: _notice(access),
      httpHeaders: PopkonApi.mediaHeaders(room.roomId),
    );
  }

  static LiveRoom _room(PopkonRoom room, {required bool includeMedia}) => LiveRoom(
    platform: 'popkontv',
    roomId: room.roomId,
    userId: room.signId,
    title: room.title,
    nick: room.nickname,
    avatar: room.avatar,
    cover: room.cover,
    area: room.category,
    link: PopkonLink.url(room.roomId),
    liveStatus: switch (room.state) {
      PopkonState.live => LiveStatus.live,
      PopkonState.offline => LiveStatus.offline,
      PopkonState.unknown => LiveStatus.unknown,
    },
    onlineViewers: room.onlineViewers?.toString(),
    totalViewers: room.totalViewers?.toString(),
    followers: room.followers?.toString(),
    audienceMetricType: AudienceMetricType.onlineViewers,
    notice: _notice(room.access),
    httpHeaders: PopkonApi.mediaHeaders(room.roomId),
    data: includeMedia ? room : null,
  );

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    final result = await _api.directory(page: page, sortType: _sortType(category), cancel: cancel);
    final seen = <String>{};
    return LiveDirectoryPage(
      page: page,
      hasMore: result.hasMore,
      rooms: result.rooms.where((room) => seen.add(room.roomId.toLowerCase())).map(_directoryCard),
    );
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async =>
      (await getDirectoryPage(page: page)).rooms;

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async =>
      (await getDirectoryPage(page: page, category: category)).rooms;

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
    if (page != 1 || pageSize < 1) return [];
    final link = PopkonLink.parse(keyword);
    if (link != null) {
      try {
        return [_room(await _api.room(link.storageKey, resolveMedia: false, cancel: cancel), includeMedia: false)];
      } on PopkonException catch (error) {
        if (error.kind == PopkonFailure.missing) return [];
        rethrow;
      }
    }
    final rooms = await _api.search(keyword, cancel: cancel);
    return List.unmodifiable(rooms.take(pageSize).map((room) => _room(room, includeMedia: false)));
  }

  String _roomId(String roomId, String platform) {
    if (platform.trim().toLowerCase() != id) throw const PopkonException(PopkonFailure.identity);
    final key = PopkonLink.parseKey(roomId);
    if (key == null) throw const PopkonException(PopkonFailure.identity);
    return key.storageKey;
  }

  Future<LiveRoom> _detail(String roomId, String platform, {required bool includeMedia}) async {
    final data = await _api.room(_roomId(roomId, platform), resolveMedia: includeMedia);
    return _room(data, includeMedia: includeMedia);
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
    if (room.effectiveLiveStatus == LiveStatus.unknown) throw const PopkonException(PopkonFailure.unknownState);
    return room.isLiveNow;
  }

  PopkonRoom _snapshot(LiveRoom detail) {
    final expected = _roomId(detail.roomId ?? '', detail.platform ?? '');
    final data = detail.data;
    if (data is! PopkonRoom || data.roomId.toLowerCase() != expected.toLowerCase()) {
      throw const PopkonException(PopkonFailure.identity);
    }
    if (data.state != PopkonState.live || data.access != PopkonAccess.public || data.streams.isEmpty) {
      throw const PopkonException(PopkonFailure.mediaUnavailable);
    }
    return data;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    if (detail.isExplicitlyOfflineNow) return [];
    final room = _snapshot(detail);
    return List.unmodifiable(
      room.streams.map(
        (stream) => LivePlayQuality(
          id: stream.id,
          quality: '${stream.label} · HLS',
          sort: stream.height * 10000000 + stream.bandwidth,
        ),
      ),
    );
  }

  Future<LivePlayUrlResolution> _resolve(LiveRoom detail, LivePlayQuality quality, {required bool refresh}) async {
    var room = _snapshot(detail);
    if (refresh) room = _snapshot(await getRoomDetail(roomId: room.roomId, platform: id));
    final selectionId = quality.selectionId.toString();
    for (final stream in room.streams) {
      if (stream.id == selectionId) {
        return LivePlayUrlResolution(urls: [stream.uri.toString()], appliedQualityData: selectionId);
      }
    }
    throw const PopkonException(PopkonFailure.mediaUnavailable);
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
