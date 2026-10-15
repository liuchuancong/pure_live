/// JSON reading helpers shared by the kick parsers. Every helper is total:
/// the platforms send numbers as strings, strings as numbers and blanks as
/// anything; a value that cannot be read becomes null instead of throwing,
/// and the parser decides whether that is an error.
library;

import 'dart:convert';

export 'package:live_sites/src/common/normalization/site_urls.dart' show normalizeImageUrl;

/// [value] as an int; numbers truncate only when integral, strings parse.
int? jsonInt(Object? value) => switch (value) {
  final num n when n.isFinite && n == n.roundToDouble() => n.toInt(),
  final String s => int.tryParse(s.trim()),
  _ => null,
};

/// [value] as a double, null when it is neither a number nor a decimal
/// string.
double? jsonDouble(Object? value) => switch (value) {
  final num n when n.isFinite => n.toDouble(),
  final String s => double.tryParse(s.trim()),
  _ => null,
};

/// [value] as trimmed text, null when it is null, blank or only spaces.
String? jsonString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

/// [value] as a count (`viewer_count`, `followers_count`): zero or more, so a
/// live room with no viewers reads as zero rather than unknown; null when the
/// value is missing or not a number.
int? jsonCount(Object? value) {
  final count = jsonInt(value);
  return count != null && count >= 0 ? count : null;
}

/// [body] decoded as JSON, null on a malformed body or one over
/// [maxJsonBytes] (a runaway answer is treated as unparseable, not decoded).
Object? decodeJson(String body) {
  if (body.length > maxJsonBytes) return null;
  try {
    return jsonDecode(body);
  } on FormatException {
    return null;
  }
}

/// The largest JSON answer decoded (4 MiB): a bigger body is a mistake, not a
/// page.
const int maxJsonBytes = 4 << 20;

/// [value] as a JSON object, null for anything else.
Map<String, dynamic>? jsonObject(Object? value) => value is Map<String, dynamic> ? value : null;

/// [value] as a JSON object, or the object a JSON text holds; null for
/// anything else. Pusher frames carry their event payloads as JSON strings.
Map<String, dynamic>? jsonOrText(Object? value) => switch (value) {
  final Map<String, dynamic> map => map,
  final String text when text.isNotEmpty => jsonObject(decodeJson(text)),
  _ => null,
};

/// [value] as a list, empty for anything else.
List<Object?> jsonList(Object? value) => value is List ? value.cast<Object?>() : const [];

/// A one-line snippet of [body] for failure diagnostics (never a whole
/// payload).
String jsonSnippet(String body) {
  final text = body.trim().replaceAll(RegExp(r'\s+'), ' ');
  return text.length <= 80 ? text : '${text.substring(0, 80)}…';
}

/// `2026-09-30 19:24:14` (UTC, as Kick's web API writes it) or ISO 8601 with
/// an optional `Z`/`±HH:MM` offset (converted to UTC); null when the value is
/// missing, unreadable or not a real date.
DateTime? jsonTime(Object? value) {
  final text = jsonString(value)?.trim();
  if (text == null || text.isEmpty) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(Z|[+-]\d{2}:?\d{2})?$')
      .firstMatch(text);
  if (match == null) return null;
  final parts = [for (var group = 1; group <= 6; group++) int.parse(match.group(group)!)];
  var time = DateTime.utc(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]);
  final offset = match.group(7);
  if (offset != null && offset != 'Z') {
    final digits = offset.substring(1).replaceAll(':', '');
    final minutes = int.parse(digits.substring(0, 2)) * 60 + int.parse(digits.substring(2));
    time = offset.startsWith('-') ? time.add(Duration(minutes: minutes)) : time.subtract(Duration(minutes: minutes));
  }
  return time.year == parts[0] && time.month == parts[1] && time.day == parts[2] && time.year > 2000 ? time : null;
}

/// A chat line's time: an epoch-seconds number or an ISO 8601 string; null
/// for anything else.
DateTime? jsonMessageTime(Object? value) {
  if (value is int) return value > 0 && value < 8640000000 ? DateTime.fromMillisecondsSinceEpoch(value * 1000) : null;
  return value is String ? DateTime.tryParse(value) : null;
}
