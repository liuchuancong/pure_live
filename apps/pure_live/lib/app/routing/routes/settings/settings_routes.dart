import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_live/app/routing/route_paths.dart';
import 'package:pure_live/features/recorder/recorder_page.dart';
import 'package:pure_live/features/settings/appearance/appearance_page.dart';
import 'package:pure_live/features/settings/data/cache_data_page.dart';
import 'package:pure_live/features/settings/fonts/font_manager_page.dart';
import 'package:pure_live/features/settings/general/general_settings_page.dart';
import 'package:pure_live/features/settings/loading/loading_style_settings_page.dart';
import 'package:pure_live/features/settings/local_config/local_config_preview_page.dart';
import 'package:pure_live/features/settings/navigation/navigation_settings_page.dart';
import 'package:pure_live/features/settings/network/network_proxy_settings_page.dart';
import 'package:pure_live/features/settings/pages/page_settings_page.dart';
import 'package:pure_live/features/settings/player/mpv_settings_page.dart';
import 'package:pure_live/features/settings/refresh/refresh_settings_page.dart';
import 'package:pure_live/features/settings/room_card/room_card_settings_page.dart';
import 'package:pure_live/features/settings/settings_page.dart';
import 'package:pure_live/features/settings/video/video_settings_page.dart';
import 'package:pure_live/features/wallpaper/wallpaper_picker_page.dart';

part 'settings_routes.g.dart';

/// The settings route: `/settings`, a full page above the shell.
///
/// Declared apart from the shell table so the chrome and the pages can
/// navigate here without importing the router back.
@TypedGoRoute<SettingsRoute>(path: RoutePath.settings)
class SettingsRoute extends GoRouteData with $SettingsRoute {
  /// The settings route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const SettingsPage();
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
