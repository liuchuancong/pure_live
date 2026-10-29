import 'dart:convert' show jsonDecode, utf8;

import 'package:http/http.dart' as http;
import 'package:media_core/media_core.dart' show SourceFormat;
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/modules/music/controller/lx_script_runtime.dart';

const String platformUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36';

/// One lx-music platform talking to its own site over HTTP.
///
/// Every platform source resolves a play URL the same way lx-music does: the
/// imported lx source scripts are asked first, and the platform's own URL
/// endpoint (when it still has one) serves as the fallback.
abstract class LxPlatformSource extends audio.MusicSource {
  /// A source over the lx runtime and an HTTP client.
  LxPlatformSource(this.runtime) : _http = http.Client();

  final LxScriptRuntime runtime;
  final http.Client _http;

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

  @override
  Future<audio.TrackSource> resolveTrackSource(audio.MusicTrack track, {audio.MusicQuality? quality}) async {
    final qualityId = quality?.id ?? '128k';
    final scripted = await runtime.resolveMusicUrl(track, qualityId);
    final url = scripted ?? await fallbackUrl(track, qualityId);
    if (url == null || url.isEmpty) {
      throw StateError('$id: no playable URL for ${track.title}');
    }
    final uri = Uri.parse(url);
    return audio.TrackSource(
      uri: uri,
      headers: playHeaders,
      format: SourceFormat.fromUri(uri),
      quality: scripted == null ? audio.MusicQuality.k128 : quality,
    );
  }

  /// Fetches a JSON object through the module's client, for the endpoints
  /// this source exposes beside the source contract (comments, hot words).
  Future<Map<String, Object?>> getJson(
    Uri uri, {
    String userAgent = platformUserAgent,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final response = await _http.get(uri, headers: {'User-Agent': userAgent, ...?headers}).timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('$id HTTP ${response.statusCode}');
    }
    return jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true)) as Map<String, Object?>;
  }

  Future<String> getText(Uri uri, {String userAgent = platformUserAgent, Map<String, String>? headers}) async {
    final response = await _http
        .get(uri, headers: {'User-Agent': userAgent, ...?headers})
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('$id HTTP ${response.statusCode}');
    }
    return utf8.decode(response.bodyBytes, allowMalformed: true);
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
