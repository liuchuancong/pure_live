import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/baidulive/baidulive_manifest.dart';
import 'package:live_sites/src/platforms/baidulive/parsers/baidulive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the Baidu Live parsers and the chat read it: the status, the
/// body text and its raw bytes (a message-list segment is gzipped without the
/// transport knowing).
typedef BaiduliveResponse = ({int status, String text, Uint8List bytes});

/// Baidu Live's transport: a [LiveHttp] wrapper that makes the signed feed
/// form POST, the room command's GET and the message-list GETs, and hands the
/// parsers `(status, text, bytes)`.
///
/// Every request goes as `baidulive`, so the app routes the platform through
/// its proxy setting. A transport breakdown becomes a network failure with
/// the transport's own words; a bad status is an ordinary answer, whose
/// meaning the parsers' status gate (and the chat's own gate) decides.
final class BaiduliveHttp {
  /// Wraps [http] as the Baidu Live transport.
  const BaiduliveHttp(this.http);

  /// The wrapped transport.
  final LiveHttp http;

  /// GETs [url] with [headers]; [cancel] ends the wait and [timeout] bounds it.
  Future<BaiduliveResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    CancelToken? cancel,
    Duration? timeout,
  }) => _send('GET', url, headers: headers, cancel: cancel, timeout: timeout);

  /// POSTs the pre-encoded form [body] of the feed to [url] with [headers]
  /// (the feed signs its own fields, so the body is handed over as built).
  Future<BaiduliveResponse> post(
    Uri url, {
    required String body,
    required Map<String, String> headers,
    CancelToken? cancel,
    Duration? timeout,
  }) => _send('POST', url, headers: headers, body: body, cancel: cancel, timeout: timeout);

  Future<BaiduliveResponse> _send(
    String method,
    Uri url, {
    required Map<String, String> headers,
    String? body,
    CancelToken? cancel,
    Duration? timeout,
  }) async {
    try {
      final response = await http.send(
        LiveRequest.custom(
          method: method,
          site: baiduliveSiteId,
          url: url,
          headers: headers,
          body: body,
          cancelToken: cancel,
          timeout: timeout,
        ),
      );
      return (status: response.statusCode, text: response.text, bytes: response.bodyBytes);
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw BaiduliveFailure(BaiduliveFailureKind.network, '$method $url: $failure', cause: failure);
    }
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
