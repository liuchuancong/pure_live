import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Douyu's transport: a [LiveHttp] wrapper that hands parsers
/// `(text, status)` pairs and maps transport breakdowns onto
/// [DouyuFailureKind.network].
final class DouyuHttp {
  /// Wraps [http] as the douyu transport.
  const DouyuHttp(this.http);

  /// The wrapped transport.
  final LiveHttp http;

  /// GETs [url] with [headers]; bad statuses are ordinary answers — the
  /// parsers decide what 403/412/5xx mean for their endpoint.
  Future<({String text, int status})> get(Uri url, {Map<String, String> headers = const {}}) async {
    try {
      final response = await http.send(LiveRequest.custom(method: 'GET', site: 'douyu', url: url, headers: headers));
      return (text: response.text, status: response.statusCode);
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw DouyuFailure(DouyuFailureKind.network, 'GET $url: $failure', cause: failure);
    }
  }

  /// POSTs [fields] as a form body (what `getH5PlayV1` expects).
  Future<({String text, int status})> postForm(
    Uri url, {
    required Map<String, String> fields,
    Map<String, String> headers = const {},
  }) async {
    final body = Uri(queryParameters: fields).query;
    try {
      final response = await http.send(
        LiveRequest.custom(
          method: 'POST',
          site: 'douyu',
          url: url,
          body: body,
          contentType: 'application/x-www-form-urlencoded',
          headers: headers,
        ),
      );
      return (text: response.text, status: response.statusCode);
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw DouyuFailure(DouyuFailureKind.network, 'POST $url: $failure', cause: failure);
    }
  }

  /// GETs [url] without following redirects, returning the `Location` of a
  /// 3xx answer (an alias page to its rid page).
  Future<({String? location, String text, int status})> getRedirect(Uri url) async {
    try {
      final response = await http.send(LiveRequest.custom(method: 'GET', site: 'douyu', url: url));
      return (location: response.headers['location'], text: response.text, status: response.statusCode);
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw DouyuFailure(DouyuFailureKind.network, 'GET $url: $failure', cause: failure);
    }
  }

  /// The raw answer of the passport renewal, whose `Set-Cookie` lines are
  /// the whole point: every repeated header, kept per-line (the joined
  /// `set-cookie` header cannot be split back apart because an `Expires`
  /// date holds a comma).
  Future<List<String>> passportSetCookies(Uri url, Map<String, String> headers) async {
    try {
      final response = await http.send(LiveRequest.custom(method: 'GET', site: 'douyu', url: url, headers: headers));
      return response.setCookies;
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw DouyuFailure(DouyuFailureKind.network, 'renewal $url: $failure', cause: failure);
    }
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
