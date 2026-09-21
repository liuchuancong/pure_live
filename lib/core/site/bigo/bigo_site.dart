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

import 'bigo_api.dart';
import 'bigo_input_recipe.dart';
import 'bigo_link.dart';

final class BigoSite extends LiveSite
    implements
        LiveSiteDirectoryPager,
        LiveDirectoryNotice,
        LiveCancellableSearch,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayUrlResolver,
        LivePlayRecoveryResolver {
  BigoSite({BigoApi? api}) : _api = api ?? BigoApi();

  final BigoApi _api;
  Future<List<BigoDirectoryCard>>? _directoryRequest;
  DateTime? _directoryAt;

  @override
  String get id => 'bigo';

  @override
  String get name => 'Bigo Live';

  @override
  String get directoryNoticeKey => 'bigo_directory_scope';

  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  Future<List<BigoDirectoryCard>> _directory({CancelToken? cancel}) {
    if (cancel != null) return _api.directory(cancel: cancel);
    final now = DateTime.now();
    final cached = _directoryRequest;
    if (cached != null && _directoryAt != null && now.difference(_directoryAt!) < const Duration(seconds: 30)) {
      return cached;
    }
    late final Future<List<BigoDirectoryCard>> request;
    request = _api
        .directory()
        .then((value) {
          _directoryAt = DateTime.now();
          return value;
        })
        .catchError((Object error) {
          if (identical(_directoryRequest, request)) {
            _directoryRequest = null;
            _directoryAt = null;
          }
          throw error;
        });
    return _directoryRequest = request;
  }

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    if (page != 1 || pageSize < 1) return [];
    return [
      LiveCategory(
        id: id,
        name: name,
        children: [
          LiveArea(
            platform: id,
            areaType: 'public',
            areaId: '72',
            areaName: i18n('bigo_category_public'),
            typeName: name,
          ),
        ],
      ),
    ];
  }

  void _category(LiveArea? category) {
    if (category != null && (category.platform != id || category.areaType != 'public' || category.areaId != '72')) {
      throw const BigoException(BigoFailure.identity);
    }
  }

  static List<T> _page<T>(List<T> values, int page, int pageSize) {
    if (page < 1 || pageSize < 1 || pageSize > 100) return [];
    final start = (page - 1) * pageSize;
    if (start >= values.length) return [];
    return values.sublist(start, (start + pageSize).clamp(0, values.length));
  }

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    _category(category);
    if (page < 1) throw const BigoException(BigoFailure.schema);
    final cards = await _directory(cancel: cancel);
    const size = 20;
    final rooms = _page(cards, page, size).map(_card).toList(growable: false);
    return LiveDirectoryPage(rooms: rooms, page: page, hasMore: page * size < cards.length);
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async =>
      _page(await _directory(), page, pageSize).map(_card).toList(growable: false);

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    _category(category);
    return getRecommendRooms(page: page, pageSize: pageSize);
  }

  static LiveRoom _card(BigoDirectoryCard card) {
    final viewers = card.reportedViewers?.toString();
    return LiveRoom(
      platform: 'bigo',
      roomId: card.siteId,
      userId: '${card.ownerId}',
      title: card.title.isEmpty ? card.nickname : card.title,
      nick: card.nickname,
      cover: card.cover ?? '',
      avatar: card.cover ?? '',
      area: 'Bigo Live',
      link: BigoLink.url(card.siteId),
      liveStatus: LiveStatus.live,
      watching: viewers ?? '',
      onlineViewers: viewers,
      audienceMetricType: AudienceMetricType.onlineViewers,
      notice: i18n('bigo_chat_notice'),
      httpHeaders: BigoApi.headers,
    );
  }

  LiveRoom _room(BigoStudioRoom room, {required bool includeMedia}) {
    final status = room.status;
    final liveStatus = switch ((status.access, status.reportedAlive, room.hls)) {
      (BigoAccess.public, true, Uri()) => LiveStatus.live,
      (BigoAccess.public, false, _) => LiveStatus.offline,
      _ => LiveStatus.unknown,
    };
    final notice = switch (status.access) {
      BigoAccess.loginRequired => i18n('bigo_login_required'),
      BigoAccess.restricted => i18n('bigo_access_restricted'),
      BigoAccess.public => i18n('bigo_chat_notice'),
    };
    return LiveRoom(
      platform: id,
      roomId: status.canonicalSiteId,
      userId: '${status.ownerId}',
      title: room.title.isEmpty ? room.nickname : room.title,
      nick: room.nickname,
      avatar: room.avatar ?? '',
      cover: room.avatar ?? '',
      area: room.category.isEmpty ? name : room.category,
      link: BigoLink.url(status.canonicalSiteId),
      liveStatus: liveStatus,
      notice: notice,
      httpHeaders: BigoApi.headers,
      data: includeMedia && liveStatus == LiveStatus.live ? room : null,
    );
  }

  String _identity(String roomId, String platform) {
    if (platform.trim().toLowerCase() != id) throw const BigoException(BigoFailure.identity);
    return BigoApi.validateSiteId(roomId);
  }

  Future<LiveRoom> _detail(String roomId, String platform, {required bool includeMedia}) async =>
      _room(await _api.studioRoom(siteId: _identity(roomId, platform)), includeMedia: includeMedia);

  @override
  Future<LiveRoom> getRoomDetail({required String roomId, required String platform}) =>
      _detail(roomId, platform, includeMedia: true);

  @override
  Future<LiveRoom> getRoomDetailForRefresh({required String roomId, required String platform}) =>
      _detail(roomId, platform, includeMedia: false);

  @override
  Future<LiveRoom> getRoomDetailForRecording({required String roomId, required String platform}) =>
      _detail(roomId, platform, includeMedia: true);

  @override
  Future<bool> getLiveStatus({required String platform, required String roomId}) async {
    final room = await getRoomDetailForRefresh(roomId: roomId, platform: platform);
    if (room.effectiveLiveStatus == LiveStatus.unknown) throw const BigoException(BigoFailure.unknownState);
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
    final siteId = BigoLink.parseOrSiteId(keyword);
    if (siteId == null) return [];
    try {
      return [_room(await _api.studioRoom(siteId: siteId, cancel: cancel), includeMedia: false)];
    } on BigoException catch (error) {
      if (error.kind == BigoFailure.missing) return [];
      rethrow;
    }
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    final siteId = _identity(detail.roomId ?? '', detail.platform ?? '');
    if (detail.isExplicitlyOfflineNow) return const [];
    final room = detail.data;
    if (detail.effectiveLiveStatus != LiveStatus.live ||
        room is! BigoStudioRoom ||
        room.status.canonicalSiteId != siteId) {
      throw const BigoException(BigoFailure.mediaUnavailable);
    }
    return [LivePlayQuality(id: 'live', quality: i18n('bigo_quality_live'))];
  }

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsRaw({required LiveRoom detail, required LivePlayQuality quality}) async {
    final siteId = _identity(detail.roomId ?? '', detail.platform ?? '');
    if (detail.isExplicitlyOfflineNow) throw const BigoException(BigoFailure.notLive);
    if (quality.selectionId != 'live' || (await getPlayQualites(detail: detail)).isEmpty) {
      throw const BigoException(BigoFailure.mediaUnavailable);
    }
    return LivePlayUrlResolution.owned(input: BigoInputRecipe(siteId), appliedQualityData: 'live');
  }

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsForRecoveryRaw({
    required LiveRoom detail,
    required LivePlayQuality quality,
  }) => resolvePlayUrlsRaw(detail: detail, quality: quality);

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    await resolvePlayUrlsRaw(detail: detail, quality: quality);
    return const [];
  }
}
