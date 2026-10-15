import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/twitcasting/api/twitcasting_endpoints.dart';
import 'package:live_sites/src/platforms/twitcasting/parsers/twitcasting_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the TwitCasting parsers read it: the body text and the
/// status.
typedef TwitcastingResponse = ({String text, int status});

/// TwitCasting's transport: a [LiveHttp] wrapper that makes the anonymous
/// GETs of the pages and `streamserver.php`, and the comment socket's
/// `eventpubsuburl.php` form POST.
///
/// Every request carries [TwitcastingEndpoints.headers] and goes as
/// `twitcasting`, so the app routes the platform through its proxy setting. A
/// transport breakdown becomes a network failure with the transport's own
/// words; a bad status is an ordinary answer, whose meaning the parsers'
/// status gate decides. A cancelled request stays cancelled.
final class TwitcastingHttp {
  /// Wraps [http] as the TwitCasting transport.
  const TwitcastingHttp(this.http);

  /// The wrapped transport (the comment connection drives it for the socket
  /// URLs).
  final LiveHttp http;

  /// GETs [url] with the platform's headers.
  Future<TwitcastingResponse> get(Uri url, {CancelToken? cancel, Duration? timeout}) async {
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.custom(
          method: 'GET',
          site: 'twitcasting',
          url: url,
          headers: TwitcastingEndpoints.headers,
          cancelToken: cancel,
          timeout: timeout,
        ),
      );
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw TwitcastingFailure(TwitcastingFailureKind.network, 'GET $url: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode);
  }

  /// POSTs [fields] as a form to [url] (the comment socket's `movie_id`).
  Future<TwitcastingResponse> post(
    Uri url,
    Map<String, String> fields, {
    CancelToken? cancel,
    Duration? timeout,
  }) async {
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.form(
          url,
          fields: fields,
          headers: TwitcastingEndpoints.headers,
          site: 'twitcasting',
          timeout: timeout,
          cancelToken: cancel,
        ),
      );
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw TwitcastingFailure(TwitcastingFailureKind.network, 'POST $url: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode);
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
