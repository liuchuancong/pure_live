import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:pure_live/app/routing/route_paths.dart';
import 'package:pure_live/features/room/room_page.dart';

part 'room_routes.g.dart';

/// A live room, a full page above the shell; [roomName] only titles the
/// bar until the room detail arrives.
@TypedGoRoute<RoomRoute>(path: RoutePath.room)
class RoomRoute extends GoRouteData with $RoomRoute {
  /// The room route.
  const new({required this.siteId, required this.roomId, this.roomName = ''});

  /// The platform the room belongs to.
  final String siteId;

  /// The platform-specific room id.
  final String roomId;

  /// A caller-provided title hint.
  final String roomName;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      RoomPage(siteId: siteId, roomId: roomId, roomName: roomName);
}
