import 'dart:convert';

import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_failure.dart';

/// The hosts of the platform's image CDN.
const Set<String> kugouliveImageRoots = {'kgimg.com', 'kugou.com'};

/// Whether [host] is [root] or a subdomain of it.
bool kugouliveHostIs(String host, String root) {
  final value = host.toLowerCase();
  return value == root || value.endsWith('.$root');
}

/// Tolerant readers of Kugou Live answers, the status and size gates, and the
/// clock reads of a broadcast's start.
abstract final class KugouliveJson {
  /// The failure of an answer's status: 400/422 a broken request, 401/403
  /// refused, 451 blocked, 404/410 missing, 429 throttled, 5xx and anything
  /// else (3xx included) a network failure. Null for 2xx.
  static KugouliveFailure? statusError(int status, String what) => switch (status) {
    >= 200 && < 300 => null,
    400 || 422 => KugouliveFailure(KugouliveFailureKind.apiChanged, '$what: HTTP $status'),
    401 || 403 => KugouliveFailure(KugouliveFailureKind.riskControl, '$what: HTTP $status'),
    451 => KugouliveFailure(KugouliveFailureKind.regionBlocked, '$what: HTTP 451'),
    404 || 410 => KugouliveFailure(KugouliveFailureKind.notFound, '$what: HTTP $status'),
    429 => KugouliveFailure(KugouliveFailureKind.rateLimited, '$what: HTTP $status'),
    _ => KugouliveFailure(KugouliveFailureKind.network, '$what: HTTP $status'),
  };

  /// [body] decoded as JSON after the status and size checks.
  static Object? decode(String body, {required String what, required int status}) {
    if (statusError(status, what) case final error?) throw error;
    if (body.length > 4 * 1024 * 1024) {
      throw KugouliveFailure(KugouliveFailureKind.apiChanged, '$what: answer over the size limit');
    }
    try {
      return jsonDecode(body);
    } on FormatException {
      throw KugouliveFailure(KugouliveFailureKind.apiChanged, '$what: not JSON');
    }
  }

  /// [value] as a map with string keys, or null.
  static Map<String, Object?>? map(Object? value) =>
      value is Map ? value.map((key, value) => MapEntry('$key', value)) : null;

  /// [value] as a list, or an empty one.
  static List<Object?> list(Object? value) => value is List ? value.cast<Object?>() : const [];

  /// The root and `data` of a `{code: 0, data: {...}}` answer: another code,
  /// or an empty or missing `data`, is api-changed.
  static ({Map<String, Object?> root, Map<String, Object?> data}) answer(
    String body, {
    required String what,
    required int status,
  }) => answerOf(
    map(decode(body, what: what, status: status)),
    what: what,
  );

  /// As [answer], for an already-decoded root.
  static ({Map<String, Object?> root, Map<String, Object?> data}) answerOf(
    Map<String, Object?>? root, {
    required String what,
  }) {
    final code = integer(root?['code']);
    if (code != 0) {
      throw KugouliveFailure(KugouliveFailureKind.apiChanged, '$what: code $code ${text(root?['msg'])}'.trim());
    }
    final data = map(root!['data']);
    if (data == null || data.isEmpty) {
      throw KugouliveFailure(KugouliveFailureKind.apiChanged, '$what: no data');
    }
    return (root: root, data: data);
  }

  /// [value] as an int; numbers truncate only when integral, strings parse.
  static int? integer(Object? value) => switch (value) {
    final num n when n.isFinite && n == n.roundToDouble() => n.toInt(),
    final String s => int.tryParse(s.trim()),
    _ => null,
  };

  /// [value] as a whole number of at least 0, else null.
  static int? count(Object? value) => switch (integer(value)) {
    final int n when n >= 0 => n,
    _ => null,
  };

  /// The trimmed text of any value, `''` for null.
  static String text(Object? value) {
    final string = value is String ? value : value?.toString();
    return string == null || string == 'null' ? '' : string.trim();
  }

  /// The first of [values] with text other than `null`, else `''`.
  static String firstText(List<Object?> values) {
    for (final value in values) {
      final read = text(value);
      if (read.isNotEmpty) return read;
    }
    return '';
  }

  static final DateTime _earliest = DateTime.utc(2000);
  static final DateTime _latest = DateTime.utc(2100);

  /// How far a start may lie after the answer's own time (servers' clocks).
  static const Duration _skew = Duration(minutes: 5);

  /// [time] when it lies in 2000–2099 and (when known) not after [answered]
  /// (give or take the skew); else null.
  static DateTime? plausible(DateTime time, DateTime? answered) =>
      time.isBefore(_earliest) || !time.isBefore(_latest) || (answered != null && time.isAfter(answered.add(_skew)))
      ? null
      : time;

  /// When the platform wrote an answer: its root `times` (milliseconds; the
  /// room lists and the room info) or `time` (milliseconds in the search,
  /// seconds in the stream answer). Null without a plausible one.
  static DateTime? answeredAt(Map<String, Object?> root) {
    final value = integer(root['times'] ?? root['time']);
    if (value == null || value <= 0) return null;
    final time = DateTime.fromMillisecondsSinceEpoch(value >= 100000000000 ? value : value * 1000, isUtc: true);
    return plausible(time, null);
  }

  /// When the broadcast of [session] (the room info's `liveSessionId`)
  /// started: its first eight hex digits are the start in Unix seconds and
  /// the hex digits after `h` the broadcaster's `kugouId`. Null for another
  /// shape, a session of another [ownerId] (when given and not 0), or an
  /// implausible time.
  static DateTime? sessionStart(Object? session, {Object? ownerId, DateTime? answered}) {
    final match = RegExp(r'^([0-9a-fA-F]{8})h([0-9a-fA-F]{1,16})$').firstMatch(text(session));
    if (match == null) return null;
    final owner = integer(ownerId) ?? 0;
    if (owner != 0 && int.tryParse(match.group(2)!, radix: 16) != owner) return null;
    return unixStart(int.parse(match.group(1)!, radix: 16), answered);
  }

  /// [seconds] (Unix) as a plausible start, else null.
  static DateTime? unixStart(Object? seconds, DateTime? answered) {
    final value = integer(seconds);
    if (value == null || value <= 0) return null;
    return plausible(DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true), answered);
  }

  /// The start of a live list card: [answered] less [liveSeconds] (its
  /// `livetime`, how long the broadcast has run). Null without either.
  static DateTime? listStart(Object? liveSeconds, DateTime? answered) {
    final seconds = integer(liveSeconds);
    if (answered == null || seconds == null || seconds < 0) return null;
    return plausible(answered.subtract(Duration(seconds: seconds)), answered);
  }

  /// An image: a doubled `/v2/fxuserlogo//v2/fxuserlogo/` folded,
  /// protocol-relative made https, a root-relative path put on the image
  /// CDN, http made https; only the platform's image hosts (and subdomains)
  /// on the default ports without user info. Empty for anything else.
  static String image(Object? raw) {
    var value = text(raw);
    if (value.isEmpty) return '';
    value = value.replaceFirst('/v2/fxuserlogo//v2/fxuserlogo/', '/v2/fxuserlogo/');
    if (value.startsWith('//')) value = 'https:$value';
    if (value.startsWith('/')) value = 'https://p3.fx.kgimg.com$value';
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 80 && uri.port != 443) ||
        !(kugouliveHostIs(uri.host, 'kgimg.com') || kugouliveHostIs(uri.host, 'kugou.com'))) {
      return '';
    }
    if (uri.scheme == 'http') value = uri.replace(scheme: 'https').toString();
    return Uri.tryParse(value)?.scheme == 'https' ? value : '';
  }
}
