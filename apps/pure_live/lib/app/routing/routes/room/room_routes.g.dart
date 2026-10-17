// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$roomRoute];

RouteBase get $roomRoute => GoRouteData.$route(
  path: '/room/:siteId/:roomId',
  hasOverriddenOnExit: false,
  factory: $RoomRoute._fromState,
);

mixin $RoomRoute on GoRouteData {
  static RoomRoute _fromState(GoRouterState state) => RoomRoute(
    siteId: state.pathParameters['siteId']!,
    roomId: state.pathParameters['roomId']!,
    roomName: state.uri.queryParameters['room-name'] ?? '',
  );

  RoomRoute get _self => this as RoomRoute;

  @override
  String get location => GoRouteData.$location(
    '/room/${Uri.encodeComponent(_self.siteId)}/${Uri.encodeComponent(_self.roomId)}',
    queryParams: {if (_self.roomName != '') 'room-name': _self.roomName},
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
