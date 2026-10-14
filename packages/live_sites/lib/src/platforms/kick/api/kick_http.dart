import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the kick parsers read it: the body text and the status.
typedef KickResponse = ({String text, int status});

/// Kick's transport: a [LiveHttp] wrapper that hands parsers `(text, status)`
/// pairs and maps transport breakdowns onto [KickFailureKind.network].
/// Bad statuses are ordinary answers — the parsers decide what 403/404/429/
/// 5xx mean for their endpoint.
final class KickHttp {
  /// Wraps [http] as the kick transport.
  const KickHttp(this.http);

  /// The wrapped transport.
  final LiveHttp http;

  /// GETs [url] with [headers].
  Future<KickResponse> get(Uri url, {Map<String, String> headers = const {}}) async {
    try {
      final response = await http.send(LiveRequest.custom(method: 'GET', site: 'kick', url: url, headers: headers));
      return (text: response.text, status: response.statusCode);
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw KickFailure(KickFailureKind.network, 'GET $url: $failure', cause: failure);
    }
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
