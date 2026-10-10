// Module: lib/src/cookies.dart
// Purpose: The cookie model and jar behind an account: parse, match, expire, cap and redact.
// Author: liuchuancong
// Created: 2026-10-11
//
// Why this is implemented here instead of taking package:cookie_jar: that jar keeps its state in files
// (PersistCookieJar) or in dart:io's Cookie type, and an L0 auth package holds secrets only through its own
// SecretVault / SessionBox ports so a web host and an encrypted store remain possible. The rules below are
// RFC 6265's matching and capping rules, not an invention, and they are the part every provider was otherwise
// re-typing by hand.

import 'package:pure_live_utils/pure_live_utils.dart';

/// One cookie as stored by a provider, with the attributes that decide where it may be sent.
final class AuthCookie {
  const AuthCookie({
    required this.name,
    required this.value,
    this.domain = '',
    this.path = '/',
    this.expiresAt,
    this.secure = false,
    this.httpOnly = false,
    this.sameSite = SameSiteMode.none,
  });

  /// Parses one `Set-Cookie` header value.
  ///
  /// Returns null for a value with no `name=` pair, which is a malformed header rather than an empty cookie:
  /// storing a nameless cookie would give the jar an entry no request can ever match.
  static AuthCookie? parse(String headerValue, {DateTime? receivedAt, String? requestHost}) {
    final parts = headerValue.split(';');
    if (parts.isEmpty) {
      return null;
    }
    final pair = parts.first;
    final equals = pair.indexOf('=');
    if (equals <= 0) {
      return null;
    }
    final name = pair.substring(0, equals).trim();
    final value = pair.substring(equals + 1).trim();
    if (name.isEmpty) {
      return null;
    }
    var domain = requestHost ?? '';
    var path = '/';
    DateTime? expiresAt;
    var secure = false, httpOnly = false;
    var sameSite = SameSiteMode.none;

    for (final rawAttribute in parts.skip(1)) {
      final attribute = rawAttribute.trim();
      if (attribute.isEmpty) {
        continue;
      }
      final split = attribute.indexOf('=');
      final key = (split < 0 ? attribute : attribute.substring(0, split)).trim().toLowerCase();
      final valueText = split < 0 ? '' : attribute.substring(split + 1).trim();
      switch (key) {
        case 'domain':
          domain = _normaliseDomain(valueText);
        case 'path':
          path = valueText.isEmpty ? '/' : valueText;
        case 'expires':
          expiresAt = parseHttpDate(valueText) ?? expiresAt;
        case 'max-age':
          final seconds = int.tryParse(valueText);
          if (seconds != null) {
            final at = (receivedAt ?? _utcNow()).toUtc();
            // A negative or zero Max-Age means "expire now", which is a deletion instruction, not a
            // far-past date: an implementation that stored it as 1969 would keep the cookie forever.
            expiresAt = seconds <= 0 ? DateTime.utc(1970) : at.add(Duration(seconds: seconds));
          }
        case 'secure':
          secure = true;
        case 'httponly':
          httpOnly = true;
        case 'samesite':
          sameSite = switch (valueText.toLowerCase()) {
            'strict' => SameSiteMode.strict,
            'lax' => SameSiteMode.lax,
            'none' => SameSiteMode.none,
            _ => SameSiteMode.none,
          };
      }
    }

    // A cookie the server scoped to a domain the request did not come from is rejected outright rather than
    // stored narrowed: accepting it would let one response plant a cookie the jar later sends to a different
    // site.
    if (requestHost != null && requestHost.isNotEmpty) {
      final wanted = _normaliseDomain(domain);
      if (wanted.isNotEmpty && !_domainMatches(requestHost, wanted)) {
        return null;
      }
      domain = wanted.isEmpty ? _normaliseDomain(requestHost) : wanted;
    }

    return AuthCookie(
      name: name,
      value: value,
      domain: domain,
      path: path,
      expiresAt: expiresAt,
      secure: secure,
      httpOnly: httpOnly,
      sameSite: sameSite,
    );
  }

  final String name;
  final String value;

  /// The host this cookie is scoped to, leading dot removed. Empty means "the host that set it".
  final String domain;
  final String path;

  /// Absolute expiry, or null for a session cookie that dies with the process.
  final DateTime? expiresAt;

  final bool secure;
  final bool httpOnly;
  final SameSiteMode sameSite;

  bool isLiveAt(DateTime now) {
    final expiry = expiresAt;
    if (expiry == null) {
      return true;
    }
    return now.toUtc().isBefore(expiry.toUtc());
  }

  /// Whether this cookie may be sent to [host].
  ///
  /// The rule is suffix equality with a dot boundary: `example.com` matches `www.example.com` but never
  /// `notexample.com`, and a bare `com` matches nothing that is not itself a registrable suffix check.
  bool matchesHost(String host) {
    if (domain.isEmpty) {
      return true;
    }
    return _domainMatches(host, domain);
  }

  /// Whether this cookie's path prefix covers [requestPath].
  ///
  /// Path matching is prefix matching at a separator boundary: `/app` covers `/app/edit` and not
  /// `/application`, which a naive startsWith gets wrong in exactly the direction that leaks a cookie.
  bool matchesPath(String requestPath) {
    final cookiePath = path.isEmpty ? '/' : path;
    if (requestPath.isEmpty || cookiePath == '/') {
      return requestPath.isEmpty || cookiePath == '/';
    }
    if (!requestPath.startsWith(cookiePath)) {
      return false;
    }
    return cookiePath.endsWith('/') || requestPath.length == cookiePath.length || requestPath[cookiePath.length] == '/';
  }

  /// Whether the request uri may carry this cookie at all.
  bool matchesUri(String url, {DateTime? now}) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return false;
    }
    if (secure && uri.scheme != 'https') {
      return false;
    }
    final at = now ?? _utcNow();
    return isLiveAt(at) && matchesHost(uri.host) && matchesPath(uri.path);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'n': name,
    'v': value,
    if (domain.isNotEmpty) 'd': domain,
    if (path != '/') 'p': path,
    if (expiresAt != null) 'e': expiresAt!.toUtc().toIso8601String(),
    if (secure) 's': true,
    if (httpOnly) 'h': true,
    if (sameSite != SameSiteMode.none) 'ss': sameSite.name,
  };

  static AuthCookie? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final name = json['n'];
    final value = json['v'];
    if (name is! String || value is! String || name.isEmpty) {
      return null;
    }
    return AuthCookie(
      name: name,
      value: value,
      domain: '${json['d'] ?? ''}',
      path: '${json['p'] ?? '/'}',
      expiresAt: DateTime.tryParse('${json['e'] ?? ''}')?.toUtc(),
      secure: json['s'] == true,
      httpOnly: json['h'] == true,
      sameSite: switch ('${json['ss'] ?? 'none'}') {
        'strict' => SameSiteMode.strict,
        'lax' => SameSiteMode.lax,
        _ => SameSiteMode.none,
      },
    );
  }

  /// The value with the secret replaced. Cookies are what a session *is*, so a log line carrying one can be
  /// replayed by whoever reads the log.
  Map<String, Object?> toDiagnosticJson() => <String, Object?>{
    'name': name,
    'domain': domain,
    'path': path,
    if (expiresAt != null) 'expiresAt': expiresAt!.toUtc().toIso8601String(),
    'length': value.length,
    if (secure) 'secure': true,
    if (httpOnly) 'httpOnly': true,
  };

  @override
  String toString() => 'AuthCookie($name, domain $domain, path $path)';
}

/// The `SameSite` values this jar records. It does not enforce them - there is no browser here - but a
/// provider that replays a cookie set with SameSite=None onto a plain http request would be breaking the
/// server's own instruction, so the attribute is kept.
enum SameSiteMode { strict, lax, none }

/// A cookie store for one provider account.
///
/// Isolation is by construction rather than by discipline: a jar belongs to one account, and there is no
/// method here that takes a provider argument to get at another account's cookies.
final class AuthCookieJar {
  AuthCookieJar({this.maxCookiesPerDomain = 50, this.maxCookies = 3000, Clock? clock}) : _clock = clock ?? systemClock {
    if (maxCookiesPerDomain < 1 || maxCookies < 1) {
      throw const AuthJarFailure('cookie caps must both be at least one');
    }
  }

  /// RFC 6265's own defaults, kept as constants rather than magic numbers at the two call sites.
  static const int defaultCookiesPerDomain = 50;

  final int maxCookiesPerDomain;
  final int maxCookies;
  final Clock _clock;

  final List<AuthCookie> _cookies = <AuthCookie>[];

  int get length => _cookies.length;

  bool get isEmpty => _cookies.isEmpty;

  /// Replaces or adds [cookie], answering whether it was stored at all.
  ///
  /// A cookie whose expiry is in the past removes the matching entry instead of storing itself, because that
  /// is what the server meant and a jar that keeps it alive ignores an explicit instruction.
  bool upsert(AuthCookie cookie, {String? requestHost}) {
    final now = _clock().toUtc();
    final host = requestHost ?? cookie.domain;
    if (!cookie.isLiveAt(now)) {
      _cookies.removeWhere(
        (stored) => stored.name == cookie.name && stored.domainMatchesForReplacement(cookie.domain, host),
      );
      return false;
    }
    final existing = _cookies.indexWhere(
      (stored) =>
          stored.name == cookie.name &&
          stored.domainMatchesForReplacement(cookie.domain, host) &&
          stored.path == cookie.path,
    );
    if (existing >= 0) {
      _cookies[existing] = cookie;
      return true;
    }
    _cookies.add(cookie);
    _enforceCaps(host);
    return true;
  }

  /// Applies one `Set-Cookie` header.
  bool absorb(String headerValue, {String? requestHost}) {
    final parsed = AuthCookie.parse(headerValue, receivedAt: _clock(), requestHost: requestHost);
    if (parsed == null) {
      return false;
    }
    return upsert(parsed, requestHost: requestHost);
  }

  /// Applies a whole `Set-Cookie` list, as one response can carry several.
  int absorbAll(Iterable<String> headers, {String? requestHost}) {
    var stored = 0;
    for (final header in headers) {
      if (absorb(header, requestHost: requestHost)) {
        stored++;
      }
    }
    return stored;
  }

  /// The `Cookie:` header value for [url], or null when nothing applies.
  String? headerFor(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return null;
    }
    final now = _clock().toUtc();
    final applicable =
        _cookies
            .where((cookie) => cookie.matchesUri(url, now: now))
            // Longest path first: RFC 6265 orders the header this way, and a server that reads only the first
            // match of a name sees the more specific cookie.
            .toList(growable: false)
          ..sort((left, right) {
            final byPath = right.path.length.compareTo(left.path.length);
            return byPath != 0 ? byPath : left.name.compareTo(right.name);
          });
    if (applicable.isEmpty) {
      return null;
    }
    return applicable.map((cookie) => '${cookie.name}=${cookie.value}').join('; ');
  }

  /// Cookies that apply to [url], for callers that need the attributes rather than a header string.
  List<AuthCookie> forUri(String url) {
    final now = _clock().toUtc();
    return List<AuthCookie>.unmodifiable(_cookies.where((cookie) => cookie.matchesUri(url, now: now)));
  }

  /// Drops everything past its expiry, answering how many went.
  int pruneExpired() {
    final now = _clock().toUtc();
    final before = _cookies.length;
    _cookies.removeWhere((cookie) => !cookie.isLiveAt(now));
    return before - _cookies.length;
  }

  void clear() => _cookies.clear();

  /// Everything, in a form the vault can store. Nothing here is safe to log: the values are the credentials.
  List<Map<String, Object?>> toJson() => <Map<String, Object?>>[for (final cookie in _cookies) cookie.toJson()];

  /// Replaces the store from [toJson] output, skipping entries it cannot read.
  ///
  /// A stored cookie list is data from disk, and one unreadable entry must not lose the rest of a session.
  int restore(Iterable<Object?> rows) {
    clear();
    var restored = 0;
    for (final row in rows) {
      final cookie = AuthCookie.fromJson(row);
      if (cookie != null && cookie.isLiveAt(_clock().toUtc())) {
        _cookies.add(cookie);
        restored++;
      }
    }
    return restored;
  }

  /// A projection safe for a diagnostics view: names, scopes, expiry - never values.
  List<Map<String, Object?>> describe() => <Map<String, Object?>>[
    for (final cookie in _cookies) cookie.toDiagnosticJson(),
  ];

  void _enforceCaps(String host) {
    pruneExpired();
    if (_cookies.length > maxCookies) {
      // Oldest first by expiry, session cookies last: a cookie with no expiry is the one the server expects
      // to be reissued next login, so dropping it costs a login while dropping an expired one costs nothing.
      _cookies.sort(_byUrgency);
      _cookies.removeRange(0, _cookies.length - maxCookies);
    }
    if (host.isEmpty) {
      return;
    }
    final scoped = _cookies.where((cookie) => cookie.domain == _normaliseDomain(host)).toList(growable: false);
    if (scoped.length <= maxCookiesPerDomain) {
      return;
    }
    final doomed = scoped.sublist(0, scoped.length - maxCookiesPerDomain);
    _cookies.removeWhere(doomed.contains);
  }

  static int _byUrgency(AuthCookie left, AuthCookie right) {
    final a = left.expiresAt, b = right.expiresAt;
    if (a == null && b == null) {
      return 0;
    }
    if (a == null) {
      return 1;
    }
    if (b == null) {
      return -1;
    }
    return a.compareTo(b);
  }
}

/// A jar configured or stored in a way it cannot honour.
final class AuthJarFailure extends DomainFailure {
  const AuthJarFailure(super.reason, {super.cause});
}

String _normaliseDomain(String value) {
  var domain = value.trim().toLowerCase();
  if (domain.startsWith('.')) {
    domain = domain.substring(1);
  }
  return domain;
}

bool _domainMatches(String host, String domain) {
  final left = _normaliseDomain(host), right = _normaliseDomain(domain);
  if (left.isEmpty || right.isEmpty) {
    return false;
  }
  return left == right || (left.endsWith('.$right') && !_isPublicSuffixBoundary(right, left));
}

/// A guard against the classic suffix mistake: `com` must not match `example.com` just because of the dot.
///
/// Real public-suffix data is a large table and a moving target, so this uses the structural rule a jar can
/// apply on its own - a domain has to have at least one label of its own beyond the match to be matchable.
bool _isPublicSuffixBoundary(String domain, String host) {
  final labels = domain.split('.');
  return labels.length < 2 || (host.split('.').length - labels.length) < 1;
}

extension on AuthCookie {
  /// Whether two cookies are the same stored cookie: same name, and the same effective domain once the
  /// host that set it is folded in.
  bool domainMatchesForReplacement(String otherDomain, String requestHost) {
    final mine = domain.isEmpty ? _normaliseDomain(requestHost) : _normaliseDomain(domain);
    final theirs = otherDomain.isEmpty ? _normaliseDomain(requestHost) : _normaliseDomain(otherDomain);
    return mine == theirs;
  }
}

DateTime _utcNow() => DateTime.now().toUtc();

/// Parses the `Expires` attribute form, which is an HTTP date rather than an ISO-8601 one.
///
/// Kept local and small: three known shapes, and a null answer for anything else, because a cookie with an
/// unreadable expiry is treated as a session cookie - the safer of the two mistakes.
DateTime? parseHttpDate(String value) {
  final iso = DateTime.tryParse(value);
  if (iso != null) {
    return iso.toUtc();
  }
  final match = RegExp(r'(\d{1,2})\s+([A-Za-z]{3})[a-z]*\s+(\d{2,4})\s+(\d{1,2}):(\d{2}):(\d{2})').firstMatch(value);
  if (match == null) {
    return null;
  }
  const months = <String>['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
  final month = months.indexOf(match.group(2)!.toLowerCase());
  if (month < 0) {
    return null;
  }
  var year = int.parse(match.group(3)!);
  if (year < 100) {
    year += year <= 69 ? 2000 : 1900;
  }
  return DateTime.utc(
    year,
    month + 1,
    int.parse(match.group(1)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6)!),
  );
}
