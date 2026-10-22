import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/missevan/api/missevan_endpoints.dart';
import 'package:live_sites/src/platforms/missevan/missevan_manifest.dart';
import 'package:live_sites/src/platforms/missevan/parsers/missevan_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the Missevan parsers read it: the body text, the status and
/// the raw `Set-Cookie` lines (the guest session of the chat is read from
/// them; the API answers ignore them).
typedef MissevanResponse = ({String text, int status, List<String> setCookies});

/// Missevan's transport: a [LiveHttp] wrapper that makes the anonymous API
/// GETs and the chat's guest-session GET, and hands the parsers
/// `(text, status, setCookies)` triples.
///
/// Every request carries [MissevanEndpoints.headers] and goes as
/// `missevan`, so the app routes the platform through its proxy setting. A
/// transport breakdown becomes a network failure with the transport's own
/// words; a bad status is an ordinary answer, whose meaning the parsers'
/// envelope gate decides.
final class MissevanHttp {
  /// Wraps [http] as the Missevan transport.
  const MissevanHttp(this.http);

  /// The wrapped transport.
  final LiveHttp http;

  /// GETs [url] with the platform's headers.
  Future<MissevanResponse> get(Uri url, {CancelToken? cancel, Duration? timeout}) async {
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.custom(
          method: 'GET',
          site: missevanSiteId,
          url: url,
          headers: MissevanEndpoints.headers,
          cancelToken: cancel,
          timeout: timeout,
        ),
      );
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw MissevanFailure(MissevanFailureKind.network, 'GET $url: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode, setCookies: response.setCookies);
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
