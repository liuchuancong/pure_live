import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/live_page/live_page.dart';
import 'package:live_sites/src/models/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/live_room/live_room.dart';

/// Room-related operations a site may support.
abstract interface class LiveRoomProvider implements LiveSiteCapability {
  /// Fetches a room by its platform-specific [roomId].
  ///
  /// Returns a [LiveSiteNotFound] left when the room does not exist. A site
  /// without room detail simply does not implement this capability, so a
  /// [LiveSiteUnsupported] left is never produced here.
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId);

  /// Fetches a page of rooms (a directory listing) for [request].
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request);
}
