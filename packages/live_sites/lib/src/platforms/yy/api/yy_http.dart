import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/yy/parsers/yy_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the YY parsers read it: the body text and the status.
typedef YyResponse = ({String text, int status});

/// YY's transport: a [LiveHttp] wrapper that makes the GETs and the
/// stream-manager POST, and hands the parsers `(text, status)` pairs.
///
/// Every request goes as `yy`, so the app routes the platform through its
/// proxy setting; the headers are the caller's (the endpoints build 3.x's
/// browser headers). A transport breakdown becomes a network failure with
/// the transport's own words; a bad status is an ordinary answer, whose
/// meaning the parsers' status gates decide.
final class YyHttp {
  /// Wraps [http] as the YY transport.
  const YyHttp(this.http);

  /// The wrapped transport.
  final LiveHttp http;

  /// GETs [url] with [headers].
  Future<YyResponse> get(Uri url, {Map<String, String> headers = const {}}) async {
    try {
      final response = await http.send(LiveRequest.custom(method: 'GET', site: 'yy', url: url, headers: headers));
      return (text: response.text, status: response.statusCode);
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw YyFailure(YyFailureKind.network, 'GET $url: $failure', cause: failure);
    }
  }

  /// POSTs [body] as UTF-8 text with [headers] (the stream-manager's JSON,
  /// declared `text/plain` as the web SDK sends it).
  Future<YyResponse> postText(Uri url, {required String body, Map<String, String> headers = const {}}) async {
    try {
      final response = await http.send(
        LiveRequest.custom(method: 'POST', site: 'yy', url: url, body: body, headers: headers),
      );
      return (text: response.text, status: response.statusCode);
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw YyFailure(YyFailureKind.network, 'POST $url: $failure', cause: failure);
    }
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
