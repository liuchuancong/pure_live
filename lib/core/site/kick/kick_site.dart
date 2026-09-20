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

import 'kick_api.dart';
import 'kick_hls.dart';
import 'kick_link.dart';

class _KickPlayback {
  _KickPlayback(this.slug, Iterable<LivePlayQuality> qualities) : qualities = List.unmodifiable(qualities);
  final String slug;
  final List<LivePlayQuality> qualities;
}

class KickSite extends LiveSite
    implements
        LiveSiteDirectoryPager,
        LiveDirectoryNotice,
        LiveCancellableSearch,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayRecoveryResolver {
  KickSite({KickApi? api}) : _api = api ?? KickApi();

  final KickApi _api;

  @override
  String get id => 'kick';

  @override
  String get name => 'Kick';

  @override
  String get directoryNoticeKey => 'kick_directory_scope';

  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  static LiveRoom _channelCard(KickChannel channel) => LiveRoom(
    platform: 'kick',
    roomId: channel.slug,
    userId: channel.slug,
    nick: channel.name,
    title: channel.name,
    avatar: channel.avatar,
    cover: channel.avatar,
    followers: channel.followers?.toString(),
    introduction: channel.bio,
    link: KickLink.url(channel.slug),
    liveStatus: channel.isBanned
        ? LiveStatus.banned
        : channel.isLive
        ? LiveStatus.live
        : LiveStatus.offline,
  );

  static LiveRoom _liveCard(KickLive live) => LiveRoom(
    platform: 'kick',
    roomId: live.channel.slug,
    userId: live.channel.slug,
    nick: live.channel.name,
    title: live.title,
    avatar: live.channel.avatar,
    cover: live.cover,
    area: live.category,
    followers: live.channel.followers?.toString(),
    introduction: live.channel.bio,
    link: KickLink.url(live.channel.slug),
    liveStatus: LiveStatus.live,
    onlineViewers: live.viewers?.toString(),
    audienceMetricType: AudienceMetricType.onlineViewers,
    notice: live.mature ? i18n('kick_mature_notice') : null,
    httpHeaders: KickApi.mediaHeaders(live.channel.slug),
  );

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async => page == 1
      ? [
          LiveCategory(
            id: id,
            name: name,
            children: [
              LiveArea(
                platform: id,
                areaType: 'directory',
                areaId: 'public',
                areaName: i18n('kick_public_directory'),
                typeName: name,
              ),
            ],
          ),
        ]
      : [];

  void _category(LiveArea? category) {
    if (category != null &&
        (category.platform != id || category.areaType != 'directory' || category.areaId != 'public')) {
      throw const KickException(KickFailure.identity);
    }
  }

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    _category(category);
    final result = await _api.directory(page: page, cancel: cancel);
    final seen = <String>{};
    return LiveDirectoryPage(
      page: page,
      hasMore: result.hasMore,
      rooms: result.lives.where((live) => seen.add(live.channel.slug)).map(_liveCard),
    );
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async =>
      (await getDirectoryPage(page: page)).rooms;

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async =>
      (await getDirectoryPage(page: page, category: category)).rooms;

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
    final rooms = await _api.search(keyword, cancel: cancel);
    return rooms
        .take(pageSize.clamp(1, 30))
        .map((room) => room.live == null ? _channelCard(room.channel) : _liveCard(room.live!))
        .toList(growable: false);
  }

  Future<List<LivePlayQuality>> _qualities(KickLive live) async {
    final source = Uri.parse(live.playbackUrl);
    final variants = KickHls.parse(source, await _api.manifest(live.playbackUrl));
    final qualities =
        variants
            .map((variant) {
              final fps = variant.frameRate >= 50 ? '60' : '';
              final id = '${variant.height}p$fps';
              return LivePlayQuality(
                id: id,
                quality: '$id · HLS',
                sort: variant.height * 10000000 + variant.bandwidth,
                data: <String>[variant.uri.toString()],
              );
            })
            .toList(growable: false)
          ..sort((left, right) => right.sort.compareTo(left.sort));
    if (qualities.isEmpty) throw const KickException(KickFailure.mediaUnavailable);
    return qualities;
  }

  Future<LiveRoom> _detail(String roomId, String platform, {required bool playback}) async {
    if (platform.trim().toLowerCase() != id) throw const KickException(KickFailure.identity);
    final room = await _api.room(roomId);
    final live = room.live;
    if (live == null) return _channelCard(room.channel);
    final detail = _liveCard(live);
    if (playback) {
      final qualities = await _qualities(live);
      detail.data = _KickPlayback(room.channel.slug, qualities);
    }
    return detail;
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
    if (detail.platform != id) throw const KickException(KickFailure.identity);
    if (detail.isExplicitlyOfflineNow) return [];
    final data = detail.data;
    if (data is! _KickPlayback || data.slug != detail.roomId || data.qualities.isEmpty) {
      throw const KickException(KickFailure.mediaUnavailable);
    }
    return data.qualities;
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    for (final current in await getPlayQualites(detail: detail)) {
      if (current.selectionId == quality.selectionId) return List.unmodifiable(current.data as List<String>);
    }
    throw const KickException(KickFailure.mediaUnavailable);
  }

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsForRecoveryRaw({
    required LiveRoom detail,
    required LivePlayQuality quality,
  }) async {
    final fresh = await getRoomDetail(roomId: detail.roomId ?? '', platform: id);
    return LivePlayUrlResolution(
      urls: await getPlayUrls(detail: fresh, quality: quality),
      appliedQualityData: quality.selectionId,
    );
  }
}
