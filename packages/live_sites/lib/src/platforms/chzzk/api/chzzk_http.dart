import 'dart:convert';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/chzzk/api/chzzk_endpoints.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the chzzk parsers read it: the decoded body and the status.
typedef ChzzkResponse = ({String text, int status});

/// Chzzk's transport: a [LiveHttp] wrapper that hands parsers `(text, status)`
/// pairs and maps transport breakdowns onto [ChzzkFailureKind.network]. Bad
/// statuses are ordinary answers — the parsers' status gate decides what
/// 400/401/403/404/429/5xx mean for the endpoint that got them, and every other
/// status (a redirect included, which this platform never follows by contract)
/// is a network failure.
///
/// Requests carry [ChzzkEndpoints.headers] — the API answers and the master
/// playlists alike are asked with them, which is how the recordings were
/// captured.
final class ChzzkHttp {
  /// Wraps [http] as the chzzk transport.
  const ChzzkHttp(this.http);

  /// The wrapped transport (the chat connection drives it for the token, the
  /// routing and the live state).
  final LiveHttp http;

  /// GETs [url] with [headers]; [cancel] ends the wait and [timeout] bounds it.
  Future<ChzzkResponse> get(Uri url, {Map<String, String>? headers, CancelToken? cancel, Duration? timeout}) async {
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.custom(
          method: 'GET',
          site: 'chzzk',
          url: url,
          headers: headers ?? ChzzkEndpoints.headers,
          cancelToken: cancel,
          timeout: timeout,
        ),
      );
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw ChzzkFailure(ChzzkFailureKind.network, 'GET $url: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode);
  }

  /// The JSON-decoded body of an answer, null when it is not JSON (the chat's
  /// token, routing and live-status answers all read it this way and treat a
  /// malformed body as "no answer", never as a crash).
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
