import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kuaishou/kuaishou_manifest.dart';
import 'package:live_sites/src/platforms/kuaishou/kuaishou_site.dart';
import 'package:live_sites/src/platforms/kuaishou/parsers/kuaishou_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Kuaishou's discovery feed: the `home/list` recommendations.
///
/// The list answers every page the same way (3.x did too), so a later page is
/// empty without a request.
final class KuaishouDiscoveryProvider implements LiveDiscoveryProvider {
  /// Serves [site].
  KuaishouDiscoveryProvider({required this.site});

  /// The site this capability serves.
  final KuaishouSite site;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({LivePageRequest? request}) async {
    request ??= LivePageRequest();
    try {
      final page = request.page < 1 ? 1 : request.page;
      final rooms = await site.recommend(page);
      return right(LivePage.of(items: rooms, hasMore: page <= 1 && rooms.isNotEmpty));
    } on KuaishouFailure catch (failure) {
      return left(failure.toLiveSiteError(kuaishouSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: kuaishouSiteId, message: '$error', cause: error));
    }
  }
}
