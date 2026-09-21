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

import 'shopeelive_api.dart';
import 'shopeelive_link.dart';

class ShopeeLiveSite extends LiveSite
    implements
        LiveSiteDirectoryPager,
        LiveDirectoryNotice,
        LiveCancellableSearch,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayUrlResolver,
        LivePlayRecoveryResolver,
        LivePlayLeaseMetadata {
  ShopeeLiveSite({ShopeeLiveApi? api}) : _api = api ?? ShopeeLiveApi();

  final ShopeeLiveApi _api;

  @override
  String get id => 'shopeelive';

  @override
  String get name => 'Shopee Live';

  @override
  String get directoryNoticeKey => 'shopeelive_directory_scope';

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
                areaType: 'feed',
                areaId: 'recommend',
                areaName: i18n('shopeelive_category_recommend'),
                typeName: name,
              ),
            ],
          ),
        ]
      : [];

  static String _displayName({required String nickname, required String username, required String shopId}) {
    if (nickname.isNotEmpty) return nickname;
    if (username.isNotEmpty) return username;
    return shopId.isEmpty ? 'Shopee Live' : 'Shopee #$shopId';
  }

  static LiveRoom _card(ShopeeLiveCard room) => LiveRoom(
    platform: 'shopeelive',
    roomId: room.storageKey,
    userId: room.userId,
    title: room.title,
    nick: _displayName(nickname: '', username: '', shopId: room.shopId),
    avatar: '',
    cover: room.cover,
    area: 'Shopee Live',
    link: ShopeeLiveLink.url(room.storageKey),
    liveStatus: LiveStatus.live,
    onlineViewers: room.viewerCount?.toString(),
    audienceMetricType: AudienceMetricType.onlineViewers,
    notice: i18n('shopeelive_chat_notice'),
    httpHeaders: ShopeeLiveApi.mediaHeaders(room.storageKey),
  );

  static LiveRoom _room(ShopeeLiveRoom room, {required bool includeMedia}) => LiveRoom(
    platform: 'shopeelive',
    roomId: room.storageKey,
    userId: room.userId,
    title: room.title,
    nick: _displayName(nickname: room.nickname, username: room.username, shopId: room.shopId),
    avatar: room.avatar,
    cover: room.cover,
    area: 'Shopee Live',
    link: ShopeeLiveLink.url(room.storageKey),
    liveStatus: switch (room.state) {
      ShopeeLiveState.live => LiveStatus.live,
      ShopeeLiveState.offline => LiveStatus.offline,
      ShopeeLiveState.unknown => LiveStatus.unknown,
    },
    onlineViewers: room.viewerCount?.toString(),
    audienceMetricType: AudienceMetricType.onlineViewers,
    notice: i18n('shopeelive_chat_notice'),
    httpHeaders: ShopeeLiveApi.mediaHeaders(room.storageKey),
    data: includeMedia ? room : null,
  );

  void _validateCategory(LiveArea? category) {
    if (category == null) return;
    if (category.platform != id || category.areaType != 'feed' || category.areaId != 'recommend') {
      throw const ShopeeLiveException(ShopeeLiveFailure.identity);
    }
  }

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    _validateCategory(category);
    if (page != 1) return LiveDirectoryPage(page: page, hasMore: false, rooms: const []);
    final result = await _api.directory(cancel: cancel);
    final seen = <String>{};
    return LiveDirectoryPage(
      page: 1,
      hasMore: false,
      rooms: result.rooms.where((room) => seen.add(room.sessionId)).map(_card),
    );
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async =>
      (await getDirectoryPage(page: page)).rooms.take(pageSize).toList(growable: false);

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async =>
      (await getDirectoryPage(page: page, category: category)).rooms.take(pageSize).toList(growable: false);

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
    final raw = keyword.trim();
    final exact = ShopeeLiveLink.parse(raw) ?? ShopeeLiveLink.parseKey(raw);
    if (exact != null) {
      try {
        return [_room(await _api.session(exact.storageKey, cancel: cancel), includeMedia: false)];
      } on ShopeeLiveException catch (error) {
        if (error.kind == ShopeeLiveFailure.missing) return [];
        rethrow;
      }
    }
    if (raw.isEmpty || raw.length > 120) throw const ShopeeLiveException(ShopeeLiveFailure.schema);
    final needle = raw.toLowerCase();
    final directory = await _api.directory(cancel: cancel);
    return directory.rooms
        .where(
          (room) =>
              room.title.toLowerCase().contains(needle) ||
              room.sessionId.contains(needle) ||
              room.shopId.contains(needle) ||
              room.userId.contains(needle),
        )
        .take(pageSize)
        .map(_card)
        .toList(growable: false);
  }

  String _roomId(String roomId, String platform) {
    if (platform.trim().toLowerCase() != id) throw const ShopeeLiveException(ShopeeLiveFailure.identity);
    final key = ShopeeLiveLink.parseKey(roomId);
    if (key == null) throw const ShopeeLiveException(ShopeeLiveFailure.identity);
    return key.storageKey;
  }

  @override
  Future<LiveRoom> getRoomDetail({required String roomId, required String platform}) async =>
      _room(await _api.session(_roomId(roomId, platform)), includeMedia: true);

  @override
  Future<LiveRoom> getRoomDetailForRecording({required String roomId, required String platform}) =>
      getRoomDetail(roomId: roomId, platform: platform);

  @override
  Future<LiveRoom> getRoomDetailForRefresh({required String roomId, required String platform}) async =>
      _room(await _api.refresh(_roomId(roomId, platform)), includeMedia: false);

  @override
  Future<bool> getLiveStatus({required String platform, required String roomId}) async {
    final room = await getRoomDetailForRefresh(roomId: roomId, platform: platform);
    if (room.effectiveLiveStatus == LiveStatus.unknown) {
      throw const ShopeeLiveException(ShopeeLiveFailure.unknownState);
    }
    return room.isLiveNow;
  }

  ShopeeLiveRoom _snapshot(LiveRoom detail) {
    final expected = _roomId(detail.roomId ?? '', detail.platform ?? '');
    final data = detail.data;
    if (data is! ShopeeLiveRoom || data.storageKey != expected) {
      throw const ShopeeLiveException(ShopeeLiveFailure.identity);
    }
    return data;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    if (detail.isExplicitlyOfflineNow) return [];
    final room = _snapshot(detail);
    if (room.state != ShopeeLiveState.live || room.qualities.isEmpty) {
      throw const ShopeeLiveException(ShopeeLiveFailure.mediaUnavailable);
    }
    return List.unmodifiable(
      room.qualities.map((quality) => LivePlayQuality(id: quality.id, quality: quality.label, sort: quality.sort)),
    );
  }

  Future<LivePlayUrlResolution> _resolve(LiveRoom detail, LivePlayQuality quality, {required bool refresh}) async {
    var room = _snapshot(detail);
    if (refresh) room = await _api.session(room.storageKey);
    if (room.state != ShopeeLiveState.live) throw const ShopeeLiveException(ShopeeLiveFailure.mediaUnavailable);
    final selectionId = quality.selectionId.toString();
    for (final stream in room.qualities) {
      if (stream.id == selectionId) {
        return LivePlayUrlResolution(
          urls: stream.urls.map((uri) => uri.toString()).toList(growable: false),
          appliedQualityData: selectionId,
        );
      }
    }
    throw const ShopeeLiveException(ShopeeLiveFailure.mediaUnavailable);
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
  DateTime? getPlayUrlRefreshAt(String url, {DateTime? now}) => ShopeeLiveApi.mediaRefreshAt(url);

  @override
  DateTime? getPlayUrlInvalidAt(String url, {DateTime? now}) => ShopeeLiveApi.mediaInvalidAt(url);
}
