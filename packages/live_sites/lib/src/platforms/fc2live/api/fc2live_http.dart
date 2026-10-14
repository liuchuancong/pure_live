import 'dart:convert';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/fc2live/api/fc2live_endpoints.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the FC2 parsers read it: the body text and the status.
typedef Fc2LiveResponse = ({String text, int status});

/// FC2 Live's transport: a [LiveHttp] wrapper that makes the platform's three
/// form POSTs and hands the parsers `(text, status)` pairs.
///
/// Every request is a POST that does not follow redirects (as the page's XHR
/// does not: 3.x mapped a 3xx to a service breakdown, and a redirect here
/// would land on a login page whose HTML is not an answer), carries
/// [Fc2LiveEndpoints.headers] and the form content type the page sends, and is
/// bounded by [Fc2LiveEndpoints.requestTimeout]. A transport breakdown becomes
/// a network failure with the transport's own words; a bad status is an ordinary
/// answer, whose meaning the parsers' status gate decides per endpoint.
final class Fc2LiveHttp {
  /// Wraps [http] as the FC2 transport.
  const Fc2LiveHttp(this.http);

  /// The wrapped transport (the comment connection drives it for its grants).
  final LiveHttp http;

  /// POSTs [fields] to [path] on the API host.
  Future<Fc2LiveResponse> post(
    String path,
    Map<String, String> fields, {
    CancelToken? cancel,
    Duration? timeout,
  }) async {
    final url = Uri.https(Fc2LiveEndpoints.host, path);
    final form = LiveRequest.form(
      url,
      fields: fields,
      site: 'fc2live',
      headers: const {...Fc2LiveEndpoints.headers, 'content-type': Fc2LiveEndpoints.formContentType},
      cancelToken: cancel,
      timeout: timeout ?? Fc2LiveEndpoints.requestTimeout,
    );
    final LiveResponse response;
    try {
      response = await http.send(form);
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw Fc2LiveFailure(Fc2LiveFailureKind.network, 'POST $url: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode);
  }

  /// The JSON-decoded body of an answer, null when it is not JSON: the comment
  /// connection reads a grant's answer this way when it only needs one field.
  static Object? json(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
