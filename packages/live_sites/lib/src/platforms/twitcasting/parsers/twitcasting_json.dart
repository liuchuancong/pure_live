import 'dart:convert';

import 'package:live_sites/src/common/normalization/site_urls.dart';
import 'package:live_sites/src/platforms/twitcasting/parsers/twitcasting_failure.dart';

/// Tolerant readers of TwitCasting answers (3.x's private helpers of
/// `TwitcastingApi`), and the status gate.
abstract final class TwitcastingJson {
  /// Maps a status other than 200: 401 and 403 a refusal, 404 not-found, 429
  /// throttled, anything else (5xx, a redirect) a network failure. A channel
  /// page handles its redirect itself, before this gate.
  static void checkStatus(int status, String what) {
    switch (status) {
      case 200:
        return;
      case 401 || 403:
        throw TwitcastingFailure(TwitcastingFailureKind.riskControl, '$what: HTTP $status');
      case 404:
        throw TwitcastingFailure(TwitcastingFailureKind.notFound, '$what: HTTP 404');
      case 429:
        throw TwitcastingFailure(TwitcastingFailureKind.rateLimited, '$what: HTTP 429');
      default:
        throw TwitcastingFailure(TwitcastingFailureKind.network, '$what: HTTP $status');
    }
  }

  /// The decoded JSON of [body], or api-changed.
  static Object? decode(String body, String what) {
    try {
      return jsonDecode(body);
    } on FormatException {
      throw TwitcastingFailure(TwitcastingFailureKind.apiChanged, '$what: not JSON');
    }
  }

  /// An object with string keys, or api-changed.
  static Map<String, dynamic> object(Object? value, String what) {
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw TwitcastingFailure(TwitcastingFailureKind.apiChanged, '$what: not an object');
    }
    return value.cast<String, dynamic>();
  }

  /// A string trimmed, anything else empty (3.x's `text`).
  static String text(Object? value) => value is String ? value.trim() : '';

  /// An int, or a string of one (3.x's `integer`).
  static int? integer(Object? value) => value is int ? value : (value is String ? int.tryParse(value) : null);

  /// The decoded path segments of [uri] joined by `/`; null when a segment
  /// does not decode.
  static String? segments(Uri uri) {
    try {
      return uri.pathSegments.join('/');
    } on FormatException {
      return null;
    }
  }

  /// An image address, made absolute; empty for anything else.
  static String picture(Object? value) => normalizeImageUrl(value is String ? value : null);
}
