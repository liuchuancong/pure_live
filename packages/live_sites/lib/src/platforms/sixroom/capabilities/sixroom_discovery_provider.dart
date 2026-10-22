import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_failure.dart';
import 'package:live_sites/src/platforms/sixroom/sixroom_manifest.dart';
import 'package:live_sites/src/platforms/sixroom/sixroom_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Six Rooms' recommendations: the app's mobile list of the live rooms of
/// every area by popularity (`special`), one request a page, a room an
/// earlier page of the sequence gave left out.
///
/// The platform has no personalized feed; the popularity list is what the
/// app's front page shows.
final class SixroomDiscoveryProvider implements LiveDiscoveryProvider {
  /// Serves [site].
  SixroomDiscoveryProvider({required this.site});

  /// The site this capability serves.
  final SixroomSite site;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      final page = await site.directoryPage(request.page, request.pageSize);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore));
    } on SixroomFailure catch (failure) {
      return left(failure.toLiveSiteError(sixroomSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: sixroomSiteId, message: '$error', cause: error));
    }
  }
}
