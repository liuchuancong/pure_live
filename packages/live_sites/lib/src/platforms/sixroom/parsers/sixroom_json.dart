import 'dart:convert';

import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_failure.dart';

/// Tolerant readers of 6.cn answers (the reference's private helpers), and
/// the status, size and envelope gates.
abstract final class SixroomJson {
  /// Maps a status other than 2xx: 404 and 410 not-found, 429 throttled,
  /// 401, 403 and a redirect (the site's refusals) a risk control, anything
  /// else (5xx and the rest) a network failure.
  static void checkStatus(int status, String what) {
    if (status >= 200 && status < 300) return;
    switch (status) {
      case 404 || 410:
        throw SixroomFailure(SixroomFailureKind.notFound, '$what: HTTP $status');
      case 429:
        throw SixroomFailure(SixroomFailureKind.rateLimited, '$what: HTTP 429');
      case 401 || 403 || (>= 300 && < 400):
        throw SixroomFailure(SixroomFailureKind.riskControl, '$what: HTTP $status');
      default:
        throw SixroomFailure(SixroomFailureKind.network, '$what: HTTP $status');
    }
  }

  /// The status, then the byte limit in UTF-8 bytes (a UTF-16 unit is at
  /// most three bytes, so only a long text is encoded to count).
  static void checkBody(String body, String what, int status) {
    checkStatus(status, what);
    const limit = 8 * 1024 * 1024;
    if (body.length > limit || (body.length * 3 > limit && utf8.encode(body).length > limit)) {
      throw SixroomFailure(SixroomFailureKind.apiChanged, '$what: answer over $limit bytes');
    }
  }

  /// The decoded JSON object of [body], or api-changed.
  static Map<String, dynamic> json(String body, String what, int status) {
    checkBody(body, what, status);
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SixroomFailure(SixroomFailureKind.apiChanged, '$what: not JSON (${snippet(body)})');
    }
    return object(decoded, what);
  }

  /// An object with text keys, or api-changed.
  static Map<String, dynamic> object(Object? value, String what) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, item) => MapEntry(key.toString(), item));
    throw SixroomFailure(SixroomFailureKind.apiChanged, '$what: expected an object');
  }

  /// A map with text keys, or null.
  static Map<String, dynamic>? map(Object? value) =>
      value is Map ? value.map((key, item) => MapEntry(key.toString(), item)) : null;

  /// Any value as trimmed text; '' for null.
  static String string(Object? value) => value?.toString().trim() ?? '';

  /// [string] with runs of white space made one space.
  static String text(Object? value) => string(value).replaceAll(RegExp(r'\s+'), ' ').trim();

  /// The first non-empty [text] of [values], or ''.
  static String firstText(Iterable<Object?> values) {
    for (final value in values) {
      final line = text(value);
      if (line.isNotEmpty) return line;
    }
    return '';
  }

  /// An integer or number (truncated), or integer text with `,` separators,
  /// when zero or more; null otherwise.
  static int? count(Object? value) {
    if (value is int) return value >= 0 ? value : null;
    if (value is num) return value >= 0 ? value.toInt() : null;
    final parsed = int.tryParse(string(value).replaceAll(',', ''));
    return parsed != null && parsed >= 0 ? parsed : null;
  }

  /// A time in epoch seconds (a number or digits), UTC; null for 0, a
  /// negative or anything else.
  static DateTime? time(Object? value) {
    final seconds = count(value);
    return seconds == null || seconds <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  /// The site's truthy: true, 1 or `'1'`.
  static bool truthy(Object? value) => value == true || value == 1 || string(value) == '1';

  /// An image address on the platform's own hosts, `//…` and `http://…` made
  /// https; '' otherwise.
  static String image(Object? value) {
    var raw = string(value);
    if (raw.startsWith('//')) raw = 'https:$raw';
    if (raw.startsWith('http://')) raw = 'https://${raw.substring(7)}';
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.hasPort || uri.fragment.isNotEmpty) {
      return '';
    }
    final host = uri.host.toLowerCase();
    const roots = ['6.cn', '6rooms.com', 'xiu123.cn'];
    return roots.any((root) => host == root || host.endsWith('.$root')) ? '$uri' : '';
  }

  /// The first non-empty [image] of [values].
  static String firstImage(Iterable<Object?> values) {
    for (final value in values) {
      final image = SixroomJson.image(value);
      if (image.isNotEmpty) return image;
    }
    return '';
  }

  /// The first line of [body], shortened, for a parse failure's message.
  static String snippet(String body) {
    final line = body.trim().replaceAll(RegExp(r'\s+'), ' ');
    return line.length <= 80 ? line : '${line.substring(0, 80)}…';
  }
}
