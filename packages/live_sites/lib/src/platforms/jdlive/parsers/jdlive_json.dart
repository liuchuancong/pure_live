import 'dart:convert';

import 'package:live_sites/src/platforms/jdlive/api/jdlive_endpoints.dart';
import 'package:live_sites/src/platforms/jdlive/parsers/jdlive_failure.dart';

/// Tolerant readers of JD Live answers (3.x's private helpers of
/// `JdLiveApi`), and the status and envelope gates every endpoint goes
/// through.
abstract final class JdliveJson {
  /// The status mapping (3.x's `_throwStatus`): 200 is an answer; 400 and
  /// 422 are api-changed, 401 and 403 a refusal, 404 not-found, 429
  /// throttled; 5xx and every other status a network failure.
  static void checkStatus(int status, {required String what}) {
    switch (status) {
      case 200:
        return;
      case 400 || 422:
        throw JdliveFailure(JdliveFailureKind.apiChanged, '$what: HTTP $status');
      case 401 || 403:
        throw JdliveFailure(JdliveFailureKind.riskControl, '$what: HTTP $status');
      case 404:
        throw JdliveFailure(JdliveFailureKind.notFound, '$what: HTTP 404');
      case 429:
        throw JdliveFailure(JdliveFailureKind.rateLimited, '$what: HTTP 429');
      default:
        throw JdliveFailure(JdliveFailureKind.network, '$what: HTTP $status');
    }
  }

  /// The `{code, subCode, data}` envelope (3.x's `_responseData`): `code`
  /// must be `0` (else api-changed, such as `2` "the current API does not
  /// exist"), `subCode` `0` (else not-found), `data` an object. An answer
  /// over [JdliveEndpoints.responseLimit] bytes or not JSON is api-changed.
  static Map<String, dynamic> data(String body, {required int status, required String what}) {
    checkStatus(status, what: what);
    // UTF-8 needs at most three bytes per UTF-16 unit, so short bodies need
    // no encoding.
    if (body.length > JdliveEndpoints.responseLimit ||
        (body.length * 3 > JdliveEndpoints.responseLimit && utf8.encode(body).length > JdliveEndpoints.responseLimit)) {
      throw JdliveFailure(JdliveFailureKind.apiChanged, '$what: answer over ${JdliveEndpoints.responseLimit} bytes');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw JdliveFailure(JdliveFailureKind.apiChanged, '$what: not JSON (${snippet(body)})');
    }
    final root = object(decoded, what);
    final code = text(root['code']);
    if (code != '0') {
      throw JdliveFailure(JdliveFailureKind.apiChanged, '$what: code $code ${text(root['echo'])}'.trim());
    }
    final sub = text(root['subCode']);
    if (sub != '0') throw JdliveFailure(JdliveFailureKind.notFound, '$what: subCode $sub');
    return object(root['data'], '$what data');
  }

  /// An object, or api-changed.
  static Map<String, dynamic> object(Object? value, String what) {
    if (value is Map<String, dynamic>) return value;
    throw JdliveFailure(JdliveFailureKind.apiChanged, '$what is not an object');
  }

  /// 3.x's integers: an integer, an integral finite number, or integer text.
  static int? integer(Object? value) => switch (value) {
    final int number => number,
    final num number when number.isFinite && number == number.toInt() => number.toInt(),
    final String text => int.tryParse(text.trim()),
    _ => null,
  };

  /// A whole number that is not negative, else null.
  static int? count(Object? value) {
    final result = integer(value);
    return result != null && result >= 0 ? result : null;
  }

  /// Text of an envelope field: text trimmed, anything else written.
  static String text(Object? value) => value is String ? value.trim() : value?.toString().trim() ?? '';

  /// Optional text: null is `''`; text (at most 65536 characters) trimmed
  /// with runs of whitespace made one space; anything else is api-changed.
  /// Blank stays `''`.
  static String optionalText(Object? value, String what) {
    if (value == null) return '';
    if (value is! String || value.length > 65536) {
      throw JdliveFailure(JdliveFailureKind.apiChanged, '$what is not text');
    }
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// The first snippet of a body, for an error message.
  static String snippet(String body) {
    final text = body.trim().replaceAll(RegExp(r'\s+'), ' ');
    return text.length <= 80 ? text : '${text.substring(0, 80)}…';
  }
}
