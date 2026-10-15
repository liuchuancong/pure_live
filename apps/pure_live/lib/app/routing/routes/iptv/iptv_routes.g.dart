// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'iptv_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$iptvRoute];

RouteBase get $iptvRoute =>
    GoRouteData.$route(path: '/iptv', hasOverriddenOnExit: false, factory: $IptvRoute._fromState);

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
