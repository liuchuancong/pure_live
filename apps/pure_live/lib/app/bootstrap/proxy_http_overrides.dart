import 'dart:io' show HttpClient, HttpOverrides, SecurityContext;

import 'package:live_net/live_net.dart' show HttpProxyRoute, ProxyRoute;

/// What the process's HTTP clients should do about a proxy, answered per
/// client creation.
///
/// The app's own transport sets its proxy explicitly (see `LiveHttp`), but a
/// third-party client that builds its own `dart:io` client — WebDAV's does —
/// only follows what the process hands out. Assigning this here lets the
/// override stay a one-line read of the setting in force at the moment a
/// connection is made, with no Riverpod reference in the IO layer.
ProxyRoute? Function()? appProxyLookup;

/// Points every `dart:io` HTTP client the process creates at the app proxy.
///
/// Installed once at start-up. A lookup that is not assigned yet, or that
/// throws (a container mid-dispose), leaves the client on Dart's own default,
/// which is `HttpClient.findProxyFromEnvironment` — the behaviour the app had
/// before this existed.
final class AppProxyHttpOverrides extends HttpOverrides {
  /// The override over the app's own proxy lookup.
  AppProxyHttpOverrides();

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    final lookup = appProxyLookup;
    if (lookup != null) {
      try {
        if (lookup() case final HttpProxyRoute route) {
          client.findProxy = (_) => 'PROXY ${route.host}:${route.port}';
        }
      } on Object {
        // A failing lookup must not take the request down with it.
      }
    }
    return client;
  }
}
