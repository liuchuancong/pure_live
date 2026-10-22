import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_failure.dart';
import 'package:live_sites/src/platforms/steambroadcast/steambroadcast_manifest.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the Steam Broadcast parsers read it: the body text and the
/// status.
typedef SteambroadcastResponse = ({String text, int status});

/// Steam Broadcast's transport: a [LiveHttp] wrapper that makes the GETs of
/// Steam Community, the chat log and the HLS master, and hands the parsers
/// `(text, status)` pairs.
///
/// Every request carries the headers its caller gives and goes as
/// `steambroadcast`, so the app routes the platform through its proxy
/// setting. A transport breakdown becomes a network failure with the
/// transport's own words; a cancellation is rethrown as the transport's own
/// cancelled failure; a bad status is an ordinary answer, whose meaning the
/// parsers' status gate decides.
final class SteambroadcastHttp {
  /// Wraps [http] as the Steam Broadcast transport.
  const SteambroadcastHttp(this.http);

  /// The wrapped transport.
  final LiveHttp http;

  /// GETs [url] with [headers], bounded by [timeout] and cancellable through
  /// [cancel].
  Future<SteambroadcastResponse> get(
    Uri url, {
    required Map<String, String> headers,
    CancelToken? cancel,
    Duration? timeout,
  }) async {
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.custom(
          method: 'GET',
          site: steambroadcastSiteId,
          url: url,
          headers: headers,
          cancelToken: cancel,
          timeout: timeout,
        ),
      );
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw SteambroadcastFailure(SteambroadcastFailureKind.network, 'GET $url: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode);
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
