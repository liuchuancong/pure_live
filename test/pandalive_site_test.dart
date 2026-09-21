import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/site/pandalive/pandalive_api.dart';
import 'package:pure_live/core/site/pandalive/pandalive_link.dart';
import 'package:pure_live/core/site/pandalive/pandalive_site.dart';
import 'package:pure_live/core/sites.dart';

void main() {
  test('official live and channel links retain the channel identity', () {
    expect(PandaLiveLink.parse('https://www.pandalive.co.kr/live/play/fixture_101'), 'fixture_101');
    expect(PandaLiveLink.parse('https://www.pandalive.co.kr/channel/fixture_101'), 'fixture_101');
    expect(PandaLiveLink.parse('https://m.pandalive.co.kr/channel/fixture_101/home'), 'fixture_101');
    expect(PandaLiveLink.parseOrId('fixture_101'), 'fixture_101');
    expect(PandaLiveLink.url('fixture_101'), 'https://www.pandalive.co.kr/live/play/fixture_101');
    for (final invalid in [
      'https://www.pandalive.co.kr/live',
      'https://www.pandalive.co.kr/search/fixture_101',
      'https://www.pandalive.co.kr.evil.test/live/play/fixture_101',
      'https://www.pandalive.co.kr:444/live/play/fixture_101',
      'https://user@www.pandalive.co.kr/live/play/fixture_101',
    ]) {
      expect(PandaLiveLink.parse(invalid), isNull);
    }
  });

  test('directory preserves native paging and concurrent viewer semantics', () async {
    late Map<String, String> sent;
    final api = PandaLiveApi(
      request: (method, uri, form, referer, cancel) async {
        expect(method, 'POST');
        expect(uri.toString(), '${PandaLiveApi.apiOrigin}/v1/live/index');
        expect(referer, '${PandaLiveApi.origin}/live');
        sent = form!;
        return (
          status: 200,
          body: jsonEncode({
            'list': [_media()],
            'page': {'offset': 30, 'limit': 30, 'total': 61, 'page': 2, 'lastPage': 3},
            'result': true,
            'message': '',
          }),
        );
      },
    );
    final result = await api.directory(page: 2);
    expect(sent, containsPair('orderBy', 'hot'));
    expect(sent, containsPair('offset', '30'));
    expect(result.page, 2);
    expect(result.hasMore, isTrue);
    expect(result.rooms.single.onlineViewers, 127);
    expect(result.rooms.single.followers, 9371);
  });

  test('live room resolves the current AWS IVS master into stable qualities', () async {
    var playRequests = 0;
    var manifestRequests = 0;
    final api = PandaLiveApi(
      request: (method, uri, form, referer, cancel) async {
        if (uri.path == '/v1/member/bj') {
          return (status: 200, body: jsonEncode(_member(live: true)));
        }
        if (uri.path == '/v1/live/play') {
          playRequests++;
          expect(form, containsPair('action', 'watch'));
          expect(form, containsPair('userId', 'fixture_101'));
          return (status: 200, body: jsonEncode(_play()));
        }
        manifestRequests++;
        expect(method, 'GET');
        expect(referer, PandaLiveLink.url('fixture_101'));
        return (status: 200, body: _manifest);
      },
    );
    final room = await api.room('fixture_101');
    expect(room.state, PandaLiveState.live);
    expect(room.access, PandaLiveAccess.public);
    expect(room.onlineViewers, 127);
    expect(room.streams.map((stream) => stream.id), ['1080p60', '720p60', '480p30']);
    expect(room.streams.first.uri.host, 'fixture.playlist.live-video.net');

    final site = PandaLiveSite(api: api);
    final detail = await site.getRoomDetail(roomId: 'fixture_101', platform: Sites.pandaLiveSite);
    expect(detail.effectiveLiveStatus, LiveStatus.live);
    expect(detail.onlineViewers, '127');
    expect(detail.totalViewers, isNull);
    final qualities = await site.getPlayQualites(detail: detail);
    expect(qualities.map((quality) => quality.selectionId), ['1080p60', '720p60', '480p30']);
    final resolution = await site.resolvePlayUrlsRaw(detail: detail, quality: qualities[1]);
    expect(resolution.urls.single, contains('/720.m3u8'));
    await site.resolvePlayUrlsForRecoveryRaw(detail: detail, quality: qualities[1]);
    expect(playRequests, 3, reason: 'API room, detail, and recovery each obtain a new watch token');
    expect(manifestRequests, 3);
  });

  test('offline channel remains searchable without creating media', () async {
    final api = PandaLiveApi(
      request: (method, uri, form, referer, cancel) async {
        expect(uri.path, '/v1/member/bj');
        return (status: 200, body: jsonEncode(_member(live: false)));
      },
    );
    final site = PandaLiveSite(api: api);
    final results = await site.searchRooms('https://www.pandalive.co.kr/channel/fixture_101/home');
    expect(results.single.effectiveLiveStatus, LiveStatus.offline);
    expect(results.single.roomId, 'fixture_101');
    expect(await site.getPlayQualites(detail: results.single), isEmpty);
  });

  test('restricted watch response preserves live status and access reason', () async {
    final api = PandaLiveApi(
      request: (method, uri, form, referer, cancel) async {
        if (uri.path == '/v1/member/bj') return (status: 200, body: jsonEncode(_member(live: true)));
        return (
          status: 200,
          body: jsonEncode({
            'result': false,
            'message': 'verification required',
            'errorData': {'code': 'needAdult'},
          }),
        );
      },
    );
    final room = await api.room('fixture_101');
    expect(room.state, PandaLiveState.live);
    expect(room.access, PandaLiveAccess.adult);
    expect(room.streams, isEmpty);
    final detail = await PandaLiveSite(api: api).getRoomDetail(roomId: 'fixture_101', platform: 'pandalive');
    await expectLater(
      PandaLiveSite(api: api).getPlayQualites(detail: detail),
      _failure(PandaLiveFailure.mediaUnavailable),
    );
  });

  test('manifest parser rejects lookalike media hosts', () {
    final master = Uri.parse('https://fixture.playback.live-video.net/master.m3u8');
    expect(
      () => PandaLiveApi.parseManifest(
        master,
        '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1,RESOLUTION=1280x720\nhttps://live-video.net.evil.test/720.m3u8\n',
      ),
      _failure(PandaLiveFailure.schema),
    );
  });

  test('registry exposes one PandaTV adapter with recording support', () {
    expect(Sites.supportedSiteIds, contains(Sites.pandaLiveSite));
    expect(Sites.of(Sites.pandaLiveSite).liveSite, isA<PandaLiveSite>());
    expect(Sites.supportSites.where((site) => site.id == Sites.pandaLiveSite), hasLength(1));
  });

  test('caller cancellation is classified before transport', () async {
    final api = PandaLiveApi(request: (_, _, _, _, _) async => throw StateError('unused'));
    await expectLater(api.room('fixture_101', cancel: CancelToken()..cancel()), _failure(PandaLiveFailure.cancelled));
  });
}

Matcher _failure(PandaLiveFailure kind) =>
    throwsA(isA<PandaLiveException>().having((error) => error.kind, 'kind', kind));

Map<String, dynamic> _member({required bool live}) => {
  'fanGrade': [],
  if (live) 'media': _media(),
  'bjInfo': {
    'idx': 101,
    'id': 'fixture_101',
    'nick': 'Fixture owner',
    'thumbUrl': 'https://cdn.pandalive.co.kr/avatar.jpg',
    'channelTitle': 'Fixture channel',
    'channelDesc': 'Fixture introduction',
    'channelBannerUrl': 'https://cdn.pandalive.co.kr/banner.jpg',
    'fanCnt': 9371,
  },
  'result': true,
  'message': '',
};

Map<String, dynamic> _play() => {
  'media': _media(),
  'PlayList': {
    'hls3': [
      {'name': 'Auto', 'sort': 1, 'url': 'https://fixture.playback.live-video.net/master.m3u8?token=fixture'},
    ],
    'hls2': [],
    'hls': [],
  },
  'result': true,
  'message': 'started',
};

Map<String, dynamic> _media() => {
  'code': '101_fixture',
  'title': 'Fixture live',
  'userId': 'fixture_101',
  'userIdx': 101,
  'userNick': 'Fixture owner',
  'category': 'talk',
  'isAdult': false,
  'isPw': false,
  'user': 127,
  'isLive': true,
  'playCnt': 900,
  'fanCnt': 9371,
  'thumbUrl': 'https://cdn.pandalive.co.kr/cover.jpg',
  'userImg': 'https://cdn.pandalive.co.kr/avatar.jpg',
};

const _manifest = '''#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=8659202,RESOLUTION=1920x1080,FRAME-RATE=60.000
https://fixture.playlist.live-video.net/1080.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=3422999,RESOLUTION=1280x720,FRAME-RATE=60.000
https://fixture.playlist.live-video.net/720.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1427999,RESOLUTION=852x480,FRAME-RATE=30.000
https://fixture.playlist.live-video.net/480.m3u8
''';
