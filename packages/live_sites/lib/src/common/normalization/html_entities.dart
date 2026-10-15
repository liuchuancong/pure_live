/// Decodes the character references of an HTML text or attribute value (the
/// common named ones, and the numeric forms); the text itself where nothing
/// matches.
///
/// Two platforms are on record (kilakila's search page, kugoulive's home
/// page); kilakila's HTML reader delegates here.
String decodeHtmlEntities(String text) {
  if (!text.contains('&')) return text;
  return text.replaceAllMapped(_entity, (match) {
    final named = _names[match.group(1)];
    if (named != null) return named;
    final numeric = match.group(2);
    if (numeric != null) {
      final code = numeric.startsWith('x') || numeric.startsWith('X')
          ? int.tryParse(numeric.substring(1), radix: 16)
          : int.tryParse(numeric);
      final scalar = code != null && code >= 0 && code <= 0x10FFFF ? String.fromCharCode(code) : null;
      if (scalar != null) return scalar;
    }
    return match.group(0)!;
  });
}

final RegExp _entity = RegExp('&([a-zA-Z][a-zA-Z0-9]{1,31});|&#([xX][0-9a-fA-F]+|[0-9]+);');

const Map<String, String> _names = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': '\u00a0',
  'copy': '\u00a9',
  'middot': '\u00b7',
  'hellip': '\u2026',
  'mdash': '\u2014',
  'ndash': '\u2013',
  'laquo': '\u00ab',
  'raquo': '\u00bb',
  'times': '\u00d7',
};
