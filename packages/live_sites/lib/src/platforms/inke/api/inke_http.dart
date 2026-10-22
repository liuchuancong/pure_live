import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/inke/api/inke_endpoints.dart';
import 'package:live_sites/src/platforms/inke/inke_manifest.dart';
import 'package:live_sites/src/platforms/inke/parsers/inke_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the Inke parsers read it: the body text and the status.
typedef InkeResponse = ({String text, int status});

/// Inke's transport: a [LiveHttp] wrapper that makes the anonymous API GETs
/// and hands the parsers `(text, status)` pairs.
///
/// Every request carries [InkeEndpoints.headers] and goes as `inke`, so the
/// app routes the platform through its proxy setting. A transport breakdown
/// becomes a network failure with the transport's own words; a bad status is
/// an ordinary answer, whose meaning the parsers' status gate decides.
final class InkeHttp {
  /// Wraps [http] as the Inke transport.
  const InkeHttp(this.http);

  /// The wrapped transport.
  final LiveHttp http;

  /// GETs [url] with the platform's headers.
  Future<InkeResponse> get(Uri url, {CancelToken? cancel}) async {
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.custom(
          method: 'GET',
          site: inkeSiteId,
          url: url,
          headers: InkeEndpoints.headers,
          cancelToken: cancel,
        ),
      );
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw InkeFailure(InkeFailureKind.network, 'GET $url: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode);
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
