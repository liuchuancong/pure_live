import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/looklive/looklive_manifest.dart';
import 'package:live_sites/src/platforms/looklive/looklive_site.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// LOOK Live's rooms: the entry of one room (the room answer with its
/// streams), and pages of the merged recommendations.
///
/// A room id is the room's number (a room link is read too); anything else is
/// not-found, without a request. A room is offline only when the platform
/// says so; a banned one says banned, and a state the platform does not name
/// stays unknown.
final class LookliveRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  LookliveRoomProvider({required this.site});

  /// The site this capability serves.
  final LookliveSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    try {
      return right(await site.detail(roomId));
    } on LookliveFailure catch (failure) {
      return left(failure.toLiveSiteError(lookliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: lookliveSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    try {
      final page = await site.recommend(request.page, request.pageSize);
      return right(LivePage.of(items: page.rooms, hasMore: page.hasMore));
    } on LookliveFailure catch (failure) {
      return left(failure.toLiveSiteError(lookliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: lookliveSiteId, message: '$error', cause: error));
    }
  }
}
