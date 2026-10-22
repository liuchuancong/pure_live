import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/weibo/api/weibo_endpoints.dart';
import 'package:live_sites/src/platforms/weibo/parsers/weibo_failure.dart';
import 'package:live_sites/src/platforms/weibo/weibo_manifest.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the Weibo parsers read it: the body text, the status and the
/// (lower-cased) headers — the last only the `t.cn` short link gate needs.
typedef WeiboResponse = ({String text, int status, Map<String, String> headers});

/// Weibo's transport: a [LiveHttp] wrapper that makes the anonymous API GETs
/// and hands the parsers `(text, status, headers)` triples.
///
/// Every request carries [WeiboEndpoints.headers] and goes as `weibo`, so the
/// app routes the platform through its proxy setting. The transport follows
/// redirects (the reference asked for one hop and read the `Location` off a
/// 3xx itself); the short-link gate reads the same header where an answer
/// still carries one. A transport breakdown becomes a network failure with
/// the transport's own words; a bad status is an ordinary answer, whose
/// meaning the parsers' status gate decides.
final class WeiboHttp {
  /// Wraps [http] as the Weibo transport.
  const WeiboHttp(this.http);

  /// The wrapped transport.
  final LiveHttp http;

  /// GETs [url] with the platform's headers.
  Future<WeiboResponse> get(Uri url, {CancelToken? cancel}) async {
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.custom(
          method: 'GET',
          site: weiboSiteId,
          url: url,
          headers: WeiboEndpoints.headers,
          cancelToken: cancel,
        ),
      );
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw WeiboFailure(WeiboFailureKind.network, 'GET $url: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode, headers: response.headers);
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
