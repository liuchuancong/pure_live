import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/kugoulive/api/kugoulive_endpoints.dart';
import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the Kugou Live parsers read it: the body text and the
/// status.
typedef KugouliveResponse = ({String text, int status});

/// Kugou Live's transport: a [LiveHttp] wrapper that makes the API GETs and
/// hands the parsers `(text, status)` pairs.
///
/// Every request carries [KugouliveEndpoints.apiHeaders] and goes as
/// `kugoulive`, so the app routes the platform through its proxy setting. A
/// transport breakdown becomes a network failure with the transport's own
/// words; a bad status is an ordinary answer, whose meaning the parsers'
/// status gate decides.
final class KugouliveHttp {
  /// Wraps [http] as the Kugou Live transport.
  const KugouliveHttp(this.http);

  /// The wrapped transport (the chat connection drives it for its scheduler).
  final LiveHttp http;

  /// GETs [url] with the platform's headers, or [headers] when given.
  Future<KugouliveResponse> get(Uri url, {Map<String, String>? headers, CancelToken? cancel}) async {
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.custom(
          method: 'GET',
          site: 'kugoulive',
          url: url,
          headers: headers ?? KugouliveEndpoints.apiHeaders,
          cancelToken: cancel,
        ),
      );
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw KugouliveFailure(KugouliveFailureKind.network, 'GET $url: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode);
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
