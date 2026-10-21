// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
  $appShellRouteData,
  $aboutRoute,
  $versionRoute,
  $versionHistoryRoute,
  $areaRoomsRoute,
  $followedAreasRoute,
  $backupRoute,
  $iptvPlayRoute,
  $loginRoute,
  $accountRoute,
  $accountCookieRoute,
  $webSearchRoute,
  $roomRoute,
  $settingsRoute,
  $appearanceRoute,
  $fontManagerRoute,
  $wallpaperRoute,
  $cacheDataRoute,
  $generalSettingsRoute,
  $refreshSettingsRoute,
  $pageSettingsRoute,
  $navigationSettingsRoute,
  $networkProxySettingsRoute,
  $loadingStyleSettingsRoute,
  $roomCardSettingsRoute,
  $videoSettingsRoute,
  $mpvSettingsRoute,
  $localConfigPreviewRoute,
  $recorderSettingsRoute,
  $platformsSettingsRoute,
  $danmakuSettingsRoute,
  $portraitSettingsRoute,
  $recordingSettingsRoute,
  $localInteractionRoute,
  $logsRoute,
  $hotAreasRoute,
  $tagsRoute,
  $shieldRoute,
  $splashRoute,
  $toolboxRoute,
  $vodRoute,
  $vodPlayRoute,
  $musicRoute,
];

RouteBase get $appShellRouteData => StatefulShellRouteData.$route(
  factory: $AppShellRouteDataExtension._fromState,
  branches: [
    StatefulShellBranchData.$branch(
      routes: [GoRouteData.$route(path: '/', hasOverriddenOnExit: false, factory: $FollowRoute._fromState)],
    ),
    StatefulShellBranchData.$branch(
      routes: [GoRouteData.$route(path: '/popular', hasOverriddenOnExit: false, factory: $PopularRoute._fromState)],
    ),
    StatefulShellBranchData.$branch(
      routes: [GoRouteData.$route(path: '/areas', hasOverriddenOnExit: false, factory: $AreasRoute._fromState)],
    ),
    StatefulShellBranchData.$branch(
      routes: [GoRouteData.$route(path: '/iptv', hasOverriddenOnExit: false, factory: $IptvRoute._fromState)],
    ),
    StatefulShellBranchData.$branch(
      routes: [GoRouteData.$route(path: '/recorder', hasOverriddenOnExit: false, factory: $RecorderRoute._fromState)],
    ),
    StatefulShellBranchData.$branch(
      routes: [GoRouteData.$route(path: '/multiview', hasOverriddenOnExit: false, factory: $MultiviewRoute._fromState)],
    ),
    StatefulShellBranchData.$branch(
      routes: [GoRouteData.$route(path: '/toolbox', hasOverriddenOnExit: false, factory: $ToolboxRoute._fromState)],
    ),
    StatefulShellBranchData.$branch(
      routes: [GoRouteData.$route(path: '/search', hasOverriddenOnExit: false, factory: $SearchRoute._fromState)],
    ),
    StatefulShellBranchData.$branch(
      routes: [GoRouteData.$route(path: '/history', hasOverriddenOnExit: false, factory: $HistoryRoute._fromState)],
    ),
  ],
);

extension $AppShellRouteDataExtension on AppShellRouteData {
  static AppShellRouteData _fromState(GoRouterState state) => const AppShellRouteData();
}

mixin $FollowRoute on GoRouteData {
  static FollowRoute _fromState(GoRouterState state) => const FollowRoute();

  @override
  String get location => GoRouteData.$location('/');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $PopularRoute on GoRouteData {
  static PopularRoute _fromState(GoRouterState state) => const PopularRoute();

  @override
  String get location => GoRouteData.$location('/popular');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $AreasRoute on GoRouteData {
  static AreasRoute _fromState(GoRouterState state) => const AreasRoute();

  @override
  String get location => GoRouteData.$location('/areas');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $IptvRoute on GoRouteData {
  static IptvRoute _fromState(GoRouterState state) => const IptvRoute();

  @override
  String get location => GoRouteData.$location('/iptv');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $RecorderRoute on GoRouteData {
  static RecorderRoute _fromState(GoRouterState state) => const RecorderRoute();

  @override
  String get location => GoRouteData.$location('/recorder');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $MultiviewRoute on GoRouteData {
  static MultiviewRoute _fromState(GoRouterState state) => const MultiviewRoute();

  @override
  String get location => GoRouteData.$location('/multiview');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $ToolboxRoute on GoRouteData {
  static ToolboxRoute _fromState(GoRouterState state) => const ToolboxRoute();

  @override
  String get location => GoRouteData.$location('/toolbox');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $SearchRoute on GoRouteData {
  static SearchRoute _fromState(GoRouterState state) => const SearchRoute();

  @override
  String get location => GoRouteData.$location('/search');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $HistoryRoute on GoRouteData {
  static HistoryRoute _fromState(GoRouterState state) => const HistoryRoute();

  @override
  String get location => GoRouteData.$location('/history');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $aboutRoute =>
    GoRouteData.$route(path: '/about', hasOverriddenOnExit: false, factory: $AboutRoute._fromState);

mixin $AboutRoute on GoRouteData {
  static AboutRoute _fromState(GoRouterState state) => const AboutRoute();

  @override
  String get location => GoRouteData.$location('/about');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $versionRoute =>
    GoRouteData.$route(path: '/about/version', hasOverriddenOnExit: false, factory: $VersionRoute._fromState);

mixin $VersionRoute on GoRouteData {
  static VersionRoute _fromState(GoRouterState state) => const VersionRoute();

  @override
  String get location => GoRouteData.$location('/about/version');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $versionHistoryRoute => GoRouteData.$route(
  path: '/about/version/history',
  hasOverriddenOnExit: false,
  factory: $VersionHistoryRoute._fromState,
);

mixin $VersionHistoryRoute on GoRouteData {
  static VersionHistoryRoute _fromState(GoRouterState state) => const VersionHistoryRoute();

  @override
  String get location => GoRouteData.$location('/about/version/history');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $areaRoomsRoute =>
    GoRouteData.$route(path: '/areas/:siteId/:areaId', hasOverriddenOnExit: false, factory: $AreaRoomsRoute._fromState);

mixin $AreaRoomsRoute on GoRouteData {
  static AreaRoomsRoute _fromState(GoRouterState state) => AreaRoomsRoute(
    siteId: state.pathParameters['siteId']!,
    areaId: state.pathParameters['areaId']!,
    areaName: state.uri.queryParameters['area-name'] ?? '',
  );

  AreaRoomsRoute get _self => this as AreaRoomsRoute;

  @override
  String get location => GoRouteData.$location(
    '/areas/${Uri.encodeComponent(_self.siteId)}/${Uri.encodeComponent(_self.areaId)}',
    queryParams: {if (_self.areaName != '') 'area-name': _self.areaName},
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $followedAreasRoute =>
    GoRouteData.$route(path: '/areas/followed', hasOverriddenOnExit: false, factory: $FollowedAreasRoute._fromState);

mixin $FollowedAreasRoute on GoRouteData {
  static FollowedAreasRoute _fromState(GoRouterState state) => const FollowedAreasRoute();

  @override
  String get location => GoRouteData.$location('/areas/followed');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $backupRoute =>
    GoRouteData.$route(path: '/settings/backup', hasOverriddenOnExit: false, factory: $BackupRoute._fromState);

mixin $BackupRoute on GoRouteData {
  static BackupRoute _fromState(GoRouterState state) => const BackupRoute();

  @override
  String get location => GoRouteData.$location('/settings/backup');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $iptvPlayRoute =>
    GoRouteData.$route(path: '/iptv/play/:channelId', hasOverriddenOnExit: false, factory: $IptvPlayRoute._fromState);

mixin $IptvPlayRoute on GoRouteData {
  static IptvPlayRoute _fromState(GoRouterState state) =>
      IptvPlayRoute(channelId: state.pathParameters['channelId']!, name: state.uri.queryParameters['name'] ?? '');

  IptvPlayRoute get _self => this as IptvPlayRoute;

  @override
  String get location => GoRouteData.$location(
    '/iptv/play/${Uri.encodeComponent(_self.channelId)}',
    queryParams: {if (_self.name != '') 'name': _self.name},
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $loginRoute =>
    GoRouteData.$route(path: '/login', hasOverriddenOnExit: false, factory: $LoginRoute._fromState);

mixin $LoginRoute on GoRouteData {
  static LoginRoute _fromState(GoRouterState state) => const LoginRoute();

  @override
  String get location => GoRouteData.$location('/login');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $accountRoute =>
    GoRouteData.$route(path: '/settings/account', hasOverriddenOnExit: false, factory: $AccountRoute._fromState);

mixin $AccountRoute on GoRouteData {
  static AccountRoute _fromState(GoRouterState state) => const AccountRoute();

  @override
  String get location => GoRouteData.$location('/settings/account');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $accountCookieRoute => GoRouteData.$route(
  path: '/settings/account/cookie',
  hasOverriddenOnExit: false,
  factory: $AccountCookieRoute._fromState,
);

mixin $AccountCookieRoute on GoRouteData {
  static AccountCookieRoute _fromState(GoRouterState state) =>
      AccountCookieRoute(siteId: state.uri.queryParameters['site-id']!);

  AccountCookieRoute get _self => this as AccountCookieRoute;

  @override
  String get location => GoRouteData.$location('/settings/account/cookie', queryParams: {'site-id': _self.siteId});

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $webSearchRoute =>
    GoRouteData.$route(path: '/search/web', hasOverriddenOnExit: false, factory: $WebSearchRoute._fromState);

mixin $WebSearchRoute on GoRouteData {
  static WebSearchRoute _fromState(GoRouterState state) => WebSearchRoute(
    url: state.uri.queryParameters['url']!,
    platform: state.uri.queryParameters['platform'] ?? '',
    keyword: state.uri.queryParameters['keyword'] ?? '',
  );

  WebSearchRoute get _self => this as WebSearchRoute;

  @override
  String get location => GoRouteData.$location(
    '/search/web',
    queryParams: {
      'url': _self.url,
      if (_self.platform != '') 'platform': _self.platform,
      if (_self.keyword != '') 'keyword': _self.keyword,
    },
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $roomRoute =>
    GoRouteData.$route(path: '/room/:siteId/:roomId', hasOverriddenOnExit: false, factory: $RoomRoute._fromState);

mixin $RoomRoute on GoRouteData {
  static RoomRoute _fromState(GoRouterState state) => RoomRoute(
    siteId: state.pathParameters['siteId']!,
    roomId: state.pathParameters['roomId']!,
    roomName: state.uri.queryParameters['room-name'] ?? '',
  );

  RoomRoute get _self => this as RoomRoute;

  @override
  String get location => GoRouteData.$location(
    '/room/${Uri.encodeComponent(_self.siteId)}/${Uri.encodeComponent(_self.roomId)}',
    queryParams: {if (_self.roomName != '') 'room-name': _self.roomName},
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $settingsRoute =>
    GoRouteData.$route(path: '/settings', hasOverriddenOnExit: false, factory: $SettingsRoute._fromState);

mixin $SettingsRoute on GoRouteData {
  static SettingsRoute _fromState(GoRouterState state) =>
      SettingsRoute(section: state.uri.queryParameters['section'] ?? '');

  SettingsRoute get _self => this as SettingsRoute;

  @override
  String get location =>
      GoRouteData.$location('/settings', queryParams: {if (_self.section != '') 'section': _self.section});

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $appearanceRoute =>
    GoRouteData.$route(path: '/settings/appearance', hasOverriddenOnExit: false, factory: $AppearanceRoute._fromState);

mixin $AppearanceRoute on GoRouteData {
  static AppearanceRoute _fromState(GoRouterState state) => const AppearanceRoute();

  @override
  String get location => GoRouteData.$location('/settings/appearance');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $fontManagerRoute =>
    GoRouteData.$route(path: '/settings/fonts', hasOverriddenOnExit: false, factory: $FontManagerRoute._fromState);

mixin $FontManagerRoute on GoRouteData {
  static FontManagerRoute _fromState(GoRouterState state) => const FontManagerRoute();

  @override
  String get location => GoRouteData.$location('/settings/fonts');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $wallpaperRoute =>
    GoRouteData.$route(path: '/settings/wallpaper', hasOverriddenOnExit: false, factory: $WallpaperRoute._fromState);

mixin $WallpaperRoute on GoRouteData {
  static WallpaperRoute _fromState(GoRouterState state) => const WallpaperRoute();

  @override
  String get location => GoRouteData.$location('/settings/wallpaper');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $cacheDataRoute =>
    GoRouteData.$route(path: '/settings/data', hasOverriddenOnExit: false, factory: $CacheDataRoute._fromState);

mixin $CacheDataRoute on GoRouteData {
  static CacheDataRoute _fromState(GoRouterState state) => const CacheDataRoute();

  @override
  String get location => GoRouteData.$location('/settings/data');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $generalSettingsRoute => GoRouteData.$route(
  path: '/settings/general',
  hasOverriddenOnExit: false,
  factory: $GeneralSettingsRoute._fromState,
);

mixin $GeneralSettingsRoute on GoRouteData {
  static GeneralSettingsRoute _fromState(GoRouterState state) => const GeneralSettingsRoute();

  @override
  String get location => GoRouteData.$location('/settings/general');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $refreshSettingsRoute => GoRouteData.$route(
  path: '/settings/refresh',
  hasOverriddenOnExit: false,
  factory: $RefreshSettingsRoute._fromState,
);

mixin $RefreshSettingsRoute on GoRouteData {
  static RefreshSettingsRoute _fromState(GoRouterState state) => const RefreshSettingsRoute();

  @override
  String get location => GoRouteData.$location('/settings/refresh');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $pageSettingsRoute =>
    GoRouteData.$route(path: '/settings/pages', hasOverriddenOnExit: false, factory: $PageSettingsRoute._fromState);

mixin $PageSettingsRoute on GoRouteData {
  static PageSettingsRoute _fromState(GoRouterState state) => const PageSettingsRoute();

  @override
  String get location => GoRouteData.$location('/settings/pages');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $navigationSettingsRoute => GoRouteData.$route(
  path: '/settings/navigation',
  hasOverriddenOnExit: false,
  factory: $NavigationSettingsRoute._fromState,
);

mixin $NavigationSettingsRoute on GoRouteData {
  static NavigationSettingsRoute _fromState(GoRouterState state) => const NavigationSettingsRoute();

  @override
  String get location => GoRouteData.$location('/settings/navigation');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $networkProxySettingsRoute => GoRouteData.$route(
  path: '/settings/proxy',
  hasOverriddenOnExit: false,
  factory: $NetworkProxySettingsRoute._fromState,
);

mixin $NetworkProxySettingsRoute on GoRouteData {
  static NetworkProxySettingsRoute _fromState(GoRouterState state) => const NetworkProxySettingsRoute();

  @override
  String get location => GoRouteData.$location('/settings/proxy');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $loadingStyleSettingsRoute => GoRouteData.$route(
  path: '/settings/loading-style',
  hasOverriddenOnExit: false,
  factory: $LoadingStyleSettingsRoute._fromState,
);

mixin $LoadingStyleSettingsRoute on GoRouteData {
  static LoadingStyleSettingsRoute _fromState(GoRouterState state) => const LoadingStyleSettingsRoute();

  @override
  String get location => GoRouteData.$location('/settings/loading-style');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $roomCardSettingsRoute => GoRouteData.$route(
  path: '/settings/room-card',
  hasOverriddenOnExit: false,
  factory: $RoomCardSettingsRoute._fromState,
);

mixin $RoomCardSettingsRoute on GoRouteData {
  static RoomCardSettingsRoute _fromState(GoRouterState state) => const RoomCardSettingsRoute();

  @override
  String get location => GoRouteData.$location('/settings/room-card');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $videoSettingsRoute =>
    GoRouteData.$route(path: '/settings/video', hasOverriddenOnExit: false, factory: $VideoSettingsRoute._fromState);

mixin $VideoSettingsRoute on GoRouteData {
  static VideoSettingsRoute _fromState(GoRouterState state) => const VideoSettingsRoute();

  @override
  String get location => GoRouteData.$location('/settings/video');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $mpvSettingsRoute =>
    GoRouteData.$route(path: '/settings/mpv', hasOverriddenOnExit: false, factory: $MpvSettingsRoute._fromState);

mixin $MpvSettingsRoute on GoRouteData {
  static MpvSettingsRoute _fromState(GoRouterState state) => const MpvSettingsRoute();

  @override
  String get location => GoRouteData.$location('/settings/mpv');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $localConfigPreviewRoute => GoRouteData.$route(
  path: '/settings/local-config',
  hasOverriddenOnExit: false,
  factory: $LocalConfigPreviewRoute._fromState,
);

mixin $LocalConfigPreviewRoute on GoRouteData {
  static LocalConfigPreviewRoute _fromState(GoRouterState state) => const LocalConfigPreviewRoute();

  @override
  String get location => GoRouteData.$location('/settings/local-config');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $recorderSettingsRoute => GoRouteData.$route(
  path: '/settings/recorder',
  hasOverriddenOnExit: false,
  factory: $RecorderSettingsRoute._fromState,
);

mixin $RecorderSettingsRoute on GoRouteData {
  static RecorderSettingsRoute _fromState(GoRouterState state) => const RecorderSettingsRoute();

  @override
  String get location => GoRouteData.$location('/settings/recorder');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $platformsSettingsRoute => GoRouteData.$route(
  path: '/settings/platforms',
  hasOverriddenOnExit: false,
  factory: $PlatformsSettingsRoute._fromState,
);

mixin $PlatformsSettingsRoute on GoRouteData {
  static PlatformsSettingsRoute _fromState(GoRouterState state) => const PlatformsSettingsRoute();

  @override
  String get location => GoRouteData.$location('/settings/platforms');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $danmakuSettingsRoute => GoRouteData.$route(
  path: '/settings/danmaku',
  hasOverriddenOnExit: false,
  factory: $DanmakuSettingsRoute._fromState,
);

mixin $DanmakuSettingsRoute on GoRouteData {
  static DanmakuSettingsRoute _fromState(GoRouterState state) => const DanmakuSettingsRoute();

  @override
  String get location => GoRouteData.$location('/settings/danmaku');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $portraitSettingsRoute => GoRouteData.$route(
  path: '/settings/portrait',
  hasOverriddenOnExit: false,
  factory: $PortraitSettingsRoute._fromState,
);

mixin $PortraitSettingsRoute on GoRouteData {
  static PortraitSettingsRoute _fromState(GoRouterState state) => const PortraitSettingsRoute();

  @override
  String get location => GoRouteData.$location('/settings/portrait');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $recordingSettingsRoute => GoRouteData.$route(
  path: '/settings/recording',
  hasOverriddenOnExit: false,
  factory: $RecordingSettingsRoute._fromState,
);

mixin $RecordingSettingsRoute on GoRouteData {
  static RecordingSettingsRoute _fromState(GoRouterState state) => const RecordingSettingsRoute();

  @override
  String get location => GoRouteData.$location('/settings/recording');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $localInteractionRoute => GoRouteData.$route(
  path: '/settings/local-interaction',
  hasOverriddenOnExit: false,
  factory: $LocalInteractionRoute._fromState,
);

mixin $LocalInteractionRoute on GoRouteData {
  static LocalInteractionRoute _fromState(GoRouterState state) => const LocalInteractionRoute();

  @override
  String get location => GoRouteData.$location('/settings/local-interaction');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $logsRoute =>
    GoRouteData.$route(path: '/settings/logs', hasOverriddenOnExit: false, factory: $LogsRoute._fromState);

mixin $LogsRoute on GoRouteData {
  static LogsRoute _fromState(GoRouterState state) => const LogsRoute();

  @override
  String get location => GoRouteData.$location('/settings/logs');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $hotAreasRoute =>
    GoRouteData.$route(path: '/settings/hot-areas', hasOverriddenOnExit: false, factory: $HotAreasRoute._fromState);

mixin $HotAreasRoute on GoRouteData {
  static HotAreasRoute _fromState(GoRouterState state) => const HotAreasRoute();

  @override
  String get location => GoRouteData.$location('/settings/hot-areas');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $tagsRoute =>
    GoRouteData.$route(path: '/settings/tags', hasOverriddenOnExit: false, factory: $TagsRoute._fromState);

mixin $TagsRoute on GoRouteData {
  static TagsRoute _fromState(GoRouterState state) => const TagsRoute();

  @override
  String get location => GoRouteData.$location('/settings/tags');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $shieldRoute =>
    GoRouteData.$route(path: '/settings/shield', hasOverriddenOnExit: false, factory: $ShieldRoute._fromState);

mixin $ShieldRoute on GoRouteData {
  static ShieldRoute _fromState(GoRouterState state) => const ShieldRoute();

  @override
  String get location => GoRouteData.$location('/settings/shield');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $splashRoute =>
    GoRouteData.$route(path: '/splash', hasOverriddenOnExit: false, factory: $SplashRoute._fromState);

mixin $SplashRoute on GoRouteData {
  static SplashRoute _fromState(GoRouterState state) => const SplashRoute();

  @override
  String get location => GoRouteData.$location('/splash');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $toolboxRoute =>
    GoRouteData.$route(path: '/toolbox', hasOverriddenOnExit: false, factory: $ToolboxRoute._fromState);

RouteBase get $vodRoute => GoRouteData.$route(path: '/vod', hasOverriddenOnExit: false, factory: $VodRoute._fromState);

mixin $VodRoute on GoRouteData {
  static VodRoute _fromState(GoRouterState state) => const VodRoute();

  @override
  String get location => GoRouteData.$location('/vod');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $vodPlayRoute =>
    GoRouteData.$route(path: '/vod/play', hasOverriddenOnExit: false, factory: $VodPlayRoute._fromState);

mixin $VodPlayRoute on GoRouteData {
  static VodPlayRoute _fromState(GoRouterState state) =>
      VodPlayRoute(videoId: state.uri.queryParameters['video-id']!, title: state.uri.queryParameters['title'] ?? '');

  VodPlayRoute get _self => this as VodPlayRoute;

  @override
  String get location => GoRouteData.$location(
    '/vod/play',
    queryParams: {'video-id': _self.videoId, if (_self.title != '') 'title': _self.title},
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $musicRoute =>
    GoRouteData.$route(path: '/music', hasOverriddenOnExit: false, factory: $MusicRoute._fromState);

mixin $MusicRoute on GoRouteData {
  static MusicRoute _fromState(GoRouterState state) => const MusicRoute();

  @override
  String get location => GoRouteData.$location('/music');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}
