import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/jdlive/jdlive_site.dart';
import 'package:live_sites/src/platforms/jdlive/parsers/jdlive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// JD Live's rooms: the play answer of one broadcast, and pages of the
/// featured list.
///
/// A room read is the play answer and, when live, the playlist check (two
/// requests): the room carries its media facts, so playback answers without
/// another request. A room id that is not a broadcast id is not-found, and a
/// broadcast the site does not know is not-found rather than an offline room.
final class JdliveRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  JdliveRoomProvider({required this.site});

  /// The site this capability serves.
  final JdliveSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    try {
      return right(await site.detail(roomId));
    } on JdliveFailure catch (failure) {
      return left(failure.toLiveSiteError('jdlive'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'jdlive', message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    try {
      // The platform pages the featured list itself (30 broadcasts a page, in
      // a sequence); a caller's page size does not reshape it.
      final page = await site.directory(request.page);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore));
    } on JdliveFailure catch (failure) {
      return left(failure.toLiveSiteError('jdlive'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'jdlive', message: '$error', cause: error));
    }
  }
}
