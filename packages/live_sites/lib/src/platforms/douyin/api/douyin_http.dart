import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the douyin parsers read it. Unlike the other platforms,
/// Douyin's parsers judge the response headers too: a `bdturing-verify` is a
/// captcha and `set-cookie` starts the anonymous session.
typedef DouyinResponse = ({String text, int status, Map<String, String> headers});

/// Douyin's transport: a [LiveHttp] wrapper that hands parsers
/// `(text, status, headers)` triples and maps transport breakdowns onto
/// [DouyinFailureKind.network].
final class DouyinHttp {
  /// Wraps [http] as the douyin transport.
  const DouyinHttp(this.http);

  /// The wrapped transport.
  final LiveHttp http;

  /// GETs [url] with [headers]; bad statuses are ordinary answers — the
  /// parsers decide what 401/403/429/5xx mean for their endpoint.
  Future<DouyinResponse> get(Uri url, {Map<String, String> headers = const {}}) async {
    try {
      final response = await http.send(LiveRequest.custom(method: 'GET', site: 'douyin', url: url, headers: headers));
      return (text: response.text, status: response.statusCode, headers: response.headers);
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw DouyinFailure(DouyinFailureKind.network, 'GET $url: $failure', cause: failure);
    }
  }

  /// The header value of [name], looked up case-insensitively (the transport
  /// lower-cases them, but a caller-supplied map need not be).
  static String? header(Map<String, String> headers, String name) {
    final lower = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    return null;
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
