import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/site/zhanqi/zhanqi_api.dart';
import 'package:pure_live/core/site/zhanqi/zhanqi_link.dart';
import 'package:pure_live/core/site/zhanqi/zhanqi_media_api.dart';
import 'package:pure_live/core/site/zhanqi/zhanqi_player_layout.dart';
import 'package:pure_live/core/site/zhanqi/zhanqi_site.dart';

void main() {
  test('official links and exact room codes keep the public code identity', () {
    expect(ZhanqiLink.parse('https://www.zhanqi.tv/11524053'), '11524053');
    expect(ZhanqiLink.parse('https://m.zhanqi.tv/11524053?from=share'), '11524053');
    expect(ZhanqiLink.parseOrCode('11524053'), '11524053');
    expect(ZhanqiLink.url('11524053'), 'https://www.zhanqi.tv/11524053');
    for (final invalid in [
      'https://www.zhanqi.tv/lives',
      'https://www.zhanqi.tv/11524053/more',
      'https://www.zhanqi.tv.evil.test/11524053',
      'https://www.zhanqi.tv:444/11524053',
      'https://www.zhanqi.tv/0',
    ]) {
      expect(ZhanqiLink.parse(invalid), isNull);
    }
  });

  test('directory and exact search retain platform status and popularity semantics', () async {
    final site = ZhanqiSite(api: _FixtureApi(_room()), media: _FixtureMedia());
    final page = await site.getDirectoryPage();
    expect(page.rooms, hasLength(1));
    expect(page.hasMore, isFalse);
    expect(page.rooms.single.roomId, '11524053');
    expect(page.rooms.single.userId, '201');
    expect(page.rooms.single.effectiveLiveStatus, LiveStatus.live);
    expect(page.rooms.single.popularity, '9000');
    expect(page.rooms.single.onlineViewers, isEmpty);
    expect(page.rooms.single.audienceMetricType, AudienceMetricType.popularity);

    final searched = await site.searchRooms('https://www.zhanqi.tv/11524053');
    expect(searched.single.roomId, '11524053');
    expect(await site.searchRooms('fixture owner'), isEmpty);
  });

  test('detail exposes only byte-validated qualities and recovery reacquires them', () async {
    final api = _FixtureApi(_room());
    final media = _FixtureMedia();
    final site = ZhanqiSite(api: api, media: media);
    final detail = await site.getRoomDetail(roomId: '11524053', platform: 'zhanqi');
    final qualities = await site.getPlayQualites(detail: detail);
    expect(qualities.map((quality) => quality.selectionId), ['quality:0', 'quality:1']);
    expect(qualities.first.quality, contains('FLV'));
    expect(qualities.last.quality, contains('HLS'));

    final first = await site.resolvePlayUrlsRaw(detail: detail, quality: qualities.first);
    expect(first.appliedQualityData, 'quality:0');
    expect(first.urls, ['https://media.example/zqlive/101_fixture.flv?k=1']);
    final recovered = await site.resolvePlayUrlsForRecoveryRaw(detail: detail, quality: qualities.last);
    expect(recovered.urls, ['https://media.example/zqlive/101_fixture_360p/playlist.m3u8?k=2']);
    expect(api.roomCalls, 2);
    expect(media.resolveCalls, 2);
    expect(media.validateCalls, 2);
  });

  test('offline and unknown status do not open the media resolver', () async {
    final media = _FixtureMedia();
    final offline = ZhanqiSite(
      api: _FixtureApi(_room(status: '0', withLayout: false)),
      media: media,
    );
    final detail = await offline.getRoomDetail(roomId: '11524053', platform: 'zhanqi');
    expect(detail.effectiveLiveStatus, LiveStatus.offline);
    expect(await offline.getPlayQualites(detail: detail), isEmpty);
    expect(await offline.getLiveStatus(platform: 'zhanqi', roomId: '11524053'), isFalse);
    expect(media.resolveCalls, 0);

    final unknown = ZhanqiSite(
      api: _FixtureApi(_room(status: '7', withLayout: false)),
      media: media,
    );
    await expectLater(
      unknown.getLiveStatus(platform: 'zhanqi', roomId: '11524053'),
      _failure(ZhanqiFailure.unknownState),
    );
    expect(media.resolveCalls, 0);
  });

  test('live detail fails closed when no candidate passes byte validation', () async {
    final site = ZhanqiSite(api: _FixtureApi(_room()), media: _FixtureMedia(accepted: false));
    await expectLater(
      site.getRoomDetail(roomId: '11524053', platform: 'zhanqi'),
      _failure(ZhanqiFailure.mediaUnavailable),
    );
  });
}

ZhanqiRoomSnapshot _room({String status = '4', bool withLayout = true}) => ZhanqiRoomSnapshot(
  code: '11524053',
  roomId: '101',
  ownerId: '201',
  title: 'Fixture replay',
  nickname: 'Fixture owner',
  avatar: 'https://image.example/avatar.jpg',
  cover: 'https://image.example/cover.jpg',
  reportedStatus: status,
  reportedOnline: 9000,
  playerLayout: withLayout ? _layout() : null,
);

ZhanqiPlayerLayout _layout() {
  final encoded = base64.encode(
    utf8.encode(
      jsonEncode({
        'vid': '101_fixture',
        'ver': '3.0',
        'status': 4,
        'line': ['Line 1'],
        'rate': ['Original', 'Smooth'],
        'suffix': ['', '_360p'],
        'rateIndex': 0,
        'square': [
          [202, 43],
        ],
      }),
    ),
  );
  return ZhanqiPlayerLayout.parseEncoded(encoded, expectedRoomId: '101', expectedVideoId: '101_fixture');
}

final class _FixtureApi extends ZhanqiApi {
  _FixtureApi(this.snapshot) : super(request: (_, _) async => throw StateError('unused'));

  final ZhanqiRoomSnapshot snapshot;
  int roomCalls = 0;

  @override
  Future<ZhanqiDirectoryPage> directory({int page = 1, int pageSize = 20, CancelToken? cancel}) async =>
      ZhanqiDirectoryPage(page: page, pageSize: pageSize, reportedTotal: 1, rooms: [snapshot]);

  @override
  Future<ZhanqiRoomSnapshot> room({
    required String code,
    String? expectedRoomId,
    String? expectedOwnerId,
    CancelToken? cancel,
  }) async {
    roomCalls++;
    if (code != snapshot.code) throw const ZhanqiException(ZhanqiFailure.missing);
    return snapshot;
  }
}

final class _FixtureMedia extends ZhanqiMediaApi {
  _FixtureMedia({this.accepted = true})
    : super(
        transport: (_, _) async => throw StateError('unused'),
        probeTransport: (_, _, _) async => throw StateError('unused'),
      );

  final bool accepted;
  int resolveCalls = 0;
  int validateCalls = 0;

  late final flv = ZhanqiMediaSource(
    cdnKey: 202,
    suffix: '',
    lineIndices: const [0],
    qualityIndices: const [0],
    directUrl: Uri.parse('https://media.example/zqlive/101_fixture.flv?k=1'),
    routedUrls: const [],
    headers: ZhanqiApi.headers,
  );
  late final hls = ZhanqiMediaSource(
    cdnKey: 43,
    suffix: '_360p',
    lineIndices: const [0],
    qualityIndices: const [1],
    directUrl: Uri.parse('https://media.example/zqlive/101_fixture_360p/playlist.m3u8?k=2'),
    routedUrls: const [],
    headers: ZhanqiApi.headers,
  );

  @override
  Future<ZhanqiMediaResolution> resolve(ZhanqiRoomSnapshot room, {CancelToken? cancel}) async {
    resolveCalls++;
    return ZhanqiMediaResolution(
      roomId: room.roomId,
      videoId: room.playerLayout!.videoId,
      routeState: ZhanqiRouteState.notRequired,
      sources: [flv, hls],
    );
  }

  @override
  Future<List<ZhanqiValidatedMedia>> validate(
    ZhanqiMediaResolution resolution, {
    CancelToken? cancel,
    int maxCandidates = 12,
  }) async {
    validateCalls++;
    if (!accepted) throw const ZhanqiException(ZhanqiFailure.mediaUnavailable);
    return [
      ZhanqiValidatedMedia(source: flv, uri: flv.directUrl, kind: ZhanqiMediaKind.flv),
      ZhanqiValidatedMedia(source: hls, uri: hls.directUrl, kind: ZhanqiMediaKind.hls),
    ];
  }
}

Matcher _failure(ZhanqiFailure kind) => throwsA(isA<ZhanqiException>().having((error) => error.kind, 'kind', kind));
