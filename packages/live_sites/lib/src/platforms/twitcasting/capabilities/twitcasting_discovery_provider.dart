import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/twitcasting/parsers/twitcasting_failure.dart';
import 'package:live_sites/src/platforms/twitcasting/twitcasting_manifest.dart';
import 'package:live_sites/src/platforms/twitcasting/twitcasting_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// TwitCasting's recommendations: the whole site's window
/// (`top/category` without an id), paged locally.
///
/// The platform has no personalized feed; the window the homepage's lists
/// show is what the website answers.
final class TwitcastingDiscoveryProvider implements LiveDiscoveryProvider {
  /// Serves [site].
  TwitcastingDiscoveryProvider({required this.site});

  /// The site this capability serves.
  final TwitcastingSite site;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      final page = await site.recommend(request.page, request.pageSize);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore));
    } on TwitcastingFailure catch (failure) {
      return left(failure.toLiveSiteError(twitcastingSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: twitcastingSiteId, message: '$error', cause: error));
    }
  }
}
