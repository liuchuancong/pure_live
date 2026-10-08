import 'package:dio/dio.dart';
import 'package:pure_live/core/index.dart' show i18n;
import 'package:pure_live/core/models/live_area.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/shared/platforms/live_directory.dart';
import 'package:pure_live/shared/platforms/live_search.dart';
import 'package:pure_live/shared/platforms/live_site.dart';
import 'package:pure_live/core/models/live_category.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/shared/platforms/live_external_room.dart';

import 'kilakila_api.dart';
import 'kilakila_danmaku.dart';
import 'kilakila_link.dart';

/// App identities are anchor UIDs, never one-broadcast IDs or display numbers.
class KilakilaSite extends LiveSite
    implements
        LiveSiteDirectoryPager,
        LiveDirectoryNotice,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayRecoveryResolver,
        LiveCancellableSearch,
        LiveSearchPaginationPolicy,
        LiveSiteExternalRoomResolver {
  @override
  RoomExternalTarget? externalRoomTarget(LiveRoom liveroom) {
    final id = sanitizedExternalRoomId(liveroom.roomId);
    if (id == null) return null;
    if (!RegExp(r'^[1-9][0-9]{0,31}$').hasMatch(id)) return null;
    return RoomExternalTarget(web: KilakilaSite.ownerUrl(id));
  }

  KilakilaSite({KilakilaApi? api}) : _api = api ?? KilakilaApi();
  final KilakilaApi _api;
  @override
  String get id => 'kilakila';
  @override
  String get name => i18n('site_kilakila');
  @override
  String get directoryNoticeKey => 'kilakila_directory_scope';
  @override
  LiveDanmaku getDanmaku() => KilakilaDanmaku();

  static String ownerUrl(String uid) => '${KilakilaApi.ownerOrigin}/index/roomuser/uid/${KilakilaApi.id(uid)}';

  static LiveRoom _room(KilakilaRoomSnapshot snapshot) => LiveRoom(
    platform: 'kilakila',
    roomId: snapshot.userId,
    userId: snapshot.userId,
    title: snapshot.title,
    nick: snapshot.nick,
    cover: snapshot.cover,
    avatar: snapshot.avatar,
    link: ownerUrl(snapshot.userId),
    watching: '',
    audienceMetricType: AudienceMetricType.unknown,
    status: snapshot.isLive ? true : null,
    liveStatus: snapshot.isLive
        ? LiveStatus.live
        : snapshot.statusCode == 10
        ? LiveStatus.offline
        : LiveStatus.unknown,
    // watchNumber has no verified concurrent-viewer semantics. Broadcast IDs
    // and signed media remain ephemeral; favorites/backup retain only the UID.
    danmakuData: snapshot.isLive && snapshot.roomId.trim().isNotEmpty
        ? KilakilaDanmakuArgs(roomId: snapshot.roomId)
        : null,
    data: snapshot.media.isEmpty
        ? null
        : [
            for (final entry in snapshot.media.entries)
              LivePlayQuality(id: entry.key, quality: entry.key.toUpperCase(), data: <String>[entry.value]),
          ],
  );

  static LiveRoom _profileRoom(KilakilaOwnerSnapshot owner) => LiveRoom(
    platform: 'kilakila',
    roomId: owner.userId,
    userId: owner.userId,
    title: owner.nick,
    nick: owner.nick,
    avatar: owner.avatar,
    link: ownerUrl(owner.userId),
    watching: '',
    audienceMetricType: AudienceMetricType.unknown,
    status: false,
    liveStatus: LiveStatus.offline,
  );

  int _type(LiveArea? category) {
    if (category == null) return 0;
    if (category.platform != id || category.areaType != 'timeline' || !{'0', '107'}.contains(category.areaId)) {
      throw const KilakilaException(KilakilaFailure.schema);
    }
    return int.parse(category.areaId!);
  }

  Future<LiveDirectoryPage> _directory({
    required int page,
    required int pageSize,
    LiveArea? category,
    CancelToken? cancel,
  }) async {
    final result = await _api.directory(page: page, pageSize: pageSize, type: _type(category), cancel: cancel);
    final seen = <String>{};
    return LiveDirectoryPage(
      page: result.page,
      hasMore: result.hasMore,
      rooms: result.rooms.where((room) => seen.add(room.userId)).map(_room),
    );
  }

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) =>
      _directory(page: page, pageSize: 10, category: category, cancel: cancel);
  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async =>
      (await _directory(page: page, pageSize: pageSize)).rooms;
  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async =>
      (await _directory(page: page, pageSize: pageSize, category: category)).rooms;
  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async => page == 1
      ? [
          LiveCategory(
            id: id,
            name: name,
            children: [
              for (final entry in {'0': 'kilakila_hot', '107': 'kilakila_newcomers'}.entries)
                LiveArea(
                  platform: id,
                  areaType: 'timeline',
                  typeName: name,
                  areaId: entry.key,
                  areaName: i18n(entry.value),
                ),
            ],
          ),
        ]
      : [];

  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) =>
      searchRoomsCancellable(keyword, page: page, pageSize: pageSize);

  static KilakilaLink? _searchLink(String input) => RegExp(r'^[1-9][0-9]{0,31}$').hasMatch(input)
      ? KilakilaLink(KilakilaLinkKind.owner, input)
      : KilakilaLink.parse(input);

  @override
  bool supportsSearchPaginationFor(String keyword) {
    final input = keyword.trim();
    return input.isNotEmpty &&
        _searchLink(input) == null &&
        !RegExp(r'^[0-9]+$').hasMatch(input) &&
        Uri.tryParse(input)?.hasScheme != true;
  }

  @override
  Future<List<LiveRoom>> searchRoomsCancellable(
    String keyword, {
    int page = 1,
    int pageSize = 30,
    CancelToken? cancel,
  }) async {
    if (page < 1 || pageSize < 1) throw const KilakilaException(KilakilaFailure.schema);
    final input = keyword.trim();
    final link = _searchLink(input);
    if (link == null) {
      if (!supportsSearchPaginationFor(input)) return const [];
      return List.unmodifiable([
        for (final owner in await _api.searchOwners(input, page: page, pageSize: pageSize, cancel: cancel))
          _profileRoom(owner),
      ]);
    }
    if (link.kind != KilakilaLinkKind.owner || page > 1) return const [];
    try {
      final owner = await _api.owner(link.id, cancel: cancel);
      final current = owner.currentRoom;
      if (current != null) return [_room(current)];
      return [_profileRoom(owner)];
    } on KilakilaException catch (error) {
      if (error.kind == KilakilaFailure.notFound) return const [];
      rethrow;
    }
  }

  Future<LiveRoom> _detail(LiveRoom liveroom, {required bool playback}) async {
    final uid = liveroom.roomId ?? '';
    final platform = liveroom.platform ?? '';
    if (platform != id) throw const KilakilaException(KilakilaFailure.schema);
    final owner = await _api.owner(uid);
    final current = owner.currentRoom;
    if (current == null) {
      return LiveRoom(
        platform: id,
        roomId: owner.userId,
        userId: owner.userId,
        nick: owner.nick,
        avatar: owner.avatar,
        link: ownerUrl(owner.userId),
        watching: '',
        audienceMetricType: AudienceMetricType.unknown,
        status: false,
        liveStatus: LiveStatus.offline,
      );
    }
    if (!playback) return _room(current);
    final detail = await _api.detail(current.roomId, expectedUserId: owner.userId);
    return _room(detail);
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return _detail(liveroom, playback: true);
  }

  @override
  Future<LiveRoom> getRoomDetailForRecording(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return _detail(liveroom, playback: true);
  }

  @override
  Future<LiveRoom> getRoomDetailForRefresh(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    return _detail(liveroom, playback: false);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom liveroom}) async {
    if (liveroom.platform != id ||
        !liveroom.isLiveNow ||
        liveroom.data is! List<LivePlayQuality> ||
        (liveroom.data as List).isEmpty) {
      throw const KilakilaException(KilakilaFailure.mediaUnavailable);
    }
    return List.unmodifiable(liveroom.data as List<LivePlayQuality>);
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom liveroom, required LivePlayQuality quality}) async {
    for (final current in await getPlayQualites(liveroom: liveroom)) {
      if (current.selectionId == quality.selectionId) return List.unmodifiable(current.data as List<String>);
    }
    throw const KilakilaException(KilakilaFailure.mediaUnavailable);
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
