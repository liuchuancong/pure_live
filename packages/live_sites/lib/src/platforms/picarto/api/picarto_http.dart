import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/picarto/api/picarto_endpoints.dart';
import 'package:live_sites/src/platforms/picarto/parsers/picarto_failure.dart';
import 'package:live_sites/src/platforms/picarto/picarto_manifest.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the Picarto parsers read it: the body text and the status.
typedef PicartoResponse = ({String text, int status});

/// One decoded GraphQL answer as the chat token reader takes it: the JSON
/// (null when the body was none) and the status.
typedef PicartoGraphResponse = ({Object? json, int status});

/// Picarto's transport: a [LiveHttp] wrapper that makes the API GETs and the
/// chat token's GraphQL POST, and hands the parsers `(text, status)` pairs.
///
/// Every request carries [PicartoEndpoints.headers] and goes as `picarto`,
/// so the app routes the platform through its proxy setting. A transport
/// breakdown becomes a network failure with the transport's own words; a bad
/// status is an ordinary answer, whose meaning the parsers' status gate
/// decides.
final class PicartoHttp {
  /// Wraps [http] as the Picarto transport.
  const PicartoHttp(this.http);

  /// The wrapped transport.
  final LiveHttp http;

  /// GETs [url] with the platform's headers.
  Future<PicartoResponse> get(Uri url, {CancelToken? cancel}) async {
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.get(url, headers: PicartoEndpoints.headers, site: picartoSiteId, cancelToken: cancel),
      );
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw PicartoFailure(PicartoFailureKind.network, 'GET $url: $failure', cause: failure);
    }
    return (text: response.text, status: response.statusCode);
  }

  /// POSTs a JSON body to [url] and decodes the answer (null when the body
  /// is no JSON — the token reader refuses it).
  Future<PicartoGraphResponse> postJson(
    Uri url, {
    required Object? body,
    Duration? timeout,
    CancelToken? cancel,
  }) async {
    final LiveResponse response;
    try {
      response = await http.send(
        LiveRequest.json(
          url,
          body: body,
          headers: PicartoEndpoints.headers,
          site: picartoSiteId,
          timeout: timeout,
          cancelToken: cancel,
        ),
      );
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw PicartoFailure(PicartoFailureKind.network, 'POST $url: $failure', cause: failure);
    }
    Object? json;
    try {
      json = response.json;
    } on FormatException {
      json = null;
    }
    return (json: json, status: response.statusCode);
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
