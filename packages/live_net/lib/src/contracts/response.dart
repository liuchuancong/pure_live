import 'dart:convert';
import 'dart:typed_data';

/// A fully-buffered HTTP response.
///
/// Error statuses (4xx/5xx) are ordinary responses, not exceptions — callers
/// decide what a bad status means for their site. Only the convenience
/// helpers in `LiveHttpCalls` promote bad statuses to `HttpStatusFailure`.
final class LiveResponse {
  /// A response with [statusCode], lower-cased [headers], the raw repeated
  /// [setCookies] lines and a defensive copy of [bodyBytes].
  new({
    required this.statusCode,
    required this.headers,
    required Uint8List bodyBytes,
    this.setCookies = const [],
  }) : bodyBytes = Uint8List.fromList(bodyBytes);

  /// HTTP status code, e.g. `200`.
  final int statusCode;

  /// Response headers keyed by lower-case name; repeated values are joined
  /// with `, `.
  final Map<String, String> headers;

  /// The raw `Set-Cookie` response lines, one per header, in order. [headers]
  /// joins repeated values with `, `, which cannot be split back apart safely
  /// (an `Expires` date holds a comma), so the individual lines are kept here
  /// for callers that must merge a login's cookies (a renewal answers several).
  final List<String> setCookies;

  /// Raw response bytes, already decompressed for gzip/deflate transfers.
  final Uint8List bodyBytes;

  /// Whether the status is 2xx.
  bool get isOk => statusCode >= 200 && statusCode < 300;

  /// The body decoded with the charset from `content-type`.
  ///
  /// Only UTF-8 and Latin-1 are decoded here; anything else (GBK and
  /// friends) stays the caller's job — read [bodyBytes] and decode with a
  /// table-based codec.
  String get text {
    final encoding = _encodingFromHeaders();
    return encoding == null ? utf8.decode(bodyBytes, allowMalformed: true) : encoding.decode(bodyBytes);
  }

  /// The body decoded as UTF-8 and parsed as JSON.
  ///
  /// Throws [FormatException] when the body is not valid JSON.
  Object? get json => jsonDecode(utf8.decode(bodyBytes, allowMalformed: true));

  Encoding? _encodingFromHeaders() {
    final contentType = headers['content-type'];
    if (contentType == null) {
      return null;
    }
    final match = RegExp(r'charset=([\w\-]+)', caseSensitive: false).firstMatch(contentType);
    if (match == null) {
      return null;
    }
    return switch (match.group(1)!.toLowerCase()) {
      'utf-8' || 'utf8' || 'ascii' || 'us-ascii' => utf8,
      'iso-8859-1' || 'latin1' => latin1,
      _ => null,
    };
  }

  @override
  String toString() => 'LiveResponse($statusCode, ${bodyBytes.length}B)';
}
