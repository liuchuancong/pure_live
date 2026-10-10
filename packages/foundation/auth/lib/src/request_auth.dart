// Module: lib/src/request_auth.dart
// Purpose: Put a stored credential onto an outgoing request, in the shape that provider asked for.
// Author: liuchuancong
// Created: 2026-10-11
//
// Providers each need the same thing done slightly differently: a bearer header, a bare token in a named
// header, a cookie line, a query parameter. Those variants are data, not code, so they are described by
// [AuthScheme] and the assembly happens once here - including the part every hand-rolled version forgets,
// which is that the resulting headers must be redactable before they reach a log.

import 'package:pure_live_utils/pure_live_utils.dart';

import 'cookies.dart';
import 'credential_store.dart';
import 'session.dart';

/// Where a provider expects its credential.
enum CredentialPlacement {
  /// `Authorization: Bearer <secret>`.
  bearer,

  /// `<headerName>: <secret>` with no prefix, which is how most Chinese live sites want a token.
  header,

  /// `Cookie: <name>=<value>` assembled from [AuthCookieJar], plus any header the provider needs anyway.
  cookie,

  /// `?<queryParam>=<secret>`, for endpoints that only sign in the query.
  query,

  /// Nothing: an anonymous account that still wants its fixed headers sent.
  none,
}

/// One provider's credential shape.
final class AuthScheme {
  const AuthScheme({
    this.placement = CredentialPlacement.bearer,
    this.headerName = 'Authorization',
    this.prefix = 'Bearer ',
    this.queryParam,
    this.fixedHeaders = const <String, String>{},
    this.fixedQuery = const <String, String>{},
  });

  /// The plain token in a named header, which is what most cookie-or-token sites use.
  const AuthScheme.headerOnly(this.headerName, {this.fixedHeaders = const <String, String>{}})
    : placement = CredentialPlacement.header,
      prefix = '',
      queryParam = null,
      fixedQuery = const <String, String>{};

  /// Cookies plus the browser-looking headers the endpoint insists on.
  const AuthScheme.cookies({this.fixedHeaders = const <String, String>{}})
    : placement = CredentialPlacement.cookie,
      headerName = 'Cookie',
      prefix = '',
      queryParam = null,
      fixedQuery = const <String, String>{};

  static const AuthScheme bearer = AuthScheme();

  final CredentialPlacement placement;
  final String headerName;

  /// Only read when [placement] is [CredentialPlacement.bearer].
  final String prefix;
  final String? queryParam;

  /// Headers sent whether or not a credential exists - a user agent, a referer, the provider's version field.
  final Map<String, String> fixedHeaders;
  final Map<String, String> fixedQuery;
}

/// A request with its credentials applied.
final class AuthRequest {
  const AuthRequest({required this.url, required this.headers, required this.queryParameters, this.session});

  final String url;
  final Map<String, String> headers;
  final Map<String, String> queryParameters;

  /// The account that was used, so a caller can tell "anonymous" from "the account you named".
  final AuthSession? session;

  bool get isAuthenticated => session?.isLoggedIn ?? false;

  /// [headers] with every credential value reduced to its length.
  ///
  /// A request log is the easiest way to leak a session: the header that authenticates is exactly the string
  /// an attacker needs, and "debug only" logs survive into release builds.
  Map<String, String> redacted() => RequestAuthorizer.redact(headers);

  @override
  String toString() => 'AuthRequest(${Uri.tryParse(url)?.host}, ${redacted()})';
}

/// No credential could be applied where one was required.
final class AuthRequestFailure extends DomainFailure {
  const AuthRequestFailure(super.reason, {this.providerId, this.accountId, super.cause});

  final String? providerId;
  final String? accountId;
}

/// Applies [AuthScheme]s to requests using a [CredentialStore] and, for cookie providers, an [AuthCookieJar].
final class RequestAuthorizer {
  const RequestAuthorizer({required this.store});

  final CredentialStore store;

  /// Headers and query for [url] as account `<providerId>/<accountId>`.
  ///
  /// [requireCredential] turns a missing secret into a failure instead of an anonymous request: a screen that
  /// is showing the user's own data must not silently fall back to fetching the public version of it, because
  /// the result looks like success and reads like lost data.
  Future<AuthRequest> authorize(
    String url, {
    required String providerId,
    required String accountId,
    AuthScheme scheme = AuthScheme.bearer,
    AuthCookieJar? jar,
    bool requireCredential = false,
  }) async {
    final session = await store.sessionOf(providerId, accountId);
    if (requireCredential && (session == null || !session.isLoggedIn)) {
      throw AuthRequestFailure('no live session for this account', providerId: providerId, accountId: accountId);
    }
    final secret = session == null ? null : await store.readSecret(session.handle);
    if (requireCredential && (secret == null || secret.isEmpty)) {
      throw AuthRequestFailure('the session has no stored secret', providerId: providerId, accountId: accountId);
    }

    final headers = Map<String, String>.of(scheme.fixedHeaders);
    var query = Map<String, String>.of(scheme.fixedQuery);

    switch (scheme.placement) {
      case CredentialPlacement.none:
        break;
      case CredentialPlacement.bearer:
        if (secret != null && secret.isNotEmpty) {
          headers[scheme.headerName] = '${scheme.prefix}$secret';
        }
      case CredentialPlacement.header:
        if (secret != null && secret.isNotEmpty) {
          headers[scheme.headerName] = secret;
        }
      case CredentialPlacement.query:
        final name = scheme.queryParam;
        if (secret != null && secret.isNotEmpty && name != null && name.isNotEmpty) {
          query = Map<String, String>.of(query)..[name] = secret;
        }
      case CredentialPlacement.cookie:
        if (secret != null && secret.isNotEmpty && scheme.headerName != 'Cookie') {
          // A cookie provider can still want a token header alongside the jar (a site that checks both).
          headers[scheme.headerName] = secret;
        }
        final cookieLine = jar?.headerFor(url);
        if (cookieLine != null && cookieLine.isNotEmpty) {
          headers['Cookie'] = cookieLine;
        }
    }

    return AuthRequest(url: url, headers: headers, queryParameters: query, session: session);
  }

  /// The same, addressed by handle instead of by ids.
  Future<AuthRequest> authorizeFor(
    CredentialHandle handle,
    String url, {
    AuthScheme scheme = AuthScheme.bearer,
    AuthCookieJar? jar,
    bool requireCredential = false,
  }) => authorize(
    url,
    providerId: handle.providerId,
    accountId: handle.accountId,
    scheme: scheme,
    jar: jar,
    requireCredential: requireCredential,
  );

  /// The names whose values are the credential itself, so [redact] knows what to cut.
  static const Set<String> sensitiveHeaderNames = <String>{
    'authorization',
    'cookie',
    'set-cookie',
    'proxy-authorization',
    'x-auth-token',
    'x-xsrf-token',
  };

  /// [headers] with the credential values replaced by their length.
  ///
  /// Unknown headers pass through unchanged: a provider's trace id is not a secret, and redacting everything
  /// makes a log line useless for the thing it was written for.
  static Map<String, String> redact(Map<String, String> headers) {
    final out = <String, String>{};
    for (final entry in headers.entries) {
      out[entry.key] = sensitiveHeaderNames.contains(entry.key.toLowerCase())
          ? '<${entry.value.length} chars>'
          : entry.value;
    }
    return Map<String, String>.unmodifiable(out);
  }
}
