import 'dart:convert';

import 'package:live_sites/src/common/normalization/site_urls.dart';
import 'package:live_sites/src/platforms/tiktok/api/tiktok_endpoints.dart';
import 'package:live_sites/src/platforms/tiktok/parsers/tiktok_failure.dart';
import 'package:live_sites/src/platforms/tiktok/parsers/tiktok_link.dart';

/// Tolerant readers of TikTok answers (the reference's private helpers), and
/// the status, size and envelope gates.
abstract final class TiktokJson {
  /// Maps a status other than 200: 400 says the shape changed, 401 and 403
  /// are a refusal, 404 is not-found, 420 and 429 are throttled, anything
  /// else (5xx, a redirect on an API request) is a network failure.
  static void checkStatus(int status, String what) {
    switch (status) {
      case 200:
        return;
      case 400:
        throw TiktokFailure(TiktokFailureKind.apiChanged, '$what: HTTP 400');
      case 401 || 403:
        throw TiktokFailure(TiktokFailureKind.riskControl, '$what: HTTP $status');
      case 404:
        throw TiktokFailure(TiktokFailureKind.notFound, '$what: HTTP 404');
      case 420 || 429:
        throw TiktokFailure(TiktokFailureKind.rateLimited, '$what: HTTP $status');
      default:
        throw TiktokFailure(TiktokFailureKind.network, '$what: HTTP $status');
    }
  }

  /// The status, then the answer limit ([TiktokEndpoints.responseLimit]) in
  /// UTF-8 bytes (a UTF-16 unit is at most three bytes, so only a long text
  /// is encoded to count).
  static void checkBody(String body, String what, int status) {
    checkStatus(status, what);
    const limit = TiktokEndpoints.responseLimit;
    if (body.length > limit || (body.length * 3 > limit && utf8.encode(body).length > limit)) {
      throw TiktokFailure(TiktokFailureKind.apiChanged, '$what: answer over $limit bytes');
    }
  }

  /// The JSON object of an answer: the status and size gates, then decode.
  /// An empty body is the site's anonymous refusal.
  static Map<String, dynamic> envelope(String body, {required int status, required String what}) {
    checkBody(body, what, status);
    if (body.isEmpty) {
      throw TiktokFailure(TiktokFailureKind.riskControl, '$what: empty answer');
    }
    return object(decode(body, what), what);
  }

  /// The decoded JSON of [text], or api-changed.
  static Object? decode(String text, String what) {
    try {
      return jsonDecode(text);
    } on FormatException {
      throw TiktokFailure(TiktokFailureKind.apiChanged, '$what: not JSON');
    }
  }

  /// An object, or api-changed.
  static Map<String, dynamic> object(Object? value, String what) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, item) => MapEntry('$key', item));
    throw TiktokFailure(TiktokFailureKind.apiChanged, '$what: expected an object');
  }

  /// An object, or none (empty) for anything else (`stats` and
  /// `liveRoomStats` only fill the card, so a broken one loses itself).
  static Map<String, dynamic> lenientObject(Object? value) =>
      value is Map ? object(value, '') : const <String, dynamic>{};

  /// An int, an integral number or an integer string.
  static int? integer(Object? value) {
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.roundToDouble()) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  /// A count of zero or more (or its text), else null.
  static int? lenientCount(Object? value) => switch (integer(value)) {
    final int count when count >= 0 => count,
    _ => null,
  };

  /// A boolean (absent is none), or api-changed for anything else.
  static bool? optionalBool(Object? value, String what) {
    if (value == null || value is bool) return value as bool?;
    throw TiktokFailure(TiktokFailureKind.apiChanged, '$what: $value');
  }

  /// A username, or api-changed.
  static String username(Object? value, String what) {
    final user = value is String ? TiktokLink.normalizeUsername(value) : null;
    if (user == null) {
      throw TiktokFailure(TiktokFailureKind.apiChanged, '$what: $value is no username');
    }
    return user;
  }

  /// A long id (15–25 digits), from a string or a number, or api-changed.
  static String longId(Object? value, String what) {
    final text = value?.toString().trim() ?? '';
    if (!RegExp(r'^[1-9][0-9]{14,24}$').hasMatch(text)) {
      throw TiktokFailure(TiktokFailureKind.apiChanged, '$what: $value');
    }
    return text;
  }

  /// A long id (see [longId]), else empty.
  static String lenientLongId(Object? value) {
    final text = value?.toString().trim() ?? '';
    return RegExp(r'^[1-9][0-9]{14,24}$').hasMatch(text) ? text : '';
  }

  /// A string of at most 8192 characters, trimmed, else empty (a blank or
  /// malformed `nickname`, `title`, `signature` or `secUid` only loses
  /// itself).
  static String lenientText(Object? value) => value is String && value.length <= 8192 ? value.trim() : '';

  /// A string of at most 4 MiB, trimmed; absent or empty is empty; anything
  /// else is api-changed.
  static String optionalText(Object? value, String what) {
    if (value == null || value == '') return '';
    if (value is String && value.length <= 4 * 1024 * 1024) return value.trim();
    throw TiktokFailure(TiktokFailureKind.apiChanged, '$what: expected a string');
  }

  /// A tier key, lower case, of letters, digits and `_`, or api-changed.
  static String tier(String raw, String what) {
    final value = raw.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{1,24}$').hasMatch(value)) {
      throw TiktokFailure(TiktokFailureKind.apiChanged, '$what: tier "$raw"');
    }
    return value;
  }

  /// The codec of a tier: empty is [fallback]; `avc`/`h264` is h264;
  /// `hevc`/`h265`/`bytevc1` is h265; anything else is api-changed.
  static String codec(Object? value, String fallback, String what) =>
      switch (optionalText(value, '$what.VCodec').toLowerCase()) {
        '' => fallback,
        'avc' || 'h264' => 'h264',
        'hevc' || 'h265' || 'bytevc1' => 'h265',
        final other => throw TiktokFailure(TiktokFailureKind.apiChanged, '$what: codec $other'),
      };

  /// `720x1280` or `720p`, lower case, else empty (also for a value that is
  /// no string).
  static String resolution(Object? value) {
    final text = value is String ? value.trim().toLowerCase() : '';
    return RegExp(r'^(?:[1-9][0-9]{1,4}x[1-9][0-9]{1,4}|[1-9][0-9]{2,4}p)$').hasMatch(text) ? text : '';
  }

  /// The https media URL [text] spells, on a trusted host
  /// ([TiktokEndpoints.isTrustedHost]), without user info, fragment, spaces
  /// or control characters, at most 64 KiB; else api-changed.
  static Uri mediaUrl(String text, String what) {
    final uri = text.length > 65536 || RegExp(r'[\s\x00-\x1f]').hasMatch(text) ? null : Uri.tryParse(text);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !TiktokEndpoints.isTrustedHost(uri.host)) {
      throw TiktokFailure(TiktokFailureKind.apiChanged, '$what: not a TikTok media URL');
    }
    return uri;
  }

  /// The first of [candidates] that is an https picture on a trusted host,
  /// else empty.
  static String image(List<Object?> candidates) {
    for (final candidate in candidates) {
      final url = normalizeImageUrl(candidate is String && candidate.length <= 16384 ? candidate : null);
      final uri = Uri.tryParse(url);
      if (uri != null &&
          uri.scheme == 'https' &&
          uri.userInfo.isEmpty &&
          !uri.hasFragment &&
          TiktokEndpoints.isTrustedHost(uri.host)) {
        return url;
      }
    }
    return '';
  }

  /// `liveRoom.startTime` (Unix seconds) as a UTC time; null when missing,
  /// not an integer, or outside 2000–2100.
  static DateTime? startTime(Object? value) {
    final seconds = integer(value);
    if (seconds == null || seconds < 946684800 || seconds > 4102444800) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }
}
