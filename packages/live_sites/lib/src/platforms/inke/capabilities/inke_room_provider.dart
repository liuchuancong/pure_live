import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/inke/inke_manifest.dart';
import 'package:live_sites/src/platforms/inke/inke_site.dart';
import 'package:live_sites/src/platforms/inke/parsers/inke_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Inke's rooms: the entry of one anchor (the website's room, and the app's
/// broadcast for a live one), and the app's hot list as the directory.
///
/// A room id is the anchor's uid; anything else is not-found, without a
/// request. A room the platform calls offline is offline, never unknown.
final class InkeRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  InkeRoomProvider({required this.site});

  /// The site this capability serves.
  final InkeSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    try {
      return right(await site.detail(roomId));
    } on InkeFailure catch (failure) {
      return left(failure.toLiveSiteError(inkeSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: inkeSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    try {
      final page = await site.hot(page: request.page);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore));
    } on InkeFailure catch (failure) {
      return left(failure.toLiveSiteError(inkeSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: inkeSiteId, message: '$error', cause: error));
    }
  }
}
