import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_failure.dart';
import 'package:live_sites/src/platforms/showroom/showroom_manifest.dart';
import 'package:live_sites/src/platforms/showroom/showroom_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// SHOWROOM's rooms: the entry of one room (profile and live info, with the
/// streams and the comment server of a live one), and pages of the
/// recommendations.
///
/// A room id is the room's number; a room key is resolved through
/// `room/status` first. The recommendation pages are slices of the
/// `live/onlives` snapshot, 30 rows a page.
final class ShowroomRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  ShowroomRoomProvider({required this.site});

  /// The site this capability serves.
  final ShowroomSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    try {
      return right(await site.detail(roomId));
    } on ShowroomFailure catch (failure) {
      return left(failure.toLiveSiteError(showroomSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: showroomSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    try {
      // The platform has no directory of its own: the snapshot is sliced
      // locally, and a caller's page size does not reshape the slice.
      final page = await site.directory(request.page);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore));
    } on ShowroomFailure catch (failure) {
      return left(failure.toLiveSiteError(showroomSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: showroomSiteId, message: '$error', cause: error));
    }
  }
}
