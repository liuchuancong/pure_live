import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_failure.dart';
import 'package:live_sites/src/platforms/sixroom/sixroom_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Six Rooms' rooms: the entry of one room (the room page for its
/// broadcaster, then the inroom answer with the stream), and pages of the
/// recommendations.
///
/// A room id is a room number or a room link of `v.6.cn` or `m.6.cn`;
/// anything else is not-found, without a request.
final class SixroomRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  SixroomRoomProvider({required this.site});

  /// The site this capability serves.
  final SixroomSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) => _guard(() => site.detail(roomId));

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) => _guard(() async {
    final page = await site.directoryPage(request.page, request.pageSize);
    return LivePage(items: page.rooms, hasMore: page.hasMore);
  });
}

/// Runs [work] at the Either boundary: a platform failure maps onto its
/// [LiveSiteError], anything else is unexpected.
Future<Either<LiveSiteError, T>> _guard<T>(Future<T> Function() work) async {
  try {
    return right(await work());
  } on SixroomFailure catch (failure) {
    return left(failure.toLiveSiteError('sixroom'));
  } on Object catch (error) {
    return left(LiveSiteError.unexpected(siteId: 'sixroom', message: '$error', cause: error));
  }
}
