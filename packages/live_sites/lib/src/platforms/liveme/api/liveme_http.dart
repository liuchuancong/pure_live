import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/liveme/api/liveme_endpoints.dart';
import 'package:live_sites/src/platforms/liveme/liveme_manifest.dart';
import 'package:live_sites/src/platforms/liveme/parsers/liveme_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the LiveMe parsers read it: the body text and the status.
typedef LivemeResponse = ({String text, int status});

/// LiveMe's transport: a [LiveHttp] wrapper that makes the API GETs and the
/// signed `queryinfosimple` POST, and hands the parsers `(text, status)`
/// pairs.
///
/// Every request carries [LivemeEndpoints.headers] and goes as `liveme`, so
/// the app routes the platform through its proxy setting. A transport
/// breakdown becomes a network failure with the transport's own words; a bad
/// status is an ordinary answer, whose meaning the parsers' status gate
/// decides. (3.x sent its requests with redirects refused; the v2 transport
/// has no such switch, so a redirect lands on an HTML page that the envelope
/// gate reads as api-changed.)
final class LivemeHttp {
  /// Wraps [http] as the LiveMe transport.
  const LivemeHttp(this.http);

  /// The wrapped transport.
  final LiveHttp http;

  /// GETs [url] with the platform's headers; the referer names [shortId]'s
  /// room page when given, else the hot list.
  Future<LivemeResponse> get(Uri url, {String? shortId, CancelToken? cancel}) => send(
    LiveRequest.custom(
      method: 'GET',
      site: livemeSiteId,
      url: url,
      headers: LivemeEndpoints.headers(shortId: shortId),
      cancelToken: cancel,
    ),
  );

  /// Sends a request built by the caller (the signed broadcast POST).
  Future<LivemeResponse> send(LiveRequest request) async {
    final LiveResponse response;
    try {
      response = await http.send(request);
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw LivemeFailure(LivemeFailureKind.network, '${request.method} ${request.url}: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode);
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
