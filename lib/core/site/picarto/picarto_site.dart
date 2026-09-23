import 'package:dio/dio.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/danmaku/empty_danmaku.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/interface/live_directory.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/plugins/locale_helper.dart';

import 'picarto_api.dart';
import 'picarto_hls.dart';

class PicartoSite extends LiveSite
    implements LiveSiteRoomRefresher, LiveSiteRecordRoomResolver, LivePlayRecoveryResolver, LiveSiteDirectoryPager {
  PicartoSite({PicartoApi? api}) : _api = api ?? PicartoApi();
  final PicartoApi _api;
  @override
  String get id => 'picarto';
  @override
  String get name => 'Picarto';
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
  Future<LiveRoom> getRoomDetailForRefresh({required String roomId, required String platform}) async =>
      (await _api.detail(roomId)).room;
  @override
  Future<LiveRoom> getRoomDetail({required String roomId, required String platform}) async {
    final detail = await _api.detail(roomId);
    if (detail.master != null) detail.room.data = parsePicartoHls(await _api.read(detail.master!), detail.master!);
    return detail.room;
  }

  @override
  Future<LiveRoom> getRoomDetailForRecording({required String roomId, required String platform}) =>
      getRoomDetail(roomId: roomId, platform: platform);
  @override
  Future<bool> getLiveStatus({required String platform, required String roomId}) async =>
      (await getRoomDetailForRefresh(roomId: roomId, platform: platform)).isPlayableNow;
  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    if (detail.isExplicitlyOfflineNow) return [];
    if (detail.platform != id || detail.data is! List<LivePlayQuality>) {
      throw const PicartoException(PicartoFailure.schema);
    }
    return List.unmodifiable(detail.data as List<LivePlayQuality>);
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    for (final current in await getPlayQualites(detail: detail)) {
      if (current.selectionId == quality.selectionId) return List.unmodifiable(current.data as List<String>);
    }
    throw const PicartoException(PicartoFailure.qualityUnavailable);
  }

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsForRecoveryRaw({
    required LiveRoom detail,
    required LivePlayQuality quality,
  }) async {
    final fresh = await getRoomDetail(roomId: detail.roomId!, platform: id);
    return LivePlayUrlResolution(
      urls: await getPlayUrls(detail: fresh, quality: quality),
      appliedQualityData: quality.selectionId,
    );
  }
}
