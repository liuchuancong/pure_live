import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_failure.dart';
import 'package:live_sites/src/platforms/showroom/showroom_manifest.dart';
import 'package:live_sites/src/platforms/showroom/showroom_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// SHOWROOM's recommendations: the snapshot's Popularity genre (or every
/// live, when the snapshot has no Popularity genre), sliced as asked.
///
/// The platform has no personalized feed; the Popularity genre is what the
/// website shows first.
final class ShowroomDiscoveryProvider implements LiveDiscoveryProvider {
  /// Serves [site].
  ShowroomDiscoveryProvider({required this.site});

  /// The site this capability serves.
  final ShowroomSite site;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({LivePageRequest? request}) async {
    request ??= LivePageRequest();
    try {
      final page = await site.recommend(request.page, request.pageSize);
      return right(LivePage.of(items: page.rooms, hasMore: page.hasMore));
    } on ShowroomFailure catch (failure) {
      return left(failure.toLiveSiteError(showroomSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: showroomSiteId, message: '$error', cause: error));
    }
  }
}
