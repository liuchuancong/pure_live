import 'dart:convert';

import 'package:live_sites/src/platforms/looklive/api/looklive_endpoints.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_failure.dart';

/// Tolerant readers of LOOK Live answers (3.x's private helpers of
/// `LookLiveApi`), and the status, size and `{code, data}` envelope gates.
abstract final class LookliveJson {
  /// Maps a status other than 200: 401 and 403 a refusal, 404 not-found, 429
  /// throttled, anything else (5xx, a redirect) a network failure.
  static void checkStatus(int status, String what) {
    switch (status) {
      case 200:
        return;
      case 401 || 403:
        throw LookliveFailure(LookliveFailureKind.riskControl, '$what: HTTP $status');
      case 404:
        throw LookliveFailure(LookliveFailureKind.notFound, '$what: HTTP 404');
      case 429:
        throw LookliveFailure(LookliveFailureKind.rateLimited, '$what: HTTP 429');
      default:
        throw LookliveFailure(LookliveFailureKind.network, '$what: HTTP $status');
    }
  }

  /// The status, then the [LookliveEndpoints.responseLimit] in UTF-8 bytes (a
  /// UTF-16 unit is at most three bytes, so only a long text is encoded to
  /// count).
  static void checkBody(String body, String what, int status) {
    checkStatus(status, what);
    const limit = LookliveEndpoints.responseLimit;
    if (body.length > limit || (body.length * 3 > limit && utf8.encode(body).length > limit)) {
      throw LookliveFailure(LookliveFailureKind.apiChanged, '$what: answer over $limit bytes');
    }
  }

  /// The decoded JSON object of [body], or api-changed.
  static Map<String, dynamic> json(String body, String what, int status) {
    checkBody(body, what, status);
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw LookliveFailure(LookliveFailureKind.apiChanged, '$what: not JSON (${snippet(body)})');
    }
    return object(decoded, what);
  }

  /// The `{code, data}` envelope (3.x's `_post`): an answer over
  /// [LookliveEndpoints.responseLimit] bytes or not a JSON object is
  /// api-changed; `code` 404 is not-found, 424, 520, 522 and 555 are
  /// refusals, anything but 200 api-changed; `data` must be an object.
  ///
  /// For the room answer, [room] tells 424 and 555 apart: they say why the
  /// room cannot be watched (424 "暂不支持此直播，请在APP中查看", 555 the
  /// password box of a private room), so they are stream-unavailable with
  /// that reason; 520 and 522 ("你当前无法进入直播间") stay refusals.
  static Map<String, dynamic> data(String body, {required int status, required String what, bool room = false}) {
    final root = json(body, what, status);
    final code = integer(root['code']);
    final message = text(root['message']);
    switch (code) {
      case 200:
        return object(root['data'], '$what data');
      case 404:
        throw LookliveFailure(LookliveFailureKind.notFound, '$what: code 404 $message'.trim());
      case 424 when room:
        throw LookliveFailure(
          LookliveFailureKind.streamUnavailable,
          '$what: code 424, watchable in the LOOK app only $message'.trim(),
        );
      case 555 when room:
        throw LookliveFailure(
          LookliveFailureKind.streamUnavailable,
          '$what: code 555, a private room with a password $message'.trim(),
        );
      case 424 || 520 || 522 || 555:
        throw LookliveFailure(LookliveFailureKind.riskControl, '$what: code $code $message'.trim());
      default:
        throw LookliveFailure(LookliveFailureKind.apiChanged, '$what: code ${describe(root['code'])} $message'.trim());
    }
  }

  /// An object, or api-changed.
  static Map<String, dynamic> object(Object? value, String what) {
    if (value is Map<String, dynamic>) return value;
    throw LookliveFailure(LookliveFailureKind.apiChanged, '$what is ${describe(value)}');
  }

  /// Text trimmed, anything else ''.
  static String text(Object? value) => value is String ? value.trim() : '';

  /// An integer, or text that parses as one (not trimmed).
  static int? integer(Object? value) => switch (value) {
    final int number => number,
    final String text => int.tryParse(text),
    _ => null,
  };

  /// A count: null when missing, else a non-negative integer (api-changed
  /// otherwise).
  static int? count(Object? value, String what) {
    if (value == null) return null;
    final count = integer(value);
    if (count == null || count < 0) {
      throw LookliveFailure(LookliveFailureKind.apiChanged, '$what is ${describe(value)}');
    }
    return count;
  }

  /// A time in epoch milliseconds (`startTime`), UTC; null when missing, zero
  /// or not a number.
  static DateTime? time(Object? value) => switch (integer(value)) {
    final int ms when ms > 0 => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
    _ => null,
  };

  /// Whether `feeInfo` asks for a ticket, as the web client decides it:
  /// `fee` set (true or a non-zero number) and no `sessionKey` (a bought
  /// ticket; never for an anonymous client).
  static bool paid(Object? feeInfo) {
    if (feeInfo is! Map) return false;
    final fee = feeInfo['fee'];
    final key = feeInfo['sessionKey'];
    return (fee == true || (fee is num && fee != 0)) && (key == null || key == '');
  }

  /// An id: a number, or text trimmed, of 1 to 19 digits not starting with 0
  /// (api-changed otherwise).
  static String id(Object? value, String what) {
    final text = switch (value) {
      final int number => '$number',
      final String text => text.trim(),
      _ => '',
    };
    if (!_identifier.hasMatch(text)) {
      throw LookliveFailure(LookliveFailureKind.apiChanged, '$what is ${describe(value)}');
    }
    return text;
  }

  /// An id as [id] reads it, or '' when missing or not one (the chatroom,
  /// which only the chat needs).
  static String optionalId(Object? value) {
    final text = switch (value) {
      final int number => '$number',
      final String text => text.trim(),
      _ => '',
    };
    return _identifier.hasMatch(text) ? text : '';
  }

  /// A picture: http(s) with a host, no user info, port or fragment, made
  /// https; '' for anything else.
  static String picture(Object? value) {
    final uri = Uri.tryParse(text(value));
    if (uri == null ||
        (!uri.isScheme('http') && !uri.isScheme('https')) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.fragment.isNotEmpty) {
      return '';
    }
    return uri.replace(scheme: 'https').toString();
  }

  /// A short description of [value] for error details.
  static String describe(Object? value) => switch (value) {
    null => 'missing',
    final String text => '"${snippet(text)}"',
    num() || bool() => '$value',
    List() => 'a list',
    Map() => 'an object',
    _ => value.runtimeType.toString(),
  };

  /// [body] trimmed of its extra whitespace, cut for an error detail.
  static String snippet(String body) {
    final text = body.trim().replaceAll(RegExp(r'\s+'), ' ');
    return text.length <= 80 ? text : '${text.substring(0, 80)}…';
  }

  static final RegExp _identifier = RegExp(r'^[1-9][0-9]{0,18}$');
}
