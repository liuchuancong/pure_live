import 'dart:convert' show jsonEncode, utf8;

import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:live_vod/live_vod.dart' show BilibiliVodClient;
import 'package:media_core/media_core.dart' show SourceFormat;
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/modules/music/controller/sources/music_source_bilibili.dart';

void main() {
  late _Stub http;
  late BilibiliMusicSource source;

  setUp(() {
    http = _Stub();
    source = BilibiliMusicSource(BilibiliVodClient(http, cookie: 'SESSDATA=test'));
  });

  test('search maps video titles to songs and drops duplicate archives', () async {
    http.route(
      '/x/web-interface/search/type',
      _json({
        'code': 0,
        'data': {
          'numResults': 43,
          'result': [_video(), _video(), _video(bvid: 'BV2', title: '夜曲《原创音乐人》', duration: '03:20')],
        },
      }),
    );

    final page = await source.search('周杰伦', page: 2, pageSize: 20);
    expect(page.items.map((track) => track.id), ['BV1', 'BV2']);
    final first = page.items.first;
    expect(first.title, '晴天');
    expect(first.artist, '周杰伦');
    expect(first.duration, const Duration(minutes: 4, seconds: 29));
    expect(first.coverUri, Uri.parse('https://cdn/cover.jpg'));
    expect(first.metadata['bvid'], 'BV1');
    expect(first.metadata['videoTitle'], '【官方 MV】周杰伦 - 晴天 无损');
    expect(page.total, 43);
    expect(page.hasMore, isTrue);

    final ask = http.requests.single;
    expect(ask.url.queryParameters['page'], '2');
    expect(ask.url.queryParameters['page_size'], '20');
    expect(ask.headers['cookie'], 'SESSDATA=test');
  });

  test('the four playback preferences choose the matching DASH audio tier', () async {
    _audioRoutes(http);
    final track = _track();

    final standard = await source.resolveTrackSource(track, quality: audio.MusicQuality.k128);
    expect(standard.uri, Uri.parse('https://cdn/132.m4s'));
    expect(standard.quality?.id, '132k');
    expect(standard.format, SourceFormat.mp4);
    expect(standard.headers['referer'], 'https://www.bilibili.com');
    expect(standard.headers['cookie'], 'SESSDATA=test');

    final high = await source.resolveTrackSource(track, quality: audio.MusicQuality.k320);
    expect(high.uri, Uri.parse('https://cdn/192.m4s'));
    expect(high.quality?.id, '192k');

    final lossless = await source.resolveTrackSource(track, quality: audio.MusicQuality.hires);
    expect(lossless.uri, Uri.parse('https://cdn/flac.m4s'));
    expect(lossless.quality, audio.MusicQuality.flac24bit);
    expect(lossless.format, SourceFormat.flac);

    final playAsk = http.requests.lastWhere((request) => request.url.path == '/x/player/playurl');
    expect(playAsk.url.queryParameters['fnval'], '16');
    expect(playAsk.url.queryParameters['cid'], '101');
  });

  test('qualities reports only the renditions the video actually offers', () async {
    _audioRoutes(http);
    final qualities = await source.qualities(_track());
    expect(qualities.map((quality) => quality.id), ['64k', '132k', '192k', 'flac24bit']);
  });

  test('lyrics use the cleaned song title and the uploader fallback', () async {
    http.route('/api/search', (url) async {
      expect(url.queryParameters['track_name'], '晴天');
      expect(url.queryParameters['artist_name'], '周杰伦');
      return await _json([
        {'duration': 269, 'syncedLyrics': '[00:01.00]一句', 'plainLyrics': '一句'},
      ])(url);
    });

    final lyric = await source.resolveLyric(_track());
    expect(lyric?.lyric, '[00:01.00]一句');
  });

  test('the music ranking is a single fixed catalog page', () async {
    http.route('/x/web-interface/ranking/v2', (url) async {
      expect(url.queryParameters['rid'], '3');
      return await _json({
        'code': 0,
        'data': {
          'list': [
            {
              'bvid': 'BV1',
              'title': '周杰伦 - 晴天',
              'pic': '//cdn/cover.jpg',
              'owner': {'name': '周杰伦'},
              'duration': 269,
            },
          ],
        },
      })(url);
    });

    final catalogs = await source.catalogs();
    expect(catalogs.single.id, 'bilibili:ranking:3');
    final page = await source.catalogItems(catalogs.single);
    expect(page.items.single.title, '晴天');
    expect(page.items.single.artist, '周杰伦');
    expect(page.hasMore, isFalse);

    final calls = http.requests.length;
    final second = await source.catalogItems(catalogs.single, page: 2);
    expect(second.items, isEmpty);
    expect(http.requests, hasLength(calls));
  });

  test('track detail uses the first part duration because music mode plays it', () async {
    http.route(
      '/x/web-interface/view',
      _json({
        'code': 0,
        'data': {
          'bvid': 'BV1',
          'aid': 42,
          'title': '周杰伦 - 晴天',
          'duration': 600,
          'pic': '//cdn/cover.jpg',
          'owner': {'name': '周杰伦'},
          'pages': [
            {'cid': 101, 'part': '晴天', 'duration': 269},
          ],
        },
      }),
    );

    final detail = await source.trackDetail(_track());
    expect(detail.duration, const Duration(seconds: 269));
    expect(detail.metadata['aid'], 42);
  });
}

Map<String, Object?> _video({String bvid = 'BV1', String title = '【官方 MV】周杰伦 - 晴天 无损', String duration = '04:29'}) => {
  'bvid': bvid,
  'aid': 42,
  'title': title,
  'author': '周杰伦',
  'pic': '//cdn/cover.jpg',
  'duration': duration,
  'play': 123,
};

audio.MusicTrack _track() => const audio.MusicTrack(
  id: 'BV1',
  sourceId: 'bilibili',
  title: '晴天',
  artist: '周杰伦',
  duration: Duration(seconds: 269),
  metadata: {'bvid': 'BV1', 'videoTitle': '【官方 MV】周杰伦 - 晴天 无损', 'uploader': '周杰伦'},
);

void _audioRoutes(_Stub http) {
  http
    ..route(
      '/x/player/pagelist',
      _json({
        'code': 0,
        'data': [
          {'cid': 101, 'part': '晴天'},
        ],
      }),
    )
    ..route(
      '/x/player/playurl',
      _json({
        'code': 0,
        'data': {
          'dash': {
            'audio': [
              {'id': 30216, 'baseUrl': 'https://cdn/64.m4s', 'bandwidth': 64000, 'codecs': 'mp4a.40.2'},
              {'id': 30280, 'baseUrl': 'https://cdn/192.m4s', 'bandwidth': 192000, 'codecs': 'mp4a.40.2'},
              {'id': 30232, 'baseUrl': 'https://cdn/132.m4s', 'bandwidth': 132000, 'codecs': 'mp4a.40.2'},
            ],
            'flac': {
              'audio': {'id': 30251, 'baseUrl': 'https://cdn/flac.m4s', 'bandwidth': 900000, 'codecs': 'fLaC'},
            },
          },
        },
      }),
    );
}

Future<LiveResponse> Function(Uri) _json(Object body) =>
    (url) async => _ok(jsonEncode(body));

LiveResponse _ok(String body) => LiveResponse(statusCode: 200, headers: const {}, bodyBytes: utf8.encode(body));

final class _Stub implements LiveHttp {
  final requests = <LiveRequest>[];
  final Map<String, Future<LiveResponse> Function(Uri)> _routes = {};

  void route(String path, Future<LiveResponse> Function(Uri) answer) => _routes[path] = answer;

  @override
  Future<LiveResponse> send(LiveRequest request) {
    requests.add(request);
    final answer = _routes[request.url.path];
    if (answer == null) throw StateError('no answer for ${request.url}');
    return answer(request.url);
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}
}
