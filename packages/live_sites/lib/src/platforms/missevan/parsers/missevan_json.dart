import 'dart:convert';

import 'package:live_sites/src/platforms/missevan/api/missevan_endpoints.dart';
import 'package:live_sites/src/platforms/missevan/parsers/missevan_failure.dart';

/// Tolerant readers of Missevan answers (3.x's private helpers of
/// `MissevanApi`), and the status, size and envelope gates.
abstract final class MissevanJson {
  /// Maps a status other than 200: 401 and 403 a refusal, 404 not-found, 429
  /// throttled, anything else (5xx, a redirect) a network failure.
  static void checkStatus(int status, String what) {
    switch (status) {
      case 200:
        return;
      case 401 || 403:
        throw MissevanFailure(MissevanFailureKind.riskControl, '$what: HTTP $status');
      case 404:
        throw MissevanFailure(MissevanFailureKind.notFound, '$what: HTTP 404');
      case 429:
        throw MissevanFailure(MissevanFailureKind.rateLimited, '$what: HTTP 429');
      default:
        throw MissevanFailure(MissevanFailureKind.network, '$what: HTTP $status');
    }
  }

  /// The `info` object of an answer under `fm.missevan.com/api/v2/`: the
  /// status, then the 1 MiB limit in UTF-8 bytes, then the JSON envelope
  /// `{code, info}`. The only code ever seen for an unknown room
  /// (500030004, sent with HTTP 404) is not-found; any other code but 0,
  /// a body over [MissevanEndpoints.responseLimit] or one that is not a JSON
  /// object is api-changed — an unknown failure is never taken for
  /// "offline".
  static Map<String, dynamic> info(String body, {required String what, int status = 200}) {
    checkStatus(status, what);
    const limit = MissevanEndpoints.responseLimit;
    if (body.length > limit || (body.length * 3 > limit && utf8.encode(body).length > limit)) {
      throw MissevanFailure(MissevanFailureKind.apiChanged, '$what: answer over $limit bytes');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw MissevanFailure(MissevanFailureKind.apiChanged, '$what: not JSON (${_snippet(body)})');
    }
    final root = object(decoded, what);
    final code = integer(root['code']);
    if (code == null) throw MissevanFailure(MissevanFailureKind.apiChanged, '$what: no code');
    if (code == 500030004) throw MissevanFailure(MissevanFailureKind.notFound, '$what: code $code');
    if (code != 0) throw MissevanFailure(MissevanFailureKind.apiChanged, '$what: code $code');
    return object(root['info'], '$what.info');
  }

  /// An object, or api-changed.
  static Map<String, dynamic> object(Object? value, String what) {
    if (value is Map<String, dynamic>) return value;
    throw MissevanFailure(MissevanFailureKind.apiChanged, '$what: expected an object');
  }

  /// A string trimmed, anything else empty.
  static String text(Object? value) => value is String ? value.trim() : '';

  /// An int, or a string that parses as one.
  static int? integer(Object? value) => switch (value) {
    final int number => number,
    final String text => int.tryParse(text),
    _ => null,
  };

  /// A room or creator id (number or string), or api-changed.
  static String id(Object? value, String what) {
    final id = '$value'.trim();
    if (MissevanEndpoints.isId(id)) return id;
    throw MissevanFailure(MissevanFailureKind.apiChanged, '$what: $value');
  }

  /// `status.open_time` as a time: epoch milliseconds from 2000 on (13
  /// digits); null for anything else (0, blank, seconds, not a number).
  static DateTime? startedAt(Object? value) => switch (integer(value)) {
    final int milliseconds when milliseconds >= 946684800000 && milliseconds < 10000000000000 =>
      DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true),
    _ => null,
  };

  static String _snippet(String body) {
    final text = body.trim().replaceAll(RegExp(r'\s+'), ' ');
    return text.length <= 80 ? text : '${text.substring(0, 80)}…';
  }
}
