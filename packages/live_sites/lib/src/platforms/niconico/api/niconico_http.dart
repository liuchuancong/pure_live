import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the niconico parsers read it: the body text, the bytes and
/// the HTTP status. Redirect following is the wrapped transport's policy;
/// a niconico room's watch page and lists answer 200 for a valid program.
typedef NiconicoResponse = ({String text, Uint8List bytes, int status});

/// Niconico's transport: a [LiveHttp] wrapper that hands parsers text/bytes
/// with the status and maps transport breakdowns onto
/// [NiconicoFailureKind.network]. Bad statuses are ordinary answers — the
/// parsers decide what 401/403/404/429/5xx mean for their endpoint.
final class NiconicoHttp {
  /// Wraps [http] as the niconico transport.
  const NiconicoHttp(this.http);

  /// The wrapped transport (the danmaku session drives it directly).
  final LiveHttp http;

  /// GETs [url] with [headers].
  Future<NiconicoResponse> get(Uri url, {Map<String, String> headers = const {}}) async {
    try {
      final response = await http.send(LiveRequest.custom(method: 'GET', site: 'niconico', url: url, headers: headers));
      return (text: response.text, bytes: response.bodyBytes, status: response.statusCode);
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw NiconicoFailure(NiconicoFailureKind.network, 'GET $url: $failure', cause: failure);
    }
  }

  /// GETs the comment server [url] and hands back the raw protobuf bytes.
  /// Unlike [get] this never throws on a bad status — the poll loop folds
  /// the status into its own failure cap and decides whether a 4xx means a
  /// fresh seat — but a transport breakdown (and a cancellation) rethrows so
  /// the loop stops.
  Future<NiconicoResponse> feed(Uri url, {Map<String, String> headers = const {}, CancelToken? cancel}) async {
    final response = await http.send(
      LiveRequest.custom(method: 'GET', site: 'niconico', url: url, headers: headers, cancelToken: cancel),
    );
    return (text: response.text, bytes: response.bodyBytes, status: response.statusCode);
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
