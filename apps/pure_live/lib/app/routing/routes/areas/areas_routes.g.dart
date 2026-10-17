// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'areas_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$areasRoute, $areaRoomsRoute];

RouteBase get $areasRoute => GoRouteData.$route(
  path: '/areas',
  hasOverriddenOnExit: false,
  factory: $AreasRoute._fromState,
);

mixin $AreasRoute on GoRouteData {
  static AreasRoute _fromState(GoRouterState state) => const AreasRoute();

  @override
  String get location => GoRouteData.$location('/areas');

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
  path: '/areas/:siteId/:areaId',
  hasOverriddenOnExit: false,
  factory: $AreaRoomsRoute._fromState,
);

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
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}
