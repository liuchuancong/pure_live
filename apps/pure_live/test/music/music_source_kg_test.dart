import 'dart:convert' show base64, base64Encode, jsonEncode, utf8;
import 'dart:io' show ZLibEncoder;
import 'dart:typed_data' show Uint8List;

import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/modules/music/controller/sources/lx_script_runtime.dart';
import 'package:pure_live/modules/music/controller/sources/music_source_kg.dart';

/// The KuGou platform's mapping and its lyric walk, argued over a stub
/// transport: the search rows map their hashes into the tier list a play
/// ask walks (the Grp children riding along, deduped), the boards map
/// their own row shape, and the lyric walk prefers a KRC candidate,
/// falls back to the plain one and answers null when neither offers
/// anything to read.
void main() {
  late _Stub http;
  late KgMusicSource kg;

  setUp(() {
    http = _Stub();
    final runtime = LxScriptRuntime(transport: http); // no scripts: the tiers come from the rows themselves
    kg = KgMusicSource(runtime, http);
  });

  Map<String, Object?> row({
    String id = '101',
    String name = '晴天',
    List<Map<String, Object?>>? singers,
    String album = '叶惠美',
    String albumId = '9001',
    String hash128 = 'h128',
    String hash320 = 'h320',
    int duration = 269,
  }) => {
    'Audioid': id,
    'OriSongName': name,
    'Singers':
        singers ??
        [
          {'name': '周杰伦', 'id': 31},
          {'name': '阿信', 'id': 32},
        ],
    'AlbumName': album,
    'AlbumID': albumId,
    'FileSize': 3000,
    'FileHash': hash128,
    'HQFileSize': 8000,
    'HQFileHash': hash320,
    'SQFileSize': 0,
    'SQFileHash': '',
    'Duration': duration,
    'AlbumImage': 'https://imge.kugou.com/stdmusic/{size}/cover.jpg',
  };

  group('the search mapping', () {
    test('a row maps its hashes into the tier list the play ask walks', () async {
      http.route(
        'song_search_v2',
        _jsonFuture({
          'error_code': 0,
          'data': {
            'total': 31,
            'lists': [row()],
          },
        }),
      );

      final page = await kg.search('晴天');
      final track = page.items.single;
      expect(track.id, '101');
      expect(track.title, '晴天');
      expect(track.artist, '周杰伦、阿信'); // the credits join the station's way
      expect(track.album, '叶惠美');
      expect(track.albumId, '9001');
      expect(track.duration, const Duration(seconds: 269));
      expect(track.coverUri.toString(), 'https://imge.kugou.com/stdmusic/480/cover.jpg'); // the {size} filled

      // The hashes are the tier list: the empty flac never counts.
      expect(track.qualities, [audio.MusicQuality.k128, audio.MusicQuality.k320]);
      expect(track.metadata['types'], ['128k', '320k']);
      expect(track.metadata['hash'], 'h128'); // the plain tier's hash leads
      expect(track.metadata['hashes'], {'128k': 'h128', '320k': 'h320'});
      expect(track.metadata['artistId'], '31'); // the credit list leads

      expect(page.total, 31);
      expect(page.hasMore, isTrue); // thirty read, thirty-one on the shelf
    });

    test('the Grp children ride along and a repeat never lands twice', () async {
      final main = row();
      final twin = row(); // the same seat again
      final child = row(
        id: '102',
        name: '晴天 (Live)',
        singers: [
          {'name': '周杰伦', 'id': 31},
        ],
      );
      http.route(
        'song_search_v2',
        _jsonFuture({
          'error_code': 0,
          'data': {
            'total': 2,
            'lists': [
              {
                ...main,
                'Grp': [child, twin],
              },
            ],
          },
        }),
      );

      final page = await kg.search('晴天');
      expect(page.items.map((track) => track.id), ['101', '102']); // the twin dropped
      expect(page.items.last.title, '晴天 (Live)');
    });

    test('a refused or shapeless answer is an empty page', () async {
      http.route('song_search_v2', _jsonFuture({'error_code': 30700, 'data': 'no'}));
      final refused = await kg.search('晴天');
      expect(refused.items, isEmpty);
      expect(refused.hasMore, isFalse);

      http.route('song_search_v2', _jsonFuture({'error_code': 0, 'data': null}));
      final shapeless = await kg.search('晴天');
      expect(shapeless.items, isEmpty);
    });
  });

  group('the boards', () {
    test('the board rows map their own shape, and an errcode refuses', () async {
      http.route(
        'rank/song',
        _jsonFuture({
          'errcode': 0,
          'data': {
            'total': 150,
            'info': [
              {
                'audio_id': '201',
                'songname': '夜曲',
                'authors': [
                  {'author_name': '周杰伦'},
                ],
                'remark': '十一月的萧邦',
                'album_id': '9002',
                'filesize': 3000,
                'hash': 'b128',
                'duration': 226,
              },
            ],
          },
        }),
      );

      final page = await kg.catalogItems(const audio.MusicCatalog(id: 'kg:8888', name: 'TOP500'));
      final track = page.items.single;
      expect(track.id, '201');
      expect(track.title, '夜曲');
      expect(track.artist, '周杰伦'); // the board spells its credits differently
      expect(track.album, '十一月的萧邦'); // the remark is the album's stand-in
      expect(track.metadata['hash'], 'b128');
      expect(page.hasMore, isTrue); // a hundred read, a hundred fifty ranked

      http.route('rank/song', _jsonFuture({'errcode': 1, 'data': null}));
      final refused = await kg.catalogItems(const audio.MusicCatalog(id: 'kg:8888', name: 'TOP500'));
      expect(refused.items, isEmpty);
    });
  });

  group('the lyric walk', () {
    test('a KRC candidate wins and its payload keeps the stations timestamps', () async {
      http
        ..route(
          '/search',
          _jsonFuture({
            'candidates': [
              {'id': 2, 'accesskey': 'k2', 'krctype': 0, 'contenttype': 0},
              {'id': 1, 'accesskey': 'k1', 'krctype': 1, 'contenttype': 0},
            ],
          }),
        )
        ..route('/download', (url) async {
          expect(url.queryParameters['fmt'], 'krc'); // the rich form asked first
          expect(url.queryParameters['id'], '1');
          return _ok(jsonEncode({'status': 200, 'content': _krcPayload('[0,3000]晴天\n[3000,2000]第二行\n')}));
        });

      final payload = await kg.resolveLyric(_track());
      expect(payload, isNotNull);
      expect(payload!.lyric, contains('[00:03.000]第二行')); // the milliseconds became stamps
    });

    test('without a KRC the plain candidate answers, decoded from its base64', () async {
      http
        ..route(
          '/search',
          _jsonFuture({
            'candidates': [
              {'id': 2, 'accesskey': 'k2', 'krctype': 0, 'contenttype': 0},
            ],
          }),
        )
        ..route('/download', (url) async {
          expect(url.queryParameters['fmt'], 'lrc');
          return _ok(jsonEncode({'status': 200, 'content': base64Encode(utf8.encode('[00:01.000]只有一行'))}));
        });

      final payload = await kg.resolveLyric(_track());
      expect(payload!.lyric, '[00:01.000]只有一行');
      expect(payload.translation, isNull);
    });

    test('nothing to read answers null, and a refused download is not a lyric', () async {
      http.route('/search', _jsonFuture({'candidates': <Object?>[]}));
      expect(await kg.resolveLyric(_track()), isNull);

      http
        ..route(
          '/search',
          _jsonFuture({
            'candidates': [
              {'id': 1, 'accesskey': 'k1', 'krctype': 1, 'contenttype': 0},
            ],
          }),
        )
        ..route('/download', _jsonFuture({'status': 500, 'content': 'junk'}));
      expect(await kg.resolveLyric(_track()), isNull); // the refused download falls away
    });
  });
}

audio.MusicTrack _track() => const audio.MusicTrack(
  id: '101',
  sourceId: 'kg',
  title: '晴天',
  artist: '周杰伦',
  album: '叶惠美',
  duration: Duration(seconds: 269),
  metadata: {'hash': 'h128'},
);

Future<LiveResponse> Function(Uri) _jsonFuture(Object json) =>
    (url) async => _ok(jsonEncode(json));

LiveResponse _ok(String body) => LiveResponse(statusCode: 200, headers: const {}, bodyBytes: utf8.encode(body));

/// The payload a KuGou server sends for a KRC lyric: a four-byte header,
/// then the zlib of the text XORed with the sixteen-byte key, base64-wrapped.
String _krcPayload(String text) {
  const key = [0x40, 0x47, 0x61, 0x77, 0x5e, 0x32, 0x74, 0x47, 0x51, 0x36, 0x31, 0x2d, 0xce, 0xd2, 0x6e, 0x69];
  final zlib = Uint8List.fromList(ZLibEncoder().convert(utf8.encode(text)));
  final out = Uint8List(4 + zlib.length)..setRange(0, 4, utf8.encode('krc1'));
  for (var i = 0; i < zlib.length; i++) {
    out[4 + i] = zlib[i] ^ key[i % 16];
  }
  return base64.encode(out);
}

/// The transport the KuGou tests code against: routes by a path fragment
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
