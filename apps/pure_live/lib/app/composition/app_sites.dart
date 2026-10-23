import 'dart:ui' show PlatformDispatcher;

import 'package:live_log/live_log.dart' show LiveLog;
import 'package:live_net/live_net.dart' show DioFactory, FixedProxyPolicy, LiveHttp, SystemProxyRoute;
import 'package:live_platform/live_platform.dart' show FormFactor, PlatformKind;
import 'package:live_sites/live_sites.dart'
    show LiveSite, LiveSiteContext, LiveSiteRegistry, LiveTargetPlatform, createBuiltInLiveSites;

/// The network and site graph: one transport factory, the site HTTP client
/// and the registry of built-in sites.
///
/// Without a build-time proxy every request follows the process environment
/// (the system route). One broken platform must not cost the others: site
/// initialization failures are logged and skipped, never fatal.
final class AppSites {
  /// The graph over the parts [boot] assembled.
  const new({required this.factory, required this.http, required this.registry});

  /// The transport factory, kept for cache purges and cookie clears.
  final DioFactory factory;

  /// The HTTP client the sites speak through.
  final LiveHttp http;

  /// The built-in sites, in registration order.
  final LiveSiteRegistry registry;

  /// Every registered site, in registration order.
  List<LiveSite> get all => registry.all;

  /// Builds the graph and initializes every site.
  ///
  /// The locale handed to the sites follows the process locale and falls
  /// back to the app's base language; sites read the context and the
  /// platform to adapt, never the process directly.
  static Future<AppSites> boot({
    required LiveLog log,
    required PlatformKind kind,
    required FormFactor formFactor,
  }) async {
    const fallbackPolicy = FixedProxyPolicy(global: SystemProxyRoute());
    final factory = DioFactory(log: log.forCategory('net'), proxyPolicy: fallbackPolicy);
    final http = factory.create();
    final registry = LiveSiteRegistry(createBuiltInLiveSites(http: http));

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
    var ready = 0;
    for (final site in registry.all) {
      try {
        await site.initialize(context);
        ready++;
      } on Object catch (error, stackTrace) {
        sitesLog.warning(
          'site "${site.manifest.id}" failed to initialize',
          fields: {'error': '$error', 'stack': '$stackTrace'},
        );
      }
    }
    sitesLog.info('site graph ready', fields: {'ready': '$ready', 'total': '${registry.all.length}'});
    return AppSites(factory: factory, http: http, registry: registry);
  }
}
