// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'multiview_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$multiviewRoute];

RouteBase get $multiviewRoute =>
    GoRouteData.$route(path: '/multiview', hasOverriddenOnExit: false, factory: $MultiviewRoute._fromState);

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
