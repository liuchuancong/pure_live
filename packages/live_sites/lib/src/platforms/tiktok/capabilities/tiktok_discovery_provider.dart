import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/tiktok/parsers/tiktok_failure.dart';
import 'package:live_sites/src/platforms/tiktok/tiktok_manifest.dart';
import 'package:live_sites/src/platforms/tiktok/tiktok_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// TikTok's discovery feed: always an empty page.
///
/// No public directory or recommendation feed is reachable anonymously — the
/// capability is implemented and knowingly empty (an empty page ends the
/// list at once), which is the site's answer, not an unsupported operation.
final class TiktokDiscoveryProvider implements LiveDiscoveryProvider {
  /// Serves [site].
  TiktokDiscoveryProvider({required this.site});

  /// The site this capability serves.
  final TiktokSite site;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      final page = await site.directory(request.page);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore));
    } on TiktokFailure catch (failure) {
      return left(failure.toLiveSiteError(tiktokSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: tiktokSiteId, message: '$error', cause: error));
    }
  }
}
