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

import 'pandalive_api.dart';
import 'pandalive_link.dart';

class PandaLiveSite extends LiveSite
    implements
        LiveSiteDirectoryPager,
        LiveDirectoryNotice,
        LiveCancellableSearch,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayUrlResolver,
        LivePlayRecoveryResolver {
  PandaLiveSite({PandaLiveApi? api}) : _api = api ?? PandaLiveApi();

  final PandaLiveApi _api;

  @override
  String get id => 'pandalive';

  @override
  String get name => 'PandaTV';

  @override
  String get directoryNoticeKey => 'pandalive_directory_scope';

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
                areaType: 'directory',
                areaId: 'public',
                areaName: i18n('pandalive_public_directory'),
                typeName: name,
              ),
            ],
          ),
        ]
      : [];

  void _category(LiveArea? category) {
    if (category != null &&
        (category.platform != id || category.areaType != 'directory' || category.areaId != 'public')) {
      throw const PandaLiveException(PandaLiveFailure.identity);
    }
  }

  static LiveRoom _directoryCard(PandaLiveCard room) => LiveRoom(
    platform: 'pandalive',
    roomId: room.userId,
    userId: room.userId,
    title: room.title,
    nick: room.nickname,
    avatar: room.avatar,
    cover: room.cover,
    area: room.category,
    link: PandaLiveLink.url(room.userId),
    liveStatus: LiveStatus.live,
    onlineViewers: room.onlineViewers?.toString(),
    totalViewers: null,
    followers: room.followers?.toString(),
    audienceMetricType: AudienceMetricType.onlineViewers,
    notice: room.isAdult
        ? i18n('pandalive_adult_notice')
        : room.isPassword
        ? i18n('pandalive_password_notice')
        : i18n('pandalive_chat_notice'),
    httpHeaders: PandaLiveApi.mediaHeaders(room.userId),
  );

  LiveRoom _room(PandaLiveRoom room, {required bool includeMedia}) => LiveRoom(
    platform: id,
    roomId: room.userId,
    userId: '${room.userIndex}',
    title: room.title,
    nick: room.nickname,
    avatar: room.avatar,
    cover: room.cover,
    area: room.category,
    link: PandaLiveLink.url(room.userId),
    liveStatus: switch (room.state) {
      PandaLiveState.live => LiveStatus.live,
      PandaLiveState.offline => LiveStatus.offline,
      PandaLiveState.unknown => LiveStatus.unknown,
    },
    onlineViewers: room.onlineViewers?.toString(),
    totalViewers: null,
    followers: room.followers?.toString(),
    introduction: room.introduction,
    audienceMetricType: AudienceMetricType.onlineViewers,
    notice: switch (room.access) {
      PandaLiveAccess.public => i18n('pandalive_chat_notice'),
      PandaLiveAccess.adult => i18n('pandalive_adult_notice'),
      PandaLiveAccess.password => i18n('pandalive_password_notice'),
      PandaLiveAccess.restricted => i18n('pandalive_restricted_notice'),
    },
    httpHeaders: PandaLiveApi.mediaHeaders(room.userId),
    data: includeMedia ? room : null,
  );

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    _category(category);
    final result = await _api.directory(page: page, cancel: cancel);
    final seen = <String>{};
    return LiveDirectoryPage(
      page: page,
      hasMore: result.hasMore,
      rooms: result.rooms.where((room) => seen.add(room.userId.toLowerCase())).map(_directoryCard),
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
    if (page < 1 || pageSize < 1) return [];
    final query = keyword.trim();
    final linkId = PandaLiveLink.parse(query);
    if (linkId != null) {
      if (page > 1) return [];
      try {
        return [_room(await _api.room(linkId, resolveMedia: false, cancel: cancel), includeMedia: false)];
      } on PandaLiveException catch (error) {
        if (error.kind == PandaLiveFailure.missing) return [];
        rethrow;
      }
    }
    if (Uri.tryParse(query)?.hasScheme == true || query.length < 2 || query.length > 100) return [];
    final exactId = PandaLiveLink.normalizeUserId(query);
    if (page == 1 && exactId != null) {
      try {
        return [_room(await _api.room(exactId, resolveMedia: false, cancel: cancel), includeMedia: false)];
      } on PandaLiveException catch (error) {
        if (error.kind != PandaLiveFailure.missing) rethrow;
      }
    }

    // The official site has separate LIVE (title/broadcaster) and BJ (live
    // plus offline profile) searches. Split the requested page between them,
    // preserving each source's native offset/limit instead of pretending that
    // either endpoint has a combined server cursor.
    final liveSize = pageSize > 1 ? (pageSize + 1) ~/ 2 : 0;
    final bjSize = pageSize - liveSize;
    PandaLiveDirectoryPage? live;
    PandaLiveSearchPage? broadcasters;
    Object? liveError;
    Object? bjError;
    // The public gateway may stall one of two simultaneous same-host POSTs.
    // Query BJ profiles first so offline broadcasters remain discoverable.
    try {
      broadcasters = await _api.searchBroadcasters(query, page: page, size: bjSize.clamp(1, 50), cancel: cancel);
    } catch (error) {
      bjError = error;
    }
    if (cancel?.isCancelled == true) throw const PandaLiveException(PandaLiveFailure.cancelled);
    if (liveSize > 0) {
      try {
        live = await _api.searchLive(query, page: page, size: liveSize.clamp(1, 50), cancel: cancel);
      } catch (error) {
        liveError = error;
      }
    }
    if (cancel?.isCancelled == true) throw const PandaLiveException(PandaLiveFailure.cancelled);
    if (live == null && broadcasters == null) throw (liveError ?? bjError)!;
    final seen = <String>{};
    final rooms = <LiveRoom>[
      for (final card in live?.rooms ?? const <PandaLiveCard>[])
        if (seen.add(card.userId.toLowerCase())) _directoryCard(card),
      for (final profile in broadcasters?.rooms ?? const <PandaLiveRoom>[])
        if (seen.add(profile.userId.toLowerCase())) _room(profile, includeMedia: false),
    ];
    if (rooms.isEmpty && (liveError != null || bjError != null)) throw (liveError ?? bjError)!;
    return List.unmodifiable(rooms);
  }

  String _userId(String roomId, String platform) {
    if (platform.trim().toLowerCase() != id) throw const PandaLiveException(PandaLiveFailure.identity);
    final userId = PandaLiveLink.normalizeUserId(roomId);
    if (userId == null) throw const PandaLiveException(PandaLiveFailure.identity);
    return userId;
  }

  Future<LiveRoom> _detail(String roomId, String platform, {required bool includeMedia}) async {
    final data = await _api.room(_userId(roomId, platform), resolveMedia: includeMedia);
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
    if (room.effectiveLiveStatus == LiveStatus.unknown) {
      throw const PandaLiveException(PandaLiveFailure.unknownState);
    }
    return room.isLiveNow;
  }

  PandaLiveRoom _snapshot(LiveRoom detail) {
    final userId = _userId(detail.roomId ?? '', detail.platform ?? '');
    final data = detail.data;
    if (data is! PandaLiveRoom || data.userId.toLowerCase() != userId.toLowerCase()) {
      throw const PandaLiveException(PandaLiveFailure.identity);
    }
    if (data.state != PandaLiveState.live || data.access != PandaLiveAccess.public || data.streams.isEmpty) {
      throw const PandaLiveException(PandaLiveFailure.mediaUnavailable);
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
    if (refresh) room = _snapshot(await getRoomDetail(roomId: room.userId, platform: id));
    final selectionId = quality.selectionId.toString();
    for (final stream in room.streams) {
      if (stream.id == selectionId) {
        return LivePlayUrlResolution(urls: [stream.uri.toString()], appliedQualityData: selectionId);
      }
    }
    throw const PandaLiveException(PandaLiveFailure.mediaUnavailable);
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
