import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/kilakila/api/kilakila_endpoints.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the KilaKila parsers read it: the body text and the status.
typedef KilakilaResponse = ({String text, int status});

/// KilaKila's transport: a [LiveHttp] wrapper that makes the API GETs and
/// hands the parsers `(text, status)` pairs.
///
/// Every request carries [KilakilaEndpoints.headers] and goes as `kilakila`,
/// so the app routes the platform through its proxy setting. A transport
/// breakdown becomes a network failure with the transport's own words; a bad
/// status is an ordinary answer, whose meaning the parsers' status gate
/// decides.
final class KilakilaHttp {
  /// Wraps [http] as the KilaKila transport.
  const KilakilaHttp(this.http);

  /// The wrapped transport.
  final LiveHttp http;

  /// GETs [url] with the platform's headers.
  Future<KilakilaResponse> get(Uri url, {CancelToken? cancel}) async {
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.custom(
          method: 'GET',
          site: 'kilakila',
          url: url,
          headers: KilakilaEndpoints.headers,
          cancelToken: cancel,
        ),
      );
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw KilakilaFailure(KilakilaFailureKind.network, 'GET $url: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode);
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
