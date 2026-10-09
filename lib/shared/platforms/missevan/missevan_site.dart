import 'package:pure_live/core/models/live_area.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/shared/platforms/live_site.dart';
import 'package:pure_live/shared/platforms/live_directory.dart';
import 'package:pure_live/shared/platforms/live_search.dart';
import 'package:dio/dio.dart';
import 'package:pure_live/core/models/live_category.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/shared/platforms/live_external_room.dart';

import 'missevan_api.dart';
import 'missevan_danmaku.dart';

/// Anonymous directory, official keyword/exact search, playback and recording.
/// Remote danmaku remains absent until its contract is verified.
class MissevanSite extends LiveSite
    implements
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayRecoveryResolver,
        LivePlayLeaseMetadata,
        LiveSiteDirectoryPager,
        LiveCancellableSearch,
        LiveSearchPaginationPolicy,
        LiveSiteExternalRoomResolver {
  @override
  RoomExternalTarget? externalRoomTarget(LiveRoom liveroom) {
    final id = sanitizedExternalRoomId(liveroom.roomId);
    if (id == null) return null;
    final path = Uri.encodeComponent(id);
    return RoomExternalTarget(web: 'https://fm.missevan.com/live/$path');
  }

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
  LiveDanmaku getDanmaku() => MissevanDanmaku();
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

  static String? _searchRoomId(String input) {
    try {
      return MissevanApi.roomId(input);
    } on MissevanException {
      final uri = Uri.tryParse(input);
      return uri == null ? null : MissevanApi.roomFromUri(uri);
    }
  }

  @override
  bool supportsSearchPaginationFor(String keyword) {
    final input = keyword.trim();
    return input.isNotEmpty && _searchRoomId(input) == null && Uri.tryParse(input)?.hasScheme != true;
  }

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
    final id = _searchRoomId(input);
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

  Future<LiveRoom> _detail(LiveRoom liveroom) {
    final roomId = liveroom.roomId ?? '';
    final platform = liveroom.platform ?? '';
    if (platform != id) throw const MissevanException(MissevanFailure.schema);
    return _api.detail(roomId);
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return _detail(liveroom);
  }

  @override
  Future<LiveRoom> getRoomDetailForRefresh(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return _detail(liveroom);
  }

  @override
  Future<LiveRoom> getRoomDetailForRecording(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return _detail(liveroom);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom liveroom}) async {
    if (liveroom.platform != id) throw const MissevanException(MissevanFailure.schema);
    if (liveroom.isExplicitlyOfflineNow) return [];
    if (!liveroom.isLiveNow || liveroom.data is! List<LivePlayQuality> || (liveroom.data as List).isEmpty) {
      throw const MissevanException(MissevanFailure.schema);
    }
    return List.unmodifiable(liveroom.data as List<LivePlayQuality>);
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom liveroom, required LivePlayQuality quality}) async {
    for (final current in await getPlayQualites(liveroom: liveroom)) {
      if (current.selectionId == quality.selectionId) return List.unmodifiable(current.data as List<String>);
    }
    throw const MissevanException(MissevanFailure.qualityUnavailable);
  }

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsForRecoveryRaw({
    required LiveRoom liveroom,
    required LivePlayQuality quality,
  }) async {
    final fresh = await getRoomDetail(liveroom);
    return LivePlayUrlResolution(
      urls: await getPlayUrls(liveroom: fresh, quality: quality),
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
