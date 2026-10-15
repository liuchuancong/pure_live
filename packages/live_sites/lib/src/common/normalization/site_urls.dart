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
