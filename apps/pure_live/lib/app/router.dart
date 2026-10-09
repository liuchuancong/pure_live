// Module: lib/app/router.dart
// Purpose: Route table for the application shell and the standalone room screen.
// Author: liuchuancong
// Created: 2026-10-09
//
// go_router replaces the v1 GetX routing. The three bottom branches share one
// IndexedStack so switching tabs keeps each tab's state; the room route sits
// outside the shell because a live room takes over the whole surface, including
// on TV where the navigation chrome must not be reachable.

import 'package:go_router/go_router.dart';
import 'package:pure_live_platform/pure_live_platform.dart';

import '../features/follow/follow_page.dart';
import '../features/plugins/plugin_host_page.dart';
import '../features/home/home_page.dart';
import '../features/room/room_page.dart';
import '../features/search/search_page.dart';
import '../features/settings/settings_page.dart';
import '../features/shell/app_shell.dart';
import '../features/vod/vod_detail_page.dart';

/// Root locations of the three navigation branches, index-aligned with the
/// destinations in [AppShell].
const List<String> branchLocations = <String>['/home', '/follow', '/settings'];

/// Builds the application router. Fresh instance per call; ownership is with
/// [di.routerProvider].
GoRouter buildGoRouter() {
  return GoRouter(
    initialLocation: branchLocations.first,
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[GoRoute(path: '/home', builder: (context, state) => const HomePage())],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[GoRoute(path: '/follow', builder: (context, state) => const FollowPage())],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[GoRoute(path: '/settings', builder: (context, state) => const SettingsPage())],
          ),
        ],
      ),
      GoRoute(path: '/search', builder: (context, state) => const SearchPage()),
      GoRoute(path: '/plugins', builder: (context, state) => const PluginHostPage()),
      GoRoute(
        path: '/vod/:sourceId/:vodId',
        builder: (context, state) => VodDetailPage(
          sourceId: state.pathParameters['sourceId']!,
          vodId: Uri.decodeComponent(state.pathParameters['vodId']!),
        ),
      ),
      GoRoute(
        path: '/room/:roomId',
        builder: (context, state) => RoomPage(
          roomId: state.pathParameters['roomId']!,
          // The card hands the ref over so the room can resolve a ticket from the source it came from;
          // a deep link without an extra still opens the room on its placeholder surface.
          contentRef: state.extra is ContentRef ? state.extra! as ContentRef : null,
        ),
      ),
    ],
  );
}
