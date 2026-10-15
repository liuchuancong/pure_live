import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/yy/parsers/yy_failure.dart';
import 'package:live_sites/src/platforms/yy/yy_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// YY's rooms: the entry of one channel (its `liveInfoDetail`, the room page
/// telling offline, unknown and short numbers apart), and the home listing
/// as the default directory.
///
/// A room id is a channel number; anything else is not-found, without a
/// request. A short number keeps the room's identity: its canonical channel
/// rides in the room's stream handle.
final class YyRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  YyRoomProvider({required this.site});

  /// The site this capability serves.
  final YySite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    try {
      return right(await site.detail(roomId));
    } on YyFailure catch (failure) {
      return left(failure.toLiveSiteError('yy'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'yy', message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    try {
      final rooms = await site.recommendRooms(page: request.page, pageSize: request.pageSize);
      return right(LivePage(items: rooms));
    } on YyFailure catch (failure) {
      return left(failure.toLiveSiteError('yy'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'yy', message: '$error', cause: error));
    }
  }
}
