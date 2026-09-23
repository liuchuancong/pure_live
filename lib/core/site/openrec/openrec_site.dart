import 'dart:async';

import 'package:dio/dio.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/common/request_scope.dart';
import 'package:pure_live/core/danmaku/empty_danmaku.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/interface/live_directory.dart';
import 'package:pure_live/core/interface/live_search.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/plugins/locale_helper.dart';

import 'openrec_api.dart';
import 'openrec_hls.dart';
import 'openrec_link.dart';

class _Playback {
  _Playback(this.roomKey, Iterable<LivePlayQuality> qualities) : qualities = List.unmodifiable(qualities);
  final String roomKey;
  final List<LivePlayQuality> qualities;
}

class OpenrecSite extends LiveSite
    implements
        LiveSiteDirectoryPager,
        LiveDirectoryNotice,
        LiveSiteRoomRefresher,
        LiveSiteRecordRoomResolver,
        LivePlayRecoveryResolver,
        LiveCancellableSearch {
  OpenrecSite({OpenrecApi? api}) : _api = api ?? OpenrecApi();
  final OpenrecApi _api;
  @override
  String get id => 'openrec';
  @override
  String get name => 'mellow-fan (OPENREC)';
  @override
  String get directoryNoticeKey => 'openrec_directory_scope';
  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  static LiveRoom _card(OpenrecMovie movie) {
    final key = OpenrecRoomKey.create(movie.channelId, movie.numericChannelId);
    return LiveRoom(
      platform: 'openrec',
      roomId: key.value,
      userId: '${key.numericId}',
      nick: movie.name,
      title: movie.title,
      avatar: movie.avatar,
      cover: movie.cover,
      link: key.url,
      watching: '',
      liveStatus: movie.isLive ? LiveStatus.live : LiveStatus.unknown,
      onlineViewers: movie.viewers?.toString(),
      audienceMetricType: AudienceMetricType.onlineViewers,
      notice: movie.publicMediaAllowed ? null : i18n('openrec_restricted'),
    );
  }

  LiveRoom _owner(OpenrecChannel owner) {
    final key = OpenrecRoomKey.create(owner.id, owner.numericId);
    return LiveRoom(
      platform: id,
      roomId: key.value,
      userId: '${key.numericId}',
      nick: owner.name,
      title: owner.name,
      avatar: owner.avatar,
      cover: owner.avatar,
      link: key.url,
      watching: '',
      audienceMetricType: AudienceMetricType.unknown,
      status: owner.isLive,
      liveStatus: owner.isLive ? LiveStatus.live : LiveStatus.offline,
      notice: owner.movieIds.length > 1 ? i18n('openrec_multiple_broadcasts') : null,
    );
  }

  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    if (category != null &&
        (category.platform != id || category.areaType != 'directory' || category.areaId != 'live')) {
      throw const OpenrecException(OpenrecFailure.schema);
    }
    final result = await _api.directory(page: page, cancel: cancel);
    final rooms = <String, LiveRoom>{};
    for (final movie in result.movies) {
      final previous = rooms[movie.channelId];
      if (previous == null) {
        rooms[movie.channelId] = _card(movie);
      } else {
        if (previous.userId != '${movie.numericChannelId}') {
          throw const OpenrecException(OpenrecFailure.identity);
        }
        // A channel card does not select the first of simultaneous broadcasts
        // or add overlapping audiences. Playback still requires one broadcast.
        previous
          ..title = previous.nick
          ..cover = previous.avatar
          ..onlineViewers = null
          ..notice = i18n('openrec_multiple_broadcasts');
      }
    }
    return LiveDirectoryPage(page: page, hasMore: result.hasMore, rooms: rooms.values);
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async =>
      (await getDirectoryPage(page: page)).rooms;
  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async =>
      (await getDirectoryPage(page: page, category: category)).rooms;
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
                areaId: 'live',
                areaName: i18n('openrec_public_directory'),
                typeName: name,
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
    if (page < 1 || pageSize < 1) throw const OpenrecException(OpenrecFailure.schema);
    if (page > 1) return const [];
    final input = keyword.trim();
    final uri = Uri.tryParse(input);
    if (uri == null || uri.hasQuery || uri.hasFragment) return const [];
    final link = OpenrecLink.validId(input) ? OpenrecLink(OpenrecLinkKind.channel, input) : OpenrecLink.parse(input);
    if (link == null || link.kind != OpenrecLinkKind.channel) return const [];
    try {
      return [_owner(await _api.channel(link.id, cancel: cancel))];
    } on OpenrecException catch (error) {
      if (error.kind == OpenrecFailure.missing) return const [];
      rethrow;
    }
  }

  Future<LiveRoom> _detail(String roomId, String platform, {required bool playback}) async {
    if (platform != id) throw const OpenrecException(OpenrecFailure.identity);
    final key = OpenrecRoomKey.parse(roomId);
    final owner = await _api.channel(key.channelId, expectedNumericId: key.numericId);
    if (!owner.isLive) return _owner(owner);
    if (owner.movieIds.length != 1) {
      if (!playback) return _owner(owner);
      throw const OpenrecException(OpenrecFailure.ambiguous);
    }
    if (!playback) {
      final movie = await _api.movie(owner.movieIds.single);
      if (movie.channelId != key.channelId || movie.numericChannelId != key.numericId) {
        throw const OpenrecException(OpenrecFailure.identity);
      }
      if (!movie.isLive) throw const OpenrecException(OpenrecFailure.notLive);
      return _card(movie);
    }
    final broadcast = await _api.broadcast(
      owner.movieIds.single,
      expectedChannelId: key.channelId,
      expectedNumericId: key.numericId,
    );
    final loaded = await withRequestCancellation(null, (owned) async {
      Future<({List<OpenrecHlsQuality> qualities, OpenrecFailure? failure})> read(OpenrecMedia source) async {
        try {
          return (qualities: parseOpenrecHls(await _api.manifest(source.url, cancel: owned), source), failure: null);
        } on OpenrecException catch (error) {
          // One unavailable family must not discard another valid one. Schema
          // and identity failures remain fatal instead of hiding corrupt data.
          if (!{
            OpenrecFailure.access,
            OpenrecFailure.missing,
            OpenrecFailure.transport,
            OpenrecFailure.service,
            OpenrecFailure.rateLimited,
            OpenrecFailure.mediaUnavailable,
          }.contains(error.kind)) {
            rethrow;
          }
          return (qualities: <OpenrecHlsQuality>[], failure: error.kind);
        }
      }

      try {
        return await Future.wait(broadcast.media.map(read), eagerError: true).timeout(const Duration(seconds: 20));
      } on TimeoutException {
        throw const OpenrecException(OpenrecFailure.transport);
      }
    });
    final qualities = <LivePlayQuality>[];
    for (final result in loaded) {
      for (final item in result.qualities) {
        final suffix = switch (item.family) {
          'low-latency-hls' => ' · ${i18n('openrec_low_latency')}',
          'public-hls' => ' · ${i18n('openrec_public_source')}',
          _ => '',
        };
        qualities.add(
          LivePlayQuality(
            id: item.id,
            quality: '${item.label == 'HLS Auto' ? i18n('openrec_hls_auto') : item.label}$suffix',
            sort: item.rank,
            data: item.urls,
          ),
        );
      }
    }
    if (qualities.isEmpty) throw OpenrecException(loaded.first.failure ?? OpenrecFailure.mediaUnavailable);
    qualities.sort((a, b) {
      final rank = b.sort.compareTo(a.sort);
      return rank != 0 ? rank : a.selectionId.toString().compareTo(b.selectionId.toString());
    });
    final room = _card(broadcast.movie);
    room.data = _Playback(key.value, qualities);
    if (loaded.any((entry) => entry.failure != null)) room.notice = i18n('openrec_partial_sources');
    return room;
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
    if (detail.platform != id) throw const OpenrecException(OpenrecFailure.identity);
    OpenrecRoomKey.parse(detail.roomId ?? '');
    if (detail.isExplicitlyOfflineNow) return [];
    final data = detail.data;
    if (!detail.isLiveNow || data is! _Playback || data.roomKey != detail.roomId || data.qualities.isEmpty) {
      throw const OpenrecException(OpenrecFailure.mediaUnavailable);
    }
    return data.qualities;
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    for (final current in await getPlayQualites(detail: detail)) {
      if (current.selectionId == quality.selectionId) return List.unmodifiable(current.data as List<String>);
    }
    throw const OpenrecException(OpenrecFailure.mediaUnavailable);
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
