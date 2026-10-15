import 'dart:convert';

import 'package:live_sites/src/common/normalization/site_urls.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_failure.dart';

/// Tolerant readers of KilaKila answers (3.x's private helpers of
/// `KilakilaApi`), and the status, size and envelope gates.
abstract final class KilakilaJson {
  /// Maps a status other than 200: 401 and 403 a refusal, 404 not-found, 429
  /// throttled, anything else (5xx, a redirect) a network failure.
  static void checkStatus(int status, String what) {
    switch (status) {
      case 200:
        return;
      case 401 || 403:
        throw KilakilaFailure(KilakilaFailureKind.riskControl, '$what: HTTP $status');
      case 404:
        throw KilakilaFailure(KilakilaFailureKind.notFound, '$what: HTTP 404');
      case 429:
        throw KilakilaFailure(KilakilaFailureKind.rateLimited, '$what: HTTP 429');
      default:
        throw KilakilaFailure(KilakilaFailureKind.network, '$what: HTTP $status');
    }
  }

  /// The status, then the 1 MiB limit in UTF-8 bytes (a UTF-16 unit is at
  /// most three bytes, so only a long text is encoded to count).
  static void checkBody(String body, String what, int status) {
    checkStatus(status, what);
    const limit = 1024 * 1024;
    if (body.length > limit || (body.length * 3 > limit && utf8.encode(body).length > limit)) {
      throw KilakilaFailure(KilakilaFailureKind.apiChanged, '$what: answer over $limit bytes');
    }
  }

  /// The decoded JSON object of [body], or api-changed.
  static Map<String, dynamic> json(String body, String what, int status) {
    checkBody(body, what, status);
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw KilakilaFailure(KilakilaFailureKind.apiChanged, '$what: not JSON');
    }
    return object(decoded, what);
  }

  /// A business code that must be 200.
  static void code(Object? value, String what) {
    final number = integer(value);
    if (number == null) throw KilakilaFailure(KilakilaFailureKind.apiChanged, '$what: no code');
    if (number != 200) throw KilakilaFailure(KilakilaFailureKind.apiChanged, '$what: code $number');
  }

  /// The `{h, b}` header: `h.code` 200 and `h.success` true.
  static void header(Map<String, dynamic> envelope, String what) {
    final h = object(envelope['h'], '$what.h');
    code(h['code'], '$what.h');
    if (h['success'] != true) {
      throw KilakilaFailure(KilakilaFailureKind.apiChanged, '$what: h.success is ${h['success']}');
    }
  }

  /// An object, or api-changed.
  static Map<String, dynamic> object(Object? value, String what) {
    if (value is Map<String, dynamic>) return value;
    throw KilakilaFailure(KilakilaFailureKind.apiChanged, '$what: expected an object');
  }

  /// A string trimmed, anything else empty.
  static String text(Object? value) => value is String ? value.trim() : '';

  /// An int, or a string that parses as one.
  static int? integer(Object? value) => switch (value) {
    final int number => number,
    final String text => int.tryParse(text),
    _ => null,
  };

  /// A non-negative integer, or api-changed.
  static int nonNegative(Object? value, String what) {
    final number = integer(value);
    if (number == null || number < 0) {
      throw KilakilaFailure(KilakilaFailureKind.apiChanged, '$what: $value');
    }
    return number;
  }

  /// A positive int within JavaScript's exact range (a larger number may
  /// already have been rounded by the server), or an id string; else
  /// api-changed.
  static String id(Object? value, String what) {
    if (value is int && value > 0 && value <= 9007199254740991) return '$value';
    if (value is String && RegExp(r'^[1-9][0-9]{0,31}$').hasMatch(value)) return value;
    throw KilakilaFailure(KilakilaFailureKind.apiChanged, '$what: $value');
  }

  /// A listener count: an integer of 0 or more (or its text), else null.
  static int? count(Object? value) => switch (integer(value)) {
    final int count when count >= 0 => count,
    _ => null,
  };

  /// A broadcast's start from `actualTime` (epoch milliseconds): null for 0,
  /// negatives, fractions, values that are not milliseconds (before 2001 or
  /// after 2286, such as seconds) and anything that is not an integer.
  static DateTime? startedAt(Object? value) => switch (integer(value)) {
    final int milliseconds when milliseconds >= 1000000000000 && milliseconds < 10000000000000 =>
      DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true),
    _ => null,
  };

  /// An image address, made absolute; one with user info is dropped.
  static String picture(Object? value) {
    final url = normalizeImageUrl(value is String ? value : null);
    return url.isEmpty || (Uri.tryParse(url)?.userInfo.isNotEmpty ?? true) ? '' : url;
  }
}
