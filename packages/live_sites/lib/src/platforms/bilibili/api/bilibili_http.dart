import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer as the bilibili parsers read it.
typedef BilibiliResponse = ({String text, int status, Map<String, String> headers});

/// Bilibili's transport: a [LiveHttp] wrapper that hands parsers
/// `(text, status, headers)` triples and maps transport breakdowns onto
/// [BilibiliFailureKind.network]. Bilibili answers a refused request with a
/// body and a code rather than a status, so bad statuses stay ordinary
/// answers for the parsers to judge.
final class BilibiliHttp {
  /// Wraps [http] as the bilibili transport.
  const BilibiliHttp(this.http);

  /// The wrapped transport.
  final LiveHttp http;

  /// GETs [url] with [headers].
  Future<BilibiliResponse> get(Uri url, {Map<String, String> headers = const {}}) async {
    try {
      final response = await http.send(LiveRequest.custom(method: 'GET', site: 'bilibili', url: url, headers: headers));
      return (text: response.text, status: response.statusCode, headers: response.headers);
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw BilibiliFailure(BilibiliFailureKind.network, 'GET $url: $failure', cause: failure);
    }
  }

  /// GETs [url] with [headers], keeping the whole [LiveResponse] — the raw
  /// `Set-Cookie` lines come out of it, which the QR login's cookies arrive
  /// as ([headers] joins repeated values, which cannot be split back apart).
  Future<LiveResponse> getRaw(Uri url, {Map<String, String> headers = const {}}) async {
    try {
      return await http.send(LiveRequest.custom(method: 'GET', site: 'bilibili', url: url, headers: headers));
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw BilibiliFailure(BilibiliFailureKind.network, 'GET $url: $failure', cause: failure);
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
