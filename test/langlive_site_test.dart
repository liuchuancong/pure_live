import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/site/langlive/langlive_api.dart';
import 'package:pure_live/core/site/langlive/langlive_link.dart';
import 'package:pure_live/core/site/langlive/langlive_site.dart';

void main() {
  test('official main and room links keep an exact public identity', () {
    expect(LangLiveLink.parse('https://www.lang.live/main/5461380'), '5461380');
    expect(LangLiveLink.parse('https://lang.live/room/5461380?from=share'), '5461380');
    expect(LangLiveLink.parseOrId('5461380'), '5461380');
    expect(LangLiveLink.url('5461380'), 'https://www.lang.live/main/5461380');
    for (final invalid in [
      'https://webview.lang.live/main/5461380',
      'https://www.lang.live/main/5461380/more',
      'https://www.lang.live/profile/5461380',
      'https://www.lang.live.evil.test/main/5461380',
      'https://www.lang.live:444/main/5461380',
      'https://www.lang.live/main/0',
    ]) {
      expect(LangLiveLink.parse(invalid), isNull);
    }
  });

  test('web contract preserves identity, status and both media protocols', () {
    final room = LangLiveApi.parseRoom(_response(), requestedRoomId: '5461380');
    expect(room.roomId, '5461380');
    expect(room.nickname, 'Fixture anchor');
    expect(room.state, LangLiveState.live);
    expect(room.media.map((media) => media.kind), [LangLiveMediaKind.flv, LangLiveMediaKind.hls]);
    expect(room.media.first.uri.host, 'video-ws-aws.lv-play.com');
  });

  test('offline response never retains stale media', () {
    final json = _response(status: 0);
    final info = json['data']['live_info'] as Map<String, dynamic>;
    info['liveurl'] = 'https://video-ws-aws.lv-play.com/live/stale.flv';
    final room = LangLiveApi.parseRoom(json, requestedRoomId: '5461380');
    expect(room.state, LangLiveState.offline);
    expect(room.media, isEmpty);
  });

  test('identity, wrapper and media host mismatches fail closed', () {
    final wrongIdentity = _response();
    (wrongIdentity['data']['live_info'] as Map<String, dynamic>)['pretty_id'] = '6072112';
    expect(() => LangLiveApi.parseRoom(wrongIdentity, requestedRoomId: '5461380'), _failure(LangLiveFailure.identity));

    final badCode = _response();
    badCode['ret_code'] = 'bad';
    expect(() => LangLiveApi.parseRoom(badCode, requestedRoomId: '5461380'), _failure(LangLiveFailure.schema));

    final badMedia = _response();
    final info = badMedia['data']['live_info'] as Map<String, dynamic>;
    info['liveurl'] = 'https://video-ws-aws.lv-play.com.evil.test/live/a.flv';
    info['liveurl_hls'] = 'file:///tmp/a.m3u8';
    final room = LangLiveApi.parseRoom(badMedia, requestedRoomId: '5461380');
    expect(room.state, LangLiveState.live);
    expect(room.media, isEmpty);
  });

  test('fixed endpoint owns cancellation and maps transport status', () async {
    final requests = <Uri>[];
    final tokens = <CancelToken>[];
    final api = LangLiveApi(
      request: (uri, token) async {
        requests.add(uri);
        tokens.add(token);
        return (status: 200, body: jsonEncode(_response()));
      },
    );
    final caller = CancelToken();
    await api.room('5461380', cancel: caller);
    expect(requests.single.toString(), 'https://api.lang.live/langweb/v1/room/liveinfo?room_id=5461380');
    expect(tokens.single.isCancelled, isTrue);
    expect(caller.isCancelled, isFalse);

    for (final entry in {
      403: LangLiveFailure.access,
      404: LangLiveFailure.missing,
      429: LangLiveFailure.rateLimited,
      503: LangLiveFailure.service,
    }.entries) {
      final failing = LangLiveApi(request: (_, _) async => (status: entry.key, body: 'private'));
      await expectLater(failing.room('5461380'), _failure(entry.value));
    }
  });

  test('exact search, playback and recovery share the owned room snapshot', () async {
    final api = _FixtureApi(_room());
    final site = LangLiveSite(api: api);
    final searched = await site.searchRooms('https://www.lang.live/main/5461380');
    expect(searched.single.roomId, '5461380');
    expect(searched.single.effectiveLiveStatus, LiveStatus.live);
    expect(await site.searchRooms('Fixture anchor'), isEmpty);

    final detail = await site.getRoomDetail(roomId: '5461380', platform: 'langlive');
    final qualities = await site.getPlayQualites(detail: detail);
    expect(qualities.map((quality) => quality.selectionId), ['flv', 'hls']);
    expect((await site.resolvePlayUrlsRaw(detail: detail, quality: qualities.first)).urls.single, endsWith('.flv'));
    expect(
      (await site.resolvePlayUrlsForRecoveryRaw(detail: detail, quality: qualities.last)).urls.single,
      endsWith('.m3u8'),
    );
    expect(api.calls, 3);
  });

  test('live room with no accepted media is kept outside playback', () async {
    final site = LangLiveSite(api: _FixtureApi(_room(media: const [])));
    await expectLater(
      site.getRoomDetail(roomId: '5461380', platform: 'langlive'),
      _failure(LangLiveFailure.mediaUnavailable),
    );
  });
}

Map<String, dynamic> _response({int status = 1}) => {
  'ret_code': '0',
  'data': {
    'live_info': {
      'pretty_id': 5461380,
      'nickname': 'Fixture anchor',
      'live_status': status,
      'liveurl': 'https://video-ws-aws.lv-play.com/live/5461380_fixture.flv',
      'liveurl_hls': 'https://video-hls-aws.lv-play.com/live/5461380_fixture.m3u8',
    },
  },
};

LangLiveRoom _room({List<LangLiveMedia>? media}) => LangLiveRoom(
  roomId: '5461380',
  nickname: 'Fixture anchor',
  state: LangLiveState.live,
  media:
      media ??
      [
        LangLiveMedia(
          kind: LangLiveMediaKind.flv,
          uri: Uri.parse('https://video-ws-aws.lv-play.com/live/5461380_fixture.flv'),
        ),
        LangLiveMedia(
          kind: LangLiveMediaKind.hls,
          uri: Uri.parse('https://video-hls-aws.lv-play.com/live/5461380_fixture.m3u8'),
        ),
      ],
);

final class _FixtureApi extends LangLiveApi {
  _FixtureApi(this.fixture) : super(request: (_, _) async => throw StateError('unused'));

  final LangLiveRoom fixture;
  int calls = 0;

  @override
  Future<LangLiveRoom> room(String rawRoomId, {CancelToken? cancel}) async {
    calls++;
    if (rawRoomId != fixture.roomId) throw const LangLiveException(LangLiveFailure.missing);
    return fixture;
  }
}

Matcher _failure(LangLiveFailure kind) => throwsA(isA<LangLiveException>().having((error) => error.kind, 'kind', kind));
