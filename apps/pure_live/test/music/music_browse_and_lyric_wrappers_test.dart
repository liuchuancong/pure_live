import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs, StorageStores;
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/modules/music/controller/library/music_library.dart' show musicTrackKey;
import 'package:pure_live/modules/music/controller/lyric/music_lyric_settings.dart';
import 'package:pure_live/modules/music/controller/sources/music_browse_source.dart';
import 'package:pure_live/modules/music/controller/sources/music_display_lyric.dart';
import 'package:pure_live/modules/music/controller/sources/music_source_cache.dart';

/// The layer the platforms share: the artist page a search alone can build
/// (its subject, its albums deduped, its photo taken only from the rows the
/// artist headlines), the capability reader that walks under the lyric
/// wrappers, the lyric cache that never asks a platform twice, and the
/// display dress that strips the word timing and turns the text
/// traditional on the way to the screen.
void main() {
  group('the artist page from a search', () {
    test('the credit line leads, its features ride, and the photo stays with the headliner', () async {
      audio.MusicTrack row(
        String id, {
        required String artist,
        String album = '',
        String albumId = '',
        String? artistPic,
      }) => audio.MusicTrack(
        id: id,
        sourceId: 'kw',
        title: '晴天',
        artist: artist,
        album: album,
        albumId: albumId.isEmpty ? null : albumId,
        metadata: artistPic == null ? const {} : {'artistPic': artistPic},
      );

      final page = await musicArtistPageFromSearch(
        (keyword, {page = 1, pageSize = 30}) async => audio.MusicSourcePage(
          items: [
            row('1', artist: '周杰伦', artistPic: 'http://pic/headline.jpg', album: '叶惠美', albumId: '9001'),
            // A featured player's photo is not the page's, even when the row ships one.
            row('2', artist: '周杰伦、阿信', artistPic: 'http://pic/feature.jpg', album: '叶惠美', albumId: '9001'),
            row('3', artist: '阿信'), // not the page's subject at all
            row('4', artist: '周杰伦'), // no album line, no card
            row('5', artist: '周杰伦', album: '十二新作', albumId: '0'), // a zero id is no album
          ],
          total: 5,
        ),
        '周杰伦、阿信', // the caller passes the whole credit line
      );

      expect(page.name, '周杰伦'); // the subject is who the line leads with
      expect(page.songs.map((track) => track.id), ['1', '2', '4', '5']); // the feature rides, the stranger drops
      expect(page.avatarUri.toString(), 'http://pic/headline.jpg');
      expect(page.albums.map((album) => album.id), ['9001']); // the twin dropped, the empty ones never landed
      expect(page.albums.single.name, '叶惠美');
      expect(page.artistId, isNull);
    });

    test('a platform that cannot open an album advertises no cards', () async {
      audio.MusicTrack row(String id, String album, String albumId) => audio.MusicTrack(
        id: id,
        sourceId: 'kw',
        title: '晴天',
        artist: '周杰伦',
        album: album,
        albumId: albumId.isEmpty ? null : albumId,
      );

      final page = await musicArtistPageFromSearch(
        (keyword, {page = 1, pageSize = 30}) async => audio.MusicSourcePage(items: [row('1', '叶惠美', '9001')], total: 1),
        '周杰伦',
        artistId: '31',
        albumsAnswered: false,
      );
      expect(page.albums, isEmpty); // a card that dead-ends is worse than no card
      expect(page.artistId, '31');
    });
  });

  group('the capability reader', () {
    test('it walks under the lyric wrapper to find what the platform can do', () {
      final platform = _StubSource();
      final wrapped = CachedLyricSource(platform);
      expect(musicCapabilityOf<_StubSource>(wrapped), same(platform));
      expect(musicCapabilityOf<MusicAlbumSource>(wrapped), isNull); // a thing it never had
      expect(musicCapabilityOf<_StubSource>(platform), same(platform)); // no wrapper at all
    });
  });

  group('the lyric cache', () {
    late StorageStores stores;

    setUp(() async {
      stores = await StorageStores.openInMemory();
      await StoragePrefs.init();
    });

    tearDown(() => stores.close());

    test('a lyric is asked once, kept, and forgotten on demand', () async {
      final platform = _StubSource(
        lyric: const audio.MusicLyricPayload(
          lyric: '[00:01.000]一句',
          translation: '[00:01.000]译文',
          romanization: '[00:01.000]yi ju',
        ),
      );
      final cached = CachedLyricSource(platform);

      final first = await cached.resolveLyric(_track());
      expect(first!.lyric, '[00:01.000]一句');
      expect(platform.lyricAsks, 1);

      final second = await cached.resolveLyric(_track());
      expect(second!.lyric, '[00:01.000]一句');
      expect(second.translation, '[00:01.000]译文'); // the tracks ride along through the round trip
      expect(second.romanization, '[00:01.000]yi ju');
      expect(platform.lyricAsks, 1); // the platform was never asked twice

      await cached.forget(_track());
      await cached.resolveLyric(_track());
      expect(platform.lyricAsks, 2); // forgotten means asked again

      expect(CachedLyricSource.storedLyricCount(), 1);
      await CachedLyricSource.clearLyricCache();
      expect(CachedLyricSource.storedLyricCount(), 0);
    });

    test('a platform with no lyric, or one that fails, leaves nothing cached', () async {
      final silent = _StubSource();
      final cached = CachedLyricSource(silent);
      expect(await cached.resolveLyric(_track()), isNull);
      expect(CachedLyricSource.storedLyricCount(), 0);

      final broken = _StubSource(lyricThrows: true);
      expect(await CachedLyricSource(broken).resolveLyric(_track()), isNull); // the wrapper swallows the failure
      expect(CachedLyricSource.storedLyricCount(), 0);
    });

    test('the cache holds two hundred songs, the oldest falling off', () async {
      // Two hundred seeded entries; the oldest is the one the map saw first.
      final seeded = <String, Object?>{
        for (var i = 0; i < 200; i++) 'kw:seed$i': {'lyric': '[00:01.000]第$i首'},
      };
      await StoragePrefs.setString(kMusicLyricCacheKey, jsonEncode(seeded));

      final cached = CachedLyricSource(_StubSource(lyric: const audio.MusicLyricPayload(lyric: '[00:01.000]新词')));
      await cached.resolveLyric(_track());

      final keys = _storedKeys();
      expect(keys, hasLength(200)); // the limit holds
      expect(keys.contains('kw:seed0'), isFalse); // the oldest fell off
      expect(keys.contains('kw:seed199'), isTrue); // the newest seed stayed
      expect(keys.contains(musicTrackKey(_track())), isTrue); // and so did the song just asked
    });
  });

  group('the display dress', () {
    // A track of its own: the cache the group above seeded must not answer
    // for it — the dress has to see the platform's own answer.
    const dressTrack = audio.MusicTrack(
      id: 'dress',
      sourceId: 'kw',
      title: '晴天',
      artist: '周杰伦',
      duration: Duration(seconds: 269),
    );

    Future<audio.MusicLyricPayload?> dressed(
      audio.MusicLyricPayload payload, {
      bool traditionalizeLyric = false,
      bool playWordLyrics = true,
    }) {
      final wrapped = DisplayLyricSource(
        _StubSource(lyric: payload),
        settingsOf: () => MusicLyricsSettings.standard.copyWith(
          traditionalizeLyric: traditionalizeLyric,
          playWordLyrics: playWordLyrics,
        ),
      );
      return wrapped.resolveLyric(dressTrack);
    }

    test('the word timing survives by default and strips when the viewer says so', () async {
      const payload = audio.MusicLyricPayload(lyric: '[00:01.000]我<0,500>爱<500,500>你');
      expect((await dressed(payload))!.lyric, contains('<0,500>')); // the default keeps the word timing
      expect((await dressed(payload, playWordLyrics: false))!.lyric, '[00:01.000]我爱你'); // tags gone, words left
    });

    test('the traditional turn dresses the translation and leaves the roman alone', () async {
      const payload = audio.MusicLyricPayload(
        lyric: '[00:01.000]万与东',
        translation: '[00:01.000]万译',
        romanization: '[00:01.000]wan',
      );
      final turned = await dressed(payload, traditionalizeLyric: true);
      expect(turned!.lyric, '[00:01.000]萬與東'); // the pairs the shipped table names
      expect(turned.translation, '[00:01.000]萬譯'); // the translation turned with it
      expect(turned.romanization, '[00:01.000]wan'); // roman letters are not for turning
    });

    test('a silent platform rides the fallback, and the fallback is dressed too', () async {
      const wordly = audio.MusicLyricPayload(lyric: '[00:01.000]我<0,500>爱');
      audio.MusicTrack? asked;
      final wrapped = DisplayLyricSource(
        _StubSource(),
        settingsOf: () => MusicLyricsSettings.standard.copyWith(playWordLyrics: false),
        lyricFallback: (track) async {
          asked = track;
          return wordly;
        },
      );

      final payload = await wrapped.resolveLyric(dressTrack);
      expect(asked!.id, 'dress'); // the fallback got the ask
      expect(payload!.lyric, '[00:01.000]我爱'); // the fallback's answer dressed like any other

      final silent = DisplayLyricSource(
        _StubSource(),
        settingsOf: () => MusicLyricsSettings.standard,
        lyricFallback: (track) async => null,
      );
      expect(await silent.resolveLyric(dressTrack), isNull); // nothing anywhere is no lyric
    });
  });
}

Set<String> _storedKeys() {
  final raw = StoragePrefs.getString(kMusicLyricCacheKey);
  if (raw == null || raw.isEmpty) return <String>{};
  return (jsonDecode(raw) as Map).keys.cast<String>().toSet();
}

audio.MusicTrack _track() => const audio.MusicTrack(
  id: '9001',
  sourceId: 'kw',
  title: '晴天',
  artist: '周杰伦',
  album: '叶惠美',
  duration: Duration(seconds: 269),
);

/// A platform the wrappers can wrap: it counts its lyric asks and can be
/// told to answer, stay silent or fail.
final class _StubSource extends audio.MusicSource {
  _StubSource({this.lyric, this.lyricThrows = false});

  final audio.MusicLyricPayload? lyric;
  final bool lyricThrows;
  int lyricAsks = 0;

  @override
  String get id => 'stub';

  @override
  String get name => 'stub';

  @override
  Future<audio.MusicLyricPayload?> resolveLyric(audio.MusicTrack track) async {
    lyricAsks += 1;
    if (lyricThrows) throw StateError('the stub refuses');
    return lyric;
  }

  @override
  Future<audio.TrackSource> resolveTrackSource(audio.MusicTrack track, {audio.MusicQuality? quality}) {
    throw UnimplementedError();
  }
}
