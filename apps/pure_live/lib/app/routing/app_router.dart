import 'package:flutter/widgets.dart' show GlobalKey, NavigatorState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_live/app/routing/route_names.dart' show RouteNames;
import 'package:pure_live/app/routing/route_observer.dart' show routeObserver;
import 'package:pure_live/app/shell/app_shell.dart' show AppShell;
import 'package:pure_live/app/shell/navigation/navigation_item.dart' show NavigationItem;
import 'package:pure_live/features/player/presentation/pages/player_page.dart' show PlayerPage;

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

GlobalKey<NavigatorState> _branchKey(NavigationItem item) => GlobalKey<NavigatorState>(debugLabel: item.route);

/// The app's router: one indexed-stack shell whose branches are the
/// navigation items, plus the screens pushed above it.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    observers: [routeObserver],
    initialLocation: RouteNames.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          for (final item in NavigationItem.values)
            StatefulShellBranch(
              navigatorKey: _branchKey(item),
              routes: [GoRoute(path: item.route, builder: (context, state) => item.page())],
            ),
        ],
      ),
      GoRoute(
        path: RouteNames.player,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PlayerPage(),
      ),
    ],
  );
});
