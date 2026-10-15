import 'dart:convert';

import 'package:live_sites/src/common/normalization/site_urls.dart';
import 'package:live_sites/src/platforms/soop/parsers/soop_failure.dart';

/// Tolerant readers of SOOP answers (3.x's `SoopApi` private helpers), and
/// the status, size and envelope gates.
abstract final class SoopJson {
  /// Maps a status other than 2xx the way 3.x's gate did: 429 throttled, 5xx
  /// a network failure, 401 and 403 a refusal, anything else (404, a
  /// redirect) an ordinary answer's shape failure.
  static void checkStatus(int status, String what) {
    if (status == 200) return;
    if (status == 429) throw SoopFailure(SoopFailureKind.rateLimited, '$what: HTTP 429');
    if (status >= 500) throw SoopFailure(SoopFailureKind.network, '$what: HTTP $status');
    if (status == 401 || status == 403) throw SoopFailure(SoopFailureKind.riskControl, '$what: HTTP $status');
    throw SoopFailure(SoopFailureKind.apiChanged, '$what: HTTP $status');
  }

  /// The status, then the 1 MiB limit in UTF-8 bytes (a UTF-16 unit is at
  /// most three bytes, so only a long text is encoded to count).
  static void checkBody(String body, String what, int status) {
    checkStatus(status, what);
    const limit = 1024 * 1024;
    if (body.length > limit || (body.length * 3 > limit && utf8.encode(body).length > limit)) {
      throw SoopFailure(SoopFailureKind.apiChanged, '$what: answer over $limit bytes');
    }
  }

  /// [body] as JSON, or null when it is not JSON.
  static Object? tryDecode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  /// The decoded JSON object of an answer (the player API and the stream
  /// manager answer JSON as `text/html`).
  static Map<String, dynamic> root(String body, {required int status, required String what}) {
    checkBody(body, what, status);
    final decoded = tryDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw SoopFailure(SoopFailureKind.apiChanged, '$what: not a JSON object (${snippet(body)})');
    }
    return decoded;
  }

  /// `data` of an `api.php` answer (`{"result": 1, "data": {…}}`); a
  /// `result` other than 1 is api-changed.
  static Map<String, dynamic> data(String body, {required int status, required String what}) {
    final parent = SoopJson.root(body, status: status, what: what);
    final result = parent['result'];
    if (result != null && integer(result) != 1) {
      throw SoopFailure(SoopFailureKind.apiChanged, '$what: result $result (${snippet(body)})');
    }
    final data = object(parent['data']);
    if (data == null) {
      throw SoopFailure(SoopFailureKind.apiChanged, '$what: no data object (${snippet(body)})');
    }
    return data;
  }

  /// An object, or null for anything else.
  static Map<String, dynamic>? object(Object? value) => value is Map<String, dynamic> ? value : null;

  /// A list field: missing is empty, anything else but a list api-changed.
  static List<Object?> listField(Object? value, String what, String body) {
    if (value == null) return const [];
    if (value is! List) {
      throw SoopFailure(SoopFailureKind.apiChanged, '$what: the list is not a list (${snippet(body)})');
    }
    return value.cast<Object?>();
  }

  /// A field as 3.x wrote it (`toString()`), empty when missing.
  static String text(Object? value) => value == null ? '' : '$value';

  /// A title or name as shown: [text] with HTML entities decoded.
  static String display(Object? value) => decodeHtmlEntities(text(value));

  /// `true`, 1, and `true`, `Y`, `yes` or `1` in any case (`is_more`,
  /// `BPWD`, `is_password`).
  static bool truthy(Object? value) => switch (value) {
    true => true,
    final num number => number == 1,
    final String text => const {'true', 'y', 'yes', '1'}.contains(text.trim().toLowerCase()),
    _ => false,
  };

  /// A trimmed non-empty string from a JSON value, or null.
  static String? string(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  /// An integer from a JSON number or integer string; null for anything
  /// else.
  static int? integer(Object? value) {
    if (value is int) return value;
    if (value is double) return value == value.truncateToDouble() ? value.toInt() : null;
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  /// A count: an integer of zero or more, else null.
  static int? count(Object? value) => switch (integer(value)) {
    final int number when number >= 0 => number,
    _ => null,
  };

  /// An http(s) URL from a JSON value, or null.
  static Uri? url(Object? value) {
    final text = string(value);
    if (text == null) return null;
    final uri = Uri.tryParse(text);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty ? uri : null;
  }

  /// An image link, made absolute ([normalizeImageUrl]).
  static String image(Object? value) => normalizeImageUrl(value is String ? value : null);

  static final RegExp _entity = RegExp('&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);');

  static const Map<String, String> _names = {
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'nbsp': ' ',
    'ensp': '\u2002',
    'emsp': '\u2003',
    'thinsp': '\u2009',
    'mdash': '—',
    'ndash': '–',
    'hellip': '…',
    'middot': '·',
    'times': '×',
    'ldquo': '“',
    'rdquo': '”',
    'lsquo': '‘',
    'rsquo': '’',
    'yen': '¥',
    'copy': '©',
    'reg': '®',
  };

  /// Decodes HTML character references (`&amp;`, `&nbsp;`, `&#39;`,
  /// `&#x1F600;`); unknown names stay as written.
  static String decodeHtmlEntities(String text) {
    if (!text.contains('&')) return text;
    return text.replaceAllMapped(_entity, (match) {
      final body = match.group(1)!;
      if (body.startsWith('#x') || body.startsWith('#X')) {
        final code = int.tryParse(body.substring(2), radix: 16);
        return code == null || code > 0x10FFFF ? match.group(0)! : String.fromCharCode(code);
      }
      if (body.startsWith('#')) {
        final code = int.tryParse(body.substring(1));
        return code == null || code > 0x10FFFF ? match.group(0)! : String.fromCharCode(code);
      }
      return _names[body] ?? match.group(0)!;
    });
  }

  /// The first line of [body], for a failure message.
  static String snippet(String body) {
    final text = body.trim().replaceAll(RegExp(r'\s+'), ' ');
    return text.length <= 80 ? text : '${text.substring(0, 80)}…';
  }
}
