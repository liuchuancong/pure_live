/// An image link as platforms return them, made absolute: surrounding quotes
/// removed, protocol-relative `//…` and a bare `host/path` made https, empty
/// for null (the string), blanks and anything that is not a web address.
///
/// Two platforms are on record (kick, kilakila); kick's parser delegates here.
String normalizeImageUrl(Object? source) {
  var value = source is String ? source.trim() : '';
  if (value.isEmpty || value.toLowerCase() == 'null') return '';
  if (value.length >= 2 &&
      ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'")))) {
    value = value.substring(1, value.length - 1).trim();
  }
  if (value.isEmpty) return '';
  if (value.startsWith('//')) return 'https:$value';
  final uri = Uri.tryParse(value);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty) return value;
  if (!value.contains(' ') && RegExp(r'^[\w.-]+\.[a-zA-Z]{2,}([/:?#]|$)').hasMatch(value)) return 'https://$value';
  return '';
}

/// A play address as the platforms return it, made absolute where the form
/// is irregular but decidable:
///
/// - quoted JSON strings and JSON-escaped slashes (`https:\/\/…`);
/// - HTML entities (`&amp;`) and surrounding whitespace;
/// - protocol-relative `//host/…`;
/// - a single-slash scheme (`http:/host`, `https:/host`) or an extra slash;
/// - a bare `host/path`;
/// - a root-relative `/path` against [base], when the caller has the room's
///   web address to resolve it against.
///
/// Other schemes (`rtmp`, `rtsp`, …) and anything not decidable are left as
/// written; the player, not this helper, decides what it can open.
String normalizePlayUrl(Object? source, {Uri? base}) {
  var value = source is String ? source.trim() : '';
  if (value.isEmpty || value.toLowerCase() == 'null') return '';
  if (value.length >= 2 &&
      ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'")))) {
    value = value.substring(1, value.length - 1).trim();
  }
  value = value.replaceAll(r'\/', '/').replaceAll('&amp;', '&').trim();
  if (value.isEmpty) return '';
  if (value.startsWith('//')) return 'https:$value';
  final singleSlash = RegExp('^(https?):/(?!/)').firstMatch(value);
  if (singleSlash != null) {
    return '${singleSlash[1]}://${value.substring(singleSlash.end)}';
  }
  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme && uri.host.isNotEmpty) return value;
  if (value.startsWith('/')) {
    return base == null ? value : base.resolve(value).toString();
  }
  if (!value.contains(' ') && RegExp(r'^[\w.-]+\.[a-zA-Z]{2,}([/:?#]|$)').hasMatch(value)) {
    return 'https://$value';
  }
  return value;
}
