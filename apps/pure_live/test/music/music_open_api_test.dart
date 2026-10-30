import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/modules/music/controller/music_open_api.dart'
    show
        kMusicOpenApiDefaultFilter,
        kMusicOpenApiStatusKeys,
        musicOpenApiLxLyricOf,
        musicOpenApiParseFilter,
        musicOpenApiStatusName;

void main() {
  group('filter', () {
    test('the default filter is the reference eight in status order', () {
      expect(kMusicOpenApiDefaultFilter.length, 8);
      expect(
        musicOpenApiParseFilter(null),
        ['status', 'name', 'singer', 'albumName', 'lyricLineText', 'duration', 'progress', 'playbackRate'],
      );
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
      const plain = audio.LyricDocument(lines: [
        audio.LyricLine(start: Duration(seconds: 12), text: '你好'),
      ]);
      expect(musicOpenApiLxLyricOf(plain), '');
    });

    test('word timing renders as enhanced LRC', () {
      const document = audio.LyricDocument(lines: [
        audio.LyricLine(
          start: Duration(seconds: 12, milliseconds: 500),
          text: '你好',
          words: [
            audio.LyricWord(start: Duration(seconds: 12, milliseconds: 500), text: '你'),
            audio.LyricWord(start: Duration(seconds: 13), text: '好'),
          ],
        ),
        audio.LyricLine(start: Duration(minutes: 1, seconds: 5), text: '第二行'),
      ]);
      expect(musicOpenApiLxLyricOf(document), '[00:12.50]<00:12.50>你<00:13.00>好');
    });
  });
}
