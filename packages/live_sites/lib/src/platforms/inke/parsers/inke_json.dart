import 'dart:convert';

import 'package:live_sites/src/common/normalization/site_urls.dart';
import 'package:live_sites/src/platforms/inke/parsers/inke_failure.dart';

/// Tolerant readers of Inke answers (3.x's private helpers of `InkeApi`), and
/// the status, size and JSON gates.
abstract final class InkeJson {
  /// Maps a status other than 200: 401 and 403 a refusal, 404 not-found, 429
  /// throttled, anything else (5xx, a redirect) a network failure.
  static void checkStatus(int status, String what) {
    switch (status) {
      case 200:
        return;
      case 401 || 403:
        throw InkeFailure(InkeFailureKind.riskControl, '$what: HTTP $status');
      case 404:
        throw InkeFailure(InkeFailureKind.notFound, '$what: HTTP 404');
      case 429:
        throw InkeFailure(InkeFailureKind.rateLimited, '$what: HTTP 429');
      default:
        throw InkeFailure(InkeFailureKind.network, '$what: HTTP $status');
    }
  }

  /// The status, then the 1 MiB limit in UTF-8 bytes (a UTF-16 unit is at
  /// most three bytes, so only a long text is encoded to count).
  static void checkBody(String body, String what, int status) {
    checkStatus(status, what);
    const limit = 1024 * 1024;
    if (body.length > limit || (body.length * 3 > limit && utf8.encode(body).length > limit)) {
      throw InkeFailure(InkeFailureKind.apiChanged, '$what: answer over $limit bytes');
    }
  }

  /// The decoded JSON object of [body], or api-changed.
  static Map<String, dynamic> json(String body, String what, int status) {
    checkBody(body, what, status);
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw InkeFailure(InkeFailureKind.apiChanged, '$what: not JSON');
    }
    return object(decoded, what);
  }

  /// An object, or api-changed.
  static Map<String, dynamic> object(Object? value, String what) {
    if (value is Map<String, dynamic>) return value;
    throw InkeFailure(InkeFailureKind.apiChanged, '$what: expected an object');
  }

  /// A string trimmed, anything else empty (3.x's `_text`).
  static String text(Object? value) => value is String ? value.trim() : '';

  /// An int, or a string that parses as one (3.x's `_integer`).
  static int? integer(Object? value) => switch (value) {
    final int number => number,
    final String text => int.tryParse(text),
    _ => null,
  };

  /// A count: an int or digit string, not negative; null otherwise.
  static int? count(Object? value) => switch (integer(value)) {
    final int count when count >= 0 => count,
    _ => null,
  };

  /// A list of at most [max] entries, else api-changed; the entries that are
  /// objects (a bad row is skipped) — 3.x's `_rows`.
  static List<Map<String, dynamic>> rows(Object? value, String what, {int max = 1000}) {
    if (value is! List || value.length > max) {
      throw InkeFailure(InkeFailureKind.apiChanged, '$what: expected a list of rows');
    }
    return value.whereType<Map<String, dynamic>>().toList();
  }

  /// An id field (number or string) as 3.x's `_id` read it; null when it is
  /// not one.
  static String? idOrNull(Object? value) {
    final text = value is int ? '$value' : InkeJson.text(value);
    return RegExp(r'^[1-9][0-9]{0,17}$').hasMatch(text) ? text : null;
  }

  /// [idOrNull], api-changed when it is not one.
  static String idOf(Object? value, String what) =>
      idOrNull(value) ?? (throw InkeFailure(InkeFailureKind.apiChanged, '$what: $value'));

  /// A Unix-seconds time: null for 0, a value outside 2000–2100 (such as
  /// milliseconds) and anything that is not an integer.
  static DateTime? startedAt(Object? value) => switch (integer(value)) {
    final int seconds when seconds >= 946684800 && seconds <= 4102444800 => DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000,
      isUtc: true,
    ),
    _ => null,
  };

  /// An image address, made absolute (the shared normalizer).
  static String picture(Object? value) => normalizeImageUrl(value);
}
