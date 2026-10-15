import 'dart:convert';

import 'package:live_sites/src/platforms/pandalive/parsers/pandalive_failure.dart';

/// Tolerant readers of PandaTV answers, and the status, size and envelope
/// gates (3.x's private helpers of `PandaLiveApi`).
abstract final class PandaliveJson {
  /// Maps a status other than 200 and 400: 401 and 403 a session refusal,
  /// 404 not-found, 429 throttled, anything else (5xx, a redirect) a network
  /// failure. 200 is accepted, and 400 is left to the caller: the platform
  /// puts its business refusals (no such broadcaster, broadcast ended) in
  /// HTTP 400 answers whose JSON says why.
  static void checkStatus(int status, String what) => switch (status) {
    200 || 400 => null,
    401 || 403 => throw PandaliveFailure(PandaliveFailureKind.riskControl, '$what: HTTP $status'),
    404 => throw PandaliveFailure(PandaliveFailureKind.notFound, '$what: HTTP 404'),
    429 => throw PandaliveFailure(PandaliveFailureKind.rateLimited, '$what: HTTP 429'),
    _ => throw PandaliveFailure(PandaliveFailureKind.network, '$what: HTTP $status'),
  };

  /// The status gate, then the [limit] on the body's length.
  static void checkBody(String body, String what, int status, {int limit = 4 * 1024 * 1024}) {
    checkStatus(status, what);
    if (body.length > limit) {
      throw PandaliveFailure(PandaliveFailureKind.apiChanged, '$what: answer over $limit characters');
    }
  }

  /// The decoded JSON object of [body], after [checkBody]: an answer that is
  /// not JSON or not an object is api-changed.
  static Map<String, dynamic> json(String body, String what, int status, {int limit = 4 * 1024 * 1024}) {
    checkBody(body, what, status, limit: limit);
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw PandaliveFailure(PandaliveFailureKind.apiChanged, '$what: not JSON');
    }
    return object(decoded, what);
  }

  /// An object, or api-changed.
  static Map<String, dynamic> object(Object? value, String what) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, value) => MapEntry('$key', value));
    throw PandaliveFailure(PandaliveFailureKind.apiChanged, '$what: expected an object');
  }

  /// An object, or null.
  static Map<String, dynamic>? maybeObject(Object? value) =>
      value is Map ? value.map((key, value) => MapEntry('$key', value)) : null;

  /// A string trimmed, anything else empty.
  static String text(Object? value) => value is String ? value.trim() : '';

  /// The first non-empty text among [values].
  static String firstText(Iterable<Object?> values) {
    for (final value in values) {
      final text = PandaliveJson.text(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  /// An int, or a string that parses as one.
  static int? integer(Object? value) => switch (value) {
    final int number => number,
    final String text => int.tryParse(text.trim()),
    _ => null,
  };

  /// A positive int, or null.
  static int? positive(Object? value) {
    final number = integer(value);
    return number != null && number > 0 ? number : null;
  }

  /// An audience figure: a whole number of 0 or more, else null.
  static int? count(Object? value) => switch (integer(value)) {
    final int count when count >= 0 => count,
    _ => null,
  };

  /// A PandaTV flag as the platform writes it: a boolean, `Y`/`N` or 1/0;
  /// null for anything else.
  static bool? flag(Object? value) => switch (value) {
    final bool flag => flag,
    'Y' || 'y' || 1 => true,
    'N' || 'n' || 0 => false,
    _ => null,
  };

  static final RegExp _koreanTime = RegExp(r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$');

  static const Duration _kst = Duration(hours: 9);

  /// A PandaTV time (`startTime`, `2026-09-28 02:00:35`) in UTC: the
  /// platform writes Korean time (UTC+9) without a zone. Null for
  /// `0000-00-00 00:00:00`, a malformed or impossible date, and anything
  /// before 2000.
  static DateTime? koreanTime(Object? value) {
    final match = _koreanTime.firstMatch(text(value));
    if (match == null) return null;
    final parts = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
    final local = DateTime.utc(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]);
    if (local.month != parts[1] || local.day != parts[2] || local.hour != parts[3] || local.minute != parts[4]) {
      return null;
    }
    final utc = local.subtract(_kst);
    return utc.year >= 2000 ? utc : null;
  }

  /// An image as the platform hands it out: an https URL on a
  /// `pandalive.co.kr` subdomain without user info; else empty.
  static String image(Object? value) {
    final text = PandaliveJson.text(value);
    if (text.isEmpty || text.length > 8192) return '';
    final uri = Uri.tryParse(text);
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) return '';
    return uri.host.toLowerCase().endsWith('.pandalive.co.kr') ? uri.toString() : '';
  }
}
