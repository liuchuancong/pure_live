import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_live/app/routing/route_names.dart' show RouteNames;
import 'package:pure_live/app/routing/route_observer.dart' show routeObserver;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/layouts/app_layout.dart' show AppLayout;
import 'package:pure_live/shared/enums/navigation_item.dart' show NavigationItem, kNavigationItems;

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// The app's router: one indexed-stack shell whose branches are the
/// navigation destinations, laid out by [AppLayout] (which picks the
/// desktop, mobile or TV chrome per device).
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    observers: [routeObserver],
    initialLocation: RouteNames.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppLayout(shell: shell),
        branches: [
          for (final item in kNavigationItems)
            StatefulShellBranch(
              navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'branch-${item.name}'),
              routes: [
                GoRoute(
                  path: item.route,
                  builder: (context, state) => _DestinationPlaceholder(item: item),
                ),
              ],
            ),
        ],
      ),
    ],
  );
});

/// The route path of a destination.
extension NavigationItemRoute on NavigationItem {
  /// The branch's path, from [RouteNames].
  String get route => switch (this) {
    NavigationItem.home => RouteNames.home,
    NavigationItem.live => RouteNames.live,
    NavigationItem.favorites => RouteNames.favorites,
    NavigationItem.history => RouteNames.history,
    NavigationItem.search => RouteNames.search,
    NavigationItem.playlist => RouteNames.playlist,
    NavigationItem.settings => RouteNames.settings,
  };
}

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
