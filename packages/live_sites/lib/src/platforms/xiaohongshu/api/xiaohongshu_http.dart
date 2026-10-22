import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/xiaohongshu/api/xiaohongshu_endpoints.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_failure.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_manifest.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the Xiaohongshu parsers read it: the body text, the status
/// and the lower-cased headers (the `Location` a short link's answer may
/// still name).
typedef XiaohongshuResponse = ({String text, int status, Map<String, String> headers});

/// Xiaohongshu's transport: a [LiveHttp] wrapper that fetches the share
/// pages and the short links, and hands the parsers `(text, status)` pairs.
///
/// Every request carries [XiaohongshuEndpoints.headers] and goes as
/// `xiaohongshu`, so the app routes the platform through its proxy setting.
/// A transport breakdown becomes a network failure with the transport's own
/// words; a bad status is an ordinary answer, whose meaning the parsers'
/// status gate decides.
final class XiaohongshuHttp {
  /// Wraps [http] as the Xiaohongshu transport.
  const XiaohongshuHttp(this.http);

  /// The wrapped transport.
  final LiveHttp http;

  /// GETs [url] with the platform's headers, within [timeout] when given
  /// (a short link's session). Redirects follow (3.x read the page of the
  /// address asked for; the page's own room id is checked when parsing).
  Future<XiaohongshuResponse> get(Uri url, {CancelToken? cancel, Duration? timeout}) async {
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.custom(
          method: 'GET',
          site: xiaohongshuSiteId,
          url: url,
          headers: XiaohongshuEndpoints.headers,
          cancelToken: cancel,
          timeout: timeout,
        ),
      );
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw XiaohongshuFailure(XiaohongshuFailureKind.network, 'GET $url: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode, headers: response.headers);
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
