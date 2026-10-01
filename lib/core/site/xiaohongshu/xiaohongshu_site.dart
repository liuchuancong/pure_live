import 'package:dio/dio.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/utils/live_short_link_session.dart';
import 'package:pure_live/core/danmaku/empty_danmaku.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/interface/live_directory.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/plugins/locale_helper.dart';

import 'xiaohongshu_api.dart';
import 'xiaohongshu_link.dart';
import 'xiaohongshu_share.dart';

class XiaohongshuSite extends LiveSite
    implements
        LiveSiteDirectoryPager,
        LiveDirectoryNotice,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayUrlResolver,
        LivePlayRecoveryResolver {
  XiaohongshuSite({XiaohongshuApi? api, this.shortLinkClientFactory}) : _api = api ?? XiaohongshuApi();
  final XiaohongshuApi _api;
  final Dio Function()? shortLinkClientFactory;
  @override
  String get id => 'xiaohongshu';
  @override
  String get name => i18n('site_xiaohongshu');
  @override
  String get directoryNoticeKey => 'xiaohongshu_directory_scope';
  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  String _roomId(String roomId, String platform) {
    if (platform != id) throw const XiaohongshuException(XiaohongshuFailure.identity);
    return XiaohongshuShare.validateRoomId(roomId);
  }

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    if (cancel?.isCancelled == true) throw const XiaohongshuException(XiaohongshuFailure.cancelled);
    if (page < 1 || category != null) throw const XiaohongshuException(XiaohongshuFailure.schema);
    // No public directory has been established. Show a persistent explanation,
    // not a fixed seed or a recommendation borrowed from an ended broadcast.
    return LiveDirectoryPage(rooms: const [], page: page, hasMore: false);
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async =>
      (await getDirectoryPage(page: page)).rooms;

  LiveRoom _room(XiaohongshuShare share, {required bool includeMedia}) => LiveRoom(
    platform: id,
    roomId: share.requestedRoomId,
    // No persistent broadcaster ID contract yet: do not copy the room ID here.
    title: share.title,
    nick: share.nickname,
    avatar: share.avatar,
    cover: share.cover,
    link: XiaohongshuLink.url(share.requestedRoomId),
    liveStatus: switch (share.reportedLive) {
      true => LiveStatus.live,
      false => LiveStatus.offline,
      null => LiveStatus.unknown,
    },
    audienceMetricType: AudienceMetricType.unknown,
    // The legacy LiveRoom default is "0". No measured audience is available;
    // keep card/header counters empty instead of displaying a fabricated zero.
    watching: '',
    notice: [
      i18n('xiaohongshu_room_scope'),
      if (share.access != XiaohongshuAccess.public) i18n('xiaohongshu_restricted'),
      if (share.displayViewers?.isNotEmpty == true)
        i18n('xiaohongshu_display_viewers', args: {'value': share.displayViewers!}),
    ].join('\n'),
    data: includeMedia ? share : null,
  );

  Future<LiveRoom> _loadDetail(String roomId, String platform, {required bool includeMedia}) async =>
      _room(await _api.room(_roomId(roomId, platform)), includeMedia: includeMedia);

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    final identity = room.detailIdentity;
    if (identity == null) return room;
    return _loadDetail(identity.roomId, identity.platform, includeMedia: true);
  }

  @override
  Future<LiveRoom> getRoomDetailForRefresh(LiveRoom room) async {
    final identity = room.detailIdentity;
    if (identity == null) return room;
    return _loadDetail(identity.roomId, identity.platform, includeMedia: false);
  }

  @override
  Future<LiveRoom> getRoomDetailForRecording(LiveRoom room) async {
    final identity = room.detailIdentity;
    if (identity == null) return room;
    final detail = await _loadDetail(identity.roomId, identity.platform, includeMedia: true);
    if (!detail.isExplicitlyOfflineNow) _snapshot(detail);
    return detail;
  }

  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) async {
    if (page != 1) return [];
    const timeout = Duration(seconds: 12);
    final session = LiveShortLinkSession(timeout: timeout, clientFactory: shortLinkClientFactory);
    final String? roomId;
    try {
      roomId = await XiaohongshuLink.resolve(keyword, session: session).timeout(timeout, onTimeout: () => null);
    } finally {
      session.close();
    }
    if (roomId == null) return [];
    try {
      return [await getRoomDetailForRefresh(LiveRoom(roomId: roomId, platform: id))];
    } on XiaohongshuException catch (error) {
      if (error.kind == XiaohongshuFailure.missing) return [];
      rethrow;
    }
  }

  XiaohongshuShare _snapshot(LiveRoom detail) {
    final roomId = _roomId(detail.roomId ?? '', detail.platform ?? '');
    final data = detail.data;
    if (data is! XiaohongshuShare || data.requestedRoomId != roomId) {
      throw const XiaohongshuException(XiaohongshuFailure.identity);
    }
    if (data.reportedLive == false || detail.isExplicitlyOfflineNow) {
      throw const XiaohongshuException(XiaohongshuFailure.notLive);
    }
    if (data.reportedLive != true || !detail.isLiveNow) {
      throw const XiaohongshuException(XiaohongshuFailure.mediaUnavailable);
    }
    if (data.responseRoomId != roomId) throw const XiaohongshuException(XiaohongshuFailure.identity);
    if (data.access != XiaohongshuAccess.public) throw const XiaohongshuException(XiaohongshuFailure.access);
    if (data.streams.isEmpty) throw const XiaohongshuException(XiaohongshuFailure.mediaUnavailable);
    return data;
  }

  static String _qualityId(XiaohongshuStream stream) => '${stream.codec}:${stream.quality}';
  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    _roomId(detail.roomId ?? '', detail.platform ?? '');
    if (detail.isExplicitlyOfflineNow) return [];
    final data = _snapshot(detail);
    final qualities = <String, LivePlayQuality>{};
    for (final source in data.streams) {
      final key = _qualityId(source);
      qualities.putIfAbsent(
        key,
        () => LivePlayQuality(id: key, quality: '${source.label} · ${source.codec.toUpperCase()}'),
      );
    }
    return List.unmodifiable(qualities.values);
  }

  Future<LivePlayUrlResolution> _resolve(LiveRoom detail, LivePlayQuality quality, {required bool refresh}) async {
    var data = _snapshot(detail);
    if (refresh) {
      data = _snapshot(await getRoomDetail(LiveRoom(roomId: data.requestedRoomId, platform: id)));
    }
    final urls = data.streams
        .where((s) => _qualityId(s) == quality.selectionId.toString())
        .map((s) => s.uri.toString())
        .toList();
    if (urls.isEmpty) throw const XiaohongshuException(XiaohongshuFailure.mediaUnavailable);
    return LivePlayUrlResolution(urls: List.unmodifiable(urls), appliedQualityData: quality.selectionId);
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
      (await resolvePlayUrlsRaw(detail: detail, quality: quality)).urls;
}
