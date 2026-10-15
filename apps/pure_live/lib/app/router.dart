import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:pure_live/app/adaptive_shell.dart';
import 'package:pure_live/background_demo_page.dart';
import 'package:pure_live/features/follow/follow_page.dart';
import 'package:pure_live/features/history/history_page.dart';
import 'package:pure_live/features/home/home_page.dart';
import 'package:pure_live/features/settings/appearance_page.dart';
import 'package:pure_live/features/settings/settings_page.dart';

part 'router.g.dart';

/// The navigation destinations that live inside the adaptive shell (rail on
/// desktop/TV, bottom bar on touch). Settings and the background demo sit
/// outside it as full pages: they read as "pushed over" the shell on every form
/// factor, and the shell keeps no branch state for them.
@TypedStatefulShellRoute<AppShellRoute>(
  branches: <TypedStatefulShellBranch<StatefulShellBranchData>>[
    TypedStatefulShellBranch<HomeBranch>(routes: <TypedRoute<RouteData>>[TypedGoRoute<HomeRoute>(path: '/')]),
    TypedStatefulShellBranch<FollowBranch>(routes: <TypedRoute<RouteData>>[TypedGoRoute<FollowRoute>(path: '/follow')]),
    TypedStatefulShellBranch<HistoryBranch>(
      routes: <TypedRoute<RouteData>>[TypedGoRoute<HistoryRoute>(path: '/history')],
    ),
  ],
)
class AppShellRoute extends StatefulShellRouteData {
  /// The shell route.
  const new();

  @override
  Widget builder(BuildContext context, GoRouterState state, StatefulNavigationShell navigationShell) =>
      AdaptiveShell(navigationShell: navigationShell);
}

/// Home branch identity for [AppShellRoute].
class HomeBranch extends StatefulShellBranchData {
  /// Home branch.
  const new();
}

/// Follow branch identity for [AppShellRoute].
class FollowBranch extends StatefulShellBranchData {
  /// Follow branch.
  const new();
}

/// History branch identity for [AppShellRoute].
class HistoryBranch extends StatefulShellBranchData {
  /// History branch.
  const new();
}

/// The home branch route.
class HomeRoute extends GoRouteData with $HomeRoute {
  /// The home route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const HomePage();
}

/// The followed-rooms branch route.
class FollowRoute extends GoRouteData with $FollowRoute {
  /// The follow route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const FollowPage();
}

/// The watch-history branch route.
class HistoryRoute extends GoRouteData with $HistoryRoute {
  /// The history route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const HistoryPage();
}

/// The settings index, pushed over the shell.
@TypedGoRoute<SettingsRoute>(path: '/settings')
class SettingsRoute extends GoRouteData with $SettingsRoute {
  /// The settings route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const SettingsPage();
}

/// The appearance editor, pushed over the settings index.
@TypedGoRoute<AppearanceRoute>(path: '/settings/appearance')
class AppearanceRoute extends GoRouteData with $AppearanceRoute {
  /// The appearance route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const AppearancePage();
}

/// Reachable while the two `LiveBackground` implementations are under visual
/// acceptance (ADR 0005); nothing in the shell links here, and the page goes
/// away once that decision lands.
@TypedGoRoute<BackgroundDemoRoute>(path: '/dev/background')
class BackgroundDemoRoute extends GoRouteData with $BackgroundDemoRoute {
  /// The background demo route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const BackgroundDemoPage();
}

/// Builds the application router; one instance lives in `appRouterProvider`.
GoRouter createAppRouter() => GoRouter(initialLocation: const HomeRoute().location, routes: $appRoutes);
