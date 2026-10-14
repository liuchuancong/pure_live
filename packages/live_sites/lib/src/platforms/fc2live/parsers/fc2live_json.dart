import 'dart:convert';

import 'package:live_sites/src/platforms/fc2live/api/fc2live_endpoints.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_failure.dart';

/// What an FC2 Live answer is worth, as the platform's own readers demand it.
///
/// The three answers are JSON made by PHP, and the site writes its numbers as
/// strings and its text with HTML character references. These readers keep
/// FC2's own strictness: a field the platform always sends as a number is a
/// failure when it is not one, while a field it sends inconsistently is read
/// leniently — the two groups are named at each use below.
abstract final class Fc2LiveJson {
  /// The failure a status carries, or null when [status] is one the endpoint
  /// answers with.
  ///
  /// 400 and 422 are the site's own "bad request" (3.x read both as a changed
  /// schema), 401 and 403 as a blocked client, 404 as no such channel and 429
  /// as a throttle; everything else — a redirect included, since these
  /// requests never follow one — says the service did not answer.
  static Fc2LiveFailure? statusFailure(int status, String what) => switch (status) {
    200 => null,
    400 || 422 => Fc2LiveFailure(Fc2LiveFailureKind.apiChanged, '$what: HTTP $status'),
    401 || 403 => Fc2LiveFailure(Fc2LiveFailureKind.riskControl, '$what: HTTP $status'),
    404 => Fc2LiveFailure(Fc2LiveFailureKind.notFound, '$what: HTTP 404'),
    429 => Fc2LiveFailure(Fc2LiveFailureKind.rateLimited, '$what: HTTP 429'),
    _ => Fc2LiveFailure(Fc2LiveFailureKind.network, '$what: HTTP $status'),
  };

  /// The decoded object of an answer: its JSON, checked for size and shape.
  /// A body of HTML, a list, a bare string or an empty text is api-changed,
  /// never an empty answer.
  static Map<String, Object?> object(String body, String what, {int status = 200}) {
    if (statusFailure(status, what) case final failure?) throw failure;
    if (body.length > Fc2LiveEndpoints.responseLimit ||
        (body.length * 3 > Fc2LiveEndpoints.responseLimit &&
            utf8.encode(body).length > Fc2LiveEndpoints.responseLimit)) {
      throw Fc2LiveFailure(
        Fc2LiveFailureKind.apiChanged,
        '$what: over ${Fc2LiveEndpoints.responseLimit ~/ (1024 * 1024)} MiB',
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw Fc2LiveFailure(Fc2LiveFailureKind.apiChanged, '$what: not JSON');
    }
    return map(decoded, what);
  }

  /// [value] as an object, or api-changed.
  static Map<String, Object?> map(Object? value, String what) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) return value.map((key, entry) => MapEntry('$key', entry));
    throw Fc2LiveFailure(Fc2LiveFailureKind.apiChanged, '$what: not an object');
  }

  /// [value] as a list, or empty when it is not one (a row reader that skips
  /// what it cannot read uses this; a must-have list is checked by the caller).
  static List<Object?> list(Object? value) => value is List ? value : const [];

  /// A number the platform means as an integer: an `int`, a finite `num`
  /// truncated, or a text of one; beyond 32 bits either way is api-changed.
  ///
  /// FC2 writes its flags and counts as strings inside JSON (`"1"`), which is
  /// why a text is accepted at all.
  static int integer(Object? value, String what) {
    final result = switch (value) {
      final int number => number,
      final num number when number.isFinite => number.toInt(),
      final String text => int.tryParse(text.trim()),
      _ => null,
    };
    if (result == null || result < -0x7fffffff || result > 0x7fffffff) {
      throw Fc2LiveFailure(Fc2LiveFailureKind.apiChanged, '$what: $value');
    }
    return result;
  }

  /// An integer with no range (a control message's `status`, which the site
  /// sends as a large code).
  static int anyInteger(Object? value, String what) {
    final result = switch (value) {
      final int number => number,
      final num number when number.isFinite => number.toInt(),
      final String text => int.tryParse(text.trim()),
      _ => null,
    };
    if (result == null) throw Fc2LiveFailure(Fc2LiveFailureKind.apiChanged, '$what: $value');
    return result;
  }

  /// An integer only when it is one, with no failure and no truncation: what a
  /// start time or a playlist row's mode needs, where a wrong type is simply
  /// "not there".
  static int? jsonInt(Object? value) => switch (value) {
    final int number => number,
    final String text => int.tryParse(text.trim()),
    _ => null,
  };

  /// A count: null when absent, null when negative, else the number. FC2 sends
  /// `0` for a channel nobody watches and once sent `-1`.
  static int? count(Object? value, String what) {
    if (value == null) return null;
    final result = integer(value, what);
    return result >= 0 ? result : null;
  }

  /// A channel category: an integer 0–99 (the site's own range, which holds
  /// numbers its area list does not name).
  static int category(Object? value, String what) {
    final result = integer(value, '$what category');
    if (result < 0 || result > 99) throw Fc2LiveFailure(Fc2LiveFailureKind.apiChanged, '$what: category $result');
    return result;
  }

  /// Text as the platform sends it: absent is empty, a non-text is api-changed,
  /// whitespace runs become one space, and over [Fc2LiveEndpoints.textLimit]
  /// characters is api-changed.
  static String text(Object? value, String what, {int limit = Fc2LiveEndpoints.textLimit}) {
    if (value == null) return '';
    if (value is! String) throw Fc2LiveFailure(Fc2LiveFailureKind.apiChanged, '$what: not a string');
    final result = value.trim().replaceAll(_spaces, ' ');
    if (result.length > limit) throw Fc2LiveFailure(Fc2LiveFailureKind.apiChanged, '$what: over $limit characters');
    return result;
  }

  static final RegExp _spaces = RegExp(r'\s+');

  /// Text as it is shown: [text] with its HTML character references decoded,
  /// then collapsed again — decoding can produce new whitespace (`a&#13;&#10;b`).
  static String displayText(Object? value, String what) {
    final first = text(value, what);
    return first.contains('&') ? text(htmlEntities(first), what) : first;
  }

  /// The first of [values] that has text, or empty.
  static String firstText(Iterable<String> values) {
    for (final value in values) {
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  /// A text that must be there: empty or over [limit] characters is api-changed
  /// (a grant's URL, token and session cookie).
  static String bounded(Object? value, int limit, String what) {
    final result = text(value, what, limit: limit);
    if (result.isEmpty || result.length > limit) {
      throw Fc2LiveFailure(Fc2LiveFailureKind.apiChanged, '$what: missing or too long');
    }
    return result;
  }

  /// A channel number as the site writes it: text that is a channel number, or
  /// api-changed.
  static String channelNumber(Object? value, String what) {
    final written = text(value, what);
    if (written.isEmpty || !Fc2LiveEndpoints.isChannelId(written)) {
      throw Fc2LiveFailure(Fc2LiveFailureKind.apiChanged, '$what: $value');
    }
    return written;
  }

  /// A value as text, or null when it has nothing in it: a channel's `userid`,
  /// which the site leaves empty for one that never existed (and once sent as a
  /// number rather than a string).
  static String? optionalId(Object? value) {
    if (value == null) return null;
    final written = value.toString().trim();
    return written.isEmpty ? null : written;
  }

  /// A broadcast start: Unix milliseconds as a UTC instant, or null for
  /// nothing, zero, a non-integer, or anything outside 2000–2100 (the site has
  /// answered `0` and once a far-future date).
  static DateTime? startTime(Object? value) {
    final milliseconds = jsonInt(value);
    if (milliseconds == null || milliseconds < _earliest || milliseconds > _latest) return null;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  }

  static const int _earliest = 946684800000;
  static const int _latest = 4102444800000;

  /// An image address the client may show: an https link on `fc2.com` or a
  /// subdomain, without user info or fragment. Anything else — a plain http
  /// link, another host, a scheme-relative one, no image at all — is empty,
  /// which never fails the room.
  static String image(Object? value) {
    final raw = text(value, 'image');
    if (raw.isEmpty) return '';
    final uri = Uri.tryParse(raw);
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !(host == 'fc2.com' || host.endsWith('.fc2.com'))) {
      return '';
    }
    return uri.toString();
  }

  /// Whether [host] is the platform's own: `live.fc2.com` or a subdomain of it
  /// (a socket node, or a media server). `live.fc2.com.evil.test` is not.
  static bool isFc2Live(String host) {
    final value = host.toLowerCase();
    return value == 'live.fc2.com' || value.endsWith('.live.fc2.com');
  }

  /// Text the site sends as HTML, shown as the page shows it: character
  /// references decoded, by name for the ones the page's own list carries and
  /// by number for `&#38;` and `&#x26;`. An unknown name or an out-of-range
  /// code is left written as it came.
  static String htmlEntities(String text) {
    if (!text.contains('&')) return text;
    return text.replaceAllMapped(_entity, (match) {
      final body = match.group(1)!;
      if (body.startsWith('#x') || body.startsWith('#X')) {
        final code = int.tryParse(body.substring(2), radix: 16);
        return code == null || code > 0x10ffff ? match.group(0)! : String.fromCharCode(code);
      }
      if (body.startsWith('#')) {
        final code = int.tryParse(body.substring(1));
        return code == null || code > 0x10ffff ? match.group(0)! : String.fromCharCode(code);
      }
      return _namedEntities[body] ?? match.group(0)!;
    });
  }

  static final RegExp _entity = RegExp(r'&(#(?:x[0-9a-fA-F]+|\d+)|[a-zA-Z][a-zA-Z0-9]{1,31});');

  /// The named references the platform's text actually carries (the site writes
  /// `&amp;`, `&lt;` and `&nbsp;` in titles and descriptions).
  static const Map<String, String> _namedEntities = {
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'nbsp': ' ',
    'ensp': ' ',
    'emsp': ' ',
    'thinsp': ' ',
    'middot': '\u{B7}',
    'bull': '\u{2022}',
    'hellip': '…',
    'mdash': '—',
    'ndash': '–',
    'minus': '\u{2212}',
    'times': '\u{D7}',
    'divide': '\u{F7}',
    'copy': '©',
    'reg': '®',
    'trade': '™',
    'deg': '°',
    'laquo': '«',
    'raquo': '»',
    'lsquo': '\u{2018}',
    'rsquo': '\u{2019}',
    'ldquo': '\u{201C}',
    'rdquo': '\u{201D}',
    'larr': '←',
    'rarr': '→',
    'uarr': '↑',
    'darr': '↓',
    'harr': '↔',
    'euro': '€',
    'pound': '£',
    'yen': '¥',
    'sect': '§',
    'para': '¶',
  };
}
