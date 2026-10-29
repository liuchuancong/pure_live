import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/modules/music/controller/music_settings.dart' show MusicSettings;
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
  DisplayLyricSource(super.inner, {required this.settingsOf});

  final MusicSettings Function() settingsOf;

  @override
  Future<audio.MusicLyricPayload?> resolveLyric(audio.MusicTrack track) async {
    final payload = await super.resolveLyric(track);
    if (payload == null) return null;
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
