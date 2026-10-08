import 'package:dio/dio.dart';
import 'package:pure_live/core/models/live_area.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/shared/platforms/live_directory.dart';
import 'package:pure_live/shared/platforms/live_search.dart';
import 'package:pure_live/shared/platforms/live_site.dart';
import 'package:pure_live/core/models/live_category.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/core/utils/i18n.dart';
import 'package:pure_live/shared/platforms/live_external_room.dart';

import 'picarto_api.dart';
import 'picarto_danmaku.dart';
import 'picarto_hls.dart';

class PicartoSite extends LiveSite
    implements
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayRecoveryResolver,
        LiveSiteDirectoryPager,
        LiveCancellableSearch,
        LiveSiteExternalRoomResolver {
  @override
  RoomExternalTarget? externalRoomTarget(LiveRoom liveroom) {
    final path = Uri.encodeComponent(id);
    return RoomExternalTarget(web: 'https://picarto.tv/$path');
  }

  PicartoSite({PicartoApi? api}) : _api = api ?? PicartoApi();
  final PicartoApi _api;
  @override
  String get id => 'picarto';
  @override
  String get name => 'Picarto';
  @override
  LiveDanmaku getDanmaku() => PicartoDanmaku();

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async => page == 1
      ? [
          LiveCategory(
            id: id,
            name: name,
            children: [
              LiveArea(
                platform: id,
                areaId: 'live',
                areaType: 'directory',
                areaName: i18n('picarto_public_directory'),
                typeName: name,
              ),
              ...await _api.categories(),
            ],
          ),
        ]
      : [];

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) {
    if (category != null && category.platform == id && category.areaType == 'directory' && category.areaId == 'live') {
      return _api.directoryPage(page: page, cancel: cancel);
    }
    return _api.directoryPage(page: page, category: category, cancel: cancel);
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) =>
      _api.directory(page: page, pageSize: pageSize);
  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) {
    if (category.platform == id && category.areaId == 'live' && category.areaType == 'directory') {
      return getRecommendRooms(page: page, pageSize: pageSize);
    }
    return _api.directory(page: page, pageSize: pageSize, category: category);
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
  }) => _api.searchProfiles(keyword, page: page, pageSize: pageSize, cancel: cancel);

  @override
  Future<LiveRoom> getRoomDetailForRefresh(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return (await _api.detail(liveroom.roomId!)).room;
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return _resolveDetail(liveroom.roomId!);
  }

  Future<LiveRoom> _resolveDetail(String roomId) async {
    final detail = await _api.detail(roomId);
    if (detail.master != null) detail.room.data = parsePicartoHls(await _api.read(detail.master!), detail.master!);
    return detail.room;
  }

  @override
  Future<LiveRoom> getRoomDetailForRecording(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return _resolveDetail(liveroom.roomId!);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom liveroom}) async {
    if (liveroom.isExplicitlyOfflineNow) return [];
    if (liveroom.platform != id || liveroom.data is! List<LivePlayQuality>) {
      throw const PicartoException(PicartoFailure.schema);
    }
    return List.unmodifiable(liveroom.data as List<LivePlayQuality>);
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom liveroom, required LivePlayQuality quality}) async {
    for (final current in await getPlayQualites(liveroom: liveroom)) {
      if (current.selectionId == quality.selectionId) return List.unmodifiable(current.data as List<String>);
    }
    throw const PicartoException(PicartoFailure.qualityUnavailable);
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
