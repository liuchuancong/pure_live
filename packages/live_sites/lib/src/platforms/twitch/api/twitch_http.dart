import 'dart:convert';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/twitch/parsers/twitch_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the twitch parsers read it: the body text, the status and the
/// lower-cased response headers.
typedef TwitchResponse = ({String text, int status, Map<String, String> headers});

/// Twitch's transport: a [LiveHttp] wrapper that hands parsers
/// `(text, status)` pairs and maps transport breakdowns onto
/// [TwitchFailureKind.network]. Bad statuses are ordinary answers — the
/// parsers decide what 401/403/404/429/5xx mean for their endpoint.
final class TwitchHttp {
  /// Wraps [http] as the twitch transport.
  const TwitchHttp(this.http);

  /// The wrapped transport (the site drives it for usher and GraphQL alike).
  final LiveHttp http;

  /// GETs [url] with [headers].
  Future<TwitchResponse> get(Uri url, {Map<String, String> headers = const {}}) async {
    try {
      final response = await http.send(LiveRequest.custom(method: 'GET', site: 'twitch', url: url, headers: headers));
      return (text: response.text, status: response.statusCode, headers: response.headers);
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw TwitchFailure(TwitchFailureKind.network, 'GET $url: $failure', cause: failure);
    }
  }

  /// POSTs one GraphQL [operation] (an operation, or a list of them as a
  /// batch). The web client sends the JSON as `text/plain`, which Twitch
  /// accepts; `application/json` does not change the answer.
  Future<TwitchResponse> gql(Object operation, {Map<String, String> headers = const {}, Uri? url}) async {
    try {
      final response = await http.send(
        LiveRequest.custom(
          method: 'POST',
          site: 'twitch',
          url: url ?? Uri.https('gql.twitch.tv', '/gql'),
          body: jsonEncode(operation),
          contentType: 'text/plain;charset=UTF-8',
          headers: headers,
        ),
      );
      return (text: response.text, status: response.statusCode, headers: response.headers);
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw TwitchFailure(TwitchFailureKind.network, 'POST gql: $failure', cause: failure);
    }
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
