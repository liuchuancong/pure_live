import 'dart:convert' show jsonEncode, utf8;

import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/modules/music/controller/sources/lx_script_runtime.dart';
import 'package:pure_live/modules/music/controller/sources/music_source_tx.dart';

/// The QQ-music platform's mapping and its gates, argued over a stub
/// transport: the signed search maps the file sizes into the tier list and
/// the album mid into a cover, a row without its ids never lands,
/// the boards open a first page only, the lyric walk refuses without a
/// song id and treats an unreadable body as no lyric, and the hot words
/// keep their own order.
void main() {
  late _Stub http;
  late TxMusicSource tx;

  setUp(() {
    http = _Stub();
    final runtime = LxScriptRuntime(transport: http); // no scripts: the tiers come from the rows themselves
    tx = TxMusicSource(runtime, http);
  });

  Map<String, Object?> row({
    String mid = '001A',
    String title = '晴天',
    String mediaMid = 'mm1',
    int flac = 0,
    int hires = 0,
    String albumMid = 'alb1',
    String albumName = '叶惠美',
  }) => {
    'mid': mid,
    'title': title,
    'singer': [
      {'name': '周杰伦', 'mid': 's31'},
      {'name': '阿信', 'mid': 's32'},
    ],
    'album': {'name': albumName, 'mid': albumMid},
    'interval': 269,
    'id': 977,
    'file': {'media_mid': mediaMid, 'size_128mp3': 3000, 'size_320mp3': 8000, 'size_flac': flac, 'size_hires': hires},
  };

  group('the zzc signature', () {
    test('the same body signs the same lowercase stamp, clean of url marks', () {
      final one = zzcSign('{"query":"晴天"}');
      final again = zzcSign('{"query":"晴天"}');
      expect(one, again); // deterministic
      expect(one.startsWith('zzc'), isTrue);
      expect(one, one.toLowerCase());
      expect(one.contains('/'), isFalse); // the url marks stripped
      expect(one.contains('='), isFalse);
      expect(one.contains('+'), isFalse);

      final other = zzcSign('{"query":"夜曲"}');
      expect(other, isNot(one)); // a different body signs differently
    });
  });

  group('the search mapping', () {
    test('a row maps its file sizes into the tier list and its album into a cover', () async {
      http.route(
        'musics.fcg',
        _jsonFuture({
          'code': 0,
          'music.search.SearchCgiService': {
            'code': 0,
            'data': {
              'meta': {'sum': 45},
              'body': {
                'song': {
                  'list': [row()],
                },
              },
            },
          },
        }),
      );

      final page = await tx.search('晴天');
      final track = page.items.single;
      expect(track.id, '001A');
      expect(track.title, '晴天');
      expect(track.artist, '周杰伦、阿信');
      expect(track.album, '叶惠美');
      expect(track.albumId, 'alb1');
      expect(track.duration, const Duration(seconds: 269));
      expect(track.coverUri.toString(), 'https://y.gtimg.cn/music/photo_new/T002R500x500M000alb1.jpg');

      expect(track.qualities, [audio.MusicQuality.k128, audio.MusicQuality.k320]); // the empty flac never counts
      expect(track.metadata['types'], ['128k', '320k']);
      expect(track.metadata['songId'], '977');
      expect(track.metadata['mediaMid'], 'mm1');
      expect(track.metadata['artistId'], 's31');
      expect(track.metadata['artistPic'], 'https://y.gtimg.cn/music/photo_new/T001R500x500M000s31.jpg');
      expect(track.metadata['pic'], 'https://y.gtimg.cn/music/photo_new/T002R500x500M000alb1.jpg');

      expect(page.total, 45);
      expect(page.hasMore, isTrue);
    });

    test('a row without its ids never lands, and the gates refuse', () async {
      http.route(
        'musics.fcg',
        _jsonFuture({
          'code': 0,
          'music.search.SearchCgiService': {
            'code': 0,
            'data': {
              'meta': {'sum': 1},
              'body': {
                'song': {
                  'list': [row(mediaMid: ''), row(mid: '')],
                },
              },
            },
          },
        }),
      );
      final midLess = await tx.search('晴天');
      expect(midLess.items, isEmpty); // no media mid, no song mid: both drop

      http.route('musics.fcg', _jsonFuture({'code': 1}));
      final refused = await tx.search('晴天');
      expect(refused.items, isEmpty);

      http.route(
        'musics.fcg',
        _jsonFuture({
          'code': 0,
          'music.search.SearchCgiService': {'code': 500, 'data': null},
        }),
      );
      final slotRefused = await tx.search('晴天');
      expect(slotRefused.items, isEmpty);
    });

    test('an album the station left unnamed wears no cover', () async {
      http.route(
        'musics.fcg',
        _jsonFuture({
          'code': 0,
          'music.search.SearchCgiService': {
            'code': 0,
            'data': {
              'meta': {'sum': 1},
              'body': {
                'song': {
                  'list': [row(albumName: '空')],
                },
              },
            },
          },
        }),
      );
      final page = await tx.search('晴天');
      final track = page.items.single;
      expect(track.coverUri, isNull);
      expect(track.metadata.containsKey('pic'), isFalse);
    });
  });

  group('the boards', () {
    test('the board maps its rows, and only a first page exists', () async {
      http.route(
        'musicu.fcg',
        _jsonFuture({
          'code': 0,
          'toplist': {
            'code': 0,
            'data': {
              'songInfoList': [row(mid: '002B', title: '夜曲')],
            },
          },
        }),
      );

      final first = await tx.catalogItems(const audio.MusicCatalog(id: 'tx:26', name: '热歌榜'));
      expect(first.items.single.id, '002B');

      final second = await tx.catalogItems(const audio.MusicCatalog(id: 'tx:26', name: '热歌榜'), page: 2);
      expect(second.items, isEmpty); // the board walks no further pages
      expect(http.calls.where((uri) => uri.path.contains('musicu.fcg')), hasLength(1));
    });
  });

  group('the lyric walk', () {
    test('a track without its song id refuses before asking', () async {
      // No metadata at all: no songId for the ask to carry.
      const track = audio.MusicTrack(id: '001A', sourceId: 'tx', title: '晴天');
      final payload = await tx.resolveLyric(track);
      expect(payload, isNull);
      expect(http.calls, isEmpty); // nothing went out
    });

    test('a refused ask and an unreadable body answer null', () async {
      http.route('musicu.fcg', _jsonFuture({'code': 1}));
      final refused = await tx.resolveLyric(_songTrack());
      expect(refused, isNull);

      http.route(
        'musicu.fcg',
        _jsonFuture({
          'code': 0,
          'req': {
            'code': 0,
            'data': {'lyric': 'not-a-qrc-body', 'trans': '', 'roma': ''},
          },
        }),
      );
      final unreadable = await tx.resolveLyric(_songTrack());
      expect(unreadable, isNull); // the body the reader cannot open is no lyric
    });
  });

  group('the hot words', () {
    test('the chart keeps its order and drops the blank words', () async {
      http.route(
        'musicu.fcg',
        _jsonFuture({
          'code': 0,
          'hotkey': {
            'data': {
              'vec_hotkey': [
                {'query': '晴天'},
                {'query': '  '},
                {'query': ' 夜曲 '},
              ],
            },
          },
        }),
      );
      final words = await tx.hotSearches();
      expect(words, ['晴天', '夜曲']); // trimmed, blanks gone, order kept

      http.route('musicu.fcg', _jsonFuture({'code': 1}));
      expect(await tx.hotSearches(), isEmpty);
    });
  });
}

audio.MusicTrack _songTrack() => const audio.MusicTrack(
  id: '001A',
  sourceId: 'tx',
  title: '晴天',
  artist: '周杰伦',
  album: '叶惠美',
  duration: Duration(seconds: 269),
  metadata: {'songId': '977', 'mediaMid': 'mm1'},
);

Future<LiveResponse> Function(Uri) _jsonFuture(Object json) =>
    (url) async => _ok(jsonEncode(json));

LiveResponse _ok(String body) => LiveResponse(statusCode: 200, headers: const {}, bodyBytes: utf8.encode(body));

/// The transport the QQ-music tests code against: routes by a path fragment
/// and remembers every ask.
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
