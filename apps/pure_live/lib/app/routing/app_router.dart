import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_live/app/routing/route_names.dart' show RouteNames;
import 'package:pure_live/app/routing/route_observer.dart' show routeObserver;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/layouts/app_layout.dart' show AppLayout;
import 'package:pure_live/shared/enums/navigation_item.dart' show NavigationItem;

part 'app_router.g.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// The shell route: one indexed stack, seven branches — one per navigation
/// destination — laid out by [AppLayout] (which picks the desktop, mobile
/// or TV chrome per device).
@TypedStatefulShellRoute<AppShellRoute>(
  branches: <TypedStatefulShellBranch<StatefulShellBranchData>>[
    TypedStatefulShellBranch<HomeBranch>(
      routes: <TypedRoute<RouteData>>[TypedGoRoute<HomeRoute>(path: RouteNames.home)],
    ),
    TypedStatefulShellBranch<LiveBranch>(
      routes: <TypedRoute<RouteData>>[TypedGoRoute<LiveRoute>(path: RouteNames.live)],
    ),
    TypedStatefulShellBranch<FavoritesBranch>(
      routes: <TypedRoute<RouteData>>[TypedGoRoute<FavoritesRoute>(path: RouteNames.favorites)],
    ),
    TypedStatefulShellBranch<HistoryBranch>(
      routes: <TypedRoute<RouteData>>[TypedGoRoute<HistoryRoute>(path: RouteNames.history)],
    ),
    TypedStatefulShellBranch<SearchBranch>(
      routes: <TypedRoute<RouteData>>[TypedGoRoute<SearchRoute>(path: RouteNames.search)],
    ),
    TypedStatefulShellBranch<PlaylistBranch>(
      routes: <TypedRoute<RouteData>>[TypedGoRoute<PlaylistRoute>(path: RouteNames.playlist)],
    ),
    TypedStatefulShellBranch<SettingsBranch>(
      routes: <TypedRoute<RouteData>>[TypedGoRoute<SettingsRoute>(path: RouteNames.settings)],
    ),
  ],
)
final class AppShellRoute extends StatefulShellRouteData {
  /// The shell route.
  const AppShellRoute();

  @override
  Widget builder(BuildContext context, GoRouterState state, StatefulNavigationShell navigationShell) {
    return AppLayout(shell: navigationShell);
  }
}

/// The home branch's token.
final class HomeBranch extends StatefulShellBranchData {
  /// The branch token.
  const HomeBranch();
}

/// The live branch's token.
final class LiveBranch extends StatefulShellBranchData {
  /// The branch token.
  const LiveBranch();
}

/// The favorites branch's token.
final class FavoritesBranch extends StatefulShellBranchData {
  /// The branch token.
  const FavoritesBranch();
}

/// The history branch's token.
final class HistoryBranch extends StatefulShellBranchData {
  /// The branch token.
  const HistoryBranch();
}

/// The search branch's token.
final class SearchBranch extends StatefulShellBranchData {
  /// The branch token.
  const SearchBranch();
}

/// The playlist branch's token.
final class PlaylistBranch extends StatefulShellBranchData {
  /// The branch token.
  const PlaylistBranch();
}

/// The settings branch's token.
final class SettingsBranch extends StatefulShellBranchData {
  /// The branch token.
  const SettingsBranch();
}

/// The home branch's screen.
@TypedGoRoute<HomeRoute>(path: RouteNames.home)
final class HomeRoute extends GoRouteData with $HomeRoute {
  /// The home route.
  const HomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const _DestinationPlaceholder(item: NavigationItem.home);
}

/// The live branch's screen.
@TypedGoRoute<LiveRoute>(path: RouteNames.live)
final class LiveRoute extends GoRouteData with $LiveRoute {
  /// The live route.
  const LiveRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const _DestinationPlaceholder(item: NavigationItem.live);
}

/// The favorites branch's screen.
@TypedGoRoute<FavoritesRoute>(path: RouteNames.favorites)
final class FavoritesRoute extends GoRouteData with $FavoritesRoute {
  /// The favorites route.
  const FavoritesRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const _DestinationPlaceholder(item: NavigationItem.favorites);
}

/// The history branch's screen.
@TypedGoRoute<HistoryRoute>(path: RouteNames.history)
final class HistoryRoute extends GoRouteData with $HistoryRoute {
  /// The history route.
  const HistoryRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const _DestinationPlaceholder(item: NavigationItem.history);
}

/// The search branch's screen.
@TypedGoRoute<SearchRoute>(path: RouteNames.search)
final class SearchRoute extends GoRouteData with $SearchRoute {
  /// The search route.
  const SearchRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const _DestinationPlaceholder(item: NavigationItem.search);
}

/// The playlist branch's screen.
@TypedGoRoute<PlaylistRoute>(path: RouteNames.playlist)
final class PlaylistRoute extends GoRouteData with $PlaylistRoute {
  /// The playlist route.
  const PlaylistRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const _DestinationPlaceholder(item: NavigationItem.playlist);
}

/// The settings branch's screen.
@TypedGoRoute<SettingsRoute>(path: RouteNames.settings)
final class SettingsRoute extends GoRouteData with $SettingsRoute {
  /// The settings route.
  const SettingsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const _DestinationPlaceholder(item: NavigationItem.settings);
}

/// The app's router: the generated typed routes under the shell route, the
/// route observer installed for the features that need visibility later.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    observers: [routeObserver],
    initialLocation: const HomeRoute().location,
    routes: $appRoutes,
  );
});

/// The branch content until the pages arrive: an honest empty state naming
/// the destination.
final class _DestinationPlaceholder extends StatelessWidget {
  const _DestinationPlaceholder({required this.item});

  final NavigationItem item;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Center(
      child: DsEmptyState(title: Text(item.label(t)), icon: DsIcon(item.icon)),
    );
  }
}
