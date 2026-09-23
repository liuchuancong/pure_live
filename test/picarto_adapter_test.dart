import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/utils/live_url_tool.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/interface/live_directory.dart';
import 'package:pure_live/core/common/http_client.dart' as core;
import 'package:pure_live/core/site/picarto/picarto_api.dart';
import 'package:pure_live/core/site/picarto/picarto_hls.dart';
import 'package:pure_live/core/site/picarto/picarto_site.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/modules/multiview/danmaku/multiview_danmaku_session.dart';
import 'package:pure_live/modules/search/search_capability.dart';
import 'package:pure_live/modules/search/web_search_room_parser.dart';
import 'package:pure_live/player/core/playback_header_resolver.dart';
import 'package:pure_live/recorder/services/ffmpeg_header_factory.dart';
import 'package:pure_live/recorder/services/stream_resolver_service.dart';

const masterText =
    '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=3661056,RESOLUTION=1280x720,FRAME-RATE=60,CODECS="avc1.640020,mp4a.40.2"\nvariant.m3u8\n';
final masterUri = Uri.parse('https://edge1-eu-west.picarto.tv/stream/hls/golive+Artist/index.m3u8');
Map<String, dynamic> channel({String name = 'Artist', bool online = true}) => {
  'id': 15237,
  'name': name,
  'title': 'Drawing',
  'online': online,
  'private': false,
  'adult': false,
  'viewers': 15,
  'total_views': 95434,
  'avatar': 'https://images.picarto.tv/avatar.jpg',
  'categories': [
    {'id': 10, 'name': 'Comic'},
  ],
};
Map<String, dynamic> detail({String name = 'Artist', bool online = true, String origin = 'edge1-eu-west'}) => {
  'channel': channel(name: name, online: online),
  'getLoadBalancerUrl': {'origin': origin},
  'getMultiStreams': {
    'streams': [
      {'channelId': 999, 'stream_name': 'golive+Other'},
      {'channelId': 15237, 'stream_name': 'golive+$name', 'thumbnail_image': 'https://thumb.picarto.tv/$name.jpg'},
    ],
  },
};
Map<String, dynamic> directory({int page = 1, int count = 30, List<Object?>? rows}) => {
  'current_page': page,
  'last_page': 2,
  'per_page': count,
  'total': 40,
  'next_page_url': 'https://untrusted.example/ignored',
  'data': rows ?? [channel()],
};
Map<String, dynamic> categories() => {
  'categories': [
    {'id': 10, 'label': 'Comic', 'online_channels': 3},
    {'id': 33, 'label': 'Drawing', 'online_channels': 2},
  ],
  'languages': [],
  'video_categories': [],
};
Matcher failure(PicartoFailure kind) => throwsA(isA<PicartoException>().having((e) => e.kind, 'kind', kind));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('production Dio transport streams bounded UTF-8 and retains HTTP classification', () async {
    final previous = core.HttpClient.instance.dio;
    final adapter = _ResponseAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    core.HttpClient.instance.dio = dio;
    try {
      final api = PicartoApi();
      adapter.body = ResponseBody.fromString(jsonEncode(directory()), 200);
      expect((await api.directory()).single.roomId, 'Artist');
      expect(adapter.request!.headers['Origin'], PicartoApi.origin);
      expect(adapter.request!.responseType, ResponseType.stream);
      adapter.body = ResponseBody.fromString('secret', 429);
      await expectLater(api.directory(), failure(PicartoFailure.rateLimited));
      adapter.body = ResponseBody.fromString('x' * (1024 * 1024 + 1), 200);
      await expectLater(api.directory(), failure(PicartoFailure.schema));
      adapter.body = ResponseBody(Stream.value(Uint8List.fromList([255])), 200);
      await expectLater(api.directory(), failure(PicartoFailure.schema));
    } finally {
      core.HttpClient.instance.dio = previous;
      dio.close(force: true);
    }
  });
  test('registry exposes strict recording, refresh and recovery; web search and no remote chat', () {
    expect(Sites.isSupported(' PICARTO '), isTrue);
    final site = Sites.of('picarto').liveSite;
    expect(site, isA<PicartoSite>());
    expect(site, isA<LiveSiteRecordRoomResolver>());
    expect(site, isA<LiveSiteRoomRefresher>());
    expect(site, isA<LivePlayRecoveryResolver>());
    expect(site, isA<LiveSiteDirectoryPager>());
    expect(Sites.supportSites.where((s) => s.id == 'picarto'), hasLength(1));
    final capability = LiveSearchCapabilities.forPlatform('picarto');
    expect(capability.supportsNativeSearch, isFalse);
    expect(capability.supportsWebSearch, isTrue);
    expect(MultiviewDanmakuSession.isSupportedPlatform('picarto'), isFalse);
  });

  test('room share parsing accepts exact hosts and one decoded channel segment', () async {
    for (final url in ['https://picarto.tv/Artist', 'http://www.picarto.tv/Artist/?ref=share']) {
      expect(WebSearchRoomParser.parse(url)?.roomId, 'Artist');
      expect(await LiveUrlTool.parseLiveUrl('Check $url'), ['Artist', 'picarto']);
      expect(LiveUrlTool.containsSupportedLink(url), isTrue);
    }
    for (final url in [
      'https://picarto.tv.exampler.org/Artist',
      'https://evil.picarto.tv/Artist',
      'https://user@picarto.tv/Artist',
      'https://picarto.tv:123/Artist',
      'ftp://picarto.tv/Artist',
      'https://picarto.tv/search?q=Artist',
      'https://picarto.tv/explore',
      'https://picarto.tv/Artist/videos',
      'https://picarto.tv//Artist',
      'https://picarto.tv/Artist%2Fvideos',
      'https://picarto.tv/%GG',
    ]) {
      expect(PicartoApi.channelFromUri(Uri.parse(url)), isNull, reason: url);
    }
  });

  test('directory has exactly one bounded request, real audience and explicit adult filter', () async {
    var calls = 0;
    final api = PicartoApi(
      request: (uri, _) async {
        calls++;
        expect(uri.host, 'ptvintern.picarto.tv');
        expect(uri.queryParameters['first'], '10');
        expect(uri.queryParameters['page'], '2');
        expect(uri.queryParameters['filter_params[adult]'], 'false');
        return (status: 200, body: jsonEncode(directory(page: 2, count: 10)));
      },
    );
    final room = (await api.directory(page: 2, pageSize: 10)).single;
    expect(calls, 1);
    expect(room.roomId, 'Artist');
    expect(room.userId, '15237');
    expect(room.onlineViewers, '15');
    expect(room.totalViewers, '95434');
    expect(room.area, 'Comic');
    expect(room.liveStatus, LiveStatus.live);
    expect(LiveRoom.audienceCapabilityFor('picarto').onlineAvailableInRoomLists, isTrue);
    expect(LiveRoom.audienceCapabilityFor('picarto').hasTotalViewers, isTrue);
  });

  test('directory deduplicates and excludes explicit adult and offline rows', () async {
    final api = PicartoApi(
      request: (_, _) async => (
        status: 200,
        body: jsonEncode(
          directory(
            rows: [
              channel(),
              channel(),
              {...channel(name: 'Adult'), 'adult': true},
              channel(name: 'Offline', online: false),
            ],
          ),
        ),
      ),
    );
    expect((await api.directory()).map((r) => r.roomId), ['Artist']);
  });

  test('official live category metadata has stable IDs and no fabricated audience', () async {
    var calls = 0;
    final api = PicartoApi(
      request: (uri, _) async {
        calls++;
        expect(uri.path, '/api/languages-categories');
        return (status: 200, body: jsonEncode(categories()));
      },
    );
    final result = await api.categories();
    expect(calls, 1);
    expect(result.map((area) => [area.platform, area.areaType, area.areaId, area.areaName]), [
      ['picarto', 'category', '10', 'Comic'],
      ['picarto', 'category', '33', 'Drawing'],
    ]);
  });

  test('category pages use the official filter and server pagination, even for short rows', () async {
    final requests = <Uri>[];
    final api = PicartoApi(
      request: (uri, _) async {
        requests.add(uri);
        return (status: 200, body: jsonEncode(directory(page: int.parse(uri.queryParameters['page']!), count: 30)));
      },
    );
    final category = LiveArea(platform: 'picarto', areaType: 'category', areaId: '10', areaName: 'Comic');
    final first = await api.directoryPage(category: category);
    final second = await api.directoryPage(page: 2, category: category);
    expect(first.rooms.single.roomId, 'Artist');
    expect(first.hasMore, isTrue);
    expect(second.hasMore, isFalse);
    expect(requests, hasLength(2));
    for (final uri in requests) {
      expect(uri.queryParameters['filter_params[categories]'], '10: true');
      expect(uri.queryParameters['filter_params[adult]'], 'false');
      expect(uri.queryParameters['filter_params[languages]'], '');
      expect(uri.queryParameters['type'], 'stream');
    }
  });

  test('category identity and server category mismatch fail before presenting a false match', () async {
    var calls = 0;
    final api = PicartoApi(
      request: (_, _) async {
        calls++;
        return (status: 200, body: jsonEncode(directory()));
      },
    );
    for (final category in [
      LiveArea(platform: 'other', areaType: 'category', areaId: '10'),
      LiveArea(platform: 'picarto', areaType: 'directory', areaId: '10'),
      LiveArea(platform: 'picarto', areaType: 'category', areaId: '010'),
      LiveArea(platform: 'picarto', areaType: 'category', areaId: 'abc'),
    ]) {
      await expectLater(api.directoryPage(category: category), failure(PicartoFailure.schema));
    }
    expect(calls, 0);
    await expectLater(
      api.directoryPage(
        category: LiveArea(platform: 'picarto', areaType: 'category', areaId: '33'),
      ),
      failure(PicartoFailure.schema),
    );
    expect(calls, 1);
  });

  test('malformed category metadata is surfaced rather than an empty catalogue', () async {
    for (final data in [
      <String, dynamic>{},
      {'categories': []},
      {
        'categories': [
          {'id': 10, 'label': ''},
        ],
      },
      {
        'categories': [
          {'id': 10, 'label': 'Comic'},
          {'id': 10, 'label': 'Comic'},
        ],
      },
    ]) {
      final api = PicartoApi(request: (_, _) async => (status: 200, body: jsonEncode(data)));
      await expectLater(api.categories(), failure(PicartoFailure.schema));
    }
  });

  test('invalid pagination is rejected without network I/O', () async {
    var calls = 0;
    final api = PicartoApi(
      request: (_, _) async {
        calls++;
        return (status: 200, body: '{}');
      },
    );
    for (final input in [(0, 30), (10001, 30), (1, 0), (1, 61)]) {
      await expectLater(api.directory(page: input.$1, pageSize: input.$2), failure(PicartoFailure.schema));
    }
    expect(calls, 0);
  });

  test('schema drift, mismatched pages and overfull pages are not empty success', () async {
    for (final data in [
      <String, dynamic>{},
      {...directory(), 'current_page': 2},
      {...directory(), 'per_page': 10},
      {...directory(), 'total': null},
      {...directory(), 'data': {}},
      directory(rows: List.generate(31, (_) => channel())),
      directory(
        rows: [
          {...channel(), 'adult': null},
        ],
      ),
    ]) {
      final api = PicartoApi(request: (_, _) async => (status: 200, body: jsonEncode(data)));
      await expectLater(api.directory(), failure(PicartoFailure.schema));
    }
  });

  test('metadata refresh selects matching second stream and never reads HLS', () async {
    final calls = <Uri>[];
    final api = PicartoApi(
      request: (uri, _) async {
        calls.add(uri);
        return (status: 200, body: jsonEncode(detail()));
      },
    );
    final parsed = await api.detail('artist');
    expect(parsed.master, masterUri);
    expect(parsed.room.cover, 'https://thumb.picarto.tv/Artist.jpg');
    expect(calls.single.path, '/api/channel/detail/artist');
    final room = await PicartoSite(api: api).getRoomDetailForRefresh(roomId: 'Artist', platform: 'picarto');
    expect(room.data, isNull);
    expect(calls, hasLength(2));
  });

  test('explicit offline is the only offline result and needs no load balancer', () async {
    final api = PicartoApi(
      request: (_, _) async => (status: 200, body: jsonEncode({'channel': channel(online: false)})),
    );
    final site = PicartoSite(api: api);
    final room = await site.getRoomDetail(roomId: 'Artist', platform: 'picarto');
    expect(room.isExplicitlyOfflineNow, isTrue);
    expect(await site.getPlayQualites(detail: room), isEmpty);
    await expectLater(
      StreamResolverService(siteResolver: (_) => site)
          .resolveStream(roomId: 'Artist', platform: 'picarto', preferredQuality: ''),
      throwsA(
        isA<StreamException>()
            .having((e) => e.type, 'type', StreamErrorType.notLive)
            .having((e) => e.retryable, 'retryable', isFalse),
      ),
    );
  });

  for (final (status, kind) in [
    (401, PicartoFailure.access),
    (403, PicartoFailure.access),
    (404, PicartoFailure.notFound),
    (429, PicartoFailure.rateLimited),
    (503, PicartoFailure.service),
  ]) {
    test('HTTP $status is $kind, never an offline card or leaked body', () async {
      final api = PicartoApi(request: (_, _) async => (status: status, body: 'secret-cookie'));
      await expectLater(api.detail('Artist'), failure(kind));
      expect(PicartoException(kind).toString(), isNot(contains('secret-cookie')));
    });
  }

  test('private rooms, including private offline rooms, are access failures', () async {
    for (final online in [true, false]) {
      final api = PicartoApi(
        request: (_, _) async => (
          status: 200,
          body: jsonEncode({
            'channel': {...channel(online: online), 'private': true},
          }),
        ),
      );
      await expectLater(api.detail('Artist'), failure(PicartoFailure.access));
    }
  });

  test('missing identity, ambiguous state, missing stream and origin injection stay errors', () async {
    for (final data in [
      <String, dynamic>{},
      {
        ...detail(),
        'channel': {...channel(), 'online': null},
      },
      detail(name: 'Other'),
      {
        ...detail(),
        'channel': {...channel(), 'private': null},
      },
      {...detail(), 'getLoadBalancerUrl': null},
      {
        ...detail(),
        'getMultiStreams': {'streams': []},
      },
      detail(origin: 'edge/../../other'),
      detail(origin: 'edge.evil'),
      {
        ...detail(),
        'getMultiStreams': {
          'streams': [
            {'channelId': 15237, 'stream_name': '../secret'},
          ],
        },
      },
    ]) {
      final api = PicartoApi(request: (_, _) async => (status: 200, body: jsonEncode(data)));
      await expectLater(api.detail('Artist'), failure(PicartoFailure.schema));
    }
  });

  test('request cancellation is passed through and late success discarded', () async {
    final barrier = Completer<({int status, String body})>();
    final token = CancelToken();
    final api = PicartoApi(
      request: (_, cancel) {
        expect(cancel, same(token));
        return barrier.future;
      },
    );
    final request = api.directory(cancel: token);
    final rejected = expectLater(request, failure(PicartoFailure.cancelled));
    token.cancel();
    barrier.complete((status: 200, body: jsonEncode(directory())));
    await rejected;
    await expectLater(api.directory(cancel: token), failure(PicartoFailure.cancelled));
  });

  test('overlapping room reads have no shared current-room cache', () async {
    final first = Completer<({int status, String body})>();
    final api = PicartoApi(
      request: (uri, _) async =>
          uri.path.endsWith('/First') ? first.future : (status: 200, body: jsonEncode(detail(name: 'Second'))),
    );
    final old = api.detail('First');
    final newer = await api.detail('Second');
    first.complete((status: 200, body: jsonEncode(detail(name: 'First'))));
    expect(newer.room.roomId, 'Second');
    expect((await old).room.roomId, 'First');
    expect(newer.master.toString(), contains('golive+Second'));
  });

  test('HLS pairs quoted attributes and relative URI with declared resolution and fps', () {
    final quality = parsePicartoHls(masterText, masterUri).single;
    expect(quality.quality, '720p 60fps');
    expect(quality.data, [masterUri.resolve('variant.m3u8').toString()]);
    expect(quality.sort, 3661056);
    expect(quality.selectionId.toString(), contains('avc1.640020,mp4a.40.2'));
  });

  test('HLS quality identity survives bandwidth and host renewal, groups duplicate profiles', () {
    final one = parsePicartoHls(masterText, masterUri).single;
    final renewed = parsePicartoHls(
      masterText.replaceAll('3661056', '4000000'),
      Uri.parse('https://edge2.picarto.tv/new/master.m3u8'),
    ).single;
    expect(renewed.selectionId, one.selectionId);
    expect(renewed.data, ['https://edge2.picarto.tv/new/variant.m3u8']);
    final multiple = parsePicartoHls(
      '$masterText${masterText.substring(8).replaceAll('variant.m3u8', 'other.m3u8')}\n',
      masterUri,
    );
    expect(multiple, hasLength(1));
    expect(multiple.single.data, hasLength(2));
  });

  test('external audio keeps a master instead of silently dropping the audio track', () {
    final qualities = parsePicartoHls(
      '#EXTM3U\n#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",URI="audio.m3u8"\n${masterText.substring(8)}',
      masterUri,
    );
    expect(qualities.single.quality, 'HLS Auto');
    expect(qualities.single.data, [masterUri.toString()]);
  });

  test('HTML, empty, dangling variants, invalid numbers and non-HTTP URIs fail HLS parsing', () {
    for (final raw in [
      '',
      '<html>error</html>',
      '#EXTM3U',
      '#EXTM3Ugarbage\n$masterText',
      '#EXTM3U\n#EXTINF:2,\n',
      masterText.replaceAll('variant.m3u8', ''),
      masterText.replaceAll('3661056', '0'),
      masterText.replaceAll('60,CODECS', 'NaN,CODECS'),
      masterText.replaceAll('1280x720', 'abc'),
      masterText.replaceAll('variant.m3u8', 'file:///secret'),
      masterText.replaceAll('variant.m3u8', 'https://user@host/media.m3u8'),
    ]) {
      expect(() => parsePicartoHls(raw, masterUri), failure(PicartoFailure.schema));
    }
  });

  test('valid media playlist remains a single auto source and unknown profiles stay distinct', () {
    expect(parsePicartoHls('#EXTM3U\n#EXT-X-TARGETDURATION:2\n#EXTINF:2,\nchunk.ts\n', masterUri).single.data, [
      masterUri.toString(),
    ]);
    final noResolution = masterText.replaceAll('RESOLUTION=1280x720,', '');
    final two = parsePicartoHls(
      '$noResolution${noResolution.substring(8).replaceAll('3661056', '1000000')}',
      masterUri,
    );
    expect(two, hasLength(2));
  });

  test('production site resolves a recorder input and recovery reacquires detail and HLS', () async {
    var details = 0;
    var playlists = 0;
    final site = PicartoSite(
      api: PicartoApi(
        request: (uri, _) async {
          if (uri.host == 'ptvintern.picarto.tv') {
            return (status: 200, body: jsonEncode(detail(origin: 'edge${++details}')));
          }
          playlists++;
          return (status: 200, body: masterText);
        },
      ),
    );
    final room = await site.getRoomDetail(roomId: 'Artist', platform: 'picarto');
    final quality = (await site.getPlayQualites(detail: room)).single;
    final recovered = await site.resolvePlayUrlsForRecovery(detail: room, quality: quality);
    expect(recovered.urls.single, contains('edge2.picarto.tv'));
    expect((await site.getPlayUrls(detail: room, quality: quality)).single, contains('edge1.picarto.tv'));
    final recorded = await StreamResolverService(siteResolver: (_) => site)
        .resolveStream(roomId: 'Artist', platform: 'picarto', preferredQuality: 'best');
    expect(recorded.url, contains('edge3.picarto.tv'));
    expect(recorded.quality.selectionId, quality.selectionId);
    expect(playlists, 3);
    expect(details, 3);
    await expectLater(
      site.getPlayUrls(
        detail: room,
        quality: LivePlayQuality(id: 'missing', quality: 'fake'),
      ),
      failure(PicartoFailure.qualityUnavailable),
    );
    final headers = await PlaybackHeaderResolver.resolve(platform: 'picarto', roomId: 'Artist');
    expect(headers, await FFmpegHeaderFactory.build(platform: 'picarto', roomId: 'Artist'));
    expect(headers['origin'], 'https://picarto.tv');
    expect(headers.containsKey('cookie'), isFalse);
  });

  test('recording treats malformed metadata as retryable rather than an offline stop', () async {
    final site = PicartoSite(api: PicartoApi(request: (_, _) async => (status: 200, body: '{}')));
    await expectLater(
      StreamResolverService(siteResolver: (_) => site)
          .resolveStream(roomId: 'Artist', platform: 'picarto', preferredQuality: ''),
      throwsA(
        isA<StreamException>()
            .having((e) => e.type, 'type', StreamErrorType.networkError)
            .having((e) => e.retryable, 'retryable', isTrue),
      ),
    );
  });

  test('site exposes native categories, public directory and category-aware pager', () async {
    final site = PicartoSite(
      api: PicartoApi(
        request: (uri, _) async => (
          status: 200,
          body: jsonEncode(
            uri.path == '/api/languages-categories'
                ? categories()
                : directory(page: int.parse(uri.queryParameters['page']!)),
          ),
        ),
      ),
    );
    final children = (await site.getCategores(1, 30)).single.children;
    expect(children.map((area) => area.areaId), ['live', '10', '33']);
    expect(children.map((area) => area.areaType), ['directory', 'category', 'category']);
    expect((await site.getCategoryRooms(children.first)).single.roomId, 'Artist');
    expect((await site.getCategoryRooms(children[1])).single.roomId, 'Artist');
    expect((await site.getDirectoryPage(category: children[1])).hasMore, isTrue);
    expect((await site.getDirectoryPage(page: 2, category: children.first)).hasMore, isFalse);
    expect(await site.getCategores(2, 30), isEmpty);
    expect(() => site.getCategoryRooms(LiveArea(platform: 'other', areaId: 'live')), failure(PicartoFailure.schema));
  });

  test('checked-in sanitized real response retains the multi-stream and playlist contract', () async {
    final data = File('test/fixtures/picarto/detail.json').readAsStringSync();
    final api = PicartoApi(request: (_, _) async => (status: 200, body: data));
    final result = await api.detail('FixtureArtist');
    expect(result.room.userId, '15237');
    expect(result.master!.path, '/stream/hls/golive+FixtureArtist/index.m3u8');
    final hls = File('test/fixtures/picarto/master.m3u8').readAsStringSync();
    expect(parsePicartoHls(hls, result.master!).single.quality, '720p 60fps');
  });
}

class _ResponseAdapter implements HttpClientAdapter {
  late ResponseBody body;
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return body;
  }

  @override
  void close({bool force = false}) {}
}
