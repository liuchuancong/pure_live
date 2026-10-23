import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/liveme/liveme_manifest.dart';
import 'package:live_sites/src/platforms/liveme/liveme_site.dart';
import 'package:live_sites/src/platforms/liveme/parsers/liveme_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// LiveMe's recommendations: pages of the featured list (the hot list), the
/// page size sent within the platform's limit.
///
/// The platform has no personalized feed; the featured list is what the
/// website shows.
final class LivemeDiscoveryProvider implements LiveDiscoveryProvider {
  /// Serves [site].
  LivemeDiscoveryProvider({required this.site});

  /// The site this capability serves.
  final LivemeSite site;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({LivePageRequest? request}) async {
    request ??= LivePageRequest();
    try {
      final page = await site.featured(page: request.page, pageSize: request.pageSize);
      return right(LivePage.of(items: page.rooms, hasMore: page.hasMore));
    } on LivemeFailure catch (failure) {
      return left(failure.toLiveSiteError(livemeSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: livemeSiteId, message: '$error', cause: error));
    }
  }
}
