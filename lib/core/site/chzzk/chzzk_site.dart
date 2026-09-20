import 'dart:async';

import 'package:dio/dio.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/common/hls_master_selection.dart';
import 'package:pure_live/core/common/request_scope.dart';
import 'package:pure_live/core/danmaku/empty_danmaku.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/interface/live_directory.dart';
import 'package:pure_live/core/interface/live_search.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/plugins/locale_helper.dart';

import 'chzzk_api.dart';
import 'chzzk_link.dart';

class _ChzzkPlayback {
  _ChzzkPlayback(this.channelId, Iterable<LivePlayQuality> qualities) : qualities = List.unmodifiable(qualities);

  final String channelId;
  final List<LivePlayQuality> qualities;
}

class _QualityBuilder {
  _QualityBuilder({required this.id, required this.label, required this.rank});

  final String id;
  final String label;
  final int rank;
  final List<String> urls = [];
}

class ChzzkSite extends LiveSite
    implements
        LiveSiteCursorDirectoryPager,
        LiveDirectoryNotice,
        LiveCancellableSearch,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayRecoveryResolver {
  ChzzkSite({ChzzkApi? api}) : _api = api ?? ChzzkApi();

  final ChzzkApi _api;

  @override
  String get id => 'chzzk';

  @override
  String get name => 'CHZZK';

  @override
  String get directoryNoticeKey => 'chzzk_directory_scope';

  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  static LiveRoom _liveCard(ChzzkLive live) => LiveRoom(
    platform: 'chzzk',
    roomId: live.channel.id,
    userId: live.channel.id,
    nick: live.channel.name,
    title: live.title,
    avatar: live.channel.avatar,
    cover: live.cover,
    area: live.category,
    link: ChzzkLink.url(live.channel.id),
    liveStatus: LiveStatus.live,
    onlineViewers: live.concurrentViewers?.toString(),
    audienceMetricType: AudienceMetricType.onlineViewers,
    notice: live.adult ? i18n('chzzk_adult_notice') : null,
    httpHeaders: ChzzkApi.mediaHeaders,
  );

  static LiveRoom _channelCard(ChzzkChannel channel) => LiveRoom(
    platform: 'chzzk',
    roomId: channel.id,
    userId: channel.id,
    nick: channel.name,
    title: channel.name,
    avatar: channel.avatar,
    cover: channel.avatar,
    followers: channel.followers?.toString(),
    introduction: channel.description,
    link: ChzzkLink.url(channel.id),
    liveStatus: channel.isLive ? LiveStatus.live : LiveStatus.offline,
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
                areaId: 'popular',
                areaName: i18n('chzzk_public_directory'),
                typeName: name,
              ),
            ],
          ),
        ]
      : [];

  void _validateCategory(LiveArea? category) {
    if (category != null &&
        (category.platform != id || category.areaType != 'directory' || category.areaId != 'popular')) {
      throw const ChzzkException(ChzzkFailure.identity);
    }
  }

  @override
  Future<LiveDirectoryPage> getDirectoryPageAtCursor({
    required int page,
    String? cursor,
    LiveArea? category,
    CancelToken? cancel,
  }) async {
    if (page < 1 || (page == 1 && cursor != null) || (page > 1 && cursor == null)) {
      throw const ChzzkException(ChzzkFailure.schema);
    }
    _validateCategory(category);
    final result = await _api.directory(cursor: cursor, cancel: cancel);
    final seen = <String>{};
    return LiveDirectoryPage(
      page: page,
      nextCursor: result.nextCursor,
      hasMore: result.hasMore,
      rooms: result.lives.where((live) => seen.add(live.channel.id)).map(_liveCard),
    );
  }

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    if (page < 1 || page > 20) throw const ChzzkException(ChzzkFailure.schema);
    _validateCategory(category);
    return withRequestCancellation(cancel, (owned) async {
      Future<LiveDirectoryPage> replay() async {
        String? cursor;
        for (var current = 1; current <= page; current++) {
          final result = await getDirectoryPageAtCursor(
            page: current,
            cursor: cursor,
            category: category,
            cancel: owned,
          );
          if (current == page) return result;
          if (!result.hasMore) return LiveDirectoryPage(page: page, hasMore: false, rooms: const []);
          cursor = result.nextCursor;
        }
        throw const ChzzkException(ChzzkFailure.schema);
      }

      try {
        return await replay().timeout(const Duration(seconds: 20));
      } on TimeoutException {
        throw const ChzzkException(ChzzkFailure.transport);
      }
    });
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
    if (page < 1 || pageSize < 1 || pageSize > 30) return [];
    final channels = await _api.searchChannels(keyword, offset: (page - 1) * pageSize, size: pageSize, cancel: cancel);
    return channels.map(_channelCard).toList(growable: false);
  }

  Future<List<LivePlayQuality>> _qualities(ChzzkLive live) async {
    final builders = <String, _QualityBuilder>{};
    for (final media in live.media) {
      late final HlsMasterPlaylist master;
      try {
        master = HlsMasterPlaylist.parse(Uri.parse(media.url), await _api.manifest(media.url));
      } on FormatException {
        throw const ChzzkException(ChzzkFailure.schema);
      }
      for (final variant in master.variants) {
        final resolution = variant.attributes['RESOLUTION'] ?? '';
        final height = int.tryParse(resolution.split('x').last) ?? 0;
        final fps = double.tryParse(variant.attributes['FRAME-RATE'] ?? '') ?? 0;
        final bandwidth = int.tryParse(variant.attributes['BANDWIDTH'] ?? '') ?? 0;
        if (height <= 0 || bandwidth <= 0) throw const ChzzkException(ChzzkFailure.schema);
        final fpsLabel = fps >= 50 ? '60' : '';
        final key = '${height}p$fpsLabel';
        final builder = builders.putIfAbsent(
          key,
          () => _QualityBuilder(id: key, label: '$key · HLS', rank: height * 10000000 + bandwidth),
        );
        if (!builder.urls.contains(variant.uri.toString())) builder.urls.add(variant.uri.toString());
      }
    }
    final qualities =
        builders.values
            .where((builder) => builder.urls.isNotEmpty)
            .map(
              (builder) => LivePlayQuality(
                id: builder.id,
                quality: builder.label,
                sort: builder.rank,
                data: List<String>.unmodifiable(builder.urls),
              ),
            )
            .toList(growable: false)
          ..sort((left, right) => right.sort.compareTo(left.sort));
    if (qualities.isEmpty) throw const ChzzkException(ChzzkFailure.mediaUnavailable);
    return qualities;
  }

  Future<LiveRoom> _detail(String channelId, String platform, {required bool playback}) async {
    if (platform.trim().toLowerCase() != id) throw const ChzzkException(ChzzkFailure.identity);
    final room = await _api.room(channelId);
    final live = room.live;
    if (live == null || !live.isLive) return _channelCard(room.channel);
    final qualities = playback && live.media.isNotEmpty ? await _qualities(live) : <LivePlayQuality>[];
    final detail = _liveCard(live)
      ..followers = room.channel.followers?.toString()
      ..introduction = room.channel.description;
    if (live.regionRestricted) {
      detail.notice = i18n('chzzk_region_notice');
    } else if (live.adult && live.media.isEmpty) {
      detail.notice = i18n('chzzk_adult_notice');
    } else if (live.timeMachineActive) {
      detail.notice = i18n('chzzk_time_machine_notice');
    }
    if (qualities.isNotEmpty) detail.data = _ChzzkPlayback(room.channel.id, qualities);
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
    if (detail.platform != id) throw const ChzzkException(ChzzkFailure.identity);
    if (detail.isExplicitlyOfflineNow) return [];
    final data = detail.data;
    if (data is! _ChzzkPlayback || data.channelId != detail.roomId || data.qualities.isEmpty) {
      throw const ChzzkException(ChzzkFailure.mediaUnavailable);
    }
    return data.qualities;
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    for (final current in await getPlayQualites(detail: detail)) {
      if (current.selectionId == quality.selectionId) return List.unmodifiable(current.data as List<String>);
    }
    throw const ChzzkException(ChzzkFailure.mediaUnavailable);
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
