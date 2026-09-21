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

import 'zhanqi_api.dart';
import 'zhanqi_link.dart';
import 'zhanqi_media_api.dart';

final class _ZhanqiQualitySource {
  const _ZhanqiQualitySource({required this.id, required this.name, required this.sort, required this.urls});

  final String id;
  final String name;
  final int sort;
  final List<String> urls;
}

final class _ZhanqiPlayback {
  _ZhanqiPlayback({required this.code, required Iterable<_ZhanqiQualitySource> qualities})
    : qualities = List.unmodifiable(qualities);

  final String code;
  final List<_ZhanqiQualitySource> qualities;
}

/// Application adapter kept behind the registry gate until a production
/// candidate passes [ZhanqiMediaApi.validate]. It never publishes an unprobed
/// signed URL to playback or recording.
final class ZhanqiSite extends LiveSite
    implements
        LiveSiteDirectoryPager,
        LiveDirectoryNotice,
        LiveCancellableSearch,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayUrlResolver,
        LivePlayRecoveryResolver {
  ZhanqiSite({ZhanqiApi? api, ZhanqiMediaApi? media}) : _api = api ?? ZhanqiApi(), _media = media ?? ZhanqiMediaApi();

  final ZhanqiApi _api;
  final ZhanqiMediaApi _media;

  @override
  String get id => 'zhanqi';

  @override
  String get name => '战旗直播';

  @override
  String get directoryNoticeKey => 'zhanqi_directory_scope';

  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    if (page != 1 || pageSize < 1) return [];
    return [
      LiveCategory(
        id: id,
        name: name,
        children: [
          LiveArea(
            platform: id,
            areaType: 'directory',
            areaId: 'public',
            areaName: i18n('zhanqi_category_public'),
            typeName: name,
          ),
        ],
      ),
    ];
  }

  void _category(LiveArea? category) {
    if (category != null &&
        (category.platform != id || category.areaType != 'directory' || category.areaId != 'public')) {
      throw const ZhanqiException(ZhanqiFailure.identity);
    }
  }

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    _category(category);
    final directory = await _api.directory(page: page, cancel: cancel);
    return LiveDirectoryPage(rooms: directory.rooms.map((room) => _card(room)), page: page, hasMore: directory.hasMore);
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    if (pageSize < 1 || pageSize > 100) return [];
    final directory = await _api.directory(page: page, pageSize: pageSize);
    return directory.rooms.map((room) => _card(room)).toList(growable: false);
  }

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    _category(category);
    return getRecommendRooms(page: page, pageSize: pageSize);
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
    if (page != 1 || pageSize < 1) return [];
    final code = ZhanqiLink.parseOrCode(keyword);
    if (code == null) return [];
    try {
      return [_card(await _api.room(code: code, cancel: cancel))];
    } on ZhanqiException catch (error) {
      if (error.kind == ZhanqiFailure.missing) return [];
      rethrow;
    }
  }

  static LiveStatus _status(ZhanqiRoomSnapshot room) => switch (room.reportedLive) {
    true => LiveStatus.live,
    false => LiveStatus.offline,
    null => LiveStatus.unknown,
  };

  LiveRoom _card(ZhanqiRoomSnapshot room, {_ZhanqiPlayback? playback}) {
    final popularity = room.reportedOnline?.toString();
    return LiveRoom(
      platform: id,
      roomId: room.code,
      userId: room.ownerId,
      title: room.title,
      nick: room.nickname ?? '',
      avatar: room.avatar ?? '',
      cover: room.cover ?? '',
      area: name,
      link: ZhanqiLink.url(room.code),
      liveStatus: _status(room),
      watching: popularity ?? '',
      popularity: popularity,
      audienceMetricType: AudienceMetricType.popularity,
      notice: i18n('zhanqi_chat_notice'),
      httpHeaders: ZhanqiApi.headers,
      data: playback,
    );
  }

  String _code(String roomId, String platform) {
    if (platform.trim().toLowerCase() != id) throw const ZhanqiException(ZhanqiFailure.identity);
    final code = ZhanqiLink.normalizeCode(roomId);
    if (code == null) throw const ZhanqiException(ZhanqiFailure.identity);
    return code;
  }

  Future<_ZhanqiPlayback> _playback(ZhanqiRoomSnapshot room, {CancelToken? cancel}) async {
    final layout = room.playerLayout;
    if (room.reportedLive != true || layout == null) throw const ZhanqiException(ZhanqiFailure.mediaUnavailable);
    final resolved = await _media.resolve(room, cancel: cancel);
    final validated = await _media.validate(resolved, cancel: cancel);
    final qualities = <_ZhanqiQualitySource>[];
    for (final qualityIndex in layout.enabledQualityIndices) {
      final media = validated.where((item) => item.source.qualityIndices.contains(qualityIndex)).toList();
      final urls = media.map((item) => item.uri.toString()).toSet().toList(growable: false);
      if (urls.isEmpty) continue;
      final protocols = media.map((item) => item.kind.name.toUpperCase()).toSet().join('/');
      final label = layout.qualityNames[qualityIndex];
      qualities.add(
        _ZhanqiQualitySource(
          id: 'quality:$qualityIndex',
          name: '$label · $protocols',
          sort: (layout.qualityNames.length - qualityIndex) * 1000,
          urls: urls,
        ),
      );
    }
    if (qualities.isEmpty) throw const ZhanqiException(ZhanqiFailure.mediaUnavailable);
    qualities.sort((left, right) => right.sort.compareTo(left.sort));
    return _ZhanqiPlayback(code: room.code, qualities: qualities);
  }

  Future<LiveRoom> _detail(String roomId, String platform, {required bool includeMedia}) async {
    final code = _code(roomId, platform);
    final room = await _api.room(code: code);
    final playback = includeMedia && room.reportedLive == true ? await _playback(room) : null;
    return _card(room, playback: playback);
  }

  @override
  Future<LiveRoom> getRoomDetail({required String roomId, required String platform}) =>
      _detail(roomId, platform, includeMedia: true);

  @override
  Future<LiveRoom> getRoomDetailForRecording({required String roomId, required String platform}) =>
      _detail(roomId, platform, includeMedia: true);

  @override
  Future<LiveRoom> getRoomDetailForRefresh({required String roomId, required String platform}) =>
      _detail(roomId, platform, includeMedia: false);

  @override
  Future<bool> getLiveStatus({required String platform, required String roomId}) async {
    final detail = await getRoomDetailForRefresh(roomId: roomId, platform: platform);
    if (detail.effectiveLiveStatus == LiveStatus.unknown) {
      throw const ZhanqiException(ZhanqiFailure.unknownState);
    }
    return detail.isLiveNow;
  }

  _ZhanqiPlayback _data(LiveRoom detail) {
    final code = _code(detail.roomId ?? '', detail.platform ?? '');
    final data = detail.data;
    if (data is! _ZhanqiPlayback || data.code != code || data.qualities.isEmpty) {
      throw const ZhanqiException(ZhanqiFailure.mediaUnavailable);
    }
    return data;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    if (detail.isExplicitlyOfflineNow) return [];
    final data = _data(detail);
    return List.unmodifiable(
      data.qualities.map((quality) => LivePlayQuality(id: quality.id, quality: quality.name, sort: quality.sort)),
    );
  }

  Future<LivePlayUrlResolution> _resolve(LiveRoom detail, LivePlayQuality quality, {required bool refresh}) async {
    var data = _data(detail);
    if (refresh) {
      final current = await getRoomDetail(roomId: detail.roomId ?? '', platform: id);
      data = _data(current);
    }
    final selectionId = quality.selectionId.toString();
    for (final candidate in data.qualities) {
      if (candidate.id == selectionId) {
        return LivePlayUrlResolution(urls: candidate.urls, appliedQualityData: selectionId);
      }
    }
    throw const ZhanqiException(ZhanqiFailure.mediaUnavailable);
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
}
