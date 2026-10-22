import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/chzzk/chzzk_manifest.dart';
import 'package:live_sites/src/platforms/chzzk/chzzk_site.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Chzzk's rooms: the channel and its live for a detail, the site-wide live list
/// as the directory.
///
/// The directory is a cursor list: a request that carries a cursor is one
/// request, and one that only names a page number is walked from the first page
/// (see `ChzzkSite.listing`), because the platform has no page parameter at all.
final class ChzzkRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  ChzzkRoomProvider({required this.site});

  /// The site this capability serves.
  final ChzzkSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    try {
      return right(await site.detail(roomId));
    } on ChzzkFailure catch (failure) {
      return left(failure.toLiveSiteError(chzzkSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: chzzkSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    try {
      final page = await site.listing(page: request.page, cursor: request.cursor);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore, nextCursor: page.nextCursor));
    } on ChzzkFailure catch (failure) {
      return left(failure.toLiveSiteError(chzzkSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: chzzkSiteId, message: '$error', cause: error));
    }
  }
}
