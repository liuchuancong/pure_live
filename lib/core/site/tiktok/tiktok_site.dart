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

import 'tiktok_api.dart';
import 'tiktok_link.dart';

class TikTokSite extends LiveSite
    implements
        LiveSiteDirectoryPager,
        LiveDirectoryNotice,
        LiveCancellableSearch,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayUrlResolver,
        LivePlayRecoveryResolver {
  TikTokSite({TikTokApi? api}) : _api = api ?? TikTokApi();

  final TikTokApi _api;

  @override
  String get id => 'tiktok';

  @override
  String get name => 'TikTok LIVE';

  @override
  String get directoryNoticeKey => 'tiktok_directory_scope';

  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    if (page < 1 || category != null) throw const TikTokException(TikTokFailure.schema);
    return LiveDirectoryPage(rooms: const [], page: page, hasMore: false);
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    if (page < 1 || pageSize < 1) return [];
    return const [];
  }

  LiveRoom _card(TikTokRoom room, {required bool includeMedia}) {
    final current = room.currentViewers?.toString();
    return LiveRoom(
      platform: id,
      roomId: room.username,
      userId: room.userId,
      nick: room.nickname,
      title: room.title,
      avatar: room.avatar,
      cover: room.cover,
      area: 'TikTok LIVE',
      followers: room.followers?.toString(),
      introduction: room.bio,
      link: TikTokLink.url(room.username),
      liveStatus: switch (room.state) {
        TikTokState.live => LiveStatus.live,
        TikTokState.offline => LiveStatus.offline,
        TikTokState.restricted => LiveStatus.banned,
        TikTokState.unknown => LiveStatus.unknown,
      },
      watching: current ?? '',
      onlineViewers: current,
      totalViewers: room.totalViewers?.toString(),
      audienceMetricType: AudienceMetricType.onlineViewers,
      notice: i18n('tiktok_chat_notice'),
      httpHeaders: TikTokApi.mediaHeaders(room.username),
      data: includeMedia ? room : null,
    );
  }

  String _roomId(String roomId, String platform) {
    if (platform.trim().toLowerCase() != id) throw const TikTokException(TikTokFailure.identity);
    final normalized = TikTokLink.normalizeUsername(roomId);
    if (normalized == null) throw const TikTokException(TikTokFailure.identity);
    return normalized;
  }

  Future<LiveRoom> _detail(String roomId, String platform, {required bool includeMedia}) async {
    final data = await _api.room(_roomId(roomId, platform), includeMedia: includeMedia);
    if (includeMedia && data.state == TikTokState.live && data.streams.isEmpty) {
      throw const TikTokException(TikTokFailure.mediaUnavailable);
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
      throw const TikTokException(TikTokFailure.unknownState);
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
    final reference = TikTokLink.parseOrUsername(keyword);
    if (reference == null) return [];
    try {
      final username = await _api.resolveReference(reference, cancel: cancel);
      return [_card(await _api.room(username, includeMedia: false, cancel: cancel), includeMedia: false)];
    } on TikTokException catch (error) {
      if (error.kind == TikTokFailure.missing) return [];
      rethrow;
    }
  }

  TikTokRoom _snapshot(LiveRoom detail) {
    final roomId = _roomId(detail.roomId ?? '', detail.platform ?? '');
    final data = detail.data;
    if (data is! TikTokRoom || data.username != roomId || data.userId != detail.userId) {
      throw const TikTokException(TikTokFailure.identity);
    }
    if (data.state == TikTokState.unknown) throw const TikTokException(TikTokFailure.unknownState);
    if (data.state != TikTokState.live || detail.isExplicitlyOfflineNow || data.streams.isEmpty) {
      throw const TikTokException(TikTokFailure.mediaUnavailable);
    }
    return data;
  }

  static String _qualityName(TikTokStream stream) => switch (stream.qualityId) {
    'origin' => i18n('tiktok_quality_origin'),
    'uhd_60' => i18n('tiktok_quality_uhd60'),
    'hd_60' => i18n('tiktok_quality_hd60'),
    'uhd' => i18n('tiktok_quality_uhd'),
    'hd' => i18n('tiktok_quality_hd'),
    'sd' => i18n('tiktok_quality_sd'),
    'ld' => i18n('tiktok_quality_ld'),
    'auto' => i18n('tiktok_quality_auto'),
    _ => stream.qualityId.toUpperCase(),
  };

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    if (detail.isExplicitlyOfflineNow) return [];
    final room = _snapshot(detail);
    return List.unmodifiable(
      room.streams.map((stream) {
        final resolution = stream.resolution.isEmpty ? '' : ' · ${stream.resolution}';
        return LivePlayQuality(
          id: stream.id,
          quality:
              '${_qualityName(stream)}$resolution · ${stream.codec.toUpperCase()} · ${stream.protocol.toUpperCase()}',
          sort: TikTokApi.qualitySort(stream),
        );
      }),
    );
  }

  Future<LivePlayUrlResolution> _resolve(LiveRoom detail, LivePlayQuality quality, {required bool refresh}) async {
    var room = _snapshot(detail);
    if (refresh) room = _snapshot(await getRoomDetail(roomId: room.username, platform: id));
    final qualityId = quality.selectionId.toString();
    for (final stream in room.streams) {
      if (stream.id == qualityId) {
        return LivePlayUrlResolution(
          urls: List.unmodifiable(stream.urls.map((uri) => uri.toString())),
          appliedQualityData: qualityId,
        );
      }
    }
    throw const TikTokException(TikTokFailure.mediaUnavailable);
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
