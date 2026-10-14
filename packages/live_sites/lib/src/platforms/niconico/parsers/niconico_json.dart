/// Small JSON and HTML reading helpers shared by the niconico parsers. Every
/// helper is total: the platform sends numbers as strings, strings as
/// numbers and blanks as anything; a value that cannot be read becomes null
/// instead of throwing, and the parser decides whether that is an error.
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

/// [value] as a http(s) URL, null for anything unparsable.
Uri? jsonUrl(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  return uri != null && (uri.isScheme('https') || uri.isScheme('http')) ? uri : null;
}

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

final RegExp _numericEntity = RegExp(r'&#(?:x([0-9a-fA-F]+)|(\d+));');
final RegExp _namedEntity = RegExp('&(quot|amp|apos|lt|gt|nbsp|copy|reg|hellip|mdash|ndash|middot|bull|#34|#38);');

/// Decodes the HTML entities a watch page bakes into its `data-props` JSON
/// attribute and its display text: the five XML/HTML attribute entities the
/// attribute can carry (`&amp;`, `&lt;`, `&gt;`, `&quot;`, `&#39;`), a
/// numeric reference (decimal or hex), and the handful of named entities a
/// program's text uses. `&amp;` is resolved last so a `&quot;` written as
/// `&amp;quot;` decodes once.
String decodeHtmlEntities(String text) {
  final result = text
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAllMapped(_numericEntity, _numeric)
      .replaceAllMapped(_namedEntity, _named);
  // `&amp;` last: it is the escape of an `&` that introduced the others.
  return result.replaceAll('&amp;', '&');
}

String _numeric(Match match) {
  final hex = match.group(1);
  final code = hex != null ? int.tryParse(hex, radix: 16) : int.tryParse(match.group(2) ?? '');
  if (code == null || code <= 0 || code > 0x10FFFF) return match.group(0)!;
  return String.fromCharCode(code);
}

String _named(Match match) => switch (match.group(1)) {
  'quot' || '#34' => '"',
  'amp' || '#38' => '&',
  'apos' => "'",
  'lt' => '<',
  'gt' => '>',
  'nbsp' => ' ',
  'copy' => '©',
  'reg' => '®',
  'hellip' => '…',
  'mdash' => '—',
  'ndash' => '–',
  'middot' => '·',
  'bull' => '•',
  _ => match.group(0)!,
};
