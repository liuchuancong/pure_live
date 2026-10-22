/// The answer readers shared by the 17LIVE parsers: the status gate, the JSON
/// envelope and the field rules the platform forces on its own answers.
///
/// 17LIVE answers an unknown room with HTTP 520 and `errorMessage`
/// `stream not found` (REG-17LIVE-004) and refuses a bad parameter with HTTP 420
/// `errorCode` 7 — neither is the ordinary 404 or 400 — so the status gate reads
/// the body as well as the code. The rules here are the platform's, not
/// defaults, and each names its source.
library;

import 'dart:convert';

import 'package:live_sites/src/platforms/seventeenlive/api/seventeenlive_endpoints.dart';
import 'package:live_sites/src/platforms/seventeenlive/parsers/seventeenlive_failure.dart';

/// The hosts the platform serves its pictures from.
const Set<String> _imageHosts = {'cdn.17app.co', 'assets-17app.akamaized.net'};

/// The characters that never appear in a bare picture path.
final RegExp _bareImage = RegExp(r'^[a-zA-Z0-9._/?=&-]+$');

/// The longest body [errorMessage] looks into (a bigger one is not read for a
/// message, only for its own failure).
const int _messageLimit = 65536;

/// The failure of an answer that is not a 200, as the reference classed it,
/// except where the platform showed otherwise: an unknown room is HTTP 520
/// `stream not found` (the reference said "service") and HTTP 420
/// `errorCode` 7 is a refused parameter (the reference took it for throttling).
/// 400 is a shape error, 401/403 a refusal of this client, 404 a missing room,
/// 429 a throttle, 5xx and anything else (a redirect included, which this
/// platform never follows by contract) a network failure. Null for 200.
SeventeenLiveFailure? statusFailure(int status, String body, String what) {
  if (status == 200) return null;
  if (errorMessage(body) == 'stream not found') {
    return SeventeenLiveFailure(SeventeenLiveFailureKind.notFound, '$what: HTTP $status stream not found');
  }
  return switch (status) {
    400 || 420 => SeventeenLiveFailure(SeventeenLiveFailureKind.apiChanged, '$what: HTTP $status'),
    401 || 403 => SeventeenLiveFailure(SeventeenLiveFailureKind.riskControl, '$what: HTTP $status'),
    404 => SeventeenLiveFailure(SeventeenLiveFailureKind.notFound, '$what: HTTP 404'),
    429 => SeventeenLiveFailure(SeventeenLiveFailureKind.rateLimited, '$what: HTTP 429'),
    _ => SeventeenLiveFailure(SeventeenLiveFailureKind.network, '$what: HTTP $status'),
  };
}

/// The `errorMessage` of a JSON body, trimmed; null when the body is too big to
/// look into, is not JSON, is not an object or names no message.
String? errorMessage(String body) {
  if (body.length > _messageLimit) return null;
  try {
    final data = jsonDecode(body);
    final message = data is Map ? data['errorMessage'] : null;
    return message is String ? message.trim() : null;
  } on FormatException {
    return null;
  }
}

/// The decoded JSON of an answer, or the failure: a bad status first, then a
/// body over [SeventeenLiveEndpoints.responseLimit], then one that is not JSON.
Object? decode(String body, {required String what, int status = 200}) {
  if (statusFailure(status, body, what) case final failure?) throw failure;
  if (body.length > SeventeenLiveEndpoints.responseLimit) {
    throw SeventeenLiveFailure(
      SeventeenLiveFailureKind.apiChanged,
      '$what: answer over ${SeventeenLiveEndpoints.responseLimit} characters',
    );
  }
  try {
    return jsonDecode(body);
  } on FormatException {
    throw SeventeenLiveFailure(SeventeenLiveFailureKind.apiChanged, '$what: not JSON');
  }
}

/// [value] as a JSON object (a `Map` of any key type, re-keyed to text), or
/// throws [SeventeenLiveFailureKind.apiChanged].
Map<String, dynamic> object(Object? value, String what) {
  if (value is Map) return value.map((key, entry) => MapEntry('$key', entry));
  throw SeventeenLiveFailure(SeventeenLiveFailureKind.apiChanged, '$what: expected an object');
}

/// [value] as a JSON object, null when it is not one (a field the platform
/// leaves out or sends in another shape is not a changed API — the caller
/// decides what that costs).
Map<String, dynamic>? optionalObject(Object? value) => value is Map ? object(value, '') : null;

/// [value] as a list, or throws [SeventeenLiveFailureKind.apiChanged].
List<Object?> list(Object? value, String what) {
  if (value is! List) throw SeventeenLiveFailure(SeventeenLiveFailureKind.apiChanged, '$what: expected a list');
  return value;
}

/// [value] as a list, empty when it is not one.
List<Object?> optionalList(Object? value) => value is List ? value.cast<Object?>() : const [];

/// [value] as an int: a JSON integer, or its text parsed (the platform writes
/// some numbers as strings). A negative number keeps its sign — these readers
/// never clamp on their own.
int? integer(Object? value) => value is int ? value : int.tryParse(value?.toString().trim() ?? '');

/// A positive number as text: what a room id or a `userInfo` id is on this
/// platform, since both are sent as integers and kept as their own digits.
String? positiveId(Object? value) {
  final number = integer(value);
  return number != null && number > 0 ? '$number' : null;
}

/// A count: a non-negative [integer], null for anything else (the lenient read
/// of a room answer; a list row asks the same field strictly).
int? count(Object? value) {
  if (value == null || value == '') return null;
  final number = integer(value);
  return number != null && number >= 0 ? number : null;
}

/// Whether [value] is a count [count] could not read: a value that is present
/// and is not a non-negative number (a list row refuses on one).
bool isBadCount(Object? value) => value != null && value != '' && count(value) == null;

/// Text as the platform's own answer gives it: absent is empty, a value that is
/// not text or is over 128 KiB cannot be read (a list row refuses on one), and
/// what is left is trimmed.
String text(Object? value) {
  if (value == null || value == '') return '';
  if (value is! String || value.length > 131072) return '';
  return value.trim();
}

/// Whether [value] is text [text] could not read: present, not a string, or too
/// long to be one.
bool isBadText(Object? value) => value != null && value != '' && (value is! String || value.length > 131072);

/// A required non-blank string, trimmed; null when it is missing, blank or over
/// 8 KiB (the platform's ids and names, which have no empty form).
String? requiredText(Object? value) {
  if (value is! String || value.trim().isEmpty || value.length > 8192) return null;
  return value.trim();
}

/// An image as the platform's own pages accept one: an http(s) URL on
/// `cdn.17app.co` or `assets-17app.akamaized.net` without user info or fragment,
/// or a bare file name there; always https. Empty for anything else.
String image(Object? value) {
  if (value is! String || value.isEmpty || value.length > 8192) return '';
  var uri = Uri.tryParse(value);
  if (uri != null && !uri.hasScheme) {
    if (value.contains('..') || !_bareImage.hasMatch(value)) return '';
    uri = Uri.https('cdn.17app.co', value.startsWith('/') ? value : '/$value');
  }
  final host = uri?.host.toLowerCase() ?? '';
  if (uri == null ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      !_imageHosts.contains(host)) {
    return '';
  }
  return uri.replace(scheme: 'https').toString();
}
