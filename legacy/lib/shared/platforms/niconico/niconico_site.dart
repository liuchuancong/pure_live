import 'package:pure_live/shared/platforms/live_search.dart';
import 'package:pure_live/shared/platforms/live_quality_discovery.dart';
import 'package:dio/dio.dart';
import 'package:pure_live/core/models/live_area.dart';
import 'package:pure_live/shared/platforms/live_directory.dart';
import 'package:pure_live/core/models/live_category.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/shared/platforms/empty_danmaku.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/shared/platforms/live_site.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/core/utils/i18n.dart';
import 'package:pure_live/shared/platforms/live_external_room.dart';
import 'package:pure_live/shared/platforms/niconico/niconico_link.dart';

import 'niconico_api.dart';
import 'niconico_contract.dart';
import 'niconico_directory.dart';
import 'niconico_input_recipe.dart';
import 'niconico_quality_catalog.dart';
import 'niconico_watch.dart';

class _Choice {
  const _Choice(this.programId, this.quality);
  final String programId;
  final NiconicoQuality quality;
  Map<String, Object> toJson() => {'programId': programId, ...quality.toJson()};
}

/// Anonymous program directory and playback. Registry/navigation acceptance is
/// a separate stage; this class never persists a watch bootstrap.
class NiconicoSite extends LiveSite
    implements
        LiveSiteDirectoryPager,
        LiveDirectoryNotice,
        LiveQualityDiscovery,
        LiveCancellableSearch,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayUrlResolver,
        LivePlayRecoveryResolver,
        LivePlayUrlCursorResolver,
        LiveSiteExternalRoomResolver {
  @override
  RoomExternalTarget? externalRoomTarget(LiveRoom liveroom) {
    final id = sanitizedExternalRoomId(liveroom.roomId);
    if (id == null) return null;
    try {
      return RoomExternalTarget(web: NiconicoLink.url(id));
    } on NiconicoException {
      return null;
    }
  }

  /// [readMaster] is supplied by the composition root: the reader is built on the
  /// recorder's HLS relay, which the shared layer must not depend on.
  NiconicoSite({
    NiconicoApi? api,
    NiconicoQualityCatalog? catalog,
    NiconicoDirectory? directory,
    required NiconicoMasterReader readMaster,
  }) : _api = api ?? NiconicoApi(),
       _directory = directory ?? NiconicoDirectory(api: api),
       _catalog = catalog ?? NiconicoQualityCatalog(api: api, readMaster: readMaster);
  final NiconicoDirectory _directory;
  final NiconicoApi _api;
  final NiconicoQualityCatalog _catalog;
  @override
  String get id => 'niconico';
  @override
  String get name => 'niconico';
  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  @override
  String get directoryNoticeKey => 'niconico_directory_scope';

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    NiconicoDirectory.validatePage(page);
    _pageSize(pageSize);
    return page == 1
        ? [
            LiveCategory(
              id: id,
              name: name,
              children: [
                for (final tab in NiconicoDirectory.categories)
                  LiveArea(
                    platform: id,
                    areaType: 'recent',
                    areaId: tab,
                    areaName: i18n('niconico_category_$tab'),
                    typeName: name,
                  ),
              ],
            ),
          ]
        : [];
  }

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) {
    if (category != null &&
        (category.platform != id ||
            category.areaType != 'recent' ||
            !NiconicoDirectory.categories.contains(category.areaId))) {
      throw const NiconicoException(NiconicoFailure.schema);
    }
    return _directory.recent(page: page, tab: category?.areaId ?? 'common', cancel: cancel);
  }

  static void _pageSize(int pageSize) {
    if (pageSize < 1 || pageSize > 100) throw const NiconicoException(NiconicoFailure.schema);
  }

  // Legacy APIs preserve native page boundaries (70 recent / 40 search).
  // Directory consumers use LiveSiteDirectoryPager for authoritative hasMore.
  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    _pageSize(pageSize);
    return (await getDirectoryPage(page: page)).rooms;
  }

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    _pageSize(pageSize);
    return (await getDirectoryPage(page: page, category: category)).rooms;
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
    if (cancel?.isCancelled == true) throw cancel!.cancelError!;
    _pageSize(pageSize);
    return (await _directory.search(keyword, page: page, cancel: cancel)).rooms;
  }

  String _identity(LiveRoom liveroom) {
    final roomId = liveroom.roomId ?? '';
    final platform = liveroom.platform ?? '';
    if (platform != id) throw const NiconicoException(NiconicoFailure.identity);
    if (NiconicoApi.isProgramId(roomId) || NiconicoApi.isBroadcasterRoomId(roomId)) return roomId;
    throw const NiconicoException(NiconicoFailure.identity);
  }

  Future<String> _programIdOf(String roomId) async =>
      NiconicoApi.isProgramId(roomId) ? roomId : await _api.resolveBroadcasterProgram(roomId);

  Future<LiveRoom> _detail(LiveRoom liveroom) async {
    final roomId = _identity(liveroom);
    final watch = await _api.room(roomId);
    final notice = switch (watch.access) {
      NiconicoAccess.loginRequired => i18n('niconico_login_required'),
      NiconicoAccess.regionRestricted => i18n('niconico_region_restricted'),
      NiconicoAccess.denied => i18n('niconico_access_restricted'),
      NiconicoAccess.allowed => null,
    };
    return LiveRoom(
      platform: id,
      roomId: roomId,
      title: watch.title,
      nick: watch.broadcaster,
      cover: watch.cover ?? '',
      avatar: watch.avatar ?? '',
      link: NiconicoLink.url(roomId),
      liveStatus: watch.status == NiconicoStatus.onAir ? LiveStatus.live : LiveStatus.offline,
      totalViewers: watch.reportedWatchCount?.toString(),
      audienceMetricType: AudienceMetricType.totalViewers,
      notice: [
        if (watch.status == NiconicoStatus.scheduled) i18n('niconico_scheduled'),
        if (watch.status == NiconicoStatus.onAir && notice != null) notice,
        i18n('niconico_program_scope'),
      ].join(' '),
    );
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
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom liveroom}) =>
      discoverPlayQualitiesRaw(liveroom: liveroom);

  @override
  Future<List<LivePlayQuality>> discoverPlayQualitiesRaw({required LiveRoom liveroom, CancelToken? cancel}) async {
    if (cancel?.isCancelled == true) throw cancel!.cancelError!;
    final programId = await _programIdOf(_identity(liveroom));
    if (liveroom.isExplicitlyOfflineNow) return const [];
    final choices = await _catalog.load(programId, cancel: cancel);
    return List.unmodifiable([
      for (final choice in choices)
        LivePlayQuality(id: choice.id, quality: choice.label, data: _Choice(programId, choice)),
    ]);
  }

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsRaw({
    required LiveRoom liveroom,
    required LivePlayQuality quality,
  }) async {
    final programId = await _programIdOf(_identity(liveroom));
    if (liveroom.isExplicitlyOfflineNow) throw const NiconicoException(NiconicoFailure.notLive);
    final choice = quality.data;
    if (choice is! _Choice || choice.programId != programId || quality.selectionId != choice.quality.id) {
      throw const NiconicoException(NiconicoFailure.identity);
    }
    return LivePlayUrlResolution.owned(
      input: NiconicoInputRecipe(
        programId: programId,
        resolution: choice.quality.resolution,
        bandwidth: choice.quality.bandwidth,
      ),
      appliedQualityData: choice.quality.id,
    );
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom liveroom, required LivePlayQuality quality}) async {
    await resolvePlayUrlsRaw(liveroom: liveroom, quality: quality);
    return const [];
  }

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsForRecoveryRaw({
    required LiveRoom liveroom,
    required LivePlayQuality quality,
  }) => resolvePlayUrlsRaw(liveroom: liveroom, quality: quality);
  @override
  Future<LivePlayUrlResolution> resolvePlayUrlAtRaw({
    required LiveRoom liveroom,
    required LivePlayQuality quality,
    required int lineIndex,
  }) {
    if (lineIndex != 0) return Future.value(const LivePlayUrlResolution(urls: []));
    return resolvePlayUrlsRaw(liveroom: liveroom, quality: quality);
  }
}
