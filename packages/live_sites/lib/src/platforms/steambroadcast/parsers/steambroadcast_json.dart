import 'dart:convert';

import 'package:live_sites/src/common/normalization/html_entities.dart';
import 'package:live_sites/src/platforms/steambroadcast/api/steambroadcast_endpoints.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_failure.dart';

/// Tolerant readers of Steam Broadcast answers, and the status, size and
/// JSON gates (the reference's private helpers).
abstract final class SteambroadcastJson {
  /// The status mapping: 200 is an answer; 400 and 422 are api-changed, 401
  /// and 403 risk control (Akamai's refusal page), 404 not-found, 429
  /// throttled; 5xx and every other status (redirects included) network. An
  /// answer over [SteambroadcastEndpoints.responseLimit] bytes is
  /// api-changed.
  static void checkBody(String body, String what, int status) {
    switch (status) {
      case 200:
        break;
      case 400 || 422:
        throw SteambroadcastFailure(SteambroadcastFailureKind.apiChanged, '$what: HTTP $status');
      case 401 || 403:
        throw SteambroadcastFailure(SteambroadcastFailureKind.riskControl, '$what: HTTP $status');
      case 404:
        throw SteambroadcastFailure(SteambroadcastFailureKind.notFound, '$what: HTTP 404');
      case 429:
        throw SteambroadcastFailure(SteambroadcastFailureKind.rateLimited, '$what: HTTP 429');
      default:
        throw SteambroadcastFailure(SteambroadcastFailureKind.network, '$what: HTTP $status');
    }
    // UTF-8 needs at most three bytes per UTF-16 unit, so short bodies need
    // no encoding.
    const limit = SteambroadcastEndpoints.responseLimit;
    if (body.length > limit || (body.length * 3 > limit && utf8.encode(body).length > limit)) {
      throw SteambroadcastFailure(SteambroadcastFailureKind.apiChanged, '$what: answer over $limit bytes');
    }
  }

  /// The decoded JSON object of [body]; anything else is api-changed.
  static Map<Object?, Object?> object(String body, String what, int status) {
    checkBody(body, what, status);
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SteambroadcastFailure(SteambroadcastFailureKind.apiChanged, '$what: not JSON (${snippet(body)})');
    }
    if (decoded is! Map) {
      throw SteambroadcastFailure(SteambroadcastFailureKind.apiChanged, '$what: not an object');
    }
    return decoded;
  }

  /// [text] trimmed with runs of white space made one space; over 65536
  /// characters is api-changed.
  static String clean(String text) {
    if (text.length > 65536) {
      throw const SteambroadcastFailure(SteambroadcastFailureKind.apiChanged, 'text over 65536 characters');
    }
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// A JSON text that only fills the card: cleaned, HTML characters
  /// decoded; '' when it is not text or too long.
  static String lenientText(Object? value) =>
      value is String && value.length <= 65536 ? clean(decodeHtmlEntities(value)) : '';

  /// A JSON value that may be absent: null is '', text is cleaned, anything
  /// else is api-changed.
  static String optionalText(Object? value, String what) {
    if (value == null) return '';
    if (value is! String) throw SteambroadcastFailure(SteambroadcastFailureKind.apiChanged, '$what is $value');
    return clean(value);
  }

  /// Non-empty text ([optionalText]); empty is api-changed.
  static String requiredText(Object? value, String what) {
    final text = optionalText(value, what);
    if (text.isEmpty) throw SteambroadcastFailure(SteambroadcastFailureKind.apiChanged, '$what is empty');
    return text;
  }

  /// A JSON flag: `true`, or a non-zero number.
  static bool flag(Object? value) => value == true || (value is num && value != 0);

  /// A concurrent viewer count: an integer, a finite number (truncated) or
  /// an integer text, when zero or more; null otherwise.
  static int? viewers(Object? value) {
    final parsed = switch (value) {
      final int number => number,
      final double number when number.isFinite => number.toInt(),
      final String text => int.tryParse(text.trim()),
      _ => null,
    };
    return parsed != null && parsed >= 0 ? parsed : null;
  }

  /// The first 80 characters of [body], white space collapsed, for a
  /// failure's diagnostic text.
  static String snippet(String body) {
    final text = body.trim().replaceAll(RegExp(r'\s+'), ' ');
    return text.length <= 80 ? text : '${text.substring(0, 80)}…';
  }
}
