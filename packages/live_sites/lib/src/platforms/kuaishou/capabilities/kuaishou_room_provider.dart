import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kuaishou/kuaishou_manifest.dart';
import 'package:live_sites/src/platforms/kuaishou/kuaishou_site.dart';
import 'package:live_sites/src/platforms/kuaishou/parsers/kuaishou_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Kuaishou's rooms: the streamer's page `/u/{id}` for detail, the home list as
/// the default directory.
///
/// The room's identity is the requested streamer id; this broadcast's
/// `liveStreamId` and its `playUrls` ride in the room's runtime handles for
/// playback and the comment feed.
final class KuaishouRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  KuaishouRoomProvider({required this.site});

  /// The site this capability serves.
  final KuaishouSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    try {
      return right(await site.detail(roomId));
    } on KuaishouFailure catch (failure) {
      return left(failure.toLiveSiteError(kuaishouSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: kuaishouSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    try {
      final page = request.page < 1 ? 1 : request.page;
      final rooms = await site.recommend(page);
      return right(LivePage(items: rooms, hasMore: page <= 1 && rooms.isNotEmpty));
    } on KuaishouFailure catch (failure) {
      return left(failure.toLiveSiteError(kuaishouSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: kuaishouSiteId, message: '$error', cause: error));
    }
  }
}
