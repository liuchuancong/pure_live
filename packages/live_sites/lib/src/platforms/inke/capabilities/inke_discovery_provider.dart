import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/inke/inke_manifest.dart';
import 'package:live_sites/src/platforms/inke/inke_site.dart';
import 'package:live_sites/src/platforms/inke/parsers/inke_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Inke's recommendations: the app's hot list (`simpleall`), one page.
///
/// The platform has no personalized feed and no native pagination; the hot
/// list is what the app shows, and it ends where the page ends.
final class InkeDiscoveryProvider implements LiveDiscoveryProvider {
  /// Serves [site].
  InkeDiscoveryProvider({required this.site});

  /// The site this capability serves.
  final InkeSite site;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({LivePageRequest? request}) async {
    request ??= LivePageRequest();
    try {
      final page = await site.hot(page: request.page);
      return right(LivePage.of(items: page.rooms, hasMore: page.hasMore));
    } on InkeFailure catch (failure) {
      return left(failure.toLiveSiteError(inkeSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: inkeSiteId, message: '$error', cause: error));
    }
  }
}
