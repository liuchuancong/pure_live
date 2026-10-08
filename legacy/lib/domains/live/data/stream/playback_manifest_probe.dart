import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:media_core_ingest/media_core_ingest.dart';
import 'package:pure_live/core/network/http_client.dart';

/// What one manifest read told us about a source.
typedef PlaybackManifestProbe = ({HlsManifestKind kind, String body});

/// Reads [url] once, bounded, so the playback input can be decided from what the
/// manifest actually contains instead of from a per-platform guess.
///
/// The manifest form is the only thing that matters: a manifest that already
/// writes absolute URLs is handed to the player untouched, while one whose
/// children are bare names (`media.95.mp4`) or absolute paths has to be rewritten
/// over loopback first, or a resolver that loses the manifest URL turns them
/// into local paths (`\tc.livehls\...\media.95.mp4`).
///
/// Returns null when the manifest cannot be read - the caller then falls back to
/// its declared needs and finally to a direct open. Live players re-read their
/// manifest every target duration, so one extra bounded read costs nothing that
/// changes the provider's behaviour.
Future<PlaybackManifestProbe?> probePlaybackManifest(
  String url, {
  Map<String, String> headers = const <String, String>{},
  Dio? client,
  Duration timeout = const Duration(seconds: 3),
  int maximumBytes = 512 * 1024,
}) async {
  final Dio dio = client ?? HttpClient.instance.dio;
  try {
    final Response<List<int>> response = await dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: headers,
        followRedirects: true,
        receiveTimeout: timeout,
        sendTimeout: timeout,
        validateStatus: (int? status) => status == 200,
      ),
    );
    final List<int>? bytes = response.data;
    if (bytes == null || bytes.isEmpty || bytes.length > maximumBytes) return null;
    final String body = _stripBom(utf8.decode(bytes, allowMalformed: true));
    if (!body.trimLeft().startsWith('#EXT')) return null;
    return (kind: classifyHlsManifest(body), body: body);
  } catch (_) {
    // An unreadable manifest is not an error here: the player may still open the
    // source directly, and a provider that rejects this read is exactly the case
    // where guessing would be wrong.
    return null;
  }
}

String _stripBom(String value) => value.startsWith('\uFEFF') ? value.substring(1) : value;
