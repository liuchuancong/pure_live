// Module: lib/src/url_reference.dart
// Purpose: Resolve a site's relative path against the url that served it, add query parameters, and redact
// credentials before a url reaches a log.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spider payloads hand back `/api/x`, `//cdn.y/z`, `../m3u8` and full urls, sometimes all four in one document,
// and each has to be answered against the url that actually responded rather than the one that was requested -
// a redirect to another CDN changes what `../` means. Uri does the reference arithmetic; this file only decides
// which base to feed it and what to hide afterwards. A url is the one field that reliably ends up in a support
// attachment, and it is exactly where a signing token lives.

/// The query keys that carry a credential by convention. A host can add its own.
const Set<String> kSensitiveQueryKeys = <String>{
  'token',
  'access_token',
  'accessToken',
  'api_key',
  'apikey',
  'key',
  'secret',
  'sign',
  'sig',
  'signature',
  'w_rid',
  'password',
  'passwd',
  'auth',
  'authorization',
  'session',
  'sid',
  'cookie',
  'm3u8token',
};

/// Any url-shaped value: callers hold strings from JSON and `Uri` objects from transports alike.
typedef UrlLike = Object;

/// The url [reference] denotes when read against [baseUrl].
///
/// Handles the four shapes a site actually emits: absolute (`https://cdn/x`), protocol-relative (`//cdn/x`,
/// which inherits the requester's scheme), root-relative (`/x`) and path-relative (`x`, `../x`, `./x`,
/// resolved against the base's *directory*, not its file). An unparseable input falls back to the base so a
/// malformed payload cannot throw inside a list build.
Uri resolveReference(UrlLike baseUrl, String? reference) {
  final base = _asUri(baseUrl);
  final text = reference?.trim() ?? '';
  if (text.isEmpty) {
    return base;
  }
  try {
    if (text.startsWith('//')) {
      final scheme = base.scheme.isEmpty ? 'https' : base.scheme;
      return Uri.parse('$scheme:$text');
    }
    if (Uri.parse(text).hasScheme) {
      return Uri.parse(text);
    }
    if (text.startsWith('/')) {
      return base.replace(path: _dotResolve(text), query: null, fragment: null);
    }
    // Uri.resolve already implements RFC 3986 reference resolution, including dot segments.
    return base.resolve(text);
  } on FormatException {
    return base;
  }
}

/// [url] with [query] merged in. A null value drops the parameter, which is how a caller says "this one must
/// not be sent" without rebuilding the map.
Uri withQuery(UrlLike baseUrl, Map<String, Object?> query, {bool overwrite = true}) {
  final base = _asUri(baseUrl);
  final merged = <String, String>{for (final entry in base.queryParameters.entries) entry.key: entry.value};
  query.forEach((name, value) {
    if (value == null) {
      merged.remove(name);
      return;
    }
    if (overwrite || !merged.containsKey(name)) {
      merged[name] = '$value';
    }
  });
  return base.replace(queryParameters: merged);
}

/// Whether two urls share scheme, host and port, which is what an origin is for a redirect check.
bool sameOrigin(UrlLike left, UrlLike right) {
  final a = _asUri(left);
  final b = _asUri(right);
  return _schemeOf(a) == _schemeOf(b) && a.host == b.host && _portOf(a) == _portOf(b);
}

/// [url] with credential-valued query parameters replaced by [marker].
String redact(UrlLike url, {Set<String> sensitive = kSensitiveQueryKeys, String marker = '***'}) {
  final parsed = _asUri(url);
  if (parsed.queryParameters.isEmpty && parsed.userInfo.isEmpty) {
    return parsed.toString();
  }
  final kept = <String, String>{
    for (final entry in parsed.queryParameters.entries)
      entry.key: sensitive.contains(entry.key.toLowerCase()) ? marker : entry.value,
  };
  final clean = parsed.replace(queryParameters: kept);
  // User info in the authority component is a credential too, and no site puts one there on purpose.
  return clean.userInfo.isEmpty ? clean.toString() : clean.replace(userInfo: '').toString();
}

/// The host, or an empty string when the value is not a url at all.
String urlHostOf(UrlLike url) {
  try {
    return _asUri(url).host;
  } on FormatException {
    return '';
  }
}

/// Whether the scheme is one this client may fetch. A spider payload that says `file://` or `javascript:` is
/// either a bug or an attempt to read the device.
bool isHttpScheme(UrlLike url) {
  final scheme = _asUri(url).scheme.toLowerCase();
  return scheme == 'http' || scheme == 'https';
}

Uri _asUri(UrlLike value) {
  if (value is Uri) {
    return value;
  }
  if (value is String) {
    return Uri.parse(value);
  }
  throw ArgumentError.value(value, 'url', 'expected a String or a Uri');
}

String _schemeOf(Uri uri) => uri.scheme.isEmpty ? 'https' : uri.scheme.toLowerCase();

int _portOf(Uri uri) => uri.hasPort ? uri.port : (uri.scheme == 'http' ? 80 : 443);

/// Strips dot segments from a root-relative path before replacing, so `/a/../b` behaves like a browser.
String _dotResolve(String path) {
  final out = <String>[];
  for (final segment in path.split('/')) {
    if (segment.isEmpty || segment == '.') {
      continue;
    }
    if (segment == '..') {
      if (out.isNotEmpty) {
        out.removeLast();
      }
      continue;
    }
    out.add(segment);
  }
  if (out.isEmpty) {
    return '/';
  }
  return '/${out.join('/')}${path.endsWith('/') ? '/' : ''}';
}
