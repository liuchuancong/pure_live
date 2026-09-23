import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/site/goodgame/goodgame_api.dart';
import 'package:pure_live/core/site/goodgame/goodgame_link.dart';
import 'package:pure_live/core/site/goodgame/goodgame_site.dart';
import 'package:pure_live/core/sites.dart';

void main() {
  test('channel and player links retain distinct stable identities', () {
    expect(GoodGameLink.parseChannel('Verloin'), 'verloin');
    expect(GoodGameLink.parse('https://goodgame.ru/Verloin')?.storageKey, 'verloin');
    expect(GoodGameLink.parse('https://www.goodgame.ru/player?15365')?.storageKey, 'id:15365');
    expect(GoodGameLink.parse('https://goodgame.ru/player?src=15365')?.storageKey, 'id:15365');
    for (final invalid in [
      'https://goodgame.ru/streams',
      'https://goodgame.ru/Verloin/dashboard',
      'https://goodgame.ru.evil.test/Verloin',
      'https://user@goodgame.ru/Verloin',
    ]) {
      expect(GoodGameLink.parse(invalid), isNull, reason: invalid);
    }
  });

  test('official directory retains page totals and explicit audience semantics', () {
    final page = GoodGameApi.parseDirectory(_directory(), expectedPage: 1);
    expect(page.hasMore, isTrue);
    expect(page.items, hasLength(1));
    final room = page.items.single;
    expect(room.channel, 'verloin');
    expect(room.viewers, 93);
    expect(room.followers, 4950);
    expect(room.category, 'Neverwinter Nights: Enhanced Edition');
    expect(room.qualities.map((quality) => quality.id), ['source', '720p', '480p', '240p']);
  });

  test('channel and player response shapes converge on the same room identity', () {
    final detail = GoodGameApi.parseRoom(_detail(generation: 1));
    final player = GoodGameApi.parsePlayer(_player(generation: 1));
    expect(detail.channel, 'verloin');
    expect(player.channel, detail.channel);
    expect(player.streamId, detail.streamId);
    expect(detail.viewers, 95);
    expect(detail.qualities.first.url.queryParameters['generation'], '1');
  });

  test('site directory, exact lookup, playback and recovery preserve quality ID', () async {
    final transport = _FixtureTransport();
    final site = GoodGameSite(api: GoodGameApi(request: transport.call));
    final category = (await site.getCategores(1, 30)).single.children.single;
    final directory = await site.getDirectoryPage(category: category);
    expect(directory.rooms.single.onlineViewers, '93');
    expect(directory.rooms.single.audienceMetricType, AudienceMetricType.onlineViewers);
    expect(directory.hasMore, isTrue);

    final exact = await site.searchRooms('https://goodgame.ru/Verloin');
    expect(exact.single.roomId, 'verloin');
    final detail = await site.getRoomDetail(roomId: 'verloin', platform: Sites.goodGameSite);
    final qualities = await site.getPlayQualites(detail: detail);
    final selected = qualities.singleWhere((quality) => quality.selectionId == '720p');
    final first = await site.resolvePlayUrlsRaw(detail: detail, quality: selected);
    expect(Uri.parse(first.urls.single).queryParameters['generation'], '2');
    final recovered = await site.resolvePlayUrlsForRecoveryRaw(detail: detail, quality: selected);
    expect(Uri.parse(recovered.urls.single).queryParameters['generation'], '3');
  });

  test('official room links and player IDs are single-page searches', () async {
    final requests = <Uri>[];
    final fixture = _FixtureTransport();
    final site = GoodGameSite(
      api: GoodGameApi(
        request: (uri, headers, cancel) {
          requests.add(uri);
          return fixture.call(uri, headers, cancel);
        },
      ),
    );
    for (final query in ['https://goodgame.ru/Verloin', 'id:15365', 'https://goodgame.ru/player?15365']) {
      expect(site.supportsSearchPaginationFor(query), isFalse);
      expect((await site.searchRooms(query)).single.roomId, 'verloin');
      final before = requests.length;
      expect(await site.searchRooms(query, page: 2), isEmpty);
      expect(requests, hasLength(before));
    }
    expect(site.supportsSearchPaginationFor('Neverwinter'), isTrue);
    expect(site.supportsSearchPaginationFor(''), isFalse);

    final beforeMissing = requests.length;
    expect(await site.searchRooms('https://goodgame.ru/not-found'), isEmpty);
    expect(requests, hasLength(beforeMissing + 1));
    expect(requests.last.path, '/api/4/users/not-found/stream');
  });

  test('directory-backed search preserves matches past the UI page size', () async {
    final template = Map<String, dynamic>.from((_directory()['streams'] as List).single as Map);
    final rooms = List.generate(84, (index) {
      final id = 20000 + index;
      return {
        ...template,
        'id': id,
        'key': 'match$index',
        'title': 'match title $index',
        'streamer': {'username': 'match$index'},
        'sources': {'source': 'https://hls.goodgame.ru/hls/$id.m3u8?expires=1790064565&token=fixture'},
      };
    });
    var directoryRequests = 0;
    final site = GoodGameSite(
      api: GoodGameApi(
        request: (uri, _, _) async {
          directoryRequests++;
          final page = int.parse(uri.queryParameters['page']!);
          return (
            status: 200,
            body: jsonEncode({
              'queryInfo': {'qty': rooms.length, 'page': page, 'onPage': 50},
              'streams': rooms.skip((page - 1) * 50).take(50).toList(),
            }),
          );
        },
      ),
    );
    final first = await site.searchRooms('match title', page: 1, pageSize: 30);
    final second = await site.searchRooms('match title', page: 2, pageSize: 30);
    final third = await site.searchRooms('match title', page: 3, pageSize: 30);
    expect(await site.searchRooms('match title', page: 4, pageSize: 30), isEmpty);
    expect(first, hasLength(30));
    expect(second, hasLength(30));
    expect(third, hasLength(24));
    expect({
      ...first.map((room) => room.roomId),
      ...second.map((room) => room.roomId),
      ...third.map((room) => room.roomId),
    }, hasLength(84));
    expect(directoryRequests, 2);
  });

  test('search continues after a native page with no visible live rooms', () async {
    final template = Map<String, dynamic>.from((_directory()['streams'] as List).single as Map);
    final site = GoodGameSite(
      api: GoodGameApi(
        request: (uri, _, _) async {
          final page = int.parse(uri.queryParameters['page']!);
          return (
            status: 200,
            body: jsonEncode({
              'queryInfo': {'qty': 51, 'page': page, 'onPage': 50},
              'streams': page == 1
                  ? List.generate(50, (index) => {...template, 'id': 20000 + index, 'online': false})
                  : [template],
            }),
          );
        },
      ),
    );
    final matches = await site.searchRooms('Neverwinter Night');
    expect(matches.map((room) => room.roomId), ['verloin']);
  });

  test('registry exposes one GoodGame adapter with recording recovery', () {
    expect(Sites.supportedSiteIds, contains(Sites.goodGameSite));
    expect(Sites.of(Sites.goodGameSite).liveSite, isA<GoodGameSite>());
    expect(Sites.supportSites.where((site) => site.id == Sites.goodGameSite), hasLength(1));
  });
}

Map<String, dynamic> _directory() => {
  'queryInfo': {'qty': 84, 'page': 1, 'onPage': 50},
  'filter': {'page': '1', 'hidden': true, 'only_gg': true},
  'streams': [
    {
      'id': 15365,
      'key': 'Verloin',
      'title': 'Neverwinter Night',
      'viewers': 93,
      'streamer': {
        'id': 202296,
        'nickname': 'Verloin',
        'username': 'Verloin',
        'avatar': 'https://goodgame.ru/files/avatars/fixture.jpg',
        'banned': false,
      },
      'online': true,
      'game': {'id': 95566, 'title': 'Neverwinter Nights: Enhanced Edition'},
      'preview': 'https://hls.goodgame.ru/previews/15365_240.jpg',
      'streamPreview': 'https://hls.goodgame.ru/previews/15365.jpg',
      'adult': false,
      'followers': 4950,
      'sources': _sources(generation: 0),
    },
  ],
};

Map<String, dynamic> _detail({required int generation}) => {
  'id': 15365,
  'title': 'Neverwinter Night',
  'stream_title': 'Neverwinter Night',
  'streamer': {'id': 202296, 'nickname': 'Verloin', 'username': 'Verloin', 'avatar': '/files/avatars/fixture.jpg'},
  'channelkey': 'Verloin',
  'status': true,
  'online': true,
  'viewers': 95,
  'followers': 4950,
  'adult': true,
  'blacklisted': false,
  'gameObj': {'id': 95566, 'title': 'Neverwinter Nights: Enhanced Edition'},
  'streamPreview': 'https://hls.goodgame.ru/previews/15365.jpg',
  'sources': _sources(generation: generation),
};

Map<String, dynamic> _player({required int generation}) => {
  'channel_id': 15365,
  'channel_key': 'Verloin',
  'channel_title': 'Neverwinter Night',
  'channel_status': 'online',
  'channel_poster': 'https://goodgame.ru/files/logotypes/fixture.gif',
  'streamer_id': 202296,
  'streamer_name': 'Verloin',
  'streamer_avatar': 'https://goodgame.ru/files/avatars/fixture.jpg',
  'adult': 0,
  'viewers': 95,
  'game': {'id': 95566, 'title': 'Neverwinter Nights: Enhanced Edition'},
  'sources': _sources(generation: generation),
};

Map<String, String> _sources({required int generation}) => {
  '240': 'https://hls.goodgame.ru/hls/15365_240.m3u8?expires=1790064565&token=fixture&generation=$generation',
  '480': 'https://hls.goodgame.ru/hls/15365_480.m3u8?expires=1790064565&token=fixture&generation=$generation',
  '720': 'https://hls.goodgame.ru/hls/15365_720.m3u8?expires=1790064565&token=fixture&generation=$generation',
  'source': 'https://hls.goodgame.ru/hls/15365.m3u8?expires=1790064565&token=fixture&generation=$generation',
  'master': 'https://hls.goodgame.ru/manifest/15365_master.m3u8?expires=1790064565&token=fixture',
};

final class _FixtureTransport {
  int generation = 0;

  Future<({int status, String body})> call(Uri uri, Map<String, String> headers, CancelToken cancel) async {
    if (uri.path == '/api/4/streams/2/') return (status: 200, body: jsonEncode(_directory()));
    if (uri.path == '/api/player') return (status: 200, body: jsonEncode(_player(generation: ++generation)));
    if (uri.path == '/api/4/users/verloin/stream') {
      return (status: 200, body: jsonEncode(_detail(generation: ++generation)));
    }
    return (status: 404, body: '{}');
  }
}
