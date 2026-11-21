import 'dart:convert' show jsonEncode, utf8;

import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/modules/music/controller/sources/lx_script_runtime.dart';
import 'package:pure_live/modules/music/controller/sources/music_source_mg.dart';

/// The Migu platform's mapping and its walks, argued over a stub transport:
/// the search rows nest one group deep and dedupe on the copyright id, the
/// format tags name the tier list, a relative picture grows the CDN host,
/// the lyric walk falls back from an unreadable word-timed body to the
/// plain one, the plaza reads its tags as name/id pairs and its feed as
/// nested columns, and the newest comments remember where the last page
/// ended.
void main() {
  late _Stub http;
  late MgMusicSource mg;

  setUp(() {
    http = _Stub();
    final runtime = LxScriptRuntime(transport: http); // no scripts: the tiers come from the rows themselves
    mg = MgMusicSource(runtime, http);
  });

  Map<String, Object?> song({
    Object? songId = '9001',
    String copyrightId = 'c1',
    String name = '晴天',
    List<Map<String, Object?>>? formats,
    List<Map<String, Object?>>? singers,
  }) => {
    'copyrightId': copyrightId,
    'songId': songId,
    'name': name,
    'album': '叶惠美',
    'albumId': '9001x',
    'duration': '269',
    'img3': '/star/cover.jpg',
    'audioFormats':
        formats ??
        [
          {'formatType': 'PQ'},
          {'formatType': 'HQ'},
          {'formatType': 'SQ'},
          {'formatType': 'ZQ24'},
        ],
    'singerList':
        singers ??
        [
          {'id': '31', 'name': '周杰伦', 'img': '/star/s.jpg'},
          {'id': '0', 'name': '阿信'}, // a zero id is not an id
        ],
    'lrcUrl': 'http://lyric.migu.cn/lrc',
    'mrcurl': 'http://lyric.migu.cn/mrc',
    'trcUrl': 'http://lyric.migu.cn/trc',
  };

  group('the search mapping', () {
    test('nested groups flatten, a twin row drops, and the mapping fills', () async {
      http.route(
        'searchAll',
        _jsonFuture({
          'code': '000000',
          'songResultData': {
            'totalCount': '45',
            'resultList': [
              [song(), song()], // the twin: same copyright id, dropped
              [
                song(
                  songId: '9002',
                  copyrightId: 'c2',
                  name: '夜曲',
                  formats: [
                    {'formatType': 'PQ'},
                    {'formatType': 'ZQ'}, // the other hi-res tag
                  ],
                ),
              ],
              'junk', // a group that is not a list rides nowhere
            ],
          },
        }),
      );

      final page = await mg.search('晴天');
      expect(page.items.map((track) => track.id), ['9001', '9002']);
      final track = page.items.first;
      expect(track.title, '晴天');
      expect(track.artist, '周杰伦、阿信');
      expect(track.album, '叶惠美');
      expect(track.albumId, '9001x');
      expect(track.duration, const Duration(seconds: 269));
      expect(track.coverUri.toString(), 'http://d.musicapp.migu.cn/star/cover.jpg'); // the relative half grown
      expect(track.qualities, [
        audio.MusicQuality.k128,
        audio.MusicQuality.k320,
        audio.MusicQuality.flac,
        audio.MusicQuality.flac24bit,
      ]);
      expect(track.metadata['types'], ['128k', '320k', 'flac', 'flac24bit']);
      expect(track.metadata['copyrightId'], 'c1');
      expect(track.metadata['lrc'], 'http://lyric.migu.cn/lrc');
      expect(track.metadata['mrc'], 'http://lyric.migu.cn/mrc');
      expect(track.metadata['trc'], 'http://lyric.migu.cn/trc');
      expect(track.metadata['artistId'], '31');
      expect(track.metadata['artistPic'], 'http://d.musicapp.migu.cn/star/s.jpg');
      expect(page.total, 45);
      expect(page.hasMore, isTrue);

      expect(page.items.last.qualities, [audio.MusicQuality.k128, audio.MusicQuality.flac24bit]); // ZQ counts too
    });

    test('a refused code is an empty page, and a null song id never lands', () async {
      http.route('searchAll', _jsonFuture({'code': '999999'}));
      final refused = await mg.search('晴天');
      expect(refused.items, isEmpty);

      http.route(
        'searchAll',
        _jsonFuture({
          'code': '000000',
          'songResultData': {
            'totalCount': '1',
            'resultList': [
              [song(songId: null)],
            ],
          },
        }),
      );
      final nullId = await mg.search('晴天');
      expect(nullId.items, isEmpty); // '${null}' reads 'null' and is refused
    });
  });

  group('the boards', () {
    test('only a first page exists, and the contents dedupe on the song id', () async {
      final second = await mg.catalogItems(const audio.MusicCatalog(id: 'mg:27553319', name: '音乐榜'), page: 2);
      expect(second.items, isEmpty);
      expect(http.calls, isEmpty);

      http.route(
        'querycontentbyId',
        _jsonFuture({
          'code': '000000',
          'columnInfo': {
            'contents': [
              {'objectInfo': song()},
              {'objectInfo': song()}, // the twin: same song id, dropped
              {'objectInfo': null},
              'junk',
            ],
          },
        }),
      );
      final first = await mg.catalogItems(const audio.MusicCatalog(id: 'mg:27553319', name: '音乐榜'));
      expect(first.items.single.id, '9001');
    });
  });

  group('the lyric walk', () {
    test('an unreadable word-timed body falls back to the plain lyric', () async {
      http
        ..route('mrc', _textFuture('short')) // too short to be a sealed body
        ..route('lrc', _textFuture('[00:01.000]一句'))
        ..route('trc', _textFuture('[00:01.000]译文'));

      final payload = await mg.resolveLyric(_track());
      expect(payload, isNotNull);
      expect(payload!.lyric, '[00:01.000]一句');
      expect(payload.translation, '[00:01.000]译文');
    });

    test('a row without its lyric addresses asks the detail for them', () async {
      http
        ..route(
          'resourceinfo',
          _jsonFuture({
            'resource': [
              {'lrcUrl': 'http://lyric.migu.cn/lrc2', 'trcUrl': ''},
            ],
          }),
        )
        ..route('lrc', _textFuture('[00:02.000]新词'));

      final payload = await mg.resolveLyric(_bareTrack());
      expect(payload!.lyric, '[00:02.000]新词');
      expect(payload.translation, isNull); // an empty translation is no translation
    });
  });

  group('the hot words and the completions', () {
    test('the chart keeps only the song words, trimmed', () async {
      http.route(
        'hotword',
        _jsonFuture({
          'code': '000000',
          'data': {
            'hotwords': [
              {
                'hotwordList': [
                  {'resourceType': 'song', 'word': ' 晴天 '},
                  {'resourceType': 'mv', 'word': '夜曲'}, // not a song word
                  {'resourceType': 'song', 'word': '  '}, // blank
                ],
              },
            ],
          },
        }),
      );
      expect(await mg.hotSearches(), ['晴天']);
    });

    test('the completions read both blocks and never repeat a tip', () async {
      http.route(
        'tone_search_suggest',
        _jsonFuture({
          'data': {
            'singerList': [
              {'singerName': '周杰伦'},
            ],
            'songList': [
              {'songName': '晴天'},
              {'songName': '周杰伦'}, // already tipped by the singers
            ],
          },
        }),
      );
      expect(await mg.suggestions('晴'), ['周杰伦', '晴天']);
    });
  });

  group('the plaza', () {
    test('the tag pairs read name then id, the first block only', () async {
      http.route(
        'musiclistplaza-taglist',
        _jsonFuture({
          'code': '000000',
          'data': [
            {
              'content': [
                {
                  'texts': ['华语', 'c1'],
                },
                {
                  'texts': ['粤语', 'c2'],
                },
                {
                  'texts': ['只有名字'],
                }, // no id half, no tag
              ],
            },
            {
              'header': {'title': '第二块'},
              'content': <Object?>[],
            },
          ],
        }),
      );
      final tags = await mg.hotTags();
      expect(tags.map((tag) => tag.id), ['c1', 'c2']); // the id is the pair's second text
      expect(tags.map((tag) => tag.name), ['华语', '粤语']);
    });

    test('nested columns flatten to their playlist rows', () async {
      http.route(
        'playlist-square-recommend',
        _jsonFuture({
          'code': '000000',
          'data': {
            'contents': [
              {
                'contents': [
                  {'resType': '2021', 'resId': 'r1', 'txt': '歌单一', 'img': 'i1.jpg'},
                  {'resType': '1011', 'resId': 'skip', 'txt': '别的', 'img': 'x.jpg'},
                ],
              },
              {'resType': '2021', 'resId': 'r2', 'txt': '歌单二', 'img': 'i2.jpg'},
              'junk',
            ],
          },
        }),
      );
      final page = await mg.playlists();
      expect(page.items.map((list) => list.id), ['r1', 'r2']);
      expect(page.items.first.name, '歌单一');
      expect(page.hasMore, isTrue); // rows came back, another page is worth asking
      expect(page.total, 0); // the columns carry no count
    });

    test("the flat shape's first bar is the play figure, not a creator", () async {
      http.route(
        'listbytag',
        _jsonFuture({
          'code': '000000',
          'data': {
            'contentItemList': [
              {'ignore': true},
              {
                'itemList': [
                  {
                    'title': '歌单A',
                    'imageUrl': 'p.jpg',
                    'logEvent': {'contentId': 'pa'},
                    'barList': [
                      {'title': '507.0万'},
                      {'title': '第二栏'},
                    ],
                  },
                ],
              },
            ],
          },
        }),
      );
      final page = await mg.playlists(tag: 'c1');
      final list = page.items.single;
      expect(list.id, 'pa');
      expect(list.name, '歌单A');
      expect(list.author, isEmpty); // the bar is a figure, not a nickname
      expect(list.playCount, 5070000); // 507.0万 read back as a number
    });
  });

  group('the playlist detail', () {
    test('the songs dedupe, and a refused cover sheet keeps the tracks', () async {
      http
        ..route(
          'playlist/song',
          _jsonFuture({
            'code': '000000',
            'data': {
              'songList': [
                song(),
                song(), // the twin: same song id, dropped
                song(songId: '9003', copyrightId: 'c3', name: '七里香'),
              ],
            },
          }),
        )
        ..route('resource/playlist/v2.0', _jsonFuture({'code': '400'}));
      final (info, tracks) = await mg.playlistDetail('12345');
      expect(tracks.map((track) => track.id), ['9001', '9003']);
      expect(info.id, '12345');
      expect(info.name, '12345'); // the id stands in where the sheet failed
      expect(info.trackCount, 2); // the rows already read are the honest count
    });

    test('the cover sheet fills the facts it names', () async {
      http
        ..route(
          'playlist/song',
          _jsonFuture({
            'code': '000000',
            'data': {
              'songList': [song()],
            },
          }),
        )
        ..route(
          'resource/playlist/v2.0',
          _jsonFuture({
            'code': '000000',
            'data': {
              'title': '我的歌单',
              'imgItem': {'img': 'cover.jpg'},
              'ownerName': '作者',
              'musicNum': 3,
              'opNumItem': {'playNum': 99},
            },
          }),
        );

      final (info, tracks) = await mg.playlistDetail('12345');
      expect(info.name, '我的歌单');
      expect(info.cover, 'cover.jpg');
      expect(info.author, '作者');
      expect(info.trackCount, 3); // the sheet's own count wins
      expect(info.playCount, 99); // the plays filed under the sheet, not the size
      expect(tracks, hasLength(1));
    });
  });

  group('the album page', () {
    test('the clock length and the card cover fill what the rows omit', () async {
      http
        ..route(
          'album/v2.0',
          _jsonFuture({
            'code': '000000',
            'data': {
              'title': '叶惠美',
              'singer': '周杰伦',
              'singerId': '31',
              'imgItems': [
                {'img': '/a/big.jpg'},
                {'img': '/a/small.jpg'},
              ],
              'totalCount': '10',
              'publishTime': '2003-07-31',
            },
          }),
        )
        ..route(
          'queryAlbumSong',
          _jsonFuture({
            'code': '000000',
            'data': {
              'songList': [
                {
                  'songId': 's1',
                  'copyrightId': 'c1',
                  'name': '以父之名',
                  'artists': [
                    {'id': '31', 'name': '周杰伦'},
                  ],
                  'length': '03:45', // a clock, not seconds
                  'albumImgs': [
                    {'img': '/a/row.jpg'},
                  ],
                },
                {
                  'songId': 's2',
                  'name': '懦夫',
                  'artists': <Object?>[], // no singers: the card's credit stands in
                  'duration': '200',
                },
                {'songId': null, 'name': '残行'}, // no song id, refused
              ],
            },
          }),
        );

      final (:album, :tracks) = await mg.album('9001x');
      expect(album.name, '叶惠美');
      expect(album.artist, '周杰伦');
      expect(album.artistId, '31');
      expect(album.coverUri.toString(), 'http://d.musicapp.migu.cn/a/big.jpg'); // the first, biggest picture
      expect(album.trackCount, 10);
      expect(album.year, 2003);

      expect(tracks, hasLength(2));
      final first = tracks[0];
      expect(first.id, 's1');
      expect(first.duration, const Duration(seconds: 225)); // 03:45 read as seconds
      expect(first.coverUri.toString(), 'http://d.musicapp.migu.cn/a/row.jpg'); // the row's own picture wins
      final second = tracks[1];
      expect(second.id, 's2');
      expect(second.artist, '周杰伦'); // the card's credit stood in
      expect(second.coverUri.toString(), 'http://d.musicapp.migu.cn/a/big.jpg'); // the card's picture stood in

      expect(http.calls.where((uri) => uri.path.contains('queryAlbumSong')), hasLength(1)); // three rows: one page
    });
  });

  group('the comment sheet', () {
    test('the hot page maps its rows and knows the page count', () async {
      http.route(
        'comment/stack',
        _jsonFuture({
          'code': '000000',
          'data': {
            'cfgHotCount': '25',
            'hotComments': [
              {
                'commentId': 'h1',
                'commentInfo': '热评',
                'user': {'nickName': '小明', 'middleIcon': 'm.jpg'},
                'commentTime': '2023-11-01T10:00:00',
                'opNumItem': {'thumbNum': '7'},
                'replyComments': [
                  {
                    'replyId': 'r1',
                    'replyInfo': '回复',
                    'user': {'nickName': '小红'},
                  },
                ],
              },
            ],
          },
        }),
      );

      final (:comments, :hasMore) = await mg.comments(_track(), hot: true, page: 1);
      final one = comments.single;
      expect(one.id, 'h1');
      expect(one.text, '热评');
      expect(one.userName, '小明');
      expect(one.avatar, 'm.jpg');
      expect(one.likedCount, 7);
      expect(one.replies.single.text, '回复');
      expect(hasMore, isTrue); // twenty-five hot, twenty shown
    });

    test("the newest pages ride the previous page's last id", () async {
      http.route('comment/stack', (url) async {
        final cursor = url.queryParameters['commentId'];
        if (cursor == null || cursor.isEmpty) {
          return _ok(
            jsonEncode({
              'code': '000000',
              'data': {
                'commentNums': '25',
                'comments': [
                  {'commentId': 'n1', 'commentInfo': '第一条'},
                  {'commentId': 'n2', 'commentInfo': '第二条'},
                ],
              },
            }),
          );
        }
        return _ok(
          jsonEncode({
            'code': '000000',
            'data': {
              'commentNums': '25',
              'comments': [
                {'commentId': 'n3', 'commentInfo': '第三条'},
              ],
            },
          }),
        );
      });

      final first = await mg.comments(_track(), hot: false, page: 1);
      expect(first.comments.map((comment) => comment.id), ['n1', 'n2']);
      expect(first.hasMore, isTrue);

      final second = await mg.comments(_track(), hot: false, page: 2);
      expect(second.comments.map((comment) => comment.id), ['n3']);
      expect(second.hasMore, isFalse); // forty asked for, twenty-five written
    });

    test('a newest page past the first without a cursor refuses', () async {
      expect(() => mg.comments(_track(), hot: false, page: 2), throwsStateError);
    });
  });
}

audio.MusicTrack _track() => const audio.MusicTrack(
  id: '9001',
  sourceId: 'mg',
  title: '晴天',
  artist: '周杰伦',
  album: '叶惠美',
  duration: Duration(seconds: 269),
  metadata: {
    'copyrightId': 'c1',
    'lrc': 'http://lyric.migu.cn/lrc',
    'mrc': 'http://lyric.migu.cn/mrc',
    'trc': 'http://lyric.migu.cn/trc',
  },
);

audio.MusicTrack _bareTrack() =>
    const audio.MusicTrack(id: '9001', sourceId: 'mg', title: '晴天', metadata: {'copyrightId': 'c1'});

Future<LiveResponse> Function(Uri) _jsonFuture(Object json) =>
    (url) async => _ok(jsonEncode(json));

Future<LiveResponse> Function(Uri) _textFuture(String body) =>
    (url) async => _ok(body);

LiveResponse _ok(String body) => LiveResponse(statusCode: 200, headers: const {}, bodyBytes: utf8.encode(body));

/// The transport the Migu tests code against: routes by a path fragment and
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
