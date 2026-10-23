import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/acfun/acfun_manifest.dart';
import 'package:live_sites/src/platforms/acfun/acfun_site.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// AcFun's discovery feed: the directory of every live room, by popularity.
///
/// AcFun has no personal recommendation shelf for an anonymous visitor — its
/// own home list is the unfiltered directory sorted by viewers, which is also
/// what the `全部` filter answers with.
final class AcfunDiscoveryProvider implements LiveDiscoveryProvider {
  /// Serves [site].
  AcfunDiscoveryProvider({required this.site});

  /// The site this capability serves.
  final AcfunSite site;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({LivePageRequest? request}) async {
    request ??= LivePageRequest();
    try {
      final page = await site.listing(page: request.page, pageSize: request.pageSize);
      return right(LivePage.of(items: page.rooms, hasMore: page.hasMore, nextCursor: page.nextCursor));
    } on AcfunFailure catch (failure) {
      return left(failure.toLiveSiteError(acfunSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: acfunSiteId, message: '$error', cause: error));
    }
  }
}
