import 'dart:convert';

import 'package:live_sites/src/platforms/liveme/api/liveme_endpoints.dart';
import 'package:live_sites/src/platforms/liveme/parsers/liveme_failure.dart';

/// Tolerant readers of LiveMe answers (3.x's private helpers of
/// `LiveMeApi`), and the status, size and envelope gates.
abstract final class LivemeJson {
  /// Maps an HTTP status other than 200 as the reference did (it read no
  /// body then): 400 api-changed, 401 and 403 a refusal, 404 not-found, 420
  /// and 429 throttled, anything else (5xx, a redirect) a network failure.
  static void checkStatus(int status, String what) {
    switch (status) {
      case 200:
        return;
      case 400:
        throw LivemeFailure(LivemeFailureKind.apiChanged, '$what: HTTP 400');
      case 401 || 403:
        throw LivemeFailure(LivemeFailureKind.riskControl, '$what: HTTP $status');
      case 404:
        throw LivemeFailure(LivemeFailureKind.notFound, '$what: HTTP 404');
      case 420 || 429:
        throw LivemeFailure(LivemeFailureKind.rateLimited, '$what: HTTP $status');
      default:
        throw LivemeFailure(LivemeFailureKind.network, '$what: HTTP $status');
    }
  }

  /// The root object of an answer whose `status` (a string or a number) is
  /// 200. Other statuses as the reference read them: 400 and 404 not-found
  /// (an unknown short id is business 400), 401 and 403 a refusal, 420 and
  /// 429 throttled, 500 "user not exist" not-found, other 5xx a network
  /// failure, anything else api-changed.
  static Map<String, dynamic> envelope(String body, String what, int status) {
    checkStatus(status, what);
    if (body.length > LivemeEndpoints.responseLimit ||
        (body.length * 3 > LivemeEndpoints.responseLimit && utf8.encode(body).length > LivemeEndpoints.responseLimit)) {
      throw LivemeFailure(LivemeFailureKind.apiChanged, '$what: answer over ${LivemeEndpoints.responseLimit} bytes');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw LivemeFailure(LivemeFailureKind.apiChanged, '$what: not JSON');
    }
    final root = object(decoded, what);
    final code = integer(root['status']);
    final message = root['msg'] is String ? root['msg'] as String : '';
    return switch (code) {
      200 => root,
      null => throw LivemeFailure(LivemeFailureKind.apiChanged, '$what: no status'),
      400 || 404 => throw LivemeFailure(LivemeFailureKind.notFound, '$what: $code $message'),
      401 || 403 => throw LivemeFailure(LivemeFailureKind.riskControl, '$what: $code $message'),
      420 || 429 => throw LivemeFailure(LivemeFailureKind.rateLimited, '$what: $code $message'),
      500 when message.contains('not exist') => throw LivemeFailure(LivemeFailureKind.notFound, '$what: $message'),
      final int other when other >= 500 => throw LivemeFailure(LivemeFailureKind.network, '$what: $other $message'),
      final int other => throw LivemeFailure(LivemeFailureKind.apiChanged, '$what: status $other $message'),
    };
  }

  /// An object, or api-changed.
  static Map<String, dynamic> object(Object? value, String what) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, value) => MapEntry('$key', value));
    throw LivemeFailure(LivemeFailureKind.apiChanged, '$what: expected an object');
  }

  /// A list of at most [max] entries, or api-changed.
  static List<Object?> list(Object? value, String what, {required int max}) {
    if (value is! List || value.length > max) {
      throw LivemeFailure(LivemeFailureKind.apiChanged, '$what: expected a list of at most $max');
    }
    return value;
  }

  /// An int, or a value whose text parses as one.
  static int? integer(Object? value) => value is int ? value : int.tryParse(value?.toString() ?? '');

  /// A count: null for null or '', else a non-negative int; anything else is
  /// api-changed.
  static int? count(Object? value, String what) {
    if (value == null || value == '') return null;
    final number = integer(value);
    if (number == null || number < 0) throw LivemeFailure(LivemeFailureKind.apiChanged, '$what: $value');
    return number;
  }

  /// Text: '' for null, else a string (at most 128 Ki characters) trimmed;
  /// anything else is api-changed.
  static String text(Object? value, String what) {
    if (value == null) return '';
    if (value is! String || value.length > 131072) throw LivemeFailure(LivemeFailureKind.apiChanged, '$what: not text');
    return value.trim();
  }

  /// The first non-empty text of [values], or api-changed when none is.
  static String firstText(List<Object?> values, String what) {
    for (final value in values) {
      final text = LivemeJson.text(value, what);
      if (text.isNotEmpty) return text;
    }
    throw LivemeFailure(LivemeFailureKind.apiChanged, '$what: missing');
  }

  /// A room id, or api-changed: 5–12 digits, no leading zero.
  static String shortId(Object? value, String what) =>
      LivemeEndpoints.normalizeShortId(value?.toString() ?? '') ??
      (throw LivemeFailure(LivemeFailureKind.apiChanged, '$what: $value'));

  /// A user or video id, or api-changed: 13–24 digits, no leading zero.
  static String longId(Object? value, String what) =>
      LivemeEndpoints.normalizeLongId(value?.toString() ?? '') ??
      (throw LivemeFailure(LivemeFailureKind.apiChanged, '$what: $value'));

  /// A country code: two letters, upper case, else ''.
  static String countryCode(Object? value) {
    final text = LivemeJson.text(value, 'countryCode').toUpperCase();
    return RegExp(r'^[A-Z]{2}$').hasMatch(text) ? text : '';
  }
}
