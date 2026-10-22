import 'dart:convert';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/kuaishou/kuaishou_manifest.dart';
import 'package:live_sites/src/platforms/kuaishou/parsers/kuaishou_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the kuaishou parsers read it: the decoded body, the status
/// and the lower-cased response headers (whose `set-cookie` starts a session).
typedef KuaishouResponse = ({String text, int status, Map<String, String> headers});

/// Kuaishou's transport: a [LiveHttp] wrapper that hands parsers
/// `(text, status, headers)` triples and maps transport breakdowns onto
/// [KuaishouFailureKind.network]. Bad statuses are ordinary answers — the
/// parsers decide what 401/403/429/5xx mean for their endpoint.
final class KuaishouHttp {
  /// Wraps [http] as the kuaishou transport.
  const KuaishouHttp(this.http);

  /// The wrapped transport (the danmaku session drives it directly).
  final LiveHttp http;

  /// GETs [url] with [headers], keeping the response headers for the session
  /// bootstrap.
  Future<KuaishouResponse> get(Uri url, {Map<String, String> headers = const {}}) async {
    try {
      final response = await http.send(
        LiveRequest.custom(method: 'GET', site: kuaishouSiteId, url: url, headers: headers),
      );
      return (text: response.text, status: response.statusCode, headers: response.headers);
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw KuaishouFailure(KuaishouFailureKind.network, 'GET $url: $failure', cause: failure);
    }
  }

  /// POSTs [json] as a JSON body (the best-effort device report); the answer
  /// is discarded, so failures only ever reach the caller as a network
  /// [KuaishouFailure].
  Future<void> postJson(Uri url, {required Object? json, Map<String, String> headers = const {}}) async {
    try {
      await http.send(
        LiveRequest.custom(
          method: 'POST',
          site: kuaishouSiteId,
          url: url,
          body: jsonEncode(json),
          contentType: 'application/json',
          headers: headers,
        ),
      );
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw KuaishouFailure(KuaishouFailureKind.network, 'POST $url: $failure', cause: failure);
    }
  }

  /// GETs the comment feed [url] and JSON-decodes it once (the codec peels any
  /// further encodings); a non-2xx answer and a body that is not JSON throw,
  /// so the session falls back to the second endpoint. A cancelled request
  /// rethrows so the poll loop stops.
  Future<Object?> feedJson(Uri url, {Map<String, String> headers = const {}, CancelToken? cancel}) async {
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.custom(method: 'GET', site: kuaishouSiteId, url: url, headers: headers, cancelToken: cancel),
      );
    } on TransportFailure {
      // A transport breakdown (and a cancellation) is the session's to fold
      // into its failure cap; the loop checks the token and stops.
      rethrow;
    }
    if (!response.isOk) {
      throw KuaishouFailure(KuaishouFailureKind.network, 'feed: HTTP ${response.statusCode}');
    }
    return jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
