import 'dart:ui' show PlatformDispatcher;

import 'package:live_log/live_log.dart' show LiveLog, LogLevel;
import 'package:live_net/live_net.dart';
import 'package:live_platform/live_platform.dart' show FormFactor, PlatformKind;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/features/account/douyu_login_store.dart' show AppDouyuLoginStore;

/// The network and site graph: one transport factory, the site HTTP client
/// and the registry of built-in sites.
///
/// The proxy comes from the build (`PURE_LIVE_PROXY`); without it every
/// request follows the process environment (the system route). Site
/// initialization failures never fail the start-up — one broken platform
/// must not cost the other sixteen.
final class AppSites {
  /// The graph over the parts [boot] assembled.
  new({required this.factory, required this.http, required this.registry, this.douyuLogin});

  /// The transport factory, kept for cache purges and cookie clears.
  final DioFactory factory;

  /// The HTTP client the sites speak through.
  final LiveHttp http;

  /// The built-in sites, in registration order.
  final LiveSiteRegistry registry;

  /// The douyu renewal store the registry was built over (null when the
  /// vault would not open — douyu then behaves as before: every request a
  /// guest). The cookie page reads the same instance through
  /// `douyuLoginStoreProvider`.
  final AppDouyuLoginStore? douyuLogin;

  /// Builds the graph and initializes every site.
  ///
  /// The locale handed to the sites follows the process locale and falls
  /// back to the app's base language; sites read the context and the
  /// platform to adapt, never the process directly.
  ///
  /// [proxyPolicyBuilder] wraps the boot's own route decision (the build's
  /// `PURE_LIVE_PROXY`, else the process environment) — how the user's
  /// network-proxy preference joins: enabled requests take its route,
  /// disabled ones fall through to the boot default.
  static Future<AppSites> boot({
    required LiveLog log,
    required PlatformKind kind,
    required FormFactor formFactor,
    Uri? proxy,
    ProxyPolicy Function(ProxyPolicy fallback)? proxyPolicyBuilder,
  }) async {
    final fallbackPolicy = FixedProxyPolicy(
      global: proxy == null
          ? const SystemProxyRoute()
          : HttpProxyRoute(
              host: proxy.host.isEmpty ? '127.0.0.1' : proxy.host,
              port: proxy.port == 0 ? 7897 : proxy.port,
            ),
    );
    final factory = DioFactory(
      log: log.forCategory('net'),
      proxyPolicy: proxyPolicyBuilder?.call(fallbackPolicy) ?? fallbackPolicy,
    );
    final http = factory.create();
    // The douyu renewal seam: the vault's snapshot the adapter renews
    // stored logins through. A vault this process cannot open leaves it
    // null — the same guest behaviour the build had before it existed.
    AppDouyuLoginStore? douyuLogin;
    try {
      douyuLogin = await AppDouyuLoginStore.load();
    } on Object {
      douyuLogin = null;
    }
    final registry = LiveSiteRegistry(createBuiltInLiveSites(http: http, douyuLogin: douyuLogin));

    final context = LiveSiteContext(
      platform: switch ((kind, formFactor)) {
        (PlatformKind.windows, _) => LiveTargetPlatform.windows,
        (PlatformKind.macos, _) => LiveTargetPlatform.macos,
        (PlatformKind.linux, _) => LiveTargetPlatform.linux,
        (PlatformKind.ios, _) => LiveTargetPlatform.ios,
        (PlatformKind.android, FormFactor.tv) => LiveTargetPlatform.androidTv,
        (PlatformKind.android, _) => LiveTargetPlatform.android,
        // Unreachable on dart:io, but the switch must be total; a desktop
        // build is the honest default for an unidentified host.
        (PlatformKind.unknown, _) => LiveTargetPlatform.windows,
      },
      locale: PlatformDispatcher.instance.locale.toLanguageTag(),
      defaultLocale: 'zh-CN',
    );
    final sitesLog = log.forCategory('sites');
    for (final site in registry.all) {
      try {
        await site.initialize(context);
      } on Object catch (error, stack) {
        sitesLog.log(
          LogLevel.warning,
          'site initialization failed',
          fields: {'site': site.manifest.id},
          error: error,
          stackTrace: stack,
        );
      }
    }
    return AppSites(factory: factory, http: http, registry: registry, douyuLogin: douyuLogin);
  }

  /// Releases every site and the pooled transports, in registration order.
  Future<void> dispose() async {
    for (final site in registry.all) {
      await site.dispose();
    }
    http.close();
  }
}
