import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/tiktok/parsers/tiktok_failure.dart';
import 'package:live_sites/src/platforms/tiktok/tiktok_manifest.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the TikTok parsers read it: the body text and the status.
typedef TiktokResponse = ({String text, int status});

/// TikTok's transport: a [LiveHttp] wrapper that makes the API GETs and
/// hands the parsers `(text, status)` pairs.
///
/// Every request goes as `tiktok`, so the app routes the platform through
/// its proxy setting, and carries the headers the site gives it (the Referer
/// names the room asked). A transport breakdown becomes a network failure
/// with the transport's own words; a bad status is an ordinary answer, whose
/// meaning the parsers' status gate decides.
final class TiktokHttp {
  /// Wraps [http] as the TikTok transport.
  const TiktokHttp(this.http);

  /// The wrapped transport.
  final LiveHttp http;

  /// GETs [url] with [headers].
  Future<TiktokResponse> get(Uri url, {Map<String, String> headers = const {}}) async {
    final LiveResponse response;
    try {
      response = await http.send(LiveRequest.custom(method: 'GET', site: tiktokSiteId, url: url, headers: headers));
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw TiktokFailure(TiktokFailureKind.network, 'GET $url: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode);
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
