import 'dart:convert';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/acfun/acfun_manifest.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the acfun parsers read it: the body text and the status.
typedef AcfunResponse = ({String text, int status});

/// AcFun's transport: a [LiveHttp] wrapper that hands parsers `(text, status)`
/// pairs and maps transport breakdowns onto [AcfunFailureKind.network]. Bad
/// statuses are ordinary answers — the parsers decide what 401/403/429/5xx
/// mean for their endpoint.
final class AcfunHttp {
  /// Wraps [http] as the acfun transport.
  const AcfunHttp(this.http);

  /// The wrapped transport.
  final LiveHttp http;

  /// GETs [url] with [headers]; [cancel] ends the wait and [timeout] bounds it.
  Future<AcfunResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    CancelToken? cancel,
    Duration? timeout,
  }) => _send('GET', url, headers: headers, cancel: cancel, timeout: timeout);

  /// POSTs [fields] as an HTML form (AcFun's own content type: the visitor
  /// login, `startPlay` and the gift table all take form fields, and the
  /// signature of the call is the form body plus the session query).
  Future<AcfunResponse> postForm(
    Uri url, {
    required Map<String, String> fields,
    Map<String, String> headers = const {},
  }) => _send(
    'POST',
    url,
    headers: headers,
    body: fields.entries
        .map((entry) => '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}')
        .join('&'),
    contentType: 'application/x-www-form-urlencoded',
  );

  Future<AcfunResponse> _send(
    String method,
    Uri url, {
    required Map<String, String> headers,
    String? body,
    String? contentType,
    CancelToken? cancel,
    Duration? timeout,
  }) async {
    try {
      final response = await http.send(
        LiveRequest.custom(
          method: method,
          site: acfunSiteId,
          url: url,
          headers: headers,
          body: body,
          contentType: contentType,
          cancelToken: cancel,
          timeout: timeout,
        ),
      );
      return (text: response.text, status: response.statusCode);
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw AcfunFailure(AcfunFailureKind.network, '$method $url: $failure', cause: failure);
    }
  }

  /// The UTF-8 text of a response body (the search endpoint answers with the
  /// BigPipe JSON of a page, which is plain JSON text).
  static String decodeBody(List<int> bytes) => utf8.decode(bytes, allowMalformed: true);

  /// Releases the wrapped transport.
  void close() => http.close();
}
