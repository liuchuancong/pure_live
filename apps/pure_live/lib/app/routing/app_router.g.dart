// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
  $appShellRoute,
  $homeRoute,
  $liveRoute,
  $favoritesRoute,
  $historyRoute,
  $searchRoute,
  $playlistRoute,
  $settingsRoute,
];

RouteBase get $appShellRoute => StatefulShellRouteData.$route(
  factory: $AppShellRouteExtension._fromState,
  branches: [
    StatefulShellBranchData.$branch(
      routes: [GoRouteData.$route(path: '/', hasOverriddenOnExit: false, factory: $HomeRoute._fromState)],
    ),
    StatefulShellBranchData.$branch(
      routes: [GoRouteData.$route(path: '/live', hasOverriddenOnExit: false, factory: $LiveRoute._fromState)],
    ),
    StatefulShellBranchData.$branch(
      routes: [GoRouteData.$route(path: '/favorites', hasOverriddenOnExit: false, factory: $FavoritesRoute._fromState)],
    ),
    StatefulShellBranchData.$branch(
      routes: [GoRouteData.$route(path: '/history', hasOverriddenOnExit: false, factory: $HistoryRoute._fromState)],
    ),
    StatefulShellBranchData.$branch(
      routes: [GoRouteData.$route(path: '/search', hasOverriddenOnExit: false, factory: $SearchRoute._fromState)],
    ),
    StatefulShellBranchData.$branch(
      routes: [GoRouteData.$route(path: '/playlist', hasOverriddenOnExit: false, factory: $PlaylistRoute._fromState)],
    ),
    StatefulShellBranchData.$branch(
      routes: [GoRouteData.$route(path: '/settings', hasOverriddenOnExit: false, factory: $SettingsRoute._fromState)],
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
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

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
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $FavoritesRoute on GoRouteData {
  static FavoritesRoute _fromState(GoRouterState state) => const FavoritesRoute();

  @override
  String get location => GoRouteData.$location('/favorites');

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

mixin $PlaylistRoute on GoRouteData {
  static PlaylistRoute _fromState(GoRouterState state) => const PlaylistRoute();

  @override
  String get location => GoRouteData.$location('/playlist');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

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
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $homeRoute => GoRouteData.$route(path: '/', hasOverriddenOnExit: false, factory: $HomeRoute._fromState);

RouteBase get $liveRoute =>
    GoRouteData.$route(path: '/live', hasOverriddenOnExit: false, factory: $LiveRoute._fromState);

RouteBase get $favoritesRoute =>
    GoRouteData.$route(path: '/favorites', hasOverriddenOnExit: false, factory: $FavoritesRoute._fromState);

RouteBase get $historyRoute =>
    GoRouteData.$route(path: '/history', hasOverriddenOnExit: false, factory: $HistoryRoute._fromState);

RouteBase get $searchRoute =>
    GoRouteData.$route(path: '/search', hasOverriddenOnExit: false, factory: $SearchRoute._fromState);

RouteBase get $playlistRoute =>
    GoRouteData.$route(path: '/playlist', hasOverriddenOnExit: false, factory: $PlaylistRoute._fromState);

RouteBase get $settingsRoute =>
    GoRouteData.$route(path: '/settings', hasOverriddenOnExit: false, factory: $SettingsRoute._fromState);
