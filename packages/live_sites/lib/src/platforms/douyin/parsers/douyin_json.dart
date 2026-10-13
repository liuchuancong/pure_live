/// Small JSON reading helpers shared by the douyin parsers. Every helper is
/// total: Douyin sends numbers as strings, strings as numbers, objects as
/// JSON-encoded strings (`lives.rawdata`) and blanks as anything; a value
/// that cannot be read becomes null instead of throwing, and the parser
/// decides whether that is an error.
library;

import 'dart:convert';

/// [value] as an int; numbers truncate only when integral, strings parse.
int? jsonInt(Object? value) => switch (value) {
  final num n when n.isFinite && n == n.roundToDouble() => n.toInt(),
  final String s => int.tryParse(s.trim()),
  _ => null,
};

/// [value] as a JSON object: a map as it is, or an object decoded from a
/// JSON-encoded string (Douyin nests whole answers as strings in its search
/// cards); null for anything else.
Map<String, dynamic>? jsonObject(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, entry) => MapEntry('$key', entry));
  if (value is String && value.trimLeft().startsWith('{')) {
    final decoded = decodeJson(value);
    return decoded is Map<String, dynamic> ? decoded : null;
  }
  return null;
}

/// [value] as a list, empty for anything else.
List<Object?> jsonList(Object? value) => value is List ? value.cast<Object?>() : const [];

/// [body] decoded as JSON, null on a malformed body.
Object? decodeJson(String body) {
  try {
    return jsonDecode(body);
  } on FormatException {
    return null;
  }
}

/// A trimmed non-empty text that is neither a map, a list nor `null`.
String? jsonText(Object? value) {
  if (value == null || value is Map || value is Iterable) return null;
  final text = value.toString().trim();
  return text.isEmpty || text == 'null' ? null : text;
}

/// The first [values] entry readable as text.
String? jsonFirstText(Iterable<Object?> values) {
  for (final value in values) {
    final text = jsonText(value);
    if (text != null) return text;
  }
  return null;
}

/// The first [values] entry usable as an id (`0`, `undefined`, `NaN` and
/// `none` are placeholders, not identities).
String? jsonFirstId(Iterable<Object?> values) {
  for (final value in values) {
    final text = jsonText(value);
    if (text != null && !const {'0', 'undefined', 'nan', 'none'}.contains(text.toLowerCase())) return text;
  }
  return null;
}

/// A digit-only web_rid (a string or an integer); null for anything else.
String? jsonWebRid(Object? value) {
  if (value is! String && value is! int) return null;
  final text = '$value'.trim();
  return RegExp(r'^\d+$').hasMatch(text) ? text : null;
}

/// [map]'s value under [key], falling back to the key matched
/// case-insensitively (Douyin's sdk keys are `ORIGION` in one field and
/// `origin` in another; the maps are joined by key, never by position).
Object? jsonLookup(Map<String, dynamic> map, String key) {
  final direct = map[key];
  if (direct != null) return direct;
  for (final entry in map.entries) {
    if (entry.key.toLowerCase() == key) return entry.value;
  }
  return null;
}

/// The first image address of [candidates]: the first entry of a `url_list`,
/// or a direct http(s) URL, made absolute; empty when none reads.
String jsonFirstImage(Iterable<Object?> candidates) {
  for (final value in candidates) {
    final list = jsonObject(value)?['url_list'];
    if (list is List) {
      final url = jsonFirstText(list);
      if (url != null) return absoluteImageUrl(url);
    }
    final direct = jsonText(value);
    if (direct != null && (direct.startsWith('http://') || direct.startsWith('https://'))) return direct;
  }
  return '';
}

/// An image address: absolute as it is (`//` completed to https), else empty.
String absoluteImageUrl(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return '';
  return text.startsWith('//') ? 'https:$text' : text;
}

/// A time in Unix seconds; null for 0 (Douyin's placeholder), negatives,
/// values too large to be seconds and anything that is not an integer.
DateTime? epochSeconds(Object? value) => switch (jsonInt(value)) {
  final int seconds when seconds > 0 && seconds < 100000000000 => DateTime.fromMillisecondsSinceEpoch(
    seconds * 1000,
    isUtc: true,
  ),
  _ => null,
};

/// A one-line snippet of [body] for failure diagnostics (never a whole
/// payload).
String jsonSnippet(String body) {
  final text = body.trim().replaceAll(RegExp(r'\s+'), ' ');
  return text.length <= 80 ? text : '${text.substring(0, 80)}…';
}

/// The visible text of an HTML page, for diagnostics.
String pageText(String body) => jsonSnippet(
  body
      .replaceAll(RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>', caseSensitive: false), ' ')
      .replaceAll(RegExp('<[^>]*>'), ' '),
);
