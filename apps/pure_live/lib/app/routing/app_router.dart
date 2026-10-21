// The app's complete route table lives in this one library.
import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/app_navigator_key.dart' show appNavigatorKey;
import 'package:pure_live/app/routing/deep_link.dart';
import 'package:pure_live/app/routing/route_paths.dart';
import 'package:pure_live/app/shell/home_shell.dart';
import 'package:pure_live/app/shell/shell_destinations.dart';
import 'package:pure_live/features/about/about_page.dart';
import 'package:pure_live/features/about/startup_update_check.dart';
import 'package:pure_live/features/about/version_history.dart' show VersionHistoryPage;
import 'package:pure_live/features/about/version_page.dart';
import 'package:pure_live/features/area_rooms/area_rooms_page.dart';
import 'package:pure_live/features/areas/areas_page.dart';
import 'package:pure_live/features/areas/followed_areas_page.dart';
import 'package:pure_live/features/backup/backup_page.dart';
import 'package:pure_live/features/follow/follow_page.dart';
import 'package:pure_live/features/history/history_page.dart';
import 'package:pure_live/features/iptv/iptv_page.dart';
import 'package:pure_live/features/iptv/iptv_play_page.dart';
import 'package:pure_live/features/login/account_page.dart';
import 'package:pure_live/features/login/cookie_editor_page.dart';
import 'package:pure_live/features/login/login_page.dart';
import 'package:pure_live/features/multiview/multiview_page.dart';
import 'package:pure_live/features/popular/popular_page.dart';
import 'package:pure_live/features/recorder/recorder_page.dart';
import 'package:pure_live/features/remote_receiver/remote_sync_page.dart';
import 'package:pure_live/features/room/room_page.dart';
import 'package:pure_live/features/search/search_page.dart';
import 'package:pure_live/features/search/web_search_view.dart';
import 'package:pure_live/features/settings/appearance/appearance_page.dart';
import 'package:pure_live/features/settings/danmaku/danmaku_settings_page.dart';
import 'package:pure_live/features/settings/data/cache_data_page.dart';
import 'package:pure_live/features/settings/fonts/font_manager_page.dart';
import 'package:pure_live/features/settings/general/general_settings_page.dart';
import 'package:pure_live/features/settings/hot_areas/hot_areas_page.dart';
import 'package:pure_live/features/settings/loading/loading_style_settings_page.dart';
import 'package:pure_live/features/settings/local_config/local_config_preview_page.dart';
import 'package:pure_live/features/settings/local_interaction/local_interaction_settings_page.dart';
import 'package:pure_live/features/settings/logs/logs_settings_page.dart';
import 'package:pure_live/features/settings/navigation/navigation_settings_page.dart';
import 'package:pure_live/features/settings/network/network_proxy_settings_page.dart';
import 'package:pure_live/features/settings/pages/page_settings_page.dart';
import 'package:pure_live/features/settings/platforms/platforms_settings_page.dart';
import 'package:pure_live/features/settings/player/mpv_settings_page.dart';
import 'package:pure_live/features/settings/recording/record_settings_page.dart';
import 'package:pure_live/features/settings/refresh/refresh_settings_page.dart';
import 'package:pure_live/features/settings/room_card/room_card_settings_page.dart';
import 'package:pure_live/features/settings/settings_page.dart';
import 'package:pure_live/features/settings/video/portrait_settings_page.dart';
import 'package:pure_live/features/settings/video/video_settings_page.dart';
import 'package:pure_live/features/shield/shield_page.dart';
import 'package:pure_live/features/splash/splash_screen.dart';
import 'package:pure_live/features/tags/tags_page.dart';
import 'package:pure_live/features/toolbox/toolbox_page.dart';
import 'package:pure_live/features/wallpaper/wallpaper_picker_page.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/platforms/tv/shell/tv_shell.dart';

part 'app_router.g.dart';

/// The app's navigation graph in typed-route form (go_router_builder).
///
/// The shell and its four branches are declared in one table here, because
/// the branch nesting is part of a single annotation. Every standalone route
/// — the settings cluster, search, rooms, the splash and the rest — also lives
/// in this library below, so a page imports one route table, not a folder of
/// route files. When a domain grows real parametrised routes, its
/// `@TypedGoRoute` annotation joins this library and the generator emits the
/// mixin into `app_router.g.dart`.
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
        _ => HomeShell(navigationShell: navigationShell),
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

// Standalone routes. Each class below used to live in its own
// `routes/<domain>/<domain>_routes.dart` library.

/// The about page: identity, update check, release notes, licenses and the
/// project page.
@TypedGoRoute<AboutRoute>(path: RoutePath.about)
class AboutRoute extends GoRouteData with $AboutRoute {
  /// The about route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const AboutPage();
}

/// The version page: `/about/version`, one level under the about cluster —
/// the reference's routed update page (3.x `RoutePath.kVersionPage`),
/// carrying the update check the about page's verdict dialogs used to open.
@TypedGoRoute<VersionRoute>(path: RoutePath.version)
class VersionRoute extends GoRouteData with $VersionRoute {
  /// The version route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const VersionPage();
}

/// The release history page: `/about/version/history` — the reference's
/// `ReleaseHistoryView`, a page rather than a sheet so the about page and
/// the version page open the same full-screen history.
@TypedGoRoute<VersionHistoryRoute>(path: RoutePath.versionHistory)
class VersionHistoryRoute extends GoRouteData with $VersionHistoryRoute {
  /// The route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const VersionHistoryPage();
}

// The areas tab's root route (`AreasRoute`, `/areas`) lives in
// `app_router.dart`, because it is a branch of the shell and the branch
// nesting is one annotation there. This file keeps the pages reached from
// the tab that render above the shell.

/// One area's room list, a full page above the shell; [areaName] rides as
/// the query and only titles the page.
@TypedGoRoute<AreaRoomsRoute>(path: RoutePath.areaRooms)
class AreaRoomsRoute extends GoRouteData with $AreaRoomsRoute {
  /// The area rooms route.
  const new({required this.siteId, required this.areaId, this.areaName = ''});

  /// The platform the area belongs to.
  final String siteId;

  /// The area's id.
  final String areaId;

  /// The area's display name.
  final String areaName;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      AreaRoomsPage(siteId: siteId, areaId: areaId, areaName: areaName);
}

/// The followed partitions, a full page above the shell — the reference's
/// `FavoriteAreasPage`, opened from the pill on the areas page.
@TypedGoRoute<FollowedAreasRoute>(path: RoutePath.followedAreas)
class FollowedAreasRoute extends GoRouteData with $FollowedAreasRoute {
  /// The followed-areas route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const FollowedAreasPage();
}

/// The backup and restore page, under the settings cluster.
@TypedGoRoute<BackupRoute>(path: RoutePath.settingsBackup)
class BackupRoute extends GoRouteData with $BackupRoute {
  /// The backup route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const BackupPage();
}

/// The watch history, pushed from the shell's menu — the reference keeps it in
/// `MenuButton`'s list (`menu_button.dart:10`), not among the tabs.
@TypedGoRoute<HistoryRoute>(path: RoutePath.history)
class HistoryRoute extends GoRouteData with $HistoryRoute {
  /// The history route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const HistoryPage();
}

/// The IPTV library page: imported playlists, their channels grouped.
@TypedGoRoute<IptvRoute>(path: RoutePath.iptv)
class IptvRoute extends GoRouteData with $IptvRoute {
  /// The IPTV route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const IptvPage();
}

/// One IPTV channel playing; [name] only titles the bar.
@TypedGoRoute<IptvPlayRoute>(path: RoutePath.iptvPlay)
class IptvPlayRoute extends GoRouteData with $IptvPlayRoute {
  /// The channel play route.
  const new({required this.channelId, this.name = ''});

  /// The library channel id.
  final String channelId;

  /// A caller-provided title hint.
  final String name;

  @override
  Widget build(BuildContext context, GoRouterState state) => IptvPlayPage(channelId: channelId, name: name);
}

/// The bilibili QR login page: `/login`, pushed from the account page.
@TypedGoRoute<LoginRoute>(path: RoutePath.login)
class LoginRoute extends GoRouteData with $LoginRoute {
  /// The login route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const LoginPage();
}

/// The account page: `/settings/account`, one level under the settings index.
@TypedGoRoute<AccountRoute>(path: RoutePath.settingsAccount)
class AccountRoute extends GoRouteData with $AccountRoute {
  /// The account route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const AccountPage();
}

/// The per-platform cookie editor: `/settings/account/cookie?site=…`, the
/// reference's one cookie page per sign-in platform. The site id is a query
/// because the editor is opened from the account hub's rows, and a deep
/// path segment (`/cookie/douyu`) would need the platform list to exist
/// before the route can be declared.
@TypedGoRoute<AccountCookieRoute>(path: RoutePath.settingsAccountCookie)
class AccountCookieRoute extends GoRouteData with $AccountCookieRoute {
  /// The editor route for [siteId].
  const new({required this.siteId});

  /// The platform whose cookie is edited.
  final String siteId;

  @override
  Widget build(BuildContext context, GoRouterState state) => CookieEditorPage(siteId: siteId);
}

/// The web search page (A09.8): the platform's search page in the app
/// where a WebView exists, handed to the system browser where it does not.
/// [url] is the built search address, [platform] its id and [keyword] the
/// words shown under the title.
@TypedGoRoute<WebSearchRoute>(path: RoutePath.webSearch)
class WebSearchRoute extends GoRouteData with $WebSearchRoute {
  /// The web search route.
  const new({required this.url, this.platform = '', this.keyword = ''});

  /// The search address to open.
  final String url;

  /// The platform being searched.
  final String platform;

  /// The words searched.
  final String keyword;

  @override
  Widget build(BuildContext context, GoRouterState state) => WebSearchView(
    request: WebSearchRequest.fromQuery(<String, String?>{
      'url': state.uri.queryParameters['url'] ?? url,
      'platform': state.uri.queryParameters['platform'] ?? platform,
      'keyword': state.uri.queryParameters['keyword'] ?? keyword,
    }),
  );
}

/// The multi-view page: up to four rooms playing side by side.
@TypedGoRoute<MultiviewRoute>(path: RoutePath.multiview)
class MultiviewRoute extends GoRouteData with $MultiviewRoute {
  /// The multiview route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const MultiviewPage();
}

/// A live room, a full page above the shell; [roomName] only titles the
/// bar until the room detail arrives.
@TypedGoRoute<RoomRoute>(path: RoutePath.room)
class RoomRoute extends GoRouteData with $RoomRoute {
  /// The room route.
  const new({required this.siteId, required this.roomId, this.roomName = ''});

  /// The platform the room belongs to.
  final String siteId;

  /// The platform-specific room id.
  final String roomId;

  /// A caller-provided title hint.
  final String roomName;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      RoomPage(siteId: siteId, roomId: roomId, roomName: roomName);
}

/// The search route: `/search`, a full page above the shell. Declared
/// apart from the shell table, like the settings route, so the home menu
/// reaches it without importing the router back.
@TypedGoRoute<SearchRoute>(path: RoutePath.search)
class SearchRoute extends GoRouteData with $SearchRoute {
  /// The search route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const SearchPage();
}

/// The settings route: `/settings`, a full page above the shell.
///
/// Declared apart from the shell table so the chrome and the pages can
/// navigate here without importing the router back. The optional [section]
/// names a `SettingsSection` value to open directly — the reference's route
/// argument (`'network'`, `'appearance'`).
@TypedGoRoute<SettingsRoute>(path: RoutePath.settings)
class SettingsRoute extends GoRouteData with $SettingsRoute {
  /// The settings route.
  const new({this.section = ''});

  /// The section to open at once, '' for the overview.
  final String section;

  @override
  Widget build(BuildContext context, GoRouterState state) => SettingsPage(section: section);
}

/// The appearance page: one level under the settings index.
@TypedGoRoute<AppearanceRoute>(path: RoutePath.settingsAppearance)
class AppearanceRoute extends GoRouteData with $AppearanceRoute {
  /// The appearance route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const AppearancePage();
}

/// The font manager: `/settings/fonts`, reached from the theme section.
@TypedGoRoute<FontManagerRoute>(path: RoutePath.settingsFonts)
class FontManagerRoute extends GoRouteData with $FontManagerRoute {
  /// The font manager route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const FontManagerPage();
}

/// The wallpaper picker: `/settings/wallpaper`, reached from the theme
/// section.
@TypedGoRoute<WallpaperRoute>(path: RoutePath.settingsWallpaper)
class WallpaperRoute extends GoRouteData with $WallpaperRoute {
  /// The wallpaper route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const WallpaperPickerPage();
}

/// Cache & data: `/settings/data`, reached from the data section.
@TypedGoRoute<CacheDataRoute>(path: RoutePath.settingsData)
class CacheDataRoute extends GoRouteData with $CacheDataRoute {
  /// The cache & data route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const CacheDataPage();
}

/// General settings: `/settings/general`, reached from the general section.
@TypedGoRoute<GeneralSettingsRoute>(path: RoutePath.settingsGeneral)
class GeneralSettingsRoute extends GoRouteData with $GeneralSettingsRoute {
  /// The general settings route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const GeneralSettingsPage();
}

/// Refresh settings: `/settings/refresh`, reached from the general section.
@TypedGoRoute<RefreshSettingsRoute>(path: RoutePath.settingsRefresh)
class RefreshSettingsRoute extends GoRouteData with $RefreshSettingsRoute {
  /// The refresh settings route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const RefreshSettingsPage();
}

/// Page settings: `/settings/pages`, reached from the general section.
@TypedGoRoute<PageSettingsRoute>(path: RoutePath.settingsPages)
class PageSettingsRoute extends GoRouteData with $PageSettingsRoute {
  /// The page settings route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const PageSettingsPage();
}

/// Navigation settings: `/settings/navigation`, reached from the general
/// section.
@TypedGoRoute<NavigationSettingsRoute>(path: RoutePath.settingsNavigation)
class NavigationSettingsRoute extends GoRouteData with $NavigationSettingsRoute {
  /// The navigation settings route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const NavigationSettingsPage();
}

/// Network proxy settings: `/settings/proxy`, reached from the network
/// section.
@TypedGoRoute<NetworkProxySettingsRoute>(path: RoutePath.settingsProxy)
class NetworkProxySettingsRoute extends GoRouteData with $NetworkProxySettingsRoute {
  /// The network proxy settings route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const NetworkProxySettingsPage();
}

/// Loading style settings: `/settings/loading-style`, reached from the feed
/// display section.
@TypedGoRoute<LoadingStyleSettingsRoute>(path: RoutePath.settingsLoadingStyle)
class LoadingStyleSettingsRoute extends GoRouteData with $LoadingStyleSettingsRoute {
  /// The loading style settings route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const LoadingStyleSettingsPage();
}

/// Room card settings: `/settings/room-card`, reached from the feed display
/// section.
@TypedGoRoute<RoomCardSettingsRoute>(path: RoutePath.settingsRoomCard)
class RoomCardSettingsRoute extends GoRouteData with $RoomCardSettingsRoute {
  /// The room card settings route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const RoomCardSettingsPage();
}

/// The video and danmaku settings: `/settings/video`.
@TypedGoRoute<VideoSettingsRoute>(path: RoutePath.settingsVideo)
class VideoSettingsRoute extends GoRouteData with $VideoSettingsRoute {
  /// The route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const VideoSettingsPage();
}

/// The mpv tuning: `/settings/mpv`, reached from the video section.
@TypedGoRoute<MpvSettingsRoute>(path: RoutePath.settingsMpv)
class MpvSettingsRoute extends GoRouteData with $MpvSettingsRoute {
  /// The route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const MpvSettingsPage();
}

/// The read-only local configuration preview: `/settings/local-config`.
@TypedGoRoute<LocalConfigPreviewRoute>(path: RoutePath.settingsLocalConfig)
class LocalConfigPreviewRoute extends GoRouteData with $LocalConfigPreviewRoute {
  /// The route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const LocalConfigPreviewPage();
}

/// The recorder: `/settings/recorder`, reached from the recording section.
@TypedGoRoute<RecorderSettingsRoute>(path: RoutePath.settingsRecorder)
class RecorderSettingsRoute extends GoRouteData with $RecorderSettingsRoute {
  /// The recorder route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const RecorderPage();
}

/// The platforms page (visibility, order, accounts, tags): the settings
/// cluster's platforms section.
@TypedGoRoute<PlatformsSettingsRoute>(path: RoutePath.settingsPlatforms)
class PlatformsSettingsRoute extends GoRouteData with $PlatformsSettingsRoute {
  /// The route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const PlatformsSettingsPage();
}

/// The danmaku settings: the settings cluster's danmaku section.
@TypedGoRoute<DanmakuSettingsRoute>(path: RoutePath.settingsDanmaku)
class DanmakuSettingsRoute extends GoRouteData with $DanmakuSettingsRoute {
  /// The route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const DanmakuSettingsPage();
}

/// The portrait-stream adaptation settings: a page of the video section.
@TypedGoRoute<PortraitSettingsRoute>(path: RoutePath.settingsPortrait)
class PortraitSettingsRoute extends GoRouteData with $PortraitSettingsRoute {
  /// The route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const PortraitSettingsPage();
}

/// The recording settings: the settings cluster's recording section.
@TypedGoRoute<RecordingSettingsRoute>(path: RoutePath.settingsRecording)
class RecordingSettingsRoute extends GoRouteData with $RecordingSettingsRoute {
  /// The route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const RecordSettingsPage();
}

/// The local interaction settings: the settings cluster's local-interaction
/// section.
@TypedGoRoute<LocalInteractionRoute>(path: RoutePath.settingsLocalInteraction)
class LocalInteractionRoute extends GoRouteData with $LocalInteractionRoute {
  /// The route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const LocalInteractionSettingsPage();
}

/// The log page: the settings cluster's log section.
@TypedGoRoute<LogsRoute>(path: RoutePath.settingsLogs)
class LogsRoute extends GoRouteData with $LogsRoute {
  /// The route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const LogsSettingsPage();
}

/// The platform visibility/order page, pushed from the platforms page.
@TypedGoRoute<HotAreasRoute>(path: RoutePath.settingsHotAreas)
class HotAreasRoute extends GoRouteData with $HotAreasRoute {
  /// The route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const HotAreasPage();
}

/// The tag manager, pushed from the platforms page.
@TypedGoRoute<TagsRoute>(path: RoutePath.settingsTags)
class TagsRoute extends GoRouteData with $TagsRoute {
  /// The route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const TagsPage();
}

/// The danmaku shield page, under the settings cluster.
@TypedGoRoute<ShieldRoute>(path: RoutePath.settingsShield)
class ShieldRoute extends GoRouteData with $ShieldRoute {
  /// The shield route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const ShieldPage();
}

/// The start-up splash: `/splash`, the launch route ahead of the shell
/// (3.x `RoutePath.kSplash`).
///
/// Everything the boot initialises — the service graph, the desktop window,
/// the provider overrides — is ready before the first frame, so the splash
/// is branding and a bounded timer only. When the timer ends the app lands
/// on the launch branch's root, replacing the splash.
@TypedGoRoute<SplashRoute>(path: RoutePath.splash)
class SplashRoute extends GoRouteData with $SplashRoute {
  /// The splash route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    // The handover target is the user's launch page (general settings), or
    // the branch the app was last left on when the navigation preference
    // asks for it — read once, when the splash routes on.
    return Consumer(
      builder: (context, ref, _) => SplashScreen(
        // A06.4: the app's own icon, 150 wide — the master image the
        // launcher icons are generated from, now bundled for the splash.
        logo: Image.asset('assets/icon/app_icon.png', width: 150, height: 150),
        showTextLogo: true,
        logoText: context.t.splash.welcome,
        loaderType: LoaderType.progressBar,
        // 显示启动页 off hands over on the first timer tick — the splash
        // still owns the route-on, it just does not linger (the reference's
        // showSplashPage).
        duration: ref.watch(appPreferencesProvider).showSplash ? const Duration(seconds: 1) : Duration.zero,
        onNextPressed: () => handOverFromSplash(context, ref),
      ),
    );
  }
}

/// The splash's route-on: the launch branch the preferences name, and any
/// room a launch handoff parked while the splash was up on top of it.
///
/// The parked room is what keeps a command-line or protocol launch from
/// losing its room to the `go` below — replacing the stack would drop
/// anything pushed during the splash, so the room waits here and is pushed
/// after the branch lands (deep_link).
void handOverFromSplash(BuildContext context, WidgetRef ref) {
  final launchLocation = launchLocationFor(ref.read(appPreferencesProvider));
  final room = ref.read(pendingLaunchRoomProvider.notifier).take();
  context.go(launchLocation);
  if (room != null) {
    unawaited(context.push(room.toRoute().location));
  }
}

/// The toolbox: link resolution, a full page above the shell.
@TypedGoRoute<ToolboxRoute>(path: RoutePath.toolbox)
class ToolboxRoute extends GoRouteData with $ToolboxRoute {
  /// The toolbox route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const ToolboxPage();
}

/// The assembled graph. Every typed route in this library is generated into
/// `$appRoutes`; the hand-written LAN-sync route joins the same table because
/// it is not annotated. A new domain route is added to this file, and the
/// generator emits its `$Route` mixin here — there is no second route file to
/// forget.
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
      // LAN sync is written by hand: it carries no @TypedGoRoute annotation,
      // so it joins the same graph here instead of a second `$appRoutes`.
      GoRoute(path: RoutePath.remoteSync, builder: (context, state) => const RemoteSyncPage()),
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
