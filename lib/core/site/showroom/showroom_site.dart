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

import 'showroom_api.dart';

class _ShowroomPlayback {
  _ShowroomPlayback(this.roomId, Iterable<LivePlayQuality> qualities) : qualities = List.unmodifiable(qualities);

  final String roomId;
  final List<LivePlayQuality> qualities;
}

class ShowroomSite extends LiveSite
    implements
        LiveSiteDirectoryPager,
        LiveDirectoryNotice,
        LiveCancellableSearch,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayRecoveryResolver {
  ShowroomSite({ShowroomApi? api}) : _api = api ?? ShowroomApi();

  final ShowroomApi _api;
  Future<ShowroomCatalog>? _catalogRequest;
  DateTime? _catalogAt;

  @override
  String get id => 'showroom';

  @override
  String get name => 'SHOWROOM';

  @override
  String get directoryNoticeKey => 'showroom_directory_scope';

  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  Future<ShowroomCatalog> _catalog({CancelToken? cancel}) {
    if (cancel != null) return _api.catalog(cancel: cancel);
    final now = DateTime.now();
    final cached = _catalogRequest;
    if (cached != null && _catalogAt != null && now.difference(_catalogAt!) < const Duration(seconds: 30)) {
      return cached;
    }
    late final Future<ShowroomCatalog> request;
    request = _api
        .catalog()
        .then((value) {
          _catalogAt = DateTime.now();
          return value;
        })
        .catchError((Object error) {
          if (identical(_catalogRequest, request)) {
            _catalogRequest = null;
            _catalogAt = null;
          }
          throw error;
        });
    _catalogRequest = request;
    return request;
  }

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    if (page != 1 || pageSize <= 0) return [];
    final catalog = await _catalog();
    return [
      LiveCategory(
        id: id,
        name: name,
        children: catalog.genres
            .map(
              (genre) => LiveArea(
                platform: id,
                areaType: 'genre',
                typeName: name,
                areaId: '${genre.id}',
                areaName: genre.name,
              ),
            )
            .toList(growable: false),
      ),
    ];
  }

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    if (page < 1) throw const ShowroomException(ShowroomFailure.schema);
    final catalog = await _catalog(cancel: cancel);
    final rooms = category == null ? _popular(catalog) : _category(catalog, category);
    const pageSize = 30;
    final start = (page - 1) * pageSize;
    if (start >= rooms.length) return LiveDirectoryPage(rooms: const [], page: page, hasMore: false);
    final end = (start + pageSize).clamp(0, rooms.length);
    return LiveDirectoryPage(rooms: rooms.sublist(start, end).map(_card), page: page, hasMore: end < rooms.length);
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    final rooms = _popular(await _catalog());
    return _page(rooms, page, pageSize).map(_card).toList(growable: false);
  }

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    final rooms = _category(await _catalog(), category);
    return _page(rooms, page, pageSize).map(_card).toList(growable: false);
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
    final query = keyword.trim().toLowerCase();
    if (query.isEmpty || page < 1 || pageSize < 1) return [];
    final catalog = await _catalog(cancel: cancel);
    final matches = catalog.uniqueLives
        .where((room) {
          return '${room.roomId}' == query ||
              room.roomUrlKey.toLowerCase() == query ||
              room.name.toLowerCase().contains(query) ||
              room.telop.toLowerCase().contains(query) ||
              room.genreName.toLowerCase().contains(query);
        })
        .toList(growable: false);
    return _page(matches, page, pageSize).map(_card).toList(growable: false);
  }

  static List<ShowroomLive> _popular(ShowroomCatalog catalog) {
    for (final genre in catalog.genres) {
      if (genre.id == 0) return genre.lives;
    }
    return catalog.uniqueLives.toList(growable: false);
  }

  List<ShowroomLive> _category(ShowroomCatalog catalog, LiveArea category) {
    if (category.platform != id || category.areaType != 'genre') {
      throw const ShowroomException(ShowroomFailure.identity);
    }
    final genreId = int.tryParse(category.areaId ?? '');
    if (genreId == null || genreId < 0) throw const ShowroomException(ShowroomFailure.identity);
    for (final genre in catalog.genres) {
      if (genre.id == genreId) return genre.lives;
    }
    throw const ShowroomException(ShowroomFailure.missing);
  }

  static List<T> _page<T>(List<T> values, int page, int pageSize) {
    if (page < 1 || pageSize < 1 || pageSize > 100) return [];
    final start = (page - 1) * pageSize;
    if (start >= values.length) return [];
    return values.sublist(start, (start + pageSize).clamp(0, values.length));
  }

  static LiveRoom _card(ShowroomLive live) {
    final audience = live.totalViewers?.toString();
    return LiveRoom(
      platform: 'showroom',
      roomId: '${live.roomId}',
      link: 'https://www.showroom-live.com/r/${live.roomUrlKey}',
      nick: live.name,
      title: live.telop.isEmpty ? live.name : live.telop,
      avatar: live.cover,
      cover: live.cover,
      area: live.genreName,
      followers: live.followers?.toString(),
      watching: audience,
      totalViewers: audience,
      audienceMetricType: AudienceMetricType.totalViewers,
      liveStatus: LiveStatus.live,
      httpHeaders: ShowroomApi.mediaHeaders,
    );
  }

  LiveRoom _detailCard(ShowroomRoom room) {
    final profile = room.profile;
    final audience = profile.totalViewers?.toString();
    final qualities = room.streams.map(_quality).toList(growable: false)
      ..sort((left, right) {
        final rank = right.sort.compareTo(left.sort);
        return rank != 0 ? rank : left.selectionId.toString().compareTo(right.selectionId.toString());
      });
    return LiveRoom(
      platform: id,
      roomId: '${profile.roomId}',
      link: 'https://www.showroom-live.com/r/${profile.roomUrlKey}',
      nick: profile.name,
      title: profile.name,
      avatar: profile.cover,
      cover: profile.cover,
      area: profile.genreName,
      followers: profile.followers?.toString(),
      watching: audience,
      totalViewers: audience,
      audienceMetricType: AudienceMetricType.totalViewers,
      introduction: profile.description,
      liveStatus: profile.isLive ? LiveStatus.live : LiveStatus.offline,
      data: profile.isLive && qualities.isNotEmpty ? _ShowroomPlayback('${profile.roomId}', qualities) : null,
      httpHeaders: ShowroomApi.mediaHeaders,
    );
  }

  static LivePlayQuality _quality(ShowroomStream stream) {
    final label = switch ((stream.type, stream.quality)) {
      ('hls_all', _) => i18n('showroom_quality_auto'),
      (_, >= 1000) => i18n('showroom_quality_original'),
      (_, >= 200) => i18n('showroom_quality_medium'),
      (_, _) => i18n('showroom_quality_low'),
    };
    return LivePlayQuality(
      id: '${stream.type}:${stream.id}:${stream.quality}',
      quality: label,
      sort: stream.type == 'hls_all' ? 2000 : stream.quality,
      data: <String>[stream.url],
    );
  }

  Future<LiveRoom> _detail(String roomId, String platform, {required bool playback}) async {
    if (platform.trim().toLowerCase() != id) throw const ShowroomException(ShowroomFailure.identity);
    return _detailCard(await _api.room(roomId, playback: playback));
  }

  @override
  Future<LiveRoom> getRoomDetail({required String roomId, required String platform}) =>
      _detail(roomId, platform, playback: true);

  @override
  Future<LiveRoom> getRoomDetailForRecording({required String roomId, required String platform}) =>
      _detail(roomId, platform, playback: true);

  @override
  Future<LiveRoom> getRoomDetailForRefresh({required String roomId, required String platform}) =>
      _detail(roomId, platform, playback: false);

  @override
  Future<bool> getLiveStatus({required String platform, required String roomId}) async =>
      (await getRoomDetailForRefresh(roomId: roomId, platform: platform)).isLiveNow;

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    if (detail.platform != id) throw const ShowroomException(ShowroomFailure.identity);
    if (detail.isExplicitlyOfflineNow) return [];
    final data = detail.data;
    if (data is! _ShowroomPlayback || data.roomId != detail.roomId || data.qualities.isEmpty) {
      throw const ShowroomException(ShowroomFailure.mediaUnavailable);
    }
    return data.qualities;
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    for (final current in await getPlayQualites(detail: detail)) {
      if (current.selectionId == quality.selectionId) return List.unmodifiable(current.data as List<String>);
    }
    throw const ShowroomException(ShowroomFailure.mediaUnavailable);
  }

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsForRecoveryRaw({
    required LiveRoom detail,
    required LivePlayQuality quality,
  }) async {
    final fresh = await getRoomDetail(roomId: detail.roomId ?? '', platform: id);
    return LivePlayUrlResolution(
      urls: await getPlayUrls(detail: fresh, quality: quality),
      appliedQualityData: quality.selectionId,
    );
  }
}
