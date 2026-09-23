import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/danmaku/empty_danmaku.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/interface/live_directory.dart';
import 'package:pure_live/core/interface/live_search.dart';
import 'package:dio/dio.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/model/live_play_quality.dart';

import 'missevan_api.dart';

/// Anonymous directory, official keyword/exact search, playback and recording.
/// Remote danmaku remains absent until its contract is verified.
class MissevanSite extends LiveSite
    implements
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayRecoveryResolver,
        LivePlayLeaseMetadata,
        LiveSiteDirectoryPager,
        LiveCancellableSearch {
  MissevanSite({MissevanApi? api}) : _api = api ?? MissevanApi();
  final MissevanApi _api;
  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    final result = await _api.directoryPage(page: page, category: category, cancel: cancel);
    return LiveDirectoryPage(rooms: result.rooms, page: result.page, hasMore: result.hasMore);
  }

  @override
  String get id => 'missevan';
  @override
  String get name => '猫耳 FM';
  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();
  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async =>
      page == 1 ? [LiveCategory(id: id, name: name, children: await _api.categories())] : [];
  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) =>
      _api.directory(page: page, pageSize: pageSize);
  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) =>
      _api.directory(page: page, pageSize: pageSize, category: category);

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
    if (pageSize < 1) return const [];
    final input = keyword.trim();
    if (input.isEmpty) return const [];
    String? id;
    try {
      id = MissevanApi.roomId(input);
    } on MissevanException {
      final uri = Uri.tryParse(input);
      if (uri != null) id = MissevanApi.roomFromUri(uri);
    }
    if (id != null) {
      if (page != 1) return const [];
      try {
        return [await _api.detail(id, includeMedia: false, cancel: cancel)];
      } on MissevanException catch (error) {
        if (error.kind == MissevanFailure.notFound) return const [];
        rethrow;
      }
    }
    // A foreign/malformed share URL is not a nickname search request.
    if (Uri.tryParse(input)?.hasScheme == true) return const [];
    return _api.searchPage(input, page: page, pageSize: pageSize, cancel: cancel);
  }

  @override
  Future<LiveRoom> getRoomDetail({required String roomId, required String platform}) {
    if (platform != id) throw const MissevanException(MissevanFailure.schema);
    return _api.detail(roomId);
  }

  @override
  Future<LiveRoom> getRoomDetailForRefresh({required String roomId, required String platform}) =>
      getRoomDetail(roomId: roomId, platform: platform);
  @override
  Future<LiveRoom> getRoomDetailForRecording({required String roomId, required String platform}) =>
      getRoomDetail(roomId: roomId, platform: platform);
  @override
  Future<bool> getLiveStatus({required String platform, required String roomId}) async =>
      (await getRoomDetail(roomId: roomId, platform: platform)).isLiveNow;
  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    if (detail.platform != id) throw const MissevanException(MissevanFailure.schema);
    if (detail.isExplicitlyOfflineNow) return [];
    if (!detail.isLiveNow || detail.data is! List<LivePlayQuality> || (detail.data as List).isEmpty) {
      throw const MissevanException(MissevanFailure.schema);
    }
    return List.unmodifiable(detail.data as List<LivePlayQuality>);
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    for (final current in await getPlayQualites(detail: detail)) {
      if (current.selectionId == quality.selectionId) return List.unmodifiable(current.data as List<String>);
    }
    throw const MissevanException(MissevanFailure.qualityUnavailable);
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

  @override
  DateTime? getPlayUrlInvalidAt(String url, {DateTime? now}) {
    try {
      final uri = Uri.parse(url);
      final kind = uri.path.endsWith('.m3u8') ? 'hls' : 'flv';
      final normalized = Uri.parse(MissevanApi.mediaUrl(url, kind: kind));
      final expires = int.tryParse(normalized.queryParameters['expires'] ?? '');
      return expires == null ? null : DateTime.fromMillisecondsSinceEpoch(expires * 1000, isUtc: true);
    } on FormatException {
      return null;
    } on MissevanException {
      return null;
    }
  }

  @override
  DateTime? getPlayUrlRefreshAt(String url, {DateTime? now}) =>
      getPlayUrlInvalidAt(url, now: now)?.subtract(const Duration(minutes: 1));
}
