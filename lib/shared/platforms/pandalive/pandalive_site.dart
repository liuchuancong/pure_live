import 'pandalive_api.dart';
import 'pandalive_danmaku.dart';
import 'pandalive_link.dart';

import 'package:dio/dio.dart';
import 'package:pure_live/core/utils/i18n.dart';
import 'package:pure_live/core/models/live_area.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/core/models/live_category.dart';
import 'package:pure_live/shared/platforms/live_site.dart';
import 'package:pure_live/shared/platforms/live_search.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/shared/platforms/live_directory.dart';
import 'package:pure_live/shared/platforms/live_external_room.dart';

class PandaLiveSite extends LiveSite
    implements
        LiveSiteDirectoryPager,
        LiveDirectoryNotice,
        LiveCancellableSearch,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayUrlResolver,
        LivePlayRecoveryResolver,
        LivePlayLeaseMetadata,
        LiveSiteExternalRoomResolver {
  @override
  RoomExternalTarget? externalRoomTarget(LiveRoom liveroom) {
    final id = sanitizedExternalRoomId(liveroom.roomId);
    if (id == null) return null;
    try {
      return RoomExternalTarget(web: PandaLiveLink.url(id));
    } on FormatException {
      return null;
    }
  }

  PandaLiveSite({PandaLiveApi? api}) : _api = api ?? PandaLiveApi();

  final PandaLiveApi _api;

  @override
  String get id => 'pandalive';

  @override
  String get name => 'PandaTV';

  @override
  String get directoryNoticeKey => 'pandalive_directory_scope';

  @override
  LiveDanmaku getDanmaku() => PandaLiveDanmaku();

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
    liveStatus: room.isRerun ? LiveStatus.replay : LiveStatus.live,
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
      PandaLiveState.live => room.isRerun ? LiveStatus.replay : LiveStatus.live,
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
    danmakuData: room.chatToken.isEmpty
        ? null
        : PandaLiveDanmakuArgs(
            userId: room.userId,
            channel: room.chatChannel.isEmpty ? room.userId : room.chatChannel,
            token: room.chatToken,
          ),
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

  String _userId(LiveRoom liveroom) {
    final roomId = liveroom.roomId ?? '';
    final platform = liveroom.platform ?? '';
    if (platform.trim().toLowerCase() != id) throw const PandaLiveException(PandaLiveFailure.identity);
    final userId = PandaLiveLink.normalizeUserId(roomId);
    if (userId == null) throw const PandaLiveException(PandaLiveFailure.identity);
    return userId;
  }

  Future<LiveRoom> _detail(LiveRoom liveroom, {required bool includeMedia}) async {
    final data = await _api.room(_userId(liveroom), resolveMedia: includeMedia);
    return _room(data, includeMedia: includeMedia);
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return _detail(liveroom, includeMedia: true);
  }

  @override
  Future<LiveRoom> getRoomDetailForRecording(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return _detail(liveroom, includeMedia: true);
  }

  @override
  Future<LiveRoom> getRoomDetailForRefresh(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return _detail(liveroom, includeMedia: false);
  }

  PandaLiveRoom _snapshot(LiveRoom liveroom) {
    final userId = _userId(liveroom);
    final data = liveroom.data;
    if (data is! PandaLiveRoom || data.userId.toLowerCase() != userId.toLowerCase()) {
      throw const PandaLiveException(PandaLiveFailure.identity);
    }
    if (data.state != PandaLiveState.live || data.access != PandaLiveAccess.public || data.streams.isEmpty) {
      throw const PandaLiveException(PandaLiveFailure.mediaUnavailable);
    }
    return data;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom liveroom}) async {
    if (liveroom.isExplicitlyOfflineNow) return [];
    final room = _snapshot(liveroom);
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

  Future<LivePlayUrlResolution> _resolve(LiveRoom liveroom, LivePlayQuality quality, {required bool refresh}) async {
    var room = _snapshot(liveroom);
    if (refresh) {
      room = _snapshot(await getRoomDetail(LiveRoom(roomId: room.userId, platform: id)));
    }
    final selectionId = quality.selectionId.toString();
    for (final stream in room.streams) {
      if (stream.id == selectionId) {
        final url = stream.uri.toString();
        _rememberIssued(url, DateTime.now());
        return LivePlayUrlResolution(urls: [url], appliedQualityData: selectionId);
      }
    }
    throw const PandaLiveException(PandaLiveFailure.mediaUnavailable);
  }

  static const Duration _variantRefreshLead = Duration(minutes: 30);

  static final Map<String, DateTime> _issuedAt = {};

  static void _rememberIssued(String url, DateTime at) {
    _issuedAt.remove(url);
    _issuedAt[url] = at;
    while (_issuedAt.length > 32) {
      _issuedAt.remove(_issuedAt.keys.first);
    }
  }

  @override
  DateTime? getPlayUrlRefreshAt(String url, {DateTime? now}) {
    final issued = _issuedAt[url];
    return issued?.toUtc().add(_variantRefreshLead);
  }

  @override
  DateTime? getPlayUrlInvalidAt(String url, {DateTime? now}) => null;

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsRaw({required LiveRoom liveroom, required LivePlayQuality quality}) =>
      _resolve(liveroom, quality, refresh: false);

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsForRecoveryRaw({
    required LiveRoom liveroom,
    required LivePlayQuality quality,
  }) => _resolve(liveroom, quality, refresh: true);

  @override
  Future<List<String>> getPlayUrls({required LiveRoom liveroom, required LivePlayQuality quality}) async =>
      (await _resolve(liveroom, quality, refresh: false)).urls;
}
