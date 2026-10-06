import 'package:dio/dio.dart';
import 'package:pure_live/core/models/live_area.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/shared/platforms/empty_danmaku.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/shared/platforms/live_directory.dart';
import 'package:pure_live/shared/platforms/live_search.dart';
import 'package:pure_live/shared/platforms/live_site.dart';
import 'package:pure_live/core/models/live_category.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/core/utils/i18n.dart';
import 'package:pure_live/shared/platforms/live_external_room.dart';

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
        LivePlayRecoveryResolver,
        LiveSiteExternalRoomResolver {
  @override
  RoomExternalTarget? externalRoomTarget(LiveRoom liveroom) {
    final id = sanitizedExternalRoomId(liveroom.roomId);
    if (id == null) return null;
    try {
      return RoomExternalTarget(web: WeiboLink.url(id));
    } on WeiboException {
      return null;
    }
  }

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

  String _id(LiveRoom liveroom) {
    final roomId = liveroom.roomId ?? '';
    final platform = liveroom.platform ?? '';
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
          liveStatus: LiveStatus.live,
          status: true,
          audienceMetricType: AudienceMetricType.unknown,
          watching: '',
          httpHeaders: WeiboApi.playHeaders,
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
      WeiboBroadcastState.offline => LiveStatus.offline,
      WeiboBroadcastState.replay => LiveStatus.replay,
      WeiboBroadcastState.unknown => LiveStatus.unknown,
    },
    restriction: WeiboApi.restrictionOf(detail),
    audienceMetricType: AudienceMetricType.unknown,
    watching: '',
    notice: [if (detail.access != WeiboAccess.public) i18n('weibo_restricted'), i18n('weibo_room_scope')].join('\n'),
    data: detail,
  );
  Future<LiveRoom> _resolveDetail(LiveRoom liveroom) async => _room(await _api.detail(_id(liveroom)));
  @override
  Future<LiveRoom> getRoomDetail(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return _resolveDetail(liveroom);
  }

  @override
  Future<LiveRoom> getRoomDetailForRecording(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return _resolveDetail(liveroom);
  }

  @override
  Future<LiveRoom> getRoomDetailForRefresh(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return _resolveDetail(liveroom);
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
    if (liveId != null) {
      try {
        return [_room(await _api.detail(liveId, cancel: cancel))];
      } on WeiboException catch (error) {
        if (error.kind == WeiboFailure.missing) return [];
        rethrow;
      }
    }
    final query = keyword.trim().toLowerCase();
    if (query.isEmpty) return [];
    // Only filter the current official recommendation snapshot. This is not
    // a broadcaster or full-site search and does not establish live status.
    final directory = await getDirectoryPage(cancel: cancel);
    return directory.rooms.where((room) => (room.nick ?? '').toLowerCase().contains(query)).take(pageSize).toList();
  }

  WeiboLiveDetail _detail(LiveRoom liveroom) {
    _id(liveroom);
    final detail = liveroom.data;
    if (detail is! WeiboLiveDetail || detail.liveId != liveroom.roomId || '${detail.ownerId}' != liveroom.userId) {
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
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom liveroom}) async {
    final data = _detail(liveroom);
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

  Future<LivePlayUrlResolution> _resolve(LiveRoom liveroom, LivePlayQuality quality) async {
    final data = _detail(liveroom);
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
  Future<LivePlayUrlResolution> resolvePlayUrlsRaw({required LiveRoom liveroom, required LivePlayQuality quality}) =>
      _resolve(liveroom, quality);
  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsForRecoveryRaw({
    required LiveRoom liveroom,
    required LivePlayQuality quality,
  }) => _resolve(liveroom, quality);
  @override
  Future<List<String>> getPlayUrls({required LiveRoom liveroom, required LivePlayQuality quality}) async =>
      (await _resolve(liveroom, quality)).urls;
}
