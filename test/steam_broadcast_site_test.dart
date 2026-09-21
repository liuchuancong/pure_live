import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/site/steambroadcast/steam_broadcast_api.dart';
import 'package:pure_live/core/site/steambroadcast/steam_broadcast_link.dart';
import 'package:pure_live/core/site/steambroadcast/steam_broadcast_site.dart';
import 'package:pure_live/core/sites.dart';

void main() {
  test('Steam broadcast links retain only canonical SteamID64 watch identities', () {
    expect(SteamBroadcastLink.parseSteamId('76561198373527746'), '76561198373527746');
    expect(
      SteamBroadcastLink.parseSteamId('https://steamcommunity.com/broadcast/watch/76561198373527746?l=english'),
      '76561198373527746',
    );
    for (final value in [
      'https://steam.tv/example',
      'https://steamcommunity.com/app/730/broadcasts',
      'https://steamcommunity.com/broadcast/watch/76561198373527746/more',
      'https://steamcommunity.com.evil.test/broadcast/watch/76561198373527746',
      '7656119837352774',
    ]) {
      expect(SteamBroadcastLink.parseSteamId(value), isNull, reason: value);
    }
  });

  test('public community directory preserves identity, current viewers, author and next offset', () {
    final page = SteamBroadcastApi.parseDirectoryHtml(_directoryHtml, page: 1);
    expect(page.hasMore, isTrue);
    expect(page.rooms, hasLength(1));
    final room = page.rooms.single;
    expect(room.steamId, '76561198373527746');
    expect(room.broadcaster, 'ProBrawlhalla');
    expect(room.title, 'Brawlhalla');
    expect(room.game, 'Brawlhalla');
    expect(room.currentViewers, 3758);
    expect(room.cover, startsWith('https://steambroadcast.akamaized.net/broadcast/76561198373527746/'));
    expect(room.avatar, startsWith('https://avatars.akamai.steamstatic.com/'));
  });

  test('watch identity, live grant and HLS master stay bound to one Steam account', () {
    final watch = SteamBroadcastApi.parseWatchHtml(_watchHtml, expectedSteamId: '76561198373527746');
    expect(watch.broadcaster, 'ProBrawlhalla');
    final room = SteamBroadcastApi.parseBroadcastJson(
      _broadcastJson(),
      steamId: '76561198373527746',
      broadcaster: watch.broadcaster,
    );
    expect(room.state, SteamBroadcastState.live);
    expect(room.currentViewers, 3797);
    expect(room.master?.host, 'cache9-lax2.steamcontent.com');
    expect(
      () => SteamBroadcastApi.validateMaster(_master, expectedSteamId: room.steamId, expectedMaster: room.master!),
      returnsNormally,
    );
    expect(
      () => SteamBroadcastApi.validateMaster(
        _master.replaceAll('76561198373527746', '76561199485215572'),
        expectedSteamId: room.steamId,
        expectedMaster: room.master!,
      ),
      throwsA(isA<SteamBroadcastException>()),
    );
  });

  test('site registers directory, exact search, adaptive media and recovery refresh', () async {
    final api = _FixtureApi();
    final site = SteamBroadcastSite(api: api);
    final directory = await site.getDirectoryPage(page: 1);
    expect(directory.rooms.single.onlineViewers, '3758');
    final exact = await site.searchRooms('https://steamcommunity.com/broadcast/watch/76561198373527746');
    expect(exact.single.nick, 'ProBrawlhalla');

    final detail = await site.getRoomDetail(roomId: '76561198373527746', platform: Sites.steamBroadcastSite);
    expect(detail.title, 'Brawlhalla');
    expect(detail.data, isA<SteamBroadcastRoom>());
    final qualities = await site.getPlayQualites(detail: detail);
    expect(qualities.single.selectionId, 'auto');
    final first = await site.resolvePlayUrlsRaw(detail: detail, quality: qualities.single);
    expect(first.urls.single, contains('/master.m3u8?broadcast_origin='));
    final recovered = await site.resolvePlayUrlsForRecoveryRaw(detail: detail, quality: qualities.single);
    expect(recovered.urls.single, first.urls.single);
    expect(api.roomCalls, 3);

    expect(Sites.supportedSiteIds, contains(Sites.steamBroadcastSite));
    expect(Sites.of(Sites.steamBroadcastSite).liveSite, isA<SteamBroadcastSite>());
    expect(Sites.supportSites.where((site) => site.id == Sites.steamBroadcastSite), hasLength(1));
  });
}

final class _FixtureApi extends SteamBroadcastApi {
  int roomCalls = 0;

  _FixtureApi() : super(request: (_, _, _) async => throw StateError('unused'));

  SteamBroadcastRoom get _directoryRoom => SteamBroadcastApi.parseDirectoryHtml(_directoryHtml, page: 1).rooms.single;

  @override
  Future<SteamBroadcastPage> directory({int page = 1, CancelToken? cancel}) async =>
      SteamBroadcastPage(rooms: page == 1 ? [_directoryRoom] : const [], hasMore: false);

  @override
  Future<SteamBroadcastRoom> room(String rawSteamId, {bool includeMedia = false, CancelToken? cancel}) async {
    roomCalls++;
    final id = SteamBroadcastLink.requireSteamId(rawSteamId);
    return SteamBroadcastApi.parseBroadcastJson(_broadcastJson(), steamId: id, broadcaster: 'ProBrawlhalla');
  }
}

const _directoryHtml = '''
<div id="page1">
  <div class="Broadcast_Card apphub_Card interactable">
    <a href="https://steamcommunity.com/broadcast/watch/76561198373527746">
      <div class="apphub_CardContentType">Brawlhalla: Broadcast</div>
      <img class="apphub_CardContentPreviewImage" src="https://steambroadcast.akamaized.net/broadcast/76561198373527746/2748973143798613994/thumbnail/?broadcast_origin=ext2-ord1.steamserver.net">
      <div class="apphub_CardContentViewers ellipsis">3,758 viewers&nbsp;</div>
      <div class="apphub_CardContentTitle ellipsis">Brawlhalla</div>
      <div class="apphub_CardContentAuthorName"><a href="https://steamcommunity.com/id/probrawlhallastream/">ProBrawlhalla</a></div>
      <div class="appHubIconHolder"><img src="https://avatars.akamai.steamstatic.com/fixture.jpg"></div>
    </a>
  </div>
  <form><input name="broadcastsoffset" value="10"><input name="p" value="2"></form>
</div>
''';

const _watchHtml = '''
<html><head><meta property="og:title" content="Steam Community :: ProBrawlhalla :: Broadcast"></head>
<body><div id="application_config" data-broadcastsinfo="{&quot;steamid&quot;:&quot;76561198373527746&quot;}"></div></body></html>
''';

Map<String, dynamic> _broadcastJson() => {
  'success': 'ready',
  'retry': 0,
  'broadcastid': '2748973143798613994',
  'hls_url': 'https://cache9-lax2.steamcontent.com/broadcast/76561198373527746/7299796105176582514/hls_manifest/0/cache9-lax2.steamcontent.com/master.m3u8?broadcast_origin=ext2-ord1.steamserver.net',
  'title': '',
  'num_viewers': 3797,
  'cdn_auth_url_parameters': null,
};

const _master = '''
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aac",NAME="Default",URI="https://cache9-lax2.steamcontent.com/broadcast/76561198373527746/7299796105176582514/hls_manifest/0/cache9-lax2.steamcontent.com/187000/audio.m3u8?broadcast_origin=ext2-ord1.steamserver.net"
#EXT-X-STREAM-INF:BANDWIDTH=7187000,RESOLUTION=1920x1080,AUDIO="aac"
https://cache9-lax2.steamcontent.com/broadcast/76561198373527746/7299796105176582514/hls_manifest/0/cache9-lax2.steamcontent.com/7000000/video.m3u8?broadcast_origin=ext2-ord1.steamserver.net
''';
