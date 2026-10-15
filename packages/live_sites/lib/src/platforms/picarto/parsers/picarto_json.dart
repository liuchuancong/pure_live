import 'dart:convert';

import 'package:live_sites/src/platforms/picarto/api/picarto_endpoints.dart';
import 'package:live_sites/src/platforms/picarto/parsers/picarto_failure.dart';

/// Tolerant readers of Picarto answers (the reference's private helpers),
/// and the status, size and envelope gates.
abstract final class PicartoJson {
  /// Maps a status other than 200: 401 and 403 a refusal, 404 not-found, 429
  /// throttled, anything else (5xx, a redirect) a network failure.
  static void checkStatus(int status, String what) {
    switch (status) {
      case 200:
        return;
      case 401 || 403:
        throw PicartoFailure(PicartoFailureKind.riskControl, '$what: HTTP $status');
      case 404:
        throw PicartoFailure(PicartoFailureKind.notFound, '$what: HTTP 404');
      case 429:
        throw PicartoFailure(PicartoFailureKind.rateLimited, '$what: HTTP $status');
      default:
        throw PicartoFailure(PicartoFailureKind.network, '$what: HTTP $status');
    }
  }

  /// The status, then the [PicartoEndpoints.responseLimit] cap in UTF-8
  /// bytes (a UTF-16 unit is at most three bytes, so only a long text is
  /// encoded to count).
  static void checkBody(String body, String what, int status) {
    checkStatus(status, what);
    const limit = PicartoEndpoints.responseLimit;
    if (body.length > limit || (body.length > limit ~/ 3 && utf8.encode(body).length > limit)) {
      throw PicartoFailure(PicartoFailureKind.apiChanged, '$what: answer over $limit bytes');
    }
  }

  /// The decoded JSON object of [body], after the gates.
  static Map<String, dynamic> json(String body, String what, int status) {
    checkBody(body, what, status);
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      decoded = null;
    }
    return object(decoded, what, body);
  }

  /// An object, or api-changed; [body] names the answer in the message.
  static Map<String, dynamic> object(Object? value, String what, [String body = '']) {
    if (value is Map<String, dynamic>) return value;
    throw PicartoFailure(PicartoFailureKind.apiChanged, '$what: expected an object${snippet(body)}');
  }

  /// An integer from a JSON number or integer string; null for anything else
  /// (fractions, blank strings).
  static int? integer(Object? value) => switch (value) {
    final int number => number,
    final double number when number == number.truncateToDouble() => number.toInt(),
    final String text => int.tryParse(text.trim()),
    _ => null,
  };

  /// A count from a JSON number or integer string: [integer] when it is zero
  /// or more, else null.
  static int? count(Object? value) => switch (integer(value)) {
    final int number when number >= 0 => number,
    _ => null,
  };

  /// A trimmed non-empty string from a JSON value, or null.
  static String? string(Object? value) {
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }

  /// The first 80 characters of [body], blanks folded — the diagnostic tail
  /// of a shape failure.
  static String snippet(String body) {
    final text = body.trim().replaceAll(RegExp(r'\s+'), ' ');
    return text.isEmpty ? '' : ' (${text.length <= 80 ? text : '${text.substring(0, 80)}…'})';
  }
}
