import 'dart:convert' show jsonEncode, utf8;

import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/modules/music/controller/sources/lx_script_runtime.dart';
import 'package:pure_live/modules/music/controller/sources/music_source_wy.dart';

/// The Netease platform's mapping and its lyric walk, argued over a stub
/// transport (the sealed bodies come back as plain JSON): the search rows
/// map the rate the privilege names into the tier list, a hires badge
/// lifts the top tier, the boards read the playlist body and open only a
/// first page, and the lyric walk prefers the word-timed answer and mends
/// the plain one's two-digit stamps.
void main() {
  late _Stub http;
  late WyMusicSource wy;

  setUp(() {
    http = _Stub();
    final runtime = LxScriptRuntime(transport: http); // no scripts: the tiers come from the rows themselves
    wy = WyMusicSource(runtime, http);
  });

  Map<String, Object?> song({
    String id = '101',
    String name = '晴天',
    int maxbr = 320000,
    String maxBrLevel = '',
    Object? privilege,
  }) {
    final inner = {
      'id': id,
      'name': name,
      'ar': [
        {'name': '周杰伦', 'id': 31},
        {'name': '阿信', 'id': 32},
      ],
      'al': {'name': '叶惠美', 'id': 9001, 'picUrl': 'https://p1.music.126.net/cover.jpg'},
      'dt': 269000,
      'privilege': privilege ?? {'maxbr': 320000},
    };
    return inner;
  }

  group('the search mapping', () {
    test('a row maps the privilege rate into the tier list', () async {
      http.route(
        '/eapi/batch',
        _jsonFuture({
          'code': 200,
          'data': {
            'totalCount': 45,
            'resources': [
              {
                'baseInfo': {'simpleSongData': song()},
              },
            ],
          },
        }),
      );

      final page = await wy.search('晴天');
      final track = page.items.single;
      expect(track.id, '101');
      expect(track.title, '晴天');
      expect(track.artist, '周杰伦、阿信');
      expect(track.album, '叶惠美');
      expect(track.albumId, '9001');
      expect(track.duration, const Duration(seconds: 269)); // the milliseconds field
      expect(track.coverUri.toString(), 'https://p1.music.126.net/cover.jpg');

      // 320000 br names the two plain tiers, never the lossless one.
      expect(track.qualities, [audio.MusicQuality.k128, audio.MusicQuality.k320]);
      expect(track.metadata['types'], ['128k', '320k']);
      expect(track.metadata['artistId'], '31');
      expect(page.total, 45);
      expect(page.hasMore, isTrue);
    });

    test('a hires badge lifts the top tier, and a refused code is an empty page', () async {
      http.route(
        '/eapi/batch',
        _jsonFuture({
          'code': 200,
          'data': {
            'totalCount': 1,
            'resources': [
              {
                'baseInfo': {
                  'simpleSongData': song(privilege: {'maxbr': 999000, 'maxBrLevel': 'hires'}),
                },
              },
            ],
          },
        }),
      );
      final hires = await wy.search('晴天');
      expect(hires.items.single.qualities, [
        audio.MusicQuality.k128,
        audio.MusicQuality.k320,
        audio.MusicQuality.flac,
        audio.MusicQuality.flac24bit,
      ]);

      http.route('/eapi/batch', _jsonFuture({'code': 401, 'data': null}));
      final refused = await wy.search('晴天');
      expect(refused.items, isEmpty);
      expect(refused.hasMore, isFalse);
    });
  });

  group('the boards', () {
    test('the playlist body maps, and only a first page exists', () async {
      http.route(
        '/weapi/v3/playlist/detail',
        _jsonFuture({
          'code': 200,
          'playlist': {
            'tracks': [song()],
          },
        }),
      );

      final first = await wy.catalogItems(const audio.MusicCatalog(id: 'wy:19723756', name: '飙升榜'));
      expect(first.items.single.id, '101');

      final second = await wy.catalogItems(const audio.MusicCatalog(id: 'wy:19723756', name: '飙升榜'), page: 2);
      expect(second.items, isEmpty); // the board walks no further pages
      expect(http.calls.where((uri) => uri.path.contains('playlist/detail')), hasLength(1));
    });
  });

  group('the lyric walk', () {
    test('the word-timed answer wins, its second tracks riding along', () async {
      http.route(
        '/eapi/song/lyric/v1',
        _jsonFuture({
          'code': 200,
          'yrc': {'lyric': '[1000,2000](0,500,0)一(500,1500,0)句'},
          'ytlrc': {'lyric': '[00:01.000]一句译文'},
          'yromalrc': {'lyric': '[00:01.000]yi ju'},
        }),
      );

      final payload = await wy.resolveLyric(_track());
      expect(payload!.lyric.startsWith('[00:01.000]'), isTrue, reason: payload.lyric); // the lrc reader's shape
      expect(payload.lyric, contains('<0,500>一'));
      expect(payload.translation, '[00:01.000]一句译文');
      expect(payload.romanization, '[00:01.000]yi ju');
    });

    test('without a word track the plain lyric answers, its stamps mended', () async {
      http.route(
        '/eapi/song/lyric/v1',
        _jsonFuture({
          'code': 200,
          'lrc': {'lyric': '[01:23:45]旧戳\n[02:03:04]第二行'},
          'tlyric': {'lyric': '[01:23:45]译文'},
        }),
      );

      final payload = await wy.resolveLyric(_track());
      // The station's third colon is two-digit centiseconds; left as a third
      // colon the reader reads the pair as hours.
      expect(payload!.lyric, '[01:23.45]旧戳\n[02:03.04]第二行');
      expect(payload.translation, '[01:23.45]译文');
    });

    test('nothing to read answers null', () async {
      http.route(
        '/eapi/song/lyric/v1',
        _jsonFuture({
          'code': 200,
          'lrc': {'lyric': '  '},
        }),
      );
      expect(await wy.resolveLyric(_track()), isNull);

      http.route('/eapi/song/lyric/v1', _jsonFuture({'code': 512}));
      expect(await wy.resolveLyric(_track()), isNull);
    });
  });
}

audio.MusicTrack _track() => const audio.MusicTrack(
  id: '101',
  sourceId: 'wy',
  title: '晴天',
  artist: '周杰伦',
  album: '叶惠美',
  duration: Duration(seconds: 269),
  metadata: {'hash': ''},
);

Future<LiveResponse> Function(Uri) _jsonFuture(Object json) =>
    (url) async => _ok(jsonEncode(json));

LiveResponse _ok(String body) => LiveResponse(statusCode: 200, headers: const {}, bodyBytes: utf8.encode(body));

/// The transport the Netease tests code against: routes by a path fragment
/// and remembers every ask. The sealed request bodies stay sealed — the
/// answers are the plain JSON the platform writes back.
final class _Stub implements LiveHttp {
  final calls = <Uri>[];
  final Map<String, Future<LiveResponse> Function(Uri url)> _routes = {};

  /// Answers every call whose path carries [fragment] with [answer].
  void route(String fragment, Future<LiveResponse> Function(Uri url) answer) => _routes[fragment] = answer;

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    calls.add(request.url);
    for (final route in _routes.entries) {
      if (request.url.path.contains(route.key)) return await route.value(request.url);
    }
    throw StateError('the stub holds no answer for ${request.url.path}');
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}
}
