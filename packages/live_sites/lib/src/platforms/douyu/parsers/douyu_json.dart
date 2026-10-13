/// Small JSON reading helpers shared by the douyu parsers. Every helper is
/// total: the platforms send numbers as strings, strings as numbers and
/// blanks as anything; a value that cannot be read becomes null instead of
/// throwing, and the parser decides whether that is an error.
library;

import 'dart:convert';

/// [value] as an int; numbers truncate only when integral, strings parse.
int? jsonInt(Object? value) => switch (value) {
  final num n when n.isFinite && n == n.roundToDouble() => n.toInt(),
  final String s => int.tryParse(s.trim()),
  _ => null,
};

/// [value] as trimmed text, null for null.
String? jsonString(Object? value) => value?.toString();

/// [value] as a positive count (`price`, `gfcnt`), null otherwise.
int? jsonCount(Object? value) {
  final count = jsonInt(value);
  return count != null && count > 0 ? count : null;
}

/// [value] as a http(s) URL, null for anything unparsable.
Uri? jsonUrl(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  return uri != null && (uri.isScheme('https') || uri.isScheme('http')) ? uri : null;
}

/// HTML entities a platform bakes into display text (`&mdash;`, `&amp;`).
String decodeHtmlEntities(String text) => text
    .replaceAll('&mdash;', '—')
    .replaceAll('&ndash;', '–')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&nbsp;', ' ');

/// [body] decoded as JSON, null on a malformed body.
Object? decodeJson(String body) {
  try {
    return jsonDecode(body);
  } on FormatException {
    return null;
  }
}

/// [value] as a JSON object, null for anything else.
Map<String, dynamic>? jsonObject(Object? value) => value is Map<String, dynamic> ? value : null;

/// [value] as a list, empty for anything else.
List<Object?> jsonList(Object? value) => value is List ? value.cast<Object?>() : const [];

/// A one-line snippet of [body] for failure diagnostics (never a whole
/// payload).
String jsonSnippet(String body) {
  final text = body.trim().replaceAll(RegExp(r'\s+'), ' ');
  return text.length <= 80 ? text : '${text.substring(0, 80)}…';
}

/// The visible text of an HTML error page, for diagnostics.
String htmlPageText(String body) => jsonSnippet(
  body
      .replaceAll(RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>', caseSensitive: false), ' ')
      .replaceAll(RegExp('<[^>]*>'), ' '),
);
