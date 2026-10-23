import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kilakila/kilakila_manifest.dart';
import 'package:live_sites/src/platforms/kilakila/kilakila_site.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// KilaKila's recommendations: the hot timeline (热门直播), ten rows a page,
/// deduplicated across the pages read in sequence.
///
/// The platform has no personalized feed; the hot timeline is what the
/// website shows.
final class KilakilaDiscoveryProvider implements LiveDiscoveryProvider {
  /// Serves [site].
  KilakilaDiscoveryProvider({required this.site});

  /// The site this capability serves.
  final KilakilaSite site;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({LivePageRequest? request}) async {
    request ??= LivePageRequest();
    try {
      final page = await site.timeline(request.page, request.pageSize);
      return right(LivePage.of(items: page.rooms, hasMore: page.hasMore));
    } on KilakilaFailure catch (failure) {
      return left(failure.toLiveSiteError(kilakilaSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: kilakilaSiteId, message: '$error', cause: error));
    }
  }
}
