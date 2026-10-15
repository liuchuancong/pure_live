import 'dart:convert';

import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_failure.dart';

/// Tolerant readers of Xiaohongshu share pages (3.x's private helpers of
/// `XiaohongshuApi`), and the status gate.
abstract final class XiaohongshuJson {
  /// Maps a status other than 200: 401, 403 and 406 the site's risk control,
  /// 404 not-found, 429 throttled, anything else (5xx, a redirect: the page
  /// must be the one asked for) a network failure.
  static void checkStatus(int status, String what) {
    switch (status) {
      case 200:
        return;
      case 401 || 403 || 406:
        throw XiaohongshuFailure(XiaohongshuFailureKind.riskControl, '$what: HTTP $status');
      case 404:
        throw XiaohongshuFailure(XiaohongshuFailureKind.notFound, '$what: HTTP 404');
      case 429:
        throw XiaohongshuFailure(XiaohongshuFailureKind.rateLimited, '$what: HTTP 429');
      default:
        throw XiaohongshuFailure(XiaohongshuFailureKind.network, '$what: HTTP $status');
    }
  }

  /// An object, or api-changed.
  static Map<String, dynamic> object(Object? value, String what) {
    if (value is Map<String, dynamic>) return value;
    throw XiaohongshuFailure(XiaohongshuFailureKind.apiChanged, '$what is not an object');
  }

  /// A string of at most [limit] characters, or null when absent; anything
  /// else is api-changed (3.x).
  static String? text(Object? value, String what, {int limit = 4096}) {
    if (value == null) return null;
    if (value is! String || value.length > limit) {
      throw XiaohongshuFailure(XiaohongshuFailureKind.apiChanged, '$what is not a short text');
    }
    return value;
  }

  /// A count 3.x read as a JSON integer of zero or more; the same integer
  /// written as a string is accepted too.
  static int? count(Object? value) => switch (value) {
    final int number when number >= 0 => number,
    final String text => RegExp(r'^\d{1,9}$').hasMatch(text.trim()) ? int.parse(text.trim()) : null,
    _ => null,
  };

  /// [text] decoded, or null when it is not JSON.
  static Object? decodeOrNull(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }
}
