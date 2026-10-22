import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/soop/parsers/soop_failure.dart';
import 'package:live_sites/src/platforms/soop/soop_manifest.dart';
import 'package:live_sites/src/platforms/soop/soop_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// SOOP's rooms: the entry of one streamer (the player answer completed with
/// the station), and pages of the site-wide recommendations (the directory).
///
/// A room id is the streamer id; anything else is not-found, without a
/// request. A streamer the platform says has no such page is not-found; one
/// off the air or blocked is offline or banned, never unknown.
final class SoopRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  SoopRoomProvider({required this.site});

  /// The site this capability serves.
  final SoopSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    try {
      return right(await site.detail(roomId));
    } on SoopFailure catch (failure) {
      return left(failure.toLiveSiteError(soopSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: soopSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    try {
      final page = await site.recommend(page: request.page);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore));
    } on SoopFailure catch (failure) {
      return left(failure.toLiveSiteError(soopSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: soopSiteId, message: '$error', cause: error));
    }
  }
}
