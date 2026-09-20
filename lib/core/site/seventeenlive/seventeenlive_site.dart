import 'package:dio/dio.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/danmaku/empty_danmaku.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/interface/live_directory.dart';
import 'package:pure_live/core/interface/live_search.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/plugins/locale_helper.dart';

import 'seventeenlive_api.dart';
import 'seventeenlive_link.dart';

class SeventeenLiveSite extends LiveSite
    implements
        LiveSiteDirectoryPager,
        LiveDirectoryNotice,
        LiveCancellableSearch,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayUrlResolver,
        LivePlayRecoveryResolver {
  SeventeenLiveSite({SeventeenLiveApi? api}) : _api = api ?? SeventeenLiveApi();

  final SeventeenLiveApi _api;

  @override
  String get id => '17live';

  @override
  String get name => '17LIVE';

  @override
  String get directoryNoticeKey => 'seventeen_directory_scope';

  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    if (cancel?.isCancelled == true) throw const SeventeenLiveException(SeventeenLiveFailure.cancelled);
    if (page < 1 || category != null) throw const SeventeenLiveException(SeventeenLiveFailure.schema);
    return LiveDirectoryPage(page: page, hasMore: false, rooms: const []);
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    if (pageSize < 1) throw const SeventeenLiveException(SeventeenLiveFailure.schema);
    return (await getDirectoryPage(page: page)).rooms;
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
    watching: '',
    onlineViewers: room.liveViewers?.toString(),
    totalViewers: room.sessionViewers?.toString(),
    audienceMetricType: AudienceMetricType.onlineViewers,
    notice: i18n('seventeen_age_notice'),
    httpHeaders: SeventeenLiveApi.mediaHeaders(room.roomId),
    data: includeMedia ? room : null,
  );

  String _roomId(String roomId, String platform) {
    if (platform.trim().toLowerCase() != id) throw const SeventeenLiveException(SeventeenLiveFailure.identity);
    final normalized = SeventeenLiveLink.normalizeRoomId(roomId);
    if (normalized == null) throw const SeventeenLiveException(SeventeenLiveFailure.identity);
    return normalized;
  }

  Future<LiveRoom> _detail(String roomId, String platform, {required bool includeMedia}) async {
    final data = await _api.room(_roomId(roomId, platform));
    if (includeMedia && data.state == SeventeenLiveState.live && data.streams.isEmpty) {
      throw const SeventeenLiveException(SeventeenLiveFailure.mediaUnavailable);
    }
    return _card(data, includeMedia: includeMedia);
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
      throw const SeventeenLiveException(SeventeenLiveFailure.unknownState);
    }
    return room.isLiveNow;
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
    if (roomId == null) return [];
    try {
      return [_card(await _api.room(roomId, cancel: cancel), includeMedia: false)];
    } on SeventeenLiveException catch (error) {
      if (error.kind == SeventeenLiveFailure.missing) return [];
      rethrow;
    }
  }

  SeventeenLiveRoom _snapshot(LiveRoom detail) {
    final roomId = _roomId(detail.roomId ?? '', detail.platform ?? '');
    final data = detail.data;
    if (data is! SeventeenLiveRoom || data.roomId != roomId || data.userId != detail.userId) {
      throw const SeventeenLiveException(SeventeenLiveFailure.identity);
    }
    if (data.state == SeventeenLiveState.unknown) {
      throw const SeventeenLiveException(SeventeenLiveFailure.unknownState);
    }
    if (data.state != SeventeenLiveState.live || detail.isExplicitlyOfflineNow) {
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
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    if (detail.isExplicitlyOfflineNow) return [];
    final room = _snapshot(detail);
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

  Future<LivePlayUrlResolution> _resolve(LiveRoom detail, LivePlayQuality quality, {required bool refresh}) async {
    var room = _snapshot(detail);
    if (refresh) room = _snapshot(await getRoomDetail(roomId: room.roomId, platform: id));
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
