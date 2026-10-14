/// Small JSON reading helpers shared by the youtube parsers. InnerTube sends
/// numbers as strings (`"timeoutMs":"5000"`), timestamps as microsecond strings
/// and blanks as anything; every helper here is total — a value that cannot be
/// read becomes null instead of throwing, and the parser decides whether that
/// is an error.
library;

import 'dart:convert';

/// [value] as an int; numbers truncate only when integral, strings parse.
int? jsonInt(Object? value) => switch (value) {
  final num n when n.isFinite && n == n.roundToDouble() => n.toInt(),
  final String s => int.tryParse(s.trim()),
  _ => null,
};

/// [value] as a double; numbers as they are, strings parsed.
double? jsonDouble(Object? value) => switch (value) {
  final num n when n.isFinite => n.toDouble(),
  final String s => double.tryParse(s.trim()),
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

/// true, 1 or "true" in any case: `isLive`, `isLiveNow` and the other flags
/// InnerTube sends as a bool, a number or a string depending on the endpoint.
bool truthy(Object? value) => value == true || value == 1 || (value is String && value.trim().toLowerCase() == 'true');

/// A one-line snippet of [body] for failure diagnostics (never a whole
/// payload).
String jsonSnippet(String body) {
  final collapsed = body.trim().replaceAll(RegExp(r'\s+'), ' ');
  return collapsed.length <= 80 ? collapsed : '${collapsed.substring(0, 80)}…';
}

/// An image address made absolute (`//i.ytimg.com/…`, `http://…`); empty when
/// there is none or it is not http(s).
String imageUrl(Object? value) {
  final address = value?.toString().trim() ?? '';
  if (address.isEmpty) return '';
  if (address.startsWith('//')) return 'https:$address';
  final uri = Uri.tryParse(address);
  return uri != null && (uri.isScheme('http') || uri.isScheme('https')) && uri.host.isNotEmpty ? address : '';
}

/// The text of an InnerTube label: `{simpleText: "…"}`, `{runs: […], …}`, a
/// bare accessibility `{accessibility: {accessibilityText: "…"}}`, or a plain
/// string; the concatenation of a run's `text` fields, emojis contributing
/// nothing.
String label(Object? value) {
  final map = jsonObject(value);
  if (map == null) return value is String ? value.trim() : '';
  final simple = map['simpleText'];
  if (simple is String) return simple.trim();
  final runs = map['runs'];
  if (runs is List) {
    final buffer = StringBuffer();
    for (final run in runs) {
      final part = jsonObject(run)?['text'];
      if (part is String) buffer.write(part);
    }
    return buffer.toString().trim();
  }
  final accessibility = jsonObject(jsonObject(map['accessibility'])?['accessibilityData'])?['label'];
  if (accessibility is String) return accessibility.trim();
  return '';
}

/// The first value stored under [key] anywhere in [node], searched
/// depth-first; null when the key is absent. InnerTube's renderers sit under
/// paths that shift between responses (`contents.twoColumnWatchNextResults…`,
/// `engagementPanels…`), so the parsers look a renderer up by name rather
/// than by a fixed path.
Object? findFirst(Object? node, String key) {
  if (node is Map) {
    final direct = node[key];
    if (direct != null) return direct;
    for (final value in node.values) {
      final found = findFirst(value, key);
      if (found != null) return found;
    }
  } else if (node is List) {
    for (final value in node) {
      final found = findFirst(value, key);
      if (found != null) return found;
    }
  }
  return null;
}

/// The URL of the last (highest-resolution) thumbnail of an InnerTube
/// `{thumbnails: [{url}]}` object, made absolute; empty when there is none.
String lastThumbnail(Object? node) {
  final list = jsonList(jsonObject(node)?['thumbnails']);
  for (final entry in list.reversed) {
    final url = imageUrl(jsonObject(entry)?['url']);
    if (url.isNotEmpty) return url;
  }
  return '';
}

/// The `url` of a single thumbnail entry, else the last of a `{thumbnails}`
/// wrapper; empty when neither names an address.
String thumbnailUrl(Object? node) {
  final direct = imageUrl(jsonObject(node)?['url']);
  if (direct.isNotEmpty) return direct;
  return lastThumbnail(node);
}
