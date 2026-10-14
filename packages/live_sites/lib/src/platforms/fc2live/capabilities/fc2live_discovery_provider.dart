import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/fc2live/fc2live_site.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// FC2 Live's discovery feed: the directory itself, which is every channel on
/// air in the site's order.
///
/// FC2 offers an anonymous visitor nothing personalised — no trending list, no
/// recommended rail, no popularity figure beside the raw viewer count — so this
/// is the same snapshot the directory pages through, sliced by the caller's page
/// rather than the platform's own 20.
final class Fc2LiveDiscoveryProvider implements LiveDiscoveryProvider {
  /// Serves [site].
  Fc2LiveDiscoveryProvider({required this.site});

  /// The site this capability serves.
  final Fc2LiveSite site;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      final page = await site.listing(page: request.page, pageSize: request.pageSize);
      return right(LivePage(items: page.rooms, totalCount: page.totalCount, hasMore: page.hasMore));
    } on Fc2LiveFailure catch (failure) {
      return left(failure.toLiveSiteError('fc2live'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'fc2live', message: '$error', cause: error));
    }
  }
}
