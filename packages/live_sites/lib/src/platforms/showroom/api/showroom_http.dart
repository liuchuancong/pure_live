import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/showroom/api/showroom_endpoints.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_failure.dart';
import 'package:live_sites/src/platforms/showroom/showroom_manifest.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the SHOWROOM parsers read it: the body text and the status.
typedef ShowroomResponse = ({String text, int status});

/// SHOWROOM's transport: a [LiveHttp] wrapper that makes the API GETs and
/// hands the parsers `(text, status)` pairs.
///
/// Every request carries [ShowroomEndpoints.headers] and goes as `showroom`,
/// so the app routes the platform through its proxy setting. A transport
/// breakdown becomes a network failure with the transport's own words; a bad
/// status is an ordinary answer, whose meaning the parsers' status gate
/// decides.
final class ShowroomHttp {
  /// Wraps [http] as the SHOWROOM transport.
  const ShowroomHttp(this.http);

  /// The wrapped transport.
  final LiveHttp http;

  /// GETs [url] with the platform's headers.
  Future<ShowroomResponse> get(Uri url) async {
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.custom(method: 'GET', site: showroomSiteId, url: url, headers: ShowroomEndpoints.headers),
      );
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw ShowroomFailure(ShowroomFailureKind.network, 'GET $url: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode);
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
