import 'package:dio/dio.dart';
import 'package:pure_live/core/index.dart' show i18n;
import 'package:pure_live/core/models/live_area.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/shared/platforms/empty_danmaku.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/shared/platforms/live_directory.dart';
import 'package:pure_live/shared/platforms/live_search.dart';
import 'package:pure_live/shared/platforms/live_site.dart';
import 'package:pure_live/core/models/live_category.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/shared/platforms/live_external_room.dart';

import 'inke_api.dart';

class InkeSite extends LiveSite
    implements
        LiveSiteDirectoryPager,
        LiveDirectoryNotice,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayRecoveryResolver,
        LiveCancellableSearch,
        LiveSearchPaginationPolicy,
        LiveSiteExternalRoomResolver {
  @override
  RoomExternalTarget? externalRoomTarget(LiveRoom liveroom) {
    // Preserve Inke's verified UID/broadcast link and official-home fallback.
    return RoomExternalTarget(web: InkeSite.externalRoomUrl(liveroom));
  }

  InkeSite({InkeApi? api}) : _api = api ?? InkeApi();
  final InkeApi _api;

  /// Official room pages need both the durable UID and a broadcast ID. Older
  /// favorites/offline metadata can lack the latter; do not invent a room URL.
  static String externalRoomUrl(LiveRoom liveroom) {
    final uri = Uri.tryParse(liveroom.link?.trim() ?? '');
    if (uri != null &&
        liveroom.platform == 'inke' &&
        liveroom.roomId != null &&
        InkeApi.roomFromUri(uri) == liveroom.roomId) {
      try {
        final ids = uri.queryParametersAll['id'];
        if (ids?.length == 1 && RegExp(r'^[0-9]{1,32}$').hasMatch(ids!.single)) return uri.toString();
      } on FormatException {
        // Malformed imported links use the official homepage.
      }
    }
    return '${InkeApi.origin}/';
  }

  @override
  String get id => 'inke';
  @override
  String get name => i18n('site_inke');
  @override
  String get directoryNoticeKey => 'inke_directory_scope';
  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();
  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) =>
      _api.directoryPage(page: page, category: category, cancel: cancel);
  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async =>
      page == 1 ? [LiveCategory(id: id, name: name, children: await _api.categories())] : [];

  Future<List<LiveRoom>> _slice({required int page, required int pageSize, LiveArea? category}) async {
    if (page < 1 || pageSize < 1) throw const InkeException(InkeFailure.schema);
    // Legacy list consumers slice one complete website showcase. The main
    // popular/category routes use the native contract and keep overflow once.
    final rows = (await getDirectoryPage(category: category)).rooms;
    if (page - 1 > rows.length ~/ pageSize) return [];
    final start = (page - 1) * pageSize;
    if (start < 0 || start >= rows.length) return [];
    return rows.sublist(start, (start + pageSize).clamp(start, rows.length));
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) => _slice(page: page, pageSize: pageSize);
  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) =>
      _slice(page: page, pageSize: pageSize, category: category);

  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) =>
      searchRoomsCancellable(keyword, page: page, pageSize: pageSize);

  static String? _searchUid(String input) {
    try {
      return InkeApi.roomId(input);
    } on InkeException {
      final uri = Uri.tryParse(input);
      return uri == null ? null : InkeApi.roomFromUri(uri);
    }
  }

  @override
  bool supportsSearchPaginationFor(String keyword) {
    final input = keyword.trim();
    return input.isNotEmpty && _searchUid(input) == null && Uri.tryParse(input)?.hasScheme != true;
  }

  @override
  Future<List<LiveRoom>> searchRoomsCancellable(
    String keyword, {
    int page = 1,
    int pageSize = 30,
    CancelToken? cancel,
  }) async {
    if (page < 1 || pageSize < 1) throw const InkeException(InkeFailure.schema);
    final input = keyword.trim();
    final uid = _searchUid(input);
    if (uid == null) {
      // A malformed/shared URL is not a nickname query.
      if (Uri.tryParse(input)?.hasScheme == true) return const [];
      return _api.searchShowcases(input, page: page, pageSize: pageSize, cancel: cancel);
    }
    if (page != 1) return const [];
    try {
      return [await _api.detail(uid, playback: false, cancel: cancel)];
    } on InkeException catch (error) {
      if (error.kind == InkeFailure.notFound) return const [];
      rethrow;
    }
  }

  Future<LiveRoom> _detail(LiveRoom liveroom, {required bool playback}) async {
    final roomId = liveroom.roomId ?? '';
    final platform = liveroom.platform ?? '';
    if (platform != id) throw const InkeException(InkeFailure.schema);
    try {
      return await _api.detail(roomId, playback: playback);
    } on InkeException catch (error) {
      if (error.kind == InkeFailure.mediaUnavailable) {
        throw InkeException(error.kind, message: i18n('inke_media_unavailable'));
      }
      rethrow;
    }
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return _detail(liveroom, playback: true);
  }

  @override
  Future<LiveRoom> getRoomDetailForRecording(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return _detail(liveroom, playback: true);
  }

  @override
  Future<LiveRoom> getRoomDetailForRefresh(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return _detail(liveroom, playback: false);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom liveroom}) async {
    if (liveroom.platform != id) throw const InkeException(InkeFailure.schema);
    if (liveroom.isExplicitlyOfflineNow) return [];
    if (!liveroom.isLiveNow || liveroom.data is! List<LivePlayQuality> || (liveroom.data as List).isEmpty) {
      throw const InkeException(InkeFailure.schema);
    }
    return List.unmodifiable(liveroom.data as List<LivePlayQuality>);
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom liveroom, required LivePlayQuality quality}) async {
    for (final current in await getPlayQualites(liveroom: liveroom)) {
      if (current.selectionId == quality.selectionId) return List.unmodifiable(current.data as List<String>);
    }
    throw const InkeException(InkeFailure.mediaUnavailable);
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
}
