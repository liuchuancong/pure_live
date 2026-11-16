import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/modules/music/controller/lyric/music_lyric_settings.dart' show MusicLyricsSettings;
import 'package:pure_live/modules/music/controller/sources/chinese_s2t.dart' show traditionalize;
import 'package:pure_live/modules/music/controller/sources/music_source_cache.dart' show CachedLyricSource;

final RegExp _wordTag = RegExp(r'<\d+,\d+>');

/// A source whose lyrics are dressed for the screen before they reach the
/// player: lx-music's `player.isS2t` traditionalizes the text and its
/// `player.isPlayLxlrc` decides whether word timing survives. The raw
/// payloads stay cached below, so a flipped preference applies from the next
/// song load onward.
final class DisplayLyricSource extends CachedLyricSource {
  /// Wraps [inner]'s lyrics behind the current display preferences.
  DisplayLyricSource(super.inner, {required this.settingsOf, this.lyricFallback});

  final MusicLyricsSettings Function() settingsOf;

  /// Asked when this platform holds no lyric for the track: the walk the
  /// host builds over the other platforms, so a song its own site never
  /// captioned still sings. The walk resolves on the raw sources and
  /// never re-enters this class.
  final Future<audio.MusicLyricPayload?> Function(audio.MusicTrack track)? lyricFallback;

  @override
  Future<audio.MusicLyricPayload?> resolveLyric(audio.MusicTrack track) async {
    var payload = await super.resolveLyric(track);
    payload ??= await lyricFallback?.call(track);
    if (payload == null) return null;
    return _dress(payload);
  }

  audio.MusicLyricPayload _dress(audio.MusicLyricPayload payload) {
    final settings = settingsOf();
    var lyric = payload.lyric;
    if (!settings.playWordLyrics) lyric = lyric.replaceAll(_wordTag, '');
    if (settings.traditionalizeLyric) {
      lyric = traditionalize(lyric);
      final translation = payload.translation;
      final romanization = payload.romanization;
      return audio.MusicLyricPayload(
        lyric: lyric,
        translation: translation == null ? null : traditionalize(translation),
        romanization: romanization,
        format: payload.format,
      );
    }
    if (lyric == payload.lyric) return payload;
    return audio.MusicLyricPayload(
      lyric: lyric,
      translation: payload.translation,
      romanization: payload.romanization,
      format: payload.format,
    );
  }
}
