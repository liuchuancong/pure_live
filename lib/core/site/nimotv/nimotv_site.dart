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

import 'nimotv_api.dart';
import 'nimotv_browser.dart';
import 'nimotv_link.dart';

class NimoTvSite extends LiveSite
    implements
        LiveSiteDirectoryPager,
        LiveDirectoryNotice,
        LiveCancellableSearch,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayUrlResolver,
        LivePlayRecoveryResolver,
        LivePlayLeaseMetadata {
  NimoTvSite({NimoTvApi? api, NimoTvDirectoryResolver? directoryResolver})
    : _api = api ?? NimoTvApi(),
      _directoryResolver = directoryResolver ?? NimoTvBrowserDirectoryResolver();

  final NimoTvApi _api;
  final NimoTvDirectoryResolver _directoryResolver;

  @override
  String get id => 'nimotv';

  @override
  String get name => 'NimoTV';

  @override
  String get directoryNoticeKey => 'nimotv_directory_scope';

  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async => page == 1
      ? [
          LiveCategory(
            id: id,
            name: name,
            children: [
              LiveArea(
                platform: id,
                areaType: 'snapshot',
                areaId: 'homepage',
                areaName: i18n('nimotv_category_homepage'),
                typeName: name,
              ),
            ],
          ),
        ]
      : [];

  static LiveRoom _room(NimoTvRoom room, {required bool includeMedia}) => LiveRoom(
    platform: 'nimotv',
    roomId: room.roomId,
    userId: room.anchorId,
    title: room.title,
    nick: room.nickname,
    avatar: room.avatar,
    cover: room.cover,
    area: room.category,
    link: NimoTvLink.url(room.roomId),
    liveStatus: switch (room.state) {
      NimoTvState.live => LiveStatus.live,
      NimoTvState.offline => LiveStatus.offline,
      NimoTvState.unknown => LiveStatus.unknown,
    },
    onlineViewers: room.viewerCount?.toString(),
    audienceMetricType: AudienceMetricType.onlineViewers,
    notice: i18n('nimotv_chat_notice'),
    httpHeaders: NimoTvApi.mediaHeaders(room.roomId),
    data: includeMedia ? room : null,
  );

  bool _supportsCategory(LiveArea category) =>
      category.platform == id &&
      ((category.areaType == 'snapshot' && category.areaId == 'homepage') ||
          (category.areaType == 'exact' && category.areaId == 'channel'));

  Future<List<NimoTvRoom>> _directoryRooms({CancelToken? cancel}) async {
    if (cancel?.isCancelled == true) throw const NimoTvException(NimoTvFailure.cancelled);
    try {
      final rooms = await _directoryResolver.resolve();
      if (cancel?.isCancelled == true) throw const NimoTvException(NimoTvFailure.cancelled);
      return rooms;
    } on NimoTvException {
      rethrow;
    } catch (_) {
      if (cancel?.isCancelled == true) throw const NimoTvException(NimoTvFailure.cancelled);
      throw const NimoTvException(NimoTvFailure.transport);
    }
  }

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    if (category != null && !_supportsCategory(category)) {
      throw const NimoTvException(NimoTvFailure.identity);
    }
    if (page != 1) return LiveDirectoryPage(page: page, hasMore: false, rooms: const []);
    final rooms = await _directoryRooms(cancel: cancel);
    return LiveDirectoryPage(
      page: page,
      hasMore: false,
      rooms: List.unmodifiable(rooms.map((room) => _room(room, includeMedia: false))),
    );
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) =>
      _directorySlice(page: page, pageSize: pageSize);

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    if (!_supportsCategory(category)) {
      throw const NimoTvException(NimoTvFailure.identity);
    }
    return _directorySlice(page: page, pageSize: pageSize);
  }

  Future<List<LiveRoom>> _directorySlice({required int page, required int pageSize}) async {
    if (page < 1 || pageSize < 1) return const [];
    final rooms = await _directoryRooms();
    final start = (page - 1) * pageSize;
    if (start >= rooms.length) return const [];
    final end = (start + pageSize).clamp(0, rooms.length);
    return List.unmodifiable(rooms.sublist(start, end).map((room) => _room(room, includeMedia: false)));
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
    if (page < 1 || pageSize < 1) return [];
    final key = NimoTvLink.parse(keyword) ?? NimoTvLink.parseKey(keyword);
    if (key != null && page == 1) {
      try {
        return [_room(await _api.room(key.storageKey, resolveMedia: false, cancel: cancel), includeMedia: false)];
      } on NimoTvException catch (error) {
        if (error.kind != NimoTvFailure.missing) rethrow;
      }
    }
    if (cancel?.isCancelled == true) throw const NimoTvException(NimoTvFailure.cancelled);
    final normalized = keyword.trim().toLowerCase();
    if (normalized.isEmpty) return [];
    final rooms = await _directoryRooms(cancel: cancel);
    if (cancel?.isCancelled == true) throw const NimoTvException(NimoTvFailure.cancelled);
    final matches = rooms
        .where((room) {
          return room.nickname.toLowerCase().contains(normalized) ||
              room.title.toLowerCase().contains(normalized) ||
              room.category.toLowerCase().contains(normalized);
        })
        .toList(growable: false);
    final start = (page - 1) * pageSize;
    if (start >= matches.length) return [];
    final end = (start + pageSize).clamp(0, matches.length);
    return List.unmodifiable(matches.sublist(start, end).map((room) => _room(room, includeMedia: false)));
  }

  String _key(String roomId, String platform) {
    if (platform.trim().toLowerCase() != id) throw const NimoTvException(NimoTvFailure.identity);
    final key = NimoTvLink.parseKey(roomId);
    if (key == null) throw const NimoTvException(NimoTvFailure.identity);
    return key.storageKey;
  }

  Future<LiveRoom> _detail(String roomId, String platform, {required bool includeMedia}) async =>
      _room(await _api.room(_key(roomId, platform), resolveMedia: includeMedia), includeMedia: includeMedia);

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
      throw const NimoTvException(NimoTvFailure.unknownState);
    }
    return room.isLiveNow;
  }

  NimoTvRoom _snapshot(LiveRoom detail) {
    final expected = _key(detail.roomId ?? '', detail.platform ?? '');
    final data = detail.data;
    if (data is! NimoTvRoom || data.roomId != expected) throw const NimoTvException(NimoTvFailure.identity);
    if (data.state != NimoTvState.live || data.qualities.isEmpty) {
      throw const NimoTvException(NimoTvFailure.mediaUnavailable);
    }
    return data;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    if (detail.isExplicitlyOfflineNow) return [];
    final room = _snapshot(detail);
    return List.unmodifiable(
      room.qualities.map((quality) => LivePlayQuality(id: quality.id, quality: quality.label, sort: quality.sort)),
    );
  }

  Future<LivePlayUrlResolution> _resolve(LiveRoom detail, LivePlayQuality quality, {required bool refresh}) async {
    var room = _snapshot(detail);
    if (refresh) room = _snapshot(await getRoomDetail(roomId: room.roomId, platform: id));
    final selectionId = quality.selectionId.toString();
    for (final stream in room.qualities) {
      if (stream.id == selectionId) {
        return LivePlayUrlResolution(urls: [stream.url.toString()], appliedQualityData: selectionId);
      }
    }
    throw const NimoTvException(NimoTvFailure.mediaUnavailable);
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
  DateTime? getPlayUrlRefreshAt(String url, {DateTime? now}) => NimoTvApi.mediaRefreshAt(url);

  @override
  DateTime? getPlayUrlInvalidAt(String url, {DateTime? now}) => NimoTvApi.mediaInvalidAt(url);
}
