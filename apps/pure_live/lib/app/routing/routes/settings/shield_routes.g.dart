// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shield_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$shieldRoute];

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
