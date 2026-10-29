import 'dart:math' show Random;

import 'package:live_net/live_net.dart';
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
