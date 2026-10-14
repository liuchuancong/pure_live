import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the youtube parsers read it: the decoded body, the status and
/// the lower-cased response headers.
typedef YouTubeResponse = ({String text, int status, Map<String, String> headers});

/// YouTube's transport: a [LiveHttp] wrapper that hands parsers
/// `(text, status, headers)` triples and maps transport breakdowns onto
/// [YoutubeFailureKind.network]. Bad statuses are ordinary answers — the
/// parsers decide what 400/401/403/404/429/5xx mean for their endpoint. A
/// cancelled request rethrows so the danmaku poll loop stops.
final class YouTubeHttp {
  /// Wraps [http] as the youtube transport.
  const YouTubeHttp(this.http);

  /// The wrapped transport (the danmaku session drives it directly).
  final LiveHttp http;

  /// GETs [url] with [headers]; a transport breakdown other than a
  /// cancellation becomes a network [YouTubeFailure].
  Future<YouTubeResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    Duration? timeout,
    CancelToken? cancel,
  }) async {
    try {
      final response = await http.send(
        LiveRequest.custom(
          method: 'GET',
          site: 'youtube',
          url: url,
          headers: headers,
          timeout: timeout,
          cancelToken: cancel,
        ),
      );
      return (text: response.text, status: response.statusCode, headers: response.headers);
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw YouTubeFailure(YoutubeFailureKind.network, 'GET $url: $failure', cause: failure);
    }
  }

  /// POSTs [json] as an InnerTube JSON body and returns the raw answer; bad
  /// statuses stay ordinary answers so the parsers can map 401/403/404/429/400
  /// to the endpoint's meaning. A transport breakdown other than a
  /// cancellation becomes a network [YouTubeFailure].
  Future<YouTubeResponse> postJson(
    Uri url, {
    required Object? json,
    Map<String, String> headers = const {},
    Duration? timeout,
    CancelToken? cancel,
  }) async {
    try {
      final response = await http.send(
        LiveRequest.json(url, body: json, site: 'youtube', headers: headers, timeout: timeout, cancelToken: cancel),
      );
      return (text: response.text, status: response.statusCode, headers: response.headers);
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw YouTubeFailure(YoutubeFailureKind.network, 'POST $url: $failure', cause: failure);
    }
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
