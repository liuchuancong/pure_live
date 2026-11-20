import 'dart:convert' show jsonEncode, utf8;

import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/modules/music/controller/sources/lx_script_runtime.dart';
import 'package:pure_live/modules/music/controller/sources/music_source_kw.dart';

/// The Kuwo platform's mapping and its walks, argued over a stub transport:
/// a row's N-MINFO names its tiers and its cover arrives either whole or as
/// a CDN-relative half, the lyric walk forks a repeated stamp into the
/// translation line, the playlist detail walks the pagination to the end,
/// the playlist search reads the gateway's Python-repr dialect with an
/// apostrophe inside a name surviving, and the play fallback answers only
/// a body that starts like an address.
void main() {
  late _Stub http;
  late KwMusicSource kw;

  setUp(() {
    http = _Stub();
    final runtime = LxScriptRuntime(transport: http); // no scripts: the tiers come from the rows themselves
    kw = KwMusicSource(runtime, http);
  });

  group('the row mapping', () {
    test('a search row strips its rid, reads the N-MINFO tiers and its whole cover', () {
      final track = KwMusicSource.trackOf(
        {
          'MUSICRID': 'MUSIC_977',
          'SONGNAME': '晴天',
          'ARTIST': '周杰伦',
          'ALBUM': '叶惠美',
          'ALBUMID': '9001',
          'ARTISTID': '31',
          'DURATION': '269',
          'N_MINFO':
              'A=1|bitrate:128,format:mp3|bitrate:320,format:mp3|bitrate:2000,format:flac|bitrate:4000,format:flac',
          'albumPic': 'https://img4.kuwo.cn/star/albumcover/full.jpg',
          'web_albumpic_short': '94/55/167/25891767.jpg',
        },
        const ['128k'],
      );

      expect(track!.id, '977'); // the rid prefix stripped
      expect(track.title, '晴天');
      expect(track.artist, '周杰伦');
      expect(track.album, '叶惠美');
      expect(track.albumId, '9001');
      expect(track.duration, const Duration(seconds: 269));
      expect(track.coverUri.toString(), 'https://img4.kuwo.cn/star/albumcover/full.jpg'); // the whole picture wins
      expect(track.qualities, [
        audio.MusicQuality.k128,
        audio.MusicQuality.k320,
        audio.MusicQuality.flac,
        audio.MusicQuality.flac24bit,
      ]);
      expect(track.metadata['types'], ['128k', '320k', 'flac', 'flac24bit']);
      expect(track.metadata['albumId'], '9001');
      expect(track.metadata['artistId'], '31');
    });

    test('a board row rides the lowercase fields and its half cover grows an address', () {
      final track = KwMusicSource.trackOf({
        'id': '977',
        'name': '夜曲',
        'artist': '周杰伦',
        'albumid': '9002',
        'duration': '226',
        'web_albumpic_short': '94/55/167/1.jpg',
      }, const []);

      expect(track!.id, '977');
      expect(track.title, '夜曲');
      expect(track.albumId, '9002');
      expect(track.coverUri.toString(), 'https://img2.kuwo.cn/star/albumcover/94/55/167/1.jpg');
      expect(track.qualities, [audio.MusicQuality.k128]); // no info line: the plain tier stands in
      expect(track.metadata['types'], ['128k']);
      expect(track.metadata.containsKey('artistId'), isFalse);
    });

    test('a row without its id or its title never lands', () {
      expect(KwMusicSource.trackOf({'MUSICRID': 'MUSIC_1', 'SONGNAME': ''}, const []), isNull);
      expect(KwMusicSource.trackOf({'SONGNAME': '晴天'}, const []), isNull);
    });

    test('the entities the gateway hides in a name come out', () {
      final track = KwMusicSource.trackOf({'MUSICRID': 'MUSIC_1', 'SONGNAME': 'A&amp;B&#39;s&nbsp;歌'}, const []);
      expect(track!.artist, isEmpty);
      expect(track.title, "A&B's 歌");
    });
  });

  group('the search walk', () {
    test('a row maps with its total, and the entities decode', () async {
      http.route(
        'r.s',
        _jsonFuture({
          'TOTAL': '45',
          'abslist': [
            {
              'MUSICRID': 'MUSIC_977',
              'SONGNAME': 'A&amp;B',
              'ARTIST': '周杰伦',
              'ALBUM': '叶惠美',
              'ALBUMID': '9001',
              'DURATION': '269',
              'N_MINFO': 'bitrate:128,format:mp3|bitrate:320,format:mp3',
            },
          ],
        }),
      );

      final page = await kw.search('晴天');
      final track = page.items.single;
      expect(track.title, 'A&B'); // the entity the gateway hid came out
      expect(track.qualities, [audio.MusicQuality.k128, audio.MusicQuality.k320]);
      expect(page.total, 45);
      expect(page.hasMore, isTrue); // forty-five ranked, thirty read
    });

    test('a shapeless answer is an empty page', () async {
      http.route('r.s', _jsonFuture({'TOTAL': 'x'}));
      final page = await kw.search('晴天');
      expect(page.items, isEmpty);
      expect(page.total, 0);
      expect(page.hasMore, isFalse);
    });
  });

  group('the boards', () {
    test('only a first page exists, and its rows ride the lowercase fields', () async {
      final second = await kw.catalogItems(const audio.MusicCatalog(id: 'kw:16', name: '热歌榜'), page: 2);
      expect(second.items, isEmpty); // the board walks no further pages
      expect(http.calls, isEmpty); // and asks nothing for it

      http.route(
        'ksong.s',
        _jsonFuture({
          'musiclist': [
            {'id': '977', 'name': '夜曲', 'artist': '周杰伦', 'albumid': '9002', 'duration': '226'},
          ],
        }),
      );
      final first = await kw.catalogItems(const audio.MusicCatalog(id: 'kw:16', name: '热歌榜'));
      expect(first.items.single.id, '977');
    });
  });

  group('the lyric walk', () {
    test('a repeated stamp forks its second line into the translation', () async {
      http.route(
        'songinfoandlrc',
        _jsonFuture({
          'data': {
            'lrclist': [
              {'lineLyric': '第一句', 'time': '0.5'},
              {'lineLyric': '译文一', 'time': '0.5'},
              {'lineLyric': '第二句', 'time': '3'},
              {'lineLyric': '  ', 'time': '4'}, // a blank line rides nowhere
              {'lineLyric': '坏时间', 'time': 'abc'}, // an unreadable time rides nowhere
            ],
          },
        }),
      );

      final payload = await kw.resolveLyric(_track());
      expect(payload, isNotNull);
      expect(payload!.lyric, '[00:00.500]第一句\n[00:03.000]第二句\n');
      expect(payload.translation, '[00:00.500]译文一\n');
      expect(payload.romanization, isNull);
    });

    test('an empty list, a missing body and a refused answer are no lyric', () async {
      http.route(
        'songinfoandlrc',
        _jsonFuture({
          'data': {'lrclist': <Object?>[]},
        }),
      );
      expect(await kw.resolveLyric(_track()), isNull);

      http.route('songinfoandlrc', _jsonFuture({'code': 200}));
      expect(await kw.resolveLyric(_track()), isNull);

      http.route('songinfoandlrc', _jsonFuture({'data': null}));
      expect(await kw.resolveLyric(_track()), isNull);
    });
  });

  group('the playlist search', () {
    test("the gateway's python-repr dialect parses, an apostrophe surviving", () async {
      // The r.s gateway answers this `ft` as a Python repr, not JSON: single
      // quotes throughout, and one inside a name that only closes where a
      // structural mark follows.
      http.route(
        'r.s',
        _textFuture(
          "{'TOTAL': '8', 'abslist': [{'playlistid': '101', 'name': 'it's fine', 'pic': 'p.jpg',"
          " 'nickname': 'dj', 'songnum': '5', 'playcnt': '99'}]}",
        ),
      );

      final page = await kw.searchPlaylists('晴天');
      final list = page.items.single;
      expect(list.id, '101');
      expect(list.name, "it's fine"); // the apostrophe inside the name survived
      expect(list.cover, 'p.jpg');
      expect(list.author, 'dj');
      expect(list.trackCount, 5);
      expect(list.playCount, 99);
      expect(page.total, 8);
      expect(page.hasMore, isTrue);
    });
  });

  group('the playlist detail', () {
    test('the pagination walks to the end, the info read off the first page', () async {
      http.route('pl.svc', (url) async {
        final first = url.queryParameters['pn'] == '0';
        return _ok(
          jsonEncode({
            'result': 'ok',
            'total': '3',
            if (first) ...{'title': '我的歌单', 'pic': 'cover.jpg', 'uname': '作者', 'playnum': '1234'},
            'musiclist': [
              if (first) ...[
                {'MUSICRID': 'MUSIC_1', 'SONGNAME': '一', 'DURATION': '100'},
                {'MUSICRID': 'MUSIC_2', 'SONGNAME': '二', 'DURATION': '200'},
              ] else
                {'MUSICRID': 'MUSIC_3', 'SONGNAME': '三', 'DURATION': '300'},
            ],
          }),
        );
      });

      final (info, tracks) = await kw.playlistDetail('12345');
      expect(info.name, '我的歌单');
      expect(info.trackCount, 3);
      expect(info.author, '作者');
      expect(info.playCount, 1234);
      expect(tracks.map((track) => track.id), ['1', '2', '3']);
      expect(http.calls.where((uri) => uri.path.contains('pl.svc')), hasLength(2)); // two reads, three rows
    });
  });

  group('the hot words and the completions', () {
    test('the chart keeps its order and drops the blank words', () async {
      http.route(
        'hotword.s',
        _jsonFuture({
          'tagvalue': [
            {'key': '晴天'},
            {'key': '  '},
            {'key': ' 夜曲 '},
          ],
        }),
      );
      expect(await kw.hotSearches(), ['晴天', '夜曲']);
    });

    test('the completions keep their order and drop the blanks', () async {
      http.route(
        't.s',
        _jsonFuture({
          'WORDITEMS': [
            {'RELWORD': '晴天 MV'},
            {'RELWORD': ''},
          ],
        }),
      );
      expect(await kw.suggestions('晴'), ['晴天 MV']);
    });
  });

  group('the play fallback', () {
    test('a body that starts like an address is the url, anything else is not', () async {
      http.route('anti.s', _textFuture('http://audio.kuwo.cn/x.mp3\n'));
      expect(await kw.fallbackUrl(_track(), '128k'), 'http://audio.kuwo.cn/x.mp3');

      http.route('anti.s', _textFuture('junk'));
      expect(await kw.fallbackUrl(_track(), '128k'), isNull);
    });
  });

  group('the track detail', () {
    test('the music-info body fills the track it already has', () async {
      http.route(
        'musicInfo',
        _jsonFuture({
          'code': 200,
          'data': {
            'name': '晴天 (修正版)',
            'artist': [
              {'name': '周杰伦'},
              {'name': '阿信'},
            ],
            'album': '叶惠美',
            'albumid': '9001',
            'duration': '269',
            'pic': 'https://img4.kuwo.cn/star/albumcover/full.jpg',
          },
        }),
      );

      final filled = await kw.trackDetail(_track());
      expect(filled.title, '晴天 (修正版)');
      expect(filled.artist, '周杰伦、阿信');
      expect(filled.album, '叶惠美');
      expect(filled.duration, const Duration(seconds: 269));
      expect(filled.coverUri.toString(), 'https://img4.kuwo.cn/star/albumcover/full.jpg');
      expect(filled.metadata['albumId'], '9001');
    });

    test('a refused code throws, a bodyless answer keeps the track', () async {
      http.route('musicInfo', _jsonFuture({'code': 500}));
      expect(() => kw.trackDetail(_track()), throwsStateError);

      http.route('musicInfo', _jsonFuture({'code': 200, 'data': null}));
      final kept = await kw.trackDetail(_track());
      expect(identical(kept, _track()), isTrue); // the track it already has, unchanged
    });
  });

  group('the comment sheet', () {
    test('the newest page maps its rows and knows the page count', () async {
      http.route(
        'com.s',
        _jsonFuture({
          'comments': [
            {'id': 'c1', 'msg': '好听', 'u_name': '小明', 'u_pic': 'pic.jpg', 'time': '1700000000', 'like_num': '3'},
          ],
          'comments_counts': '25',
        }),
      );

      final (:comments, :hasMore) = await kw.comments(_track(), hot: false, page: 1);
      final one = comments.single;
      expect(one.id, 'c1');
      expect(one.text, '好听');
      expect(one.userName, '小明');
      expect(one.avatar, 'pic.jpg');
      expect(one.likedCount, 3);
      expect(hasMore, isTrue); // twenty-five written, twenty shown

      final last = await kw.comments(_track(), hot: false, page: 2);
      expect(last.hasMore, isFalse); // the second page is the end
    });
  });
}

audio.MusicTrack _track() => const audio.MusicTrack(
  id: '977',
  sourceId: 'kw',
  title: '晴天',
  artist: '周杰伦',
  album: '叶惠美',
  duration: Duration(seconds: 269),
);

Future<LiveResponse> Function(Uri) _jsonFuture(Object json) =>
    (url) async => _ok(jsonEncode(json));

Future<LiveResponse> Function(Uri) _textFuture(String body) =>
    (url) async => _ok(body);

LiveResponse _ok(String body) => LiveResponse(statusCode: 200, headers: const {}, bodyBytes: utf8.encode(body));

/// The transport the Kuwo tests code against: routes by a path fragment and
/// remembers every ask.
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
