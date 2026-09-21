import 'package:dio/dio.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/core/danmaku/empty_danmaku.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/interface/live_directory.dart';
import 'package:pure_live/core/interface/live_search.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/plugins/locale_helper.dart';

import 'taobao_live_api.dart';
import 'taobao_live_link.dart';

final class TaobaoLiveSite extends LiveSite
    implements
        LiveSiteDirectoryPager,
        LiveDirectoryNotice,
        LiveCancellableSearch,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayUrlResolver,
        LivePlayRecoveryResolver,
        LivePlayLeaseMetadata {
  TaobaoLiveSite({TaobaoLiveApi? api})
    : _api = api ?? TaobaoLiveApi(cookieProvider: () => SettingsService.to.cookieManager.taobaoCookie.value);

  final TaobaoLiveApi _api;

  @override
  String get id => 'taobaolive';

  @override
  String get name => i18n('site_taobaolive');

  @override
  String get directoryNoticeKey => 'taobaolive_directory_scope';

  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  TaobaoLiveIdentity _identity(String roomId, String platform) {
    if (platform.trim().toLowerCase() != id) {
      throw const TaobaoLiveException(TaobaoLiveFailure.identity);
    }
    final identity = TaobaoLiveLink.parseStorageKey(roomId);
    if (identity == null) throw const TaobaoLiveException(TaobaoLiveFailure.identity);
    return identity;
  }

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    if (cancel?.isCancelled == true) {
      throw const TaobaoLiveException(TaobaoLiveFailure.cancelled);
    }
    if (page < 1 || category != null) {
      throw const TaobaoLiveException(TaobaoLiveFailure.identity);
    }
    // The current public portal is a product landing page rather than a
    // consumer catalogue. Keep this empty instead of presenting a fixed room.
    return LiveDirectoryPage(rooms: const [], page: page, hasMore: false);
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    if (pageSize < 1) return const [];
    return (await getDirectoryPage(page: page)).rooms;
  }

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async => const [];

  static LiveRoom _room(TaobaoLiveRoom room, {required bool includeMedia}) {
    final total = room.totalViews?.toString();
    final notice = <String>[
      i18n('taobaolive_room_scope'),
      if (room.state == TaobaoLiveState.restricted) i18n('taobaolive_restricted_notice'),
      if (room.state == TaobaoLiveState.replay) i18n('taobaolive_replay_notice'),
      i18n('taobaolive_chat_notice'),
    ];
    return LiveRoom(
      platform: 'taobaolive',
      roomId: room.identity.storageKey,
      userId: room.creatorId,
      title: room.title,
      nick: room.nick,
      avatar: room.avatar.isEmpty ? room.cover : room.avatar,
      cover: room.cover,
      area: i18n('site_taobaolive'),
      link: TaobaoLiveLink.watchUrl(room.identity),
      liveStatus: switch (room.state) {
        TaobaoLiveState.live => LiveStatus.live,
        TaobaoLiveState.offline => LiveStatus.offline,
        TaobaoLiveState.replay => LiveStatus.replay,
        TaobaoLiveState.restricted || TaobaoLiveState.unknown => LiveStatus.unknown,
      },
      watching: total ?? '',
      totalViewers: total,
      followers: room.followers?.toString(),
      audienceMetricType: total == null ? AudienceMetricType.unknown : AudienceMetricType.totalViewers,
      notice: notice.join('\n'),
      httpHeaders: TaobaoLiveApi.mediaHeaders(room.identity),
      data: includeMedia ? room : null,
    );
  }

  Future<LiveRoom> _detail(TaobaoLiveIdentity identity, {required bool includeMedia, CancelToken? cancel}) async =>
      _room(
        await _api.room(identity, includeMedia: includeMedia, cancel: cancel),
        includeMedia: includeMedia,
      );

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
    if (page != 1 || pageSize < 1) return const [];
    final raw = keyword.trim();
    if (raw.isEmpty) return const [];
    try {
      final identity = await _api.resolveReference(raw, cancel: cancel);
      return [await _detail(identity, includeMedia: false, cancel: cancel)];
    } on TaobaoLiveException catch (error) {
      if (error.kind == TaobaoLiveFailure.missing || error.kind == TaobaoLiveFailure.identity) {
        return const [];
      }
      rethrow;
    }
  }

  @override
  Future<LiveRoom> getRoomDetail({required String roomId, required String platform}) =>
      _detail(_identity(roomId, platform), includeMedia: true);

  @override
  Future<LiveRoom> getRoomDetailForRecording({required String roomId, required String platform}) =>
      _detail(_identity(roomId, platform), includeMedia: true);

  @override
  Future<LiveRoom> getRoomDetailForRefresh({required String roomId, required String platform}) =>
      _detail(_identity(roomId, platform), includeMedia: false);

  @override
  Future<bool> getLiveStatus({required String platform, required String roomId}) async {
    final room = await getRoomDetailForRefresh(roomId: roomId, platform: platform);
    if (room.effectiveLiveStatus == LiveStatus.unknown) {
      throw const TaobaoLiveException(TaobaoLiveFailure.access);
    }
    return room.isLiveNow;
  }

  TaobaoLiveRoom _snapshot(LiveRoom detail) {
    final identity = _identity(detail.roomId ?? '', detail.platform ?? '');
    final room = detail.data;
    if (room is! TaobaoLiveRoom || room.identity != identity) {
      throw const TaobaoLiveException(TaobaoLiveFailure.identity);
    }
    if (room.state != TaobaoLiveState.live || room.variants.isEmpty) {
      throw const TaobaoLiveException(TaobaoLiveFailure.mediaUnavailable);
    }
    return room;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    _identity(detail.roomId ?? '', detail.platform ?? '');
    if (detail.isExplicitlyOfflineNow) return const [];
    final room = _snapshot(detail);
    return List.unmodifiable(
      room.variants.map(
        (variant) => LivePlayQuality(id: variant.id, quality: variant.label, sort: _qualitySort(variant.id)),
      ),
    );
  }

  static int _qualitySort(String id) => switch (id) {
    'ud' => 6,
    'hd' => 5,
    'md' => 4,
    'ld' => 3,
    'lld' => 2,
    'auto' => 1,
    _ => 0,
  };

  Future<LivePlayUrlResolution> _resolve(LiveRoom detail, LivePlayQuality quality, {required bool refresh}) async {
    var room = _snapshot(detail);
    if (refresh) {
      room = _snapshot(await _detail(room.identity, includeMedia: true));
    }
    final selectionId = quality.selectionId.toString();
    for (final variant in room.variants) {
      if (variant.id != selectionId) continue;
      final urls = [variant.hls, variant.flv].whereType<Uri>().map((uri) => uri.toString()).toList(growable: false);
      if (urls.isEmpty) throw const TaobaoLiveException(TaobaoLiveFailure.mediaUnavailable);
      return LivePlayUrlResolution(urls: urls, appliedQualityData: selectionId);
    }
    throw const TaobaoLiveException(TaobaoLiveFailure.mediaUnavailable);
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
  DateTime? getPlayUrlRefreshAt(String url, {DateTime? now}) => TaobaoLiveApi.mediaRefreshAt(url, now: now);

  @override
  DateTime? getPlayUrlInvalidAt(String url, {DateTime? now}) => TaobaoLiveApi.mediaInvalidAt(url);
}
