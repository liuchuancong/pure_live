import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/jdlive/jdlive_manifest.dart';
import 'package:live_sites/src/platforms/jdlive/jdlive_site.dart';
import 'package:live_sites/src/platforms/jdlive/parsers/jdlive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// JD Live's recommendations: the featured list again, in its own page
/// sequence, cut to what the caller asked for (at most 30).
///
/// JD has no personalized feed; the platform's featured list is what the
/// website shows, so the discovery feed is the one area's rooms.
final class JdliveDiscoveryProvider implements LiveDiscoveryProvider {
  /// Serves [site].
  JdliveDiscoveryProvider({required this.site});

  /// The site this capability serves.
  final JdliveSite site;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({LivePageRequest? request}) async {
    request ??= LivePageRequest();
    try {
      final page = await site.recommend(request.page, request.pageSize);
      return right(LivePage.of(items: page.rooms, hasMore: page.hasMore));
    } on JdliveFailure catch (failure) {
      return left(failure.toLiveSiteError(jdliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: jdliveSiteId, message: '$error', cause: error));
    }
  }
}
