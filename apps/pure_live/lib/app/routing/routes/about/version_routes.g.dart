// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'version_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$versionRoute];

RouteBase get $versionRoute => GoRouteData.$route(
  path: '/about/version',
  hasOverriddenOnExit: false,
  factory: $VersionRoute._fromState,
);

mixin $VersionRoute on GoRouteData {
  static VersionRoute _fromState(GoRouterState state) => const VersionRoute();

  @override
  String get location => GoRouteData.$location('/about/version');

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
