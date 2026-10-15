import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:pure_live/app/router/routes/settings_routes.dart' as settings_routes;
import 'package:pure_live/app/shell/app_shell.dart';
import 'package:pure_live/features/follow/follow_page.dart';
import 'package:pure_live/features/history/history_page.dart';
import 'package:pure_live/features/home/home_page.dart';
import 'package:pure_live/features/popular/popular_page.dart';

part 'app_router.g.dart';

/// The app's navigation graph in typed-route form (go_router_builder).
///
/// The shell and its three branches are declared in one table here, because
/// the branch nesting is part of a single annotation; the settings route
/// lives in its own file so the chrome and the pages can reach it without
/// importing this library back. When a domain grows real parametrised
/// routes, its `routes/<域>_routes.dart` takes its own annotations and
/// joins [routerProvider] the same way the settings list does.
@TypedStatefulShellRoute<AppShellRouteData>(
  branches: <TypedStatefulShellBranch<StatefulShellBranchData>>[
    TypedStatefulShellBranch<HomeBranchData>(routes: <TypedRoute<RouteData>>[TypedGoRoute<HomeRoute>(path: '/')]),
    TypedStatefulShellBranch<FollowBranchData>(
      routes: <TypedRoute<RouteData>>[TypedGoRoute<FollowRoute>(path: '/follow')],
    ),
    TypedStatefulShellBranch<HistoryBranchData>(
      routes: <TypedRoute<RouteData>>[TypedGoRoute<HistoryRoute>(path: '/history')],
    ),
  ],
)
class AppShellRouteData extends StatefulShellRouteData {
  /// The shell around the three branches.
  const new();

  @override
  Widget builder(BuildContext context, GoRouterState state, StatefulNavigationShell navigationShell) =>
      AppShell(navigationShell: navigationShell);
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
@TypedGoRoute<PopularRoute>(path: '/popular')
class PopularRoute extends GoRouteData with $PopularRoute {
  /// The popular route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const PopularPage();
}

/// The assembled graph: this library's shell table plus the standalone
/// route files.
final routerProvider = Provider<GoRouter>(
  (ref) => GoRouter(routes: <RouteBase>[...$appRoutes, ...settings_routes.$appRoutes]),
);
