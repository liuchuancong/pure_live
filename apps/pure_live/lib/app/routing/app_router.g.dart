// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
  $appShellRoute,
  $settingsSectionRoute,
  $roomRoute,
  $areaRoomsRoute,
];

RouteBase get $appShellRoute => StatefulShellRouteData.$route(
  factory: $AppShellRouteExtension._fromState,
  branches: [
    StatefulShellBranchData.$branch(
      routes: [
        GoRouteData.$route(
          path: '/',
          hasOverriddenOnExit: false,
          factory: $HomeRoute._fromState,
        ),
      ],
    ),
    StatefulShellBranchData.$branch(
      routes: [
        GoRouteData.$route(
          path: '/zones',
          hasOverriddenOnExit: false,
          factory: $ZonesRoute._fromState,
        ),
      ],
    ),
    StatefulShellBranchData.$branch(
      routes: [
        GoRouteData.$route(
          path: '/live',
          hasOverriddenOnExit: false,
          factory: $LiveRoute._fromState,
        ),
      ],
    ),
    StatefulShellBranchData.$branch(
      routes: [
        GoRouteData.$route(
          path: '/favorites',
          hasOverriddenOnExit: false,
          factory: $FavoritesRoute._fromState,
        ),
      ],
    ),
    StatefulShellBranchData.$branch(
      routes: [
        GoRouteData.$route(
          path: '/history',
          hasOverriddenOnExit: false,
          factory: $HistoryRoute._fromState,
        ),
      ],
    ),
    StatefulShellBranchData.$branch(
      routes: [
        GoRouteData.$route(
          path: '/search',
          hasOverriddenOnExit: false,
          factory: $SearchRoute._fromState,
        ),
      ],
    ),
    StatefulShellBranchData.$branch(
      routes: [
        GoRouteData.$route(
          path: '/multiview',
          hasOverriddenOnExit: false,
          factory: $MultiviewRoute._fromState,
        ),
      ],
    ),
    StatefulShellBranchData.$branch(
      routes: [
        GoRouteData.$route(
          path: '/recorder',
          hasOverriddenOnExit: false,
          factory: $RecorderRoute._fromState,
        ),
      ],
    ),
    StatefulShellBranchData.$branch(
      routes: [
        GoRouteData.$route(
          path: '/toolbox',
          hasOverriddenOnExit: false,
          factory: $ToolboxRoute._fromState,
        ),
      ],
    ),
    StatefulShellBranchData.$branch(
      routes: [
        GoRouteData.$route(
          path: '/settings',
          hasOverriddenOnExit: false,
          factory: $SettingsRoute._fromState,
        ),
      ],
    ),
  ],
);

extension $AppShellRouteExtension on AppShellRoute {
  static AppShellRoute _fromState(GoRouterState state) => const AppShellRoute();
}

mixin $HomeRoute on GoRouteData {
  static HomeRoute _fromState(GoRouterState state) => const HomeRoute();

  @override
  String get location => GoRouteData.$location('/');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $ZonesRoute on GoRouteData {
  static ZonesRoute _fromState(GoRouterState state) => const ZonesRoute();

  @override
  String get location => GoRouteData.$location('/zones');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $LiveRoute on GoRouteData {
  static LiveRoute _fromState(GoRouterState state) => const LiveRoute();

  @override
  String get location => GoRouteData.$location('/live');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $FavoritesRoute on GoRouteData {
  static FavoritesRoute _fromState(GoRouterState state) =>
      const FavoritesRoute();

  @override
  String get location => GoRouteData.$location('/favorites');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

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
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

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
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $MultiviewRoute on GoRouteData {
  static MultiviewRoute _fromState(GoRouterState state) =>
      const MultiviewRoute();

  @override
  String get location => GoRouteData.$location('/multiview');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

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
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

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
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $SettingsRoute on GoRouteData {
  static SettingsRoute _fromState(GoRouterState state) => const SettingsRoute();

  @override
  String get location => GoRouteData.$location('/settings');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $settingsSectionRoute => GoRouteData.$route(
  path: '/settings/:section',
  hasOverriddenOnExit: false,
  factory: $SettingsSectionRoute._fromState,
);

mixin $SettingsSectionRoute on GoRouteData {
  static SettingsSectionRoute _fromState(GoRouterState state) =>
      SettingsSectionRoute(section: state.pathParameters['section']!);

  SettingsSectionRoute get _self => this as SettingsSectionRoute;

  @override
  String get location =>
      GoRouteData.$location('/settings/${Uri.encodeComponent(_self.section)}');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $roomRoute => GoRouteData.$route(
  path: '/room/:platform/:roomId',
  hasOverriddenOnExit: false,
  factory: $RoomRoute._fromState,
);

mixin $RoomRoute on GoRouteData {
  static RoomRoute _fromState(GoRouterState state) => RoomRoute(
    platform: state.pathParameters['platform']!,
    roomId: state.pathParameters['roomId']!,
  );

  RoomRoute get _self => this as RoomRoute;

  @override
  String get location => GoRouteData.$location(
    '/room/${Uri.encodeComponent(_self.platform)}/${Uri.encodeComponent(_self.roomId)}',
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $areaRoomsRoute => GoRouteData.$route(
  path: '/zones/:platform/:areaId',
  hasOverriddenOnExit: false,
  factory: $AreaRoomsRoute._fromState,
);

mixin $AreaRoomsRoute on GoRouteData {
  static AreaRoomsRoute _fromState(GoRouterState state) => AreaRoomsRoute(
    platform: state.pathParameters['platform']!,
    areaId: state.pathParameters['areaId']!,
  );

  AreaRoomsRoute get _self => this as AreaRoomsRoute;

  @override
  String get location => GoRouteData.$location(
    '/zones/${Uri.encodeComponent(_self.platform)}/${Uri.encodeComponent(_self.areaId)}',
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}
