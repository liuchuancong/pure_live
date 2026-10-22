import 'dart:convert';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/bigo/api/bigo_endpoints.dart';
import 'package:live_sites/src/platforms/bigo/bigo_manifest.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the bigo parsers read it: the decoded body and the status.
typedef BigoResponse = ({String text, int status});

/// Bigo's transport: a [LiveHttp] wrapper that hands parsers `(text, status)`
/// pairs, sends every request with [BigoEndpoints.headers] and never follows a
/// redirect, and maps transport breakdowns onto [BigoFailureKind.network].
/// Bad statuses are ordinary answers — the parsers' status gate decides what
/// 401/403/404/429/5xx mean for the endpoint that got them.
final class BigoHttp {
  /// Wraps [http] as the bigo transport.
  const BigoHttp(this.http);

  /// The wrapped transport.
  final LiveHttp http;

  /// GETs [url]; [cancel] ends the wait and [timeout] bounds it.
  Future<BigoResponse> get(Uri url, {CancelToken? cancel, Duration? timeout}) =>
      _send('GET', url, cancel: cancel, timeout: timeout);

  /// POSTs an empty body (the studio answer is asked for with no request body
  /// at all) or [fields] as an HTML form.
  Future<BigoResponse> post(Uri url, {Map<String, String> fields = const {}, CancelToken? cancel, Duration? timeout}) =>
      _send(
        'POST',
        url,
        cancel: cancel,
        timeout: timeout,
        body: fields.isEmpty ? '' : _form(fields),
        contentType: fields.isEmpty ? null : 'application/x-www-form-urlencoded; charset=UTF-8',
      );

  Future<BigoResponse> _send(
    String method,
    Uri url, {
    CancelToken? cancel,
    Duration? timeout,
    String? body,
    String? contentType,
  }) async {
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.custom(
          method: method,
          site: bigoSiteId,
          url: url,
          headers: BigoEndpoints.headers,
          body: body,
          contentType: contentType,
          cancelToken: cancel,
          timeout: timeout,
        ),
      );
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw BigoFailure(BigoFailureKind.network, '$method $url: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode);
  }

  /// The `getWebSocketLink` body: [fields] as percent-encoded pairs (the page's
  /// own form encoding).
  static String _form(Map<String, String> fields) => fields.entries
      .map((entry) => '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}')
      .join('&');

  /// The UTF-8 text of a body, tolerant of a broken tail.
  static String decodeBody(List<int> bytes) => utf8.decode(bytes, allowMalformed: true);

  /// Releases the wrapped transport.
  void close() => http.close();
}
