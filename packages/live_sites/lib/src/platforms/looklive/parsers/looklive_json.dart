import 'dart:convert';

import 'package:live_sites/src/platforms/looklive/api/looklive_endpoints.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.

/// The readers and gates of LOOK's answers (3.x's field helpers, `_post` and
/// `_checkStatus`): a status gate, the `{code, data}` envelope, and the typed
/// readers every field goes through.
abstract final class LookliveJson {
  /// 3.x's text: text trimmed, anything else ''.
  static String text(Object? value) => value is String ? value.trim() : '';

  /// 3.x's integers: an integer, or text that is one (not trimmed).
  static int? integer(Object? value) => switch (value) {
    final int number => number,
    final String text => int.tryParse(text),
    _ => null,
  };

  /// 3.x's counts: null when missing, else a non-negative integer
  /// (api-changed otherwise).
  static int? count(Object? value, String what) {
    if (value == null) return null;
    final count = integer(value);
    if (count == null || count < 0) {
      throw LookliveFailure(LookliveFailureKind.apiChanged, '$what is ${kindOf(value)}');
    }
    return count;
  }

  /// A time in epoch milliseconds (`startTime`), UTC; null when missing, zero
  /// or not a number.
  static DateTime? startedAt(Object? value) => switch (integer(value)) {
    final int ms when ms > 0 => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
    _ => null,
  };

  /// Whether `feeInfo` asks for a ticket, as LOOK's web client decides it:
  /// `fee` set (true or a non-zero number) and no `sessionKey` (a bought
  /// ticket; never for an anonymous client).
  static bool paid(Object? feeInfo) {
    if (feeInfo is! Map) return false;
    final fee = feeInfo['fee'];
    final key = feeInfo['sessionKey'];
    return (fee == true || (fee is num && fee != 0)) && (key == null || key == '');
  }

  /// 3.x's ids: a number, or text trimmed, of 1 to 19 digits not starting
  /// with 0 (api-changed otherwise).
  static String id(Object? value, String what) {
    final text = switch (value) {
      final int number => '$number',
      final String text => text.trim(),
      _ => '',
    };
    if (!_identifier.hasMatch(text)) {
      throw LookliveFailure(LookliveFailureKind.apiChanged, '$what is ${kindOf(value)}');
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

  /// 3.x's pictures: http(s) with a host, no user info, port or fragment,
  /// made https; '' for anything else.
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

  /// An answer object; anything else is api-changed.
  static Map<String, dynamic> object(Object? value, String what) {
    if (value is Map<String, dynamic>) return value;
    throw LookliveFailure(LookliveFailureKind.apiChanged, '$what is ${kindOf(value)}');
  }

  /// A short description of [value] for error details.
  static String kindOf(Object? value) => switch (value) {
    null => 'missing',
    final String text => '"${LookliveEndpoints.snippet(text)}"',
    num() || bool() => '$value',
    List() => 'a list',
    Map() => 'an object',
    _ => value.runtimeType.toString(),
  };

  /// 3.x's status mapping: 200 is an answer; 401 and 403 are risk control
  /// (3.x's "access"), 404 not-found, 429 rate-limited; 5xx and every other
  /// status (redirects included) are network failures.
  static void checkStatus(int status, {required String what}) {
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

  /// The `{code, data}` envelope (3.x's `_post`): an answer over
  /// [LookliveEndpoints.responseLimit] bytes or not a JSON object is
  /// api-changed; `code` 404 is not-found, 424, 520, 522 and 555 are risk
  /// control (3.x's "access"), anything but 200 is api-changed; `data` must
  /// be an object.
  ///
  /// For the room answer ([room]), 424 and 555 say why the room cannot be
  /// watched (LOOK's web client: 424 "暂不支持此直播，请在APP中查看", 555
  /// opens the password box of a private room), so they are
  /// stream-unavailable with that reason; 520 and 522 ("你当前无法进入直播
  /// 间") stay risk control.
  static Map<String, dynamic> data(String body, {required int status, required String what, bool room = false}) {
    checkStatus(status, what: what);
    // UTF-8 needs at most three bytes per UTF-16 unit, so short bodies need
    // no encoding.
    if (body.length > LookliveEndpoints.responseLimit ||
        (body.length * 3 > LookliveEndpoints.responseLimit &&
            utf8.encode(body).length > LookliveEndpoints.responseLimit)) {
      throw LookliveFailure(
        LookliveFailureKind.apiChanged,
        '$what: answer over ${LookliveEndpoints.responseLimit} bytes',
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw LookliveFailure(LookliveFailureKind.apiChanged, '$what: not JSON (${LookliveEndpoints.snippet(body)})');
    }
    final root = object(decoded, what);
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
        throw LookliveFailure(LookliveFailureKind.apiChanged, '$what: code ${kindOf(root['code'])} $message'.trim());
    }
  }

  static final RegExp _identifier = RegExp(r'^[1-9][0-9]{0,18}$');
}
