import 'dart:convert';

import 'package:live_sites/src/platforms/acfun/parsers/acfun_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.

const AcfunFailureKind _apiChanged = AcfunFailureKind.apiChanged;

/// The loose JSON accessors every acfun parser reads through, and the answer
/// envelope rules.
///
/// AcFun mixes types for the same field — `pcursor` is a string on one answer
/// and a number on the next, `viewersCount` arrives as `"76"` — and leaves
/// whole objects out. A wrong type therefore reads as absent instead of
/// throwing: only a missing `result`, a missing list or a non-object answer is
/// a failure, and each of those names the endpoint that broke.
abstract final class AcfunJson {
  /// The JSON object of an answer; see [checkStatus] for the statuses. A body
  /// that is not JSON, or not an object, is api-changed.
  static Map<String, dynamic> root(String body, {required int status, required String what}) {
    checkStatus(body, status: status, what: what);
    final decoded = tryDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw AcfunFailure(_apiChanged, '$what: not a JSON object (${snippet(body)})');
  }

  /// HTTP 429 is rate-limited; 5xx network; 401 and 403 risk control; any
  /// other non-2xx api-changed. (AcFun answers a blocked request with 403 and
  /// a body that is a page, not JSON.)
  static void checkStatus(String body, {required int status, required String what}) {
    if (status >= 200 && status < 300) return;
    if (status == 429) throw AcfunFailure(AcfunFailureKind.rateLimited, '$what: HTTP 429');
    if (status >= 500) throw AcfunFailure(AcfunFailureKind.network, '$what: HTTP $status');
    if (status == 401 || status == 403) throw AcfunFailure(AcfunFailureKind.riskControl, '$what: HTTP $status');
    throw AcfunFailure(_apiChanged, '$what: HTTP $status (${snippet(body)})');
  }

  /// The body decoded, null when it is not JSON.
  static Object? tryDecode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  /// A map, or null when [value] is not one.
  static Map<String, dynamic>? object(Object? value) => value is Map<String, dynamic> ? value : null;

  /// A list, or null when [value] is not one.
  static List<Object?>? listOf(Object? value) => value is List ? value.cast<Object?>() : null;

  /// A list, or the empty list.
  static List<Object?> list(Object? value) => listOf(value) ?? const [];

  /// A field as the site's own `toString()` wrote it: a trimmed string, a
  /// number's digits, anything else empty.
  static String text(Object? value) => value is String ? value.trim() : (value is num ? '$value' : '');

  /// A trimmed non-empty string, or null.
  static String? string(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  /// An integer from a JSON number or integer string; null for a fraction, a
  /// blank or anything else.
  static int? intOf(Object? value) => switch (value) {
    final int value => value,
    final double value => value == value.truncateToDouble() ? value.toInt() : null,
    final String value => int.tryParse(value.trim()),
    _ => null,
  };

  /// A count from a JSON number or integer string: [intOf] when it is zero or
  /// more, else null.
  static int? count(Object? value) => switch (intOf(value)) {
    final int number when number >= 0 => number,
    _ => null,
  };

  /// The first 80 characters of a body, whitespace collapsed — enough to name
  /// a changed answer without quoting a page.
  static String snippet(String body) {
    final text = body.trim().replaceAll(RegExp(r'\s+'), ' ');
    return text.length <= 80 ? text : '${text.substring(0, 80)}…';
  }
}
