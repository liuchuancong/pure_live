/// The answer readers shared by the bigo parsers: the status gate, the two
/// envelopes the site answers with (a `{code, data}` object and a JSONP
/// callback) and the strict field readers.
///
/// Bigo answers its public endpoints with typed fields — an id that is not
/// text, a `needLogin` that is not a bool, a count written with letters — and
/// the reference took each of those as the API having changed under us rather
/// than guessing. So the readers here are strict on purpose; only the places
/// the site is known to send a number as a text (or omit a field entirely) are
/// tolerant, and each one says so.
library;

import 'dart:convert';

import 'package:live_sites/src/platforms/bigo/api/bigo_endpoints.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_failure.dart';

/// The status gate of every answer: 200 is an answer, 401 and 403 are risk
/// control, 404 is not-found, 429 is rate limited and every other status —
/// a redirect included, bigo requests never follow one — is a network failure.
/// An answer over [BigoEndpoints.responseLimit] bytes has changed shape.
void checkStatus(String body, {required int status, required String what}) {
  switch (status) {
    case 200:
      break;
    case 401 || 403:
      throw BigoFailure(BigoFailureKind.riskControl, '$what: HTTP $status');
    case 404:
      throw BigoFailure(BigoFailureKind.notFound, '$what: HTTP 404');
    case 429:
      throw BigoFailure(BigoFailureKind.rateLimited, '$what: HTTP 429');
    default:
      throw BigoFailure(BigoFailureKind.network, '$what: HTTP $status');
  }
  // UTF-8 needs at most three bytes per UTF-16 unit, so a short body needs no
  // encoding.
  if (body.length > BigoEndpoints.responseLimit ||
      (body.length * 3 > BigoEndpoints.responseLimit && utf8.encode(body).length > BigoEndpoints.responseLimit)) {
    throw BigoFailure(BigoFailureKind.apiChanged, '$what: answer over ${BigoEndpoints.responseLimit} bytes');
  }
}

/// The `{code, data}` envelope: `code` the number 0 and `data` an object;
/// anything else is [BigoFailureKind.apiChanged].
Map<String, dynamic> successData(String body, {required int status, required String what}) {
  checkStatus(body, status: status, what: what);
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    throw BigoFailure(BigoFailureKind.apiChanged, '$what: not JSON (${snippet(body)})');
  }
  if (decoded is! Map<String, dynamic>) {
    throw BigoFailure(BigoFailureKind.apiChanged, '$what: not an object (${snippet(body)})');
  }
  final code = decoded['code'];
  if (code is! int || code != 0) {
    final message = decoded['msg'] is String ? ' ${decoded['msg']}' : '';
    throw BigoFailure(BigoFailureKind.apiChanged, '$what: code $code$message'.trim());
  }
  final data = decoded['data'];
  if (data is! Map<String, dynamic>) {
    throw BigoFailure(BigoFailureKind.apiChanged, '$what: data is not an object');
  }
  return data;
}

/// A JSONP answer of [callback] (`callback({...});` — the site's exact form)
/// as an object.
Map<String, dynamic> jsonpObject(String body, {required String callback, required int status, required String what}) {
  checkStatus(body, status: status, what: what);
  final prefix = '$callback(';
  final text = body.trim();
  if (text.startsWith(prefix) && text.endsWith(');')) {
    try {
      final decoded = jsonDecode(text.substring(prefix.length, text.length - 2));
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Reported below.
    }
  }
  throw BigoFailure(BigoFailureKind.apiChanged, '$what: not JSONP of $callback (${snippet(body)})');
}

/// Text of [value], or api-changed when it is not text.
String text(Object? value, String what) {
  if (value is! String) throw BigoFailure(BigoFailureKind.apiChanged, '$what is not text');
  return value;
}

/// Text of [value], empty when the field is missing (the site leaves a name or
/// a topic out of an offline studio's answer).
String optionalText(Object? value, String what) => value == null ? '' : text(value, what);

/// A whole number of at least 1 (an owner account, a `roomStatus`), or
/// api-changed.
int count(Object? value, String what) {
  if (value is! int || value < 0) throw BigoFailure(BigoFailureKind.apiChanged, '$what is $value');
  return value;
}

/// An account id: an integer 1 … 2⁵³ − 1, or api-changed.
int owner(Object? value, String what) {
  if (value is! int || value < 1 || value > 9007199254740991) {
    throw BigoFailure(BigoFailureKind.apiChanged, '$what is $value');
  }
  return value;
}

/// A 0/1 flag as a number, or api-changed.
bool binary(Object? value, String what) {
  if (value is! int || (value != 0 && value != 1)) throw BigoFailure(BigoFailureKind.apiChanged, '$what is $value');
  return value == 1;
}

/// A real JSON boolean, or api-changed (`needLogin` is never sent as a number).
bool boolean(Object? value, String what) {
  if (value is! bool) throw BigoFailure(BigoFailureKind.apiChanged, '$what is $value');
  return value;
}

/// [value] as a list, or api-changed.
List<Object?> list(Object? value, String what) {
  if (value is! List) throw BigoFailure(BigoFailureKind.apiChanged, '$what is not a list');
  return value;
}

/// [value] as an object, or api-changed.
Map<String, dynamic> object(Object? value, String what) {
  if (value is! Map<String, dynamic>) throw BigoFailure(BigoFailureKind.apiChanged, '$what is not an object');
  return value;
}

/// A picture address made strict: an http(s) URL with a host, no user info and
/// no fragment, as [Uri] writes it; '' for anything else (an offline studio's
/// empty field included).
String picture(Object? value) {
  if (value is! String || value.isEmpty) return '';
  final uri = Uri.tryParse(value);
  if (uri == null ||
      (!uri.isScheme('http') && !uri.isScheme('https')) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    return '';
  }
  return '$uri';
}

/// The media playlist of a studio: an https `.m3u8` URL with a host, no user
/// info and no fragment; api-changed otherwise.
Uri playlist(Object? value) {
  final uri = value is String ? Uri.tryParse(value) : null;
  if (uri == null ||
      !uri.isScheme('https') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      !uri.path.toLowerCase().endsWith('.m3u8')) {
    throw BigoFailure(BigoFailureKind.apiChanged, 'getInternalStudioInfo: hls_src ${snippet('$value')}');
  }
  return uri;
}

/// A one-line snippet of [body] for failure diagnostics (never a whole
/// payload).
String snippet(String body) {
  final text = body.trim().replaceAll(RegExp(r'\s+'), ' ');
  return text.length <= 80 ? text : '${text.substring(0, 80)}…';
}
