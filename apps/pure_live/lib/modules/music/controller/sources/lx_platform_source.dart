import 'dart:math' show Random;

import 'package:live_net/live_net.dart';
import 'package:media_core/media_core.dart' show SourceFormat;
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/modules/music/controller/lx_script_runtime.dart';
import 'package:pure_live/modules/music/controller/sources/music_browse_source.dart'
    show MusicAlbumSource, MusicArtistDetail, MusicArtistSource, musicArtistPageFromSearch;

const String platformUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36';

/// The rungs a play ask walks, best first: [asked] itself, then every lower
/// rung that [declared] (what the imported scripts advertise) and [owned]
/// (what the song's own tier list claims, when it has one) both allow, down to
/// the plain 128K every platform serves.
///
/// A song with no 320K used to fail the play and be skipped by 播放失败自动跳曲;
/// the reference plays it at the best rung it does hold, and so does this. An
/// unknown or `auto` ask starts at the top — which is what 自动 means there too.
/// The asked rung is never dropped, even when neither gate allows it: a song's
/// tier list is the site's claim, and a script sometimes answers a rung it was
/// not advertised for.
List<audio.MusicQuality> lxQualityLadder({
  required String asked,
  required Iterable<String> declared,
  required Iterable<String> owned,
}) {
  final allowed = declared.toSet();
  final held = owned.toSet();
  const ranked = LxPlatformSource.rankedQualities;
  var start = ranked.indexWhere((quality) => quality.id == asked);
  final unknownAsk = start < 0;
  if (unknownAsk) start = 0;
  final ladder = [
    for (final quality in ranked.skip(start))
      if ((allowed.contains(quality.id) || quality == audio.MusicQuality.k128) &&
          (held.isEmpty || held.contains(quality.id)))
        quality,
  ];
  if (!unknownAsk) {
    final askedQuality = ranked[start];
    if (!ladder.any((quality) => quality.id == asked)) ladder.insert(0, askedQuality);
  }
  return ladder.isEmpty ? const [audio.MusicQuality.k128] : ladder;
}

/// One lx-music platform talking to its own site over HTTP.
///
/// Every platform source resolves a play URL the same way lx-music does: the
/// imported lx source scripts are asked first, and the platform's own URL
/// endpoint (when it still has one) serves as the fallback.
abstract class LxPlatformSource extends audio.MusicSource {
  /// A source over the lx runtime and the app's shared transport.
  LxPlatformSource(this.runtime, this.http);

  final LxScriptRuntime runtime;
  final LiveHttp http;

  /// The qualities the imported scripts declare for this platform, with the
  /// plain tier every platform serves as the floor.
  List<String> scriptQualities() {
    final declared = runtime.qualitysFor(id);
    return declared.isEmpty ? const ['128k'] : declared;
  }

  /// Headers a resolved audio stream is fetched with.
  Map<String, String> get playHeaders => {'User-Agent': platformUserAgent};

  /// The platform's own play-URL endpoint, used when no script answers.
  Future<String?> fallbackUrl(audio.MusicTrack track, String qualityId) async => null;

  /// The tiers, best first. lx-music's own ladder: a song is asked from the
  /// chosen rung down to the plain one, and the first rung that answers is
  /// what plays.
  static const List<audio.MusicQuality> rankedQualities = [
    audio.MusicQuality.hires,
    audio.MusicQuality.flac24bit,
    audio.MusicQuality.flac,
    audio.MusicQuality.k320,
    audio.MusicQuality.k192,
    audio.MusicQuality.k128,
  ];

  /// The rungs to ask for [track], starting at [asked] and walking down; the
  /// rules live in [lxQualityLadder].
  List<audio.MusicQuality> qualityLadder(audio.MusicTrack track, String asked) =>
      lxQualityLadder(asked: asked, declared: scriptQualities(), owned: [for (final one in track.qualities) one.id]);

  @override
  Future<audio.TrackSource> resolveTrackSource(audio.MusicTrack track, {audio.MusicQuality? quality}) async {
    final asked = quality ?? audio.MusicQuality.k128;
    Object? firstFailure;
    for (final rung in qualityLadder(track, asked.id)) {
      try {
        final scripted = await runtime.resolveMusicUrl(track, rung.id);
        if (scripted != null && scripted.isNotEmpty) return _sourceOf(scripted, rung, fromScript: true);
        final fallback = await fallbackUrl(track, rung.id);
        if (fallback != null && fallback.isNotEmpty) {
          return _sourceOf(fallback, audio.MusicQuality.k128, fromScript: false);
        }
      } on Object catch (failure) {
        // A rung that refuses is the ladder's business; the first refusal is
        // kept, because that is the message the queue prints when no rung
        // answers at all.
        firstFailure ??= failure;
        continue;
      }
    }
    final failure = firstFailure;
    if (failure is Error) throw failure;
    if (failure is Exception) throw failure;
    if (failure != null) throw StateError('$failure');
    throw StateError('$id: no playable URL for ${track.title}');
  }

  audio.TrackSource _sourceOf(String url, audio.MusicQuality quality, {required bool fromScript}) {
    final uri = Uri.parse(url);
    return audio.TrackSource(
      uri: uri,
      headers: playHeaders,
      format: SourceFormat.fromUri(uri),
      // The rung that actually answered, not the one that was asked: the
      // player's quality label reads this, and a song served at 128K must not
      // claim 320K.
      quality: fromScript ? quality : audio.MusicQuality.k128,
    );
  }

  static const Duration _timeout = Duration(seconds: 20);

  final Random _random = Random();

  /// lx-music's rate-limit answer: a 429 waits a random 2–6 s and asks once
  /// more, giving a throttling gateway a beat to recover.
  Future<T> _patient<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on HttpStatusFailure catch (failure) {
      if (failure.statusCode != 429) rethrow;
      await Future<void>.delayed(Duration(milliseconds: 2000 + _random.nextInt(4001)));
      return await action();
    }
  }

  /// Fetches a JSON object through the app's transport, for the endpoints
  /// this source exposes beside the source contract (comments, hot words).
  Future<Map<String, Object?>> getJson(
    Uri uri, {
    String userAgent = platformUserAgent,
    Map<String, String>? headers,
    Duration timeout = _timeout,
  }) async {
    return await _patient(() async {
      final answer = await http.getJson(uri, headers: {'User-Agent': userAgent, ...?headers}, timeout: timeout);
      if (answer is! Map<String, Object?>) {
        throw StateError('$id answered a ${answer.runtimeType}, expected an object');
      }
      return answer;
    });
  }

  Future<String> getText(Uri uri, {String userAgent = platformUserAgent, Map<String, String>? headers}) {
    return _patient(() => http.getText(uri, headers: {'User-Agent': userAgent, ...?headers}, timeout: _timeout));
  }

  /// Posts a JSON body and JSON-decodes the answer.
  Future<Object?> postJson(Uri uri, Map<String, String> headers, Object? body) {
    return _patient(() => http.postJson(uri, body: body, headers: headers, timeout: _timeout));
  }

  /// Posts urlencoded fields and JSON-decodes the answer.
  Future<Object?> postForm(Uri uri, Map<String, String> fields, Map<String, String>? headers) async {
    return await _patient(() async {
      final response = await http.postForm(uri, fields: fields, headers: headers ?? const {}, timeout: _timeout);
      return response.json;
    });
  }

  static audio.MusicQuality qualityOf(String id) => switch (id) {
    '320k' => audio.MusicQuality.k320,
    'flac' => audio.MusicQuality.flac,
    'flac24bit' => audio.MusicQuality.flac24bit,
    _ => audio.MusicQuality.k128,
  };

  static String decodeName(String value) => value
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
}

/// The artist page an lx platform can answer out of its own song search.
///
/// Four of these platforms have no endpoint that lists an artist's
/// discography, but every one of them answers a song search whose rows carry
/// the artist line and the album the song sits on — which is what the artist
/// page and the home rail show. A platform with a real artist endpoint (Kuwo)
/// implements [MusicArtistSource] on its own and does not carry this.
///
/// The albums are only listed where the platform can also open one: an album
/// card whose page answers "this platform has no album page" is a door into a
/// wall, so the row stays empty until [MusicAlbumSource] is carried too.
mixin LxArtistPageFromSearch on LxPlatformSource implements MusicArtistSource {
  @override
  Future<MusicArtistDetail> artist(String name, {String? artistId}) =>
      musicArtistPageFromSearch(search, name, artistId: artistId, albumsAnswered: this is MusicAlbumSource);
}
