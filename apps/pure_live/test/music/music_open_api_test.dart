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
import 'package:pure_live/modules/music/controller/playback/music_playback.dart' show MusicOpenApiPlayer;

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
    late _FakeOpenApiPlayer player;
    late audio.AudioPlaybackState playback;
    late List<Completer<audio.LyricDocument>> loads;
    late int port;

    setUp(() async {
      stores = await StorageStores.openInMemory();
      await StoragePrefs.init();
      container = ProviderContainer();
      playback = audio.AudioPlaybackState.idle;
      player = _FakeOpenApiPlayer();
      loads = [];
      api = MusicOpenApi(
        () => player,
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
      final body = await _request(port, '/status?filter=name,lyric');
      return jsonDecode(body) as Map<String, Object?>;
    }

    test('play and pause are explicit commands rather than toggles', () async {
      playback = const audio.AudioPlaybackState(
        track: audio.MusicTrack(id: '1', sourceId: 'kw', title: 'Song', artist: 'Singer'),
      );
      await _request(port, '/play');
      expect(player.plays, 1);
      expect(player.pauses, 0);
      expect(player.toggles, 0);

      playback = const audio.AudioPlaybackState(
        track: audio.MusicTrack(id: '1', sourceId: 'kw', title: 'Song', artist: 'Singer'),
        playing: true,
      );
      await _request(port, '/pause');
      expect(player.plays, 1);
      expect(player.pauses, 1);
      expect(player.toggles, 0);
    });

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

    test('each subscription keeps its own last status', () async {
      playback = const audio.AudioPlaybackState(
        track: audio.MusicTrack(id: '1', sourceId: 'kw', title: 'First', artist: 'Singer'),
      );
      final firstPending = _subscribe(port, 'name');
      await _until(() => loads.length == 1);
      loads[0].complete(
        const audio.LyricDocument(
          lines: [audio.LyricLine(start: Duration.zero, text: '')],
        ),
      );
      final first = await firstPending;
      addTearDown(first.close);
      expect(await first.nextEvent(), {'event': 'name', 'data': '"First"'});

      playback = const audio.AudioPlaybackState(
        track: audio.MusicTrack(id: '2', sourceId: 'kw', title: 'Second', artist: 'Singer'),
      );
      final secondPending = _subscribe(port, 'name');
      await _until(() => loads.length == 2);
      loads[1].complete(
        const audio.LyricDocument(
          lines: [audio.LyricLine(start: Duration.zero, text: '')],
        ),
      );
      final second = await secondPending;
      addTearDown(second.close);
      expect(await second.nextEvent(), {'event': 'name', 'data': '"Second"'});

      api.pushPlayerStatus();
      expect(await first.nextEvent(), {'event': 'name', 'data': '"Second"'});
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

Future<String> _request(int port, String path) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse('http://127.0.0.1:$port$path'));
    final response = await request.close();
    return await response.transform(utf8.decoder).join();
  } finally {
    client.close(force: true);
  }
}

Future<_SseClient> _subscribe(int port, String filter) async {
  final client = HttpClient();
  final request = await client.getUrl(Uri.parse('http://127.0.0.1:$port/subscribe-player-status?filter=$filter'));
  final response = await request.close();
  return _SseClient(client, response);
}

final class _SseClient {
  _SseClient(this._client, HttpClientResponse response)
    : _lines = StreamIterator(response.transform(utf8.decoder).transform(const LineSplitter()));

  final HttpClient _client;
  final StreamIterator<String> _lines;

  Future<Map<String, String>> nextEvent() async {
    final event = <String, String>{};
    while (await _lines.moveNext()) {
      final line = _lines.current;
      if (line.isEmpty) {
        if (event.isNotEmpty) return event;
        continue;
      }
      final separator = line.indexOf(':');
      if (separator <= 0) continue;
      final value = line.substring(separator + 1);
      event[line.substring(0, separator)] = value.startsWith(' ') ? value.substring(1) : value;
    }
    throw StateError('the event stream closed');
  }

  Future<void> close() async {
    await _lines.cancel();
    _client.close(force: true);
  }
}

final class _FakeOpenApiPlayer implements MusicOpenApiPlayer {
  int plays = 0;
  int pauses = 0;
  int toggles = 0;

  @override
  Future<void> toggle() async {
    toggles++;
  }

  @override
  Future<void> playCurrent() async {
    plays++;
  }

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> next() async {}

  @override
  Future<void> previous() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setMuted({required bool muted}) async {}
}

Future<void> _until(bool Function() test) async {
  for (var i = 0; i < 200; i++) {
    if (test()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('the awaited condition never came');
}
