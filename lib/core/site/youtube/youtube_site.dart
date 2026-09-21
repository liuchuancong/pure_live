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

import 'youtube_api.dart';
import 'youtube_link.dart';

class YouTubeSite extends LiveSite
    implements
        LiveSiteDirectoryPager,
        LiveDirectoryNotice,
        LiveCancellableSearch,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayUrlResolver,
        LivePlayRecoveryResolver,
        LivePlayLeaseMetadata {
  YouTubeSite({YouTubeApi? api}) : _api = api ?? YouTubeApi();

  final YouTubeApi _api;

  @override
  String get id => 'youtube';

  @override
  String get name => 'YouTube Live';

  @override
  String get directoryNoticeKey => 'youtube_directory_scope';

  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    if (page < 1 || category != null) throw const YouTubeException(YouTubeFailure.schema);
    return LiveDirectoryPage(rooms: const [], page: page, hasMore: false);
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    if (page < 1 || pageSize < 1) return [];
    return const [];
  }

  LiveRoom _card(YouTubeRoom room, {required bool includeMedia}) {
    final current = room.currentViewers?.toString();
    return LiveRoom(
      platform: id,
      roomId: room.videoId,
      userId: room.channelId,
      nick: room.author,
      title: room.title,
      avatar: room.thumbnail,
      cover: room.thumbnail,
      area: room.category.isEmpty ? 'YouTube Live' : room.category,
      introduction: room.description,
      link: YouTubeLink.videoUrl(room.videoId),
      liveStatus: switch (room.state) {
        YouTubeState.live => LiveStatus.live,
        YouTubeState.offline => LiveStatus.offline,
        YouTubeState.restricted => LiveStatus.banned,
        YouTubeState.unknown => LiveStatus.unknown,
      },
      watching: current ?? '',
      onlineViewers: current,
      audienceMetricType: AudienceMetricType.onlineViewers,
      notice: i18n('youtube_chat_notice'),
      httpHeaders: YouTubeApi.mediaHeaders(room.videoId),
      data: includeMedia ? room : null,
    );
  }

  String _videoId(String roomId, String platform) {
    if (platform.trim().toLowerCase() != id) throw const YouTubeException(YouTubeFailure.identity);
    final normalized = YouTubeLink.normalizeVideoId(roomId);
    if (normalized == null) throw const YouTubeException(YouTubeFailure.identity);
    return normalized;
  }

  Future<LiveRoom> _detail(String roomId, String platform, {required bool includeMedia}) async {
    final data = await _api.room(_videoId(roomId, platform), includeMedia: includeMedia);
    if (includeMedia && data.state == YouTubeState.live && data.streams.isEmpty) {
      throw const YouTubeException(YouTubeFailure.mediaUnavailable);
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
      throw const YouTubeException(YouTubeFailure.unknownState);
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
    final reference = YouTubeLink.parseOrReference(keyword);
    if (reference == null) return [];
    try {
      final videoId = await _api.resolveReference(reference, cancel: cancel);
      return [_card(await _api.room(videoId, includeMedia: false, cancel: cancel), includeMedia: false)];
    } on YouTubeException catch (error) {
      if (error.kind == YouTubeFailure.missing || error.kind == YouTubeFailure.notLive) return [];
      rethrow;
    }
  }

  YouTubeRoom _snapshot(LiveRoom detail) {
    final roomId = _videoId(detail.roomId ?? '', detail.platform ?? '');
    final data = detail.data;
    if (data is! YouTubeRoom || data.videoId != roomId || data.channelId != detail.userId) {
      throw const YouTubeException(YouTubeFailure.identity);
    }
    if (data.state == YouTubeState.unknown) throw const YouTubeException(YouTubeFailure.unknownState);
    if (data.state != YouTubeState.live || detail.isExplicitlyOfflineNow || data.streams.isEmpty) {
      throw const YouTubeException(YouTubeFailure.mediaUnavailable);
    }
    return data;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    if (detail.isExplicitlyOfflineNow) return [];
    final room = _snapshot(detail);
    return List.unmodifiable(
      room.streams.map((stream) {
        final codec = stream.codec.isEmpty ? '' : ' · ${stream.codec.toUpperCase()}';
        final label = switch (stream.id) {
          'hls:auto' => i18n('youtube_quality_hls_auto'),
          'dash:auto' => i18n('youtube_quality_dash_auto'),
          _ => stream.label,
        };
        return LivePlayQuality(
          id: stream.id,
          quality: '$label$codec · ${stream.protocol.toUpperCase()}',
          sort: YouTubeApi.qualitySort(stream),
        );
      }),
    );
  }

  Future<LivePlayUrlResolution> _resolve(LiveRoom detail, LivePlayQuality quality, {required bool refresh}) async {
    var room = _snapshot(detail);
    if (refresh) room = _snapshot(await getRoomDetail(roomId: room.videoId, platform: id));
    final qualityId = quality.selectionId.toString();
    for (final stream in room.streams) {
      if (stream.id == qualityId) {
        return LivePlayUrlResolution(
          urls: List.unmodifiable(stream.urls.map((uri) => uri.toString())),
          appliedQualityData: qualityId,
        );
      }
    }
    throw const YouTubeException(YouTubeFailure.mediaUnavailable);
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

  @override
  DateTime? getPlayUrlInvalidAt(String url, {DateTime? now}) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final query = int.tryParse(uri.queryParameters['expire'] ?? '');
    if (query != null && query > 0) return DateTime.fromMillisecondsSinceEpoch(query * 1000, isUtc: true);
    final segments = uri.pathSegments;
    final index = segments.indexOf('expire');
    if (index >= 0 && index + 1 < segments.length) {
      final path = int.tryParse(segments[index + 1]);
      if (path != null && path > 0) return DateTime.fromMillisecondsSinceEpoch(path * 1000, isUtc: true);
    }
    return null;
  }

  @override
  DateTime? getPlayUrlRefreshAt(String url, {DateTime? now}) {
    final invalid = getPlayUrlInvalidAt(url, now: now);
    return invalid?.subtract(const Duration(minutes: 10));
  }
}
