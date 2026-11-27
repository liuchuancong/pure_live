import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs, StorageStores;
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/modules/music/controller/library/music_library.dart' show musicFavouritesProvider;
import 'package:pure_live/modules/music/controller/playback/music_open_api.dart'
    show
        MusicOpenApi,
        kMusicOpenApiDefaultFilter,
        kMusicOpenApiStatusKeys,
        musicOpenApiLxLyricOf,
        musicOpenApiParseFilter,
        musicOpenApiStatusName;

void main() {
  group('filter', () {
    test('the default filter is the reference eight in status order', () {
      expect(kMusicOpenApiDefaultFilter.length, 8);
      expect(musicOpenApiParseFilter(null), [
        'status',
        'name',
        'singer',
        'albumName',
        'lyricLineText',
        'duration',
        'progress',
        'playbackRate',
      ]);
      expect(musicOpenApiParseFilter(''), kMusicOpenApiDefaultFilter);
    });

    test('a filter keeps status-key order and drops unknown names', () {
      expect(musicOpenApiParseFilter('progress,name'), ['name', 'progress']);
      expect(musicOpenApiParseFilter('status,bogus,collect'), ['status', 'collect']);
      expect(musicOpenApiParseFilter('bogus'), kMusicOpenApiDefaultFilter);
      // Every status key passes through untouched.
      expect(musicOpenApiParseFilter(kMusicOpenApiStatusKeys.join(',')), kMusicOpenApiStatusKeys);
    });
  });

  group('status name', () {
    const track = audio.MusicTrack(id: '1', sourceId: 'kw', title: 'Song', artist: 'Singer');

    test('error wins, then playing, then paused, then stoped', () {
      expect(musicOpenApiStatusName(const audio.AudioPlaybackState(error: 'boom')), 'error');
      expect(musicOpenApiStatusName(const audio.AudioPlaybackState(playing: true)), 'playing');
      expect(musicOpenApiStatusName(const audio.AudioPlaybackState(track: track)), 'paused');
      expect(musicOpenApiStatusName(audio.AudioPlaybackState.idle), 'stoped');
      // A paused player with an error still reads as the error.
      expect(musicOpenApiStatusName(const audio.AudioPlaybackState(track: track, error: 'boom')), 'error');
    });
  });

  group('lxlyric', () {
    test('a lyric without word timing contributes nothing', () {
      expect(musicOpenApiLxLyricOf(null), '');
      const plain = audio.LyricDocument(
        lines: [audio.LyricLine(start: Duration(seconds: 12), text: '你好')],
      );
      expect(musicOpenApiLxLyricOf(plain), '');
    });

    test('word timing renders as enhanced LRC', () {
      const document = audio.LyricDocument(
        lines: [
          audio.LyricLine(
            start: Duration(seconds: 12, milliseconds: 500),
            text: '你好',
            words: [
              audio.LyricWord(start: Duration(seconds: 12, milliseconds: 500), text: '你'),
              audio.LyricWord(start: Duration(seconds: 13), text: '好'),
            ],
          ),
          audio.LyricLine(start: Duration(minutes: 1, seconds: 5), text: '第二行'),
        ],
      );
      expect(musicOpenApiLxLyricOf(document), '[00:12.50]<00:12.50>你<00:13.00>好');
    });
  });

  group('lyric status', () {
    late StorageStores stores;
    late ProviderContainer container;
    late MusicOpenApi api;
    late audio.AudioPlaybackState playback;
    late List<Completer<audio.LyricDocument>> loads;
    late int port;

    setUp(() async {
      stores = await StorageStores.openInMemory();
      await StoragePrefs.init();
      container = ProviderContainer();
      playback = audio.AudioPlaybackState.idle;
      loads = [];
      api = MusicOpenApi(
        () => throw StateError('status does not drive playback'),
        () => playback,
        loadLyric: ({force = false}) {
          final load = Completer<audio.LyricDocument>();
          loads.add(load);
          return load.future;
        },
        favourites: container.read(musicFavouritesProvider.notifier),
        isFavourite: (_) => false,
      );
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      port = socket.port;
      await socket.close();
      await api.start(port, lan: false);
    });

    tearDown(() async {
      await api.stop();
      container.dispose();
      await stores.close();
    });

    Future<Map<String, Object?>> status() async {
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse('http://127.0.0.1:$port/status?filter=name,lyric'));
        final response = await request.close();
        return jsonDecode(await response.transform(utf8.decoder).join()) as Map<String, Object?>;
      } finally {
        client.close(force: true);
      }
    }

    test('the same song id on two platforms gets its own lyric', () async {
      playback = const audio.AudioPlaybackState(
        track: audio.MusicTrack(id: '1', sourceId: 'kw', title: 'Song', artist: 'Singer'),
      );
      final first = status();
      await _until(() => loads.length == 1);
      loads[0].complete(
        const audio.LyricDocument(
          lines: [audio.LyricLine(start: Duration.zero, text: '酷我')],
          raw: '[00:00.00]酷我',
        ),
      );
      expect((await first)['lyric'], '[00:00.00]酷我');

      playback = const audio.AudioPlaybackState(
        track: audio.MusicTrack(id: '1', sourceId: 'wy', title: 'Song', artist: 'Singer'),
      );
      final second = status();
      await _until(() => loads.length == 2);
      loads[1].complete(
        const audio.LyricDocument(
          lines: [audio.LyricLine(start: Duration.zero, text: '网易')],
          raw: '[00:00.00]网易',
        ),
      );
      expect((await second)['lyric'], '[00:00.00]网易');
    });

    test('a late lyric cannot replace the current song or its cached document', () async {
      playback = const audio.AudioPlaybackState(
        track: audio.MusicTrack(id: '1', sourceId: 'kw', title: 'First', artist: 'Singer'),
      );
      final first = status();
      await _until(() => loads.length == 1);
      playback = const audio.AudioPlaybackState(
        track: audio.MusicTrack(id: '2', sourceId: 'kw', title: 'Second', artist: 'Singer'),
      );
      final second = status();
      await _until(() => loads.length == 2);
      loads[1].complete(
        const audio.LyricDocument(
          lines: [audio.LyricLine(start: Duration.zero, text: '新歌')],
          raw: '[00:00.00]新歌',
        ),
      );
      expect((await second)['lyric'], '[00:00.00]新歌');
      loads[0].complete(
        const audio.LyricDocument(
          lines: [audio.LyricLine(start: Duration.zero, text: '旧歌')],
          raw: '[00:00.00]旧歌',
        ),
      );
      expect((await first)['lyric'], '');
      expect((await status())['lyric'], '[00:00.00]新歌');
      expect(loads, hasLength(2));
    });
  });
}

Future<void> _until(bool Function() test) async {
  for (var i = 0; i < 200; i++) {
    if (test()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('the awaited condition never came');
}
