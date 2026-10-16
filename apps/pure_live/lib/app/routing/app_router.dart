import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:pure_live/app/navigation/app_navigator_key.dart' show appNavigatorKey;
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/route_paths.dart';
import 'package:pure_live/app/routing/routes/about/about_routes.dart' as about_routes;
import 'package:pure_live/app/routing/routes/areas/areas_routes.dart' as areas_routes;
import 'package:pure_live/app/routing/routes/iptv/iptv_routes.dart' as iptv_routes;
import 'package:pure_live/app/routing/routes/multiview/multiview_routes.dart' as multiview_routes;
import 'package:pure_live/app/routing/routes/search/search_routes.dart' as search_routes;
import 'package:pure_live/app/routing/routes/settings/settings_routes.dart' as settings_routes;
import 'package:pure_live/app/routing/routes/toolbox/toolbox_routes.dart' as toolbox_routes;
import 'package:pure_live/features/follow/follow_page.dart';
import 'package:pure_live/features/history/history_page.dart';
import 'package:pure_live/features/home/home_page.dart';
import 'package:pure_live/features/popular/popular_page.dart';
import 'package:pure_live/platforms/desktop/shell/desktop_shell.dart';
import 'package:pure_live/platforms/mobile/shell/mobile_shell.dart';
import 'package:pure_live/platforms/tablet/shell/tablet_shell.dart';
import 'package:pure_live/platforms/tv/shell/tv_shell.dart';

part 'app_router.g.dart';

/// The app's navigation graph in typed-route form (go_router_builder).
///
/// The shell and its three branches are declared in one table here, because
/// the branch nesting is part of a single annotation; the settings and
/// search routes live in their own files so the chrome and the pages can
/// reach them without importing this library back. When a domain grows real
/// parametrised routes, its `routes/<域>_routes.dart` takes its own
/// annotations and joins [routerProvider] the same way those two lists do.
@TypedStatefulShellRoute<AppShellRouteData>(
  branches: <TypedStatefulShellBranch<StatefulShellBranchData>>[
    TypedStatefulShellBranch<HomeBranchData>(
      routes: <TypedRoute<RouteData>>[TypedGoRoute<HomeRoute>(path: RoutePath.home)],
    ),
    TypedStatefulShellBranch<FollowBranchData>(
      routes: <TypedRoute<RouteData>>[TypedGoRoute<FollowRoute>(path: RoutePath.follow)],
    ),
    TypedStatefulShellBranch<HistoryBranchData>(
      routes: <TypedRoute<RouteData>>[TypedGoRoute<HistoryRoute>(path: RoutePath.history)],
    ),
  ],
)
class AppShellRouteData extends StatefulShellRouteData {
  /// The shell around the three branches.
  const new();

  @override
  Widget builder(BuildContext context, GoRouterState state, StatefulNavigationShell navigationShell) => Consumer(
    builder: (context, ref, _) => switch (ref.watch(environmentProvider).runtime.formFactor) {
      FormFactor.phone => MobileShell(navigationShell: navigationShell),
      FormFactor.tablet => TabletShell(navigationShell: navigationShell),
      FormFactor.tv => TvShell(navigationShell: navigationShell),
      FormFactor.desktop => DesktopShell(navigationShell: navigationShell),
    },
  );
}

/// Marks the home branch inside the shell.
class HomeBranchData extends StatefulShellBranchData {
  /// The branch marker.
  const new();
}

/// Marks the follow branch inside the shell.
class FollowBranchData extends StatefulShellBranchData {
  /// The branch marker.
  const new();
}

/// Marks the history branch inside the shell.
class HistoryBranchData extends StatefulShellBranchData {
  /// The branch marker.
  const new();
}

/// The home branch's root route: `/`.
class HomeRoute extends GoRouteData with $HomeRoute {
  /// The home route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const HomePage();
}

/// The follow branch's root route: `/follow`.
class FollowRoute extends GoRouteData with $FollowRoute {
  /// The follow route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const FollowPage();
}

/// The history branch's root route: `/history`.
class HistoryRoute extends GoRouteData with $HistoryRoute {
  /// The history route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const HistoryPage();
}

/// The popular page: every platform's recommend feed, a full page above the
/// shell.
@TypedGoRoute<PopularRoute>(path: RoutePath.popular)
class PopularRoute extends GoRouteData with $PopularRoute {
  /// The popular route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const PopularPage();
}

/// The assembled graph: this library's shell table plus every standalone
/// route file. A `routes/<域>_routes.dart` that is annotated but not
/// listed here is a route the app cannot reach — every new file joins
/// this list.
///
/// The navigator key is the app's one global navigator: the desktop shell's
/// close prompt reaches it from outside the widget tree (app_navigator_key).
final routerProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    navigatorKey: appNavigatorKey,
    routes: <RouteBase>[
      ...$appRoutes,
      ...about_routes.$appRoutes,
      ...areas_routes.$appRoutes,
      ...iptv_routes.$appRoutes,
      ...multiview_routes.$appRoutes,
      ...toolbox_routes.$appRoutes,
      ...search_routes.$appRoutes,
      ...settings_routes.$appRoutes,
    ],
  ),
);
