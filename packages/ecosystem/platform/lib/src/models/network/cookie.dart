// Module: lib/src/models/network/cookie.dart
// Purpose: A cookie record the platform holds on behalf of an extension.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/platform-models.md section 12. The value is sensitive: toString and every diagnostic
// view redact it, because a cookie jar that leaks into a log leaks the session with it. There is no
// toJson here on purpose - section 16's serialisation list does not name Cookie, and a store that persists
// one does it through secure storage rather than through a model that invites JSON encoding.

/// Domain and path matching rules, kept close to what the protocols hand us: a cookie for
/// `example.com` is sent to its subdomains, a cookie for `api.example.com` is not.
final class Cookie {
  const Cookie({
    required this.name,
    required this.value,
    required this.domain,
    this.path = '/',
    this.expiresAt,
    this.secure = false,
    this.httpOnly = false,
  });

  final String name;
  final String value;

  /// The host the cookie was set for. A leading dot is accepted and ignored, matching what the
  /// Set-Cookie header allows.
  final String domain;
  final String path;

  /// Null means a session cookie: it dies with the runtime rather than being persisted.
  final DateTime? expiresAt;
  final bool secure;
  final bool httpOnly;

  bool get isSessionCookie => expiresAt == null;

  bool isExpiredAt(DateTime now) {
    final expiry = expiresAt;
    return expiry != null && !now.toUtc().isBefore(expiry);
  }

  /// Whether this cookie belongs on a request for [uri].
  bool matchesUri(Uri uri) {
    if (secure && uri.scheme != 'https') {
      return false;
    }
    if (!matchesHost(uri.host)) {
      return false;
    }
    final requestPath = uri.path.isEmpty ? '/' : uri.path;
    return requestPath.startsWith(path);
  }

  bool matchesHost(String host) {
    final lower = host.toLowerCase();
    final owned = domain.toLowerCase();
    final apex = owned.startsWith('.') ? owned.substring(1) : owned;
    if (apex.isEmpty || lower.isEmpty) {
      return false;
    }
    return lower == apex || lower.endsWith('.$apex');
  }

  /// The value is replaced by its length; see the file header for why.
  String redacted() =>
      '$name=<${value.length} chars> domain=$domain path=$path'
      '${expiresAt == null ? ' session' : ''}${secure ? ' secure' : ''}${httpOnly ? ' httpOnly' : ''}';

  @override
  String toString() => redacted();
}
