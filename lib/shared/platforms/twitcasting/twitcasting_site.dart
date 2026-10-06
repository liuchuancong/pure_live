import 'package:dio/dio.dart';
import 'package:pure_live/core/models/live_area.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/shared/platforms/live_search.dart';
import 'package:pure_live/shared/platforms/live_site.dart';
import 'package:pure_live/core/models/live_category.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/shared/platforms/live_external_room.dart';

import 'twitcasting_api.dart';
import 'twitcasting_danmaku.dart';

class TwitcastingSite extends LiveSite
    implements
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayRecoveryResolver,
        LiveCancellableSearch,
        LivePlayStreamFacts,
        LiveSiteExternalRoomResolver {
  @override
  RoomExternalTarget? externalRoomTarget(LiveRoom liveroom) {
    final path = Uri.encodeComponent(id);
    return RoomExternalTarget(web: 'https://twitcasting.tv/$path');
  }

  TwitcastingSite({TwitcastingApi? api}) : _api = api ?? TwitcastingApi();
  final TwitcastingApi _api;
  @override
  String get id => 'twitcasting';
  @override
  String get name => 'TwitCasting';
  @override
  LiveDanmaku getDanmaku() => TwitcastingDanmaku();
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

  Future<LiveRoom> _resolveDetail(LiveRoom liveroom) {
    final roomId = liveroom.roomId ?? '';
    final platform = liveroom.platform ?? '';
    if (platform != id) throw const TwitcastingException(TwitcastingFailure.schema);
    return _api.detail(roomId);
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return _resolveDetail(liveroom);
  }

  @override
  Future<LiveRoom> getRoomDetailForRefresh(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return _resolveDetail(liveroom);
  }

  @override
  Future<LiveRoom> getRoomDetailForRecording(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return _resolveDetail(liveroom);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom liveroom}) async {
    if (liveroom.platform != id) throw const TwitcastingException(TwitcastingFailure.schema);
    if (liveroom.isExplicitlyOfflineNow) return [];
    if (liveroom.data is! List<LivePlayQuality>) throw const TwitcastingException(TwitcastingFailure.schema);
    return List.unmodifiable(liveroom.data as List<LivePlayQuality>);
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom liveroom, required LivePlayQuality quality}) async {
    for (final current in await getPlayQualites(liveroom: liveroom)) {
      if (current.selectionId == quality.selectionId) return List.unmodifiable(current.data as List<String>);
    }
    throw const TwitcastingException(TwitcastingFailure.qualityUnavailable);
  }

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsForRecoveryRaw({
    required LiveRoom liveroom,
    required LivePlayQuality quality,
  }) async {
    final fresh = await getRoomDetail(liveroom);
    final urls = await getPlayUrls(liveroom: fresh, quality: quality);
    return LivePlayUrlResolution(
      urls: urls,
      appliedQualityData: quality.selectionId,
      streamFacts: declareStreamFacts(urls),
    );
  }

  @override
  Map<String, LiveStreamFacts> declareStreamFacts(List<String> urls) => <String, LiveStreamFacts>{
    for (final url in urls)
      if (_isTwitCastingHost(url)) url: (format: LiveStreamFormat.hls, codec: null, unresolvedChildren: true),
  };

  static bool _isTwitCastingHost(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host == 'twitcasting.tv' || host.endsWith('.twitcasting.tv');
  }
}
