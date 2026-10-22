import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/cc/cc_manifest.dart';
import 'package:live_sites/src/platforms/cc/cc_site.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// CC's rooms: the entry of one anchor (`activitylives`, then
/// `live/channel`, else the room page), and pages of the all-live directory.
///
/// A room id is the anchor's ccid; anything else is not-found without a
/// request. An anchor the platform says is not broadcasting is offline, its
/// room page filling in what it keeps.
final class CcRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  CcRoomProvider({required this.site});

  /// The site this capability serves.
  final CcSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    try {
      return right(await site.detail(roomId));
    } on CcFailure catch (failure) {
      return left(failure.toLiveSiteError(ccSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: ccSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    try {
      final page = await site.recommend(page: request.page, pageSize: request.pageSize);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore));
    } on CcFailure catch (failure) {
      return left(failure.toLiveSiteError(ccSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: ccSiteId, message: '$error', cause: error));
    }
  }
}
