import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/looklive/looklive_site.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// LOOK Live's recommendations: the website's two homepage lists merged,
/// video rooms first, twenty a list a page.
///
/// The platform has no personalized feed; the homepage is what the website
/// shows.
final class LookliveDiscoveryProvider implements LiveDiscoveryProvider {
  /// Serves [site].
  LookliveDiscoveryProvider({required this.site});

  /// The site this capability serves.
  final LookliveSite site;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      final page = await site.recommend(request.page, request.pageSize);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore));
    } on LookliveFailure catch (failure) {
      return left(failure.toLiveSiteError('looklive'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'looklive', message: '$error', cause: error));
    }
  }
}
