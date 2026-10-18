import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:pure_live/app/navigation/app_navigator_key.dart' show appNavigatorKey;
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/deep_link.dart';
import 'package:pure_live/app/routing/route_paths.dart';
import 'package:pure_live/app/routing/routes/about/about_routes.dart' as about_routes;
import 'package:pure_live/app/routing/routes/about/version_routes.dart' as version_routes;
import 'package:pure_live/app/routing/routes/areas/areas_routes.dart' as areas_routes;
import 'package:pure_live/app/routing/routes/history/history_routes.dart' as history_routes;
import 'package:pure_live/app/routing/routes/iptv/iptv_routes.dart' as iptv_routes;
import 'package:pure_live/app/routing/routes/login/login_routes.dart' as login_routes;
import 'package:pure_live/app/routing/routes/multiview/multiview_routes.dart' as multiview_routes;
import 'package:pure_live/app/routing/routes/search/search_routes.dart' as search_routes;
import 'package:pure_live/app/routing/routes/settings/settings_routes.dart' as settings_routes;
import 'package:pure_live/app/routing/routes/splash/splash_routes.dart' as splash_routes;
import 'package:pure_live/app/routing/routes/toolbox/remote_sync_routes.dart' as remote_sync_routes;
import 'package:pure_live/app/routing/routes/toolbox/toolbox_routes.dart' as toolbox_routes;
import 'package:pure_live/features/areas/areas_page.dart';
import 'package:pure_live/features/follow/follow_page.dart';
import 'package:pure_live/features/popular/popular_page.dart';
import 'package:pure_live/features/recorder/recorder_page.dart';
import 'package:pure_live/features/version/startup_update_check.dart';
import 'package:pure_live/platforms/adaptive/shell/adaptive_shell.dart';
import 'package:pure_live/platforms/tv/shell/tv_shell.dart';

part 'app_router.g.dart';

/// The app's navigation graph in typed-route form (go_router_builder).
///
/// The shell and its four branches are declared in one table here, because
/// the branch nesting is part of a single annotation; the settings and
/// search routes live in their own files so the chrome and the pages can
/// reach them without importing this library back. When a domain grows real
/// parametrised routes, its `routes/<域>_routes.dart` takes its own
/// annotations and joins [routerProvider] the same way those two lists do.
///
/// The branch table is the reference's home tab set (3.x `HomeMenu`):
/// favorites, popular, areas and the recording centre. Favorites is the
/// shell's first screen — the reference has no launcher page above its tabs —
/// and the watch history is a page pushed from the rail's menu, where
/// `MenuButton` keeps it.
@TypedStatefulShellRoute<AppShellRouteData>(
  branches: <TypedStatefulShellBranch<StatefulShellBranchData>>[
    TypedStatefulShellBranch<FollowBranchData>(
      routes: <TypedRoute<RouteData>>[TypedGoRoute<FollowRoute>(path: RoutePath.favorites)],
    ),
    TypedStatefulShellBranch<PopularBranchData>(
      routes: <TypedRoute<RouteData>>[TypedGoRoute<PopularRoute>(path: RoutePath.popular)],
    ),
    TypedStatefulShellBranch<AreasBranchData>(
      routes: <TypedRoute<RouteData>>[TypedGoRoute<AreasRoute>(path: RoutePath.areas)],
    ),
    TypedStatefulShellBranch<RecordBranchData>(
      routes: <TypedRoute<RouteData>>[TypedGoRoute<RecorderRoute>(path: RoutePath.recorder)],
    ),
  ],
)
class AppShellRouteData extends StatefulShellRouteData {
  /// The shell around the three branches.
  const new();

  @override
  Widget builder(BuildContext context, GoRouterState state, StatefulNavigationShell navigationShell) => Consumer(
    builder: (context, ref, _) {
      // One chrome for phone, tablet and desktop — the shell pins the
      // navigation mode from the form factor and, on desktop, from the window
      // width. TV keeps its own focus-first shell: D-pad traversal wants the
      // autofocus ordering only that shell arranges.
      final shell = switch (ref.watch(environmentProvider).runtime.formFactor) {
        FormFactor.tv => TvShell(navigationShell: navigationShell),
        _ => AdaptiveShell(navigationShell: navigationShell),
      };
      // Page settings can hide the branch the viewer stands on; the guard
      // walks the shell to the first visible one when that happens. The
      // startup update check rides the same shell — the reference runs it
      // from the home page, once, after the cold start settles.
      return StartupUpdateCheck(
        child: ShellBranchGuard(navigationShell: navigationShell, child: shell),
      );
    },
  );
}

/// Marks the follow branch inside the shell.
class FollowBranchData extends StatefulShellBranchData {
  /// The branch marker.
  const new();
}

/// Marks the popular branch inside the shell.
class PopularBranchData extends StatefulShellBranchData {
  /// The branch marker.
  const new();
}

/// Marks the areas branch inside the shell.
class AreasBranchData extends StatefulShellBranchData {
  /// The branch marker.
  const new();
}

/// Marks the recording centre branch inside the shell.
class RecordBranchData extends StatefulShellBranchData {
  /// The branch marker.
  const new();
}

/// The favorites branch's root route: `/` — the shell's first screen.
class FollowRoute extends GoRouteData with $FollowRoute {
  /// The follow route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const FollowPage();
}

/// The recording centre's root route: `/recorder` — the reference's record tab.
class RecorderRoute extends GoRouteData with $RecorderRoute {
  /// The recorder route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const RecorderPage();
}

/// The popular branch's root route: `/popular` — the reference's popular
/// tab, a shell branch since the tab conversion.
class PopularRoute extends GoRouteData with $PopularRoute {
  /// The popular route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const PopularPage();
}

/// The areas branch's root route: `/areas` — the reference's areas tab, a
/// shell branch since the tab conversion.
class AreasRoute extends GoRouteData with $AreasRoute {
  /// The areas route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const AreasPage();
}

/// The assembled graph: this library's shell table plus every standalone
/// route file. A `routes/<域>_routes.dart` that is annotated but not
/// listed here is a route the app cannot reach — every new file joins
/// this list.
///
/// The navigator key is the app's one global navigator: the desktop shell's
/// close prompt reaches it from outside the widget tree (app_navigator_key).
///
/// The launch route is the splash (the splash wave owns the start flow); the
/// launch-page and restore-last-tab preferences decide the branch the splash
/// hands over to, through `launchLocationFor` at the splash's handover — a
/// parked deep-link room rides above that branch (deep_link).
///
/// Two hand-off doors join the graph here. The top-level redirect rewrites a
/// cold-start `purelive://room` deep link to the room route before any
/// matching, so a cold-start link wins over the initial location (go_router
/// only falls back to that when no deep link exists). On the desktop the
/// single-instance channel's forwarded requests are answered for as long as
/// this provider lives: a second launch's room link pushes on top of
/// whatever page the app is on (deep_link).
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: appNavigatorKey,
    // The launch route is the splash: everything the boot initialises is
    // ready before the first frame, so the splash only brands the wait and
    // then hands over to the launch branch. A cold-start deep link still wins
    // over the initial location — the redirect below rewrites it before
    // matching, and go_router only falls back to the initial location.
    initialLocation: RoutePath.splash,
    redirect: launchDeepLinkRedirect,
    routes: <RouteBase>[
      ...$appRoutes,
      ...splash_routes.$appRoutes,
      ...about_routes.$appRoutes,
      ...version_routes.$appRoutes,
      ...areas_routes.$appRoutes,
      ...iptv_routes.$appRoutes,
      ...multiview_routes.$appRoutes,
      ...toolbox_routes.$appRoutes,
      ...remote_sync_routes.$appRoutes,
      ...search_routes.$appRoutes,
      ...history_routes.$appRoutes,
      ...login_routes.$appRoutes,
      ...settings_routes.$appRoutes,
    ],
  );
  // The single-instance requests a second desktop launch forwards. The
  // channel queues what arrived before this subscription exists, so a
  // cold-start payload is not lost while the splash is the only route.
  final channel = ref.watch(desktopInstanceChannelProvider);
  if (channel != null) {
    final subscription = channel.forwarded.listen((intent) => unawaited(handleLaunchIntent(ref, router, intent)));
    ref.onDispose(subscription.cancel);
  }
  return router;
});
