import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/looklive/api/looklive_endpoints.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the LOOK Live parsers read it: the body text and the status.
typedef LookliveResponse = ({String text, int status});

/// LOOK Live's transport: a [LiveHttp] wrapper that makes the `weapi` form
/// POSTs of the API and the socket.io handshake GET of the chat, and hands
/// the parsers `(text, status)` pairs.
///
/// Every request goes as `looklive`, so the app routes the platform through
/// its proxy setting, and carries [LookliveEndpoints.requestHeaders] (or the
/// headers given). A transport breakdown becomes a network failure with the
/// transport's own words; a bad status is an ordinary answer, whose meaning
/// the parsers' status gate decides.
final class LookliveHttp {
  /// Wraps [http] as the LOOK Live transport.
  const LookliveHttp(this.http);

  /// The wrapped transport.
  final LiveHttp http;

  /// POSTs the `weapi` envelope of [payload] to [path].
  Future<LookliveResponse> post(String path, Object? payload, {CancelToken? cancel, Duration? timeout}) async {
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.custom(
          method: 'POST',
          site: 'looklive',
          url: Uri.parse('${LookliveEndpoints.apiOrigin}$path'),
          body: LookliveEndpoints.formBody(payload),
          headers: LookliveEndpoints.requestHeaders,
          cancelToken: cancel,
          timeout: timeout,
        ),
      );
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw LookliveFailure(LookliveFailureKind.network, 'POST $path: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode);
  }

  /// GETs [url] with [headers] (the socket.io handshake of the chat).
  Future<LookliveResponse> get(Uri url, {Map<String, String>? headers, CancelToken? cancel, Duration? timeout}) async {
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.custom(
          method: 'GET',
          site: 'looklive',
          url: url,
          headers: headers ?? const {},
          cancelToken: cancel,
          timeout: timeout,
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
