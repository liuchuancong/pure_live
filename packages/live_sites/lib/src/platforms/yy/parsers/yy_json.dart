import 'dart:convert';

import 'package:live_sites/src/common/normalization/site_urls.dart';
import 'package:live_sites/src/platforms/yy/api/yy_endpoints.dart';
import 'package:live_sites/src/platforms/yy/parsers/yy_failure.dart';

/// Tolerant readers of YY answers (3.x's private helpers of `YyApi`), and
/// the status, envelope and strictness gates. Everything here is pure.
abstract final class YyJson {
  /// The decoded JSON of [body]: HTTP 429 → rate-limited, 401/403 → risk
  /// control, 5xx → network, any other non-2xx → api-changed; a body that
  /// is not JSON is null.
  static Object? decoded(String body, {required int status, required String what}) {
    if (status == 429) {
      throw YyFailure(YyFailureKind.rateLimited, '$what: HTTP 429');
    }
    if (status == 401 || status == 403) {
      throw YyFailure(YyFailureKind.riskControl, '$what: HTTP $status');
    }
    if (status >= 500) {
      throw YyFailure(YyFailureKind.network, '$what: HTTP $status');
    }
    if (status < 200 || status >= 300) {
      throw YyFailure(YyFailureKind.apiChanged, '$what: HTTP $status (${snippet(body)})');
    }
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  /// The `{resultCode, data}` envelope of `page.action` and
  /// `liveInfoDetail`: any `resultCode` but 0, or a body that is not a JSON
  /// object, is api-changed.
  static Map<String, dynamic> checked(String body, {required int status, required String what}) {
    final root = object(decoded(body, status: status, what: what));
    if (root == null) {
      throw YyFailure(YyFailureKind.apiChanged, '$what: not a JSON object (${snippet(body)})');
    }
    final code = integer(root['resultCode']);
    if (code != 0) {
      throw YyFailure(YyFailureKind.apiChanged, '$what: resultCode $code (${snippet(body)})');
    }
    return root;
  }

  /// An HTML page's status: 429 rate-limited, 401/403 risk control, 5xx
  /// network, any other non-2xx api-changed. The room page's 404 shape
  /// (status 200 with `yycom_404`) is its parser's to tell.
  static void checkPage(int status, String what) {
    if (status == 429) {
      throw YyFailure(YyFailureKind.rateLimited, '$what: HTTP 429');
    }
    if (status == 401 || status == 403) {
      throw YyFailure(YyFailureKind.riskControl, '$what: HTTP $status');
    }
    if (status >= 500) {
      throw YyFailure(YyFailureKind.network, '$what: HTTP $status');
    }
    if (status < 200 || status >= 300) {
      throw YyFailure(YyFailureKind.apiChanged, '$what: HTTP $status');
    }
  }

  /// An object, or null when [value] is none.
  static Map<String, dynamic>? object(Object? value) => value is Map<String, dynamic> ? value : null;

  /// An object, or api-changed.
  static Map<String, dynamic> field(Object? value, String what) {
    final map = object(value);
    if (map == null) {
      throw YyFailure(YyFailureKind.apiChanged, '$what: expected an object');
    }
    return map;
  }

  /// A list, or empty when [value] is none.
  static List<Object?> list(Object? value) => value is List ? value.cast<Object?>() : const [];

  /// A string trimmed, anything else empty.
  static String text(Object? value) => value is String ? value.trim() : '';

  /// A string trimmed, or a number as its text.
  ///
  /// YY's ids arrive both ways: `page.action`, `liveInfoDetail`, the header
  /// and `getCategory` send numbers, the search sends strings. This is the
  /// reader for anything quoted-or-numbered; [text] stays for fields that
  /// are words.
  static String scalar(Object? value) => switch (value) {
    final String text => text.trim(),
    final num number => '$number',
    _ => '',
  };

  /// An int, or a string that parses as one.
  static int? integer(Object? value) => switch (value) {
    final int number => number,
    final String text => int.tryParse(text.trim()),
    _ => null,
  };

  /// A channel number: a positive decimal without leading zeros, else null.
  static String? channel(Object? value) {
    final text = YyJson.scalar(value);
    return text.isNotEmpty && YyEndpoints.isChannel(text) ? text : null;
  }

  /// A URL, or null when [value] is not one.
  static Uri? url(Object? value) => value is String && value.isNotEmpty ? Uri.tryParse(value) : null;

  /// `decodeURIComponent` without throwing: a malformed escape stays as
  /// written, malformed UTF-8 becomes U+FFFD.
  static String percentDecode(String value) {
    final bytes = <int>[];
    for (var i = 0; i < value.length; i++) {
      final byte = value[i] == '%' && i + 2 < value.length
          ? int.tryParse(value.substring(i + 1, i + 3), radix: 16)
          : null;
      if (byte != null) {
        bytes.add(byte);
        i += 2;
      } else {
        bytes.addAll(utf8.encode(value[i]));
      }
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// `liveOn` and friends: 1, true or `live`.
  static bool isLive(Object? value) {
    if (value is bool) return value;
    final state = value?.toString().trim().toLowerCase();
    return state == '1' || state == 'true' || state == 'live';
  }

  /// A broadcast's start from a list or detail `startTime` (Unix seconds);
  /// 0, negative and implausible values are none.
  static DateTime? startedAt(Object? value) => switch (integer(value)) {
    final int seconds when seconds > 0 && seconds < 100000000000 => DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000,
      isUtc: true,
    ),
    _ => null,
  };

  /// A room title without YY's default suffix: a room without a title of
  /// its own is titled `<nickname> 正在直播` (also
  /// `<nickname>正在直播`), which becomes `<nickname>`; other titles are
  /// kept as they are.
  static String title(Object? value) {
    final room = text(value);
    if (!room.endsWith(YyEndpoints.liveSuffix)) return room;
    return room.substring(0, room.length - YyEndpoints.liveSuffix.length).trim();
  }

  /// A streamer name, empty for YY's placeholder name.
  static String name(Object? value) {
    final nick = text(value);
    return nick == YyEndpoints.placeholderName ? '' : nick;
  }

  /// An image address made absolute by [normalizeImageUrl], over https
  /// (3.x's `validImgUrl`); empty when there is none.
  static String image(Object? value) => https(normalizeImageUrl(value));

  /// Protocol-relative and http addresses are served over https (3.x's
  /// `normalizeWebUrl`).
  static String https(String url) {
    final value = url.trim();
    if (value.startsWith('//')) return 'https:$value';
    if (value.startsWith('http://')) return 'https://${value.substring(7)}';
    return value;
  }

  /// [body] on one line, at most 80 characters, for a failure message.
  static String snippet(String body) {
    final line = body.trim().replaceAll(RegExp(r'\s+'), ' ');
    return line.length <= 80 ? line : '${line.substring(0, 80)}…';
  }
}
