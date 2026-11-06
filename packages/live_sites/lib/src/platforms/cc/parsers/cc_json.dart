import 'dart:convert';

import 'package:live_sites/src/common/normalization/html_entities.dart' show decodeHtmlEntities;
import 'package:live_sites/src/common/normalization/normalization.dart'
    show normalizeImageUrl, parseAudienceNumberOrNull;
import 'package:live_sites/src/platforms/cc/api/cc_endpoints.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.

/// Tolerant readers of NetEase CC answers, the status gate and the clock
/// reads of a broadcast's start (the reference's private helpers).
abstract final class CcJson {
  /// HTTP 429 → throttled; 5xx → network; any other non-2xx → api-changed.
  static void checkStatus(int status, String what) {
    if (status >= 200 && status < 300) return;
    if (status == 429) throw CcFailure(CcFailureKind.rateLimited, '$what: HTTP 429');
    if (status >= 500) throw CcFailure(CcFailureKind.network, '$what: HTTP $status');
    throw CcFailure(CcFailureKind.apiChanged, '$what: HTTP $status');
  }

  /// The JSON of a response after [checkStatus]; a body that is not JSON is
  /// api-changed.
  static Object? decode(String body, {required int status, required String what}) {
    checkStatus(status, what);
    try {
      return jsonDecode(body);
    } on FormatException {
      throw CcFailure(CcFailureKind.apiChanged, '$what: not JSON (${snippet(body)})');
    }
  }

  /// [text] decoded as JSON, or null when it is not (the room page's
  /// `__NEXT_DATA__`, whose absence is the caller's own api-changed).
  static Object? tryDecode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }

  /// An object, or null for anything else.
  static Map<String, dynamic>? object(Object? value) => value is Map<String, dynamic> ? value : null;

  /// An object field, or an empty one: a missing field reads as empty.
  static Map<String, dynamic> fields(Object? value) => value is Map<String, dynamic> ? value : const {};

  /// A list, or an empty one.
  static List<Object?> list(Object? value) => value is List ? value.cast<Object?>() : const [];

  /// A field as 3.x wrote it (the string itself, a number as text), empty
  /// when missing (3.x wrote "null" or null).
  static String text(Object? value) => switch (value) {
    final String textValue => textValue,
    final num number => '$number',
    _ => '',
  };

  /// A trimmed non-empty string from a JSON value, or null.
  static String? string(Object? value) {
    if (value == null) return null;
    final textValue = value.toString().trim();
    return textValue.isEmpty ? null : textValue;
  }

  /// An integer from a JSON number or integer string; null for anything
  /// else.
  static int? integer(Object? value) => switch (value) {
    final int number => number,
    final double number when number == number.truncateToDouble() => number.toInt(),
    final String textValue => int.tryParse(textValue.trim()),
    _ => null,
  };

  /// An http(s) URL from a JSON value, or null.
  static Uri? url(Object? value) {
    final textValue = string(value);
    if (textValue == null) return null;
    final uri = Uri.tryParse(textValue);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty ? uri : null;
  }

  /// A count field as written when it holds a digit (3.x's
  /// `parseRoomAudience` rule), as a number; null when it says nothing.
  /// Values like `298945` stay exact; a unit-suffixed text falls through the
  /// shared tolerant count reader.
  static int? digitCount(Object? value) {
    final textValue = value?.toString().trim() ?? '';
    if (textValue.isEmpty || textValue == 'null' || !RegExp('[0-9]').hasMatch(textValue)) return null;
    return integer(textValue) ?? parseAudienceNumberOrNull(textValue);
  }

  /// [value], else [fallback], made absolute by [normalizeImageUrl]; empty
  /// when neither is an image.
  static String image(Object? value, [Object? fallback]) {
    final first = normalizeImageUrl(value);
    return first.isNotEmpty ? first : normalizeImageUrl(fallback);
  }

  /// A name or attribute as the catalog reads it: text, HTML entities
  /// decoded, surrounding blanks dropped.
  static String catalogName(Object? value) => decodeHtmlEntities(text(value)).trim();

  static final RegExp _localTime = RegExp(r'^(\d{4})-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$');

  /// `yyyy-MM-dd HH:mm:ss` in Beijing time (UTC+8, checked against the
  /// channel's `liveMinute`), as UTC; none before 2000 or when malformed.
  static DateTime? beijingTime(Object? value) {
    final match = _localTime.firstMatch(string(value) ?? '');
    if (match == null || int.parse(match.group(1)!) < 2000) return null;
    return DateTime.tryParse('${match.group(0)!.replaceFirst(' ', 'T')}+08:00')?.toUtc();
  }

  /// A `cuteid`/`ccid` (number or string) as the room id, or null.
  static String? cuteid(Object? value) => switch (value) {
    final int number when number > 0 && number <= 9007199254740991 => '$number',
    final String textValue when CcEndpoints.ccidPattern.hasMatch(textValue) => textValue,
    _ => null,
  };

  /// The first snippet of a body, for an error message.
  static String snippet(String body) {
    final textValue = body.trim().replaceAll(RegExp(r'\s+'), ' ');
    return textValue.length <= 80 ? textValue : '${textValue.substring(0, 80)}…';
  }
}
