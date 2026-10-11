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
  const new({required this.host, this.port = 7897});

  /// Proxy host name or IP.
  final String host;

  /// Proxy port; defaults to the common local proxy port 7897.
  final int port;

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
