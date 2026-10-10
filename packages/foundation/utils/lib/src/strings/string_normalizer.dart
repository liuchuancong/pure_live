// Module: lib/src/strings/string_normalizer.dart
// Purpose: URL text checks and the redaction of sensitive headers and query parameters.
// Author: liuchuancong
// Created: 2026-10-08
//
// The redaction rules come from docs/contracts/platform-models.md section 16: Authorization, Cookie and the
// other listed headers may be held at runtime but must never reach diagnostics or persistence in clear text.
// Keeping the list here means one place to review when a source adds its own auth header.

/// Header names whose values must be redacted before logging or storage, lower cased for comparison.
const Set<String> sensitiveHeaderNames = <String>{
  'authorization',
  'cookie',
  'set-cookie',
  'proxy-authorization',
  'x-api-key',
  'x-auth-token',
};

/// The text that replaces a redacted value.
const String redactedPlaceholder = '***';

/// Query parameters redacted by default: every one of them has carried a token in some source's url.
const Set<String> sensitiveQueryKeys = <String>{'token', 'sign', 'key', 'secret', 'auth', 'sig'};

/// True when [value] parses as an absolute http(s) URL.
bool isHttpUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme) {
    return false;
  }
  return (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
}

/// The lower cased host of [value], or null when it is not a URL with a host.
String? hostOf(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.host.isEmpty) {
    return null;
  }
  return uri.host.toLowerCase();
}

/// Returns a copy of [headers] with sensitive values replaced by [redactedPlaceholder].
///
/// Comparison ignores case because HTTP header names are case-insensitive.
Map<String, String> redactHeaders(Map<String, String> headers, {Set<String> extraSensitiveNames = const <String>{}}) {
  // Set.union takes a Set, so the lower-cased copy has to become one before the merge.
  final blocked = sensitiveHeaderNames.union(extraSensitiveNames.map((name) => name.toLowerCase()).toSet());
  return Map<String, String>.fromEntries(
    headers.entries.map(
      (entry) => MapEntry(entry.key, blocked.contains(entry.key.toLowerCase()) ? redactedPlaceholder : entry.value),
    ),
  );
}

/// Redacts query parameters so a signed URL can be logged without leaking its token.
///
/// The rewrite works on the raw query text instead of rebuilding a [Uri], so parameters that survive keep
/// their original encoding and the placeholder stays readable as three stars rather than percent-encoded.
String redactQuery(String url, {Set<String> sensitiveKeys = sensitiveQueryKeys}) {
  final mark = url.indexOf('?');
  if (mark < 0 || mark == url.length - 1) {
    return url;
  }
  final prefix = url.substring(0, mark + 1);
  final query = url.substring(mark + 1);
  final rewritten = query
      .split('&')
      .map((part) {
        final equals = part.indexOf('=');
        if (equals < 1) {
          return part;
        }
        final name = part.substring(0, equals).toLowerCase();
        if (!sensitiveKeys.contains(name)) {
          return part;
        }
        return '${part.substring(0, equals)}=$redactedPlaceholder';
      })
      .join('&');
  return '$prefix$rewritten';
}
