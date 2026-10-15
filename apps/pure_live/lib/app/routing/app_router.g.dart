// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$appShellRouteData, $popularRoute, $areasRoute, $areaRoomsRoute];

RouteBase get $appShellRouteData => StatefulShellRouteData.$route(
  factory: $AppShellRouteDataExtension._fromState,
  branches: [
    StatefulShellBranchData.$branch(
      routes: [GoRouteData.$route(path: '/', hasOverriddenOnExit: false, factory: $HomeRoute._fromState)],
    ),
    StatefulShellBranchData.$branch(
      routes: [GoRouteData.$route(path: '/follow', hasOverriddenOnExit: false, factory: $FollowRoute._fromState)],
    ),
    StatefulShellBranchData.$branch(
      routes: [GoRouteData.$route(path: '/history', hasOverriddenOnExit: false, factory: $HistoryRoute._fromState)],
    ),
  ],
);

extension $AppShellRouteDataExtension on AppShellRouteData {
  static AppShellRouteData _fromState(GoRouterState state) => const AppShellRouteData();
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

mixin $FollowRoute on GoRouteData {
  static FollowRoute _fromState(GoRouterState state) => const FollowRoute();

  @override
  String get location => GoRouteData.$location('/follow');

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

RouteBase get $popularRoute =>
    GoRouteData.$route(path: '/popular', hasOverriddenOnExit: false, factory: $PopularRoute._fromState);

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

RouteBase get $areasRoute =>
    GoRouteData.$route(path: '/areas', hasOverriddenOnExit: false, factory: $AreasRoute._fromState);

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
