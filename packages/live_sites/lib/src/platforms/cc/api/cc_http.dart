import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/cc/api/cc_endpoints.dart';
import 'package:live_sites/src/platforms/cc/cc_manifest.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the CC parsers read it: the body text and the status.
typedef CcResponse = ({String text, int status});

/// NetEase CC's transport: a [LiveHttp] wrapper that makes the anonymous API
/// GETs, the room-page GETs and the Dashen JSON POST, and hands the parsers
/// `(text, status)` pairs.
///
/// Every request carries [CcEndpoints.apiHeaders] (or the headers given) and
/// goes as `cc`, so the app routes the platform through its proxy setting. A
/// transport breakdown becomes a network failure with the transport's own
/// words; a bad status is an ordinary answer, whose meaning the parsers'
/// status gate decides per endpoint. A caller's cancellation rethrows.
final class CcHttp {
  /// Wraps [http] as the CC transport.
  const CcHttp(this.http);

  /// The wrapped transport.
  final LiveHttp http;

  /// GETs [url] with the API headers, or [headers] when given (the Dashen
  /// registry goes with its own, a media probe with the media ones), within
  /// [timeout] when given (the existence check's 8 s).
  Future<CcResponse> get(Uri url, {Map<String, String>? headers, CancelToken? cancel, Duration? timeout}) async {
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.get(
          url,
          headers: headers ?? CcEndpoints.apiHeaders,
          site: ccSiteId,
          timeout: timeout,
          cancelToken: cancel,
        ),
      );
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw CcFailure(CcFailureKind.network, 'GET $url: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode);
  }

  /// POSTs [body] as JSON to [url] (the Dashen configuration's `id`).
  Future<CcResponse> postJson(Uri url, Object? body, {Map<String, String>? headers, CancelToken? cancel}) async {
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.json(
          url,
          body: body,
          headers: headers ?? CcEndpoints.dashenHeaders,
          site: ccSiteId,
          cancelToken: cancel,
        ),
      );
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw CcFailure(CcFailureKind.network, 'POST $url: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode);
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
