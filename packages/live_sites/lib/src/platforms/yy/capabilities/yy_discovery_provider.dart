import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/yy/parsers/yy_failure.dart';
import 'package:live_sites/src/platforms/yy/yy_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// YY's recommendations: the home listing (`more/page.action` with
/// `biz=other`), whose cards name their area by `biz` when the catalog
/// taught it or the preset names it.
///
/// The platform has no personalized feed; the home listing is what the
/// website shows.
final class YyDiscoveryProvider implements LiveDiscoveryProvider {
  /// Serves [site].
  YyDiscoveryProvider({required this.site});

  /// The site this capability serves.
  final YySite site;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      final rooms = await site.recommendRooms(page: request.page, pageSize: request.pageSize);
      return right(LivePage(items: rooms));
    } on YyFailure catch (failure) {
      return left(failure.toLiveSiteError('yy'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'yy', message: '$error', cause: error));
    }
  }
}
