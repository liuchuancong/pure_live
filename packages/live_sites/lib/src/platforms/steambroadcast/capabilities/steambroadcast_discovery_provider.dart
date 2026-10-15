import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_failure.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_room_parser.dart' show siteId;
import 'package:live_sites/src/platforms/steambroadcast/steambroadcast_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Steam Broadcast's recommendations: the trending broadcasts (the one area
/// the platform browses), the first [page size] cards of a directory page.
///
/// The platform has no personalized feed; the trending broadcasts are what
/// the website shows.
final class SteambroadcastDiscoveryProvider implements LiveDiscoveryProvider {
  /// Serves [site].
  SteambroadcastDiscoveryProvider({required this.site});

  /// The site this capability serves.
  final SteambroadcastSite site;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      final page = await site.recommend(request.page, request.pageSize);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore));
    } on SteambroadcastFailure catch (failure) {
      return left(failure.toLiveSiteError(siteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: siteId, message: '$error', cause: error));
    }
  }
}
