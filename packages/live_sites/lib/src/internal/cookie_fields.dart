/// Cookie helpers shared by the platforms' sign-in capabilities: a pasted
/// browser cookie in, the header line a request carries out.
library;

final RegExp _controlCharacters = RegExp(r'[\u0000-\u001F\u007F]');

final RegExp _cookiePrefix = RegExp(r'^Cookie:\s*', caseSensitive: false);

/// The `name=value` pairs of a pasted cookie [rawCookieHeader]: control
/// characters and a leading `Cookie:` name stripped, attribute fields (`path`,
/// `expires`, `domain`) and value-less fields dropped, a later field replacing
/// an earlier one of the same name.
Map<String, String> parseCookieFields(String rawCookieHeader) {
  final cleaned = rawCookieHeader.replaceAll(_controlCharacters, '').trim().replaceFirst(_cookiePrefix, '');
  final fields = <String, String>{};
  for (final part in cleaned.split(';')) {
    final separator = part.indexOf('=');
    if (separator <= 0) continue;
    final name = part.substring(0, separator).trim();
    final value = part.substring(separator + 1).trim();
    if (name.isEmpty || value.isEmpty) continue;
    fields[name] = value;
  }
  return fields;
}

/// [fields] as the `name=value; …` header line a request carries.
String cookieHeaderOf(Map<String, String> fields) =>
    fields.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');
