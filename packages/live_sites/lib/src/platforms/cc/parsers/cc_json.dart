import 'dart:convert';

import 'package:live_sites/src/common/normalization/site_counts.dart';
import 'package:live_sites/src/common/normalization/site_urls.dart';
import 'package:live_sites/src/platforms/cc/api/cc_endpoints.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_failure.dart';

/// Tolerant readers of CC answers (3.x's private helpers of `CcApi`), and
/// the status, size and JSON gates every answer goes through.
abstract final class CcJson {
  /// The status mapping (3.x's `_checkStatus`, with the contract's refusal
  /// fold): 2xx is an answer; 401 and 403 are a refusal, 429 throttled, 5xx
  /// a network failure; any other status (a 400-class shape no endpoint
  /// explains, a redirect) is api-changed.
  static void checkStatus(int status, String what) {
    if (status >= 200 && status < 300) return;
    if (status == 401 || status == 403) {
      throw CcFailure(CcFailureKind.riskControl, '$what: HTTP $status');
    }
    if (status == 429) throw CcFailure(CcFailureKind.rateLimited, '$what: HTTP 429');
    if (status >= 500) throw CcFailure(CcFailureKind.network, '$what: HTTP $status');
    throw CcFailure(CcFailureKind.apiChanged, '$what: HTTP $status');
  }

  /// The status, then the [CcEndpoints.responseLimit] in UTF-8 bytes (a
  /// UTF-16 unit is at most three bytes, so only a long text is encoded to
  /// count).
  static void checkBody(String body, String what, int status) {
    checkStatus(status, what);
    const limit = CcEndpoints.responseLimit;
    if (body.length > limit || (body.length * 3 > limit && utf8.encode(body).length > limit)) {
      throw CcFailure(CcFailureKind.apiChanged, '$what: answer over $limit bytes');
    }
  }

  /// The decoded JSON of [body] after the gates; a body that is not JSON is
  /// api-changed. May be any JSON value, `null` included.
  static Object? decode(String body, {required String what, required int status}) {
    checkBody(body, what, status);
    try {
      return jsonDecode(body);
    } on FormatException {
      throw CcFailure(CcFailureKind.apiChanged, '$what: not JSON (${snippet(body)})');
    }
  }

  /// An object, or null for anything else (a missing field reads as absent).
  static Map<String, dynamic>? objectOrNull(Object? value) => value is Map<String, dynamic> ? value : null;

  /// An object field, or an empty one: a missing field reads as empty (3.x's
  /// `_fields`).
  static Map<String, dynamic> fields(Object? value) => objectOrNull(value) ?? const {};

  /// A list, or an empty one.
  static List<Object?> list(Object? value) => value is List ? value.cast<Object?>() : const [];

  /// A field as 3.x wrote it (the string itself, a number as text), empty
  /// when missing (3.x wrote "null" or null).
  static String text(Object? value) => switch (value) {
    final String text => text,
    final num number => '$number',
    _ => '',
  };

  /// A string field, or null for anything else.
  static String? string(Object? value) => value is String ? value : null;

  /// 3.x's integers: an int, an integral number, or integer text.
  static int? integer(Object? value) => switch (value) {
    final int number => number,
    final num number when number.isFinite && number == number.toInt() => number.toInt(),
    final String text => int.tryParse(text.trim()),
    _ => null,
  };

  /// An audience figure kept as the platform wrote it: an audience text that
  /// carries a digit (an explicit zero included) parsed to an absolute
  /// number, else null.
  static int? figure(Object? value) {
    final raw = text(value);
    return hasExplicitAudienceValue(raw) ? parseAudienceNumberOrNull(raw) : null;
  }

  /// A `cuteid`/`ccid` (number or string) as the room id, or null.
  static String? cuteid(Object? value) {
    if (value is int) return value > 0 && value <= 9007199254740991 ? '$value' : null;
    if (value is String && CcEndpoints.ccidPattern.hasMatch(value)) return value;
    return null;
  }

  /// An absolute https image address with a host and no user info, else
  /// empty (the catalog's rule).
  static String httpsImage(Object? value) {
    if (value is! String || value.length > 2048) return '';
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty && uri.userInfo.isEmpty ? value : '';
  }

  /// Bounded non-blank text: [value] trimmed when it is a string of at most
  /// [limit] characters that stays non-blank, else null (the catalog's
  /// fields).
  static String? boundedText(Object? value, int limit) =>
      value is String && value.trim().isNotEmpty && value.length <= limit ? value.trim() : null;

  /// An absolute http(s) URL of [value] with a host, else null.
  static Uri? url(Object? value) {
    final raw = string(value);
    if (raw == null) return null;
    final uri = Uri.tryParse(raw);
    return uri != null && (uri.isScheme('http') || uri.isScheme('https')) && uri.host.isNotEmpty ? uri : null;
  }

  static final RegExp _localTime = RegExp(r'^(\d{4})-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$');

  /// `yyyy-MM-dd HH:mm:ss` in Beijing time (UTC+8, checked against the
  /// channel's `liveMinute`), as UTC; none before 2000 or when malformed.
  static DateTime? beijingTime(Object? value) {
    final match = _localTime.firstMatch(string(value) ?? '');
    if (match == null || int.parse(match.group(1)!) < 2000) return null;
    return DateTime.tryParse('${match.group(0)!.replaceFirst(' ', 'T')}+08:00')?.toUtc();
  }

  /// The first snippet of a body, for an error message.
  static String snippet(String body) {
    final text = body.trim().replaceAll(RegExp(r'\s+'), ' ');
    return text.length <= 80 ? text : '${text.substring(0, 80)}…';
  }

  /// An image link made absolute by the shared normalizer (the lists' covers
  /// and avatars arrive protocol-relative or bare).
  static String image(Object? value) => normalizeImageUrl(value is String ? value : null);
}
