// Module: lib/src/strings.dart
// Purpose: String and URL text helpers shared by every layer, including the redaction of sensitive headers.
// Author: liuchuancong
// Created: 2026-10-08
//
// The redaction rules come from docs/contracts/platform-models.md section 16: Authorization, Cookie and
// the other listed headers may be held at runtime but must never reach diagnostics or persistence in clear
// text. Keeping the list here means one place to review when a source adds its own auth header.

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

extension StringExtras on String {
  /// The string itself, or null when it is empty or only whitespace.
  ///
  /// Several protocols send an empty field instead of omitting it; treating that as absent keeps the
  /// model's null meaning ("the protocol did not say") intact.
  String? get nullIfBlank => trim().isEmpty ? null : this;

  /// Collapses runs of whitespace to single spaces and trims the ends.
  String get collapsedWhitespace => trim().replaceAll(RegExp(r'\s+'), ' ');

  /// Shortens to [maxLength] with a trailing ellipsis, leaving short input untouched.
  String truncate(int maxLength, {String ellipsis = '…'}) {
    if (maxLength <= 0 || length <= maxLength) {
      return this;
    }
    final keep = maxLength - ellipsis.length;
    if (keep <= 0) {
      return substring(0, maxLength);
    }
    return '${substring(0, keep)}$ellipsis';
  }
}

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
Map<String, String> redactHeaders(Map<String, String> headers) {
  return Map<String, String>.fromEntries(
    headers.entries.map(
      (entry) => MapEntry(
        entry.key,
        sensitiveHeaderNames.contains(entry.key.toLowerCase()) ? redactedPlaceholder : entry.value,
      ),
    ),
  );
}

/// Redacts query parameters so a signed URL can be logged without leaking its token.
///
/// The rewrite works on the raw query text instead of rebuilding a [Uri], so parameters that survive keep
/// their original encoding and the placeholder stays readable as `***` rather than `%2A%2A%2A`.
String redactQuery(
  String url, {
  Set<String> sensitiveQueryKeys = const <String>{'token', 'sign', 'key', 'secret', 'auth', 'sig'},
}) {
  final mark = url.indexOf('?');
  if (mark < 0 || mark == url.length - 1) {
    return url;
  }
  final prefix = url.substring(0, mark + 1);
  final query = url.substring(mark + 1);
  final rewritten = query.split('&').map((part) {
    final equals = part.indexOf('=');
    if (equals < 1) {
      return part;
    }
    final name = part.substring(0, equals).toLowerCase();
    if (!sensitiveQueryKeys.contains(name)) {
      return part;
    }
    return '${part.substring(0, equals)}=$redactedPlaceholder';
  }).join('&');
  return '$prefix$rewritten';
}
