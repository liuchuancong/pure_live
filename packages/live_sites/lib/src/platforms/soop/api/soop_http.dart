import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/soop/api/soop_endpoints.dart';
import 'package:live_sites/src/platforms/soop/parsers/soop_failure.dart';
import 'package:live_sites/src/platforms/soop/soop_manifest.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the SOOP parsers read it: the body text and the status.
typedef SoopResponse = ({String text, int status});

/// SOOP's transport: a [LiveHttp] wrapper that makes the API GETs and the
/// player API's form POST, and hands the parsers `(text, status)` pairs.
///
/// Every request carries [SoopEndpoints.apiHeaders] and goes as `soop`, so
/// the app routes the platform through its proxy setting. A transport
/// breakdown becomes a network failure with the transport's own words; a bad
/// status is an ordinary answer, whose meaning the parsers' status gate
/// decides.
final class SoopHttp {
  /// Wraps [http] as the SOOP transport.
  const SoopHttp(this.http);

  /// The wrapped transport.
  final LiveHttp http;

  /// GETs [url] with the platform's headers.
  Future<SoopResponse> get(Uri url, {CancelToken? cancel}) async {
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.get(url, headers: SoopEndpoints.apiHeaders(), site: soopSiteId, cancelToken: cancel),
      );
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw SoopFailure(SoopFailureKind.network, 'GET $url: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode);
  }

  /// POSTs [fields] as the player's form to [url].
  Future<SoopResponse> postForm(Uri url, Map<String, String> fields, {CancelToken? cancel}) async {
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.form(
          url,
          fields: fields,
          headers: SoopEndpoints.apiHeaders(),
          site: soopSiteId,
          cancelToken: cancel,
        ),
      );
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw SoopFailure(SoopFailureKind.network, 'POST $url: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode);
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
