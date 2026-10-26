/// Redacts secrets out of log text and structured fields before they reach
/// any sink.
///
/// Three families of secrets are covered: query parameters of signed URLs
/// (`?...&sign=abc`), credential headers (`cookie:`, `authorization:`)
/// wherever they appear as text, and map entries whose key names one
/// (`fields['cookie']`). Values are replaced with [replacement]; key names
/// stay visible so the log line is still diagnosable.
///
/// This is the single redaction entry point: it runs at emit time in
/// `LiveLog` and again in every export path, never only in one formatter.
final class LogSanitizer {
  /// A sanitizer with the given [queryKeys] and [headerNames] treated as
  /// secrets (both compared case-insensitively).
  const new({
    this.queryKeys = defaultSensitiveQueryKeys,
    this.headerNames = defaultSensitiveHeaderNames,
    this.replacement = defaultReplacement,
  });

  /// Query parameter keys whose values are signatures or tokens.
  final Set<String> queryKeys;

  /// Header names (and field names) whose whole value is a credential.
  final Set<String> headerNames;

  /// The text substituted for every redacted value.
  final String replacement;

  /// Default redaction for signed URL query parameters.
  static const Set<String> defaultSensitiveQueryKeys = {
    'sign',
    'signature',
    'token',
    'access_token',
    'refresh_token',
    'access_key',
    'api_key',
    'auth_key',
    'ticket',
    'w_rid',
    'wssign',
    'secret',
    'password',
    'passwd',
    'cookie',
  };

  /// Default redaction for credential-like headers and field names.
  static const Set<String> defaultSensitiveHeaderNames = {
    'cookie',
    'set-cookie',
    'authorization',
    'proxy-authorization',
    'token',
    'access_token',
    'refresh_token',
    'access_key',
    'api_key',
    'password',
  };

  /// The default replacement text.
  static const String defaultReplacement = '***';

  static final RegExp _queryPattern = RegExp(
    '([?&])(${defaultSensitiveQueryKeys.join('|')})=([^&\\s\'"]+)',
    caseSensitive: false,
  );

  static final RegExp _headerPattern = RegExp(
    '(${defaultSensitiveHeaderNames.join('|')})\\s*[:=]\\s*'
    '([^;\\s\'"&]+)',
    caseSensitive: false,
  );

  /// Redacts signed query parameters and credential headers from [text].
  String sanitizeText(String text) {
    var result = text;
    if (queryKeys.isNotEmpty) {
      result = result.replaceAllMapped(_queryPattern, (match) => '${match.group(1)}${match.group(2)}=$replacement');
    }
    if (headerNames.isNotEmpty) {
      result = result.replaceAllMapped(_headerPattern, (match) => '${match.group(1)}=$replacement');
    }
    return result;
  }

  /// Redacts [value] recursively: credential-keyed map entries are masked
  /// entirely, strings pass through [sanitizeText], lists recurse. Deeply
  /// nested values are collapsed to the replacement to bound the work.
  Object? sanitizeValue(Object? value, {int depth = 0}) {
    if (depth > 4) {
      return replacement;
    }
    if (value is String) {
      return sanitizeText(value);
    }
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _isSensitiveName(entry.key.toString())
              ? replacement
              : sanitizeValue(entry.value, depth: depth + 1),
      };
    }
    if (value is List) {
      return [for (final item in value) sanitizeValue(item, depth: depth + 1)];
    }
    return value;
  }

  /// Redacts a field map: credential-keyed entries are masked entirely,
  /// every value passes through [sanitizeValue]. The typed counterpart
  /// of [sanitizeValue] for emit-time field merging.
  Map<String, Object?> sanitizeFields(Map<String, Object?> fields) {
    if (fields.isEmpty) {
      return const {};
    }
    return {
      for (final entry in fields.entries)
        entry.key: _isSensitiveName(entry.key) ? replacement : sanitizeValue(entry.value),
    };
  }

  bool _isSensitiveName(String name) {
    final lowered = name.toLowerCase();
    return headerNames.contains(lowered) || queryKeys.contains(lowered);
  }
}
