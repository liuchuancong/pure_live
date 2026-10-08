import 'package:dio/dio.dart';
import 'package:pure_live/core/models/live_area.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/shared/platforms/live_directory.dart';
import 'package:pure_live/shared/platforms/live_search.dart';
import 'package:pure_live/shared/platforms/live_site.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/core/utils/i18n.dart';
import 'package:pure_live/shared/platforms/live_external_room.dart';

import 'seventeenlive_api.dart';
import 'seventeenlive_danmaku.dart';
import 'seventeenlive_link.dart';

class SeventeenLiveSite extends LiveSite
    implements
        LiveSiteCursorDirectoryPager,
        LiveDirectoryNotice,
        LiveCancellableSearch,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayUrlResolver,
        LivePlayRecoveryResolver,
        LiveSiteExternalRoomResolver {
  @override
  RoomExternalTarget? externalRoomTarget(LiveRoom liveroom) {
    final id = sanitizedExternalRoomId(liveroom.roomId);
    if (id == null) return null;
    try {
      return RoomExternalTarget(web: SeventeenLiveLink.url(id));
    } on FormatException {
      return null;
    }
  }

  SeventeenLiveSite({SeventeenLiveApi? api}) : _api = api ?? SeventeenLiveApi();

  final SeventeenLiveApi _api;

  @override
  String get id => '17live';

  @override
  String get name => '17LIVE';

  @override
  String get directoryNoticeKey => 'seventeen_directory_scope';

  @override
  LiveDanmaku getDanmaku() => SeventeenLiveDanmaku();

  @override
  Future<LiveDirectoryPage> getDirectoryPageAtCursor({
    required int page,
    String? cursor,
    LiveArea? category,
    CancelToken? cancel,
  }) async {
    if (page < 1 || (page == 1 && cursor != null) || (page > 1 && cursor == null) || category != null) {
      throw const SeventeenLiveException(SeventeenLiveFailure.schema);
    }
    final result = await _api.directory(cursor: cursor, cancel: cancel);
    return LiveDirectoryPage(
      page: page,
      rooms: result.rooms.map((room) => _card(room, includeMedia: false)),
      hasMore: result.hasMore,
      nextCursor: result.nextCursor,
    );
  }

  /// Compatibility callers replay a short prefix; catalogue controllers use
  /// the cursor contract directly and own their refresh generation.
  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    if (page < 1 || page > 20) throw const SeventeenLiveException(SeventeenLiveFailure.schema);
    String? cursor;
    for (var current = 1; current <= page; current++) {
      final result = await getDirectoryPageAtCursor(page: current, cursor: cursor, category: category, cancel: cancel);
      if (current == page) return result;
      if (!result.hasMore) return LiveDirectoryPage(page: page, hasMore: false, rooms: const []);
      cursor = result.nextCursor;
    }
    throw const SeventeenLiveException(SeventeenLiveFailure.schema);
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    if (pageSize < 1) throw const SeventeenLiveException(SeventeenLiveFailure.schema);
    return (await getDirectoryPage(page: page)).rooms.take(pageSize).toList(growable: false);
  }

  LiveRoom _card(SeventeenLiveRoom room, {required bool includeMedia}) => LiveRoom(
    platform: id,
    roomId: room.roomId,
    userId: room.userId,
    nick: room.nickname,
    title: room.title,
    avatar: room.avatar,
    cover: room.cover,
    area: room.audioOnly ? i18n('seventeen_audio_room') : '',
    followers: room.followers?.toString(),
    introduction: room.bio,
    link: SeventeenLiveLink.url(room.roomId),
    liveStatus: switch (room.state) {
      SeventeenLiveState.live => LiveStatus.live,
      SeventeenLiveState.offline => LiveStatus.offline,
      SeventeenLiveState.unknown => LiveStatus.unknown,
    },
    restriction: room.state == SeventeenLiveState.live ? room.restriction : null,
    startedAt: room.startedAt,
    watching: '',
    onlineViewers: room.liveViewers?.toString(),
    totalViewers: room.sessionViewers?.toString(),
    audienceMetricType: AudienceMetricType.onlineViewers,
    notice: i18n('seventeen_age_notice'),
    httpHeaders: SeventeenLiveApi.mediaHeaders(room.roomId),
    danmakuData: room.state == SeventeenLiveState.live
        ? SeventeenLiveDanmakuArgs(roomId: room.roomId)
        : null,
    data: includeMedia ? room : null,
  );

  String _roomId(LiveRoom liveroom) {
    final roomId = liveroom.roomId ?? '';
    final platform = liveroom.platform ?? '';
    if (platform.trim().toLowerCase() != id) throw const SeventeenLiveException(SeventeenLiveFailure.identity);
    final normalized = SeventeenLiveLink.normalizeRoomId(roomId);
    if (normalized == null) throw const SeventeenLiveException(SeventeenLiveFailure.identity);
    return normalized;
  }

  Future<LiveRoom> _detail(LiveRoom liveroom, {required bool includeMedia}) async {
    final data = await _api.room(_roomId(liveroom));
    if (includeMedia && data.state == SeventeenLiveState.live && data.streams.isEmpty) {
      throw const SeventeenLiveException(SeventeenLiveFailure.mediaUnavailable);
    }
    return _card(data, includeMedia: includeMedia);
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
    final roomId = SeventeenLiveLink.parseOrId(keyword);
    if (roomId != null) {
      try {
        return [_card(await _api.room(roomId, cancel: cancel), includeMedia: false)];
      } on SeventeenLiveException catch (error) {
        if (error.kind == SeventeenLiveFailure.missing) return [];
        rethrow;
      }
    }
    final query = _searchKeyword(keyword);
    if (query.isEmpty || _isUrl(query)) return [];
    final rooms = await _api.searchCurrentLive(query, cancel: cancel);
    return rooms.take(pageSize).map((room) => _card(room, includeMedia: false)).toList(growable: false);
  }

  static final RegExp _urlPattern = RegExp('^[a-z][a-z0-9+.-]*://', caseSensitive: false);

  static bool _isUrl(String text) => _urlPattern.hasMatch(text.trim());

  static String _searchKeyword(String keyword) {
    var text = keyword.trim();
    if (text.length > 100) {
      var end = 100;
      final last = text.codeUnitAt(end - 1);
      if (last >= 0xD800 && last <= 0xDBFF) end--;
      text = text.substring(0, end).trim();
    }
    return text;
  }

  SeventeenLiveRoom _snapshot(LiveRoom liveroom) {
    final roomId = _roomId(liveroom);
    final data = liveroom.data;
    if (data is! SeventeenLiveRoom || data.roomId != roomId || data.userId != liveroom.userId) {
      throw const SeventeenLiveException(SeventeenLiveFailure.identity);
    }
    if (data.state == SeventeenLiveState.unknown) {
      throw const SeventeenLiveException(SeventeenLiveFailure.unknownState);
    }
    if (data.state != SeventeenLiveState.live || liveroom.isExplicitlyOfflineNow) {
      throw const SeventeenLiveException(SeventeenLiveFailure.mediaUnavailable);
    }
    if (data.streams.isEmpty) throw const SeventeenLiveException(SeventeenLiveFailure.mediaUnavailable);
    return data;
  }

  static String _qualityName(String qualityId) => switch (qualityId) {
    'enhanced' => i18n('seventeen_quality_enhanced'),
    'hd' => i18n('seventeen_quality_hd'),
    'h264' => i18n('seventeen_quality_h264'),
    'standard' => i18n('seventeen_quality_standard'),
    _ => throw const SeventeenLiveException(SeventeenLiveFailure.schema),
  };

  static int _qualitySort(String qualityId) => switch (qualityId) {
    'enhanced' => 400,
    'hd' => 300,
    'h264' => 200,
    'standard' => 100,
    _ => 0,
  };

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom liveroom}) async {
    if (liveroom.isExplicitlyOfflineNow) return [];
    final room = _snapshot(liveroom);
    return List.unmodifiable(
      room.streams.map(
        (stream) => LivePlayQuality(
          id: stream.qualityId,
          quality: '${_qualityName(stream.qualityId)} · FLV',
          sort: _qualitySort(stream.qualityId),
        ),
      ),
    );
  }

  Future<LivePlayUrlResolution> _resolve(LiveRoom liveroom, LivePlayQuality quality, {required bool refresh}) async {
    var room = _snapshot(liveroom);
    if (refresh) {
      room = _snapshot(await getRoomDetail(LiveRoom(roomId: room.roomId, platform: id)));
    }
    final qualityId = quality.selectionId.toString();
    for (final stream in room.streams) {
      if (stream.qualityId == qualityId) {
        return LivePlayUrlResolution(
          urls: List.unmodifiable(stream.urls.map((uri) => uri.toString())),
          appliedQualityData: qualityId,
        );
      }
    }
    throw const SeventeenLiveException(SeventeenLiveFailure.mediaUnavailable);
  }

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
