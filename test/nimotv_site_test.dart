import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/site/nimotv/nimotv_api.dart';
import 'package:pure_live/core/site/nimotv/nimotv_link.dart';
import 'package:pure_live/core/site/nimotv/nimotv_site.dart';
import 'package:pure_live/core/sites.dart';

void main() {
  test('official room links normalize numeric IDs and channel aliases', () {
    expect(NimoTvLink.parse('https://www.nimo.tv/live/40972312')?.storageKey, '40972312');
    expect(NimoTvLink.parse('https://m.nimo.tv/SBTCPotm')?.storageKey, 'sbtcpotm');
    expect(NimoTvLink.url('40972312'), 'https://www.nimo.tv/live/40972312');
    expect(NimoTvLink.url('SBTCPotm'), 'https://www.nimo.tv/sbtcpotm');
    for (final invalid in [
      'https://www.nimo.tv/search',
      'https://www.nimo.tv/game/123',
      'https://www.nimo.tv/live/40972312?from=share',
      'https://www.nimo.tv.evil.test/live/40972312',
      'https://user@www.nimo.tv/live/40972312',
    ]) {
      expect(NimoTvLink.parse(invalid), isNull, reason: invalid);
    }
  });

  test('exact channel search returns current identity without fabricating a catalog', () async {
    final transport = _FixtureTransport();
    final site = NimoTvSite(api: NimoTvApi(request: transport.call));
    final category = (await site.getCategores(1, 30)).single.children.single;
    expect(category.areaId, 'channel');
    expect((await site.getDirectoryPage(category: category)).rooms, isEmpty);
    final rooms = await site.searchRooms('https://www.nimo.tv/live/40972312');
    expect(rooms.single.roomId, '40972312');
    expect(rooms.single.nick, 'Fixture Host');
    expect(rooms.single.onlineViewers, '60');
    expect(rooms.single.audienceMetricType, AudienceMetricType.onlineViewers);
    expect(transport.roomCalls, 1);
  });

  test('room detail exposes five signed FLV qualities, recovery and lease timing', () async {
    final transport = _FixtureTransport();
    final site = NimoTvSite(api: NimoTvApi(request: transport.call));
    final detail = await site.getRoomDetail(roomId: '40972312', platform: Sites.nimoTvSite);
    expect(detail.effectiveLiveStatus, LiveStatus.live);
    expect(detail.httpHeaders['Referer'], 'https://www.nimo.tv/live/40972312');
    final qualities = await site.getPlayQualites(detail: detail);
    expect(qualities.map((quality) => quality.selectionId), ['flv:6000', 'flv:2500', 'flv:1000', 'flv:500', 'flv:250']);
    final first = await site.resolvePlayUrlsRaw(detail: detail, quality: qualities.first);
    final firstUri = Uri.parse(first.urls.single);
    expect(firstUri.scheme, 'https');
    expect(firstUri.host, 'al.flv.nimo.tv');
    expect(firstUri.path, '/live/fixture_stream.flv');
    expect(firstUri.queryParameters['ratio'], '6000');
    expect(firstUri.queryParameters['wsSecret'], 'secret1');

    final recovered = await site.resolvePlayUrlsForRecoveryRaw(detail: detail, quality: qualities.first);
    expect(Uri.parse(recovered.urls.single).queryParameters['wsSecret'], 'secret2');
    expect(transport.roomCalls, 2);

    const media = 'https://al.flv.nimo.tv/live/fixture.flv?wsTime=6b49d200';
    expect(NimoTvApi.mediaInvalidAt(media), DateTime.utc(2027, 1, 15, 7, 59, 50));
    expect(NimoTvApi.mediaRefreshAt(media), DateTime.utc(2027, 1, 15, 7, 54, 50));
  });

  test('offline rooms keep current audience unknown and have no media', () {
    final room = NimoTvApi.parseRoom(_roomHtml(generation: 1, live: false), resolveMedia: true);
    expect(room.state, NimoTvState.offline);
    expect(room.viewerCount, isNull);
    expect(room.qualities, isEmpty);
  });

  test('registry exposes one NimoTV adapter with recording recovery', () {
    expect(Sites.supportedSiteIds, contains(Sites.nimoTvSite));
    expect(Sites.of(Sites.nimoTvSite).liveSite, isA<NimoTvSite>());
    expect(Sites.supportSites.where((site) => site.id == Sites.nimoTvSite), hasLength(1));
  });
}

final class _FixtureTransport {
  int roomCalls = 0;

  Future<({int status, String body})> call(Uri uri, Map<String, String> headers, CancelToken cancel) async {
    if (uri.host == 'm.nimo.tv' && uri.path == '/live/40972312') {
      roomCalls++;
      return (status: 200, body: _roomHtml(generation: roomCalls));
    }
    throw StateError('Unexpected fixture request: $uri');
  }
}

String _roomHtml({required int generation, bool live = true}) {
  final payload =
      'http://al.hls.nimo.tv/live/V|id=fixture_stream|appid=81&tp=1700000000&wsSecret=secret$generation&wsTime=6b49d200';
  final package = payload.codeUnits.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  final room = <String, dynamic>{
    'roomId': 40972312,
    'anchorId': 1639528022670,
    'nickname': 'Fixture Host',
    'avatarUrl': 'https://img.nimo.tv/avatar/fixture.png',
    'title': 'Fixture Live',
    'game': 'Wild Rift',
    'viewerNum': 60,
    'liveStreamStatus': live ? 1 : 0,
    'roomScreenshots': [
      {'key': 2, 'url': 'http://img.nimo.tv/cover/fixture.jpg'},
    ],
    'mStreamPkg': live ? package : '',
  };
  return '<html><script>var G_roomBaseInfo = ${jsonEncode(room)};</script></html>';
}
