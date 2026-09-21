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

import 'langlive_api.dart';
import 'langlive_link.dart';

/// Internal readiness adapter. It is intentionally kept out of the site registry until
/// a current production response and one returned media prefix are verified.
final class LangLiveSite extends LiveSite
    implements
        LiveSiteDirectoryPager,
        LiveDirectoryNotice,
        LiveCancellableSearch,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayUrlResolver,
        LivePlayRecoveryResolver {
  LangLiveSite({LangLiveApi? api}) : _api = api ?? LangLiveApi();

  final LangLiveApi _api;

  @override
  String get id => 'langlive';

  @override
  String get name => '浪 Live';

  @override
  String get directoryNoticeKey => 'langlive_directory_scope';

  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    if (cancel?.isCancelled == true) throw const LangLiveException(LangLiveFailure.cancelled);
    if (page < 1 || category != null) throw const LangLiveException(LangLiveFailure.schema);
    return LiveDirectoryPage(rooms: const [], page: page, hasMore: false);
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    if (page < 1 || pageSize < 1) return [];
    return (await getDirectoryPage(page: page)).rooms;
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
    final roomId = LangLiveLink.parseOrId(keyword);
    if (roomId == null) return [];
    try {
      return [_card(await _api.room(roomId, cancel: cancel), includeMedia: false)];
    } on LangLiveException catch (error) {
      if (error.kind == LangLiveFailure.missing) return [];
      rethrow;
    }
  }

  static LiveStatus _status(LangLiveRoom room) => switch (room.state) {
    LangLiveState.live => LiveStatus.live,
    LangLiveState.offline => LiveStatus.offline,
    LangLiveState.unknown => LiveStatus.unknown,
  };

  LiveRoom _card(LangLiveRoom room, {required bool includeMedia}) => LiveRoom(
    platform: id,
    roomId: room.roomId,
    userId: room.roomId,
    title: room.nickname,
    nick: room.nickname,
    area: name,
    link: LangLiveLink.url(room.roomId),
    liveStatus: _status(room),
    notice: i18n('langlive_chat_notice'),
    httpHeaders: LangLiveApi.mediaHeaders(room.roomId),
    data: includeMedia && room.state == LangLiveState.live ? room : null,
  );

  String _roomId(String roomId, String platform) {
    if (platform.trim().toLowerCase() != id) throw const LangLiveException(LangLiveFailure.identity);
    final normalized = LangLiveLink.normalizeRoomId(roomId);
    if (normalized == null) throw const LangLiveException(LangLiveFailure.identity);
    return normalized;
  }

  Future<LiveRoom> _detail(String roomId, String platform, {required bool includeMedia}) async {
    final data = await _api.room(_roomId(roomId, platform));
    if (includeMedia && data.state == LangLiveState.live && data.media.isEmpty) {
      throw const LangLiveException(LangLiveFailure.mediaUnavailable);
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
      throw const LangLiveException(LangLiveFailure.unknownState);
    }
    return room.isLiveNow;
  }

  LangLiveRoom _snapshot(LiveRoom detail) {
    final roomId = _roomId(detail.roomId ?? '', detail.platform ?? '');
    final data = detail.data;
    if (data is! LangLiveRoom || data.roomId != roomId || data.state != LangLiveState.live || data.media.isEmpty) {
      throw const LangLiveException(LangLiveFailure.mediaUnavailable);
    }
    return data;
  }

  static String _qualityName(LangLiveMediaKind kind) => switch (kind) {
    LangLiveMediaKind.flv => i18n('langlive_quality_flv'),
    LangLiveMediaKind.hls => i18n('langlive_quality_hls'),
  };

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    if (detail.isExplicitlyOfflineNow) return [];
    final room = _snapshot(detail);
    return List.unmodifiable(
      room.media.map(
        (media) => LivePlayQuality(
          id: media.kind.name,
          quality: _qualityName(media.kind),
          sort: media.kind == LangLiveMediaKind.flv ? 200 : 100,
        ),
      ),
    );
  }

  Future<LivePlayUrlResolution> _resolve(LiveRoom detail, LivePlayQuality quality, {required bool refresh}) async {
    var room = _snapshot(detail);
    if (refresh) room = _snapshot(await getRoomDetail(roomId: room.roomId, platform: id));
    final selectionId = quality.selectionId.toString();
    for (final media in room.media) {
      if (media.kind.name == selectionId) {
        return LivePlayUrlResolution(urls: [media.uri.toString()], appliedQualityData: selectionId);
      }
    }
    throw const LangLiveException(LangLiveFailure.mediaUnavailable);
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
