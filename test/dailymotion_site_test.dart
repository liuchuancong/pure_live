import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/site/dailymotion/dailymotion_api.dart';
import 'package:pure_live/core/site/dailymotion/dailymotion_browser.dart';
import 'package:pure_live/core/site/dailymotion/dailymotion_link.dart';
import 'package:pure_live/core/site/dailymotion/dailymotion_site.dart';
import 'package:pure_live/core/sites.dart';

void main() {
  test('official media and user links keep distinct identities', () {
    expect(DailymotionLink.parseVideoId('x3B68JN'), 'x3b68jn');
    expect(DailymotionLink.parseVideoId('https://www.dailymotion.com/video/x3b68jn'), 'x3b68jn');
    expect(DailymotionLink.parseVideoId('https://www.dailymotion.com/live/x3b68jn'), 'x3b68jn');
    expect(DailymotionLink.parseVideoId('https://www.dailymotion.com/embed/video/x3b68jn'), 'x3b68jn');
    expect(DailymotionLink.parseVideoId('https://dai.ly/x3b68jn'), 'x3b68jn');
    expect(DailymotionLink.parseUsername('https://www.dailymotion.com/CNEWS'), 'CNEWS');
    expect(DailymotionLink.parseUsername('CNEWS'), 'CNEWS');
    for (final invalid in [
      'https://www.dailymotion.com/video/not-a-video',
      'https://www.dailymotion.com/search',
      'https://www.dailymotion.com.evil.test/video/x3b68jn',
      'https://user@www.dailymotion.com/video/x3b68jn',
    ]) {
      expect(DailymotionLink.parseVideoId(invalid), isNull, reason: invalid);
    }
  });

  test('native API directory, keyword search and channel live search retain server paging', () async {
    final transport = _FixtureTransport();
    final site = DailymotionSite(
      api: DailymotionApi(request: transport.call),
      mediaResolver: _FixtureMedia(),
    );
    final category = (await site.getCategores(1, 30)).single.children.single;
    final first = await site.getDirectoryPage(category: category);
    expect(first.rooms.single.roomId, 'x3b68jn');
    expect(first.rooms.single.effectiveLiveStatus, LiveStatus.live);
    expect(first.rooms.single.onlineViewers, isNull);
    expect(first.rooms.single.audienceMetricType, AudienceMetricType.unknown);
    expect(first.hasMore, isTrue);

    final keyword = await site.searchRooms('news live');
    expect(keyword.single.roomId, 'x3b68jn');
    final channel = await site.searchRooms('CNEWS');
    expect(channel.single.nick, 'CNEWS');
    expect(transport.userCalls, 1);
  });

  test('embedded player payload validates and sorts native HLS renditions', () {
    const playlist = '''#EXTM3U
#EXT-X-STREAM-INF:RESOLUTION=512x288,FRAME-RATE=25.000000,BANDWIDTH=782336,NAME="380"
https://live.eu-north-1a.cf.dmcdn.net/sec2(token)/dm/3/x3b68jn/d/live-380.m3u8?startdate=1#cell=test
#EXT-X-STREAM-INF:RESOLUTION=848x477,FRAME-RATE=50.000000,BANDWIDTH=1667072,NAME="480@60"
https://live.eu-north-1a.cf.dmcdn.net/sec2(token)/dm/3/x3b68jn/d/live-480@60.m3u8?startdate=1#cell=test
''';
    final payload = jsonEncode({
      'masterUrl': 'https://cdndirector.dailymotion.com/cdn/live/video/x3b68jn.m3u8?auth=fixture',
      'playlist': playlist,
    });
    final qualities = DailymotionBrowserMediaResolver.parseMediaPayload('x3b68jn', payload);
    expect(qualities.map((quality) => quality.id), ['hls:480@60', 'hls:380']);
    expect(qualities.first.label, '480@60 · HLS');
    expect(qualities.first.url.fragment, isEmpty);
    expect(qualities.first.url.queryParameters['startdate'], '1');
    expect(DailymotionBrowserMediaResolver.buildMediaScript('x3b68jn'), contains('cdndirector.dailymotion.com'));
    expect(
      () => DailymotionBrowserMediaResolver.parseMaster(
        'x3b68jn',
        '#EXTM3U\n#EXT-X-STREAM-INF:NAME="x"\nhttps://evil.test/x3b68jn/live.m3u8',
      ),
      throwsA(isA<DailymotionException>()),
    );
  });

  test('room detail exposes browser renditions and recovery refreshes the signed URL', () async {
    final media = _FixtureMedia();
    final site = DailymotionSite(
      api: DailymotionApi(request: _FixtureTransport().call),
      mediaResolver: media,
    );
    final detail = await site.getRoomDetail(roomId: 'x3b68jn', platform: Sites.dailymotionSite);
    expect(detail.effectiveLiveStatus, LiveStatus.live);
    expect(detail.httpHeaders['Referer'], 'https://geo.dailymotion.com/');
    final qualities = await site.getPlayQualites(detail: detail);
    expect(qualities.single.selectionId, 'hls:720');
    final first = await site.resolvePlayUrlsRaw(detail: detail, quality: qualities.single);
    expect(Uri.parse(first.urls.single).queryParameters['generation'], '1');
    final recovered = await site.resolvePlayUrlsForRecoveryRaw(detail: detail, quality: qualities.single);
    expect(Uri.parse(recovered.urls.single).queryParameters['generation'], '2');
    expect(media.refreshes, 1);
  });

  test('registry exposes one Dailymotion adapter with recording recovery', () {
    expect(Sites.supportedSiteIds, contains(Sites.dailymotionSite));
    expect(Sites.of(Sites.dailymotionSite).liveSite, isA<DailymotionSite>());
    expect(Sites.supportSites.where((site) => site.id == Sites.dailymotionSite), hasLength(1));
  });
}

final class _FixtureTransport {
  int userCalls = 0;

  Future<({int status, String body})> call(Uri uri, Map<String, String> headers, CancelToken cancel) async {
    if (uri.path == '/videos') {
      return (status: 200, body: jsonEncode(_page()));
    }
    if (uri.path == '/user/CNEWS/videos') {
      userCalls++;
      return (status: 200, body: jsonEncode(_page()));
    }
    if (uri.path == '/video/x3b68jn') {
      return (status: 200, body: jsonEncode(_video(description: 'Fixture description')));
    }
    return (status: 404, body: '{}');
  }

  static Map<String, dynamic> _page() => {
    'page': 1,
    'limit': 30,
    'has_more': true,
    'list': [_video()],
  };

  static Map<String, dynamic> _video({String? description}) => {
    'id': 'x3b68jn',
    'title': 'Live CNEWS',
    'description': description,
    'onair': true,
    'mode': 'live',
    'owner.id': 'x24vth',
    'owner.username': 'CNEWS',
    'owner.screenname': 'CNEWS',
    'thumbnail_720_url': 'https://s1.dmcdn.net/l/fixture/x720',
  };
}

final class _FixtureMedia implements DailymotionMediaResolver {
  int calls = 0;
  int refreshes = 0;

  @override
  Future<List<DailymotionQuality>> resolve(String videoId, {bool refresh = false}) async {
    calls++;
    if (refresh) refreshes++;
    return [
      DailymotionQuality(
        id: 'hls:720',
        label: '720 · HLS',
        sort: 720,
        url: Uri.parse('https://live.eu.dmcdn.net/sec2(token)/dm/3/$videoId/d/live-720.m3u8?generation=$calls'),
      ),
    ];
  }
}
