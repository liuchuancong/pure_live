// The two rules the music module borrowed from lx-music's play path, pinned
// where they can be read: the rungs a play ask walks when a song does not hold
// the chosen tier, and how far cross-source matching may concede before it is
// a different song.
import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/modules/music/controller/sources/lx_platform_source.dart' show lxQualityLadder;
import 'package:pure_live/modules/music/controller/sources/music_source_match.dart' show findSameSong;

void main() {
  List<String> ladder({required String asked, required List<String> declared, List<String> owned = const []}) => [
    for (final quality in lxQualityLadder(asked: asked, declared: declared, owned: owned)) quality.id,
  ];

  group('the quality ladder', () {
    test('walks down from the asked rung through what the song holds', () {
      expect(ladder(asked: '320k', declared: ['128k', '320k', 'flac'], owned: ['128k', '320k']), ['320k', '128k']);
    });

    test('still asks the rung that was chosen, even when no gate allows it', () {
      // The site claimed the song has no lossless copy and the scripts do not
      // advertise it, yet a script sometimes answers a rung it was not
      // advertised for — the ask must not silently start lower.
      expect(ladder(asked: 'flac', declared: ['128k']), ['flac', '128k']);
    });

    test('an unknown or automatic ask starts at the top of what is offered', () {
      expect(ladder(asked: 'auto', declared: ['128k', 'flac']), ['flac', '128k']);
      expect(ladder(asked: '192k', declared: ['128k', '192k'], owned: ['128k']), ['192k', '128k']);
    });

    test('a song that names no tiers takes every rung the scripts declare', () {
      expect(ladder(asked: 'flac24bit', declared: ['128k', '320k', 'flac', 'flac24bit']), [
        'flac24bit',
        'flac',
        '320k',
        '128k',
      ]);
    });

    test('the plain rung is always there to land on', () {
      expect(ladder(asked: '128k', declared: []), ['128k']);
    });
  });

  group('cross-source matching', () {
    const target = audio.MusicTrack(
      id: 'a',
      title: '平凡之路',
      artist: '朴树',
      album: '猎户星座',
      sourceId: 'kw',
      duration: Duration(seconds: 300),
    );

    audio.MusicTrack candidate({
      String title = '平凡之路',
      String artist = '朴树',
      String album = '猎户星座',
      String sourceId = 'tx',
      int seconds = 302,
    }) => audio.MusicTrack(
      id: 'c',
      title: title,
      artist: artist,
      album: album,
      sourceId: sourceId,
      duration: Duration(seconds: seconds),
    );

    test('prefers the strictest reading among the answers', () {
      // A candidate whose album names a different record passes only the loose
      // readings; the exact one must still win although it is asked second.
      final conflicting = candidate(album: '生在夏末');
      final exact = candidate();
      expect(findSameSong(target, [conflicting, exact])?.album, '猎户星座');
    });

    test('takes a song whose album field is missing on one side', () {
      expect(findSameSong(target, [candidate(album: '')]), isNotNull);
    });

    test('takes a song whose singer string no two sites write alike', () {
      // The case the strict test lost: a featured-artist string written the
      // other platform's way, with the duration still saying it is the song.
      expect(findSameSong(target, [candidate(artist: '朴树 / 张悬')]), isNotNull);
    });

    test('refuses a same-named song at a different length', () {
      expect(findSameSong(target, [candidate(seconds: 180)]), isNull);
    });

    test('never answers with the source the track already came from', () {
      expect(findSameSong(target, [candidate(sourceId: 'kw')]), isNull);
    });
  });
}
