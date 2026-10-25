import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:live_iptv/live_iptv.dart' show IptvChannel;
import 'package:live_sites/live_sites.dart' show LiveArea;
import 'package:media_core/media_core.dart' show PresentationMode;
import 'package:pure_live/app/providers/presentation_providers.dart' show roomPresentationProvider;
import 'package:pure_live/app/routing/root_navigator.dart' show rootNavigatorKey;
import 'package:pure_live/app/routing/route_names.dart' show RouteNames;
import 'package:pure_live/app/routing/route_observer.dart' show routeObserver;
import 'package:pure_live/features/areas/area_rooms_page.dart' show AreaRoomsPage;
import 'package:pure_live/features/areas/areas_page.dart' show AreasPage;
import 'package:pure_live/features/favorites/favorites_page.dart' show FavoritesPage;
import 'package:pure_live/features/history/history_page.dart' show HistoryPage;
import 'package:pure_live/features/iptv/iptv_play_page.dart' show IptvPlayPage;
import 'package:pure_live/features/multiview/multiview_page.dart' show MultiviewPage;
import 'package:pure_live/features/popular/popular_page.dart' show PopularPage;
import 'package:pure_live/features/recorder/recorder_page.dart' show RecorderPage;
import 'package:pure_live/features/room/room_page.dart' show RoomPage;
import 'package:pure_live/features/search/search_page.dart' show SearchPage;
import 'package:pure_live/features/search/web_search_page.dart' show WebSearchPage, WebSearchRequest;
import 'package:pure_live/features/settings/settings_page.dart' show SettingsPage, SettingsSectionPane;
import 'package:pure_live/features/settings/settings_sections.dart' show SettingsSection;
import 'package:pure_live/features/toolbox/toolbox_page.dart' show ToolboxPage;
import 'package:pure_live/features/vod/vod_video_page.dart' show VodVideoPage;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/layouts/app_layout.dart' show AppLayout;
import 'package:pure_live/layouts/desktop/title_bar.dart' show WindowChromeFrame;
import 'package:pure_live/shared/enums/navigation_item.dart' show NavigationItem;

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
    final parsed = SettingsSection.of(section) ?? SettingsSection.personalization;
    return _SettingsSectionScreen(section: parsed);
  }
}

/// The pushed section's screen: the pane alone under an app bar whose back
/// leads to the settings menu.
final class _SettingsSectionScreen extends StatelessWidget {
  const _SettingsSectionScreen({required this.section});

  final SettingsSection section;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final t = context.t;
    return WindowChromeFrame(
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          backgroundColor: colors.surface,
          surfaceTintColor: const Color(0x00000000),
          elevation: 0,
          title: Text(t.settings.title),
        ),
        body: SettingsSectionPane(section: section),
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
    child: AreaRoomsPage(
      platform: platform,
      areaId: areaId,
      area: switch (state.extra) {
        final LiveArea area => area,
        _ => null,
      },
    ),
  );
}

/// Where a freshly started engine opens. The primary uses the home branch;
/// a clone overrides it with the route in its launch arguments.
final windowInitialRouteProvider = Provider<String>((ref) => const PopularRoute().location);

/// The app's router: the generated typed routes under the shell route, the
/// route observer installed for the features that need visibility later.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    observers: [routeObserver],
    initialLocation: ref.watch(windowInitialRouteProvider),
    routes: [
      ...$appRoutes,
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
