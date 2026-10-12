/// One playlist line's address, split from the |Key=Value headers that
/// some providers append to hand the player a user agent or a referer.
///
/// Shared by both parsers: a TXT list writes `name,url|User-Agent=…` just
/// as often as an M3U does, and a header dropped on the way in is a channel
/// that plays in the list and fails the moment it is opened.
///
/// Splits `url` from a `url|Key=Value&Key2=Value2` tail.
({String url, Map<String, String> headers}) splitUrlHeaders(String line) {
  final separator = line.indexOf('|');
  if (separator < 0) {
    return (url: line.trim(), headers: const {});
  }
  final url = line.substring(0, separator).trim();
  final tail = line.substring(separator + 1);
  final headers = <String, String>{};
  for (final pair in tail.split('&')) {
    final equals = pair.indexOf('=');
    if (equals <= 0) {
      continue;
    }
    final key = pair.substring(0, equals).trim().toLowerCase();
    final value = pair.substring(equals + 1).trim();
    if (key == 'user-agent') {
      headers['user-agent'] = value;
    } else if (key == 'referer' || key == 'referrer') {
      headers['referer'] = value;
    }
  }
  return (url: url, headers: headers);
}
