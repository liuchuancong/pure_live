import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/site/rumble/rumble_api.dart';
import 'package:pure_live/core/site/rumble/rumble_browser.dart';
import 'package:pure_live/core/site/rumble/rumble_link.dart';
import 'package:pure_live/core/site/rumble/rumble_site.dart';
import 'package:pure_live/core/sites.dart';

void main() {
  test('public video and channel links keep distinct durable identities', () {
    expect(RumbleLink.parseVideoKey('v7fngda-RT-DE-live-tv'), 'v7fngda-rt-de-live-tv');
    expect(
      RumbleLink.parseVideoKey('https://rumble.com/v7fngda-rt-de-live-tv.html?e9s=src_v1_blp'),
      'v7fngda-rt-de-live-tv',
    );
    expect(RumbleLink.parseChannel('https://rumble.com/c/RTDE?e9s=src_v1_cbl'), 'RTDE');
    expect(RumbleLink.parseChannel('https://rumble.com/user/example'), 'example');
    for (final invalid in [
      'https://rumble.com/embed/v7dh3fs/',
      'https://rumble.com/browse/live',
      'https://rumble.com.evil.test/v7fngda-rt-de-live-tv.html',
      'https://user@rumble.com/v7fngda-rt-de-live-tv.html',
    ]) {
      expect(RumbleLink.parseVideoKey(invalid), isNull, reason: invalid);
    }
  });

  test('official directory keeps native paging and separates concurrent from cumulative views', () {
    final page = RumbleApi.parseDirectoryHtml(_directoryHtml, page: 1);
    expect(page.hasMore, isTrue);
    expect(page.items, hasLength(1));
    final room = page.items.single;
    expect(room.videoKey, 'v7fngda-rt-de-live-tv');
    expect(room.channel, 'RTDE');
    expect(room.currentViewers, 1960);
    expect(room.totalViews, 797919);
    expect(room.state, RumbleState.live);
  });

  test('VideoObject detail keeps the embed identity separate from the public page identity', () {
    final room = RumbleApi.parseRoomHtml(_detailHtml, expectedVideoKey: 'v7fngda-rt-de-live-tv');
    expect(room.videoKey, 'v7fngda-rt-de-live-tv');
    expect(room.embedId, 'v7dh3fs');
    expect(room.currentViewers, isNull);
    expect(room.totalViews, 797919);
    expect(room.followers, 7390);
    expect(room.category, 'News');
  });

  test('browser payload validates and sorts official HLS renditions', () {
    final payload = jsonEncode({
      'videoKey': 'v7fngda-rt-de-live-tv',
      'title': 'RT DE LIVE-TV',
      'description': '',
      'thumbnail': 'https://hugh.cdn.rumble.cloud/video/fixture.jpg',
      'embedUrl': 'https://rumble.com/embed/v7dh3fs/',
      'channel': '/c/RTDE',
      'channelName': 'RT DE',
      'category': 'News',
      'followers': '7.39K followers',
      'currentViewers': '2,107',
      'totalViews': 797919,
      'live': true,
      'masterUrl': 'https://rumble.com/live-hls-dvr/yjArByN2fi0/playlist.m3u8?',
      'playlist': _master,
    });
    final room = RumbleBrowserPageResolver.parsePagePayload('v7fngda-rt-de-live-tv', payload, requireMedia: true);
    expect(room.currentViewers, 2107);
    expect(room.qualities.map((quality) => quality.id), ['hls:1080p', 'hls:720p', 'hls:360p']);
    expect(room.qualities.first.label, '1080p · HLS');
    expect(RumbleBrowserPageResolver.buildPageScript(room.videoKey, includeMedia: true), contains('/live-hls'));
    expect(
      () => RumbleBrowserPageResolver.parseMaster(
        '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1,RESOLUTION=1x1\nhttps://evil.test/live.m3u8',
      ),
      throwsA(isA<RumbleException>()),
    );
  });

  test('site directory, exact detail and recovery retain stable quality selection', () async {
    final resolver = _FixtureResolver();
    final site = RumbleSite(
      api: RumbleApi(request: _FixtureTransport().call),
      pageResolver: resolver,
    );
    final category = (await site.getCategores(1, 30)).single.children.single;
    final directory = await site.getDirectoryPage(category: category);
    expect(directory.rooms.single.onlineViewers, '1960');
    expect(directory.rooms.single.totalViewers, '797919');
    expect(directory.rooms.single.audienceMetricType, AudienceMetricType.onlineViewers);

    final detail = await site.getRoomDetail(roomId: 'v7fngda-rt-de-live-tv', platform: Sites.rumbleSite);
    expect(detail.onlineViewers, '2107');
    expect(detail.totalViewers, '797919');
    final qualities = await site.getPlayQualites(detail: detail);
    expect(qualities.single.selectionId, 'hls:1080p');
    final first = await site.resolvePlayUrlsRaw(detail: detail, quality: qualities.single);
    expect(Uri.parse(first.urls.single).queryParameters['generation'], '1');
    final recovered = await site.resolvePlayUrlsForRecoveryRaw(detail: detail, quality: qualities.single);
    expect(Uri.parse(recovered.urls.single).queryParameters['generation'], '2');
    expect(resolver.refreshes, 1);
  });

  test('registry exposes one Rumble adapter with recording recovery', () {
    expect(Sites.supportedSiteIds, contains(Sites.rumbleSite));
    expect(Sites.of(Sites.rumbleSite).liveSite, isA<RumbleSite>());
    expect(Sites.supportSites.where((site) => site.id == Sites.rumbleSite), hasLength(1));
  });
}

const _directoryHtml = '''<!doctype html><html><head>
<link rel="next" href="https://rumble.com/browse/live?page=2">
</head><body>
<div class="videostream thumbnail__grid-item" data-video-id="445895848">
  <div class="thumbnail__thumb thumbnail__thumb--live">
    <img class="thumbnail__image" src="https://hugh.cdn.rumble.cloud/video/fixture.jpg" alt="RT DE LIVE-TV">
    <span class="videostream__number">1.96K</span>
    <a class="videostream__link" href="/v7fngda-rt-de-live-tv.html?e9s=src_v1_blp"></a>
  </div>
  <h3 class="thumbnail__title" title="RT DE LIVE-TV"></h3>
  <a rel="author" class="channel__link" href="/c/RTDE?e9s=src_v1_blp">
    <img class="channel__image" src="https://hugh.cdn.rumble.cloud/channel/fixture.jpeg">
    <span class="channel__name" title="RT DE">RT DE</span>
  </a>
  <span class="videostream__views" data-views="797919"></span>
</div></body></html>''';

const _detailHtml = '''<!doctype html><html><head>
<script type="application/ld+json">[{"@type":"VideoObject","name":"RT DE LIVE-TV","description":"Fixture","thumbnailUrl":"https://hugh.cdn.rumble.cloud/video/fixture.jpg","embedUrl":"https://rumble.com/embed/v7dh3fs/","url":"https://rumble.com/v7fngda-rt-de-live-tv.html","interactionStatistic":{"userInteractionCount":797919}}]</script>
</head><body>
<h1 class="h1">RT DE LIVE-TV</h1>
<a class="media-by--a" href="/c/RTDE?e9s=src_v1_cbl" rel="author">
  <div class="media-heading-name">RT DE</div><div class="media-heading-num-followers">7.39K followers</div>
</a>
<div class="media-description-info-stream-time">Streaming now</div>
<a class="video-category-tag video-category-tag-primary">News</a>
</body></html>''';

const _master = '''#EXTM3U
#EXT-X-VERSION:3
#EXT-X-STREAM-INF:BANDWIDTH=7000000,RESOLUTION=1920x1080
https://hugh.cdn.rumble.cloud/live/fixture/stream_1080p/chunklist_DVR.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=3500000,RESOLUTION=1280x720
https://hugh.cdn.rumble.cloud/live/fixture/stream_720p/chunklist_DVR.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1200000,RESOLUTION=640x360
https://hugh.cdn.rumble.cloud/live/fixture/stream_360p/chunklist_DVR.m3u8
''';

final class _FixtureTransport {
  Future<({int status, String body})> call(Uri uri, Map<String, String> headers, CancelToken cancel) async {
    if (uri.path == '/browse/live') return (status: 200, body: _directoryHtml);
    if (uri.path == '/v7fngda-rt-de-live-tv.html') return (status: 200, body: _detailHtml);
    return (status: 404, body: '');
  }
}

final class _FixtureResolver implements RumblePageResolver {
  int generation = 0;
  int refreshes = 0;

  @override
  Future<RumbleRoom> resolve(String videoKey, {bool includeMedia = true, bool refresh = false}) async {
    generation++;
    if (refresh) refreshes++;
    return RumbleRoom(
      videoKey: videoKey,
      channel: 'RTDE',
      channelName: 'RT DE',
      title: 'RT DE LIVE-TV',
      description: 'Fixture',
      cover: 'https://hugh.cdn.rumble.cloud/video/fixture.jpg',
      avatar: 'https://hugh.cdn.rumble.cloud/channel/fixture.jpeg',
      category: 'News',
      followers: 7390,
      currentViewers: 2107,
      totalViews: 797919,
      state: RumbleState.live,
      embedId: 'v7dh3fs',
      qualities: includeMedia
          ? [
              RumbleQuality(
                id: 'hls:1080p',
                label: '1080p · HLS',
                sort: 1080,
                url: Uri.parse(
                  'https://hugh.cdn.rumble.cloud/live/fixture/stream_1080p/chunklist_DVR.m3u8?generation=$generation',
                ),
              ),
            ]
          : const [],
    );
  }
}
