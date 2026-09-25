import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/site/nimotv/nimotv_api.dart';
import 'package:pure_live/core/site/nimotv/nimotv_browser.dart';
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

  test('homepage directory exposes a finite snapshot and local keyword search', () async {
    final directory = _FixtureDirectory();
    final site = NimoTvSite(
      api: NimoTvApi(request: _FixtureTransport().call),
      directoryResolver: directory,
    );
    final category = (await site.getCategores(1, 30)).single.children.single;
    expect(category.areaId, 'homepage');
    expect(category.areaType, 'snapshot');
    final page = await site.getDirectoryPage(category: category);
    expect(page.hasMore, isFalse);
    expect(page.rooms.map((room) => room.roomId), ['40972312', '694735831']);
    expect(page.rooms.first.onlineViewers, '1900');
    expect(page.rooms.first.cover, page.rooms.first.avatar);
    expect(page.rooms.first.audienceMetricType, AudienceMetricType.onlineViewers);

    final searched = await site.searchRooms('fixture', pageSize: 1);
    expect(searched.single.roomId, '40972312');
    expect(directory.calls, 2);
  });

  test('exact channel search returns authoritative current identity', () async {
    final transport = _FixtureTransport();
    final site = NimoTvSite(
      api: NimoTvApi(request: transport.call),
      directoryResolver: _FixtureDirectory(),
    );
    final rooms = await site.searchRooms('https://www.nimo.tv/live/40972312');
    expect(rooms.single.roomId, '40972312');
    expect(rooms.single.nick, 'Fixture Host');
    expect(rooms.single.onlineViewers, '60');
    expect(rooms.single.audienceMetricType, AudienceMetricType.onlineViewers);
    expect(transport.roomCalls, 1);
  });

  test('room detail exposes the signed source FLV, recovery and lease timing', () async {
    final transport = _FixtureTransport();
    final site = NimoTvSite(
      api: NimoTvApi(request: transport.call),
      directoryResolver: _FixtureDirectory(),
    );
    final detail = await site.getRoomDetail(roomId: '40972312', platform: Sites.nimoTvSite);
    expect(detail.effectiveLiveStatus, LiveStatus.live);
    expect(detail.httpHeaders['Referer'], 'https://www.nimo.tv/live/40972312');
    final qualities = await site.getPlayQualites(detail: detail);
    expect(qualities.map((quality) => quality.selectionId), ['flv:source']);
    final first = await site.resolvePlayUrlsRaw(detail: detail, quality: qualities.first);
    final firstUri = Uri.parse(first.urls.single);
    // The CDN rejects https and any parameter added to its signed query.
    expect(firstUri.scheme, 'http');
    expect(firstUri.host, 'al.flv.nimo.tv');
    expect(firstUri.path, '/live/fixture_stream.flv');
    expect(firstUri.query, 'wsSecret=secret1&wsTime=6b49d200&fm=Zml4dHVyZQ%3D%3D&ctype=nimo_wap');

    final recovered = await site.resolvePlayUrlsForRecoveryRaw(detail: detail, quality: qualities.first);
    expect(Uri.parse(recovered.urls.single).queryParameters['wsSecret'], 'secret2');
    expect(transport.roomCalls, 2);

    const media = 'https://al.flv.nimo.tv/live/fixture.flv?wsTime=6b49d200';
    expect(NimoTvApi.mediaInvalidAt(media), DateTime.utc(2027, 1, 15, 7, 59, 50));
    expect(NimoTvApi.mediaRefreshAt(media), DateTime.utc(2027, 1, 15, 7, 54, 50));
  });

  test('stream packages with a length-prefixed id field still resolve media (2026-09 format)', () {
    for (final lengthPrefixedId in [false, true]) {
      final room = NimoTvApi.parseRoom(
        _roomHtml(generation: 1, lengthPrefixedId: lengthPrefixedId),
        resolveMedia: true,
      );
      final url = room.qualities.first.url;
      expect(url.path, '/live/fixture_stream.flv');
      expect(url.queryParameters['ctype'], 'nimo_wap'); // the trailing TARS head byte is not included
    }
  });

  test('offline rooms keep current audience unknown and have no media', () {
    final room = NimoTvApi.parseRoom(_roomHtml(generation: 1, live: false), resolveMedia: true);
    expect(room.state, NimoTvState.offline);
    expect(room.viewerCount, isNull);
    expect(room.qualities, isEmpty);
  });

  test('browser directory payload validates identity, audience and media hosts', () {
    final rooms = NimoTvBrowserDirectoryResolver.parseDirectoryPayload(
      jsonEncode([
        {
          'roomId': '40972312',
          'nickname': 'Fixture Host',
          'avatar': 'http://img.nimo.tv/avatar/fixture.png',
          'title': 'Fixture Live',
          'category': 'Wild Rift',
          'viewerCount': 1900,
        },
      ]),
    );
    expect(rooms.single.avatar, 'https://img.nimo.tv/avatar/fixture.png');
    expect(rooms.single.cover, rooms.single.avatar);
    expect(rooms.single.viewerCount, 1900);
    expect(rooms.single.state, NimoTvState.live);
    expect(
      () => NimoTvBrowserDirectoryResolver.parseDirectoryPayload(
        '[{"roomId":"1","nickname":"x","avatar":"https://evil.test/a.png","title":"x"}]',
      ),
      throwsA(isA<NimoTvException>()),
    );
    expect(NimoTvBrowserDirectoryResolver.buildDirectoryScript(), contains('home-hot-'));
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
    if (uri.host == 'm.nimo.tv') return (status: 404, body: '');
    throw StateError('Unexpected fixture request: $uri');
  }
}

final class _FixtureDirectory implements NimoTvDirectoryResolver {
  int calls = 0;

  @override
  Future<List<NimoTvRoom>> resolve() async {
    calls++;
    return [
      NimoTvRoom(
        roomId: '40972312',
        anchorId: '',
        nickname: 'Fixture Host',
        avatar: 'https://img.nimo.tv/avatar/fixture.png',
        cover: 'https://img.nimo.tv/avatar/fixture.png',
        title: 'Fixture Live',
        category: 'Wild Rift',
        viewerCount: 1900,
        state: NimoTvState.live,
        qualities: const [],
      ),
      NimoTvRoom(
        roomId: '694735831',
        anchorId: '',
        nickname: 'Second Host',
        avatar: '',
        cover: '',
        title: 'Second Live',
        category: 'PK',
        viewerCount: 569,
        state: NimoTvState.live,
        qualities: const [],
      ),
    ];
  }
}

String _roomHtml({required int generation, bool live = true, bool lengthPrefixedId = false}) {
  final idField = lengthPrefixedId ? '\\f3id=fixture_stream|\x86' : '|id=fixture_stream|';
  final query = 'wsSecret=secret$generation&wsTime=6b49d200&fm=Zml4dHVyZQ%3D%3D&ctype=nimo_wap';
  // Mirrors the TARS layout: a type-6 head byte and a one-byte length before
  // the signed query, then the next field's (printable) head byte `S`.
  final payload =
      'http://al.flv.nimo.tv/live/&http://al.hls.nimo.tv/live/V${idField}appid=81&tp=1700000000'
      'F${String.fromCharCode(query.length)}${query}S';
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
