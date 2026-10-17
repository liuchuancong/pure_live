import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_live/app/routing/route_paths.dart';
import 'package:pure_live/features/area_rooms/area_rooms_page.dart';

part 'areas_routes.g.dart';

// The areas tab's root route (`AreasRoute`, `/areas`) lives in
// `app_router.dart`, because it is a branch of the shell and the branch
// nesting is one annotation there. This file keeps the pages reached from
// the tab that render above the shell.

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
