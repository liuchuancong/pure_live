import 'dart:convert';

import 'package:live_sites/src/common/normalization/html_entities.dart';
import 'package:live_sites/src/platforms/weibo/api/weibo_endpoints.dart';
import 'package:live_sites/src/platforms/weibo/parsers/weibo_failure.dart';

/// Tolerant readers of Weibo answers (the reference's private helpers of
/// `WeiboApi`), and the envelope, status, size and field gates.
abstract final class WeiboJson {
  /// Maps a status other than 200: 401 and 403 a refusal, 404 not-found, 429
  /// throttled, anything else (5xx, a redirect) a network failure (the
  /// reference read no body then).
  static void checkStatus(int status, String what) {
    switch (status) {
      case 200:
        return;
      case 401 || 403:
        throw WeiboFailure(WeiboFailureKind.riskControl, '$what: HTTP $status');
      case 404:
        throw WeiboFailure(WeiboFailureKind.notFound, '$what: HTTP 404');
      case 429:
        throw WeiboFailure(WeiboFailureKind.rateLimited, '$what: HTTP 429');
      default:
        throw WeiboFailure(WeiboFailureKind.network, '$what: HTTP $status');
    }
  }

  /// The `data` of an answer. A status other than 200 fails as [checkStatus]
  /// says. A body over [WeiboEndpoints.responseLimit], not a JSON object,
  /// without integer `code` and `error_code`, or whose `data` is not an object
  /// is api-changed; so is any code but 100000/0, except
  /// [WeiboEndpoints.missingCode] when [missing] (the detail), which is
  /// not-found.
  static Map<String, dynamic> data(String body, {required String what, int status = 200, bool missing = false}) {
    checkStatus(status, what);
    // A UTF-16 unit is at most three UTF-8 bytes: short bodies are not
    // encoded to be counted.
    const limit = WeiboEndpoints.responseLimit;
    if (body.length > limit || (body.length * 3 > limit && utf8.encode(body).length > limit)) {
      throw WeiboFailure(WeiboFailureKind.apiChanged, '$what: answer over $limit bytes');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw WeiboFailure(WeiboFailureKind.apiChanged, '$what: not JSON');
    }
    final root = object(decoded, what);
    final code = count(root['code'], '$what.code');
    final error = count(root['error_code'], '$what.error_code');
    final msg = root['msg'] is String ? root['msg'] as String : null;
    if (missing && error == WeiboEndpoints.missingCode) {
      throw WeiboFailure(WeiboFailureKind.notFound, '$what: ${msg ?? error}');
    }
    if (code != WeiboEndpoints.okCode || error != 0) {
      throw WeiboFailure(WeiboFailureKind.apiChanged, '$what: code $code error_code $error ${msg ?? ''}');
    }
    return object(root['data'], '$what.data');
  }

  /// An object, or api-changed.
  static Map<String, dynamic> object(Object? value, String what) {
    if (value is Map<String, dynamic>) return value;
    throw WeiboFailure(WeiboFailureKind.apiChanged, '$what: expected an object');
  }

  /// A display text (title, nickname): a string with HTML character
  /// references decoded (18-7), empty for anything else (18-8; the reference
  /// failed the row).
  static String text(Object? value) => value is String ? decodeHtmlEntities(value) : '';

  /// An integer of zero or more, or api-changed (the reference's `_number`).
  static int count(Object? value, String what) {
    if (value is int && value >= 0) return value;
    throw WeiboFailure(WeiboFailureKind.apiChanged, '$what: $value');
  }

  /// A 0/1 flag, or api-changed (the reference's `_binary`).
  static int flag(Object? value, String what) {
    final flag = count(value, what);
    if (flag > 1) throw WeiboFailure(WeiboFailureKind.apiChanged, '$what: $value');
    return flag;
  }

  /// A positive integer below 2^53, or null (the reference's owner uid).
  static int? uidOrNull(Object? value) => value is int && value >= 1 && value <= 9007199254740991 ? value : null;

  /// [uidOrNull], required: api-changed when the value is no owner uid.
  static int uid(Object? value, String what) =>
      uidOrNull(value) ?? (throw WeiboFailure(WeiboFailureKind.apiChanged, '$what: $value'));

  /// A broadcast id as the answer wrote it, or api-changed.
  static String liveId(Object? value, String what) {
    if (value is String && WeiboEndpoints.isLiveId(value)) return value;
    throw WeiboFailure(WeiboFailureKind.apiChanged, '$what: $value');
  }

  /// A media address (the reference's `_url`): plain http(s) with a host, as
  /// written, without spaces, backslashes, user info or a fragment; null for
  /// anything else, an empty string included (18-8: a bad address only drops
  /// that line; the reference failed the room).
  static String? mediaUrl(Object? value) {
    if (value is! String || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (value.trim() != value ||
        RegExp(r'[\\\s]').hasMatch(value) ||
        uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      return null;
    }
    return value;
  }

  /// A replay's recording ([mediaUrl]) made https, as the web player does (the
  /// replay CDN answers https, checked 2026-09-28).
  static String? replayUrl(Object? value) => switch (mediaUrl(value)) {
    final String url when url.toLowerCase().startsWith('http:') => 'https${url.substring('http'.length)}',
    final url => url,
  };

  /// A start from epoch milliseconds (`startTime`); null for anything that is
  /// not a time after 2001 and before 2286 (the platform writes 0 when there
  /// is none).
  static DateTime? startedAt(Object? value) => switch (value) {
    final int milliseconds when milliseconds >= 1000000000000 && milliseconds < 10000000000000 =>
      DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true),
    _ => null,
  };
}
