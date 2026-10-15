import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/jdlive/api/jdlive_endpoints.dart';
import 'package:live_sites/src/platforms/jdlive/parsers/jdlive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the JD Live parsers read it: the body text and the status.
typedef JdliveResponse = ({String text, int status});

/// JD Live's transport: a [LiveHttp] wrapper that makes the two anonymous API
/// GETs and the chat's `liveauth` form POST, and hands the parsers
/// `(text, status)` pairs.
///
/// Every request carries [JdliveEndpoints.apiHeaders] and goes as `jdlive`, so
/// the app routes the platform through its proxy setting. A transport
/// breakdown becomes a network failure with the transport's own words; a bad
/// status is an ordinary answer, whose meaning the parsers' status gate
/// decides per endpoint.
final class JdliveHttp {
  /// Wraps [http] as the JD Live transport.
  const JdliveHttp(this.http);

  /// The wrapped transport (the comment connection drives it for `liveauth`).
  final LiveHttp http;

  /// GETs [url] with the API headers, or [headers] when given (the playlist
  /// check goes with the media headers).
  Future<JdliveResponse> get(Uri url, {Map<String, String>? headers, CancelToken? cancel, Duration? timeout}) async {
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.custom(
          method: 'GET',
          site: 'jdlive',
          url: url,
          headers: headers ?? JdliveEndpoints.apiHeaders,
          cancelToken: cancel,
          timeout: timeout,
        ),
      );
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw JdliveFailure(JdliveFailureKind.network, 'GET $url: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode);
  }

  /// POSTs [fields] as the page's form to [url] (the chat's `liveauth`).
  Future<JdliveResponse> post(Uri url, Map<String, String> fields, {CancelToken? cancel, Duration? timeout}) async {
    final form = fields.entries
        .map((entry) => '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}')
        .join('&');
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.custom(
          method: 'POST',
          site: 'jdlive',
          url: url,
          headers: const {...JdliveEndpoints.apiHeaders, 'content-type': 'application/x-www-form-urlencoded'},
          body: form,
          cancelToken: cancel,
          timeout: timeout,
        ),
      );
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw JdliveFailure(JdliveFailureKind.network, 'POST $url: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode);
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
