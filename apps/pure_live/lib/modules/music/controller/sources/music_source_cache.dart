import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/modules/music/controller/music_library.dart' show musicTrackKey;

/// The preference the fetched lyrics are cached under.
const String kMusicLyricCacheKey = 'music.lyrics.cache';

/// How many songs keep a cached lyric; the oldest falls off first.
const int kMusicLyricCacheLimit = 200;

/// A source whose lyrics are remembered.
///
/// lx-music keeps fetched lyrics in its database so a replayed song never
/// asks its platform twice; this does the same against the preference store.
/// Everything else — search, boards, play URLs — rides the wrapped source
/// untouched.
class CachedLyricSource extends audio.MusicSource {
  /// Wraps [inner] with a lyric cache.
  CachedLyricSource(this.inner);

  /// The platform source the calls ride on.
  final audio.MusicSource inner;

  @override
  String get id => inner.id;

  @override
  String get name => inner.name;

  @override
  Future<audio.MusicSourcePage<audio.MusicTrack>> search(String keyword, {int page = 1, int pageSize = 30}) =>
      inner.search(keyword, page: page, pageSize: pageSize);

  @override
  Future<audio.MusicTrack> trackDetail(audio.MusicTrack track) => inner.trackDetail(track);

  @override
  Future<List<audio.MusicQuality>> qualities(audio.MusicTrack track) => inner.qualities(track);

  @override
  Future<audio.TrackSource> resolveTrackSource(audio.MusicTrack track, {audio.MusicQuality? quality}) =>
      inner.resolveTrackSource(track, quality: quality);

  @override
  Future<List<audio.MusicCatalog>> catalogs() => inner.catalogs();

  @override
  Future<audio.MusicSourcePage<audio.MusicTrack>> catalogItems(audio.MusicCatalog catalog, {int page = 1}) =>
      inner.catalogItems(catalog, page: page);

  @override
  Future<audio.MusicLyricPayload?> resolveLyric(audio.MusicTrack track) async {
    final cached = _read()[musicTrackKey(track)];
    if (cached != null) return cached;
    try {
      final payload = await inner.resolveLyric(track);
      if (payload != null) await _write(track, payload);
      return payload;
    } on Object {
      return null;
    }
  }

  /// Forgets [track]'s cached lyric; a refresh asks the platform again.
  Future<void> forget(audio.MusicTrack track) async {
    final cache = _read();
    if (cache.isEmpty) return;
    final next = _serialized({...cache}..remove(musicTrackKey(track)));
    await StoragePrefs.setString(kMusicLyricCacheKey, next);
  }

  Map<String, audio.MusicLyricPayload> _read() {
    try {
      final raw = StoragePrefs.getString(kMusicLyricCacheKey);
      if (raw == null || raw.isEmpty) return const <String, audio.MusicLyricPayload>{};
      final json = jsonDecode(raw);
      if (json is! Map) return const <String, audio.MusicLyricPayload>{};
      final cache = <String, audio.MusicLyricPayload>{};
      for (final entry in json.entries) {
        if (entry.key is! String || entry.value is! Map<String, Object?>) continue;
        final payload = _payloadOf(entry.value as Map<String, Object?>);
        if (payload != null) cache[entry.key as String] = payload;
      }
      return cache;
    } on Object {
      return const <String, audio.MusicLyricPayload>{};
    }
  }

  static audio.MusicLyricPayload? _payloadOf(Map<String, Object?> json) {
    final lyric = json['lyric'];
    if (lyric is! String || lyric.isEmpty) return null;
    String? text(String key) {
      final value = json[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    return audio.MusicLyricPayload(
      lyric: lyric,
      translation: text('translation'),
      romanization: text('romanization'),
      format: text('format') ?? 'lrc',
    );
  }

  Future<void> _write(audio.MusicTrack track, audio.MusicLyricPayload payload) async {
    final next = <String, audio.MusicLyricPayload>{..._read()}
      ..remove(musicTrackKey(track))
      ..[musicTrackKey(track)] = payload;
    while (next.length > kMusicLyricCacheLimit) {
      next.remove(next.keys.first);
    }
    await StoragePrefs.setString(kMusicLyricCacheKey, _serialized(next));
  }

  static String _serialized(Map<String, audio.MusicLyricPayload> cache) => jsonEncode({
    for (final entry in cache.entries)
      entry.key: {
        'lyric': entry.value.lyric,
        if (entry.value.translation != null) 'translation': entry.value.translation,
        if (entry.value.romanization != null) 'romanization': entry.value.romanization,
        if (entry.value.format != 'lrc') 'format': entry.value.format,
      },
  });
}
