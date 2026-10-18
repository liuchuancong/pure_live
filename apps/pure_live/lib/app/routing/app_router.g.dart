// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$appShellRouteData];

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
      routes: [GoRouteData.$route(path: '/recorder', hasOverriddenOnExit: false, factory: $RecorderRoute._fromState)],
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
