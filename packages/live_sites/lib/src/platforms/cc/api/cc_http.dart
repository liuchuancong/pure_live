import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/cc/api/cc_endpoints.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the CC parsers read it: the body text and the status.
typedef CcResponse = ({String text, int status});

/// CC's transport: a [LiveHttp] wrapper that makes the API GETs and the
/// Dashen catalog's GET and JSON POST, and hands the parsers `(text, status)`
/// pairs.
///
/// Every request carries the endpoint's headers and goes as `cc`, so the app
/// routes the platform through its proxy setting. A transport breakdown
/// becomes a network failure with the transport's own words; a bad status is
/// an ordinary answer, whose meaning the parsers' status gate decides.
final class CcHttp {
  /// Wraps [http] as the CC transport.
  const CcHttp(this.http);

  /// The wrapped transport.
  final LiveHttp http;

  /// GETs [url] with the platform's headers, or [headers] when given (the
  /// Dashen catalog goes with its own), and [timeout] when given (the
  /// existence check bounds itself).
  Future<CcResponse> get(Uri url, {Map<String, String>? headers, CancelToken? cancel, Duration? timeout}) async {
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.get(url, headers: headers ?? CcEndpoints.apiHeaders, site: CcEndpoints.site, timeout: timeout),
      );
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw CcFailure(CcFailureKind.network, 'GET $url: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode);
  }

  /// POSTs [body] as JSON to [url] (the Dashen live configuration).
  Future<CcResponse> postJson(Uri url, Object? body, {Map<String, String>? headers, CancelToken? cancel}) async {
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.json(
          url,
          body: body,
          headers: headers ?? CcEndpoints.apiHeaders,
          site: CcEndpoints.site,
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
