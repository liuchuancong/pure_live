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

import 'fc2_api.dart';
import 'fc2_input_recipe.dart';
import 'fc2_link.dart';
import 'fc2_live_danmaku.dart';

final class Fc2Site extends LiveSite
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
    return officialExternalRoom(() => Fc2Link.channelUrl(id));
  }

  Fc2Site({Fc2Api? api}) : _api = api ?? Fc2Api();

  final Fc2Api _api;
  Future<Fc2Directory>? _directoryRequest;
  DateTime? _directoryAt;

  @override
  String get id => 'fc2live';

  @override
  String get name => 'FC2 Live';

  @override
  String get directoryNoticeKey => 'fc2live_directory_scope';

  @override
  LiveDanmaku getDanmaku() => Fc2LiveDanmaku();

  Future<Fc2Directory> _directory({CancelToken? cancel}) {
    if (cancel != null) return _api.directory(cancel: cancel);
    final now = DateTime.now();
    final cached = _directoryRequest;
    if (cached != null && _directoryAt != null && now.difference(_directoryAt!) < const Duration(seconds: 20)) {
      return cached;
    }
    late final Future<Fc2Directory> request;
    request = _api
        .directory()
        .then((value) {
          _directoryAt = DateTime.now();
          return value;
        })
        .catchError((Object error) {
          if (identical(_directoryRequest, request)) {
            _directoryRequest = null;
            _directoryAt = null;
          }
          throw error;
        });
    return _directoryRequest = request;
  }

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    if (page != 1 || pageSize < 1) return [];
    LiveArea area(String value, String label) =>
        LiveArea(platform: id, areaType: 'public', areaId: value, areaName: label, typeName: name);
    return [
      LiveCategory(
        id: id,
        name: name,
        children: [
          area('all', i18n('fc2live_category_all')),
          area('1', i18n('fc2live_category_chat')),
          area('2', i18n('fc2live_category_game')),
          area('4', i18n('fc2live_category_video')),
          area('9', i18n('fc2live_category_audio')),
          area('5', i18n('fc2live_category_other')),
        ],
      ),
    ];
  }

  int? _category(LiveArea? category) {
    if (category == null) return null;
    if (category.platform != id || category.areaType != 'public') {
      throw const Fc2Exception(Fc2Failure.identity);
    }
    final areaId = category.areaId;
    if (areaId == 'all') return null;
    final value = areaId == null ? null : int.tryParse(areaId);
    if (!const {1, 2, 4, 5, 9}.contains(value)) throw const Fc2Exception(Fc2Failure.identity);
    return value;
  }

  static bool _matchesCategory(Fc2Room room, int? category) =>
      category == null || room.categoryId == category || (category == 2 && room.categoryId == 3);

  static List<T> _page<T>(List<T> values, int page, int pageSize) {
    if (page < 1 || pageSize < 1 || pageSize > 100) return [];
    final start = (page - 1) * pageSize;
    if (start >= values.length) return [];
    return values.sublist(start, (start + pageSize).clamp(0, values.length));
  }

  static LiveRoom _room(Fc2Room room, {required bool includeMedia}) {
    final live = room.state != Fc2State.offline;
    final liveStatus = live ? LiveStatus.live : LiveStatus.offline;
    final viewers = live ? room.currentViewers?.toString() : null;
    final totalViewers = live ? room.totalViewers?.toString() : null;
    return LiveRoom(
      platform: 'fc2live',
      roomId: room.channelId,
      userId: room.channelId,
      title: room.title,
      nick: room.userName,
      avatar: room.cover,
      cover: room.cover,
      area: room.categoryName,
      link: Fc2Link.channelUrl(room.channelId),
      liveStatus: liveStatus,
      restriction: live ? room.restriction : null,
      startedAt: live ? room.startedAt : null,
      watching: viewers ?? '',
      onlineViewers: viewers,
      totalViewers: totalViewers,
      audienceMetricType: viewers == null ? AudienceMetricType.unknown : AudienceMetricType.onlineViewers,
      notice: room.state == Fc2State.restricted
          ? i18n('fc2live_access_restricted')
          : room.isAdult
          ? i18n('fc2live_adult_notice')
          : i18n('fc2live_chat_notice'),
      httpHeaders: Fc2Api.mediaHeaders(room.channelId),
      danmakuData: liveStatus == LiveStatus.live ? Fc2LiveDanmakuArgs(channelId: room.channelId) : null,
      data: includeMedia && liveStatus == LiveStatus.live ? room : null,
    );
  }

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    if (page < 1) throw const Fc2Exception(Fc2Failure.schema);
    final categoryId = _category(category);
    final all = (await _directory(cancel: cancel)).rooms.where((room) => _matchesCategory(room, categoryId)).toList();
    const size = 20;
    return LiveDirectoryPage(
      rooms: _page(all, page, size).map((room) => _room(room, includeMedia: false)),
      page: page,
      hasMore: page * size < all.length,
    );
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async => _page(
    (await _directory()).rooms,
    page,
    pageSize,
  ).map((room) => _room(room, includeMedia: false)).toList(growable: false);

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    final categoryId = _category(category);
    final rooms = (await _directory()).rooms.where((room) => _matchesCategory(room, categoryId)).toList();
    return _page(rooms, page, pageSize).map((room) => _room(room, includeMedia: false)).toList(growable: false);
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
    final raw = keyword.trim();
    if (raw.isEmpty || page < 1 || pageSize < 1 || pageSize > 100) return [];
    final exactId = Fc2Link.parseChannelId(raw);
    if (exactId != null) {
      if (page != 1) return [];
      try {
        return [_room(await _api.room(exactId, cancel: cancel), includeMedia: false)];
      } on Fc2Exception catch (error) {
        if (error.kind == Fc2Failure.missing) return [];
        rethrow;
      }
    }
    final query = raw.toLowerCase();
    final matches = (await _directory(cancel: cancel)).rooms
        .where(
          (room) =>
              room.channelId.contains(query) ||
              room.userName.toLowerCase().contains(query) ||
              room.title.toLowerCase().contains(query) ||
              room.categoryName.toLowerCase().contains(query),
        )
        .toList();
    return _page(matches, page, pageSize).map((room) => _room(room, includeMedia: false)).toList(growable: false);
  }

  String _identity(LiveRoom liveroom) {
    final roomId = liveroom.roomId ?? '';
    final platform = liveroom.platform ?? '';
    if (platform.trim().toLowerCase() != id) throw const Fc2Exception(Fc2Failure.identity);
    final channelId = Fc2Link.parseChannelId(roomId);
    if (channelId == null) throw const Fc2Exception(Fc2Failure.identity);
    return channelId;
  }

  Future<LiveRoom> _detail(LiveRoom liveroom, {required bool includeMedia}) async =>
      _room(await _api.room(_identity(liveroom)), includeMedia: includeMedia);

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return _detail(liveroom, includeMedia: true);
  }

  @override
  Future<LiveRoom> getRoomDetailForRefresh(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return _detail(liveroom, includeMedia: false);
  }

  @override
  Future<LiveRoom> getRoomDetailForRecording(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return _detail(liveroom, includeMedia: true);
  }

  Fc2Room _snapshot(LiveRoom liveroom) {
    final channelId = _identity(liveroom);
    final room = liveroom.data;
    if (liveroom.effectiveLiveStatus != LiveStatus.live || room is! Fc2Room || room.channelId != channelId) {
      throw const Fc2Exception(Fc2Failure.schema);
    }
    return room;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom liveroom}) async {
    if (liveroom.isExplicitlyOfflineNow) return const [];
    _snapshot(liveroom);
    return [LivePlayQuality(id: 'auto', quality: i18n('fc2live_quality_auto'))];
  }

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsRaw({
    required LiveRoom liveroom,
    required LivePlayQuality quality,
  }) async {
    final room = _snapshot(liveroom);
    if (quality.selectionId != 'auto') throw const Fc2Exception(Fc2Failure.schema);
    return LivePlayUrlResolution.owned(input: Fc2InputRecipe(room.channelId), appliedQualityData: 'auto');
  }

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsForRecoveryRaw({
    required LiveRoom liveroom,
    required LivePlayQuality quality,
  }) => resolvePlayUrlsRaw(liveroom: liveroom, quality: quality);

  @override
  Future<List<String>> getPlayUrls({required LiveRoom liveroom, required LivePlayQuality quality}) async {
    await resolvePlayUrlsRaw(liveroom: liveroom, quality: quality);
    return const [];
  }
}
