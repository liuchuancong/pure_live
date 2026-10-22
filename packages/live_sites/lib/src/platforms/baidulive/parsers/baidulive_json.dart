import 'dart:convert';

import 'package:live_sites/src/platforms/baidulive/api/baidulive_endpoints.dart';
import 'package:live_sites/src/platforms/baidulive/parsers/baidulive_failure.dart';

/// Tolerant readers of Baidu Live answers (3.x's private helpers of
/// `BaiduLiveApi`), the status gate and the `{errno, data}` envelope gate.
abstract final class BaiduliveJson {
  /// The failure of an answer's status (3.x's `_throwStatus`, typed):
  /// 400/422 a shape the platform refused, 401/403 refused, 451 region, 404
  /// and 410 missing, 429 throttled, 5xx and anything else (3xx included:
  /// redirects are not followed) a network failure. Null for 2xx.
  static BaiduliveFailure? statusError(int status, String what) => switch (status) {
    >= 200 && < 300 => null,
    400 || 422 => BaiduliveFailure(BaiduliveFailureKind.apiChanged, '$what: HTTP $status'),
    401 || 403 => BaiduliveFailure(BaiduliveFailureKind.riskControl, '$what: HTTP $status'),
    451 => BaiduliveFailure(BaiduliveFailureKind.regionBlocked, '$what: HTTP 451'),
    404 || 410 => BaiduliveFailure(BaiduliveFailureKind.notFound, '$what: HTTP $status'),
    429 => BaiduliveFailure(BaiduliveFailureKind.rateLimited, '$what: HTTP 429'),
    _ => BaiduliveFailure(BaiduliveFailureKind.network, '$what: HTTP $status'),
  };

  /// An answer as a JSON object whose `errno` is 0 (3.x: `service`
  /// otherwise; a number or a numeric string): the status gate, the
  /// [BaiduliveEndpoints.responseLimit] (in characters, as 3.x counted it),
  /// JSON, an object, and `errno` 0.
  static Map<String, Object?> answer(String body, {required String what, required int status}) {
    if (statusError(status, what) case final error?) throw error;
    if (body.length > BaiduliveEndpoints.responseLimit) {
      throw BaiduliveFailure(
        BaiduliveFailureKind.apiChanged,
        '$what: answer over ${BaiduliveEndpoints.responseLimit} characters',
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw BaiduliveFailure(BaiduliveFailureKind.apiChanged, '$what: not JSON');
    }
    final root = map(decoded);
    if (root == null) throw BaiduliveFailure(BaiduliveFailureKind.apiChanged, '$what: not a JSON object');
    final errno = integer(root['errno']);
    if (errno != 0) {
      throw BaiduliveFailure(BaiduliveFailureKind.apiChanged, '$what: errno ${root['errno']} ${text(root['errmsg'])}');
    }
    return root;
  }

  /// A JSON object as a `String` keyed map, or null for anything else.
  static Map<String, Object?>? map(Object? value) =>
      value is Map ? value.map((key, value) => MapEntry('$key', value)) : null;

  /// A JSON object, or an empty map for anything else (3.x's `_map(value) ??
  /// const {}` at every read).
  static Map<String, Object?> object(Object? value) => map(value) ?? const {};

  /// A JSON list, or none for anything else.
  static List<Object?> list(Object? value) => value is List ? value.cast<Object?>() : const [];

  /// A value as text, trimmed; '' when it is absent.
  static String text(Object? value) => value?.toString().trim() ?? '';

  /// The first of [values] that is not empty as text; '' when none is.
  static String firstText(Iterable<Object?> values) {
    for (final value in values) {
      final text = BaiduliveJson.text(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  /// An integer from a JSON number or integer string; null for anything else.
  static int? integer(Object? value) => switch (value) {
    final int number => number,
    final double number when number == number.truncateToDouble() => number.toInt(),
    final String text => int.tryParse(text.trim()),
    _ => null,
  };

  /// A count: [integer] when it is zero or more, else null.
  static int? count(Object? value) => switch (integer(value)) {
    final int number when number >= 0 => number,
    _ => null,
  };

  /// A positive [integer], or null.
  static int? positive(Object? value) => switch (integer(value)) {
    final int number when number > 0 => number,
    _ => null,
  };

  /// An image as 3.x accepted it: https on `bdstatic.com`, `bdimg.com` or
  /// `bcebos.com` (or a subdomain), without user info or fragment; else
  /// empty.
  static String image(Object? value) {
    final uri = Uri.tryParse(text(value));
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.hasFragment) return '';
    final host = uri.host.toLowerCase();
    const roots = ['bdstatic.com', 'bdimg.com', 'bcebos.com'];
    return roots.any((root) => host == root || host.endsWith('.$root')) ? uri.toString() : '';
  }

  /// The first of [values] that is an image as [image] reads it; '' when none
  /// is.
  static String firstImage(Iterable<Object?> values) {
    for (final value in values) {
      final url = image(value);
      if (url.isNotEmpty) return url;
    }
    return '';
  }

  /// A broadcast start from the room command's `create_time` (Unix seconds);
  /// null unless positive whole seconds of at most ten digits.
  static DateTime? startedAt(Object? value) {
    final seconds = integer(value);
    if (seconds == null || seconds <= 0 || seconds > 9999999999) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  /// [body] trimmed of its extra whitespace and cut, for an error detail.
  static String snippet(String body) {
    final text = body.trim().replaceAll(RegExp(r'\s+'), ' ');
    return text.length <= 80 ? text : '${text.substring(0, 80)}…';
  }
}
