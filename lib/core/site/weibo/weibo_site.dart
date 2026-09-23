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

import 'weibo_api.dart';
import 'weibo_link.dart';

class _WeiboChoice {
  const _WeiboChoice(this.liveId, this.ownerId);
  final String liveId;
  final int ownerId;
}

/// Public broadcast adapter. Registration and account-following are separate
/// contracts; fresh resolution never swaps to an unrelated/new broadcast.
class WeiboSite extends LiveSite
    implements
        LiveSiteDirectoryPager,
        LiveDirectoryNotice,
        LiveCancellableSearch,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayUrlResolver,
        LivePlayRecoveryResolver {
  WeiboSite({WeiboApi? api}) : _api = api ?? WeiboApi();
  final WeiboApi _api;
  @override
  String get id => 'weibo';
  @override
  String get name => i18n('site_weibo');
  @override
  String get directoryNoticeKey => 'weibo_directory_scope';
  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  void _page(int page, [int pageSize = 30]) {
    if (page < 1 || pageSize < 1 || pageSize > 1000) throw const WeiboException(WeiboFailure.schema);
  }

  void _cancel(CancelToken? cancel) {
    if (cancel?.isCancelled == true) throw const WeiboException(WeiboFailure.cancelled);
  }

  String _id(String roomId, String platform) {
    if (platform != id) throw const WeiboException(WeiboFailure.identity);
    return WeiboApi.validateLiveId(roomId);
  }

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    _cancel(cancel);
    _page(page);
    if (category != null &&
        (category.platform != id || category.areaType != 'recommendation' || category.areaId != 'live')) {
      throw const WeiboException(WeiboFailure.schema);
    }
    if (page > 1) return LiveDirectoryPage(page: page, hasMore: false, rooms: const []);
    final cards = await _api.directory(cancel: cancel);
    return LiveDirectoryPage(
      page: page,
      hasMore: false,
      rooms: cards.map(
        (card) => LiveRoom(
          platform: id,
          roomId: card.liveId,
          userId: '${card.ownerId}',
          nick: card.nickname,
          title: card.nickname,
          cover: card.cover,
          link: WeiboLink.url(card.liveId),
          liveStatus: LiveStatus.unknown,
          audienceMetricType: AudienceMetricType.unknown,
          watching: '',
          notice: i18n('weibo_room_scope'),
        ),
      ),
    );
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    _page(page, pageSize);
    return (await getDirectoryPage(page: page)).rooms;
  }

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    _page(page, pageSize);
    return (await getDirectoryPage(page: page, category: category)).rooms;
  }

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    _page(page, pageSize);
    return page == 1
        ? [
            LiveCategory(
              id: id,
              name: name,
              children: [
                LiveArea(
                  platform: id,
                  areaType: 'recommendation',
                  areaId: 'live',
                  areaName: i18n('weibo_public_directory'),
                  typeName: name,
                ),
              ],
            ),
          ]
        : [];
  }

  LiveRoom _room(WeiboLiveDetail detail) => LiveRoom(
    platform: id,
    roomId: detail.liveId,
    userId: '${detail.ownerId}',
    title: detail.title,
    nick: detail.nickname,
    avatar: detail.avatar,
    cover: detail.cover,
    link: WeiboLink.url(detail.liveId),
    liveStatus: switch (detail.state) {
      WeiboBroadcastState.live => LiveStatus.live,
      WeiboBroadcastState.replay => LiveStatus.replay,
      WeiboBroadcastState.unknown => LiveStatus.unknown,
    },
    audienceMetricType: AudienceMetricType.unknown,
    watching: '',
    notice: [if (detail.access != WeiboAccess.public) i18n('weibo_restricted'), i18n('weibo_room_scope')].join('\n'),
    data: detail,
  );
  @override
  Future<LiveRoom> getRoomDetail({required String roomId, required String platform}) async =>
      _room(await _api.detail(_id(roomId, platform)));
  @override
  Future<LiveRoom> getRoomDetailForRecording({required String roomId, required String platform}) =>
      getRoomDetail(roomId: roomId, platform: platform);
  @override
  Future<LiveRoom> getRoomDetailForRefresh({required String roomId, required String platform}) =>
      getRoomDetail(roomId: roomId, platform: platform);
  @override
  Future<bool> getLiveStatus({required String platform, required String roomId}) async {
    final room = await getRoomDetailForRefresh(roomId: roomId, platform: platform);
    if (room.liveStatus == LiveStatus.unknown) {
      final data = _detail(room);
      throw WeiboException(data.access == WeiboAccess.public ? WeiboFailure.unknownState : WeiboFailure.access);
    }
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
    _cancel(cancel);
    _page(page, pageSize);
    if (page > 1) return [];
    final liveId = WeiboLink.parse(keyword);
    if (liveId == null) return [];
    return [_room(await _api.detail(liveId, cancel: cancel))];
  }

  WeiboLiveDetail _detail(LiveRoom room) {
    _id(room.roomId ?? '', room.platform ?? '');
    final detail = room.data;
    if (detail is! WeiboLiveDetail || detail.liveId != room.roomId || '${detail.ownerId}' != room.userId) {
      throw const WeiboException(WeiboFailure.identity);
    }
    return detail;
  }

  void _live(WeiboLiveDetail detail) {
    if (detail.access != WeiboAccess.public) throw const WeiboException(WeiboFailure.access);
    if (detail.state == WeiboBroadcastState.unknown) throw const WeiboException(WeiboFailure.unknownState);
    if (detail.state != WeiboBroadcastState.live) throw const WeiboException(WeiboFailure.notLive);
    if (detail.mediaUrls.isEmpty) throw const WeiboException(WeiboFailure.mediaUnavailable);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    final data = _detail(detail);
    if (data.state == WeiboBroadcastState.replay) return [];
    _live(data);
    return List.unmodifiable([
      LivePlayQuality(
        id: 'original',
        quality: i18n('weibo_original_stream'),
        data: _WeiboChoice(data.liveId, data.ownerId),
      ),
    ]);
  }

  Future<LivePlayUrlResolution> _resolve(LiveRoom detail, LivePlayQuality quality) async {
    final data = _detail(detail);
    _live(data);
    final choice = quality.data;
    if (quality.selectionId != 'original' ||
        choice is! _WeiboChoice ||
        choice.liveId != data.liveId ||
        choice.ownerId != data.ownerId) {
      throw const WeiboException(WeiboFailure.identity);
    }
    // No observed URL expiry contract. Refresh at each new playback/recording
    // attempt instead of caching signed URLs or guessing a lifetime.
    final fresh = await _api.detail(data.liveId, expectedOwnerId: data.ownerId);
    _live(fresh);
    return LivePlayUrlResolution(urls: fresh.mediaUrls, appliedQualityData: 'original');
  }

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsRaw({required LiveRoom detail, required LivePlayQuality quality}) =>
      _resolve(detail, quality);
  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsForRecoveryRaw({
    required LiveRoom detail,
    required LivePlayQuality quality,
  }) => _resolve(detail, quality);
  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async =>
      (await _resolve(detail, quality)).urls;
}
