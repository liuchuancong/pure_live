import 'dart:convert';

import 'package:live_sites/src/platforms/showroom/api/showroom_endpoints.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_failure.dart';

/// Tolerant readers of SHOWROOM answers (the reference's private helpers of
/// `ShowroomApi`), and the status and envelope gates.
abstract final class ShowroomJson {
  /// The status, then the decoded JSON object of [body]: 200 is an answer;
  /// 401 and 403 are refusals, 404 not-found, 429 throttled; 5xx and every
  /// other status (redirects included: the reference did not follow them) a
  /// network failure. The answer must be a JSON object.
  static Map<String, dynamic> checked(String body, {required int status, required String what}) {
    switch (status) {
      case 200:
        break;
      case 401 || 403:
        throw ShowroomFailure(ShowroomFailureKind.riskControl, '$what: HTTP $status');
      case 404:
        throw ShowroomFailure(ShowroomFailureKind.notFound, '$what: HTTP 404');
      case 429:
        throw ShowroomFailure(ShowroomFailureKind.rateLimited, '$what: HTTP 429');
      default:
        throw ShowroomFailure(ShowroomFailureKind.network, '$what: HTTP $status');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw ShowroomFailure(ShowroomFailureKind.apiChanged, '$what: not JSON (${snippet(body)})');
    }
    return object(decoded, what);
  }

  /// An object, or api-changed.
  static Map<String, dynamic> object(Object? value, String what) {
    if (value is Map) return value.map((key, value) => MapEntry('$key', value));
    throw ShowroomFailure(ShowroomFailureKind.apiChanged, '$what: not an object');
  }

  /// A list of at most [max] items, or api-changed.
  static List<Object?> list(Object? value, String what, {required int max}) {
    if (value is! List || value.length > max) {
      throw ShowroomFailure(
        ShowroomFailureKind.apiChanged,
        '$what is ${value is List ? '${value.length} items' : 'not a list'}',
      );
    }
    return value.cast<Object?>();
  }

  /// The reference's integers: a JSON integer or an integer string.
  static int? integer(Object? value) => value is int ? value : int.tryParse(value?.toString() ?? '');

  /// A positive integer, or api-changed.
  static int positive(Object? value, String what) => switch (integer(value)) {
    final int number when number > 0 => number,
    _ => throw ShowroomFailure(ShowroomFailureKind.apiChanged, '$what is $value'),
  };

  /// A non-negative integer, or api-changed.
  static int count(Object? value, String what) => switch (integer(value)) {
    final int number when number >= 0 => number,
    _ => throw ShowroomFailure(ShowroomFailureKind.apiChanged, '$what is $value'),
  };

  /// A count the answer may leave out: null for null or ''.
  static int? optionalCount(Object? value, String what) => value == null || value == '' ? null : count(value, what);

  /// A string of at most 8192 characters, not blank, trimmed.
  static String text(Object? value, String what) {
    if (value is! String || value.trim().isEmpty || value.length > 8192) {
      throw ShowroomFailure(ShowroomFailureKind.apiChanged, '$what is $value');
    }
    return value.trim();
  }

  /// A text the answer may leave out: '' for null, else a string of at most
  /// 131072 characters, trimmed.
  static String optionalText(Object? value, String what) {
    if (value == null) return '';
    if (value is! String || value.length > 131072) {
      throw ShowroomFailure(ShowroomFailureKind.apiChanged, '$what is not text');
    }
    return value.trim();
  }

  /// A room key (`room_url_key`), or api-changed.
  static String key(Object? value, String what) {
    final text = ShowroomJson.text(value, what);
    if (!ShowroomEndpoints.keyPattern.hasMatch(text)) {
      throw ShowroomFailure(ShowroomFailureKind.apiChanged, '$what "$text" is not a room key');
    }
    return text;
  }

  /// A non-empty string, or null; trimmed.
  static String? optionalString(Object? value) => value is String && value.trim().isNotEmpty ? value.trim() : null;

  /// The reference's `_image`: an https image on a SHOWROOM host, as
  /// written; '' for anything else.
  static String image(Object? value) {
    if (value is! String || value.length > 8192) return '';
    final uri = Uri.tryParse(value);
    final host = uri?.host.toLowerCase();
    return uri != null &&
            uri.isScheme('https') &&
            uri.userInfo.isEmpty &&
            host != null &&
            ShowroomEndpoints.isTrustedHost(host)
        ? value
        : '';
  }

  /// The reference's `mediaUrl`: an https URL on a SHOWROOM host without
  /// spaces, controls, user info or fragment; api-changed otherwise.
  static String mediaUrl(Object? value, String what) {
    if (value is! String || value.length > 8192 || value.contains(RegExp(r'[\s\x00-\x1f]'))) {
      throw ShowroomFailure(ShowroomFailureKind.apiChanged, '$what: url ${snippet('$value')}');
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.isScheme('https') ||
        uri.userInfo.isNotEmpty ||
        uri.host.isEmpty ||
        uri.hasFragment ||
        !ShowroomEndpoints.isTrustedHost(uri.host.toLowerCase())) {
      throw ShowroomFailure(ShowroomFailureKind.apiChanged, '$what: url ${snippet(value)}');
    }
    return value;
  }

  /// The first words of a body, for a diagnostic.
  static String snippet(String body) {
    final text = body.trim().replaceAll(RegExp(r'\s+'), ' ');
    return text.length <= 80 ? text : '${text.substring(0, 80)}…';
  }
}
