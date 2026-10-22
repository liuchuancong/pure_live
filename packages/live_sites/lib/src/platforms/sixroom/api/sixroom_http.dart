import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/sixroom/api/sixroom_endpoints.dart';
import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_failure.dart';
import 'package:live_sites/src/platforms/sixroom/sixroom_manifest.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the Six Rooms parsers read it: the body text and the status.
typedef SixroomResponse = ({String text, int status});

/// Six Rooms' transport: a [LiveHttp] wrapper that makes the platform's GETs
/// and its one form POST, and hands the parsers `(text, status)` pairs.
///
/// The requests go as `sixroom`, so the app routes the platform through its
/// proxy setting. A page request carries [SixroomEndpoints.webHeaders], the
/// app's mobile lists and the inroom POST the mobile ones, and the chat
/// servers' request its own. A transport breakdown becomes a network failure
/// with the transport's own words; a bad status is an ordinary answer, whose
/// meaning the parsers' status gate decides (the gate folds a redirect, the
/// site's refusals, into risk control).
final class SixroomHttp {
  /// Wraps [http] as the Six Rooms transport.
  const SixroomHttp(this.http);

  /// The wrapped transport.
  final LiveHttp http;

  /// How long one request may take.
  static const Duration timeout = Duration(seconds: 15);

  /// GETs [url] with the platform's web headers, or the mobile ones for the
  /// app's lists.
  Future<SixroomResponse> get(Uri url, {CancelToken? cancel, bool mobile = false}) async => await _send(
    'GET',
    url,
    headers: mobile ? SixroomEndpoints.listHeaders : SixroomEndpoints.webHeaders,
    cancel: cancel,
  );

  /// GETs [url] with the chat servers' headers.
  Future<SixroomResponse> getChat(Uri url, {required String roomId, CancelToken? cancel}) =>
      _send('GET', url, headers: SixroomEndpoints.chatHeaders(roomId), cancel: cancel);

  /// POSTs [fields] as the app's form (the fields in their order, encoded as
  /// `Uri` does).
  Future<SixroomResponse> postForm(Uri url, Map<String, String> fields, {CancelToken? cancel}) => _send(
    'POST',
    url,
    headers: SixroomEndpoints.mobileHeaders,
    body: Uri(queryParameters: fields).query,
    contentType: 'application/x-www-form-urlencoded',
    cancel: cancel,
  );

  Future<SixroomResponse> _send(
    String method,
    Uri url, {
    required Map<String, String> headers,
    String? body,
    String? contentType,
    CancelToken? cancel,
  }) async {
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.custom(
          method: method,
          site: sixroomSiteId,
          url: url,
          headers: headers,
          body: body,
          contentType: contentType,
          cancelToken: cancel,
          timeout: timeout,
        ),
      );
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw SixroomFailure(SixroomFailureKind.network, '$method $url: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode);
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
