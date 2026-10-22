import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/picarto/parsers/picarto_failure.dart';
import 'package:live_sites/src/platforms/picarto/picarto_manifest.dart';
import 'package:live_sites/src/platforms/picarto/picarto_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Picarto's recommendations: the public directory (`api/explore`), live
/// non-adult channels by viewers, thirty a page.
///
/// The platform has no personalized feed; its own explore page is what the
/// website shows.
final class PicartoDiscoveryProvider implements LiveDiscoveryProvider {
  /// Serves [site].
  PicartoDiscoveryProvider({required this.site});

  /// The site this capability serves.
  final PicartoSite site;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      final page = await site.directory(request.page, request.pageSize);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore));
    } on PicartoFailure catch (failure) {
      return left(failure.toLiveSiteError(picartoSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: picartoSiteId, message: '$error', cause: error));
    }
  }
}
