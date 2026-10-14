import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/bigo/bigo_site.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Bigo's rooms: the studio answer for a detail, the public list as the
/// directory.
///
/// A detail is three requests (a fresh web token and the studio with it); its
/// id is the site's `clientBigoId`, whatever id it was asked for by. The
/// studio's access and the directory's cards ride in the room's runtime handles
/// for playback and the chat connection.
final class BigoRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  BigoRoomProvider({required this.site});

  /// The site this capability serves.
  final BigoSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    try {
      return right(await site.detail(roomId));
    } on BigoFailure catch (failure) {
      return left(failure.toLiveSiteError('bigo'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'bigo', message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    try {
      final page = request.page < 1 ? 1 : request.page;
      final result = await site.directory(page);
      return right(LivePage(items: result.rooms, hasMore: result.hasMore));
    } on BigoFailure catch (failure) {
      return left(failure.toLiveSiteError('bigo'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'bigo', message: '$error', cause: error));
    }
  }
}
