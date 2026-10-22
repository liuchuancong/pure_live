import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/chzzk/chzzk_manifest.dart';
import 'package:live_sites/src/platforms/chzzk/chzzk_site.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Chzzk's discovery feed: the site-wide live list, which is what the platform
/// shows on its own home page — every open broadcast, ranked by concurrent
/// viewers.
///
/// Chzzk has no personal recommendation for an anonymous visitor, so this is
/// that list; it is a cursor, so a caller that carries one forward gets the next
/// 30 rooms and one that names a page number is walked there.
final class ChzzkDiscoveryProvider implements LiveDiscoveryProvider {
  /// Serves [site].
  ChzzkDiscoveryProvider({required this.site});

  /// The site this capability serves.
  final ChzzkSite site;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      final page = await site.listing(page: request.page, cursor: request.cursor);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore, nextCursor: page.nextCursor));
    } on ChzzkFailure catch (failure) {
      return left(failure.toLiveSiteError(chzzkSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: chzzkSiteId, message: '$error', cause: error));
    }
  }
}
