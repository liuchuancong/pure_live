import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/looklive/api/looklive_endpoints.dart';
import 'package:live_sites/src/platforms/looklive/looklive_manifest.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the LOOK Live parsers read it: the body text and the
/// status.
typedef LookliveResponse = ({String text, int status});

/// LOOK Live's transport: a [LiveHttp] wrapper that POSTs the `weapi` form
/// and hands the parsers `(text, status)` pairs.
///
/// Every request carries [LookliveEndpoints.requestHeaders] and goes as
/// `looklive`, so the app routes the platform through its proxy setting, and
/// has the platform's 20 s deadline. A transport breakdown becomes a network
/// failure with the transport's own words; a bad status is an ordinary
/// answer, whose meaning the parsers' status gate decides.
final class LookliveHttp {
  /// Wraps [http] as the LOOK Live transport.
  const LookliveHttp(this.http);

  /// The wrapped transport.
  final LiveHttp http;

  /// POSTs [payload] to [path] in the `weapi` envelope.
  Future<LookliveResponse> post(String path, Object? payload) async {
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.custom(
          method: 'POST',
          site: lookliveSiteId,
          url: Uri.parse('${LookliveEndpoints.apiOrigin}$path'),
          body: LookliveEndpoints.formBody(payload),
          contentType: 'application/x-www-form-urlencoded',
          headers: LookliveEndpoints.requestHeaders,
          timeout: LookliveEndpoints.requestTimeout,
        ),
      );
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw LookliveFailure(LookliveFailureKind.network, 'POST $path: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode);
  }

  /// GETs [url] with [headers], for the chat's socket.io sessions.
  Future<LookliveResponse> get(Uri url, {required Map<String, String> headers, CancelToken? cancel}) async {
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.custom(
          method: 'GET',
          site: lookliveSiteId,
          url: url,
          headers: headers,
          timeout: LookliveEndpoints.requestTimeout,
          cancelToken: cancel,
        ),
      );
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw LookliveFailure(LookliveFailureKind.network, 'GET $url: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode);
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
