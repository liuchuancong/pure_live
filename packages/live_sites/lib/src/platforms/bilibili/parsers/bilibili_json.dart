/// Small JSON reading helpers shared by the bilibili parsers. Every helper is
/// total: Bilibili sends numbers as strings (`"online":"1234"`), strings as
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

/// [value] as a count of zero or more (bilibili's `watched_show.num`,
/// `online`), null for a negative or an unreadable value.
int? jsonCount(Object? value) {
  final count = jsonInt(value);
  return count != null && count >= 0 ? count : null;
}

/// [value] as a JSON object: a map as it is, or one decoded from a
/// JSON-encoded string (bilibili hides the rich chat user in `info[0][15]`
/// as JSON text); null for anything else.
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

final RegExp _namedEntities = RegExp(
  '&(quot|#34|#35|#36|#37|#38|#39|#40|#41|#43|#44|#45|#46|#47|#58|#59|#60|#61|#62|#64|#96'
  '|amp|lt|gt|nbsp|mdash|ndash|hellip|middot|times|divide|copy|reg|trade|deg|plusmn|laquo|raquo'
  '|larr|rarr|uarr|darr|harr|euro|pound|yen|sect|para);',
);

const Map<String, String> _entityTable = {
  '&quot;': '"',
  '&#34;': '"',
  '&#35;': '#',
  '&#36;': r'$',
  '&#37;': '%',
  '&#38;': '&',
  '&#39;': "'",
  '&#40;': '(',
  '&#41;': ')',
  '&#43;': '+',
  '&#44;': ',',
  '&#45;': '-',
  '&#46;': '.',
  '&#47;': '/',
  '&#58;': ':',
  '&#59;': ';',
  '&#60;': '<',
  '&#61;': '=',
  '&#62;': '>',
  '&#64;': '@',
  '&#96;': '`',
  '&amp;': '&',
  '&lt;': '<',
  '&gt;': '>',
  '&nbsp;': ' ',
  '&mdash;': '—',
  '&ndash;': '–',
  '&hellip;': '…',
  '&middot;': '·',
  '&times;': '×',
  '&divide;': '÷',
  '&copy;': '©',
  '&reg;': '®',
  '&trade;': '™',
  '&deg;': '°',
  '&plusmn;': '±',
  '&laquo;': '«',
  '&raquo;': '»',
  '&larr;': '←',
  '&rarr;': '→',
  '&uarr;': '↑',
  '&darr;': '↓',
  '&harr;': '↔',
  '&euro;': '€',
  '&pound;': '£',
  '&yen;': '¥',
  '&sect;': '§',
  '&para;': '¶',
};

/// HTML entities bilibili bakes into display text (area and room titles,
/// `news_info.content`, the search highlights) and `&#123;` numeric
/// references. `&amp;` is last so a decoded `&` is never read again.
String decodeHtmlEntities(String text) {
  final named = text.replaceAllMapped(_namedEntities, (match) => _entityTable[match[0]!] ?? match[0]!);
  return named
      .replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
        final value = int.tryParse(match.group(1) ?? '');
        return value == null || value < 32 || value > 0x10FFFF ? match[0]! : String.fromCharCode(value);
      })
      .replaceAll('&amp;', '&');
}

/// A bilibili image address made absolute (`//i0.hdslb.com/…`, `http://…`):
/// https on `hdslb.com`, http left alone elsewhere; empty when there is none.
String imageUrl(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return '';
  if (text.startsWith('//')) return 'https:$text';
  final uri = Uri.tryParse(text);
  return uri != null && (uri.isScheme('http') || uri.isScheme('https')) && uri.host.isNotEmpty ? text : '';
}

/// A bilibili image address with the CDN size hint [suffix] (`@400w.jpg`).
String sizedImage(Object? value, [String suffix = '']) {
  final url = imageUrl(value);
  return url.isEmpty ? '' : '$url$suffix';
}

/// A one-line snippet of [body] for failure diagnostics (never a whole
/// payload).
String jsonSnippet(String body) {
  final text = body.trim().replaceAll(RegExp(r'\s+'), ' ');
  return text.length <= 80 ? text : '${text.substring(0, 80)}…';
}
