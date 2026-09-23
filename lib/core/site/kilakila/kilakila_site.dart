import 'package:dio/dio.dart';
import 'package:pure_live/common/index.dart' show i18n;
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/danmaku/empty_danmaku.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/interface/live_directory.dart';
import 'package:pure_live/core/interface/live_search.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/model/live_play_quality.dart';

import 'kilakila_api.dart';
import 'kilakila_link.dart';

/// App identities are anchor UIDs, never one-broadcast IDs or display numbers.
class KilakilaSite extends LiveSite
    implements
        LiveSiteDirectoryPager,
        LiveDirectoryNotice,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayRecoveryResolver,
        LiveCancellableSearch {
  KilakilaSite({KilakilaApi? api}) : _api = api ?? KilakilaApi();
  final KilakilaApi _api;
  @override
  String get id => 'kilakila';
  @override
  String get name => i18n('site_kilakila');
  @override
  String get directoryNoticeKey => 'kilakila_directory_scope';
  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

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
    liveStatus: snapshot.isLive ? LiveStatus.live : LiveStatus.unknown,
    // watchNumber has no verified concurrent-viewer semantics. Broadcast IDs
    // and signed media remain ephemeral; favorites/backup retain only the UID.
    data: snapshot.media.isEmpty
        ? null
        : [
            for (final entry in snapshot.media.entries)
              LivePlayQuality(id: entry.key, quality: entry.key.toUpperCase(), data: <String>[entry.value]),
          ],
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

  @override
  Future<List<LiveRoom>> searchRoomsCancellable(
    String keyword, {
    int page = 1,
    int pageSize = 30,
    CancelToken? cancel,
  }) async {
    if (page < 1 || pageSize < 1) throw const KilakilaException(KilakilaFailure.schema);
    if (page > 1) return const [];
    final input = keyword.trim();
    final link = RegExp(r'^[1-9][0-9]{0,31}$').hasMatch(input)
        ? KilakilaLink(KilakilaLinkKind.owner, input)
        : KilakilaLink.parse(input);
    if (link == null || link.kind != KilakilaLinkKind.owner) return const [];
    try {
      final owner = await _api.owner(link.id, cancel: cancel);
      final current = owner.currentRoom;
      if (current != null) return [_room(current)];
      return [
        LiveRoom(
          platform: id,
          roomId: owner.userId,
          userId: owner.userId,
          nick: owner.nick,
          avatar: owner.avatar,
          link: ownerUrl(owner.userId),
          watching: '',
          audienceMetricType: AudienceMetricType.unknown,
          status: null,
          liveStatus: LiveStatus.unknown,
        ),
      ];
    } on KilakilaException catch (error) {
      if (error.kind == KilakilaFailure.notFound) return const [];
      rethrow;
    }
  }

  Future<LiveRoom> _detail(String uid, String platform, {required bool playback}) async {
    if (platform != id) throw const KilakilaException(KilakilaFailure.schema);
    final owner = await _api.owner(uid);
    final current = owner.currentRoom;
    if (current == null) {
      // No advertised broadcast is not an authoritative offline declaration.
      return LiveRoom(
        platform: id,
        roomId: owner.userId,
        userId: owner.userId,
        nick: owner.nick,
        avatar: owner.avatar,
        link: ownerUrl(owner.userId),
        watching: '',
        audienceMetricType: AudienceMetricType.unknown,
        status: null,
        liveStatus: LiveStatus.unknown,
      );
    }
    if (!playback) return _room(current);
    final detail = await _api.detail(current.roomId, expectedUserId: owner.userId);
    return _room(detail);
  }

  @override
  Future<LiveRoom> getRoomDetail({required String roomId, required String platform}) =>
      _detail(roomId, platform, playback: true);
  @override
  Future<LiveRoom> getRoomDetailForRecording({required String roomId, required String platform}) =>
      _detail(roomId, platform, playback: true);
  @override
  Future<LiveRoom> getRoomDetailForRefresh({required String roomId, required String platform}) =>
      _detail(roomId, platform, playback: false);
  @override
  Future<bool> getLiveStatus({required String platform, required String roomId}) async =>
      (await getRoomDetailForRefresh(roomId: roomId, platform: platform)).isLiveNow;
  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    if (detail.platform != id ||
        !detail.isLiveNow ||
        detail.data is! List<LivePlayQuality> ||
        (detail.data as List).isEmpty) {
      throw const KilakilaException(KilakilaFailure.mediaUnavailable);
    }
    return List.unmodifiable(detail.data as List<LivePlayQuality>);
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    for (final current in await getPlayQualites(detail: detail)) {
      if (current.selectionId == quality.selectionId) return List.unmodifiable(current.data as List<String>);
    }
    throw const KilakilaException(KilakilaFailure.mediaUnavailable);
  }

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsForRecoveryRaw({
    required LiveRoom detail,
    required LivePlayQuality quality,
  }) async {
    final fresh = await getRoomDetail(roomId: detail.roomId ?? '', platform: detail.platform ?? '');
    return LivePlayUrlResolution(
      urls: await getPlayUrls(detail: fresh, quality: quality),
      appliedQualityData: quality.selectionId,
    );
  }
}
