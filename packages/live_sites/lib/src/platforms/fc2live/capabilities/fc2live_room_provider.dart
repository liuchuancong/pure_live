import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/fc2live/fc2live_site.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// FC2 Live's rooms: one channel's member answer, and the snapshot of every
/// channel on air as the directory.
///
/// The directory has no paging of its own — `allchannellist.php` answers the
/// whole list at once — so a page is a slice of one snapshot and
/// [LivePage.totalCount] is that snapshot's own size, which is why a room does
/// not repeat between pages or drop out of them.
final class Fc2LiveRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  Fc2LiveRoomProvider({required this.site});

  /// The site this capability serves.
  final Fc2LiveSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    try {
      return right(await site.detail(roomId));
    } on Fc2LiveFailure catch (failure) {
      return left(failure.toLiveSiteError('fc2live'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'fc2live', message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    try {
      final page = await site.listing(page: request.page, pageSize: request.pageSize);
      return right(LivePage(items: page.rooms, totalCount: page.totalCount, hasMore: page.hasMore));
    } on Fc2LiveFailure catch (failure) {
      return left(failure.toLiveSiteError('fc2live'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'fc2live', message: '$error', cause: error));
    }
  }
}
