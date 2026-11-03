import 'dart:convert' show base64Encode, utf8;

/// Proxy routing decisions for outgoing requests.
///
/// A [ProxyPolicy] answers "which route should this request take". Routes are
/// pooled by identity: every distinct [ProxyRoute.key] gets its own
/// transport, so switching proxy per site never crosses connections.
sealed class ProxyRoute {
  /// Base of every routing decision; use the concrete routes below.
  const new();

  /// Stable identity used for transport pooling.
  String get key;
}

/// Connect directly, no proxy.
final class DirectRoute extends ProxyRoute {
  /// The one direct route.
  const new();

  @override
  String get key => 'direct';
}

/// Uses the proxy configured by the process environment
/// (`HTTP_PROXY` / `HTTPS_PROXY` / `NO_PROXY`), i.e. what the system or
/// the user's shell already set up.
final class SystemProxyRoute extends ProxyRoute {
  /// The one environment-driven route.
  const new();

  @override
  String get key => 'system';
}

/// Connect through an HTTP CONNECT proxy.
final class HttpProxyRoute extends ProxyRoute {
  /// Routes through [host]:[port]; [port] defaults to the common local proxy
  /// port 7897.
  ///
  /// [username] and [password] are the proxy's own credentials. An empty pair
  /// leaves the route unauthenticated; a filled one belongs to *this* endpoint
  /// and is never presented to another — which is the property that has to hold
  /// before a stored password is safe to hand out at all, and it is measured in
  /// the app's `test/app/proxy_credentials_test.dart`.
  const new({required this.host, this.port = 7897, this.username = '', this.password = ''});

  /// Proxy host name or IP.
  final String host;

  /// Proxy port; defaults to the common local proxy port 7897.
  final int port;

  /// The proxy's username.
  final String username;

  /// The proxy's password. It never enters [key], [toString], or equality, so
  /// the string a transport pool is labelled with and a log prints cannot carry
  /// it out of this object.
  final String password;

  /// Whether this endpoint asks for a credential at all.
  ///
  /// Both halves are required: a username with no password is a half-typed
  /// entry, and `Basic` of a blank password would be answered with a 407 the
  /// caller cannot explain.
  bool get isAuthenticationRequired => username.isNotEmpty && password.isNotEmpty;

  /// The string dart:io's `findProxy` must be handed to authenticate a route.
  ///
  /// `PROXY host:port`, or `PROXY user:pass@host:port` — and deliberately
  /// **without** a scheme: `_ProxyConfiguration` cuts the userinfo at the
  /// last `@` and then at the *first* colon, so
  /// `PROXY http://user:pass@host:port` reaches the proxy with a username of
  /// `http://user`. A bare `host:port` (what [key] is) is not a directive
  /// dart:io parses at all: it answers every request with
  /// `Invalid proxy configuration`.
  String get ioRoute => isAuthenticationRequired ? 'PROXY $username:$password@$host:$port' : 'PROXY $host:$port';

  /// The `http://host:port` form FFmpeg's `-http_proxy` and mpv's `http-proxy`
  /// take.
  ///
  /// [includeCredentials] is a caller's promise that *that* library parses the
  /// userinfo as its documentation says: mpv does, FFmpeg does not — its
  /// `-http_proxy` reads a bare `host:port` and would fold the credential into
  /// the hostname — so an authenticated endpoint reaches FFmpeg through a
  /// [proxyAuthorizationHeader] instead.
  String url({bool includeCredentials = false}) {
    final hostPort = host.contains(':') && !host.startsWith('[') ? '[$host]:$port' : '$host:$port';
    if (!includeCredentials || !isAuthenticationRequired) return 'http://$hostPort';
    return 'http://${Uri.encodeComponent(username)}:${Uri.encodeComponent(password)}@$hostPort';
  }

  /// The `Proxy-Authorization` value for this endpoint, or null when it asks for
  /// nothing: `Basic` over `user:pass`, as an HTTP proxy expects.
  String? get proxyAuthorizationHeader =>
      isAuthenticationRequired ? 'Basic ${base64Encode(utf8.encode('$username:$password'))}' : null;

  /// The identity this route is pooled and logged under: host and port only.
  @override
  String get key => 'http://$host:$port';

  @override
  String toString() => key;
}

/// Decides the [ProxyRoute] for a request.
///
/// Implementations are consulted for every request; they must be cheap and
/// side-effect free.
abstract interface class ProxyPolicy {
  /// The route for [url] issued by [site], or null for the caller's default.
  ProxyRoute? routeFor(Uri url, {String? site});
}

/// A policy with one global route and optional per-site overrides.
///
/// A per-site entry maps to that route; map a site to `null` to force direct
/// connection for it.
final class FixedProxyPolicy implements ProxyPolicy {
  /// A policy with [global] as the default route and [bySite] overrides.
  const new({this.global, this.bySite = const {}});

  /// Route used when no per-site override matches.
  final ProxyRoute? global;

  /// Per-site overrides keyed by site id.
  final Map<String, ProxyRoute?> bySite;

  @override
  ProxyRoute? routeFor(Uri url, {String? site}) {
    if (site != null && bySite.containsKey(site)) {
      return bySite[site];
    }
    return global;
  }
}
