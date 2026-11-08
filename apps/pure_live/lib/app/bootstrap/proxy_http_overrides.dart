import 'dart:io' show HttpClient, HttpClientBasicCredentials, HttpOverrides, SecurityContext;

import 'package:live_net/live_net.dart' show HttpProxyRoute, ProxyRoute;
import 'package:pure_live/app/logging/app_log.dart' show appLog;

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
          // The same route the app's own transport builds: the credential in the
          // string Dart parses it from, plus the registration that puts it on a
          // CONNECT tunnel — the one case a `PROXY host:port` string cannot
          // reach. Third-party clients (WebDAV's) get no less than Dio does.
          // Loopback and LAN targets answer DIRECT: the LAN sync pairing and
          // the DLNA control speak in local addresses a proxy cannot reach,
          // and pushing them at the proxy breaks pairing for anyone whose
          // proxy is not on the same subnet.
          client.findProxy = route.ioRouteFor;
          if (route.isAuthenticationRequired) {
            client.addProxyCredentials(
              route.host,
              route.port,
              '',
              HttpClientBasicCredentials(route.username, route.password),
            );
          }
        }
      } on Object catch (error) {
        // A failing lookup must not take the request down with it — but the
        // request will go out direct, and the viewer should know why.
        appLog.forCategory('network.proxy').warning(
          'proxy lookup failed; requests fall back to direct',
          fields: {'error': '$error'},
        );
      }
    }
    return client;
  }
}
