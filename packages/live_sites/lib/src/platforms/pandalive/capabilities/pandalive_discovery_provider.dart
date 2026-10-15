import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/pandalive/pandalive_site.dart';
import 'package:live_sites/src/platforms/pandalive/parsers/pandalive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// PandaTV's recommendations: the public directory (公开直播), by
/// popularity.
///
/// The platform has no personalized feed; its directory is what the website
/// shows.
final class PandaliveDiscoveryProvider implements LiveDiscoveryProvider {
  /// Serves [site].
  PandaliveDiscoveryProvider({required this.site});

  /// The site this capability serves.
  final PandaliveSite site;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      final page = await site.directory(request.page, request.pageSize);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore));
    } on PandaliveFailure catch (failure) {
      return left(failure.toLiveSiteError('pandalive'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'pandalive', message: '$error', cause: error));
    }
  }
}
