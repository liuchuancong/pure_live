import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/site/vkvideolive/vkvideolive_api.dart';
import 'package:pure_live/core/site/vkvideolive/vkvideolive_link.dart';
import 'package:pure_live/core/site/vkvideolive/vkvideolive_site.dart';
import 'package:pure_live/core/sites.dart';

void main() {
  test('current and legacy official links normalize one channel identity', () {
    expect(VkVideoLiveLink.parse('https://live.vkvideo.ru/HighMySide')?.storageKey, 'highmyside');
    expect(VkVideoLiveLink.parse('https://live.vkplay.ru/HighMySide')?.storageKey, 'highmyside');
    expect(VkVideoLiveLink.parse('https://vkplay.live/HighMySide')?.storageKey, 'highmyside');
    expect(VkVideoLiveLink.url('HighMySide'), 'https://live.vkvideo.ru/highmyside');
    for (final invalid in [
      'https://live.vkvideo.ru/app/catalog/categories',
      'https://live.vkvideo.ru/clan/gost',
      'https://live.vkvideo.ru/highmyside?ref=test',
      'https://live.vkvideo.ru.evil.test/highmyside',
      'https://user@live.vkvideo.ru/highmyside',
    ]) {
      expect(VkVideoLiveLink.parse(invalid), isNull, reason: invalid);
    }
  });

  test('public categories and directory preserve server offsets and audience metrics', () async {
    final transport = _FixtureTransport();
    final api = VkVideoLiveApi(request: transport.call);
    final categories = await api.categories(limit: 40);
    expect(categories.items.single.title, 'МИР ТАНКОВ');
    expect(categories.items.single.viewerCount, 999);
    expect(categories.nextOffset, 40);

    final site = VkVideoLiveSite(api: api);
    final first = await site.getDirectoryPage();
    expect(first.hasMore, isTrue);
    expect(first.rooms.single.roomId, 'highmyside');
    expect(first.rooms.single.onlineViewers, '368');
    expect(first.rooms.single.totalViewers, '924');
    expect(first.rooms.single.audienceMetricType, AudienceMetricType.onlineViewers);
    final second = await site.getDirectoryPage(page: 2);
    expect(second.hasMore, isFalse);
    expect(transport.directoryOffsets, [0, 36]);
  });

  test('native channel search includes offline results and retains the after cursor', () async {
    final transport = _FixtureTransport();
    final site = VkVideoLiveSite(api: VkVideoLiveApi(request: transport.call));
    final first = await site.searchRooms('test', pageSize: 20);
    expect(first, hasLength(2));
    expect(first.first.effectiveLiveStatus, LiveStatus.live);
    expect(first.first.onlineViewers, '12');
    expect(first.last.effectiveLiveStatus, LiveStatus.offline);
    expect(first.last.onlineViewers, isNull);
    final second = await site.searchRooms('test', page: 2, pageSize: 20);
    expect(second, isEmpty);
    expect(transport.searchAfter, [null, 'cursor-2']);
  });

  test('room detail parses signed HLS variants, mirrors, recovery and lease expiry', () async {
    final transport = _FixtureTransport();
    final site = VkVideoLiveSite(api: VkVideoLiveApi(request: transport.call));
    final detail = await site.getRoomDetail(roomId: 'highmyside', platform: Sites.vkVideoLiveSite);
    expect(detail.effectiveLiveStatus, LiveStatus.live);
    expect(detail.nick, 'HighMySide');
    expect(detail.onlineViewers, '368');
    expect(detail.httpHeaders['Referer'], 'https://live.vkvideo.ru/highmyside');
    final qualities = await site.getPlayQualites(detail: detail);
    expect(qualities.map((quality) => quality.selectionId), ['1920x1080', '1280x720']);
    final urls = await site.resolvePlayUrlsRaw(detail: detail, quality: qualities.first);
    expect(urls.urls, hasLength(2));
    expect(urls.urls.every((url) => url.contains('/19251309447816_fullhd/index.m3u8')), isTrue);
    final recovered = await site.resolvePlayUrlsForRecoveryRaw(detail: detail, quality: qualities.first);
    expect(recovered.urls.every((url) => url.contains('generation=2')), isTrue);
    expect(transport.roomCalls, 2);

    const media = 'https://vsd130.okcdn.ru/hls/master.m3u8/sig/token/expires/1800000000000/srcIp/1/video/variant.m3u8';
    expect(VkVideoLiveApi.mediaInvalidAt(media), DateTime.utc(2027, 1, 15, 7, 59, 50));
    expect(VkVideoLiveApi.mediaRefreshAt(media), DateTime.utc(2027, 1, 15, 7, 57, 50));
  });

  test('registry exposes one VK Video Live adapter with recording recovery', () {
    expect(Sites.supportedSiteIds, contains(Sites.vkVideoLiveSite));
    expect(Sites.of(Sites.vkVideoLiveSite).liveSite, isA<VkVideoLiveSite>());
    expect(Sites.supportSites.where((site) => site.id == Sites.vkVideoLiveSite), hasLength(1));
  });
}

final class _FixtureTransport {
  final List<int> directoryOffsets = [];
  final List<String?> searchAfter = [];
  int roomCalls = 0;

  Future<({int status, String body})> call(Uri uri, Map<String, String> headers, CancelToken cancel) async {
    if (uri.path.endsWith('/category/')) {
      return (status: 200, body: jsonEncode(_categories()));
    }
    if (uri.path == '/v1/catalog/public_video_streams/') {
      final offset = int.tryParse(uri.queryParameters['offset'] ?? '') ?? 0;
      directoryOffsets.add(offset);
      return (status: 200, body: jsonEncode(_directory(last: offset > 0)));
    }
    if (uri.path == '/v8/search/channel') {
      searchAfter.add(uri.queryParameters['after']);
      return (status: 200, body: jsonEncode(_search(last: uri.queryParameters['after'] != null)));
    }
    if (uri.path == '/v1/blog/highmyside/public_video_stream') {
      roomCalls++;
      return (status: 200, body: jsonEncode(_room(generation: roomCalls)));
    }
    if (uri.host.endsWith('.okcdn.ru')) {
      final generation = uri.queryParameters['generation'] ?? '1';
      return (status: 200, body: _master(generation));
    }
    throw StateError('Unexpected fixture request: $uri');
  }
}

Map<String, dynamic> _categories() => {
  'data': {
    'categories': [
      {
        'id': '4588a9f0-b606-4827-9b6a-f2da4309c196',
        'type': 'game',
        'title': 'МИР ТАНКОВ',
        'coverUrl': 'https://images.live.vkvideo.ru/public_video_stream/category/fixture',
        'count': {'viewers': 999},
      },
    ],
  },
  'extra': {'offset': 40, 'isLast': false},
};

Map<String, dynamic> _directory({required bool last}) => {
  'data': {
    'streamBlogs': last ? [] : [_directoryRoom()],
  },
  'extra': {'offset': 36, 'isLast': last},
};

Map<String, dynamic> _directoryRoom() => {
  'stream': {
    'id': '8700d83c-2bc2-4d88-88c3-988b16db7ccd',
    'title': 'Fixture stream',
    'previewUrl': 'https://images.live.vkvideo.ru/public_video_stream/stream/fixture/preview',
    'isOnline': true,
    'isEnded': false,
    'isPlaybackDisabled': false,
    'accessRestrictions': {
      'view': {'allowed': true},
    },
    'count': {'viewers': 368, 'views': 924},
    'category': {'title': 'МИР ТАНКОВ'},
  },
  'blog': {
    'blogUrl': 'highmyside',
    'owner': {
      'id': 18480298,
      'displayName': 'HighMySide',
      'avatarUrl': 'https://images.live.vkvideo.ru/user/18480298/avatar',
    },
  },
};

Map<String, dynamic> _search({required bool last}) => {
  'data': {
    'channels': last
        ? []
        : [
            {
              'url': 'fixture_live',
              'id': 1,
              'nick': 'Fixture Live',
              'channelStatus': 'online',
              'streamId': '11111111-1111-4111-8111-111111111111',
              'avatarUrl': '',
              'coverUrl': '',
              'counters': {'subscribers': 20},
            },
            {
              'url': 'fixture_offline',
              'id': 2,
              'nick': 'Fixture Offline',
              'channelStatus': 'offline',
              'streamId': '',
              'avatarUrl': '',
              'coverUrl': '',
              'counters': {'subscribers': 3},
            },
          ],
  },
  'refs': {
    'streams': {
      '11111111-1111-4111-8111-111111111111': {
        'title': 'Fixture Live',
        'previewUrl': 'https://images.live.vkvideo.ru/public_video_stream/stream/fixture/preview',
        'categoryId': '22222222-2222-4222-8222-222222222222',
        'counters': {'viewers': 12, 'views': 30},
        'flags': {'isPlaybackDisabled': false},
      },
    },
    'categories': {
      '22222222-2222-4222-8222-222222222222': {'title': 'Fixture category'},
    },
  },
  'extra': {'isLast': last, 'after': last ? '' : 'cursor-2'},
};

Map<String, dynamic> _room({required int generation}) => {
  'id': '8700d83c-2bc2-4d88-88c3-988b16db7ccd',
  'title': 'Fixture stream',
  'isOnline': true,
  'isEnded': false,
  'isPlaybackDisabled': false,
  'accessRestrictions': {
    'view': {'allowed': true},
  },
  'count': {'viewers': 368, 'views': 924},
  'user': {
    'id': 18480298,
    'displayName': 'HighMySide',
    'avatarUrl': 'https://images.live.vkvideo.ru/user/18480298/avatar',
  },
  'previewUrl': 'https://images.live.vkvideo.ru/public_video_stream/stream/fixture/preview',
  'channelCoverImageUrl': '',
  'category': {'title': 'МИР ТАНКОВ'},
  'data': [
    {
      'playerUrls': [
        {
          'type': 'live_hls',
          'url':
              'https://vsd130.okcdn.ru/hls/master.m3u8/sig/token/expires/1800000000000/srcIp/1/video/video.m3u8?generation=$generation',
        },
      ],
      'sharedPlayerUrls': [
        {
          'type': 'live_hls',
          'url':
              'https://vsd255.okcdn.ru/hls/master.m3u8/sig/token/expires/1800000000000/srcIp/1/video/video.m3u8?generation=$generation',
        },
      ],
    },
  ],
};

String _master(String generation) =>
    '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-STREAM-INF:BANDWIDTH=10653494,RESOLUTION=1920x1080,QUALITY=full
19251309447816_fullhd/index.m3u8?generation=$generation
#EXT-X-STREAM-INF:BANDWIDTH=2734027,RESOLUTION=1280x720,QUALITY=hd
19251309447816_high/index.m3u8?generation=$generation
''';
