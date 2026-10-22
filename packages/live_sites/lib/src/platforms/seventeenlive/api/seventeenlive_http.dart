import 'dart:convert';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/seventeenlive/parsers/seventeenlive_failure.dart';
import 'package:live_sites/src/platforms/seventeenlive/seventeenlive_manifest.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the 17LIVE parsers read it: the body text and the status.
typedef SeventeenLiveResponse = ({String text, int status});

/// 17LIVE's transport: a [LiveHttp] wrapper that hands parsers `(text, status)`
/// pairs and maps transport breakdowns onto [SeventeenLiveFailureKind.network].
/// Bad statuses are ordinary answers — the status gate in
/// `parsers/seventeenlive_json.dart` decides what 400/401/403/404/420/429/5xx
/// mean for the endpoint that got them, and every other status (a redirect
/// included, which this platform never follows) is a network failure.
///
/// Requests are tagged `site: seventeenliveSiteId` and carry the caller's
/// headers: the catalog ones for the sections and the search, the room's own for
/// `lives/<id>` (its `Referer` is the room page), and `authHeaders` with a JSON
/// body for the chat token.
final class SeventeenLiveHttp {
  /// Wraps [http] as the 17LIVE transport.
  const SeventeenLiveHttp(this.http);

  /// The wrapped transport (the chat connection drives it for its token).
  final LiveHttp http;

  /// GETs [url] with [headers]; [cancel] ends the wait and [timeout] bounds it.
  Future<SeventeenLiveResponse> get(
    Uri url, {
    required Map<String, String> headers,
    CancelToken? cancel,
    Duration? timeout,
  }) => send(LiveRequest.custom(method: 'GET', site: seventeenliveSiteId, url: url, headers: headers, cancelToken: cancel, timeout: timeout));

  /// POSTs [body] as JSON to [url] with [headers] — the chat's token request,
  /// which the website sends as `POST {}` and which answers for the room the
  /// socket then joins.
  Future<SeventeenLiveResponse> post(
    Uri url, {
    required Map<String, String> headers,
    Object? body,
    CancelToken? cancel,
    Duration? timeout,
  }) => send(
    LiveRequest.custom(
      method: 'POST',
      site: seventeenliveSiteId,
      url: url,
      body: jsonEncode(body ?? const <String, Object?>{}),
      contentType: 'application/json',
      headers: headers,
      cancelToken: cancel,
      timeout: timeout,
    ),
  );

  /// One request, with its transport breakdown turned into a network failure. A
  /// cancelled request is rethrown as it came: the caller asked for it.
  Future<SeventeenLiveResponse> send(LiveRequest request) async {
    final LiveResponse response;
    try {
      response = await http.send(request);
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw SeventeenLiveFailure(SeventeenLiveFailureKind.network, '${request.method} ${request.url}: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode);
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
