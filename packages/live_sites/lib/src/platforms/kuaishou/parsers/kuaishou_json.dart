/// Small JSON reading helpers shared by the kuaishou parsers. Every helper is
/// total: Kuaishou sends numbers as strings (`"id":"123"`), text as numbers
/// and blanks as anything; a value that cannot be read becomes null instead
/// of throwing, and the parser decides whether that is an error.
library;

import 'dart:convert';

/// [value] as an int; numbers truncate only when integral, strings parse.
int? jsonInt(Object? value) => switch (value) {
  final num n when n.isFinite && n == n.roundToDouble() => n.toInt(),
  final String s => int.tryParse(s.trim()),
  _ => null,
};

/// [value] as text, null for null (numbers become their digits, tolerant of
/// the platform's numeric-as-string ids).
String? jsonString(Object? value) => value?.toString();

/// [value] as a JSON object: a map as it is, or one decoded from a
/// JSON-encoded string; null for anything else.
Map<String, dynamic>? jsonObject(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, entry) => MapEntry('$key', entry));
  if (value is String && value.trimLeft().startsWith('{')) {
    final decoded = decodeJson(value);
    return decoded is Map<String, dynamic> ? decoded : null;
  }
  return null;
}

/// An object field, or an empty one: a missing field reads as empty.
Map<String, dynamic> fields(Object? value) => jsonObject(value) ?? const <String, dynamic>{};

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

/// A field as text (the platform's own spelling), empty when missing.
String text(Object? value) => value == null ? '' : '$value';

/// true, 1 or "true" in any case: `isLiving` and the other flags Kuaishou
/// sends as a number, a string or a bool depending on the endpoint.
bool truthy(Object? value) => value == true || value == 1 || (value is String && value.trim().toLowerCase() == 'true');

/// An image address made absolute (`//ali2.a.yximgs.com/…`, `http://…`); empty
/// when there is none or it is not http(s).
String imageUrl(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return '';
  if (text.startsWith('//')) return 'https:$text';
  final uri = Uri.tryParse(text);
  return uri != null && (uri.isScheme('http') || uri.isScheme('https')) && uri.host.isNotEmpty ? text : '';
}

/// A one-line snippet of [body] for failure diagnostics (never a whole
/// payload).
String jsonSnippet(String body) {
  final text = body.trim().replaceAll(RegExp(r'\s+'), ' ');
  return text.length <= 80 ? text : '${text.substring(0, 80)}…';
}
