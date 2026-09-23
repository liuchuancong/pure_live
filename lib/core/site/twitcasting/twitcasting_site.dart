import 'package:dio/dio.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/danmaku/empty_danmaku.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/interface/live_search.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/model/live_play_quality.dart';

import 'twitcasting_api.dart';

class TwitcastingSite extends LiveSite
    implements LiveSiteRoomRefresher, LiveSiteRecordRoomResolver, LivePlayRecoveryResolver, LiveCancellableSearch {
  TwitcastingSite({TwitcastingApi? api}) : _api = api ?? TwitcastingApi();
  final TwitcastingApi _api;
  @override
  String get id => 'twitcasting';
  @override
  String get name => 'TwitCasting';
  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();
  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async =>
      page == 1 ? [LiveCategory(id: id, name: name, children: await _api.categories())] : [];
  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) =>
      _api.directory(page: page, pageSize: pageSize);
  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) {
    if (category.platform != id ||
        category.areaType != 'directory' ||
        category.areaId == null ||
        category.areaId!.isEmpty) {
      throw const TwitcastingException(TwitcastingFailure.schema);
    }
    return _api.directory(page: page, pageSize: pageSize, category: category.areaId!);
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
  }) => _api.searchLives(keyword, page: page, pageSize: pageSize, cancel: cancel);

  @override
  Future<LiveRoom> getRoomDetail({required String roomId, required String platform}) {
    if (platform != id) throw const TwitcastingException(TwitcastingFailure.schema);
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
      (await getRoomDetail(roomId: roomId, platform: platform)).isPlayableNow;
  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    if (detail.platform != id) throw const TwitcastingException(TwitcastingFailure.schema);
    if (detail.isExplicitlyOfflineNow) return [];
    if (detail.data is! List<LivePlayQuality>) throw const TwitcastingException(TwitcastingFailure.schema);
    return List.unmodifiable(detail.data as List<LivePlayQuality>);
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    for (final current in await getPlayQualites(detail: detail)) {
      if (current.selectionId == quality.selectionId) return List.unmodifiable(current.data as List<String>);
    }
    throw const TwitcastingException(TwitcastingFailure.qualityUnavailable);
  }

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsForRecoveryRaw({
    required LiveRoom detail,
    required LivePlayQuality quality,
  }) async {
    final fresh = await getRoomDetail(roomId: detail.roomId!, platform: detail.platform!);
    return LivePlayUrlResolution(
      urls: await getPlayUrls(detail: fresh, quality: quality),
      appliedQualityData: quality.selectionId,
    );
  }
}
