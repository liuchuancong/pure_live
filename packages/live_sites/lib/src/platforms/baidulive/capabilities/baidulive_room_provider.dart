import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/baidulive/baidulive_manifest.dart';
import 'package:live_sites/src/platforms/baidulive/baidulive_site.dart';
import 'package:live_sites/src/platforms/baidulive/parsers/baidulive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Baidu Live's rooms: one room command per lookup, with the answer kept as
/// the room's stream data (3.x's room entry, follow refresh and recording
/// answer are this one request), and pages of the recommendations.
///
/// A room id is the room as asked for (a room link is read too); anything
/// else is not-found without a request. A room is offline only when the
/// platform says so — an announced or ended broadcast is not, and a state the
/// platform does not name stays unknown, never "offline".
final class BaiduliveRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  BaiduliveRoomProvider({required this.site});

  /// The site this capability serves.
  final BaiduliveSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    try {
      return right(await site.detail(roomId));
    } on BaiduliveFailure catch (failure) {
      return left(failure.toLiveSiteError(baiduliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: baiduliveSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    try {
      final page = await site.recommend(request.page, request.pageSize);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore));
    } on BaiduliveFailure catch (failure) {
      return left(failure.toLiveSiteError(baiduliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: baiduliveSiteId, message: '$error', cause: error));
    }
  }
}
