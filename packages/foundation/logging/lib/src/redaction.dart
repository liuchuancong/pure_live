// Module: lib/src/redaction.dart
// Purpose: The field-level scrubbing a log record applies before any sink can see it.
// Author: liuchuancong
// Created: 2026-10-11
//
// Redaction belongs on the record, not on the sink: a sink that forgets to scrub writes a credential into a
// file on a device that then gets attached to a bug report. The header and query rules come from
// `pure_live_utils` (`redactHeaders`, `redactQuery`, `sensitiveHeaderNames`) - this file only adds the case
// those two cannot see: a credential sitting in free text, where it is neither a header map nor a url.

import 'package:pure_live_utils/pure_live_utils.dart';

/// The placeholder `utils` uses for a masked value: it names the fact that something was there, so a reader
/// can tell "absent" from "hidden".
const String redactedMarker = redactedPlaceholder;

/// Every field name that is never written: the shared header list, the shared query list, and the few names
/// that only show up in a body.
final Set<String> kSensitiveFieldNames = <String>{
  ...sensitiveHeaderNames,
  ...sensitiveQueryKeys,
  'password',
  'passwd',
  'client_secret',
  'api_key',
  'apikey',
  'access_token',
  'accesstoken',
  'refresh_token',
  'sessionid',
  'wts',
  'w_rid',
};

/// True when [key] names a credential by itself.
bool isSensitiveFieldName(String key) => kSensitiveFieldNames.contains(key.trim().toLowerCase());

/// A map key that says "this is a header block", which needs per-entry treatment rather than whole-value.
bool isHeaderBagName(String key) => key.toLowerCase().contains('header');

/// A credential assignment inside free text: `token=abc`, `Authorization: Bearer xyz`, `passwd: hunter2`.
///
/// Every name is a whole word between `\b` markers. A substring rule (`...sign...` anywhere in an identifier)
/// matched `design: v2` and masked a value that was never a secret, which is worse than the bug it prevents:
/// a log that hides innocent fields teaches nobody to trust it.
final RegExp _embeddedSecret = RegExp(
  r'\b(token|access_token|accessToken|accesstoken|refresh_token|refreshToken|api_key|apikey|api-key'
  r'|client_secret|clientSecret|secret|password|passwd|authorization|proxy_authorization|cookie|set-cookie'
  r'|signature|sign|wts|w_rid|sig|auth|session|sessionid|sid)\b(\s*[=:]\s*)([^\s&,;"\x27]{3,})((?:[ \t]+[^\s&,;"\x27]+)*)',
  caseSensitive: false,
);

/// Masks a credential that appears inside a string value.
///
/// A url goes through `utils.redactQuery`, which understands parameter boundaries and leaves the other
/// parameters readable; anything else gets the assignment pattern masked to the end of the value, because a
/// `Bearer <token>` is two words and masking one of them leaves the credential standing behind its own
/// redaction. Returns null when nothing changed, so a caller can skip rebuilding a map.
String? maskEmbeddedSecrets(Object? value) {
  if (value is! String) {
    return null;
  }
  if (isHttpUrl(value)) {
    final cleaned = redactQuery(value, sensitiveKeys: kSensitiveFieldNames);
    return cleaned == value ? null : cleaned;
  }
  if (!_embeddedSecret.hasMatch(value)) {
    return null;
  }
  return value.replaceAllMapped(_embeddedSecret, (Match match) => '${match.group(1)}${match.group(2)}$redactedMarker');
}

/// One field value, scrubbed.
Object? redactFieldValue(String key, Object? value) {
  if (isSensitiveFieldName(key)) {
    return value == null ? null : redactedMarker;
  }
  if (value is Map) {
    return redactFields(_asStringKeys(value));
  }
  return maskEmbeddedSecrets(value) ?? value;
}

/// A field map with credentials removed, applied recursively to nested maps.
Map<String, Object?> redactFields(Map<String, Object?> fields) {
  if (fields.isEmpty) {
    return const <String, Object?>{};
  }
  final out = <String, Object?>{};
  fields.forEach((key, value) {
    if (isHeaderBagName(key) && value is Map) {
      out[key] = redactHeaders(_asStringMap(value), extraSensitiveNames: kSensitiveFieldNames);
      return;
    }
    out[key] = redactFieldValue(key, value);
  });
  return Map<String, Object?>.unmodifiable(out);
}

Map<String, String> _asStringMap(Map<Object?, Object?> source) {
  return <String, String>{for (final entry in source.entries) '${entry.key}': '${entry.value}'};
}

Map<String, Object?> _asStringKeys(Map<Object?, Object?> source) {
  return <String, Object?>{for (final entry in source.entries) '${entry.key}': entry.value};
}
