import 'package:live_net/src/contracts/live_http.dart';
import 'package:live_net/src/contracts/request.dart';
import 'package:live_net/src/contracts/response.dart';

/// Thrown by the convenience helpers when the answer is not 2xx.
final class HttpStatusFailure implements Exception {
  /// A failure carrying the offending [statusCode] and the requested [url].
  const new({required this.statusCode, required this.url});

  /// The offending HTTP status.
  final int statusCode;

  /// The requested URL.
  final Uri url;

  @override
  String toString() => 'HttpStatusFailure($statusCode, $url)';
}

/// Convenience call shapes over the raw [LiveHttp] contract.
///
/// These promote non-2xx statuses to [HttpStatusFailure]; use [LiveHttp.send]
/// directly when a bad status is an expected, site-specific outcome.
extension LiveHttpCalls on LiveHttp {
  /// Sends and throws [HttpStatusFailure] when the status is not 2xx.
  Future<LiveResponse> sendChecked(LiveRequest request) async {
    final response = await send(request);
    if (!response.isOk) {
      throw HttpStatusFailure(statusCode: response.statusCode, url: request.url);
    }
    return response;
  }

  /// GETs and returns the body decoded by its charset.
  Future<String> getText(
    Uri url, {
    Map<String, String> headers = const {},
    String? site,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    final response = await sendChecked(
      LiveRequest.get(url, headers: headers, site: site, timeout: timeout, cancelToken: cancelToken),
    );
    return response.text;
  }

  /// GETs and JSON-decodes the body.
  Future<Object?> getJson(
    Uri url, {
    Map<String, String> headers = const {},
    String? site,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    final response = await sendChecked(
      LiveRequest.get(url, headers: headers, site: site, timeout: timeout, cancelToken: cancelToken),
    );
    return response.json;
  }

  /// POSTs a JSON body and JSON-decodes the answer.
  Future<Object?> postJson(
    Uri url, {
    required Object? body,
    Map<String, String> headers = const {},
    String? site,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    final response = await sendChecked(
      LiveRequest.json(url, body: body, headers: headers, site: site, timeout: timeout, cancelToken: cancelToken),
    );
    return response.json;
  }

  /// POSTs urlencoded fields and returns the raw checked response.
  Future<LiveResponse> postForm(
    Uri url, {
    required Map<String, String> fields,
    Map<String, String> headers = const {},
    String? site,
    Duration? timeout,
    CancelToken? cancelToken,
  }) {
    return sendChecked(
      LiveRequest.form(url, fields: fields, headers: headers, site: site, timeout: timeout, cancelToken: cancelToken),
    );
  }

  /// HEADs and returns the checked response (headers only, no body).
  Future<LiveResponse> head(
    Uri url, {
    Map<String, String> headers = const {},
    String? site,
    Duration? timeout,
    CancelToken? cancelToken,
  }) {
    return sendChecked(LiveRequest.head(url, headers: headers, site: site, timeout: timeout, cancelToken: cancelToken));
  }
}
