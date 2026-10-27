import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:live_iptv/live_iptv.dart' show IptvChannel;
import 'package:live_sites/live_sites.dart' show LiveArea;
import 'package:media_core/media_core.dart' show PresentationMode;
import 'package:pure_live/app/navigation/navigation.dart' show navigationOf;
import 'package:pure_live/app/providers/providers.dart';
import 'package:pure_live/app/routing/navigation/root_navigator.dart' show rootNavigatorKey;
import 'package:pure_live/app/routing/navigation/route_names.dart' show RouteNames;
import 'package:pure_live/app/routing/navigation/route_observer.dart' show routeObserverProvider;
import 'package:pure_live/features/areas/areas.dart';
import 'package:pure_live/features/favorites/favorites.dart';
import 'package:pure_live/features/history/history.dart';
import 'package:pure_live/features/iptv/iptv.dart';
import 'package:pure_live/features/multiview/multiview.dart';
import 'package:pure_live/features/popular/popular.dart';
import 'package:pure_live/features/recorder/recorder.dart';
import 'package:pure_live/features/room/room.dart';
import 'package:pure_live/features/search/search.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/features/toolbox/toolbox.dart';
import 'package:pure_live/features/vod/vod.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/layouts/layouts.dart';
import 'package:pure_live/shared/shared.dart';

part 'app_router.g.dart';

/// The shell route: one indexed stack, seven branches — one per navigation
/// destination — laid out by [AppLayout] (which picks the desktop, mobile
/// or TV chrome per device).
@TypedStatefulShellRoute<AppShellRoute>(
  branches: <TypedStatefulShellBranch<StatefulShellBranchData>>[
    TypedStatefulShellBranch<PopularBranch>(
      routes: <TypedRoute<RouteData>>[TypedGoRoute<PopularRoute>(path: RouteNames.popular)],
    ),
    TypedStatefulShellBranch<ZonesBranch>(
      routes: <TypedRoute<RouteData>>[TypedGoRoute<ZonesRoute>(path: RouteNames.zones)],
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
    TypedStatefulShellBranch<MultiviewBranch>(
      routes: <TypedRoute<RouteData>>[TypedGoRoute<MultiviewRoute>(path: RouteNames.multiview)],
    ),
    TypedStatefulShellBranch<RecorderBranch>(
      routes: <TypedRoute<RouteData>>[TypedGoRoute<RecorderRoute>(path: RouteNames.recorder)],
    ),
    TypedStatefulShellBranch<ToolboxBranch>(
      routes: <TypedRoute<RouteData>>[TypedGoRoute<ToolboxRoute>(path: RouteNames.toolbox)],
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

/// The popular branch's token.
final class PopularBranch extends StatefulShellBranchData {
  /// The branch token.
  const PopularBranch();
}

/// The zones branch's token.
final class ZonesBranch extends StatefulShellBranchData {
  /// The branch token.
  const ZonesBranch();
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

/// The multi-view branch's token.
final class MultiviewBranch extends StatefulShellBranchData {
  /// The branch token.
  const MultiviewBranch();
}

/// The recording branch's token.
final class RecorderBranch extends StatefulShellBranchData {
  /// The branch token.
  const RecorderBranch();
}

/// The toolbox branch's token.
final class ToolboxBranch extends StatefulShellBranchData {
  /// The branch token.
  const ToolboxBranch();
}

/// The settings branch's token.
final class SettingsBranch extends StatefulShellBranchData {
  /// The branch token.
  const SettingsBranch();
}

/// The popular branch's screen.
final class PopularRoute extends GoRouteData with $PopularRoute {
  /// The popular route.
  const PopularRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const PopularPage();
}

/// The zones branch's screen.
final class ZonesRoute extends GoRouteData with $ZonesRoute {
  /// The zones route.
  const ZonesRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const AreasPage();
}

/// The live branch's screen.
final class LiveRoute extends GoRouteData with $LiveRoute {
  /// The live route.
  const LiveRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const _DestinationPlaceholder(item: NavigationItem.live);
}

/// The favorites branch's screen.
final class FavoritesRoute extends GoRouteData with $FavoritesRoute {
  /// The favorites route.
  const FavoritesRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const FavoritesPage();
}

/// The history branch's screen.
final class HistoryRoute extends GoRouteData with $HistoryRoute {
  /// The history route.
  const HistoryRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const HistoryPage();
}

/// The search branch's screen.
final class SearchRoute extends GoRouteData with $SearchRoute {
  /// The search route.
  const SearchRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const SearchPage();
}

/// The multi-view branch's screen.
final class MultiviewRoute extends GoRouteData with $MultiviewRoute {
  /// The multiview route.
  const MultiviewRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const MultiviewPage();
}

/// The recording branch's screen.
final class RecorderRoute extends GoRouteData with $RecorderRoute {
  /// The recorder route.
  const RecorderRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const RecorderPage();
}

/// The toolbox branch's screen.
final class ToolboxRoute extends GoRouteData with $ToolboxRoute {
  /// The toolbox route.
  const ToolboxRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const ToolboxPage();
}

/// The settings branch's screen.
final class SettingsRoute extends GoRouteData with $SettingsRoute {
  /// The settings route.
  const SettingsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const SettingsPage();
}

/// One settings section as its own pushed route: the phone's settings menu
/// navigates into submenus; on the desktop the pane switches in place and
/// never opens this route.
@TypedGoRoute<SettingsSectionRoute>(path: RouteNames.settingsSection)
final class SettingsSectionRoute extends GoRouteData with $SettingsSectionRoute {
  /// The route into [section].
  const SettingsSectionRoute({required this.section});

  /// The section's enum name.
  final String section;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    final parsed = SettingsSection.of(section) ?? SettingsSection.theme;
    return _SettingsSectionScreen(section: parsed);
  }
}

/// The pushed section's screen: the pane alone under a page header whose
/// back leads to its category.
final class _SettingsSectionScreen extends StatelessWidget {
  const _SettingsSectionScreen({required this.section});

  final SettingsSection section;

  @override
  Widget build(BuildContext context) {
    return _SettingsSubpage(
      title: section.label(context.t),
      pageIdentity: 'settings/${section.name}',
      child: SettingsSectionPane(section: section),
    );
  }
}

/// One category's screen: its sections as rows, each opening its own page.
/// The phone's second level — the settings list opens a category, the
/// category opens a section.
final class _SettingsCategoryScreen extends ConsumerWidget {
  const _SettingsCategoryScreen({required this.category});

  /// The group key from the route.
  final String category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final groups = navigationOf(ref.watch(selectedModuleProvider)).settingsGroups;
    final group = groups.where((group) => group.labelKey == category).firstOrNull ?? groups.first;
    return _SettingsSubpage(
      title: settingsGroupLabel(t, group.labelKey),
      pageIdentity: 'settings/category/${group.labelKey}',
      child: SettingsCategoryPane(
        group: group,
        onOpen: (section) {
          openSettingsSection(ref, section);
          unawaited(context.push(SettingsSectionRoute(section: section.name).location));
        },
      ),
    );
  }
}

/// The shared shell of a pushed settings page: the window's caption strip,
/// a desen page header with its back button, then the page's own scroll.
final class _SettingsSubpage extends StatelessWidget {
  const _SettingsSubpage({required this.title, required this.pageIdentity, required this.child});

  /// The page's name in the header.
  final String title;

  /// What the scroll pair watches.
  final String pageIdentity;

  /// The page under the header.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final t = context.t;
    return WindowChromeFrame(
      child: Scaffold(
        backgroundColor: colors.surface,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DsPaneHeader(
                title: Row(
                  children: [
                    DsButton.icon(
                      variant: DsButtonVariant.ghost,
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const DsIcon(DsIcons.chevronLeft),
                      semanticLabel: t.common.back,
                    ),
                    const SizedBox(width: DsSpace.s4),
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.title.copyWith(color: colors.text),
                      ),
                    ),
                  ],
                ),
              ),
              // A pushed page is outside the shell's content area, so it
              // carries the scroll pair itself.
              Expanded(
                child: ScrollEdgeControls(pageIdentity: pageIdentity, child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The live room detail, pushed on the root navigator above the shell: one
/// room at a time, back returns to where it was opened from.
@TypedGoRoute<RoomRoute>(path: RouteNames.room)
final class RoomRoute extends GoRouteData with $RoomRoute {
  /// The room detail over [platform] and [roomId].
  const RoomRoute({required this.platform, required this.roomId});

  /// The room's platform id.
  final String platform;

  /// The room's platform room id.
  final String roomId;

  @override
  Widget build(BuildContext context, GoRouterState state) => _PlayerWindowChrome(
    child: RoomPage(platform: platform, roomId: roomId),
  );
}

/// One area's rooms (the reference's `kAreaRooms`), pushed on the root
/// navigator above the shell. The [LiveArea] object rides in as the push's
/// `extra` when the route was opened in-app; a deep link without it shows
/// the area's id.
@TypedGoRoute<AreaRoomsRoute>(path: RouteNames.areaRooms)
final class AreaRoomsRoute extends GoRouteData with $AreaRoomsRoute {
  /// The rooms of [areaId] on [platform].
  const AreaRoomsRoute({required this.platform, required this.areaId});

  /// The area's platform id.
  final String platform;

  /// The area's id.
  final String areaId;

  @override
  Widget build(BuildContext context, GoRouterState state) => WindowChromeFrame(
    // Outside the shell's content area, so this page carries the scroll
    // pair itself.
    child: ScrollEdgeControls(
      pageIdentity: 'areaRooms/$platform/$areaId',
      child: AreaRoomsPage(
        platform: platform,
        areaId: areaId,
        area: switch (state.extra) {
          final LiveArea area => area,
          _ => null,
        },
      ),
    ),
  );
}

/// Where a window opens when no route is named.
final windowInitialRouteProvider = Provider<String>((ref) => const PopularRoute().location);

/// Builds one window's router.
///
/// Every OS window gets its own [GoRouter] and its own navigator key: sharing
/// either would make a push in one window move another. The primary uses the
/// app-wide [rootNavigatorKey] because the close dialog and the shell read it;
/// secondary windows pass a fresh key.
/// Builds one window's router.
///
/// Every OS window gets its own [GoRouter], navigator key and route observer:
/// sharing any of them would make a push in one window move another, and
/// Flutter rejects one observer attached to two navigators. The primary uses
/// the app-wide [rootNavigatorKey] because the close dialog and the shell read
/// it; secondary windows pass a fresh key.
GoRouter buildAppRouter({
  required String initialLocation,
  required GlobalKey<NavigatorState> navigatorKey,
  required RouteObserver<ModalRoute<void>> observer,
}) {
  return GoRouter(
    navigatorKey: navigatorKey,
    observers: [observer],
    initialLocation: initialLocation,
    // There is no route at the bare root: the shell's branches start at
    // /popular and every other page is pushed above them. A '/' can still
    // arrive from a stale launch argument or a restored location, and it
    // must land on the home branch rather than on GoRouter's error page.
    redirect: (context, state) => state.uri.path == '/' ? const PopularRoute().location : null,
    routes: [
      ...$appRoutes,
      // A category's page, written by hand beside the generated section
      // route: the phone's settings list pushes it, and its rows push the
      // section pages above it.
      GoRoute(
        path: RouteNames.settingsCategory,
        builder: (context, state) => _SettingsCategoryScreen(category: state.pathParameters['category']!),
      ),
      GoRoute(
        path: RouteNames.iptvPlay,
        builder: (context, state) => _PlayerWindowChrome(
          child: IptvPlayPage(
            channelId: state.pathParameters['channelId']!,
            channel: switch (state.extra) {
              final IptvChannel channel => channel,
              _ => null,
            },
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.webSearch,
        builder: (context, state) => WindowChromeFrame(
          child: WebSearchPage(
            request: switch (state.extra) {
              final WebSearchRequest request => request,
              _ => null,
            },
          ),
        ),
      ),
      // The video station's cards push one archive's page; the route is
      // written by hand rather than generated, so a cards-only change never
      // needs a build_runner pass (which would rewrite the l10n output).
      GoRoute(
        path: RouteNames.vodVideo,
        builder: (context, state) => _PlayerWindowChrome(child: VodVideoPage(bvid: state.pathParameters['bvid']!)),
      ),
    ],
  );
}

/// The primary window's default router, used by the mobile/TV roots and by
/// tests that build the app without an OS window.
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = buildAppRouter(
    initialLocation: ref.watch(windowInitialRouteProvider),
    navigatorKey: rootNavigatorKey,
    observer: ref.watch(routeObserverProvider),
  );
  ref.onDispose(router.dispose);
  return router;
});

/// A player route keeps the window's caption strip while it is a windowed
/// page; a presentation that fills the window (fullscreen or the in-window
/// fullscreen) hides it, exactly as the system caption would. PiP and a
/// floating player keep it: those are still ordinary windows.
final class _PlayerWindowChrome extends ConsumerWidget {
  const _PlayerWindowChrome({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(roomPresentationProvider);
    final immersive = mode == PresentationMode.fullscreen || mode == PresentationMode.windowFullscreen;
    return WindowChromeFrame(enabled: !immersive, child: child);
  }
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
