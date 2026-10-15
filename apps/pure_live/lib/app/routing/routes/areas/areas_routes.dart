import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_live/app/routing/route_paths.dart';
import 'package:pure_live/features/area_rooms/area_rooms_page.dart';
import 'package:pure_live/features/areas/areas_page.dart';

part 'areas_routes.g.dart';

/// The areas page: every platform's category catalogue, a full page above
/// the shell.
@TypedGoRoute<AreasRoute>(path: RoutePath.areas)
class AreasRoute extends GoRouteData with $AreasRoute {
  /// The areas route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const AreasPage();
}

/// One area's room list, a full page above the shell; [areaName] rides as
/// the query and only titles the page.
@TypedGoRoute<AreaRoomsRoute>(path: RoutePath.areaRooms)
class AreaRoomsRoute extends GoRouteData with $AreaRoomsRoute {
  /// The area rooms route.
  const new({required this.siteId, required this.areaId, this.areaName = ''});

  /// The platform the area belongs to.
  final String siteId;

  /// The area's id.
  final String areaId;

  /// The area's display name.
  final String areaName;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      AreaRoomsPage(siteId: siteId, areaId: areaId, areaName: areaName);
}
