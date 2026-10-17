// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'iptv_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$iptvRoute, $iptvPlayRoute];

RouteBase get $iptvRoute => GoRouteData.$route(
  path: '/iptv',
  hasOverriddenOnExit: false,
  factory: $IptvRoute._fromState,
);

mixin $IptvRoute on GoRouteData {
  static IptvRoute _fromState(GoRouterState state) => const IptvRoute();

  @override
  String get location => GoRouteData.$location('/iptv');

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

RouteBase get $iptvPlayRoute => GoRouteData.$route(
  path: '/iptv/play/:channelId',
  hasOverriddenOnExit: false,
  factory: $IptvPlayRoute._fromState,
);

mixin $IptvPlayRoute on GoRouteData {
  static IptvPlayRoute _fromState(GoRouterState state) => IptvPlayRoute(
    channelId: state.pathParameters['channelId']!,
    name: state.uri.queryParameters['name'] ?? '',
  );

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
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}
