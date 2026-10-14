/// The answer readers shared by the chzzk parsers: the `{code, message,
/// content}` envelope, the status gate and the field rules the platform forces
/// on its own answers.
///
/// Chzzk answers 200 and `code` 200 for an id it does not know (with a null
/// `channelId`), writes every `openDate` in Korean time without saying so, and
/// hides a live's viewer count behind an exposure flag — so these rules are the
/// platform's, not defaults, and each one names its source.
library;

import 'dart:convert';

import 'package:live_sites/src/platforms/chzzk/api/chzzk_endpoints.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_failure.dart';

/// Korea Standard Time, the zone of every `openDate` (no daylight saving).
const Duration _kst = Duration(hours: 9);

/// A channel id: 32 lower-case hex digits.
final RegExp _channelId = RegExp(r'^[a-f0-9]{32}$');

/// The characters that never appear in an area id the platform can route.
final RegExp _unsafeAreaId = RegExp(r'[\s/\\?#\x00-\x1f\x7f]');

/// An `openDate` as the platform writes it: Korean time, no zone marker, a
/// space or the ISO `T` between the date and the clock.
final RegExp _seoulTime = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})$');

/// The failure of a non-200 status: 400 is a changed shape, 401 and 403 are
/// risk control, 404 is not-found, 429 is rate limited, and everything else —
/// a redirect included, chzzk requests never follow one — is a network failure.
/// Null for 200.
ChzzkFailure? statusFailure(int status, String what) => switch (status) {
  200 => null,
  400 => ChzzkFailure(ChzzkFailureKind.apiChanged, '$what: HTTP 400'),
  401 || 403 => ChzzkFailure(ChzzkFailureKind.riskControl, '$what: HTTP $status'),
  404 => ChzzkFailure(ChzzkFailureKind.notFound, '$what: HTTP 404'),
  429 => ChzzkFailure(ChzzkFailureKind.rateLimited, '$what: HTTP 429'),
  _ => ChzzkFailure(ChzzkFailureKind.network, '$what: HTTP $status'),
};

/// The `content` of an API answer (null when the answer has none). A bad
/// status, a body over the size limit, a body that is not JSON, a top level
/// that is not an object or a `code` that is not 200 all throw.
Object? content(Object? body, {required String what, int status = 200}) {
  if (statusFailure(status, what) case final failure?) throw failure;
  final text = body is String ? body : '${body ?? ''}';
  if (text.length > ChzzkEndpoints.responseLimit) {
    throw ChzzkFailure(ChzzkFailureKind.apiChanged, '$what: answer over ${ChzzkEndpoints.responseLimit} characters');
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    throw ChzzkFailure(ChzzkFailureKind.apiChanged, '$what: not JSON');
  }
  if (decoded is! Map) throw ChzzkFailure(ChzzkFailureKind.apiChanged, '$what: not a JSON object');
  final code = jsonInt(decoded['code']);
  if (code != 200) {
    final message = decoded['message'] is String ? ' ${decoded['message']}' : '';
    throw ChzzkFailure(ChzzkFailureKind.apiChanged, '$what: code $code$message'.trim());
  }
  return decoded['content'];
}

/// [value] as a JSON object (a `Map` of any key type, re-keyed to text), or
/// throws [ChzzkFailureKind.apiChanged].
Map<String, dynamic> object(Object? value, String what) {
  if (value is Map) return value.map((key, entry) => MapEntry('$key', entry));
  throw ChzzkFailure(ChzzkFailureKind.apiChanged, '$what: expected an object');
}

/// [value] as a JSON object, null when it is not one (a field the platform
/// leaves out is not a changed API).
Map<String, dynamic>? optionalObject(Object? value) => value is Map ? object(value, '') : null;

/// [value] as a list, or throws [ChzzkFailureKind.apiChanged].
List<Object?> list(Object? value, String what) {
  if (value is! List) throw ChzzkFailure(ChzzkFailureKind.apiChanged, '$what: expected a list');
  return value;
}

/// [value] as a list, empty when it is not one.
List<Object?> optionalList(Object? value) => value is List ? value.cast<Object?>() : const [];

/// [value] as an int; a double only when it is integral, a string parsed.
/// A negative number keeps its sign (these readers never clamp on their own).
int? jsonInt(Object? value) => switch (value) {
  final int number => number,
  final double number when number == number.roundToDouble() && number.isFinite => number.toInt(),
  final String text => int.tryParse(text.trim()),
  _ => null,
};

/// A count: a non-negative [jsonInt], null for anything else.
int? jsonCount(Object? value) {
  final number = jsonInt(value);
  return number != null && number >= 0 ? number : null;
}

/// [value] as text, trimmed; '' for a null or a non-string (the platform sends
/// a number where it once sent text).
String text(Object? value) => value is String ? value.trim() : '';

/// Any value as its own text, trimmed; null for a null.
String? stringify(Object? value) {
  if (value == null) return null;
  final result = value.toString().trim();
  return result.isEmpty ? null : result;
}

/// A channel id: 32 lower-case hex digits, or null. The platform accepts an
/// upper-case id in a link but writes its own ids lower-case, so an answer's
/// id is checked as written.
String? channelId(Object? value) {
  final text = value is String ? value.trim() : null;
  return text != null && _channelId.hasMatch(text) ? text : null;
}

/// Whether [value] is a channel id as the platform writes it (lower case).
bool isChannelId(String value) => _channelId.hasMatch(value);

/// An area id that can go into a request path: not blank, at most 128
/// characters, no whitespace, control characters, `/`, `\`, `?` or `#`, not
/// `.` or `..`. Ids are sent path-encoded and one of them holds an `&`
/// (`Mount_&_Blade2_Bannerlord`), which the platform itself accepts.
bool isAreaId(String id) => id.isNotEmpty && id.length <= 128 && id != '.' && id != '..' && !_unsafeAreaId.hasMatch(id);

/// The name shown for a `categoryType` ([ChzzkEndpoints.categoryTypeNames],
/// else the type itself).
String categoryTypeName(String type) => ChzzkEndpoints.categoryTypeNames[type] ?? type;

/// An image as the platform's own pages accept one: https on NAVER's static
/// host or the Akamai CDN in front of it (or their subdomains), without user
/// info or fragment, at most 8 KiB; empty for anything else.
String image(Object? value) {
  if (value is! String || value.length > 8192) return '';
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.isScheme('https') || uri.userInfo.isNotEmpty || uri.hasFragment) return '';
  final host = uri.host.toLowerCase();
  final allowed =
      host == 'pstatic.net' ||
      host.endsWith('.pstatic.net') ||
      host == 'akamaized.net' ||
      host.endsWith('.akamaized.net');
  return allowed ? value : '';
}

/// A live's cover: `liveImageUrl` with its `{type}` set to the 480-width
/// variant, else `defaultThumbnailImageUrl`; empty when neither is an [image].
/// A region-locked or adult live has neither, and its card carries no cover
/// rather than a broken address.
String cover(Object? primary, Object? fallback) {
  for (final value in [primary, fallback]) {
    if (value is! String || value.isEmpty) continue;
    final url = image(value.replaceAll('{type}', '480'));
    if (url.isNotEmpty) return url;
  }
  return '';
}

/// Concurrent viewers, only when the streamer has not hidden them:
/// `concurrentUserCount` is read when `cvExposure` is true and treated as
/// unsaid when it is not (a live that hides its count still sends the number).
int? online(Map<String, dynamic> data) => data['cvExposure'] == true ? jsonCount(data['concurrentUserCount']) : null;

/// `liveCategoryValue`, or `liveCategory` when it is null; an empty value
/// stays empty (the platform sends `''` for a live with no category).
String areaName(Map<String, dynamic> data) => text(data['liveCategoryValue'] ?? data['liveCategory']);

/// A live hidden outside Korea: `krOnlyViewing`, or `blindType` `ABROAD`. A
/// list row carries only `blindType` while every such live also had
/// `krOnlyViewing` in its detail (checked 2026-09-29), so both are asked.
bool regionLocked(Map<String, dynamic> data) => data['krOnlyViewing'] == true || data['blindType'] == 'ABROAD';

/// Whether a paid product is attached to a live.
bool paid(Map<String, dynamic> data) =>
    data['paidProduct'] != null || data['paidProductId'] != null || data['watchPartyPaidProductId'] != null;

/// An `openDate` (`2026-09-27 17:52:04`) in UTC: chzzk writes Korean time
/// without saying so — the newest start of the site-wide list was four minutes
/// before the request only when read as Korean time (2026-09-29). Null when
/// missing, malformed, out of range or before 2000.
DateTime? seoulTime(Object? value) {
  final match = _seoulTime.firstMatch(stringify(value) ?? '');
  if (match == null) return null;
  final parts = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
  final local = DateTime.utc(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]);
  if (local.month != parts[1] || local.day != parts[2] || local.hour != parts[3] || local.minute != parts[4]) {
    return null;
  }
  final utc = local.subtract(_kst);
  return utc.year >= 2000 ? utc : null;
}

/// A one-line snippet of a body for failure diagnostics (never a whole
/// payload).
String snippet(String body) {
  final text = body.trim().replaceAll(RegExp(r'\s+'), ' ');
  return text.length <= 80 ? text : '${text.substring(0, 80)}…';
}
