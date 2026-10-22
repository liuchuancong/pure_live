import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/pandalive/pandalive_manifest.dart';
import 'package:live_sites/src/platforms/pandalive/pandalive_site.dart';
import 'package:live_sites/src/platforms/pandalive/parsers/pandalive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// PandaTV's rooms: the entry of one broadcaster (`member/bj`; while the
/// broadcast is live also `live/play` and its IVS master), and pages of the
/// public directory.
///
/// A room id is a broadcaster id; anything else is not-found, without a
/// request. A broadcast that cannot be played is still entered; its stream
/// says why.
final class PandaliveRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  PandaliveRoomProvider({required this.site});

  /// The site this capability serves.
  final PandaliveSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    try {
      return right(await site.detail(roomId));
    } on PandaliveFailure catch (failure) {
      return left(failure.toLiveSiteError(pandaliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: pandaliveSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    try {
      final page = await site.directory(request.page, request.pageSize);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore));
    } on PandaliveFailure catch (failure) {
      return left(failure.toLiveSiteError(pandaliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: pandaliveSiteId, message: '$error', cause: error));
    }
  }
}
