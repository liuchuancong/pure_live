import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/seventeenlive/parsers/seventeenlive_failure.dart';
import 'package:live_sites/src/platforms/seventeenlive/seventeenlive_manifest.dart';
import 'package:live_sites/src/platforms/seventeenlive/seventeenlive_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// 17LIVE's rooms: one `lives/<id>` for a room, the Japan recommendation
/// sections as the directory.
///
/// [getRoom] is the room entry and, at the same time, the refresh: this contract
/// has no separate refresher, and the reference read the same answer for both —
/// the entry carries the pull URLs and the chat channel in its transient handles,
/// which a follow-card refresh simply ignores. An id that is not a room id (1 to
/// 12 digits) is not-found without a request.
///
/// The directory is a cursor list: a request that carries a cursor is one
/// request, and one that only names a page number is walked from the first page
/// (see [SeventeenLiveSite.directory]), because the platform has no page
/// parameter at all.
final class SeventeenLiveRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  SeventeenLiveRoomProvider({required this.site});

  /// The site this capability serves.
  final SeventeenLiveSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    try {
      return right(await site.detail(roomId));
    } on SeventeenLiveFailure catch (failure) {
      return left(failure.toLiveSiteError(seventeenliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: seventeenliveSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    try {
      final page = await site.directory(page: request.page, cursor: request.cursor, pageSize: request.pageSize);
      return right(LivePage.of(items: page.rooms, hasMore: page.hasMore, nextCursor: page.nextCursor));
    } on SeventeenLiveFailure catch (failure) {
      return left(failure.toLiveSiteError(seventeenliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: seventeenliveSiteId, message: '$error', cause: error));
    }
  }
}
