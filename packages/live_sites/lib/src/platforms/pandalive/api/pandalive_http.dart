import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/pandalive/api/pandalive_endpoints.dart';
import 'package:live_sites/src/platforms/pandalive/parsers/pandalive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the PandaTV parsers read it: the body text and the status.
typedef PandaliveResponse = ({String text, int status});

/// PandaTV's transport: a [LiveHttp] wrapper that makes the four anonymous
/// form POSTs of the API and the media GETs, and hands the parsers
/// `(text, status)` pairs.
///
/// Every request goes as `pandalive`, so the app routes the platform through
/// its proxy setting. A transport breakdown becomes a network failure with
/// the transport's own words; a bad status is an ordinary answer, whose
/// meaning the parsers' status gate decides (the platform's business
/// refusals arrive as HTTP 400 answers).
final class PandaliveHttp {
  /// Wraps [http] as the PandaTV transport.
  const PandaliveHttp(this.http);

  /// The wrapped transport.
  final LiveHttp http;

  /// POSTs [fields] as the website's form to [path] of the API, standing for
  /// [referer].
  Future<PandaliveResponse> post(
    String path,
    Map<String, String> fields, {
    required String referer,
    CancelToken? cancel,
    Duration? timeout,
  }) async {
    final url = Uri.https(PandaliveEndpoints.apiHost, path);
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.form(
          url,
          fields: fields,
          headers: {...PandaliveEndpoints.headers(referer), 'content-type': 'application/x-www-form-urlencoded'},
          site: PandaliveEndpoints.siteId,
          timeout: timeout,
          cancelToken: cancel,
        ),
      );
    } on CancelledFailure {
      rethrow;
    } on TransportFailure catch (failure) {
      throw PandaliveFailure(PandaliveFailureKind.network, 'POST $path: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode);
  }

  /// GETs [url] with [headers] (an IVS master or variant playlist).
  Future<PandaliveResponse> get(Uri url, {required Map<String, String> headers, CancelToken? cancel}) async {
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.custom(
          method: 'GET',
          site: PandaliveEndpoints.siteId,
          url: url,
          headers: headers,
          cancelToken: cancel,
        ),
      );
    } on CancelledFailure {
      rethrow;
    } on TransportFailure catch (failure) {
      throw PandaliveFailure(PandaliveFailureKind.network, 'GET $url: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode);
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
